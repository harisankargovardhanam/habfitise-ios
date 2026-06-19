import SwiftUI

// MARK: - Section Label

struct ProfileSectionLabel: View {
    @Environment(ThemeManager.self) private var theme
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(theme.colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 20)
    }
}

// MARK: - List Rows

struct ProfileDarkCell<Content: View>: View {
    @Environment(ThemeManager.self) private var theme
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(theme.colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct ProfileChevronRow: View {
    @Environment(ThemeManager.self) private var theme
    let title: String
    var value: String?
    var valueColor: Color?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(theme.colors.textPrimary)

                Spacer()

                if let value {
                    Text(value)
                        .font(.system(size: 15))
                        .foregroundStyle(valueColor ?? theme.colors.textSecondary)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.colors.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ProfileActionRow: View {
    @Environment(ThemeManager.self) private var theme
    let icon: String
    let title: String
    var tint: Color?
    var action: () -> Void

    private var resolvedTint: Color {
        tint ?? theme.colors.danger
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(resolvedTint)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(resolvedTint)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ProfileProUpgradeRow: View {
    @Environment(ThemeManager.self) private var theme
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "star.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(theme.colors.accentGreen)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Habfitise Pro")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(theme.colors.textPrimary)

                    Text("Unlock all features")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.colors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.colors.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Theme Picker

struct ThemePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(spacing: 0) {
            Text("Choose Theme")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(themeManager.colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(AppTheme.allCases) { themeOption in
                        ThemeOptionRow(
                            theme: themeOption,
                            isSelected: themeManager.currentTheme == themeOption,
                            accentGreen: themeOption.colors.accentGreen
                        ) {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                themeManager.applyTheme(themeOption)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(themeManager.colors.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(themeManager.preferredColorScheme)
    }
}

struct ThemeOptionRow: View {
    let theme: AppTheme
    let isSelected: Bool
    let accentGreen: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ThemePreviewCircle(theme: theme)

                Text(theme.rawValue)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(theme.colors.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(accentGreen)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? accentGreen.opacity(0.1) : theme.colors.cardBackground)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isSelected ? accentGreen.opacity(0.25) : theme.colors.cardBorder,
                        lineWidth: 1
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ThemePreviewCircle: View {
    let theme: AppTheme

    var body: some View {
        ZStack {
            Circle()
                .fill(theme.colors.background)
                .frame(width: 36, height: 36)

            Circle()
                .fill(theme.colors.cardBackground)
                .frame(width: 24, height: 24)

            Circle()
                .fill(theme.colors.accentGreen)
                .frame(width: 10, height: 10)
        }
        .frame(width: 36, height: 36)
    }
}

// MARK: - Edit Sheets

struct EditProfileSheet: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ProfileViewModel
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Display name") {
                    TextField("Your name", text: $viewModel.displayName)
                }

                Section("Details") {
                    Stepper("Age: \(viewModel.age)", value: $viewModel.age, in: 13...100)
                    Stepper("Height: \(Int(viewModel.heightCm)) cm", value: $viewModel.heightCm, in: 120...230, step: 1)
                    Stepper(
                        "Weight: \(String(format: "%.1f", viewModel.weightKg)) kg",
                        value: $viewModel.weightKg,
                        in: 30...250,
                        step: 0.5
                    )
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.colors.accentGreen)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct TargetWeightEditSheet: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ProfileViewModel
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Target Weight")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)

                Stepper(
                    String(format: "%.1f kg", viewModel.targetWeightKg),
                    value: $viewModel.targetWeightKg,
                    in: 30...250,
                    step: 0.5
                )
                .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())

                Spacer()
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.colors.accentGreen)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct TimelineEditSheet: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ProfileViewModel
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(GoalTimeline.allCases) { option in
                    Button {
                        viewModel.timeline = option
                    } label: {
                        HStack {
                            Text(option.label)
                                .foregroundStyle(.primary)
                            Spacer()
                            if viewModel.timeline == option {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(theme.colors.accentGreen)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Timeline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.colors.accentGreen)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct DaysPerWeekEditSheet: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ProfileViewModel
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Days per week")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)

                Stepper(
                    "\(viewModel.daysPerWeek) day\(viewModel.daysPerWeek == 1 ? "" : "s")",
                    value: $viewModel.daysPerWeek,
                    in: 1...7
                )
                .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())

                Spacer()
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.colors.accentGreen)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
