# Store review notes

The app opens as a working calculator. A code typed on it, then `=`, opens a private notes space. Both stores allow disguised safety apps, but only when reviewers are told what is hidden and how to reach it. Tell them in the review notes. Never put this text in the app, its strings, its notifications or its permission prompts: the person holding her phone may be the one she is hiding from.

## What to tell both stores

- **Purpose:** a safety app for women facing harassment and abuse in Bangladesh. She may live with the person who checks her phone, so the app only ever shows a calculator.
- **How to get in:** on the first launch, set three codes of 6-10 digits (for example 246813, 135792, 975310). Then type the first code and press `=`.
- **The other two codes:** the second opens an ordinary-looking notes space, for when someone forces her to unlock. The third deletes all app data, and the app then stays a plain calculator until it is reinstalled. Tell reviewers not to test the third code until they are done.
- **Permissions:** camera and photos attach images to her notes; the microphone records sound when she asks it to; location goes into the text she sends to the contacts she adds; notifications carry the Cancel button of the 5-second SOS countdown and its result. Nothing leaves the phone otherwise. There is no account and no server.

## Apple (App Store Connect > App Review Information > Notes)

- App Review Guideline 2.3.1 rules out hidden or undocumented features, so the notes above are required, not optional.
- The home-screen name is "Calculator". The App Store name must be unique, so the listing name can differ. The listing text must still say honestly what the app is.
- Do not offer an alternate icon. `setAlternateIconName` always shows a system alert, which would draw attention to the app.
- Expect questions about the background modes in `ios/Runner/Info.plist` (audio, fetch, location, processing). Each needs a one-line reason in the notes.

## Google Play (Play Console)

- **App content > App access:** choose "All or some functionality is restricted" and paste the "How to get in" steps.
- **Deceptive behaviour policy:** a generic name and its own calculator icon, on a calculator that really works, is not impersonation. Do not copy another calculator's icon. The background-service notification never poses as the system or another app: it is titled with the app's own label ("Calculator") and says "Alert shortcuts are on." It shows only while she has turned on the power-button or shake SOS.
- **SMS:** `SEND_SMS` needs the Permissions Declaration Form. Google grants it only for uses on its exception list, so check the current list before the first upload. Without it, the Play build must drop silent SMS.
- **Location and microphone foreground service, background location:** each needs a declaration, and Play may ask for a short video of the feature in use.
- **Data safety:** data stays on the device; SOS texts go only to contacts she adds.
