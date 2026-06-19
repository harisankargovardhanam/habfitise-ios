import Foundation
import RevenueCat

@MainActor
final class PurchaseService: NSObject {
    static let shared = PurchaseService()

    private(set) var offerings: Offerings?
    private(set) var customerInfo: CustomerInfo?
    private(set) var isConfigured = false

    private override init() {
        super.init()
    }

    static func isUsableAPIKey(_ apiKey: String) -> Bool {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let lower = trimmed.lowercased()
        return !AppConstants.RevenueCatConfig.placeholderPrefixes.contains { lower.hasPrefix($0) }
    }

    func configure(apiKey: String, appUserID: String? = nil) {
        guard Self.isUsableAPIKey(apiKey) else { return }
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: apiKey, appUserID: appUserID)
        Purchases.shared.delegate = self
        isConfigured = true
    }

    func refreshCustomerInfo() async throws -> CustomerInfo {
        guard isConfigured else { throw PurchaseServiceError.notConfigured }
        let info = try await Purchases.shared.customerInfo()
        customerInfo = info
        return info
    }

    func fetchOfferings() async throws -> Offerings {
        guard isConfigured else { throw PurchaseServiceError.notConfigured }
        let offerings = try await Purchases.shared.offerings()
        self.offerings = offerings
        return offerings
    }

    func purchase(package: Package) async throws -> CustomerInfo {
        guard isConfigured else { throw PurchaseServiceError.notConfigured }
        let result = try await Purchases.shared.purchase(package: package)
        customerInfo = result.customerInfo
        return result.customerInfo
    }

    func restorePurchases() async throws -> CustomerInfo {
        guard isConfigured else { throw PurchaseServiceError.notConfigured }
        let info = try await Purchases.shared.restorePurchases()
        customerInfo = info
        return info
    }

    var isProActive: Bool {
        customerInfo?.entitlements[AppConstants.RevenueCat.proEntitlementID]?.isActive == true
    }
}

enum PurchaseServiceError: LocalizedError {
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "RevenueCat is not configured. Add REVENUECAT_API_KEY to Config/Secrets.xcconfig."
        }
    }
}

extension PurchaseService: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.customerInfo = customerInfo
        }
    }
}
