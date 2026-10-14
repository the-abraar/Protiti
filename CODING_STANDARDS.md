# Coding standards (review rules)

- No hard-coded secrets, PINs or keys; anything sensitive goes through secure storage and is hashed or encrypted.
- Real and decoy data never share a file, key or table. Decoy mode must not reveal that a real vault exists.
- UI and error text must not mention the vault, duress or wipe in the disguise paths.
- Claims in README, docs and UI (legal admissibility, accuracy, statistics, integrations) need a source or softer wording.
- New logic with a branch or security effect gets a test in `dkc/test/`.
- Guard `BuildContext` use after `await` with `mounted`; do not add `print` in `lib/`.
- `scripts/check.sh` must pass before finishing; never commit build output or `.DS_Store`.
