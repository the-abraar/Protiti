# 🛡️ Protiti (প্রতীতি)

**"সন্দেহহীন সত্য, অকাট্য প্রমাণের অধিকার"**  
*"From Doubt to Certitude: Structure for Digital Justice"*

> **Note:** "Protiti" (প্রতীতি - Deep Conviction & Undisputed Certitude) is the official brand identity. Rooted in Bengali epistemology and cultural resonance, Protiti establishes indisputable digital evidence for women facing online harassment in Bangladesh. See [`team_handoffs/design_handoff.md`](team_handoffs/design_handoff.md) for the brand identity and verified uniqueness audit.

A Digital Evidence Vault app designed for women facing online harassment in Bangladesh. Protiti stores screenshots, photos, recordings and notes encrypted on the phone and lists them, with the SHA-256 of each original, in a GD draft PDF for police reporting. No lawyer has reviewed whether the output is admissible.

## 🎯 DKC Fellowship — Theme: Gender-based Online Violence

### Core Features

- **📦 Secure Evidence Vault** — PIN-locked, encrypted storage with a **Duress PIN (Decoy Vault)** for physical coercion scenarios. Fingerprint unlock is opt-in.
- **📝 GD-Automator** — Builds an offline GD draft PDF from the evidence she chooses. No AI, no network call.
- **🚨 Panic Frame** — SMS SOS to the trusted contacts she adds, with the real per-recipient sent and delivered result and a Call 999 button when sending fails. See [SOS](#sos) below.
- **🤝 Support Bridge** — Curated directory of pro-bono lawyers and mental health counselors

### Tech Stack

- **Framework:** Flutter + Dart
- **Architecture:** MVVM (Model-View-ViewModel)
- **Database:** SQLite with SQLCipher encryption
- **Auth:** 6-10 digit PIN with escalating lockout; fingerprint/face opt-in (biometric only, never the phone PIN)
- **Security:** AES-256-GCM evidence files in 64 KiB authenticated chunks (older AES-CTR files are rewritten on first open); SHA-256 of each original file or note text, taken before any processing; the app only ever opens as a working calculator

### Project Structure

```
dkc/
└── lib/
    ├── data/
    │   ├── models/         # DB/API models
    │   ├── repositories/   # Data access layer
    │   └── services/       # Encryption, biometric, location, database
    ├── domain/
    │   ├── models/         # Evidence, Complaint, Contact, SupportProvider, UserProfile
    │   └── use_cases/      # GD generation, panic trigger
    └── ui/
        ├── core/theme/     # Dark mode theme (Navy #0A1128, Blue #1282A2, Amber #FFC857)
        └── features/
            ├── auth/       # Calculator (the only lock screen) + code setup
            ├── vault/      # Evidence vault with 4-tab navigation
            ├── complaint/  # GD-Automator wizard
            ├── panic/      # Panic Frame emergency button
            └── support/    # Support Bridge directory
```

### Owner TODOs before any real use

- Release keystore (the release build is signed with the debug key).
- Test on a real Android phone with a SIM: SOS with credit, without credit and in airplane mode; Recents thumbnail; wipe.
- On real Android phones (one each of Xiaomi, Oppo, Vivo, Realme if possible), with the app swiped away: power-button and shake SOS, the 5 s Cancel, the buzz patterns, the result and delivery notice, the second-PIN alert; shake thresholds on a rickshaw/CNG ride and in a bag; a call with the phone at the ear must not trigger. Then check each battery-guide deep link opens.
- Verify any hotline other than 999 and 109 (PCSW, NGOs, campus numbers) with the service itself before listing it. The GD PDF uses `cybersupport.women@police.gov.bd`, the address on the police portal.
- Decide whether to add an "export original file" option. Today the original stays only in the encrypted vault (and, for gallery imports, in her gallery), so nobody else can recompute a SHA-256 the PDF lists.
- Add a siren sound at `assets/audio/siren.mp3`; the siren button plays nothing until then.
- Pick a neutral `applicationId` / bundle ID before the first store upload; `com.protiti.protiti` shows in Android App info and cannot change once published.
- On a real phone: check the launcher icon and label, Recents, App info and the permission prompts in English and Bangla.

### The calculator disguise

- The app always opens as a calculator that really works. She gets in by typing a code and pressing `=`; holding `=` asks for a fingerprint only if she turned that on. A wrong code shows nothing.
- Setup shows once, on the first launch after she installs it. After the wipe code the app stays a plain calculator for good on that install; uninstalling and reinstalling starts fresh.
- Launcher, Recents, App info and the iOS home screen say "Calculator" (Bangla "ক্যালকুলেটর" on Android) with a plain calculator icon. Permission prompts are neutral but honest ("Used to attach photos to your notes").
- No icon or name switching at runtime. On iOS, `setAlternateIconName` always shows a system alert, which would draw attention. On Android, switching launcher `activity-alias` entries with `PackageManager.setComponentEnabledSetting` can remove her home-screen shortcuts. One fixed calculator face avoids both.
- What to tell Apple and Google reviewers, without putting any hidden-feature text in the app: [`STORE_REVIEW.md`](STORE_REVIEW.md).

### SOS

- In the app: hold the SOS button 3 s, then 5 s to Cancel (or Send now). The SMS goes out silently on Android; on iOS the Messages sheet opens and she presses Send. If the screen goes away during the 5 s (screen off, another app, another tab), it sends at once by silent SMS, buzzes the result, and the SOS tab shows it later; on iOS that silent send cannot happen, so the SOS tab says it was not sent.
- Android only, each off by default and turned on in Settings after an explanation: power button pressed 4 times within 3 s (ignored during a call), and hard shaking (4 peaks over 3 g within 3 s). Each waits 5 s first: two short buzzes and a notice with Cancel. One long buzz means every text was accepted, three long buzzes mean not; the notice gives the count, delivery reports and a Call 999 button. The service runs only while a trigger is on and does not restart after a reboot until she opens the app.
- Second PIN (opt-in, off by default): opening with it sends the SOS silently, with no notice, buzz, recording or cancel window. The real SOS tab later shows whether it went.
- iOS cannot run background triggers or send SMS silently, so Settings hides those switches there and says why.
- The text is Bangla and English, names no app and fits in 2 SMS parts: `জরুরি! সাহায্য দরকার। Urgent, help me! অবস্থান/Location 09:30: https://maps.google.com/?q=…`. Android may keep a copy in the Messages app's Sent folder; Settings says so.
- SMS goes through the local `hardware_sos` plugin (`SmsSender.kt`), which Flutter registers on every engine, the background service's included. Battery savers on Xiaomi, Oppo, Vivo and Realme can stop the service; Settings > Keep SOS shortcuts working has the steps and deep links.

### Getting Started

```bash
cd protiti
flutter pub get
flutter run
```

### Impact

> *64% of Bangladeshi women face digital violence. Most cases go unreported because evidence is lost, legal processes are intimidating, and support is hard to find. Protiti changes that.*

---

**Team:** [Your Team Name]  
**DKC Fellowship Application — UNDP Bangladesh**