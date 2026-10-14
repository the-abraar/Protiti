# Protiti: independent critique (2026-10-14)

Reviewer stance: senior engineer, product and go-to-market. I read the docs, `judge.md` (last section first), the scorecard, `legal/`, `team_handoffs/`, the website and pitch, and all of `dkc/lib/**` plus the native Android code. I ran `flutter analyze` and `flutter test` (Flutter 3.44.9) on a copy of `dkc/` in the session scratchpad. I also ran four probe tests there and took two viewport screenshots of `website/index.html` (375x812, 1280x800). I did not run the app on a phone or simulator. Branch: `jev_int` at `7d7f7d8`.

"Confirmed" means I traced the code path end to end or reproduced it. "Suspected" means the code is as described but the effect depends on device or OS behaviour I did not run.

---

## 1. Verdict

- **What it is:** a Flutter "digital evidence vault" for women facing online harassment in Bangladesh. It has a calculator disguise, real and duress PINs, an encrypted vault, a GD (General Diary) PDF generator, a panic/SOS screen and a support directory. It was built in about 10 days for the DKC Fellowship application.
- **Who it is for:** on paper, female students aged 18-30 facing sextortion, fake profiles and deepfakes. In the code, most features target physical coercion and stalking: duress PIN, siren, fake call, geofence, "struggle detection".
- **Is it worth continuing as code?** Not in its current form. The idea, a safe evidence log plus a fast route to PCSW, 109 and 999, is worth testing with real caseworkers. This codebase is the wrong base. It is wide (about 45 plugins, 20 "tactical" services) and shallow. Several of its safety features currently make a survivor *less* safe.
- **My GTM readiness: 5%** (weighted 15, capped at 5). The scorecard says 12%.
- **Why I am lower than 12%:** the 12% assumed the problems were "unreviewed". Having reviewed the code, I found them broken. The real vault ships with three invented evidence items and a placeholder "trusted contact" (`+8801700000000`), and there is no screen to delete either. So every SOS goes to a stranger's number plus 999 and 109, and every police PDF lists invented evidence. The decoy vault prints "Showing 3 innocent decoy files." The fingerprint button accepts the phone's own unlock PIN and opens the real vault. The calculator lets anyone guess PINs without limit (I reproduced this). Screenshot and app-switcher protection never turn on (I reproduced the mechanism). A hard-coded geofence in central Dhaka auto-fires SOS. If any of these reaches a real survivor, the app could hurt her. That deserves a lower cap than "unreviewed".

---

## 2. Code and architecture

**Structure.** `lib/` has `data/` (services, repositories), `domain/` (models, use cases) and `ui/features/`. That is about 7,300 lines. `lib/data/models/` and `lib/ui/core/widgets/` are empty. The README says "MVVM", but in practice only the vault uses a `ChangeNotifier` (`VaultProvider`). Everything else news up services inline. For example, `AuthService()` is constructed separately at `lock_screen.dart:28` and `vault_screen.dart:56,66,77,86`. Use cases build their own network clients, e.g. `JevService('DKC_DEMO_API_KEY')` at `vault_provider.dart:60`. Nothing is injected, so nothing can be tested with fakes.

**State.** `DatabaseService` keeps static DB handles (`database_service.dart:17-18`) that are never closed or reset. Bug B10 below follows from that. Auth state is re-read from secure storage on every call, which is fine.

**Fit of choices.**
- Flutter fits a two-platform app built by a student team.
- SQLCipher plus `flutter_secure_storage` is a reasonable base.
- The plugin list is not reasonable. `freerasp` and `flutter_jailbreak_detection` both exist (both pull `IOSSecuritySuite`). So do `secure_application` and `screen_protector`. Then there are `nearby_connections`, `flutter_blue_plus`, `flutter_callkit_incoming`, `torch_light`, `proximity_sensor`, `http_certificate_pinning`, `ntp`, `battery_plus`, `network_info_plus` and `flutter_dynamic_icon`. Most of these serve features that do not work (see section 3).
- Several dependencies are pinned to `any` (`pubspec.yaml`: `secure_application`, `record`, `flutter_jailbreak_detection`, `screen_brightness`, `record_linux`).

**Dead or placeholder code (Confirmed by grep):**

| Code | State |
|---|---|
| `domain/use_cases/package_evidence.dart` | Never called. It would zip ciphertext that police cannot read, and it writes Bangla text with `codeUnits`, which garbles it (`:32`). |
| `P2PTransferService.dispatchEncryptedVault` | Never called. The beacon auto-accepts any device (`p2p_transfer_service.dart:17-25`) and the receive handler is empty. |
| `ContactRepository.addContact` / `getAllContacts` | Never called from the UI. |
| `VaultProvider.deleteEvidence` | Never called from the UI. |
| `ComplaintRepository` reads | Complaints are saved (`complaint_wizard_screen.dart:99`) but never shown. |
| `CloudSmsService` | Placeholder Twilio SID, token and number (`cloud_sms_service.dart:7-9`). |
| `NetworkSecurityService` | Placeholder fingerprint `'82:13:95:25:A8:12:00:23:44...'` (`network_security_service.dart:14`), so it always returns false. |
| `CamouflageService` | No alternate icon declared on either platform, so it is a no-op. |
| `biometric_mode` | Read at `auth_service.dart:170`, never written. |
| `SoundMode` silence | Commented out (`trigger_panic.dart:260`). |
| `packages/hardware_sos` | Still named `com.example.hardware_sos`. |

**Duplication.** `website/protiti_mockup.html` and `pitch_materials/protiti_mockup.html` are near copies. Evidence-row mapping is written twice in `evidence_repository.dart:57-105`. Drafts are stored under four separate secure-storage keys.

**Standards adherence (`CODING_STANDARDS.md`).** The repo breaks its own rules:
- "No hard-coded PINs": `0000` is hard-coded at `auth_service.dart:17`.
- "Decoy mode must not reveal that a real vault exists": broken at `vault_screen.dart:499-501` (B2).
- "UI text must not mention the vault, duress or wipe in the disguise paths": the biometric prompt says "show vault" (`biometric_service.dart:9`). The lockout message says "Vault locked" (`app_en.arb` `lockoutMessage`). The setup screen explains duress and 0000 (`pin_setup_screen.dart:49`).
- "No `print` in lib": `database_service.dart:51`.
- "New logic with a security effect gets a test": there are no tests for wipe, lockout, the calculator path, decoy UI, SOS or RASP.
- "Guard BuildContext after await": 5 analyzer infos in `vault_screen.dart`.

**Repo hygiene.** `dkc/` tracks `write_files.py` and `setup_dirs.py`. The latter contains an absolute path to `/Users/blackbird/Everything/dev/DKC/protiti/lib`. It also tracks `run_showcase.sh`, `wait_and_snap.sh`, `bin/test_jev.dart` and `runs/run_1..4` (PDFs and screenshots). There are four stale `subagent-*` branches with worktrees under `~/.gemini/...`. `main` is 32 commits behind `jev_int`.

---

## 3. Bugs (ranked)

P0 means it could harm a real user. P1 means it breaks a core promise or destroys or leaks data. P2 means a wrong but contained result.

| # | Sev | Status | Where | Failure scenario | Fix sketch |
|---|---|---|---|---|---|
| B1 | P0 | Confirmed | `database_service.dart:135-169` (fake evidence), `:175-198` (contacts incl. "Ayesha (Sister / Trusted SOS)" `+8801700000000`); no UI calls `addContact` or `deleteEvidence` | A real user's first real-vault open seeds 3 invented "evidence" rows and 3 contacts. She cannot add her own contact or delete the fakes. Every SOS goes to 999, 109 and a placeholder number that may belong to a stranger. Every GD PDF lists the invented items, because the wizard exports all `items` (`complaint_wizard_screen.dart:82-86` → `generate_complaint.dart:57-65`). | Delete both seed blocks. Build add/edit/delete for contacts with a "send test SMS" step. Add delete for evidence. Let the user pick which evidence goes into the PDF. Test: a fresh DB has 0 rows. |
| B2 | P0 | Confirmed | `vault_screen.dart:499-501`, `app_en.arb:59` | Under coercion the survivor enters the duress PIN. The decoy grid shows a banner with an eye-slash icon: "Showing 3 innocent decoy files." The decoy also lacks the Settings and P2P icons and has a different title (`vault_screen.dart:164-196`). The duress feature tells the abuser it is a duress feature. | Remove the banner. Make the decoy UI pixel-identical in chrome to the real vault. Add a widget test that searches the decoy tree for "decoy", "vault", "duress" (en and bn). |
| B3 | P0 | Confirmed | `biometric_service.dart:8-10` (no `biometricOnly`; local_auth 3.0.2 defaults to `false`), `auth_service.dart:167-175`, `lock_screen.dart:153-157` | The fingerprint button accepts the phone's own PIN or pattern as a fallback, and it always opens the **real** vault. A controlling partner usually knows the phone PIN, so he taps the fingerprint icon, types the phone PIN and is in. App PIN, duress PIN and lockout are all bypassed. | Pass `biometricOnly: true`, or remove biometrics until there is a decoy-routing design. Test with a fake `LocalAuthentication`. |
| B4 | P0 | Confirmed (reproduced) | `lock_screen.dart:175-180` → `auth_service.dart:78-82` | The calculator `=` key calls `matchPin`, which skips the lockout. My probe test made 5 bad guesses (`verifyPin` then returns `lockedOut`), and `matchPin` with the right PIN still returned `authenticatedReal`. Anyone can try all 10,000 PINs on the calculator. Separately, the lockout uses NTP and falls back to the device clock when offline (`time_service.dart:11-16`), so airplane mode plus a clock change clears it. Even honest lockout gives 5 guesses per 15 minutes, about 21 days for the whole PIN space. | Route the calculator through `verifyPin`, with silent failure in disguise. Store the lockout as a monotonic attempt counter with escalating delays, not wall-clock expiry. Use 6+ digit PINs. |
| B5 | P0 | Confirmed (mechanism reproduced) | `main.dart:65-84`, `lock_screen.dart:161-172`, `vault_screen.dart:107-115` | `SecureApplication` wraps only the home route. `pushReplacement` puts `VaultScreen` in a sibling route, so `SecureApplicationProvider.of(context, listen: false)` hits the package's `!` and throws ("Null check operator used on a null value"; I reproduced the same tree in a scratch test). `secure()` never runs, so Android `FLAG_SECURE` is never set and the iOS switcher is never blurred. Recents snapshots and screenshots show the vault. The screenshot listener then locks the vault, but only after the screenshot is already saved. | Put `SecureApplication` in `MaterialApp.builder` (above the Navigator), or set `FLAG_SECURE` natively in `MainActivity` for the whole app. Add a widget test that pushes the vault and asserts `secured == true`. |
| B6 | P0 | Confirmed (trace) | `geofence_service.dart:9-13, 30-35, 47-49`; started at `background_sos_service.dart:97-98`; armed from `lock_screen.dart:53` | A "danger zone" is hard-coded at 23.8103, 90.4125 (central Dhaka) with a 500 m radius. Any user who granted location and mic and passes through it fires a full panic on every 100 m position update. Mock locations fire it too. Today, delivery from the background is broken (B8), so the effect is repeated 2-minute mic recordings (the mic indicator shows on screen), BLE scans and battery drain. Once delivery is fixed, it will spam 999. | Delete the geofence. If it ever returns, it must be user-configured, opt-in and confirm before sending. |
| B7 | P0 | Code confirmed, effect Suspected | `rasp_service.dart:18, 24, 32, 36, 50-56`; `main.dart:22` | `onAppIntegrity` and `onHooks` run `executeNuclearWipe()`. The Android signing hash is hard-coded from one machine, and the iOS team ID is `INSERT_TEAM_ID_HERE`. `isProd: kReleaseMode`. A release build signed with any other key (Play App Signing re-signs with Google's key) can wipe all evidence at every launch. Commit `991b93d` (Sep 27) already had to stop `onDebug` from self-destructing test builds. | Never wipe on a heuristic. At most show a warning. Remove RASP until there is a signed release pipeline. |
| B8 | P0 | Confirmed to native boundary, device effect Suspected | `MainActivity.kt:23-55` (channel only on the activity engine); `native_sms_service.dart:14-20, 41-50`; `trigger_panic.dart:219-252`; `shake_to_sos_service.dart:54-58` | Power-button, shake and geofence SOS run in `flutter_background_service`'s own engine. The `com.protiti.protiti/sms` channel is not registered there, so `hasPermission` throws, gets caught and returns false. `launchUrl` and the share sheet need a foreground activity. So background SOS sends nothing, yet shake still posts "VoLTE carrier settings updated" as if it worked. | Move SMS sending into a plugin registered on all engines, or a native `BroadcastReceiver` / `Service`. Then test on a real phone with the app killed. |
| B9 | P0 | Confirmed | `panic_screen.dart:279-281, 437-447`; `MainActivity.kt:68` (null sent/delivery intents) | The UI always says "Emergency SOS triggered! Broadcasted to responders." and "Offline SMS Dispatched Successfully" with a green check. That includes `share_fallback` and `failed`, and it includes no SIM, no credit or no signal. | Show the real `dispatchMethod`. Use `sentIntent`/`deliveryIntent` and show per-recipient status. If sending fails, put a big "Call 999" next to the error. |
| B10 | P1 | Confirmed (trace) | `wipe_service.dart:11-29`; `database_service.dart:17-18, 34-41` (no close anywhere); `vault_provider.dart:118, 183` (`.bin`); `secure_audio_service.dart:41` (`.tmp`); `pin_setup_screen.dart:49` | Wipe deletes the DB files while the static handles stay open, so the old evidence list stays visible until the process dies. Photos (`.bin`) and audio (`.tmp`) do not match the `.enc` / `.enc_audio` filter, so they survive. Keys are deleted, so they become unreadable, but they remain as a forensic trace. After the wipe, the app shows "Set up your PINs ... a different duress PIN (opens a decoy vault). Do not use 0000." to whoever typed 0000. And 0000 is the first PIN most people guess. | Close and null both DBs, delete `-wal`/`-journal`, and use one extension for all evidence. After a wipe, show a neutral screen such as a blank calculator. Make the wipe code user-chosen, not 0000. |
| B11 | P1 | Confirmed (trace) | `vault_provider.dart:58-76`; `analyze_evidence_use_case.dart:23-30`; `jev_service.dart:21-32` | Every saved real-vault item calls `api.typesafe.ai` three times with the placeholder key `DKC_DEMO_API_KEY`. The user's own typed text is sent in plaintext (over TLS) to a third party without consent. When the call fails, the use case swallows the error, and the provider appends `[AI Classification: ERROR_ANALYZING \| Severity: 1/10]` to her description. That "1/10" goes into the police PDF. There is no HTTP timeout, so on a hung network the Save button waits forever. | Remove the AI call from the save path entirely. If it returns, it should be opt-in and on-device, or behind an explicit consent screen. |
| B12 | P1 | Confirmed | `vault_provider.dart:50-53`; `cloud_backup_service.dart:11, 40`; `notification_service.dart:36-38` | Every real-vault load POSTs an encrypted metadata blob to `api.typesafe.ai`. `|| true` means it "succeeds" even on a 404, and then posts a notification titled **"Google Play Services"**. The blob is encrypted with a key that never leaves the phone, so nothing can be restored. It is a backup in name only. Android shows the app name in the notification header anyway. | Delete the feature, or design real backup with a user-held recovery key. Never impersonate Google. |
| B13 | P1 | Code confirmed, delay Suspected | `trigger_panic.dart:126-190`; `cloud_sms_service.dart:17-22`; `network_security_service.dart:14-15` (plugin uses `connectTimeout = timeout * 1000`, so 50 s) | Before any SMS goes out, the panic waits for GPS (up to 4 s), a 2 s BLE scan plus a 2 s delay, and 1 s of accelerometer sampling. Then it tries the Twilio path, which can never succeed, once per recipient, in sequence, each with a 50 s connect timeout. On a captive portal or throttled 2G, the real SMS could start minutes late. | Send the SMS first, with whatever location is cached. Do telemetry after, or never. Remove the cloud path. |
| B14 | P1 | Confirmed | `vault_provider.dart:103-107, 122, 132`; `hash_evidence_service.dart:5-7`; `generate_complaint.dart:57-59, 150-152`; `vault_screen.dart:380` | The "forensic" chain does not hold. Photos are re-encoded at quality 90 with EXIF stripped, which deletes the original capture time and device. The stored SHA-256 is of the ciphertext, which changes with every encryption. The PDF "SHA-256" is `sha256(id_type_description)`, which anyone can recompute. Timestamps come from the device clock. The QR just encodes a hash, and nothing verifies it. Typed notes are saved as type `screenshot`. | Hash the original bytes before any processing, and keep the original encrypted. Record source URL and app. Do not call it "cryptographically verified" until a third party can check it. |
| B15 | P1 | Confirmed | `trigger_panic.dart:274-280`; `secure_audio_service.dart:15-21, 41` | The 2-minute panic recording is encrypted, but no DB row is created, so it never appears in the vault or any export. The plaintext `.m4a` sits in the cache directory until a `Future.delayed` fires. If the app is killed first, the plaintext stays. | Create the evidence row. Record to the app-private documents directory and encrypt on stop, with recovery on next launch. |
| B16 | P1 | Confirmed (calculator part reproduced) | `lock_screen.dart:186-236, 249-284, 29, 60-66`; `camouflage_service.dart:8-12`; `AndroidManifest.xml:31`; `ios/Runner/Info.plist:5-22, 47-48` | The disguise is cosmetic. On the calculator, `%` and `±` are typed as text (my probe showed "5%±"). The calculator's app bar is light grey over a black body and carries a lock icon that opens the branded "Protiti (প্রতীতি)" screen. The icon swap is a no-op (no `CFBundleAlternateIcons`, no Android `activity-alias`). The launcher label is "Protiti". Permission prompts say "Forensic Vault", "evidence" and "SOS". The default launch screen is the branded one. "Always launch as calculator" is off by default and hidden inside the real vault's settings. | Pick one disguise and make it real: full arithmetic, no reveal button, `activity-alias` on Android, neutral permission strings. Make it the default. |
| B17 | P1 | Confirmed | `lock_screen.dart:53`; `background_sos_service.dart:28-35` (`record` `hasPermission()` requests by default) | On first launch, before any explanation or PIN setup, the OS asks for location and microphone. A frightened user sees "Allow Protiti to record audio?" with no context, and anyone looking over her shoulder sees it too. | Ask only when she turns on a feature that needs it, after a plain-language explanation screen. |
| B18 | P1 | Suspected (Android lifecycle) | `vault_screen.dart:128-139`; `vault_provider.dart:85-150` | The external camera activity sends the app to `paused`, which pushes the lock screen and disposes the provider mid-capture. In release mode the save probably completes silently. In debug, `notifyListeners` after dispose throws and the `finally` deletes the photo. Either way, every camera capture ends at the lock screen. | Suppress the lock while a picker you started is open. Use an in-app camera. |
| B19 | P1 | Confirmed | `pin_setup_screen.dart:27-32, 49-54`; `setPins` has no other caller | No "confirm PIN" field, no change-PIN screen and no recovery. One typo locks the survivor out of her own evidence, and her only way out is the 0000 wipe. | Add a confirm field and a change-PIN screen behind the real PIN. Write down the recovery story. |
| B20 | P1 | Confirmed | `panic_screen.dart:289` (`grey[300]` on `#F7F9FC`), `:473` (`white70` on white), `vault_screen.dart:199` (`white70` icon on the light app bar) | The core SOS instruction "Press & Hold for 3 seconds..." is close to invisible (about 1.2:1 contrast). The recipients line on the result card is white on white. The "Lock vault immediately" button is invisible. These are dark-theme leftovers on a light theme. | Use theme colours. Add a contrast check to the widget tests. |
| B21 | P2 | Confirmed / Suspected | `generate_complaint.dart:72-183, 103` | The PDF uses the default font, so Bangla complaint text is dropped or garbled; no `pw.Font` is loaded anywhere. The plaintext PDF is left in the temp directory. It lists `pcsw@police.gov.bd`, but the police portal lists `cybersupport.women@police.gov.bd` (Suspected: portal last updated Dec 2023). | Embed a Bengali font with shaping (or render via HTML/print), delete the temp file after sharing, and verify contacts with PCSW. |
| B22 | P2 | Confirmed | `panic_screen.dart:139-141` vs. the comment at `database_service.dart:171-174` | In duress mode the Panic tab shows a "campus numbers" page with no SOS. That is the exact moment she is being coerced. Its "Dhaka University Proctor Office" is `01700000000` (`panic_screen.dart:648`), which may be a real stranger. | Offer a disguised SOS in decoy mode, or a silent alert when the duress PIN is entered. Use only verified numbers. |
| B23 | P2 | Suspected | `database_service.dart:46-63`; `AndroidManifest.xml` has no `allowBackup="false"` | If secure storage throws (a known failure after Android backup restore), a fresh "transient" key is generated. An existing DB then cannot open ("file is not a database"), and a new DB is encrypted with a key that is gone on next launch. | Fail closed with a clear error. Set `allowBackup="false"` and exclude the app from iCloud backup on purpose. |
| B24 | P2 | Suspected | `proximity_lock_service.dart:12-24`; `HardwareSosPlugin.kt:17-18, 45-47, 69-79`; `shake_to_sos_service.dart:12-14, 35-59` | False triggers in normal use. Covering the proximity sensor for 1.2 s (in bed, or with a flip case) bounces her to the lock screen. Any 3 screen on/off events in 2 s (3 power presses, call proximity, notification wake) fire SOS. 3 shakes over 2.7 g fire SOS (rickshaw or CNG on Dhaka roads, phone in a bag). | Gate each trigger behind explicit setup and a cancel window, then field-test the thresholds. |
| B25 | P2 | Confirmed | `auth_service.dart:14-15`; `database_service.dart:21-22`; `encryption_service.dart:8` | Secure-storage key names include `protiti_duress_pin` and `protiti_real_pin`. With backup or forensic access, the names alone show that a duress scheme exists. | Use neutral key names. |
| B26 | P2 | Confirmed | `android/app/build.gradle.kts:31-34` | The release build is signed with the debug key. | Set up a release keystore (owner task). |

What `judge.md` says is fixed and is fixed: default PINs `1234` and `9999` are gone, PINs are salted hashes, and the real and decoy DBs are separate files with separate keys and tables. Those were the right first fixes. They are not the main risks.

---

## 4. Corner cases and threat-model failures

The attacker is someone who has the phone, often knows its unlock PIN, and may watch her use it.

| Scenario | What happens today | Status |
|---|---|---|
| App visible in launcher | Label "Protiti", default icon, on both platforms. The disguise toggle does not change either (B16). | Confirmed |
| Recents / app switcher snapshot | Shows the vault content, because `FLAG_SECURE` and the iOS blur never engage (B5). | Confirmed (mechanism) |
| Notifications | The persistent foreground-service notification "System Service - Running background optimizations..." (`background_sos_service.dart:71-74`), plus fake "Google Play Services" and "Android System" ones. Android shows the real app name in each header, so the "stealth" notifications point straight at Protiti. | Confirmed (code), header display is standard Android |
| PIN brute force | Unlimited on the calculator (B4). Device PIN works through the fingerprint button (B3). The 4-digit hashes are crackable offline, but that hardly matters next to the two online bypasses. | Confirmed |
| Lockout | Stored as a wall-clock expiry. Offline clock change clears it (B4). | Confirmed |
| Duress PIN | Opens a decoy that says it is a decoy (B2), has fewer buttons, allows screenshots (`vault_screen.dart:110-114`) and offers no SOS (B22). No silent alert is sent when the duress PIN is used. | Confirmed |
| Wipe PIN 0000 | Hard-coded, published in `AGENTS.md` and on the setup screen. An accidental or curious entry destroys evidence without confirmation, then explains the scheme (B10). In calculator mode 0000 does nothing, so behaviour differs by mode. | Confirmed |
| Phone shared by family | Default branded screen, permission prompts naming "Forensic Vault", a mic indicator during panic recordings, and an always-on notification. A sibling or in-law can see all of these. | Confirmed |
| Gallery copies | The gallery import keeps the original in the public gallery. The app warns (good) but cannot delete it. Camera capture goes through the system camera, whose cache file is deleted (`vault_provider.dart:141-146`). Fine. | Confirmed |
| Cache / temp files | Plaintext GD PDFs (`generate_complaint.dart:179-183`), the decrypted audio during playback (`secure_audio_player.dart:49-53`, deleted on dispose only) and panic `.m4a` files (B15) all sit in the temp directory. | Confirmed |
| Clipboard | Cleared on pause (`vault_screen.dart:132`). Good. | Confirmed |
| Logs | One `print` (`database_service.dart:51`) and RASP `debugPrint`s. The Jev error includes the response body. Low risk without adb. | Confirmed |
| Sent SMS folder | The SMS says "EMERGENCY SOS [Protiti]" (`trigger_panic.dart:93`). On Android, the system writes messages sent by a non-default SMS app into the SMS provider, so they appear in her Messages history. That contradicts the "zero trace" comments (`native_sms_service.dart:3-5`, `cloud_sms_service.dart:12-13`). | Suspected (documented Android 4.4+ behaviour; current OEM UIs not checked) |
| Backups | Android `allowBackup` is unset (default on), so encrypted DBs and the secure-storage prefs file may go to Google backup. A restore likely breaks decryption (B23). On iOS, Keychain entries survive uninstall, so a reinstall keeps the old PIN hashes while the DB files are gone. | Suspected |
| Uninstall | All evidence is lost. The "cloud backup" cannot restore anything (B12). | Confirmed |
| SOS with no network | Android with SEND_SMS granted, foreground only: SMS goes out after the telemetry delays. iOS opens the visible Messages compose sheet. | Confirmed (code) |
| SOS with no credit / no SIM | SmsManager accepts the message and the UI says "Dispatched Successfully" (B9). | Confirmed |
| Location denied | Message says "GPS location unavailable". Fine. But `getCurrentLocation` may itself pop a permission dialog mid-panic (`location_service.dart:14-16`). | Confirmed |
| Battery saver / OEM killers | Xiaomi, Oppo, Vivo and Realme dominate Bangladesh and aggressively kill foreground services. The power-button and shake SOS run there, and they are already broken (B8). Continuous high-accuracy GPS plus the accelerometer stream drain battery. | Suspected |
| Bangla input | The evidence description field uses `TextInputType.visiblePassword` (`vault_screen.dart:359`). Many IMEs, Gboard included, then hide language switching, which blocks Bangla. The PIN field's `digitsOnly` drops Bangla numerals ০-৯ (`pin_setup_screen.dart:39`). The PDF drops Bangla (B21). The SOS SMS is English-only. | Suspected (IME-dependent), PDF Confirmed |
| Low-end Android | Images and audio are base64'd and encrypted as whole strings in memory (`vault_provider.dart:109-119`, `secure_audio_service.dart:30-42`). A 30-minute vault recording becomes a ~50 MB string, and OOM on 2 GB phones is likely. The APK is heavy (~45 plugins). | Suspected |
| Stalkerware already on the phone | Not detected. Root/jailbreak checks miss the common Android stalkerware pattern (accessibility service, notification listener or device admin, no root). The warning banner's premise that "stalkerware typically requires" root (`threat_detection_service.dart:4-5`) is wrong. | Confirmed (code) |

---

## 5. Security and privacy

**Encryption design.**
- SQLCipher DBs use random 256-bit keys kept in secure storage (`database_service.dart:46-63`).
- Evidence files use one shared AES key (`encryption_service.dart:8-19`) with the `encrypt` package default **AES-SIC (CTR)** and a random 16-byte IV per message. So there is no IV reuse, which is good. There is also no authentication tag: ciphertext can be altered without detection. Use AES-GCM.
- The key point: **the PIN is a UI gate, not a cryptographic one.** No key is derived from the PIN. Anyone who reaches the app UI (B3, B4) or runs code as the app gets everything. Encryption at rest only protects against raw file copies made without keystore access.
- The salted single-round SHA-256 PIN hash (`auth_service.dart:44-52`) is weak, as `judge.md` says. But I disagree with `judge.md`'s emphasis: the PIN hash sits in the same store as the DB keys, so cracking it offline gains an attacker nothing they don't already have. The online bypasses are the real problem.
- A sound design would wrap the vault key with a key derived from a 6+ digit PIN (Argon2id or PBKDF2) plus a hardware-backed key with attempt limits, with no device-credential fallback.

**Secure storage.** `flutter_secure_storage` 11 is reasonable. The in-memory fallback in `AuthService._write` (`auth_service.dart:32-36`) silently "succeeds" if the keystore throws. The PIN then exists only until restart, and on the next launch the user is asked to set up again.

**Jailbreak/root checks and RASP.** Low value and high risk. The root and jailbreak result only shows a red banner on the branded lock screen. That banner also fires for anyone with developer mode on (`threat_detection_service.dart:12`). freeRASP can wipe all evidence on a false positive (B7), and freeRASP reports to Talsec with `watcherMail: security@typesafe.ai` (`rasp_service.dart:26`). That is third-party telemetry. I would remove both libraries.

**Network calls and what leaves the device:**

| Destination | What is sent | When | File |
|---|---|---|---|
| `api.typesafe.ai/v1/systemone` | The user's evidence description, plaintext JSON | 3x per real evidence save | `jev_service.dart:21-32` |
| `api.typesafe.ai/v1/protiti/sync` | Encrypted evidence metadata plus a timestamp | Every real-vault load | `cloud_backup_service.dart:30-37` |
| `api.twilio.com` | A TLS handshake for "pinning" (fails); the POST never happens | Every SOS, per recipient | `network_security_service.dart:9-16` |
| `en.wikipedia.org` | Random-article fetch | When the decoy is empty | `decoy_generator_service.dart:16` |
| NTP pool | Time query | Each lockout check | `time_service.dart:9` |
| Talsec (freeRASP) | Security telemetry | At launch | `rasp_service.dart:26, 46` |
| SMS recipients | Location, battery level, Wi-Fi SSID and the names of nearby Bluetooth devices (bystanders' too) | Every SOS | `trigger_panic.dart:96-149` |

Who runs `api.typesafe.ai` is not stated anywhere in the repo, and there is no privacy notice. My attempt to check whether the hosts respond was blocked by the session's permission system, so whether they exist is unverified.

**Secrets.** No secret is committed (I checked git history for `sk-or-`). `vercel_test/.env.local` holds a live-looking OpenRouter key on disk. It is gitignored and untracked. Delete the folder and rotate the key if the folder was ever zipped or shared.

**Self-resemblance to stalkerware.** Background mic recording, background location, silent SMS, notifications disguised as Google, and sideloading from flash drives together match Play Protect's spyware patterns. Expect warnings or removal. Suspected.

---

## 6. UI

- **Layout.** The vault, wizard and support screens are clean, card-based light-theme layouts. Tap targets are large, with 76 px keypad buttons. Leftover dark-theme colours make key text invisible (B20). The panic screen stacks 4 big buttons plus 4 hotline cards, so the hold-to-SOS circle competes with "ACTIVATE VISUAL SOS", "CALL 999 NOW" and "TRIGGER SIREN ALARM".
- **Disguise quality.** Poor (B16). The calculator looks like a dark iOS calculator under a light Material app bar. Two keys are broken, and a lock icon reveals the real app. The "thermal shutdown" decoy is a static screen that becomes a black route the back gesture escapes (`thermal_decoy_screen.dart:15-24`). The fake call says "HR Department / Work Urgent" (`alibi_service.dart:13-15`). That is odd for a student, and English-only.
- **Bangla.** The l10n files cover about 47 strings on the lock and vault screens. The panic, settings, PIN setup, complaint wizard, support, viewers and all dialogs are hard-coded English (e.g. `panic_screen.dart:175-176, 223, 284, 294`; `pin_setup_screen.dart:45-54`). For the target user, the most important screens are in a second language.
- **Error states.** Mostly silent. Failures are caught and dropped (`catch (_) {}` throughout), so the user is told success when it failed (B9, B12) and never learns her evidence was not analysed. The one surfaced error, "Failed to export PDF: $e", shows a raw exception.
- **Website.** At 375 px the phone mockup comes first and is clipped at the right edge. The headline is below the fold. It loads the Tailwind play CDN, which is not meant for production. It is a pitch site, not a survivor-facing site. It also publicly explains the calculator disguise and duress PIN, which teaches abusers what to look for.

## 7. UX

- **Speed to SOS under stress.** From a locked phone: open the app, type the PIN on the keypad (or on the calculator, then `=`), tap the Panic tab, hold 3 s without moving (the screen scrolls, so a shaky finger cancels the hold), then wait about 5 s of telemetry plus the cloud attempt. That is 15-30 s at best, and minutes on bad networks (B13). The quick paths (power button, shake) do not send (B8). The fastest real SOS in this app is the "CALL 999" button, and that is one tap in the phone's own dialer anyway.
- **Onboarding a frightened user.** The first screens are OS permission prompts with no context (B17), then a bare "Set up your PINs" form with no confirm field (B19) and the word "duress". There is no explanation of what the app does, what leaves the phone, or what happens if she forgets the PIN. There is no safety-planning content, and no "is it safe for you to have this app?" check, which survivor-safety practitioners treat as basic.
- **Trusted-contact setup.** It does not exist (B1). This is the biggest UX gap: the promise "SMS to your trusted contacts" cannot be delivered.
- **Discoverability vs. stealth.** The app mixes both badly. The branded launch is the default and the disguise is opt-in and leaky. Meanwhile the hidden gestures are undiscoverable even to the owner: long-press the title for the thermal decoy, 5 taps to close, an invisible double-tap zone in the bottom-left corner for the fake call (`lock_screen.dart:294-309`). That zone also eats taps on the calculator's `0` key. My view: for online-harassment survivors (the stated users), stealth matters less than getting evidence out of the phone safely and fast. For intimate-partner-violence users, stealth must be near-perfect or it is worse than nothing. Pick one user.

## 8. Accessibility and performance

- **Screen readers.** There is one `Semantics` widget in the app (the panic button). The calculator, keypad dots and icon-only buttons have tooltips, which TalkBack reads. The invisible alibi zone has none, which is correct.
- **Contrast.** It fails on the most critical text (B20).
- **Motor.** The 3-second steady hold is hard with tremor or panic, and there is no alternative path that works (B8).
- **Text scaling.** Fixed font sizes throughout. Not tested at 200%.
- **Performance.** Whole-file base64 encryption in memory; three sequential AI calls with no timeout on each save; a continuous GPS stream plus accelerometer plus foreground service all day; about 45 native plugins at cold start, plus a blocking `await RaspService.initializeRasp()` before `runApp` (`main.dart:22`). Expect a slow first frame and real battery drain on low-end Android. Suspected; nothing was measured.

## 9. Testing and verification

**What I ran (scratch copy of `dkc/`):**
- `flutter pub get --offline`: lockfile unchanged.
- `flutter analyze --no-fatal-infos lib test`: 13 infos (7 deprecated, 5 `use_build_context_synchronously`, 1 `avoid_print`), 0 errors.
- `flutter test`: **7/7 pass**.

This matches `judge.md`. I did not run `scripts/check.sh` in the repo, because its `pub get` step could rewrite tracked files.

**What the 7 tests prove:**
- `auth_service_test` (3): PIN validation and the hash round-trip, using the in-memory fallback only.
- `encryption_service_test` (2): AES round-trip with a mocked keystore.
- `database_separation_test` (1): two getter strings differ. It opens no database.
- `widget_test` (1): the branded lock screen renders. My probe showed it **never reaches `PinSetupScreen`**, so the new first-run gate has no UI test.

**My four probes (scratch only):** the calculator bypasses lockout (B4, reproduced); a pushed route cannot see `SecureApplicationProvider` (B5, reproduced); the `%` and `±` keys are typed as text (B16, reproduced); the widget test skips setup.

**Gaps:**
- No test touches SOS, wipe, decoy UI text, contacts, PDF content or RASP.
- `integration_test/jev_*` use a `MockJevService` keyword matcher. The `runs/` screenshot "JEV points us in the right direction!" is a mock grading itself, not evidence that the AI works.
- CI triggers only on `main` and `develop` (`.github/workflows/flutter_ci.yml:5,7`). All recent work is on `jev_int`, so CI has never run on it.
- No device testing. Commit `991b93d` and the iOS-simulator runs in `dkc/runs/` show it has been launched on an emulator or simulator, and RASP has fired. So `judge.md`'s "never run on a device" is roughly right but slightly too strong. No one has walked the first-run-to-SOS path as a user on a real phone with a SIM.

## 10. Deploy and operations

**Backend:** none of its own. The endpoints are a third-party domain (`api.typesafe.ai`) and placeholder Twilio credentials, with no owner, SLA or privacy terms.

**Google Play.**
- `SEND_SMS` is restricted to default SMS handlers, with a narrow exception list. The manifest comment admits it is "not available on Play Store distribution" (`AndroidManifest.xml:23-28`).
- `ACCESS_BACKGROUND_LOCATION` and the location/microphone foreground-service types each need a Play declaration and a video, with a strong justification.
- The "Google Play Services" notification breaks the impersonation rules.
- A disguise is possible in principle (disguised safety apps exist) but needs honest store listing text.

**App Store.**
- Apple requires hidden features to be disclosed to App Review.
- iOS has no silent SMS.
- Changing an alternate icon always shows a system alert naming the app.
- The iOS team ID is a placeholder.

**Sideloading via "offline APK installation flash drives"** (`team_handoffs/community_handoff.md:183`): this needs "install unknown apps" turned on, which leaves a trace. Play Protect warnings are likely. There is no update channel, so a security fix can never reach installed phones. This plan should be cancelled until the app is safe.

**Release:** signed with the debug key (B26). No crash reporting, no versioned releases, no rollback.

**Support:** none. There is no helpline, no data-recovery story, no incident process and no named operator. For a safety app, an owner who answers when the SOS failed is part of the product.

## 11. Legal and compliance

**Evidence admissibility.** The Evidence (Amendment) Act 2022 does make digital records admissible in Bangladesh, with forensic examination when authenticity is disputed. That part is real.

The app's evidence is weaker than ordinary screenshots, because:
- it re-encodes photos and strips EXIF;
- it hashes the ciphertext, not the original;
- it uses device-clock timestamps;
- it prints fake hashes in the PDF;
- it injects invented evidence rows into the PDF (B1, B14).

A defence lawyer would use those points to attack an otherwise genuine complaint.

**The legal guide.** `legal/cyber_protection_act_2026_guide.md` gives exact sections, penalties and bailability for a "Cyber Protection Act, 2026", for example "Section 25: up to 7 years, BDT 1,000,000, Non-Bailable" (`:49`), and states that GDs "must be converted into an FIR" (`:58`).

- What I could confirm: the Cyber Security Ordinance 2025 (No. 25 of 2025) repealed the 2023 Act in May 2025.
- What is unsettled: reports from September 2026 describe a *draft* Cyber Protection (Amendment) Act 2026 under cabinet review. An opinion piece says a "Cyber Safety Act 2026" was adopted.
- I found no primary source for these section numbers or penalties. Treat them as unverified and possibly invented.
- "Section 65B certificate" and "Section 22A" (`legal_aid_partnership_framework.md:36, 56, 63-66`; `e_gd_schema_mapping.md:234-247`) are section numbers from India's Evidence Act. The guide itself hedges with "65A & 65B equivalents" (`:85`). Suspected wrong for Bangladesh.

**Partnership framework.** `legal_aid_partnership_framework.md:105-109` is written as agreed clauses ("BLAST and BNWLA agree that..."). Nothing is signed. If judges see it, it should say "proposed".

**Data protection.**
- Bangladesh's Personal Data Protection Ordinance 2025 was approved in October 2025; I did not verify gazette status. It is consent- and disclosure-based.
- The app sends evidence text to a third-party AI without consent (B11) and transmits bystanders' Bluetooth device names (`trigger_panic.dart:126-149`).
- It has no privacy notice, no terms and no named data controller.
- "Secure Audio Wiretap" (`vault_provider.dart:252`) records other people. Whether that is lawful in Bangladesh needs counsel.

**Duty of care and liability.** Telling a survivor "SOS dispatched successfully" when it was not (B9) is the kind of failure that creates moral, reputational and possibly legal liability. So does sending her SOS to a placeholder number (B1), or wiping her evidence on a heuristic (B7). Nobody should distribute it to real users until those are fixed and a supervising organisation owns the service.

**Overclaims still live** (the README was softened; the rest were not):

| Claim | Where | Reality |
|---|---|---|
| "courtroom-ready evidence under the Evidence (Amendment) Act, 2022" | `website/index.html` | Evidence chain is weak (B14). No counsel review. |
| "Increase in actionable, court-admissible General Diaries" / "3x increase" | `website/index.html`, `pitch_deck.md:82` | No baseline, no pilot. |
| "direct alerts to PCSW in severe danger" | `website/index.html` | No code sends anything to PCSW. |
| "vetted pro-bono lawyers (BLAST, BNWLA) ... via secure P2P" | `website/index.html`, `pitch_deck.md:42` | No partner agreed. P2P sends nothing. |
| "hallucination-free" Jev AI | `website/tech.html`, `pitch_deck.md:66` | Unsourced. Only ever tested with a keyword mock. |
| "Zero-knowledge sync", "Unbreakable cryptographic evidence chains" | `website/tech.html`, `index.html` | The "sync" restores nothing. The hashes are not verifiable. |
| "64% of Bangladeshi women face digital violence" | `website/index.html:78`, `pitch_deck.md:17`, `demo_script.md` | No source cited anywhere. |
| "designed to integrate directly with the Bangladesh Police's official e-GD API" | `demo_script.md` | The PDF itself says no such API exists (`generate_complaint.dart:99-101`). |
| "Dispatches GPS coordinates via offline SMS to emergency contacts" | `panic_screen.dart:294` | There are no user contacts (B1). |

## 12. Market, demand and marketability

**Who it serves.** The pitch names female students facing online harassment. Their main needs are:
- preserving posts and chats with URL, account and time;
- getting content taken down (platform reports, StopNCII.org for intimate images);
- reaching PCSW quickly;
- not being shamed at the thana.

The app offers almost none of that. There is no URL or link capture (the `Evidence.url` field is never set by the UI), no platform-reporting flow and no takedown help. What it does offer is mostly for intimate-partner physical danger: duress PIN, siren, fake call, struggle telemetry. That is a different user with different risks. **Product-problem fit is unvalidated, and on the evidence in the repo it is mismatched.**

**Who pays.**
- The DKC seed grant is BDT 50,000 (about USD 400). That is a campaign budget, not an app budget. `community_handoff.md` already spends it on cards and refreshments.
- Realistic long-term payers: NGOs (BLAST, BNWLA, ASK, Naripokkho), UN agencies (UN Women, UNFPA, UNDP itself), the government (a2i, MoWCA), or a platform trust-and-safety grant.
- None of them pays for an app without a named operating partner and a safety review. There is no revenue model, which is fine for a public-good tool, but someone must own operations.

**Existing alternatives:**

| Alternative | What it does | Relevance |
|---|---|---|
| **JOY** (MoWCA / a2i, Bangladesh) | Emergency button alerts police, the 109 centre and 3 chosen contacts. Power-button trigger. Monitored 24/7 per early reports. | A government-backed Bangladeshi version of Protiti's SOS already exists, with a monitoring team. Protiti needs a reason to exist beside it. |
| **109** national helpline (MoWCA) | 24/7 toll-free. Was 10921 until 2017. | Only 12% of women know it, vs 45% for 999 (Daily Star, 2025). The app lists 109 and 10921 as if they were two services (`panic_screen.dart:519-543`). |
| **PCSW** (Police Cyber Support for Women) | All-women police unit for cyber harassment. Hotline 01320000888, Facebook page, email. | The natural partner and the real "route to justice". |
| **999** | National emergency. | Already one tap from any phone. |
| **myPlan** | Research-backed safety planning and danger assessment. | Shows the value is in safety *planning*, not gadgets. |
| **bSafe** | SOS to a social network, audio/video recording. | Practitioners flag evidence recording as risky when phones are monitored. |
| **Aspire News** | Disguised as a news app, with a hidden help section. | Even disguised apps can be found by abusers (practitioner caution). |
| **DocuSAFE** (NNEDV, US DOJ funded) | Survivor evidence-collection app. | **Shut down on 1 October 2023.** Even a well-funded national NGO could not sustain an evidence app, and users had to move their data out. A direct warning for Protiti's sustainability story. |

**Distribution.** The only credible channel is NGO and shelter caseworkers or PCSW officers installing it *with* the survivor, after a safety check. That also fixes onboarding and contact setup. Campus "ambassadors" handing out APKs on flash drives is the riskiest possible channel.

**Why would a survivor trust it?** Today she has no reason to. It comes from an unnamed student team (the README says "Team: [Your Team Name]"), with no organisation behind it, no privacy notice, and data going to a domain she has never heard of. Trust has to be borrowed from PCSW or a known NGO.

**Marketability for the fellowship.** The pitch is strong on story and branding (Protiti / প্রতীতি is a good name). DKC judges a digital-peacebuilding *initiative* rooted in one division, with BDT 50k. A campaign plus a minimal, honest tool fits that better than "8 divisions" and "Cyber Protection Act mapping" (`pitch_materials/eight_divisions_rollout.md`, which the Sep 25 critique already flagged).

Sources:
- [JOY app, The Daily Star](https://www.thedailystar.net/city/joy-smartphone-app-for-violence-against-women-and-children-in-bangladesh-1613269)
- [JOY launch, Prothom Alo](https://en.prothomalo.com/science-technology/App-‘Joy’-launched-to-combat-violence-against)
- [PCSW, Bangladesh Police portal](https://police.portal.gov.bd/pages/static-pages/6922df86933eb65569e228c0)
- [109 history and usage, Prothom Alo](https://en.prothomalo.com/bangladesh/crime-and-law/dzperx8nt7)
- [109 awareness, Daily Star 2025](https://www.thedailystar.net/supplements/16-days-activism-2025/news/when-danger-strikes-where-can-women-turn-4042526)
- [NNEDV Safety Net app reviews](https://www.techsafety.org/apps-reviewed/)
- [DocuSAFE shutdown, techsafety.org](https://www.techsafety.org/docusafe)
- [Evidence (Amendment) Act 2022, UNB](https://unb.com.bd/category/Bangladesh/parliament-passes-law-allowing-digital-evidences-in-court-trial/103884)
- [Cyber Security Ordinance 2025, Digital Policy Alert](https://digitalpolicyalert.org/change/18746-cyber-security-ordinance-2025-ordinance-no-25-of-2025)
- [Cyber Protection (Amendment) Act 2026 draft, UNB](https://unb.com.bd/category/Bangladesh/govt-forms-cabinet-committee-to-finalise-draft-of-cyber-security-amendment-act/189681)
- [Netra News on "Cyber Safety Act 2026"](https://netra.news/2026/bangladesh-cyber-safety-law-abuse/)
- [Personal Data Protection Ordinance 2025, Dhaka Tribune](https://www.dhakatribune.com/bangladesh/393590/bangladesh-government-approves-personal-data)
- [Play SMS/Call Log policy, Play Console Help](https://support.google.com/googleplay/android-developer/answer/16558241?hl=en)
- [SmsManager writes to the SMS provider, Android Developers Blog](https://android-developers.googleblog.com/2013/10/getting-your-sms-apps-ready-for-kitkat.html)

## 13. GTM percentage breakdown

| Dimension (weight) | Scorecard | Mine | One line |
|---|---|---|---|
| Product works (25) | 4 | **2** | Vault, notes and PDF work on a simulator. Trusted-contact SOS is impossible (B1), background SOS sends nothing (B8), the decoy self-reveals (B2), the PDF contains invented evidence. |
| Quality and verification (15) | 3 | **2** | 7 shallow tests pass and analyze is clean. CI never runs on `jev_int`. No device test. Tests miss every P0. |
| Security and privacy (15) | 3 | **1** | Device PIN opens the real vault (B3), unlimited calculator guesses (B4), no screen protection (B5), evidence text sent to a third party (B11), self-wipe on heuristics (B7). |
| Legal and compliance (10) | 4 | **1** | No privacy notice or terms. The legal guide rests on an unverified act and Indian section numbers. Public "court-admissible" claims. |
| Market validation (15) | 2 | **1** | Zero conversations with survivors, PCSW or NGOs. A government app (JOY) already covers SOS. |
| Deploy and operations (10) | 1 | **1** | No backend, debug signing, Play-blocked permissions, placeholders, no support. |
| Claims honesty (10) | 4 | **2** | README fixed. Website, tech page, pitch and demo script still overclaim, and the app UI itself claims success it did not achieve. |
| **Weighted** | 31 | **15** | (2x25 + 2x15 + 1x15 + 1x10 + 1x15 + 1x10 + 2x10) / 10 |
| **Cap** | 12 | **5** | The app would put a real user at risk today (B1-B3, B6, B7, B9). |
| **Final** | **12** | **5** | |

Where I disagree with `judge.md` and the scorecard:
1. They say the "DECOY MODE" banner is gone (grep). A string with the same effect is still there, in the l10n file the grep missed (B2).
2. They treat the offline PIN-hash weakness as the main auth gap. The online bypasses (B3, B4) are far worse.
3. Real/decoy file separation is real, but it does not deliver decoy safety.
4. "Never run on a device" is slightly too strong. It ran on a simulator and emulator, and RASP fired.
5. The scorecard's "Product works 4" assumed the SOS and contacts worked. They do not.

## 14. What to cut or stop doing

**Stop:**
- "Hardening" this codebase feature by feature.
- Writing more legal mappings or PRDs (`todo.md`'s ASD-STE100 PRD can wait until a partner confirms the problem).
- Agent rounds that add capability.
- Any plan to hand out APKs.

**Cut from the app** (each is unsafe, fake or both):
- Jev AI classification and the cloud "backup".
- Twilio cloud SMS and certificate pinning.
- The geofence.
- BLE, Wi-Fi, battery and accelerometer "telemetry" in the SOS.
- P2P beacon, RASP detonation, notification impersonation, proximity lock, Bluetooth tether.
- The thermal decoy, the 5-tap crash and the alibi call, until a user asks for them.
- The decoy Wikipedia fetch.
- Duplicate libraries (`flutter_jailbreak_detection` or `freerasp`; `screen_protector` or `secure_application`), `flutter_dynamic_icon`, `http_certificate_pinning`, `ntp`, `record_linux`.

What is left (vault, notes, photo and screenshot capture, PIN plus duress, PDF export, hotline dialer, one SMS SOS) is about a third of the code and covers what the pitch actually promises.

**Repo clutter:**
- `vercel_test/`: an unrelated OpenRouter probe with a key on disk and `node_modules`. Delete it.
- `dkc/runs/`, `dkc/write_files.py`, `dkc/setup_dirs.py`, `dkc/run_showcase.sh`, `dkc/wait_and_snap.sh`, `dkc/bin/test_jev.dart`.
- `integration_test/jev_*`: mock "showcases" that look like evidence.
- The duplicate `protiti_mockup.html`, `assets/archived_old_logo_ideas/`, the empty `legal/untitled folder`, the empty `lib/data/models/` and `lib/ui/core/widgets/`.
- The four stale `subagent-*` branches and their `~/.gemini` worktrees.
- Merge or reset `main` (32 behind) so the default branch means something.

## 15. Top 10 next actions (ordered by value)

| # | Action | Effort | Who |
|---|---|---|---|
| 1 | **Decide now: pause the app.** Do not ship, demo on real users or distribute any build. If the fellowship result is positive, spend month 1 on validation (action 2) before any new code. If negative, archive with a "not for real use" notice at the top of the README. | 30 min | Owner |
| 2 | Talk to PCSW and 2-3 NGO caseworkers (BLAST, BNWLA, ASK): what evidence police actually accept, what gets survivors hurt, whether they would install a tool *with* a client. Pick one user (online harassment *or* IPV) from what they say. | 2-3 weeks, ~6 conversations | Owner |
| 3 | Safety stop-gap, so any build that leaks cannot hurt anyone: remove the seed evidence and contacts (B1); remove the decoy banner and match decoy chrome (B2); `biometricOnly: true` or remove biometrics (B3); calculator through `verifyPin` (B4); delete the geofence (B6) and RASP detonation (B7); remove the AI and cloud-backup calls (B11, B12); show the true SOS status (B9). One test per item. | 1 day | Agent |
| 4 | Make the core promise real: contact add/edit/delete with a test SMS, evidence delete and choose-for-PDF, PIN confirm and change, SMS-first panic with sent/delivered status (B13), SOS that works from the background engine (B8). | 2-3 days | Agent |
| 5 | Fix the protection layer: `SecureApplication` above the Navigator or native `FLAG_SECURE` (B5); wipe that closes DBs, deletes every evidence file and lands on a neutral screen with a user-chosen wipe code (B10); `allowBackup=false` (B23); neutral key names (B25). | 1 day | Agent |
| 6 | One real-phone session on a cheap Xiaomi or Realme with a SIM: first run, disguise, both PINs, SOS with credit, without credit and in airplane mode, PDF export, app-switcher snapshot, wipe. Record what you see. | Half a day | Owner |
| 7 | Rewrite every public claim to match the code: website, tech page, pitch deck (`.md`, `.html`, `.pptx` via `generate_deck.py`), demo script. Remove "court-admissible", "hallucination-free", "zero-knowledge", "direct alerts to PCSW", "vetted BLAST/BNWLA", the e-GD API line and the unsourced 64% (or source it). Mark the partnership framework "proposed". | 2-3 hours | Agent, owner approves |
| 8 | Counsel review of `legal/`: replace the "Cyber Protection Act 2026" section table with verified text of whatever law is in force, drop Indian-numbered sections, confirm the PCSW contacts, add a privacy notice and terms that name a data controller. | 1-2 weeks elapsed | Owner + lawyer |
| 9 | Repo and CI cleanup: delete the clutter in section 14, rotate the OpenRouter key, run CI on every branch, merge `jev_int` to `main`, set a real release keystore (B26). | 1-2 hours (keystore: owner) | Agent + owner |
| 10 | Only if continuing after 2-6: a human security review of a redesigned key hierarchy (PIN-derived wrapping key via Argon2id or PBKDF2 plus a hardware-backed key, AES-GCM, hash-before-transform evidence chain), and a named NGO or PCSW partner who owns support. | 1 week + reviewer | Owner (find reviewer and partner), agent implements |

**Continue or pause:** pause. I agree with the pending decision to pause until the fellowship result. I disagree with "after hardening". The remaining problems are product and safety design, not hardening, and more agent rounds on this codebase add risk faster than value. The idea earns another look only with a field partner in the room. If the team continues, the honest version is a small, Bangla-first evidence log and referral tool, set up by a caseworker. It should be judged by whether PCSW accepts its output, not by how many "tactical" features it has.
