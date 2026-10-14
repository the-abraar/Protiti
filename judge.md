# Protiti: go-to-market judge

Scored 2026-10-14 from the README, `team_handoffs/` (including the Sep 25 `judge_critique.md`), `legal/`, a code grep and the git log. I did not run the app, the tests or CI. Treat the score as +/- 10 points.

## Verdict

**12%, cap 12.** A Flutter prototype of an evidence vault for women facing online harassment in Bangladesh, built for the DKC Fellowship application. It is a safety product for people at physical risk, and nothing shows it has run on a real phone, been security-reviewed or been used by a survivor.

## What exists

- Flutter app (`dkc/lib`): lock screen with calculator disguise, real and duress PINs with a decoy vault, evidence vault, GD-Automator complaint wizard, panic screen (3-second hold, SMS with location), support directory.
- `legal/`: Cyber Protection Act 2026 guide, e-GD schema mapping, GD template, legal-aid partnership framework (documents, not signed agreements).
- Pitch deck, website mockups, team handoffs. Git history exists; last commit 2026-10-06.
- Tests: three files (`auth_service_test`, `encryption_service_test`, `widget_test`). The CI workflow pins Flutter 3.19.x, but `pubspec.yaml` needs Dart `^3.12.2`, so CI likely cannot resolve; it has not been checked.

## Gaps (ranked)

1. **Never tested on a device or with a survivor.** No usability test, no real-phone SMS or GPS test, no check of the disguise on a real handset.
2. **Hard-coded default PINs** `1234` and `9999` in `lib/data/services/auth_service.dart`. The Sep 25 critique's on-screen "Demo PIN" card and "DECOY MODE" banner no longer appear in `lib` (grep). Whether the PINs are forced to change at first run is unverified.
3. **Decoy isolation unverified.** The critique found real and decoy data in one SQLite table. Whether that was fixed is not confirmed ("segregated decoy storage" is claimed in the handoff).
4. **No security review** of the encryption, key handling or panic flow. Agent-written, no human review.
5. **Legal claims unverified.** "Legally admissible", the Cyber Protection Act 2026 mapping and the Section 65B points have no counsel review. The e-GD "Live API" was called a myth in the critique; the README still says "designed for direct e-GD API integration".
6. **Market validation is zero.** BLAST and BNWLA appear in a framework document; no partner has agreed to anything.
7. **Claims honesty:** "hallucination-free" AI triage, the "Jev" engine and the 64% statistic are unsourced here. Docs and the README name different brands, PINs and folders (`protiti/` vs `dkc/`).
8. **No `AGENTS.md`, `CODING_STANDARDS.md` or `scripts/check.sh`**, so there is no single gate.

## Scores (0-10)

| Dimension (weight) | Score |
|---|---|
| Product works (25) | 4 |
| Quality and verification (15) | 3 |
| Security and privacy (15) | 3 |
| Legal and compliance (10) | 4 |
| Market validation (15) | 2 |
| Deploy and operations (10) | 1 |
| Claims honesty (10) | 4 |
| **Weighted** | **31** |
| **Cap** | **12** (safety product with unreviewed crypto, never run on a device) |
| **Final** | **12** |

## Next steps, in order

1. **You:** decide whether this continues after the fellowship outcome. Nobody is waiting on it today.
2. **You:** run it on one real Android phone; check the disguise, both PINs, the panic SMS and the PDF export.
3. **Code:** force a PIN change at first run; confirm decoy and real data use separate stores; add `scripts/check.sh`, `AGENTS.md` and `CODING_STANDARDS.md`; fix the CI Flutter version.
4. **You:** talk to one legal-aid organisation or survivor-support worker before more features; get counsel to review the legal claims.
5. **You:** get a human security review of the encryption and panic code before anyone real uses it.
6. Remove or soften unverifiable claims in the README and pitch.

## Update 1 (2026-10-14, agent round, pushed `f4f16bf` to `jev_int`)

Done (agent-made; `scripts/check.sh` passes locally on Flutter 3.44.9: analyze, 7 tests): default PINs 1234 and 9999 removed; first launch requires a 4-digit real PIN and a different duress PIN, and no PIN unlocks before setup; PINs stored as salted SHA-256 hashes (they were plaintext); real and decoy data were already in separate files with separate keys; README claims fixed; CI Flutter pinned to 3.44.x; `AGENTS.md`, `CODING_STANDARDS.md` and `scripts/check.sh` added.
**Weaker than it looks:** CI lost its format step and runs analyze with `--no-fatal-infos` because both failed on existing code. The decoy test compares table names only. A 4-digit PIN hash can be brute-forced offline.
**Not verified:** the PIN setup screen on a device; CI on GitHub. Not merged to `main`. Score unchanged at 12% (cap).
