import Foundation
import OSLog
import RevenueCat

enum PurchaseConfigurationIssue: Equatable {
    case missingKey
    case unresolvedBuildVariable
    case placeholderKey
    case secretKeyInClient
    case invalidKeyFormat

    var settingsLabel: String {
        switch self {
        case .missingKey:
            "Missing API key"
        case .unresolvedBuildVariable:
            "Build variable not resolved"
        case .placeholderKey:
            "Placeholder key in Secrets.xcconfig"
        case .secretKeyInClient:
            "Use Public SDK key (appl_…), not secret (sk_…)"
        case .invalidKeyFormat:
            "Use iOS public SDK key (appl_…)"
        }
    }
}

struct PurchaseConfigurationStatus: Equatable {
    var isConfigured: Bool
    var issue: PurchaseConfigurationIssue?
    var linkedAppUserID: String?

    static let notConfigured = PurchaseConfigurationStatus(isConfigured: false, issue: .missingKey, linkedAppUserID: nil)

    var connectionLabel: String {
        if let issue, !isConfigured {
            return "Not connected — \(issue.settingsLabel)"
        }
        if let linkedAppUserID {
            return "Connected · \(linkedAppUserID.prefix(8))…"
        }
        if isConfigured {
            return "Ready — sign in to link account"
        }
        return "Not connected"
    }
}

@MainActor
final class PurchaseService: NSObject {
    static let shared = PurchaseService()

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "VAYA", category: "RevenueCat")

    private(set) var offerings: Offerings?
    private(set) var customerInfo: CustomerInfo?
    private(set) var isConfigured = false
    private(set) var linkedAppUserID: String?
    private(set) var lastBootstrapError: String?
    private(set) var configurationStatus = PurchaseConfigurationStatus.notConfigured

    private override init() {
        super.init()
    }

    static func configurationIssue(for apiKey: String) -> PurchaseConfigurationIssue? {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return .missingKey
        }

        if trimmed.contains("$(") {
            return .unresolvedBuildVariable
        }

        let lower = trimmed.lowercased()
        if AppConstants.RevenueCatConfig.placeholderPrefixes.contains(where: { lower.hasPrefix($0) }) {
            return .placeholderKey
        }

        if trimmed.hasPrefix("sk_") {
            return .secretKeyInClient
        }

        if !trimmed.hasPrefix("appl_") && !trimmed.hasPrefix("test_") {
            return .invalidKeyFormat
        }

        return nil
    }

    @discardableResult
    func configureIfNeeded() -> PurchaseConfigurationStatus {
        guard !isConfigured else {
            configurationStatus = PurchaseConfigurationStatus(
                isConfigured: true,
                issue: nil,
                linkedAppUserID: linkedAppUserID
            )
            return configurationStatus
        }

        guard
            let rawKey = Bundle.main.object(forInfoDictionaryKey: AppConstants.RevenueCat.apiKeyKey) as? String
        else {
            configurationStatus = PurchaseConfigurationStatus(isConfigured: false, issue: .missingKey, linkedAppUserID: nil)
            Self.logger.error("RevenueCat API key missing from Info.plist")
            return configurationStatus
        }

        if let issue = Self.configurationIssue(for: rawKey) {
            configurationStatus = PurchaseConfigurationStatus(isConfigured: false, issue: issue, linkedAppUserID: nil)
            Self.logger.error("RevenueCat not configured: \(issue.settingsLabel, privacy: .public)")
            return configurationStatus
        }

        let apiKey = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: apiKey)
        Purchases.shared.delegate = self
        isConfigured = true
        configurationStatus = PurchaseConfigurationStatus(isConfigured: true, issue: nil, linkedAppUserID: linkedAppUserID)
        Self.logger.info("RevenueCat SDK configured")
        return configurationStatus
    }

    var onCustomerInfoUpdated: ((CustomerInfo) -> Void)?

    /// Links RevenueCat to the Supabase user and restores App Store subscriptions after reinstall.
    func bootstrapSubscription(for userId: String) async -> Bool {
        lastBootstrapError = nil
        configureIfNeeded()

        guard isConfigured else {
            lastBootstrapError = configurationStatus.issue?.settingsLabel ?? "RevenueCat is not configured"
            return false
        }

        let normalizedUserId = userId.lowercased()

        do {
            let (loginInfo, created) = try await Purchases.shared.logIn(normalizedUserId)
            customerInfo = loginInfo
            linkedAppUserID = normalizedUserId
            configurationStatus = PurchaseConfigurationStatus(
                isConfigured: true,
                issue: nil,
                linkedAppUserID: linkedAppUserID
            )
            Self.logger.info("RevenueCat logIn succeeded (created=\(created)) for user \(normalizedUserId.prefix(8), privacy: .public)…")

            if isProEntitlementActive(in: loginInfo) {
                return true
            }

            let restored = try await Purchases.shared.restorePurchases()
            customerInfo = restored
            return isProEntitlementActive(in: restored)
        } catch {
            lastBootstrapError = error.localizedDescription
            Self.logger.error("RevenueCat bootstrap failed: \(error.localizedDescription, privacy: .public)")

            if let info = try? await refreshCustomerInfo() {
                linkedAppUserID = normalizedUserId
                return isProEntitlementActive(in: info)
            }
            return false
        }
    }

    func logOutIfNeeded() async {
        guard isConfigured else { return }
        _ = try? await Purchases.shared.logOut()
        customerInfo = nil
        linkedAppUserID = nil
        configurationStatus = PurchaseConfigurationStatus(isConfigured: true, issue: nil, linkedAppUserID: nil)
    }

    private func isProEntitlementActive(in info: CustomerInfo) -> Bool {
        info.entitlements[AppConstants.RevenueCat.proEntitlementID]?.isActive == true
    }

    func refreshCustomerInfo() async throws -> CustomerInfo {
        configureIfNeeded()
        guard isConfigured else { throw PurchaseServiceError.notConfigured(configurationStatus.issue) }
        let info = try await Purchases.shared.customerInfo()
        customerInfo = info
        return info
    }

    func fetchOfferings() async throws -> Offerings {
        configureIfNeeded()
        guard isConfigured else { throw PurchaseServiceError.notConfigured(configurationStatus.issue) }
        let offerings = try await Purchases.shared.offerings()
        self.offerings = offerings
        return offerings
    }

    func purchase(package: Package) async throws -> CustomerInfo {
        configureIfNeeded()
        guard isConfigured else { throw PurchaseServiceError.notConfigured(configurationStatus.issue) }
        let result = try await Purchases.shared.purchase(package: package)
        customerInfo = result.customerInfo
        return result.customerInfo
    }

    func restorePurchases() async throws -> CustomerInfo {
        configureIfNeeded()
        guard isConfigured else { throw PurchaseServiceError.notConfigured(configurationStatus.issue) }
        let info = try await Purchases.shared.restorePurchases()
        customerInfo = info
        return info
    }

    var isProActive: Bool {
        customerInfo?.entitlements[AppConstants.RevenueCat.proEntitlementID]?.isActive == true
    }
}

enum PurchaseServiceError: LocalizedError {
    case notConfigured(PurchaseConfigurationIssue?)

    var errorDescription: String? {
        switch self {
        case .notConfigured(let issue):
            if let issue {
                "RevenueCat is not configured (\(issue.settingsLabel)). Add your iOS public SDK key (appl_…) to Config/Secrets.xcconfig and rebuild."
            } else {
                "RevenueCat is not configured. Add REVENUECAT_API_KEY to Config/Secrets.xcconfig."
            }
        }
    }
}

extension PurchaseService: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.customerInfo = customerInfo
            self.onCustomerInfoUpdated?(customerInfo)
        }
    }
}
