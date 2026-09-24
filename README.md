# 🛡️ Shield-Frame

**"Structure for Justice, Space for Safety"**

A Digital Evidence Vault app designed for women facing online harassment in Bangladesh. Shield-Frame provides a secure, encrypted framework to document screenshots, links, and timestamps of abuse in a format that is legally admissible and ready for police reporting.

## 🎯 DKC Fellowship — Theme: Gender-based Online Violence

### Core Features

- **📦 Secure Evidence Vault** — Biometric-locked, encrypted storage with auto-metadata extraction
- **📝 GD-Automator** — Generates legally-formatted General Diary complaints mapped to Bangladesh Cyber Security Act
- **🚨 Panic Frame** — One-touch emergency alert with GPS location + evidence pack to trusted contacts
- **🤝 Support Bridge** — Curated directory of pro-bono lawyers and mental health counselors

### Tech Stack

- **Framework:** Flutter + Dart
- **Architecture:** MVVM (Model-View-ViewModel)
- **Database:** SQLite with SQLCipher encryption
- **Auth:** Biometric (fingerprint/face) + PIN
- **Security:** AES-256 encryption, SHA-256 evidence hashing, app disguise mode

### Project Structure

```
shield_frame/
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
cd shield_frame
flutter pub get
flutter run
```

### Impact

> *64% of Bangladeshi women face digital violence. Most cases go unreported because evidence is lost, legal processes are intimidating, and support is hard to find. Shield-Frame changes that.*

---

**Team:** [Your Team Name]  
**DKC Fellowship Application — UNDP Bangladesh**