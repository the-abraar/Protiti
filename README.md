# 🛡️ Protiti (প্রতীতি)

**"সন্দেহহীন সত্য, অকাট্য প্রমাণের অধিকার"**  
*"From Doubt to Certitude: Structure for Digital Justice"*

> **Note:** "Protiti" (প্রতীতি - Deep Conviction & Undisputed Certitude) is the official brand identity. Rooted in Bengali epistemology and cultural resonance, Protiti establishes indisputable digital evidence for women facing online harassment in Bangladesh. See [`team_handoffs/design_handoff.md`](team_handoffs/design_handoff.md) for the brand identity and verified uniqueness audit.

A Digital Evidence Vault app designed for women facing online harassment in Bangladesh. Protiti provides a secure, encrypted framework to document screenshots, links, and timestamps of abuse in a format that is legally admissible and ready for police reporting.

## 🎯 DKC Fellowship — Theme: Gender-based Online Violence

### Core Features

- **📦 Secure Evidence Vault** — Biometric-locked, encrypted storage with a **Duress PIN (Decoy Vault)** for physical coercion scenarios
- **📝 GD-Automator** — Uses TypeSafe's "Jev" AI to map data to the **Cyber Protection Act 2026** and designed for direct **Bangladesh Police e-GD API** integration
- **🚨 Panic Frame** — Offline-first SOS alert with SMS fallback for low-connectivity environments
- **🤝 Support Bridge** — Curated directory of pro-bono lawyers and mental health counselors

### Tech Stack

- **Framework:** Flutter + Dart
- **Architecture:** MVVM (Model-View-ViewModel)
- **Database:** SQLite with SQLCipher encryption
- **AI Engine:** TypeSafe AI "Jev" (System One) for fast, hallucination-free legal triage
- **Auth:** Biometric (fingerprint/face) + PIN
- **Security:** AES-256 encryption, SHA-256 evidence hashing, app disguise mode

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
    │   └── use_cases/      # GD generation, evidence packaging, panic trigger
    └── ui/
        ├── core/theme/     # Dark mode theme (Navy #0A1128, Blue #1282A2, Amber #FFC857)
        └── features/
            ├── auth/       # Lock screen + calculator disguise
            ├── vault/      # Evidence vault with 4-tab navigation
            ├── complaint/  # GD-Automator wizard
            ├── panic/      # Panic Frame emergency button
            └── support/    # Support Bridge directory
```

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