import SwiftUI
import UIKit

// MARK: - Task Row

struct TaskRow: View {
    @Environment(ThemeManager.self) private var theme
    let task: TaskRecord
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onReschedule: () -> Void

    @State private var checkTrim: CGFloat = 0
    @State private var isCheckedVisual = false
    @State private var flashBackground = false
    @State private var strikeProgress: CGFloat = 0
    @State private var titleMuted = false

    var body: some View {
        HStack(spacing: HabfitiseSpacing.md) {
            TaskCheckCircle(
                isComplete: isCheckedVisual,
                trimProgress: checkTrim,
                onTap: handleToggle
            )

            Text(task.title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(titleMuted ? theme.colors.textTertiary : theme.colors.textPrimary)
                .lineLimit(2)
                .overlay(alignment: .leading) {
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(theme.colors.textTertiary)
                            .frame(width: geometry.size.width * strikeProgress, height: 1)
                            .offset(y: geometry.size.height / 2)
                    }
                }
                .animation(.easeOut(duration: 0.2), value: titleMuted)

            Spacer(minLength: HabfitiseSpacing.sm)

            TaskDueChip(dueDate: task.dueDate, isComplete: isCheckedVisual)
        }
        .padding(HabfitiseSpacing.lg)
        .background(flashBackground ? theme.colors.chipDone : Color.clear)
        .animation(.easeOut(duration: 0.4), value: flashBackground)
        .contentShape(Rectangle())
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                onReschedule()
            } label: {
                Label("Reschedule", systemImage: "calendar")
            }
            .tint(theme.colors.waterBlue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .onAppear {
            syncVisualState(animated: false)
        }
        .onChange(of: task.isComplete) { _, complete in
            if complete, !isCheckedVisual {
                syncVisualState(animated: true)
            } else if !complete {
                syncVisualState(animated: false)
            }
        }
    }

    private func handleToggle() {
        guard !task.isComplete else { return }
        runCompleteAnimation()
        onToggle()
    }

    private func runCompleteAnimation() {
        checkTrim = 0
        withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
            checkTrim = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                isCheckedVisual = true
            }
        }

        flashBackground = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 0.2)) {
                flashBackground = false
            }
        }

        withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
            strikeProgress = 1
        }

        withAnimation(.easeOut(duration: 0.2)) {
            titleMuted = true
        }
    }

    private func syncVisualState(animated: Bool) {
        let complete = task.isComplete
        if animated, complete {
            runCompleteAnimation()
            return
        }

        isCheckedVisual = complete
        checkTrim = complete ? 1 : 0
        strikeProgress = complete ? 1 : 0
        titleMuted = complete
        flashBackground = false
    }
}

// MARK: - Check Circle

struct TaskCheckCircle: View {
    @Environment(ThemeManager.self) private var theme
    let isComplete: Bool
    let trimProgress: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if isComplete {
                    Circle()
                        .fill(theme.colors.accentGreen)
                        .frame(width: 22, height: 22)

                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white)
                } else {
                    Circle()
                        .stroke(theme.colors.trackBackground, lineWidth: 1.5)
                        .frame(width: 22, height: 22)

                    Circle()
                        .trim(from: 0, to: trimProgress)
                        .stroke(
                            theme.colors.accentGreen,
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 22, height: 22)
                }
            }
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .disabled(isComplete)
    }
}

// MARK: - Due Chip

struct TaskDueChip: View {
    @Environment(ThemeManager.self) private var theme
    let dueDate: Date?
    let isComplete: Bool

    private var style: TaskDueChipStyle {
        TaskDueChipStyle.style(for: dueDate, isComplete: isComplete, colors: theme.colors)
    }

    var body: some View {
        Text(style.label)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(style.foreground)
            .padding(.horizontal, HabfitiseSpacing.sm)
            .padding(.vertical, HabfitiseSpacing.xs)
            .background(Capsule().fill(style.background))
            .lineLimit(1)
    }
}

// MARK: - Header Chips

struct TasksHeaderChipRow: View {
    @Environment(ThemeManager.self) private var theme
    let todayCount: Int
    let upcomingCount: Int

    var body: some View {
        HStack(spacing: HabfitiseSpacing.sm) {
            headerChip("\(todayCount) today")
            headerChip("\(upcomingCount) upcoming")
        }
    }

    private func headerChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(theme.colors.textPrimary)
            .padding(.horizontal, HabfitiseSpacing.md)
            .padding(.vertical, HabfitiseSpacing.sm)
            .background(
                Capsule()
                    .fill(theme.colors.fieldBackground)
            )
            .overlay {
                Capsule()
                    .strokeBorder(theme.colors.cardBorder, lineWidth: 1)
            }
    }
}

// MARK: - FAB

struct TasksFAB: View {
    @Environment(ThemeManager.self) private var theme
    let pulse: Bool
    let action: () -> Void

    @State private var pulseScale: CGFloat = 1

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 52, height: 52)
                .background(Circle().fill(theme.colors.accentGreen))
                .shadow(color: theme.colors.accentGreen.opacity(0.35), radius: 10, y: 4)
                .scaleEffect(pulseScale)
        }
        .buttonStyle(.plain)
        .onAppear {
            guard pulse else { return }
            startPulse()
        }
        .onChange(of: pulse) { _, shouldPulse in
            if shouldPulse {
                startPulse()
            } else {
                pulseScale = 1
            }
        }
    }

    private func startPulse() {
        pulseScale = 1
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.05
        }
    }
}
