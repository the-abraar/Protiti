# AGENTS.md

- Flutter app is in `dkc/`; run everything from there. `scripts/check.sh` runs pub get, analyze, test and a stray-file check. No pre-commit hook (analyze has known info-level lints).
- Flutter 3.44.x / Dart ^3.12.2 (`dkc/pubspec.yaml`); CI in `.github/workflows/flutter_ci.yml` must stay in step.
- PINs: no defaults. First launch shows `pin_setup_screen.dart`; `AuthService` stores salted SHA-256 hashes in secure storage. `0000` is the reserved wipe PIN. Calculator disguise unlocks via `AuthService.matchPin` (no attempt counting).
- Real and decoy vaults are separate SQLCipher files with separate keys and table names (`database_service.dart`). Emergency contacts live only in the real DB.
- Unit tests have no secure-storage plugin; `AuthService` falls back to an in-memory map.
- Do not commit `build/`, `.dart_tool/` or `.DS_Store`. Do not edit `judge.md`; it holds status and gaps.
