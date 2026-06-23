# Habfitise — Application Workflows

> One-app fitness companion: **workouts, habits, tasks, water, mood, and progress**.
> This document explains how each section works end-to-end — data, state, and the user flow.

---

## 1. Architecture at a Glance

| Layer | Tech | Role |
|-------|------|------|
| Persistence | **SwiftData** (`@Model`) | **Source of truth.** All writes go here first. |
| Cloud | **Supabase** | Backup + cross-device sync. Optional (`useLocalOnly` flag). |
| State | **`@Observable` ViewModels** (iOS 17+), `@MainActor` | One VM per feature, bound to `@Query` results. |
| UI | **SwiftUI** | Views are dumb; VMs hold logic. |
| Pattern | **Offline-first MVVM** | App fully works with no network. Sync runs opportunistically. |

**Core principle — offline-first.** Every record conforms to `SyncTrackable` (`synced: Bool`, `updatedAt: Date`). A local write sets `synced = false`. `SyncService` later pushes all unsynced rows to Supabase and flips `synced = true`. Network loss never blocks the user.

**Data binding pattern.** Views declare SwiftData `@Query` properties (filtered by `userId`). On change, the View calls `viewModel.bind(...)`, which transforms raw models into display-ready state. VMs do not own the data — `@Query` does.

---

## 2. App Lifecycle & Navigation

State machine lives in [`AppState`](../Habfitise/App/AppState.swift):

```
authState: .loading → .authenticated(userId) | .unauthenticated | .error
```

Flow on launch:

1. **Auth** ([`AuthViewModel`](../Habfitise/Features/Auth/ViewModels/AuthViewModel.swift)) — sign in/up. On success → `setAuthenticated(userId:)`.
2. **Onboarding gate** — `setAuthenticated` checks `hasCompletedOnboarding`. Missing → route to onboarding. (Legacy users with an existing `UserProfile` are auto-migrated as "completed".)
3. **Onboarding** (if needed) → builds first plan → `finishOnboarding()`.
4. **Main tabs** — Home, Workout, Progress (tab bar in `MainTabView`).

`pendingNavigation` drives routing (`.home`, `.onboarding`, `.auth`, `.upgrade(trigger)`). `authenticatedUserId` is the single accessor every feature uses to scope its queries.

---

## 3. Onboarding

File: [`OnboardingViewModel`](../Habfitise/Features/Onboarding/ViewModels/OnboardingViewModel.swift)

4-step wizard (`step` 0…3, validated by `canContinue`):

| Step | Collects |
|------|----------|
| 0 | Welcome |
| 1 | Goal (`loseWeight` / `buildMuscle` / `improveFitness` / `buildHabits`) |
| 2 | Current + target weight, unit, timeline |
| 3 | Training weekdays, preferred time, equipment, daily water goal |

**Build plan** (`buildMyPlan`):
1. Assemble `WorkoutPlanRequest` from answers.
2. Call `EdgeFunctionService.generateWorkoutPlan` (remote, or local fallback via [`LocalWorkoutPlanGenerator`](../Habfitise/Core/EdgeFunctionService/LocalWorkoutPlanGenerator.swift)).
3. `saveOnboardingData` persists: a `UserProfile`, a first `WorkoutTemplate` (scheduled to the next selected weekday), a `WaterGoal`, and UserDefaults keys.
4. `syncService.syncAll(...)` → `appState.finishOnboarding()`.

Animated loading messages cycle on a cancellable `Task` during the build.

---

## 4. Home (Dashboard)

Files: [`HomeView`](../Habfitise/Features/Home/Views/HomeView.swift) · [`HomeViewModel`](../Habfitise/Features/Home/ViewModels/HomeViewModel.swift)

The aggregation screen. Pulls **10 `@Query` streams** (habits, tasks, water, templates, today's sessions, recent sessions, missed workouts, profile, water goal, body weight) and folds them into one snapshot via `bind(...)`.

**Sections rendered:**
- **Greeting** — time-of-day + profile name (`makeGreeting`).
- **Energy / mood selector** — 1–5 scale → writes `MoodCheckin` (see §9).
- **Today's workout card** — three modes resolved by `buildWorkoutCard`:
  - `.completed` — a session finished today → shows summary + "View details".
  - `.scheduled` — a template `isScheduledToday` → "Start Workout".
  - `.quickStart` — nothing scheduled → pick a type to log ad-hoc.
- **Habits row** — today's completion chips.
- **Tasks** — top 3 open tasks.
- **Water** — progress bar + tappable cups.
- **Streak stats** — `computeStreakStats`: weekly workouts, day streak, sessions logged, habits done.

`bind()` re-runs whenever any underlying `@Query` changes (habit/task/water/template/session edits) so the dashboard stays live.

---

## 5. Workout

The largest subsystem. Three distinct flows: **templates**, **building/logging a session**, and **missed-workout recovery**.

### 5.1 Data model ([`WorkoutModels.swift`](../Habfitise/Core/SwiftDataStack/WorkoutModels.swift))

```
WorkoutTemplate ──cascade──> ExerciseTemplate     (the plan)
WorkoutSession  ──(by id)──> ExerciseSet          (a logged instance)
MissedWorkout                                       (overdue, awaiting a decision)
PersonalRecord                                      (best-ever per exercise)
```

- **Template** = reusable plan (name, type, exercises, `estimatedMinutes`, `nextScheduledAt`, `repeatSchedule`).
- **Session** = one performed workout (`startedAt`/`completedAt`, `durationSeconds`, `totalVolumeKg`, optional `templateId`).
- **ExerciseSet** = one set (`reps`, `weightKg`, `durationSeconds`, `distanceKm`, `isWarmup`, `isPersonalRecord`); `volumeKg = weight × reps`.

`WorkoutType`: weights, cardio, bodyweight, HIIT, flexibility.

### 5.2 Building & logging a session ([`WorkoutBuilderViewModel`](../Habfitise/Features/Workout/ViewModels/WorkoutBuilderViewModel.swift))

Two phases: **`.setup` → `.active`**.

**Setup** — start blank, from a template, or resume an unfinished session. Add exercises from catalog / custom / cardio options, reorder, delete, and group two+ into a **superset**.

**Active session:**
- `startActiveSession` seeds `setStates` (optional warm-up + working sets), loads previous-session summaries, body weight, and volume hints. Starts a 1-second elapsed timer (`Task`).
- Per set: adjust reps/weight/duration/distance, toggle warm-up, then `completeSet`:
  1. Insert an `ExerciseSet` (offline-first).
  2. **PR check** — `checkForNewPR`; if beaten, insert `PersonalRecord`, flag the set, append to `sessionPRs`.
  3. Store estimated 1RM for weighted sets.
  4. **Superset logic** — jump to the paired exercise instead of resting if its matching set is pending.
  5. Otherwise start the **rest timer** (cancellable `Task`, haptic at 10s and on finish).
- **Cardio** exercises get a separate count-up timer.
- **Finish** (`prepareEndWorkout` → `finalizeWorkout`): build `WorkoutSession`, compute volume + estimated calories, persist. If repeat requested, set `template.nextScheduledAt`/`repeatSchedule` (or create a new template from the session). Reschedule/cancel the notification, then `syncAll`.

> Note: [`ActiveWorkoutViewModel`](../Habfitise/Features/Workout/ViewModels/ActiveWorkoutViewModel.swift) is an older, simpler single-exercise logging flow with the same shape (set → rest → PR detect → end). The Builder VM is the richer current path.

### 5.3 Missed workouts ([`MissedWorkoutService`](../Habfitise/Features/Workout/Services/MissedWorkoutService.swift))

- **Detection** — finds templates whose `nextScheduledAt` is in the past with no completed session that day and no existing pending record → inserts a `MissedWorkout(.pending)` + schedules a reminder.
- **Proactive prompt** — 8h after the scheduled time, surfaces a sheet (unless dismissed).
- **Resolution** — user picks:
  - **Push tomorrow** / **reschedule** → move `nextScheduledAt`, mark `.pushed`, reschedule reminder.
  - **Skip** → clear `nextScheduledAt`, mark `.skipped`, cancel reminder.

---

## 6. Habits

Files: [`HabitsViewModel`](../Habfitise/Features/Habits/ViewModels/HabitsViewModel.swift) · models `Habit` + `HabitCompletion`.

- **Habit** = recurring intention (name, frequency, reminder time, color).
- **HabitCompletion** = one tick on one date.

Workflow:
- **Complete today** (`completeHabit`) — guards against double-completion, inserts a `HabitCompletion`, recomputes streak. Returns a streak value when a **milestone** is hit (drives celebration UI).
- **Undo** (`undoHabitToday`) — deletes today's completion(s).
- **Streak** (`streakForHabit` in `SwiftDataStack`) — walks backward from today over the set of completion days; counts consecutive days (today optional — grace if not yet done today).
- **Week view** (`weekDays`) — Mon-start 7-day grid showing done/today/future per habit.
- **Create** (`saveHabit`) — trimmed name required.

Water lives alongside habits in the UI (cups/celebration) but is its own model — see §8.

---

## 7. Tasks

Files: [`TasksViewModel`](../Habfitise/Features/Tasks/ViewModels/TasksViewModel.swift) · model `TaskRecord` (named to avoid clashing with Swift's `Task`).

- A task has `title`, optional `dueDate`, `isComplete`, optional `recurrence`, optional `linkedHabitId`.
- **Bucketing** (`bind`) — sorts every task into:
  - **Today** — due before tomorrow.
  - **Upcoming** — due later.
  - **Someday** — no due date.
- **Sort order** — incomplete first, then by due date, then alphabetical.
- **Actions** — `completeTask` (sets complete + `markPendingSync`), `deleteTask` (confirm sheet), `rescheduleTask` (date picker), `saveTask`.
- Counts (`todayCount`, `totalOpenTasks`) feed badges on Home and the tab.

---

## 8. Water

Files: [`WaterViewModel`](../Habfitise/Features/Water/ViewModels/WaterViewModel.swift) · models `WaterLog`, `WaterGoal`.

- Each tap logs a `WaterLog` (cup ≈ 350 ml, or a smaller "drop" from Home).
- Daily total = sum of today's logs; goal from `WaterGoal` (fallback to UserDefaults / default).
- UI fills cups proportionally; hitting the goal triggers a celebration.
- `WaterGoal` also stores reminder window + interval for scheduled notifications.

---

## 9. Mood / Energy

Model `MoodCheckin` (`energyScore`, `moodScore`, optional wearable HRV / sleep). Logged from Home's 1–5 energy selector via `MoodDao`. On load, the initial value is resolved from HealthKit energy score → today's check-in → neutral default. Used for daily context and (future) plan adjustment.

---

## 10. Progress

Files: [`ProgressViewModel`](../Habfitise/Features/Progress/ViewModels/ProgressViewModel.swift) · `ProgressAnalytics`.

Pure analytics screen — reads everything, writes (almost) nothing. `bind(...)` computes:

| Metric | How |
|--------|-----|
| Workouts this month | Completed sessions in the current month interval. |
| Tasks completed | Count of `isComplete` tasks. |
| Weekly workout minutes | 7-bucket array, Mon-start, summed `durationSeconds/60`. |
| Habit completion rate | `completed ÷ expected` over active habits × 7 days. |
| Personal records | Fetched `PersonalRecord` rows, formatted. |
| Habit heatmap | Last **4 weeks (free)** / **10 weeks (Pro)** grid. |
| Water week | Per-day totals + daily average vs goal. |

**Export** (`exportFileURL`) — `generateCSV` writes every workout, set, habit, completion, task, and water log to a temp `.csv` for share-sheet export.

---

## 11. Sync Engine

File: [`SyncService`](../Habfitise/Core/SyncService/SyncService.swift)

- **Trigger points** — after finishing a workout, after onboarding, and automatically when the network returns (`NWPathMonitor`: offline → online edge fires `syncAll`).
- **Guards** — skips if `useLocalOnly`, already in flight, Supabase unconfigured, or no `userId`.
- **Push pipeline** — for each model type in dependency order (profile → sessions → sets → habits → completions → tasks → mood → water → goals): fetch unsynced rows → upsert in batches (`onConflict: "id"`) → mark `synced = true` → save.
- **Direction** — currently **push-only** (local → cloud backup). SwiftData remains the read source.
- `syncStatus` (`idle` / `syncing` / `error`) surfaces to the UI.

---

## 12. Pro Gating

`AppState.isPro` + `requireUpgrade(for:)` (RevenueCat via `PurchaseService`). Locked behind Pro:
- Extended habit heatmap (10 vs 4 weeks).
- AI daily plan generation.
- Other premium widgets/sections marked with a lock.

Triggering a gated feature sets `pendingNavigation = .upgrade(trigger)` to present the paywall.

---

## 13. Data Model Summary

All conform to `SyncTrackable` unless noted. Registered in `HabfitiseSwiftDataSchema`.

| Model | Purpose |
|-------|---------|
| `UserProfile` | Identity, goals, target weight, Pro flag. |
| `WorkoutTemplate` → `ExerciseTemplate` | Reusable plan (cascade-deletes exercises). |
| `WorkoutSession` → `ExerciseSet` | Performed workout + its sets. |
| `MissedWorkout` | Overdue scheduled workout awaiting a decision. |
| `PersonalRecord` | Best-ever value per exercise/type. |
| `BodyWeightEntry` | Logged body weight over time. |
| `Habit` → `HabitCompletion` | Recurring habit + daily ticks. |
| `TaskRecord` | To-do with optional due date / recurrence / habit link. |
| `MoodCheckin` | Energy/mood (+ optional wearable data). |
| `WaterLog` / `WaterGoal` | Hydration logs + daily target/reminders. |
| `ExerciseTemplate` | *(not synced — owned via template cascade)* |

---

*Generated from source review. Paths are clickable relative to `docs/`.*
