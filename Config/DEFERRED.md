# Deferred integrations

## Firebase / FCM push (re-enable before production)

**Status:** Disabled for local dev. Not required for auth, sync, or local notifications.

**When app is ready for remote push:**

1. Re-add Firebase SPM in `project.yml`:
   - Package: `https://github.com/firebase/firebase-ios-sdk` (from 11.0.0)
   - Products: `FirebaseCore`, `FirebaseMessaging`
2. Run `xcodegen generate`
3. Add `GoogleService-Info.plist` to `Habfitise/` target
4. Restore `aps-environment` in `Habfitise/Habfitise.entitlements` and `project.yml`
5. Restore `AppDelegate` + FCM wiring in `HabfitiseApp.swift` (see git history)
6. Restore FCM token fetch in `NotificationService.registerForRemoteNotifications()`
7. Wire `UserProfile.fcmToken` → Supabase on token refresh
8. Backend: send pushes via FCM using stored tokens

**Reminder:** Ask in chat: *"Re-enable Firebase push for Habfitise"*

---

## Apple Developer capabilities (Personal Team → Paid Program)

**Status:** Disabled so free Personal Team can sign & run on device.

Personal teams **cannot** use:
- Sign In with Apple
- HealthKit
- Push notifications (remote)

**When enrolled in Apple Developer Program ($99/yr):**

1. Set `AppConstants.Capabilities.signInWithApple = true` and `healthKit = true`
2. Restore in `project.yml` entitlements properties:
   ```yaml
   properties:
     com.apple.developer.healthkit: true
     com.apple.developer.applesignin:
       - Default
   ```
3. Run `xcodegen generate`
4. Re-add `aps-environment: development` when enabling Firebase push
5. Enable capability in [Apple Developer portal](https://developer.apple.com) for App ID `com.habfitise.app`

**Reminder:** Ask in chat: *"Re-enable Apple capabilities for Habfitise"*

---

## RevenueCat / Pro subscriptions (optional for dev)

**Status:** Skipped when `REVENUECAT_API_KEY` empty or placeholder in `Config/Secrets.xcconfig`.

App runs fine without it — `isPro` stays false, upgrade sheets still show.

**When ready for subscriptions:**

1. Add real public SDK key to `Config/Secrets.xcconfig`
2. Configure products + entitlement `pro` in RevenueCat dashboard
3. Test restore / purchase on device

**Reminder:** Ask in chat: *"Configure RevenueCat for Habfitise"*

---

## Local-only mode (current)

**Status:** `AppConstants.Backend.useLocalOnly = true` — SwiftData on device only. No Supabase auth, sync, or edge functions.

**To re-enable Supabase later:** set `useLocalOnly` to `false` in `AppConstants.swift`, then deploy edge functions and configure auth.

---

## Edge Function `habfitise-plan-generator` (404 on Build my plan)

**Status:** iOS app falls back to a **local stub plan** when Supabase returns 404 (function not deployed).

**Deploy to Supabase (real AI plan later):**

```bash
cd /Users/hari/Desktop/Repo/habfitise-ios
supabase login
supabase link --project-ref rphskgqyqmeejargbxab
supabase functions deploy habfitise-plan-generator
```

Function stub lives at `supabase/functions/habfitise-plan-generator/index.ts`.

Dashboard: **Edge Functions** → confirm `habfitise-plan-generator` exists.

iOS calls: `habfitise-plan-generator` (`AppConstants.EdgeFunctions.planGenerator`).

**Reminder:** Ask in chat: *"Deploy Habfitise edge functions"*
