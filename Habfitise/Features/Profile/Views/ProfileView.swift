import SwiftUI
import SwiftData

struct ProfileView: View {
    let userId: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(SyncService.self) private var syncService
    @Environment(ThemeManager.self) private var themeManager

    @State private var viewModel = ProfileViewModel()
    @State private var settingsViewModel = SettingsViewModel()
    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var showPaywall = false
    @State private var showEditProfile = false
    @State private var showTargetWeightEdit = false
    @State private var showTimelineEdit = false
    @State private var showDaysPerWeekEdit = false
    @State private var showBodyWeightLog = false

    @Query private var profiles: [UserProfile]

    init(userId: String) {
        let normalizedUserId = userId.lowercased()
        self.userId = normalizedUserId
        _profiles = Query(
            filter: #Predicate<UserProfile> { profile in
                profile.userId == normalizedUserId
            }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    userInfoCard
                    appearanceSection
                    goalsSection

                    if !appState.isPro {
                        proSection
                    }

                    developerSection
                    accountSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .cloudRefreshable(scope: .profile) {
                viewModel.load(profile: profiles.first, userId: userId)
                await viewModel.refreshAccountEmail()
            }
            .background(themeManager.colors.background.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .toolbarBackground(themeManager.colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(themeManager.preferredColorScheme, for: .navigationBar)
        }
        .preferredColorScheme(themeManager.preferredColorScheme)
        .task {
            await viewModel.refreshAccountEmail()
        }
        .onAppear {
            viewModel.load(profile: profiles.first, userId: userId)
        }
        .onChange(of: profiles.first?.updatedAt) { _, _ in
            viewModel.load(profile: profiles.first, userId: userId)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environment(appState)
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileSheet(viewModel: viewModel) {
                viewModel.save(profile: profiles.first, context: modelContext)
                pushToCloud()
            }
        }
        .sheet(isPresented: $showTargetWeightEdit) {
            TargetWeightEditSheet(viewModel: viewModel) {
                viewModel.save(profile: profiles.first, context: modelContext)
                pushToCloud()
            }
        }
        .sheet(isPresented: $showTimelineEdit) {
            TimelineEditSheet(viewModel: viewModel) {
                viewModel.save(profile: profiles.first, context: modelContext)
                pushToCloud()
            }
        }
        .sheet(isPresented: $showDaysPerWeekEdit) {
            DaysPerWeekEditSheet(viewModel: viewModel) {
                viewModel.save(profile: profiles.first, context: modelContext)
                pushToCloud()
            }
        }
        .sheet(isPresented: $showBodyWeightLog) {
            BodyWeightLogSheet(userId: userId)
        }
        .alert("Sign out?", isPresented: $showSignOutConfirm) {
            Button("Sign Out", role: .destructive) {
                HabfitiseHaptics.destructive()
                Task {
                    await settingsViewModel.signOut(appState: appState)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to sign in again to access your data on this device.")
        }
        .alert("Delete account?", isPresented: $showDeleteConfirm) {
            Button("Delete Account", role: .destructive) {
                HabfitiseHaptics.destructive()
                Task {
                    await settingsViewModel.deleteAccount(
                        userId: userId,
                        appState: appState,
                        context: modelContext
                    )
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes your profile, workouts, habits, and tasks from this phone only. Your cloud account and data in Supabase are not deleted.")
        }
    }

    // MARK: - Sections

    private var userInfoCard: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.firstInitial)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(themeManager.colors.accentGreen))

                Text(viewModel.displayName.isEmpty ? "Your profile" : viewModel.displayName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(themeManager.colors.textPrimary)

                if !viewModel.accountEmail.isEmpty {
                    Text(viewModel.accountEmail)
                        .font(.system(size: 14))
                        .foregroundStyle(themeManager.colors.textSecondary)
                }

                Text(viewModel.goalSubtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(themeManager.colors.textSecondary)

                Text(viewModel.memberSinceLabel)
                    .font(.system(size: 13))
                    .foregroundStyle(themeManager.colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)

            Button {
                showEditProfile = true
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(themeManager.colors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(themeManager.colors.chipBackground))
            }
            .padding(12)
        }
        .background(themeManager.colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProfileSectionLabel(title: "Appearance")

            ProfileDarkCell {
                VStack(alignment: .leading, spacing: 12) {
                    Text("App Theme")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(themeManager.colors.textPrimary)

                    ThemePickerGrid()
                }
                .padding(16)
            }
        }
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProfileSectionLabel(title: "Goals")

            ProfileDarkCell {
                ProfileChevronRow(
                    title: "Target weight",
                    value: viewModel.targetWeightLabel
                ) {
                    showTargetWeightEdit = true
                }

                rowDivider

                ProfileChevronRow(
                    title: "Timeline",
                    value: viewModel.timelineLabel
                ) {
                    showTimelineEdit = true
                }

                rowDivider

                ProfileChevronRow(
                    title: "Days per week",
                    value: viewModel.daysPerWeekLabel
                ) {
                    showDaysPerWeekEdit = true
                }

                rowDivider

                ProfileChevronRow(
                    title: "Log body weight",
                    value: "Today"
                ) {
                    showBodyWeightLog = true
                }
            }
        }
    }

    private var proSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProfileSectionLabel(title: "Pro")

            ProfileDarkCell {
                ProfileProUpgradeRow {
                    showPaywall = true
                }

                rowDivider

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("Cloud sync", systemImage: "icloud.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(themeManager.colors.textPrimary)
                        Spacer()
                        Text("Pro")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(themeManager.colors.accentGreen)
                    }
                    Text("Sync habits, tasks, and workouts across devices.")
                        .font(.system(size: 13))
                        .foregroundStyle(themeManager.colors.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
    }

    private var developerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProfileSectionLabel(title: "Testing")

            ProfileDarkCell {
                Toggle(isOn: debugProBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("VAYA Pro")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(themeManager.colors.textPrimary)
                        Text("Turn on Pro features for testing")
                            .font(.system(size: 12))
                            .foregroundStyle(themeManager.colors.textSecondary)
                    }
                }
                .tint(themeManager.colors.accentGreen)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
    }

    private var debugProBinding: Binding<Bool> {
        Binding(
            get: { appState.isPro },
            set: { enabled in
                appState.setDebugProEnabled(enabled)
                appState.refreshWidgets(context: modelContext)
                if enabled {
                    Task {
                        await syncService.sync(
                            modelContext: modelContext,
                            userId: userId,
                            mode: .full,
                            scope: .all,
                            force: true
                        )
                    }
                }
            }
        )
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProfileSectionLabel(title: "Account")

            ProfileDarkCell {
                if !AppConstants.Backend.useLocalOnly {
                    HStack {
                        Label("Email", systemImage: "envelope")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(themeManager.colors.textPrimary)
                        Spacer()
                        Text(viewModel.accountEmailLabel)
                            .font(.system(size: 15))
                            .foregroundStyle(themeManager.colors.textSecondary)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                    rowDivider
                }

                ProfileActionRow(icon: "arrow.right.square", title: "Sign Out") {
                    showSignOutConfirm = true
                }

                rowDivider

                ProfileActionRow(icon: "trash", title: "Delete Account") {
                    showDeleteConfirm = true
                }
            }
        }
    }

    private var rowDivider: some View {
        Divider()
            .overlay(Color.white.opacity(0.08))
            .padding(.leading, 16)
    }

    private func pushToCloud() {
        guard appState.canUseCloudSync else { return }
        syncService.schedulePush(modelContext: modelContext, userId: userId)
    }
}

#if DEBUG
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView(userId: "preview")
            .environment(AppState())
            .environment(ThemeManager())
    }
}
#endif
