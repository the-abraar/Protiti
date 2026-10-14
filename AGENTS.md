# AGENTS.md

- Flutter app is in `dkc/`; run everything from there. `scripts/check.sh` runs pub get, analyze, test and a stray-file check. No pre-commit hook (analyze has known info-level lints).
- Flutter 3.44.x / Dart ^3.12.2 (`dkc/pubspec.yaml`); CI in `.github/workflows/flutter_ci.yml` must stay in step.
- PINs: no defaults and no reserved code. First launch shows `pin_setup_screen.dart`: she picks a real PIN, a second (duress) PIN and a wipe code, 6-10 digits each, all typed twice; Settings > Change codes needs the current real PIN. A forgotten PIN cannot be recovered. `AuthService` stores salted SHA-256 hashes in secure storage under neutral key names (`secure_store.dart`; old names are migrated at launch).
- Keypad and calculator both unlock only through `AuthService.verifyPin`: a persisted miss counter with escalating delays (30 s to 1 h) on a monotonic clock, no wall clock or NTP. The calculator fails silently. Biometrics are opt-in and `biometricOnly`.
- The wipe (her wipe code, in either mode) closes both DBs, deletes the keys, both DB files with `-wal`/`-journal`/`-shm`, every evidence file (`.enc`, plus legacy `.bin`/`.tmp`/`.enc_audio` and plaintext `.m4a`) and the temp dir, then opens on a blank calculator.
- Real and decoy vaults are separate SQLCipher files with separate keys and table names (`database_service.dart`). Emergency contacts live only in the real DB.
- Tests have no platform plugins: `dkc/test/helpers/fakes.dart` mocks the secure-storage, path_provider and sqflite channels. Secure-storage errors propagate (fail closed); there is no in-memory fallback.
- Do not commit `build/`, `.dart_tool/` or `.DS_Store`. Do not edit `judge.md`; it holds status and gaps.
