# Protiti: independent critique (2026-10-15)

Reviewer stance: senior engineer, product and go-to-market. Scope: the worktree on branch `oct14-int` at `1aa6782` (41 commits ahead of `origin/jev_int`, 74 ahead of `origin/main`, **not pushed**). I read `AGENTS.md`, `CODING_STANDARDS.md`, both READMEs, `judge.md` (last section first), `todo.md`, `DKC.md`, `demo_script.md`, `dkc/STORE_REVIEW.md`, `legal/`, the website and pitch. I then read all of `dkc/lib/**`, `dkc/packages/hardware_sos/**` (Dart and Kotlin) and `dkc/android/**`, plus the iOS `Info.plist` and `AppDelegate.swift`.

What I ran, all on a copy of `dkc/` in the session scratchpad (the lockfile stayed unchanged):
- `flutter analyze --no-fatal-infos`: 3 infos (deprecated `withOpacity`), 0 errors or warnings.
- `flutter test`: **107/107 pass**.
- Kotlin JVM tests `:hardware_sos:testDebugUnitTest`: **6/6 pass**.
- `flutter build apk --debug`: builds. `flutter build apk --release --split-per-abi`: failed once after the debug build (stale plugin registrant, see N26), then built after `flutter clean`: arm64 27.0 MB, armv7 23.3 MB. The merged release manifest has **no INTERNET permission**.
- Six probe tests of my own (scratch only, listed in section 9). All six reproduced a bug.
- Viewport screenshots of `website/index.html` at 375x812 and 1280x800.
- Web searches for the law, competitors and Play policy (sources at the end of section 12).

I did not run the app on a phone or simulator. Nothing here was seen on real hardware.

"Confirmed" means I traced the code path end to end or reproduced it. "Suspected" means the code is as described, but the effect depends on device or OS behaviour I did not run.

---

## 0. Since 2026-10-14

The fix round was large and mostly real. I checked each item in the code, not in commit messages. New problems from the fix round are numbered N1-N30 in section 3.

### 0.1 Baseline bugs B1-B26

| # | Baseline finding | Status | Evidence |
|---|---|---|---|
| B1 | Fake evidence and placeholder SOS contacts seeded; no contact or delete UI | **Fixed** | No real-vault seeding: `database_service.dart:114-121`. Old seeds removed by the v2 upgrade: `:105-110`. Contacts add, edit, delete and test SMS: `contacts_screen.dart:40-91`. Evidence delete with confirmation: `vault_screen.dart:407-425`. She picks the PDF items: `complaint_wizard_screen.dart:29, 83-86`. |
| B2 | Decoy banner "Showing 3 innocent decoy files"; different chrome | **Fixed**, but see N3 | The banner is gone. The chrome is shared: `vault_screen.dart:75-128`. The test regex checks "decoy/vault/duress" in en and bn (`vault_screen_test.dart:18`). The decoy still shows the brand name in its title (N3). |
| B3 | Fingerprint button accepted the phone PIN and opened the real vault | **Fixed** | `biometricOnly: true`: `biometric_service.dart:12`. Off by default and enabled only after a successful scan: `auth_service.dart:127-138`. Only a long press on `=`: `lock_screen.dart:312`. |
| B4 | Calculator skipped the lockout; NTP lockout; 4-digit PINs | **Fixed**, two new holes | `=` goes through `verifyPin`: `lock_screen.dart:176-180` → `auth_service.dart:104-124`. Monotonic stopwatch: `:17`. 6-10 digits: `:48`. Delays escalate from 30 s to 1 h: `:89-99`. New holes: the second PIN clears the counter (N1), and parallel guesses count once (N7). |
| B5 | `SecureApplication` never engaged; no FLAG_SECURE | **Fixed** (code), device unverified | Native `FLAG_SECURE` before the first frame: `MainActivity.kt:28-31`. `SecureApplication` in `MaterialApp.builder`: `main.dart:35-49, 87`. |
| B6 | Hard-coded Dhaka geofence fired SOS | **Fixed** | The service and its dependencies are deleted (grep finds nothing). |
| B7 | RASP self-wipe on heuristics | **Fixed** | `freerasp` and the jailbreak libraries are gone from `pubspec.yaml` and `lib`. |
| B8 | Background SOS could not reach the SMS channel | **Fixed in code**, device unverified | SMS lives in the plugin, which is registered on every engine: `HardwareSosPlugin.kt:49-55`. Context-only sender: `SmsSender.kt:34-125`. `DartPluginRegistrant.ensureInitialized()`: `background_sos_service.dart:274`. |
| B9 | UI always said "Dispatched Successfully" | **Fixed** | Per-recipient `sentIntent` result: `SmsSender.kt:79-83`. Honest result card with a Call 999 button: `panic_screen.dart:521-590`. Notice text: `background_sos_service.dart:69-80`. |
| B10 | Wipe left DB handles, `.bin`/`.tmp` files, then explained the scheme; wipe PIN 0000 | **Fixed**, one residue | Closes the handles, deletes the `-wal`/`-journal`/`-shm` files, every evidence extension and the temp folder: `wipe_service.dart:13-57`. Blank calculator afterwards: `lock_screen.dart:92-101`. User-chosen wipe code: `auth_service.dart:56-62`. Residue: the SOS service and its notice survive the wipe (N9). |
| B11 | Evidence text sent to `api.typesafe.ai` | **Fixed** | No HTTP code in `lib`, and no `http` package. The release manifest has no INTERNET permission. |
| B12 | Fake cloud backup; "Google Play Services" notice | **Fixed** | Deleted. |
| B13 | GPS, BLE and accelerometer telemetry plus Twilio before the SMS | **Fixed** | SMS first with the cached fix: `trigger_panic.dart:113-143`. Trade-off: no fresh fix is ever sent (N11). |
| B14 | Re-encoded photos, ciphertext hash, fake PDF hash | **Mostly fixed** | Hash and encryption in one pass over the original: `encryption_service.dart:47-54, 81-109`. No re-encode: `vault_provider.dart:101-119`. Old ciphertext hashes are read as null (`evidence.dart:41`; the old key was `sha256_checksum`), and the PDF says "not recorded": `generate_complaint.dart:69-71`. Still open: phone-clock times, and no way to export an original, so nobody can recompute a hash (N10). These are per-item hashes, not a chain. |
| B15 | Panic recording had no DB row; plaintext in cache | **Fixed** | Row created: `trigger_panic.dart:186-192` → `secure_audio_service.dart:53-62`. Records into the private documents folder: `:22-31`. Recovery at launch: `:83-102`, `main.dart:24-26`. |
| B16 | Cosmetic disguise: broken keys, reveal button, "Protiti" label | **Mostly fixed** | Real arithmetic and no reveal button: `lock_screen.dart:159-221`. Launcher label `strings.xml:4`. iOS name `Info.plist:39-48`. Neutral permission text. Open: the package id `com.protiti.protiti` (`build.gradle.kts:21`) and other tells outside the app (N15). |
| B17 | OS permission prompts at first launch | **Fixed** | `startIfEnabled` checks and never asks: `lock_screen.dart:47-49`, `background_sos_service.dart:222-230`. |
| B18 | Camera intent locked the vault mid-capture | **Fixed** (widget test), device unverified | `pickerOpen` flag: `vault_provider.dart:93-98`. Lock suppressed: `vault_screen.dart:57`. |
| B19 | No PIN confirm, no change-PIN | **Fixed** | Each code typed twice: `pin_setup_screen.dart:42-47`. Change codes behind the real PIN: `settings_screen.dart:178-194`, `auth_service.dart:77-86`. No recovery, by design, and the setup text says so. |
| B20 | Invisible SOS instruction text | **Fixed** on the panic screen | A WCAG AA contrast test covers the panic screen (`panic_test.dart`). Other screens are unchecked. |
| B21 | No Bangla font in the PDF; plaintext PDF left in temp; wrong PCSW email | **Fixed**, with caveats | Shaped Bangla as one image per line: `pdf_text.dart:18-65`. Shared copy swept: `temp_files.dart:26-33`. PCSW email: `generate_complaint.dart:26-27`. Caveat: Bangla text cannot be searched or copied (N10, N13). |
| B22 | Duress mode had no SOS; placeholder proctor number | **Fixed** | The decoy lists only 999 and 109: `panic_screen.dart:724-765`. Opt-in silent alert: `silent_alert_service.dart:48-75`. Caveat: the text stays in her Sent messages (N4). |
| B23 | Throwaway key on storage error; backups on | **Fixed**, one residue | `allowBackup="false"` plus extraction rules: `AndroidManifest.xml:26-28`, `data_extraction_rules.xml`. iOS exclusion: `AppDelegate.swift:18-25`. DB fails closed: `database_service.dart:70-80`. Residue: the evidence key is still silently regenerated (N18). |
| B24 | False SOS triggers (proximity, 3 presses, 3 shakes) | **Fixed in code**, thresholds not field-tested | Proximity lock deleted. 4 presses in 3 s, ignored in calls: `HardwareSosPlugin.kt:156-167, 273-274`. Shake 4 peaks over 3 g: `shake_to_sos_service.dart:13-31`. Opt-in each, 5 s window. |
| B25 | Revealing secure-storage key names | **Fixed** | `secure_store.dart:11-28`, migration `:31-60`. |
| B26 | Release signed with the debug key | **Still open** | `build.gradle.kts:31-35`. |

### 0.2 Threat-model corner cases (baseline section 4)

| Scenario | Status | Now |
|---|---|---|
| App visible in launcher | **Mostly fixed** | Labelled "Calculator" with a calculator icon. Most phones already have a calculator, so two appear. `com.protiti.protiti` shows in App info (N15). |
| Recents / switcher snapshot | **Fixed** (code) | `FLAG_SECURE`, Recents title "Calculator" (`main.dart:71`). New small tell: a screenshot of the "calculator" is refused with a system toast (N15). |
| Notifications | **Partly fixed** | The fake Google and Android notices are gone. New: a persistent "Calculator: Alert shortcuts are on." notice while a trigger is on, plus a heads-up, lock-screen-public countdown and result (N4). |
| PIN brute force | **Fixed**, new hole | Escalating lockout and 6+ digits. But the second PIN resets the counter (N1). |
| Lockout | **Fixed**, new side effects | Monotonic, so clock changes do nothing. But during a lockout the second PIN and the wipe code do nothing either (N5), and anyone can lock her out for up to an hour per miss. |
| Duress PIN | **Partly fixed** | No banner, same chrome, opt-in silent alert. Still gives itself away through the brand title (N3), fixed public seed notes (N14) and the Sent-folder copy (N4). |
| Wipe PIN 0000 | **Fixed**, new risk | User-chosen, ends on a blank calculator, marker file kept. New: a code one digit from the real PIN is allowed (N6). |
| Shared family phone | **Partly fixed** | No branded screen, neutral prompts. Still: the always-on notice, the mic indicator during the 2-minute recording, and a permission list no calculator has (N4, N15). |
| Gallery copies | **No longer applies as a bug** | Still inherent: imports stay in the gallery, and the app warns. |
| Cache / temp files | **Fixed** | Playback folder and PDF copies are swept (`temp_files.dart`). Recordings live in the private folder. A picker copy survives only if the app dies mid-encrypt (N28). |
| Clipboard | **Unchanged (fine)** | Cleared on pause: `vault_screen.dart:58`. |
| Logs | **Fixed** | No `print` or `debugPrint` in `lib` or the plugin. |
| Sent SMS folder | **Still open** (documented) | The text names no app but says "Urgent, help me!" (`trigger_panic.dart:177`). Settings warns (`settings_screen.dart:103-104, 165-166`). |
| Backups | **Fixed** | Android off, iOS excluded, Keychain "this device only". |
| Uninstall | **Still open** | All evidence is lost, with no export (N10). On iOS the Keychain keeps the old codes after an uninstall, so "a reinstall starts fresh" (`AGENTS.md`) holds only after a wipe. Suspected (standard iOS behaviour). |
| SOS with no network | **Fixed** | Honest failure plus Call 999 (`panic_screen.dart:563-577`). |
| SOS with no credit / no SIM | **Fixed** | `sentIntent` failures are reported. New: there is no retry on the second SIM (N12). |
| Location denied | **Fixed** | No prompt mid-SOS (`location_service.dart:6-17`); the text says "Location unknown". New: an old cached fix shows a time but no date (N11). |
| Battery saver / OEM killers | **Partly fixed** | A battery guide with OEM deep links (`OemBattery.kt`). The service does not restart after a reboot or an OEM kill until she opens the app (N20). Not field-tested. |
| Bangla input | **Mostly fixed** | The note field uses a multiline keyboard (tested). Bangla digits count in codes. The PDF shapes Bangla. Still: setup, SOS, settings, contacts and the GD wizard are English-only (N21). |
| Low-end Android | **Partly fixed** | Streaming 64 KiB chunks, so no OOM. But pure-Dart AES runs on the UI isolate: I measured 8 MiB in 10.2 s (N19). |
| Stalkerware already on the phone | **Still open** | Not detected, and no guidance given. The misleading root banner is gone. |

### 0.3 Network calls (baseline section 5)

| Destination | Status |
|---|---|
| `api.typesafe.ai/v1/systemone` (AI) | **No longer applies**: removed. |
| `api.typesafe.ai/v1/protiti/sync` (backup) | **No longer applies**: removed. |
| `api.twilio.com` pinning | **No longer applies**: removed. |
| `en.wikipedia.org` decoy fetch | **No longer applies**: removed. |
| NTP pool | **No longer applies**: removed (monotonic clock). |
| Talsec (freeRASP) | **No longer applies**: removed. |
| SMS: location, battery, Wi-Fi SSID, BLE names | **Fixed**: now only bilingual text, the map link and the fix time (`trigger_panic.dart:176-182`). |

The release APK has no INTERNET permission (checked in the merged manifest), so it cannot reach the network. "Nothing is uploaded" is now true by construction. That is the strongest privacy property this app has.

### 0.4 Claims list (baseline section 11)

| Claim | Status |
|---|---|
| "courtroom-ready evidence" (website) | **Fixed**: "No lawyer has yet reviewed…" (`index.html:171`). |
| "3x increase" in GDs | **Fixed**: shown as "aims, not results; no pilot has run" (`index.html:152`, `pitch_deck.md:80`). |
| "direct alerts to PCSW" | **Fixed** (`index.html:137`: "It does not alert PCSW by itself"). The same line now says it "dials … the PCSW hotline with one tap", which the app cannot do (N29). |
| "vetted pro-bono lawyers (BLAST, BNWLA) via P2P" | **Fixed**: the framework says PROPOSED (`legal_aid_partnership_framework.md:3, 10`). |
| "hallucination-free" Jev AI | **Fixed**: removed. |
| "Zero-knowledge sync", "Unbreakable chains" | **Fixed**: removed. |
| Unsourced "64%" | **Fixed**: sourced with the not-a-national-sample caveat. |
| e-GD API in the demo script | **Fixed**. |
| "Dispatches GPS via offline SMS" with no contacts | **Fixed**: contacts exist. |

### 0.5 Baseline top-10 actions

| # | Action | Status |
|---|---|---|
| 1 | Decide now: pause the app | **Still open**. `decision.md` still says "Pause after the hardening agents finish". Another hardening round ran instead. |
| 2 | Talk to PCSW and 2-3 NGO caseworkers | **Still open**. Zero conversations recorded. |
| 3 | Safety stop-gap (B1-B3, B4, B6, B7, B9, B11, B12) | **Fixed**, each with tests. |
| 4 | Make the core promise real (contacts, delete, choose-for-PDF, PIN confirm, SMS-first, background SOS) | **Fixed in code**; device-untested. |
| 5 | Protection layer (B5, B10, B23, B25) | **Fixed**. |
| 6 | One real-phone session on a cheap Xiaomi or Realme | **Still open**. It is now the single biggest unknown. |
| 7 | Rewrite every public claim | **Mostly fixed**. Leftovers: the website mockup shows a branded screen that no longer exists, the "one tap PCSW" line, and stale `dkc/README.md` lines (N29). |
| 8 | Counsel review of `legal/` | **Still open**. Docs are marked UNVERIFIED, which is honest but not a review. |
| 9 | Repo and CI cleanup | **Partly done**: `dkc/runs`, the helper scripts and the duplicate mockup are gone, and CI runs on every branch. Still open: `vercel_test/` is tracked, there is no keystore, nothing is pushed or merged, and CI has not run on this code. |
| 10 | Security review and a named partner | **Still open**. |

---

## 1. Verdict

- **What it is:** an Android-first Flutter evidence vault behind a working calculator. It has real, second (duress) and wipe codes, AES-256-GCM files, SQLCipher records, per-item SHA-256 of originals, a Bangla-capable GD draft PDF, trusted contacts, and SMS SOS from the app, the power button, shaking or the second PIN.
- **Who it is for:** on paper, female students facing online harassment. In practice, half the code (duress, wipe, silent SOS, siren, strobe) serves someone in physical danger from a person who holds her phone.
- **Continue?** Yes, but only as a validation exercise, and no more agent hardening rounds first. The fix round removed every active harm I found on Oct 14. The code is now a decent prototype. Its remaining problems are design choices that only a field partner and a real phone can settle.
- **My GTM readiness: 10%** (weighted 32.5, cap 10).
- **Versus the scorecard's 5%:** I raise it because the active harms are verifiably gone. The fake contact, fake evidence, both PIN bypasses, fake success, self-wipe, geofence and third-party uploads have all been removed, and the release build cannot touch the network. I cap it at 10, not higher, for three reasons. Nobody has run it on a phone. No security reviewer or field partner exists. And the coercion path still leaks: the decoy is titled "Protiti" while the public GitHub repo explains the decoy (N3); the second PIN resets the lockout (N1); the SOS countdown is a heads-up notice the abuser can read and cancel (N4); and the in-app SOS is silently dropped if she turns the screen off during the countdown (N2). Any one of these could hurt the exact user the feature exists for.

---

## 2. Code and architecture

**Size and shape.** `lib/` is about 6,200 lines (without l10n), down from about 7,300, with 28 dependencies instead of about 45. The layering is `data/` (services, repositories), `domain/` (models, use cases) and `ui/features/`. The plugin `packages/hardware_sos` adds about 500 lines of Kotlin. The cut list in the README matches the code.

**Fit of choices.**
- One plugin for SMS, vibration, the notice and the OEM links is the right fix for B8: a plain-context sender works on any engine.
- Streaming AES-GCM with the file id, chunk index and last-chunk flag in the associated data is a correct design. I checked the chunk boundaries for exact multiples of 64 KiB, empty files, truncation and reordering. The tests cover them, and I found no flaw in the format.
- Rendering Bangla as line images in the PDF is a pragmatic workaround for the `pdf` package's lack of shaping. It costs searchability (N13).
- The weak choice is pure-Dart AES (PointyCastle via `encrypt`) on the UI isolate (N19).

**Coupling and state.**
- Services are still created inline. `TriggerPanicUseCase` is wired three times with the same arguments: `panic_screen.dart:58-64`, `background_sos_service.dart:276-282`, `silent_alert_service.dart:65-72`.
- Test seams are constructor parameters (`useCase`, `deliveries`, `pickImage`, `sendSms`), a real improvement over Oct 14.
- `DatabaseService` keeps static handles per isolate (`database_service.dart:22-23`). The background engine therefore has its own handles, which the wipe cannot close (N9).
- The panic countdown lives in widget state, which is the root cause of N2. The background path already has a correct, tested state machine (`SosTriggerHandler`, `background_sos_service.dart:86-156`). The foreground screen does not use it.

**Dead code and duplication (Confirmed by grep).**

| Code | State |
|---|---|
| `domain/models/user_profile.dart`, `support_provider.dart` | Never used. |
| `ComplaintRepository.getAllComplaints` | Never called. Complaints are saved (`complaint_wizard_screen.dart:101-115`) and never shown. |
| `Evidence.toMap/fromMap`, `TrustedContact.toMap/fromMap` | Unused. The repositories map columns by hand, twice each (`evidence_repository.dart:16-46, 57-107`; `contact_repository.dart:34-58`). |
| `integration_test` dev dependency | No `integration_test/` folder remains. It also broke my release build after a debug build (N26). |
| Siren button | Plays nothing: the asset does not exist (N8). |
| `packages/hardware_sos/example/` | The scaffold example app, still named `com.example.hardware_sos`. |

**Obfuscated schema.** Table names like `sys_analytics_cache` and `net_telemetry_peers` add confusion for no gain. The file is SQLCipher-encrypted, so anyone who can read the table names already has the data. It is harmless, but it is not security.

**Standards adherence (`CODING_STANDARDS.md`).**
- "UI must not mention vault, duress or wipe in disguise paths": met for those words. The decoy still shows the brand (N3), which is worse than the word "vault".
- "New logic with a security effect gets a test": now broadly met (107 tests). But the six holes I found were all in tested modules, so the tests check the happy path of each rule, not its abuse.
- "Guard `BuildContext` after await": analyze is clean.
- Errors are still swallowed: there are 29 `catch (_) {}` sites. Most are deliberate, for "never throw in an emergency". The siren (N8) shows the cost.

**Repo hygiene.** 41 unpushed commits on `oct14-int`; `main` is 74 commits behind; `vercel_test/` (unrelated) is still tracked. `dkc/README.md` still says "MVVM", "Dark mode theme" and `cd protiti`.

---

## 3. Bugs (ranked)

P1 means it could hurt a coerced user or breaks a core promise. P2 means a wrong result or a leak with a contained effect. P3 means minor. No P0 remains. Nothing I found actively endangers a user the way B1-B3 did.

| # | Sev | Status | Where | Failure scenario | Fix sketch |
|---|---|---|---|---|---|
| N1 | P1 | **Confirmed (reproduced)** | `auth_service.dart:110-123`; line 122 clears the counter after *any* match | The abuser has forced her to reveal the second PIN, which is the exact case it exists for. Now he can type 4 guesses, then the second PIN (which clears the miss counter), then 4 more guesses, without ever waiting. My probe: 40 wrong guesses interleaved with the second PIN gave **0 lockouts**. The lockout drops from "years" to weeks by hand, or hours with an auto-clicker. | Only a real-PIN match clears the counter. A second-PIN match leaves it as it is. Add the probe as a test. |
| N2 | P1 | **Confirmed (reproduced)** | `panic_screen.dart:96-99` cancels `_countdown` in `dispose`; `vault_screen.dart:57-64` replaces the whole vault on `paused`; `vault_screen.dart:110` swaps tabs out of the tree | She holds SOS for 3 s, then does the natural thing: turns the screen off, switches to the dialer, or the abuser grabs the phone. The vault locks, `PanicScreen` is disposed, the countdown is cancelled and **no SMS is sent**. No buzz or notice tells her. A tab change does the same. My probe: 0 SMS after leaving the screen mid-countdown. | Run the in-app countdown through a long-lived `SosTriggerHandler` (the background one is already tested), not in widget state. Treat "left the screen" as "send", not "cancel". |
| N3 | P1 | **Confirmed (reproduced)** | `vault_screen.dart:84-89` shows `l10n.appTitle` in both modes; `app_en.arb:3` "Protiti (প্রতীতি)", `app_bn.arb:3` "প্রতীতি" | Under coercion she types the second PIN. The "ordinary notes space" is titled **Protiti**. Searching the name finds the public GitHub repo (`github.com/the-abraar/DKC`, public) and the website (`index.html:127`, `tech.html:73-75`), which explain that a second PIN opens a decoy and a real vault exists. The B2 test regex (`vault_screen_test.dart:18`) does not include the brand, so the test passes. My probe found "Protiti" in the decoy tree. | Use a neutral title ("Notes" / "নোট") in both modes. Add "Protiti", "প্রতীতি" and "calculator" to the forbidden regex. Make the repo private, or strip the mechanism from public docs. |
| N4 | P1 | **Confirmed (code)**; indicator behaviour is standard Android 12+ | Notice: `HardwareSosPlugin.kt:199-237` (`IMPORTANCE_HIGH` at `:202`, `VISIBILITY_PUBLIC` at `:205, 217`). Recording: `background_sos_service.dart:275-282` uses the default `record: true` → `trigger_panic.dart:152, 186-192`. Sent copy: `SmsSender.kt:116` | A power-button SOS with the abuser present does four things. (1) A heads-up "Calculator: Sending your message in 5 seconds [Cancel]" pops up, readable on the lock screen, and he can tap Cancel. (2) "Message sent to 2 of 2. Delivered to 2." stays on the lock screen. (3) The green mic dot and "Calculator is using the microphone" show for 2 minutes. (4) "Urgent, help me!" sits in her Messages Sent folder. The second-PIN alert avoids (1)-(3) but not (4). | Add a "quiet" mode: `IMPORTANCE_LOW`, `VISIBILITY_SECRET`, neutral text ("Sync complete"), cancel by a press pattern instead of a button, and no background recording unless she opts in separately. Say plainly in Settings that the Sent copy cannot be avoided by a non-default SMS app. |
| N5 | P1 | **Confirmed (reproduced)** | `auth_service.dart:106-107` checks the lockout before matching any code | He tries 5+ codes himself, then orders her to unlock. Her second PIN does nothing, because the calculator fails silently. He concludes she is lying. The wipe code is blocked too. He can also lock her out of her own evidence for an hour per extra miss. My probe: second PIN and wipe code during a lockout both returned `lockedOut`. | During a lockout, still match the second PIN and the wipe code; only real-PIN candidates wait. This leaks nothing about the real PIN. |
| N6 | P1 | **Confirmed (reproduced)** | `auth_service.dart:56-62` checks only "different" and "not all zeros"; setup makes the wipe code mandatory (`pin_setup_screen.dart:114-115`) | Real PIN `123456`, wipe code `123457` or `1234567`: both are accepted. A one-key slip, a double-tap or a stuck key destroys all evidence with no confirmation, and the app stays a calculator for good (`wipe_service.dart:31-36`). A stressed user who mixes up three codes is the normal case. | Make the wipe code optional and off by default. Require it to differ from the real and second PINs in at least 3 positions and not share their first 4 digits. Consider requiring the wipe code twice. |
| N10 | P1 | **Confirmed** | No export anywhere in `vault_screen.dart`; the viewer is view-only (`secure_image_viewer.dart`); the PDF lists metadata only (`generate_complaint.dart:97-105`); FLAG_SECURE blocks screenshots (`MainActivity.kt:28-31`) | A camera photo, recording or note saved in Protiti can never reach PCSW, a lawyer or a court. The PDF says "anyone who has the same file can recompute" the hash (`generate_complaint.dart:31-37`), but nobody else can ever have the file. Bangla note text goes into the PDF as images (`pdf_text.dart:33-62`), so even a note's hash cannot be recomputed from the PDF. The README lists this as an owner decision. I rank it P1, because "evidence for police" is the product. | An "Export original" action per item (share sheet, with a clear warning), plus an evidence-package ZIP of originals and a manifest with hashes for a caseworker. Ask PCSW what format they accept. |
| N7 | P2 | **Confirmed (reproduced)**; practical rate Suspected | `lock_screen.dart:178-180` calls `_verifyPin` without awaiting; `auth_service.dart:106, 118` read, then write the counter | 12 parallel wrong guesses were counted as **1 miss, 0 lockouts**. A human cannot type fast enough to exploit this. An auto-clicker or `adb input` loop on an unlocked phone might. | Allow one verify in flight (a simple Future chain or flag), and ignore `=` while it is pending. |
| N8 | P2 | **Confirmed** | `acoustic_deterrent_service.dart:18` plays `audio/siren.mp3`; `assets/audio/` holds only `.gitkeep` (never in git history); the error is swallowed (`:19-21`) | "TRIGGER SIREN ALARM" (`panic_screen.dart:291-318`) maxes the volume, opens the strobe and plays nothing. A safety button that silently does nothing is worse than no button. | Add a licensed siren asset with a test that it exists, or remove the button. |
| N9 | P2 | **Confirmed** | `wipe_service.dart:13-27` never touches the background service; the service re-reads its switches only on a trigger (`background_sos_service.dart:300-302`); `closeAll` closes only the calling isolate's handles (`database_service.dart:49-58`) | After a wipe, "Calculator: Alert shortcuts are on." stays in the notification shade until a reboot or a trigger. The plain calculator still carries a safety notice. The background isolate's open SQLCipher handle on the now-deleted file also lives until the process dies. | The wipe calls `FlutterBackgroundService().invoke('reload')` (or stops the service) and clears notice 889. |
| N11 | P2 | **Confirmed** | `trigger_panic.dart:119` uses the cached fix only; `:123, 179` print `HH:MM` without a date | If no app asked for location recently, the SOS says "Location unknown", and no fresh fix ever follows. A fix from yesterday at 09:30 reads "Location 09:30" and looks current. | Add the date when the fix is not from today. Send a second SMS when a fresh fix arrives (cap the wait at 60 s). |
| N12 | P2 | Suspected | `SmsSender.kt:65-71` uses the default SMS subscription | Dual-SIM phones are the norm in Bangladesh, and credit is often on one SIM. With credit on SIM 2 only, or SIM selection set to "ask every time", the send fails, honestly, with no retry on the other SIM. | On failure, retry once per active subscription (`SubscriptionManager`; needs `READ_PHONE_STATE`). Test on a dual-SIM Xiaomi. |
| N13 | P2 | **Confirmed** | `generate_complaint.dart:92-166`; the wizard collects only station, title and description (`complaint_wizard_screen.dart:24-26`) | The GD draft has no complainant name, parent or spouse, address, NID, phone, incident date, time and place, accused profile or URL, or signature. The team's own `legal/gd_template.md:9-36` requires all of these. The letter is English-only, though a Bangla template exists in `legal/`. It prints the jargon "Triage Route: EGD_DIRECT" (`:85, 163`), the wizard step is titled "Legal Review & Police Format" (`complaint_wizard_screen.dart:338`) with no review, and the file is named `PROTITI-….pdf` (`:125`), which names the app wherever she shares it. | Follow `gd_template.md` (Bangla first). Drop the triage line and rename the step. Use a neutral file name ("GD-draft-2026-10-15.pdf"). |
| N14 | P2 | **Confirmed** | `database_service.dart:167-193` | Every install's decoy has the same three notes ("Fall 2026 University Semester Syllabus…", "Weekly Grocery Budget… (Dhanmondi)", "Kacchi Biryani & Shahi Tukra"), dated 2, 4 and 6 days before first use, and the text is public in the repo. Anyone who has read the repo recognises the decoy, and an abuser who checks twice a month apart sees nothing new. | Let her write two or three decoy notes at setup, or pick from a randomized pool. Never publish the seed text. |
| N15 | P2 | **Confirmed** (code); visibility is standard Android | `build.gradle.kts:21`; `AndroidManifest.xml:3-20`; `MainActivity.kt:28-31` | Outside the app, "Calculator" gives itself away. App info shows the package `com.protiti.protiti` and permissions for SMS, location, microphone, camera and notifications. The privacy dashboard lists "Calculator used location/microphone". A screenshot of the calculator is refused with a system toast. Two calculator icons sit in the app drawer. | Pick a neutral `applicationId` now (it is permanent once on Play). Request each permission only on opt-in, which is already done. List the remaining tells honestly in an in-app safety-check screen. |
| N16 | P2 | **Confirmed** | `settings_screen.dart:140` ("Try it once now, then tap Cancel") | There is no test mode. If she misses the 5-second Cancel, every contact gets "Urgent, help me!" and her location. | Add a "Send a test" mode that texts "This is a test from my phone, please ignore." |
| N17 | P2 | **Confirmed** | Decoy support view `support_screen.dart:179-195`; real directory `:43-77` | PCSW was removed from the hotline list for being unverified (`panic_screen.dart:628-629`). Meanwhile the real directory still lists four unverified NGO numbers (ASK's `01726222222` looks patterned), and the decoy lists two Dhaka University-style switchboard numbers. The policy is applied unevenly. | Verify each number with the service or remove it, as was done for PCSW. |
| N18 | P3 | **Confirmed** | `encryption_service.dart:34-43` | If the evidence key is missing (Keystore reset, or a restore on a new phone), a new key is silently created. Old files then fail GCM ("Decryption Failed"), and new files use the new key. Two first-ever encryptions at the same moment (a launch-time `recoverPending` plus a save) can each write a different key. | Fail closed when any `.enc` file exists, the way `getOrGenerateDbKey` does. Create the key once, under a lock. |
| N19 | P3 | Suspected (measured on desktop JIT) | `encryption_service.dart:81-140` runs on the calling isolate | My probe: 8 MiB took **10.2 s to encrypt and 10.2 s to decrypt** (Flutter test JIT on an Apple-silicon Mac). AOT on a low-end ARM phone will be faster than JIT but slower than that CPU. Expect a frozen UI for seconds per photo and much longer for long recordings. Legacy migration does both. | `Isolate.run` for the encrypt and decrypt loops, or a native AES-GCM (platform cipher). |
| N20 | P3 | Suspected | `background_sos_service.dart:257` (`autoStartOnBoot: false`); plugin watchdog receivers exported | After a reboot or an OEM kill, the triggers are off until she opens the calculator. The notice simply disappears, so she does not know. Android 12+ blocks a background restart of a location/microphone service. | Show "Shortcuts are off since the restart" on the SOS tab. Field-test on Xiaomi, Oppo, Vivo and Realme. |
| N21 | P3 | **Confirmed** | `pin_setup_screen.dart:93-119`; `panic_screen.dart` (all but one string); `settings_screen.dart`; `contacts_screen.dart`; `complaint_wizard_screen.dart` | The first screen she ever sees (code setup) and the SOS, settings, contacts and GD screens are English-only. | Move all strings to the ARB files, Bangla first. |
| N22 | P3 | **Confirmed** | `lock_screen.dart:178` matches `^\d{4,10}$`, while codes are 6-10 digits (`auth_service.dart:48`) | Someone using the calculator normally types "2500 =" with no operator. That counts as a miss, and a few of those start her lockout. | Match `^\d{6,10}$`. |
| N23 | P3 | **Confirmed** | `trigger_panic.dart:145-151`; only `strobe_screen.dart:36` resets brightness | After a fully successful in-app SOS the window goes to brightness 0, and nothing restores it. She reads the result card and the delivery updates on a black screen. | Restore after 10 s or on a tap. Make it optional. |
| N24 | P3 | **Confirmed** | `panic_screen.dart:187, 397-399`: tap callbacks inside a `SingleChildScrollView` | A drag past the touch slop during the 3-second hold makes the scroll view win, and the hold resets. A shaking thumb can fail repeatedly. | Use a `LongPressGestureRecognizer` with a larger slop, or move the button out of the scroll view. |
| N25 | P3 | **Confirmed** | `AndroidManifest.xml:61-65` forces `exported="true"`; the merged manifest also exports `WatchdogReceiver` and `BootReceiver` | Any app on the phone can start the SOS service or poke its watchdog. The impact is low, but it is needless attack surface in a safety app. | Override to `exported="false"` (the plugin does not need external callers). |
| N26 | P3 | **Confirmed (reproduced once)** | `pubspec.yaml` (`integration_test` dev dependency); the generated `GeneratedPluginRegistrant.java` | `flutter build apk --release` right after a debug build failed with "package dev.flutter.plugins.integration_test does not exist". It built after `flutter clean`. Any release pipeline that does not clean first can fail. | Drop the unused `integration_test` dependency, and run `flutter clean` in the release script. |
| N27 | P3 | **Confirmed** | `ios/Runner/Info.plist:19-25` | Background modes `audio`, `fetch`, `location` and `processing`, while iOS has no background feature (`settings_screen.dart:273-281`). Likely App Review rejection under 2.5.4. | Remove all four. |
| N28 | P3 | **Confirmed** | `vault_provider.dart:121-124`; `temp_files.dart:26-33` sweeps only playback and PDFs | If the app dies between pick and encrypt, the picker's plaintext copy stays in the cache until the wipe. | Sweep `image_picker*` files in `TempFiles.sweep`. |
| N29 | P3 | **Confirmed** | `website/index.html:137`; `pitch_deck.md:43, 68`; `Protiti_Pitch_Deck.html:370`; the website phone mockup (screenshot) | The public materials say "one-tap … PCSW hotline", but the app's hotline list is only 999 and 109. The website mockup still shows a branded "Protiti … Tap to unlock" fingerprint screen, which no longer exists. | Fix the copy and replace the mockup with a calculator. |
| N30 | P3 | Suspected | `lock_screen.dart:97-100` | The wipe ends with a `MaterialPageRoute` push. The "calculator" visibly re-animates after `=`, which a calculator never does. | Swap the route with no transition, or just reset state in place. |

---

## 4. Corner cases and failure modes

The attacker is someone who holds her phone, knows its unlock pattern, may have watched her use the app, and can search the web.

| Scenario | What happens now | Status |
|---|---|---|
| He opens the app drawer | "Calculator" with a plain icon, next to the phone's own calculator. | Confirmed (resources); two icons is user-dependent |
| He opens Settings > Apps > Calculator | Package `com.protiti.protiti`; permissions for SMS, microphone, location, camera, notifications; storage that grows with evidence (N15). | Confirmed (manifest) |
| He looks at Recents | A blank (secure) thumbnail titled "Calculator". | Confirmed (code) |
| He tries to screenshot the calculator | "Can't take screenshot due to security policy", a tell (N15). | Confirmed (FLAG_SECURE is whole-app) |
| He pulls down notifications | Nothing unless a trigger is on. If one is on: "Calculator: Alert shortcuts are on." permanently (N4). After a wipe it is still there (N9). | Confirmed |
| He guesses PINs | 4 free misses, then 30 s, 1, 5, 15 and 60 min, persisted, and immune to clock changes and restarts. | Confirmed (tests) |
| He knows the second PIN | Unlimited guessing by interleaving it (N1). | Confirmed (probe) |
| He guesses, then forces her to unlock | Her second PIN silently fails during the lockout (N5). | Confirmed (probe) |
| She uses the second PIN | Decoy notes app titled "Protiti" (N3); the same three public seed notes (N14); Safety tab with 999 and 109; Help tab with a campus directory. If the silent alert is on, an "Urgent, help me!" text goes out and stays in Sent. | Confirmed |
| She mistypes her PIN by one digit | If that digit makes it her wipe code: everything is gone, and the app is a calculator forever (N6). | Confirmed (validation) |
| She forgets which code is which | She may try the wipe code. There is no confirmation. | Confirmed |
| Shared family phone, sibling uses the calculator | Real arithmetic works. "2500 =" counts as a PIN miss (N22). | Confirmed |
| Evidence in the gallery | Gallery and screenshot imports stay in the gallery and in Google Photos backup; the app warns. Most harassment evidence is screenshots, so the vault holds a copy, not the only copy. | Confirmed (inherent) |
| Cache, temp, clipboard, logs | Swept or cleared; no logs. Picker copy only on a crash (N28). | Confirmed |
| Cloud backups | Off on Android (both cloud and device transfer); excluded on iOS. | Confirmed (config) |
| Uninstall | All evidence is lost, and there is no export to save it first (N10). | Confirmed |
| He makes her uninstall it | Same. There is no "move my evidence to a caseworker" path. | Confirmed |
| SOS with no network or credit | Honest "Not sent", three long buzzes, Call 999 on the notice. | Confirmed (code); device untested |
| SOS with credit on SIM 2 only | Fails, with no retry (N12). | Suspected |
| Location off | "Location unknown", no prompt, no follow-up fix (N11). | Confirmed |
| Battery saver kills the service | Triggers stop silently; restored only when she opens the app (N20). | Suspected |
| She turns the screen off after an in-app SOS | The SOS is cancelled (N2). | Confirmed (probe) |
| False trigger on a rickshaw | 4 peaks over 3 g in 3 s, then a 5 s window. Not field-tested. On Pixel and Xiaomi, 5 power presses also fire the phone's built-in Emergency SOS, so a habitual 5-press fires both. | Suspected |
| Bangla keyboard | Notes and the PDF work. Setup and SOS screens are English (N21). | Confirmed |
| Phone stolen while unlocked into the vault | Locks on `paused`, but not on an inactivity timeout. A phone left open on a table stays in the vault. | Confirmed (`vault_screen.dart:52-66`) |

---

## 5. Security and privacy

**What is now good.**
- The release build has no INTERNET permission, so data cannot leave except by SMS she triggers or a share she starts.
- Evidence files use authenticated AES-GCM with a correct streaming format.
- DB keys are random, 256-bit and fail closed.
- `FLAG_SECURE` is set for the whole app. Backups are off.
- Keychain items are "this device only".
- Key names are neutral, and there is no logging.
- Biometrics are biometric-only and opt-in.

This is a real step from Oct 14.

**What is still structurally weak.**
- **The PIN is a UI gate, not a key.** No key is derived from it. Everything (DB keys, evidence key, PIN hashes) sits in one secure store. Anyone who gets code execution as the app, or an unlocked Keystore (root, a forensic tool on an unpatched phone), gets all of it. A 6-digit salted single SHA-256 (`auth_service.dart:35-38`) falls in about a second offline, but that matters little while the keys sit next to it. The right design wraps the vault key with a PIN-derived key (PBKDF2 or Argon2id) and a hardware-backed, attempt-limited key, so the real vault is undecryptable without the real PIN even with full storage access.
- **The duress model leaks at the edges** (N1, N3, N4, N5, N14). The core idea is sound. The edges decide whether it protects her.
- **Public documentation of the mechanism.** The repo is public. `README.md`, `AGENTS.md` and `STORE_REVIEW.md` describe "type the code, then `=`", "hold `=` for fingerprint" and the decoy. Disguised safety apps need some obscurity. A public repo plus a brand name in the decoy removes it.
- **SMS is not private.** Every SOS and test text lands in her Sent folder (`SmsSender.kt:116`; documented Android behaviour for non-default SMS apps). The app tells her. Good, but it limits the "silent" alert.
- **Exported service and receivers** (N25).
- **No security review.** The README says so. Everything above is agent-written and unreviewed.

**I disagree with `judge.md` on one point.** It treats the offline PIN-hash weakness as the main auth gap. It is not: the online paths (N1, N5) and the absence of a PIN-wrapped key matter more.

---

## 6. UI

- **Calculator.** It looks and behaves like a stock dark calculator: chaining, `%`, `±`, Error, 9 significant digits (tests). That was a big step up. Small tells remain: no backspace, no history, the screenshot block, and the re-animation after a wipe (N30).
- **Vault.** Clean light card grid, an extended FAB, and a bottom sheet with five capture options. Cards show a raw type badge ("TEXT", "IMAGE"). The details dialog shows UTC with a label saying so. That is correct, but a survivor reading "08:30 UTC" for an event at 14:30 local will be confused.
- **Panic screen.** Still four big competing buttons (SOS, VISUAL SOS, CALL 999, SIREN), the last of which does nothing (N8). The header says "OFFLINE SMS DISPATCH READY" and "EMERGENCY SEQUENCE ACTIVE": all-caps, military copy for a frightened user. The new result card is honest and well designed: a red Call 999 button right next to the failure.
- **Decoy.** It has the same chrome as the real vault, so it shares the brand title (N3). Its "Help" tab is a campus directory and its "Safety" tab lists 999 and 109. Plausible for a student, but a hidden notes app that also has a "Safety" tab invites questions.
- **Website.** At 375 px the phone mockup still comes first, clipped at the right edge, with the headline below the fold (same as Oct 14). The mockup shows a branded "Protiti … Tap to unlock" screen that the app no longer has (N29). The desktop hero now carries the "Not for real use" banner. Good.

## 7. UX

- **First run.** A frightened user's first screen is an English form with six obscured fields (three codes, each twice), 6-10 digits, all different, and a mandatory wipe code. The text is accurate and honest ("A forgotten PIN cannot be recovered"). But there is no "is it safe for you to have this app?" check, no explanation of what the Sent folder, notifications or App info reveal, and no practice step. Most users will pick three similar codes (N6).
- **Getting in.** Type the code, then `=`. A wrong code shows nothing. After 5 misses she is silently locked out for 30 s, then longer, and has no way to tell "wrong code" from "locked". She will think the app is broken.
- **Adding evidence.** The flow is good: save first, then add details, with a gallery warning. The core job, though, is capturing online harassment, and the app has no share target ("Share to…" from Facebook, Messenger or WhatsApp), no URL capture from the share sheet, and no screenshot-then-import shortcut. She must take a screenshot, open the calculator, type the PIN, tap +, choose "screenshot", find the image and type the link by hand. Then the original stays in her gallery anyway.
- **Getting evidence out.** It cannot be done (N10). This is the biggest UX hole now.
- **SOS in the app.** Unlock, open the Safety tab, hold 3 s without drifting (N24), then wait 5 s without leaving the screen (N2). Realistically 15-25 s, and fragile. "CALL 999 NOW" is still the fastest real help, and it is one tap in the phone's own dialer anyway.
- **SOS from the background.** It is opt-in with clear explanations. The explanation says to "try it once now, then tap Cancel", with no test mode (N16). The battery guide comes right after enabling. Good.
- **When things go wrong.** Much better than Oct 14: failures are reported per contact, with Call 999. The silent failures left are the dropped in-app countdown (N2), the siren (N8) and the service stopping after a reboot (N20).
- **Pick one user.** The product still serves two users. The online-harassment student needs fast capture with URLs, takedown help (platform reports, StopNCII.org) and a PCSW-ready package. The IPV survivor needs near-perfect stealth. The fix round invested mostly in the second. The pitch names the first.

## 8. Accessibility and performance

- **Screen readers.** Only the SOS button has a `Semantics` label. A 3-second press-and-hold is hard to perform with TalkBack, and there is no semantic action alternative (Suspected). Keypad keys read their glyphs ("−", "×", "÷").
- **Contrast.** The panic screen is tested against WCAG AA. The others are not.
- **Text scaling.** Fixed font sizes. The calculator uses `FittedBox`, so it survives. The panic screen at 200% was not tested.
- **Motor.** The hold is fragile (N24). The background triggers give an alternative.
- **Performance.**
  - The release APK is 23-27 MB per ABI, fine for low-end phones.
  - Cold start no longer blocks on RASP.
  - Pure-Dart AES on the UI isolate is the bottleneck (N19).
  - The shake trigger samples the accelerometer at about 15 Hz all day inside a foreground service. The battery cost is unmeasured, and whether shake works with the screen off depends on wake-lock behaviour on each OEM (Suspected).
  - The Bangla PDF renders each line as a 3x PNG on the UI thread. A long Bangla description means seconds of work and a multi-MB PDF (Suspected; not measured).
- **Slow networks.** Not relevant any more: SMS only.

## 9. Testing and verification

**Results.** 107 Dart tests and 6 Kotlin tests pass. Analyze shows 3 infos. Debug and release APKs build (release after `flutter clean`).

**What the tests prove** (read and run):
- The calculator does real arithmetic. Wrong codes count and show nothing. The lockout holds and the real PIN works after it. The wipe lands on a calculator and stays one after a restart. No revealing string appears in en or bn (`lock_screen_test.dart`).
- The decoy has no "decoy/vault/duress" words and the same chrome. Delete needs confirmation. The camera does not lock the vault. A note saves with its source. A photo is saved before its details (`vault_screen_test.dart`).
- SMS goes first with the cached fix. Nothing is texted to 999 or 109. Failures are never reported as success. Result text contrast passes (`panic_test.dart`).
- The shake detector thresholds; the trigger handler (window, cancel, once-only, failure, delivery updates); the off-by-default switches; the second-PIN alert gating (`sos_triggers_test.dart`).
- GCM round trips, tampering, truncation and swapping fail, legacy CTR migrates, and a failed rewrite leaves the old file (`encryption_service_test.dart`).
- The wipe deletes the expected files. The PDF carries the real hashes, Bangla as images, and multipage flow. Contacts normalise BD numbers.
- Kotlin: the press counter, delivery-report parsing, the part tally and the OEM mapping.

**What they do not prove:**
- Anything on a device: real SMS, `sentIntent` and delivery reports, the background engine, the foreground service on Xiaomi, Oppo, Vivo or Realme, FLAG_SECURE, biometric-only, the mic indicator, sensor delivery with the screen off.
- That SQLCipher actually encrypts. The DB tests use a recording fake `Database` (`database_service_test.dart:9`), so `PRAGMA key` is never executed.
- Abuse of the rules. My six probes each broke one:

| Probe | Result |
|---|---|
| P1 leave the panic screen mid-countdown | 0 SMS sent (N2) |
| P2 second PIN and wipe code during a lockout | both `lockedOut` (N5) |
| P3 12 parallel wrong guesses | counter = 1, 0 lockouts (N7) |
| P4 `validatePins('123456','987654','123457')` | accepted (N6) |
| P5 decoy view text | "Protiti" found (N3) |
| P6 40 guesses interleaved with the second PIN | 0 lockouts (N1) |

**CI.** The workflow runs `pub get`, `analyze` and `test` on every branch (`.github/workflows/flutter_ci.yml`). It does not run the Kotlin tests or any build. This code is unpushed, so CI has never run on it.

**`judge.md`** still says "7 tests" and "4-digit PIN" in its last section. It is out of date by a full round (expected, since agents may not edit it).

## 10. Deploy and operations

- **Backend:** none, by design. That removes hosting, monitoring and backup work. It also removes any way to help a user whose SOS failed or whose evidence was lost.
- **Release.**
  - Signed with the debug key (B26).
  - No versioning beyond `1.0.0+1`.
  - No crash reporting. That is defensible for privacy, but then there must be another feedback path (a caseworker).
  - No update channel for sideloaded builds, so a security fix cannot reach installed phones.
  - The first release build failed until `flutter clean` (N26).
- **Google Play.**
  - `SEND_SMS` is possible. The Play exception list includes "Physical safety/emergency alerts to send SMS", so the manifest comment "Not available on Play Store distribution" (`AndroidManifest.xml:11-15`) is out of date. It still needs the Permissions Declaration Form and approval.
  - Location and microphone foreground-service types need declarations and probably a video.
  - Play requires a privacy policy URL for apps that request location, microphone or SMS, and none exists.
  - A "Calculator" listing with a hidden vault is allowed if the listing is honest and App access explains the codes (`STORE_REVIEW.md` covers this well).
- **App Store.** Hidden features must go in the review notes (2.3.1), which `STORE_REVIEW.md` covers. Background modes with no function (N27) are a likely rejection. There is no silent SMS on iOS, and the iOS build has never been run.
- **Distribution.** Until a partner exists there is no safe channel. The flash-drive plan was cancelled (`team_handoffs/community_handoff.md`). Good.
- **Support and rollback:** none. For a safety app, "who answers when it failed" is part of the product.

## 11. Legal and compliance

- **Cyber law.** The Cyber Security Ordinance 2025 was gazetted on 21 May 2025 and replaced the Cyber Security Act 2023. Reports from June-July 2026 describe a Cyber Security (Amendment) Act 2026 passed by Parliament, and an op-ed calls it the "Cyber Safety Act 2026". The names and dates conflict across sources. `legal/cyber_protection_act_2026_guide.md` still builds a full section table on an unsourced "Cyber Protection Act, 2026". It is now flagged UNVERIFIED in every heading. That is honest, but it is still wrong content. The fix is to cite the gazetted text of whatever is in force, not to hedge invented sections.
- **Indian section numbers** (65A/65B, 22A, 45A, 85A/B, 88A) are flagged but still present.
- **The legal guide's own banner is stale in the app's favour.** It still says the app "re-encodes photos, strips EXIF, hashes the encrypted file" (`:7`). That stopped being true in this round.
- **Evidence (Amendment) Act 2022.** Digital records are admissible, with examination if disputed. The app's evidence is now better than before (original bytes, honest hash text). But it cannot be produced (N10), and its times are the phone clock.
- **Data protection.** No privacy notice, no terms, no named operator. The Personal Data Protection Ordinance 2025 was approved in October 2025; gazette status unverified. With no server, the app itself processes data only on the device. But Play still requires a policy, and an NGO operator would be a controller for anything it handles.
- **Recording.** The 2-minute background recording captures other people. Lawfulness in Bangladesh needs counsel (`todo.md` lists it).
- **Liability.** Much lower than on Oct 14, because nothing claims success it did not achieve. N2 (silently dropped SOS) and N6 (one-digit wipe) are the kind of failure a supervising organisation would need disclosed before any pilot.
- **Partnerships.** Correctly marked PROPOSED.

## 12. Market, demand and marketability

**Demand is real.** PCSW had been contacted by 60,808 women for cybercrime by September 2024 (Dhaka Tribune, via IANS); doxxing 41%, hacking 18%, blackmail 17%. A 2024 BBS-UNFPA survey reported that about 89% of women social-media users had faced online violence, and about 75% did not report. ActionAid found about 65% of women who complained saw no action. The bottleneck is reporting, stigma and police follow-through, not storage.

**Who pays.** Nobody, today. The realistic payers are NGOs (BLAST, BNWLA, ASK), UN agencies (UN Women, UNFPA, UNDP), MoWCA or a2i, or a platform trust-and-safety grant, and only with a named operating partner. The DKC seed is BDT 50,000. No revenue model, which is fine for a public good, but someone must own operations.

**Alternatives (updated):**

| Alternative | What it does | What it means for Protiti |
|---|---|---|
| **JOY 109** (MoWCA/a2i, 2018) | SOS to police, 109 and 3 contacts | The baseline treated it as live. A Daily Star piece from **October 2020** says it is "nowhere to be found". I could not confirm it exists in 2026. Weaker competition than I said on Oct 14. |
| **HELP app** (BJC + Switch Bangladesh, March 2025) | Alert to volunteers and local police with location; DMP said logged incidents would count as an FIR | A police-backed SOS with an institutional receiver. DMP admitted early on that no distress signal had come through yet. A natural partner, or a reason not to build SOS. |
| **Bachao** (2022) | GPS SOS to contacts and services | More SOS overlap. |
| **Built-in Android Emergency SOS** | Pixel and Xiaomi: 5 power presses; Xiaomi texts location to trusted contacts | Already on many target phones, free and trusted. Protiti's 4-press trigger duplicates it and can collide with it. |
| **Samsung Secure Folder, Xiaomi Second Space and hidden apps, Oppo/Realme Private Safe** | OS-level hidden vaults | Free, preinstalled "hide my files" tools. They answer most of the vault need without a new app to discover. |
| **109 / 999 / PCSW hotline 01320000888 and Facebook page** | Human help | The real route. Only 12% of women know 109 (Daily Star 2025). The app could do more by promoting these than by adding features. |
| **myPlan, bSafe, Aspire News** | Safety planning; SOS plus recording; disguised news app | Covered on Oct 14. Practitioners favour safety planning over gadgets. |
| **DocuSAFE** (NNEDV) | Survivor evidence app | Shut down on 1 October 2023. The sustainability warning still stands. |

**Why would a survivor switch?** Today the only unique bundle is "evidence with an original hash, plus a GD draft, behind a calculator". Neither half works end to end: the evidence cannot be produced (N10) and the GD draft lacks what a GD needs (N13). Fix those two and talk to PCSW, and the bundle becomes a real reason. Without them, Secure Folder plus PCSW's Facebook page beats it.

**Distribution.** Caseworkers (NGOs, OCC, PCSW) installing it *with* the survivor after a safety check. Campus ambassadors only for awareness, never for APKs.

**Pitch and website vs. reality:**

| Claim | Where | Reality |
|---|---|---|
| "one-tap … PCSW hotline" | `index.html:137`, `pitch_deck.md:43, 68`, deck HTML `:370` | The app shows only 999 and 109 (N29). |
| Phone mockup: branded "Protiti, Tap to unlock" | `website/index.html` (screenshot) | The app is calculator-only. |
| "Curated directory of pro-bono lawyers and mental health counselors" | `dkc/README.md` | Four unverified numbers (N17). |
| "SHA-256 … anyone with the same file can recompute" | PDF, wizard | Nobody else can get the file (N10). |
| "Legal Review & Police Format" | wizard step `:338` | No review happened. |
| "Siren alarm" | panic screen | Plays nothing (N8). |
| "Encrypted vault … Nothing is uploaded" | README | True (no INTERNET permission). |
| 64% statistic | website, deck, demo | Sourced and caveated. Good. |

Sources:
- [Cyber Security Ordinance gazette, Dhaka Tribune](https://www.dhakatribune.com/bangladesh/381943/govt-issues-gazette-of-cyber-security-ordinance)
- [Cyber Security Ordinance 2025, Digital Policy Alert](https://digitalpolicyalert.org/change/18746-cyber-security-ordinance-2025-ordinance-no-25-of-2025)
- [Amendment passed, drops gambling clause, Financial Express](https://thefinancialexpress.com.bd/sci-tech/bangladesh-amends-cybersecurity-law-drops-online-gambling-clause)
- [Cabinet committee on the 2026 amendment, UNB](https://unb.com.bd/category/Bangladesh/govt-forms-cabinet-committee-to-finalise-draft-of-cyber-security-amendment-act/189681)
- [Netra News on "Cyber Safety Act 2026"](https://netra.news/2026/bangladesh-cyber-safety-law-abuse/)
- [Observer BD explainer naming CSA 2026 and the PCSW hotline, 18 July 2026](https://observerbd.com/news/583873)
- [PCSW caseload via IANS, 2026](https://ianslive.in/women-in-bangladesh-face-growing-wave-of-digital-violence-report--20260516201448)
- [Dhaka Tribune: women face rising digital abuse](https://www.dhakatribune.com/bangladesh/410337/the-price-of-speaking-online-women-in-bangladesh)
- [JOY launch, Daily Star](https://www.thedailystar.net/city/joy-smartphone-app-for-violence-against-women-and-children-in-bangladesh-1613269)
- [Daily Star 2020: Joy 109 "nowhere to be found"](https://www.thedailystar.net/city/news/3-personal-safety-apps-travelling-1974977)
- [HELP app launch, Dhaka Tribune 2025](https://www.dhakatribune.com/bangladesh/377762/help-is-here-app-integrates-police-volunteers-to)
- [Tech vs. sexual violence (Joy, Bachao), Dhaka Tribune](https://www.dhakatribune.com/bangladesh/377086/can-technology-offer-a-hope-against-soaring-sexual)
- [109 awareness, Daily Star 2025](https://www.thedailystar.net/supplements/16-days-activism-2025/news/when-danger-strikes-where-can-women-turn-4042526)
- [Android 12 Emergency SOS with five presses, Android Police](https://www.androidpolice.com/2021/02/18/android-12-adds-emergency-sos-with-five-taps-of-the-power-button/?amp)
- [Emergency SOS on Android phones, mobiles.co.uk](https://www.mobiles.co.uk/blog/how-to-setup-emergency-sos-features-on-android-and-ios/)
- [Play SMS and Call Log permitted uses (incl. "Physical safety/emergency alerts")](https://support.google.com/googleplay/android-developer/answer/9047303?hl=en)
- [Play SMS/Call Log policy](https://support.google.com/googleplay/android-developer/answer/16558241?hl=en)
- [DocuSAFE shutdown, techsafety.org](https://www.techsafety.org/docusafe)
- [NNEDV Safety Net app reviews](https://www.techsafety.org/apps-reviewed/)

## 13. GTM % breakdown

| Dimension (weight) | Scorecard | Mine | One line |
|---|---|---|---|
| Product works (25) | 2 | **4** | Every core flow now exists in code, and debug and release APKs build. Never run on a phone. Evidence cannot leave the vault (N10), the GD lacks the GD fields (N13), and the in-app SOS drops on screen-off (N2). |
| Quality and verification (15) | 2 | **4** | 107 Dart and 6 Kotlin tests pass, and analyze is clean. No device test, CI never ran on this code, and six probes broke six tested rules. |
| Security and privacy (15) | 1 | **4** | No network at all, GCM, FLAG_SECURE, no backups, biometric-only. But the PIN is not a key, the duress edges leak (N1, N3-N5), and no review. |
| Legal and compliance (10) | 1 | **2** | Honest UNVERIFIED flags. No privacy notice or terms (a Play blocker), wrong-act content still in `legal/`, recording law open. |
| Market validation (15) | 1 | **1** | Zero conversations with survivors, PCSW or NGOs. |
| Deploy and operations (10) | 1 | **1** | Debug-signed, no channel, no operator, no support. |
| Claims honesty (10) | 2 | **6** | README banner, sourced statistic, hedged legal claims, honest SOS results. Leftovers: the PCSW one-tap, the stale mockup, the "Legal Review" step, the silent siren, stale README lines. |
| **Weighted** | 15 | **32.5** | (4x25 + 4x15 + 4x15 + 2x10 + 1x15 + 1x10 + 6x10) / 10 |
| **Cap** | 5 | **10** | A safety product never run on a phone, with no reviewer or partner, whose duress path still gives itself away (N1, N3, N4, N5) and whose SOS can drop silently (N2). |
| **Final** | **5** | **10** | |

Where I disagree with `judge.md` and the scorecard:
1. The scorecard's cap reason ("fake trusted contact, two PIN bypasses, the decoy gives itself away, SOS reports success") is out of date. The first, second and fourth are fixed in code. The third is half fixed: no banner, but a brand title (N3).
2. `judge.md`'s last section ("7 tests", "4-digit PIN") is a full round behind.
3. Both still frame the gap as hardening. It is now validation: a phone, a partner, a reviewer.

## 14. What to cut or stop doing

**Stop:**
- Agent hardening rounds. This round was good work, but each round adds code a reviewer must read, and the open questions (N4's cancel-vs-stealth trade-off, N10's export format, which user) are not code questions.
- Polishing the GD PDF typography before knowing what PCSW accepts.
- Expanding `legal/` with hedged content. Replace it with sourced content, or shrink it.

**Cut from the app:**
- The siren and strobe ("VISUAL SOS"). One plays nothing, and both are for a physical-danger scenario the stated user rarely faces. They also crowd the SOS screen.
- The shake trigger, until field data exists. It is the most false-positive-prone, keeps an accelerometer running all day, and duplicates the power trigger.
- The background 2-minute recording by default (N4). Keep in-app recording.
- The decoy's fixed seed notes (N14).
- The obfuscated table names (cost without benefit).
- `integration_test`, `UserProfile`, `SupportProvider`, unused `toMap/fromMap`, the plugin example app.
- The iOS background modes.

**Repo:**
- Delete `vercel_test/`.
- Push this branch and merge to `main` so CI and reviewers see one truth.
- Make the repo private, or move the mechanism docs out of the public tree.

## 15. Top 10 next actions (ordered by value)

| # | Action | Effort | Who |
|---|---|---|---|
| 1 | **Run it on one cheap Android phone with a SIM** (Xiaomi or Realme, Android 13+): first run, calculator, three codes, decoy, wipe, camera capture, SOS in-app (screen off mid-countdown), power-button SOS with the app swiped away, no credit, airplane mode, dual SIM, PDF share, Recents, App info, notifications. Record what you see. | Half a day | Owner |
| 2 | **Talk to PCSW and 2-3 caseworkers** (BLAST, ASK, an OCC): what evidence format they accept (originals? a ZIP? printed screenshots?), whether a GD draft helps, whether they would install it *with* a client. Pick one user from the answers. | 2-3 weeks, about 6 conversations | Owner |
| 3 | **Close the coercion-path holes:** only the real PIN clears the counter (N1); match the second PIN and the wipe code during a lockout (N5); serialize `verifyPin` (N7); 6-10 digit match on `=` (N22); a neutral title in both modes and brand names in the forbidden-word test (N3); a wipe code optional and far from the other codes (N6); the wipe stops the SOS service (N9). One test per item, starting from my probes. | 1 day | Agent |
| 4 | **Make the in-app SOS survive leaving the screen** (N2): move the countdown into a long-lived handler; leaving the screen means send. Add a test mode (N16), a dated location and a follow-up fresh fix (N11). | Half a day | Agent |
| 5 | **Evidence export** (N10), in the format action 2 says partners accept: per-item "Export original", and a caseworker package (originals plus a manifest of hashes and capture details). | 1-2 days after action 2 | Agent, owner decides the format |
| 6 | **GD draft from `legal/gd_template.md`**, Bangla first: complainant, incident date, time and place, accused profile and URL, signature line; neutral file name; drop "Triage Route" and "Legal Review" (N13). Then have one PCSW officer or lawyer read a sample. | Half a day + 1 review | Agent, then owner |
| 7 | **Decide the stealth vs. cancel trade-off for background SOS** (N4) with a caseworker: a quiet notice, cancel by press pattern, recording off by default. Then implement. | 1 conversation + half a day | Owner decides, agent builds |
| 8 | **Store and release basics:** neutral `applicationId` now (N15), release keystore (B26), drop `integration_test` and clean in the release script (N26), remove the iOS background modes (N27), export=false overrides (N25), a privacy policy page, the Play SMS declaration under "Physical safety/emergency alerts". | Half a day agent + keystore and policy by owner | Agent + owner |
| 9 | **Claims and content:** fix the PCSW one-tap copy and the website mockup (N29); verify or remove the directory numbers (N17); add or remove the siren (N8); replace the "Cyber Protection Act 2026" table with the gazetted Ordinance 2025 as amended (counsel); update `dkc/README.md`; move all strings to Bangla-first ARB files (N21). | 3-4 hours agent; counsel 1-2 weeks | Agent + owner + lawyer |
| 10 | **Only if actions 1-2 say continue:** a human security review of a PIN-wrapped key design (PBKDF2/Argon2id plus a hardware-backed, attempt-limited key), AES in an isolate or native code (N19), and a named NGO or PCSW partner who owns support. | 1 week + reviewer | Owner finds reviewer and partner; agent implements |

**Continue or pause:** continue only with actions 1 and 2, and pause code work until they are done. The code is no longer the problem it was on Oct 14. It is now a credible prototype that nobody outside the team has touched. One afternoon with a phone and six conversations will tell more than another agent round.
