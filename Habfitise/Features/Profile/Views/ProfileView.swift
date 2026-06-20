import SwiftUI
import SwiftData

struct ProfileView: View {
    let userId: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(ThemeManager.self) private var themeManager

    @State private var viewModel = ProfileViewModel()
    @State private var settingsViewModel = SettingsViewModel()
    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var showThemePicker = false
    @State private var showPaywall = false
    @State private var showEditProfile = false
    @State private var showTargetWeightEdit = false
    @State private var showTimelineEdit = false
    @State private var showDaysPerWeekEdit = false
    @State private var showBodyWeightLog = false

    @Query private var profiles: [UserProfile]

    init(userId: String) {
        self.userId = userId
        _profiles = Query(
            filter: #Predicate<UserProfile> { profile in
                profile.userId == userId
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

                    accountSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(themeManager.colors.background.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 17))
                        .foregroundStyle(themeManager.colors.accentGreen)
                }
            }
            .toolbarBackground(themeManager.colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(themeManager.preferredColorScheme, for: .navigationBar)
        }
        .preferredColorScheme(themeManager.preferredColorScheme)
        .onAppear {
            viewModel.load(profile: profiles.first, userId: userId)
        }
        .sheet(isPresented: $showThemePicker) {
            ThemePickerView()
                .environment(themeManager)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environment(appState)
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileSheet(viewModel: viewModel) {
                viewModel.save(profile: profiles.first, context: modelContext)
            }
        }
        .sheet(isPresented: $showTargetWeightEdit) {
            TargetWeightEditSheet(viewModel: viewModel) {
                viewModel.save(profile: profiles.first, context: modelContext)
            }
        }
        .sheet(isPresented: $showTimelineEdit) {
            TimelineEditSheet(viewModel: viewModel) {
                viewModel.save(profile: profiles.first, context: modelContext)
            }
        }
        .sheet(isPresented: $showDaysPerWeekEdit) {
            DaysPerWeekEditSheet(viewModel: viewModel) {
                viewModel.save(profile: profiles.first, context: modelContext)
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
            Text("This permanently deletes your profile, workouts, habits, and all local data. This cannot be undone.")
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
                ProfileChevronRow(
                    title: "App Theme",
                    value: themeManager.currentTheme.rawValue
                ) {
                    showThemePicker = true
                }
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
            }
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProfileSectionLabel(title: "Account")

            ProfileDarkCell {
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
