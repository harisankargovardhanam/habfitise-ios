# Habfitise iOS

Native iOS app — workout logger, habit tracker, task organiser, water intake, and AI daily planner.

## Stack

- SwiftUI + Swift 5.9+
- iOS 17+ minimum
- SwiftData (offline-first)
- Supabase Swift SDK (auth + sync)
- RevenueCat (Pro subscriptions)
- Firebase (FCM push) — **deferred**, see `Config/DEFERRED.md`
- HealthKit (Apple Watch / Health data)

## Project Structure

```
Habfitise/
├── App/                    AppState, routing types
├── Features/
│   ├── Auth/
│   ├── Onboarding/         4-step goal + schedule flow
│   ├── Home/
│   ├── Workout/
│   ├── Habits/
│   ├── Tasks/
│   ├── Water/
│   ├── Progress/
│   └── Settings/
├── Core/
│   ├── SupabaseClient/
│   ├── SwiftDataStack/
│   ├── HealthKitService/
│   ├── NotificationService/
│   ├── PurchaseService/
│   ├── SyncService/
│   └── EdgeFunctionService/
└── Shared/
    ├── Theme/
    ├── Components/
    ├── Extensions/
    └── Constants/
```

## Setup

1. Open `Habfitise.xcodeproj` in Xcode 16+
2. Copy `Config/Secrets.xcconfig.example` → `Config/Secrets.xcconfig` and fill keys:
   - `SUPABASE_URL` — use `https:/$()/your-project.supabase.co` (`//` alone breaks xcconfig)
   - `SUPABASE_ANON_KEY`
   - `REVENUECAT_API_KEY`
3. ~~Add `GoogleService-Info.plist`~~ (Firebase deferred — see `Config/DEFERRED.md`)
4. Set your Apple Development Team in project signing

## SPM Dependencies

| Package | URL | Product |
|---------|-----|---------|
| supabase-swift | https://github.com/supabase/supabase-swift | Supabase |
| purchases-ios | https://github.com/RevenueCat/purchases-ios | RevenueCat |

Firebase (FirebaseCore, FirebaseMessaging) deferred — see `Config/DEFERRED.md`.

See `Package.swift` for version pins.

## Regenerate Xcode Project

```bash
brew install xcodegen
xcodegen generate
```

## Routing

`ContentView` switches on app state:

1. `OnboardingView` — first launch
2. `AuthView` — onboarding complete, not signed in
3. `MainTabView` — authenticated main app

`AppState` (`@Observable`) holds `authState`, `isPro`, `syncStatus`, `pendingNavigation`.

## Design System

| Token | Value |
|-------|-------|
| Background | `#1A6B35` |
| Accent | `#22C55E` |
| Water | `#3B82F6` |
| Card | `#FFFFFF` |

Cards: 24pt top radius only. Bar charts: `Capsule()`. Tab bar: frosted glass inset pill.
