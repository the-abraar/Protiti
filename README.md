> **Research prototype. Not for real use: unsafe for survivors until reviewed by a security expert and a field partner.**

# Protiti (প্রতীতি)

**"সন্দেহহীন সত্য, অকাট্য প্রমাণের অধিকার"**
*"From Doubt to Certitude: Structure for Digital Justice"*

"Protiti" (প্রতীতি, "deep conviction") is the project name. See [`team_handoffs/design_handoff.md`](team_handoffs/design_handoff.md) for the brand identity.

A prototype evidence vault for women facing online harassment in Bangladesh. It stores screenshots, photos and notes in an encrypted vault and drafts a General Diary (GD) text for manual filing. It is not legal advice, and no lawyer has reviewed whether its output is admissible.

## DKC Fellowship: Gender-based Online Violence

### Features

- **Calculator disguise.** The app opens as a working calculator. Your PIN unlocks it.
- **Encrypted vault.** Photos, screenshots, recordings and notes on the phone, the files AES-256-GCM encrypted and the records in an SQLCipher database. Each item keeps the SHA-256 of the original file (or note text) taken before anything else touches it, its source, the phone-clock time and an optional platform and link. Nothing is uploaded.
- **PINs.** A real PIN (6 or more digits, set at first launch), a duress PIN that opens a separate decoy vault, and an optional wipe code that you choose. Codes must differ in at least 3 digits, so one slip cannot turn one into another.
- **Biometrics.** Off by default. When turned on, fingerprint or face only (no device-PIN fallback).
- **GD draft.** A guided form that makes a PDF draft for you to file in person. There is no e-GD API integration and no automatic law mapping.
- **Panic screen.** One SMS SOS with your location to your saved contacts (contact setup is a known gap), plus one-tap dialing for 999 and the 109 helpline.
- **Support directory.** A static list of support organisations. Their phone numbers are hidden until each organisation confirms them. No organisation has agreed to a partnership.

Cut from this prototype (unsafe, fake or unverified): the AI classifier, cloud backup, cloud SMS and certificate pinning, the geofence, root detection and self-wipe, P2P and Bluetooth transfer, sensor telemetry in the SOS, the proximity lock, fake notifications and calls, the thermal decoy, the 5-tap crash and the online decoy fetch.

Known gaps are in [`judge.md`](judge.md) and [`CrtiQue_Oct14.md`](CrtiQue_Oct14.md).

### Tech stack

- **Framework:** Flutter + Dart
- **Database:** SQLite with SQLCipher encryption; real and decoy vaults use separate files and keys
- **Auth:** salted PIN hashes in secure storage; optional biometric-only unlock
- **Security:** AES-256-GCM evidence files (authenticated, streamed in chunks), SHA-256 of each original, calculator disguise. Not reviewed by a security expert.

### Project structure

```
dkc/
└── lib/
    ├── data/
    │   ├── repositories/   # Data access layer
    │   └── services/       # Encryption, auth, location, database
    ├── domain/
    │   ├── models/         # Evidence, Complaint, Contact, SupportProvider, UserProfile
    │   └── use_cases/      # GD generation, panic trigger
    └── ui/
        ├── core/theme/
        └── features/
            ├── auth/       # Lock screen, calculator disguise, PIN setup
            ├── vault/      # Evidence vault
            ├── complaint/  # GD draft wizard
            ├── panic/      # Panic screen
            └── support/    # Support directory
```

### Getting started

```bash
cd dkc
flutter pub get
flutter run
```

Run `scripts/check.sh` before you commit.

---

**Team:** Team Protiti (see `pitch_materials/pitch_deck.md`)
**DKC Fellowship application, UNDP Bangladesh**
