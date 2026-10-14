# 🛡️ Protiti (প্রতীতি)

**"সন্দেহহীন সত্য, অকাট্য প্রমাণের অধিকার"**  
*"From Doubt to Certitude: Structure for Digital Justice"*

> **Note:** "Protiti" (প্রতীতি - Deep Conviction & Undisputed Certitude) is the official brand identity. Rooted in Bengali epistemology and cultural resonance, Protiti establishes indisputable digital evidence for women facing online harassment in Bangladesh. See [`team_handoffs/design_handoff.md`](team_handoffs/design_handoff.md) for the brand identity and verified uniqueness audit.

A Digital Evidence Vault app designed for women facing online harassment in Bangladesh. Protiti provides a secure, encrypted framework to document screenshots, links, and timestamps of abuse in a format that is legally admissible and ready for police reporting.

## 🎯 DKC Fellowship — Theme: Gender-based Online Violence

### Core Features

- **📦 Secure Evidence Vault** — PIN-locked, encrypted storage with a **Duress PIN (Decoy Vault)** for physical coercion scenarios. Fingerprint unlock is opt-in.
- **📝 GD-Automator** — Builds an offline GD draft PDF from the evidence she chooses. No AI, no network call.
- **🚨 Panic Frame** — SMS SOS to the trusted contacts she adds, with the real per-recipient result and a Call 999 button when sending fails
- **🤝 Support Bridge** — Curated directory of pro-bono lawyers and mental health counselors

### Tech Stack

- **Framework:** Flutter + Dart
- **Architecture:** MVVM (Model-View-ViewModel)
- **Database:** SQLite with SQLCipher encryption
- **Auth:** 6-10 digit PIN with escalating lockout; fingerprint/face opt-in (biometric only, never the phone PIN)
- **Security:** AES-256 encryption, SHA-256 evidence hashing; the app only ever opens as a working calculator

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
- Verify any hotline other than 999 and 109 (PCSW, NGOs, campus numbers) with the service itself before listing it.
- Add a siren sound at `assets/audio/siren.mp3`; the siren button plays nothing until then.
- Pick a neutral `applicationId` / bundle ID before the first store upload; `com.protiti.protiti` shows in Android App info and cannot change once published.
- On a real phone: check the launcher icon and label, Recents, App info and the permission prompts in English and Bangla.

### The calculator disguise

- The app always opens as a calculator that really works. She gets in by typing a code and pressing `=`; holding `=` asks for a fingerprint only if she turned that on. A wrong code shows nothing.
- Setup shows once, on the first launch after she installs it. After the wipe code the app stays a plain calculator for good on that install; uninstalling and reinstalling starts fresh.
- Launcher, Recents, App info and the iOS home screen say "Calculator" (Bangla "ক্যালকুলেটর" on Android) with a plain calculator icon. Permission prompts are neutral but honest ("Used to attach photos to your notes").
- No icon or name switching at runtime. On iOS, `setAlternateIconName` always shows a system alert, which would draw attention. On Android, switching launcher `activity-alias` entries with `PackageManager.setComponentEnabledSetting` can remove her home-screen shortcuts. One fixed calculator face avoids both.
- What to tell Apple and Google reviewers, without putting any hidden-feature text in the app: [`STORE_REVIEW.md`](STORE_REVIEW.md).

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