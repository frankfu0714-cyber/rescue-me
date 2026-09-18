# Rescue Me

A native iOS app that fakes an incoming phone call so you can escape awkward conversations, bad dates, or meetings you'd rather not be in.

## Build

```bash
xcodegen generate   # regenerate .xcodeproj after any project.yml changes
```

Open `RescueMe.xcodeproj` in Xcode, select an iPhone simulator, and run.

Requires Xcode 16+, iOS 17+ deployment target. No third-party dependencies.

---

## Delivery Mechanism

Two layers work together for maximum reliability:

### Primary — CallKit `CXProvider.reportNewIncomingCall` ✅
When the scheduled timer fires, the app calls `CallKitService.shared.reportIncomingCall(from:)`. This hands the call to the system:

| Phone state | Result |
|---|---|
| **Locked** | Full-screen native incoming call UI — looks exactly like a real call |
| **Unlocked** | Compact banner at top + our custom `FakeIncomingCallView` full-screen |

The app answers the CallKit call in `CXProviderDelegate` and transitions to `FakeInCallView`.

**Requirements already set:** `UIBackgroundModes: [voip, audio]` in `Info.plist`. No special entitlements needed (we are NOT using PushKit/VoIP push, only the local `reportNewIncomingCall` API).

### Fallback — Local Notification
A `UNTimeIntervalNotificationTrigger` is scheduled simultaneously with the countdown. If the app is suspended before the timer fires (e.g., user force-quit), the notification fires and the tap handler calls `triggerCallFromNotification(...)`.

---

## Known App Store Risks

| Guideline | Risk | Mitigation |
|---|---|---|
| **4.1** — Safety | Deceptive UI that impersonates a real incoming call | None; this is the core feature. Review outcome is uncertain. |
| **4.3** — Spam | Misuse of CallKit (VoIP API for fake calls) | Several approved apps do this. Framing as "prank / rescue" may help. |

Recommend submitting to App Store Review *after* v1 is polished. Apple has approved similar apps (Fake-A-Call, Fake Call Plus) — no guarantee but precedent exists.

---

## Screen Flow

```
Contacts Grid
  → (tap contact) → Schedule Modal
      delay: 5s / 30s / 1min / 3min / 5min / Custom wheel
      audio: Silence / Mumble / Ambient
  → Countdown banner ("Call from Mom in 28s…")
  → FakeIncomingCallView  ← (CallKit lock-screen or custom full-screen)
      Decline → idle
      Accept  → FakeInCallView
          [duration timer] [mute/keypad/speaker/+/FaceTime/contacts buttons]
          End Call → idle
```

---

## Audio Modes

| Mode | What plays |
|---|---|
| **Silence** | Nothing |
| **Mumble** | Pink noise synthesized with Kellett approximation — sounds like a distant muffled voice |
| **Ambient** | Low-pass filtered white noise — quiet background atmosphere |

All audio is synthesized on-device via `AVAudioEngine`. No bundled audio files, no network.

The **ringtone** is a synthesized dual-tone (440 Hz + 480 Hz) that matches the classic North American PSTN ring, with soft attack/release envelope. Pattern: 2 s ring, 4 s silence, loop.

---

## Architecture

```
RescueMe/
├── Models/
│   ├── Contact.swift        — Codable struct, photo stored in Documents/ContactPhotos/
│   └── AudioMode.swift      — enum: silence | mumble | ambient
├── Services/
│   ├── AppState.swift       — @Observable singleton: contacts, call phase, countdown
│   ├── CallKitService.swift — CXProvider wrapper; onAnswer/onDecline callbacks
│   ├── NotificationService.swift — UNUserNotificationCenter scheduling
│   ├── AudioService.swift   — AVAudioEngine ringtone + noise synthesis
│   └── HapticsService.swift — AudioServices vibration pattern
└── Views/
    ├── ContactsGridView.swift
    ├── ContactCard.swift
    ├── ScheduleModalView.swift
    ├── FakeIncomingCallView.swift   ← money shot
    ├── FakeInCallView.swift
    ├── AddEditContactView.swift
    └── SettingsView.swift
```

---

## v0 → v1 ideas

- Home Screen widget for one-tap scheduling
- Shake to trigger
- Apple Watch complication
- Siri Shortcut
- Real bundled audio clips (professional mumble / ambient recordings)
- Custom ringtone library
