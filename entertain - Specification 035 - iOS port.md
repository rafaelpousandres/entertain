# Entertain — Specification 035 — iOS port

> **Origin:** Entertain is live on Android (1.0.32+48, production). This spec brings it
> to iOS. Based on the iOS reconnaissance report (CC, 2026-11-15): the Dart code is
> almost fully portable — no native code, no push/FCM, no Google Maps, no in-app
> purchases. The real work is the iOS project, the three permissions, build/signing via
> Codemagic, and Apple's review requirements.
>
> **Build environment decision:** Codemagic (cloud macOS CI, free tier — 500 macOS
> build minutes/month, enough for this app's cadence). No physical Mac needed for
> development; an iPhone is needed only for the final test pass.

## Decisions (locked)

1. **Build:** Codemagic (cloud, free tier). CC sets up `codemagic.yaml` + code signing.
2. **Apple account:** personal (the existing active Apple Developer account).
3. **Devices:** iPhone only for v1. iPad explicitly out — this removes the two
   `sharePositionOrigin`/`bounds` iPad issues from the report.
4. **In-app account deletion:** implement before submitting (Apple requires apps with
   account creation to allow initiating deletion in-app; Entertain's account is
   anonymous/auto-created, so do it to avoid a rejection round).
5. **Payments:** out — none exist yet; added to both stores together when premium comes.
6. **Build numbering:** iOS keeps its own build counter, separate from Android's
   versionCode, so a build burned on one store doesn't waste the number on the other.

## Goal

Ship Entertain on the App Store (iPhone), reusing the existing Flutter codebase. Adapt
only what iOS needs: the iOS project, permissions, launch/icon, signing and CI, a few
predictable code fixes, and Apple's review requirements (in-app account deletion, AI
disclosure, privacy labels).

## Out of scope

- iPad (v1 is iPhone only).
- Payments / in-app purchases (none exist).
- Push notifications (the app has none).
- Any new feature — this is a platform port, not a feature release.

---

## Block A — iOS project and configuration

### A1 — Generate the iOS project
`flutter create --platforms=ios .` with bundle id **com.pous.entertain** (same as
Android, confirm it's free on App Store Connect). `pod install`. Set the minimum
deployment target (CC recommends in the plan; iOS 13 or 14 is a reasonable floor).
Select the Apple Team for signing.

### A2 — Permissions (Info.plist + Podfile)
Three permissions, each with a justification string, **localised ca/es/en** via
`InfoPlist.strings` (not ARB):
- `NSCameraUsageDescription` — take a photo of a dish/ingredient/drink/event.
- `NSPhotoLibraryUsageDescription` — pick photos from the library.
- `NSContactsUsageDescription` — pick a contact for a supplier or guest.
Enable in the Podfile the `permission_handler` macros `PERMISSION_CAMERA=1` and
`PERMISSION_CONTACTS=1` (without them the plugin always answers "denied").

### A3 — Icon, splash, languages
- Icon: enable `flutter_launcher_icons` for iOS (today `ios: false`); provide an icon
  with no transparency.
- Splash: `flutter_native_splash` config currently Android-only; add the iOS part and
  regenerate. Expect the native splash → Flutter splash handoff to differ from Android;
  accept a reasonable result (the animated circular-mask splash is Android-specific).
- Languages: add `CFBundleLocalizations` (ca, es, en) to Info.plist (iOS equivalent of
  Android's `locales_config.xml`).

### A4 — Privacy manifests
Verify the installed plugin versions ship their `PrivacyInfo.xcprivacy` where Apple
requires it; update plugin versions if any is missing. (Could not be checked without
the iOS project.)

---

## Block B — Build and signing via Codemagic

### B1 — Codemagic setup
- Connect the GitHub repo to Codemagic.
- `codemagic.yaml` at the repo root: Flutter iOS workflow, `--dart-define-from-file`
  for the Supabase URL/anon key (same values as Android; they are not secret-sensitive
  but follow the existing dart-define pattern), build the IPA, and deliver to TestFlight.
- **Code signing:** use Codemagic's automatic code signing with an App Store Connect API
  key (Rafael generates the key in App Store Connect; CC wires it into Codemagic). This
  avoids manual certificate/provisioning-profile juggling.
- The delivery convention changes for iOS: the artifact is an IPA to TestFlight via
  Codemagic, not an AAB to the bridge folder. Note this in CLAUDE.md.

### B2 — First build to TestFlight
Produce a first signed build and get it into TestFlight. The report flags this as the
most uncertain block (first-time CI + signing). Expect iteration.

---

## Block C — Predictable code fixes (from the report)

These work on Android but are written for it; fix/verify for iOS:
- **Contacts picker** (`lib/util/contact_picker.dart`): on iOS the picker needs no
  permission but the re-read does; from iOS 18 the user may grant only some contacts —
  handle a contact outside the granted set gracefully.
- **SMS**: the `sms:<number>?body=…` separator has historically differed on iOS; verify
  the body arrives pre-filled, adjust if not.
- **HEIC photos**: iPhone saves HEIC; the code recompresses to JPEG before upload, which
  should cover it, but it's never been tested with HEIC — verify.
- **Back gesture**: edit screens block exit with unsaved changes via `PopScope`, which on
  iOS disables the swipe-back gesture on those screens. Correct behaviour; confirm it's
  not jarring.
- **Multi-photo selection**: the limit of 10 is applied to the picker and re-applied to
  the result; should work the same with the iOS picker — verify.

---

## Block D — In-app account deletion (Apple requirement)

Today: Settings shows the account id and a link to a web page; the user emails and the
account is deleted manually within 30 days. Apple requires account deletion to be
**initiable from within the app**.
- **Client:** an action in Settings ("Delete my account and data") with a clear
  confirmation (irreversible), that calls a server function.
- **Server:** an Edge Function (service_role) that deletes the group and all its data
  (events, menus, dishes, catalog, photos in Storage, quota rows, etc.), consistent with
  the data model. CC designs the deletion scope and confirms it in words before any
  server change; this touches production data, so the migration/confirmation protocol
  applies.
- Keep the existing web/email route as a fallback if useful, but the in-app path is what
  Apple needs.
- **This is the one item that adds real new work (client + server), per the report.**

---

## Block E — App Store review inputs (product/content, no new code)

- **AI disclosure:** the dish assistant and menu wizard send user text to a third-party
  AI provider via Edge Functions. Verify Apple's current rule on disclosing/consenting
  to third-party AI data sharing, and that the privacy policy covers it; add an in-app
  disclosure/consent only if the rule requires it. CC/Rafael confirm the current wording.
- **Privacy labels (App Store "nutrition label"):** declare data collected and why —
  answerable from the existing privacy policy (HTTPS-only, Supabase).
- **Encryption export compliance:** HTTPS only → the standard exemption answer.
- **DSA trader status (EU):** declare it in App Store Connect (the banner seen earlier).

---

## Block F — App Store listing (Rafael, with assets)

- iOS screenshots (required sizes), description, keywords — can reuse the Android store
  copy and the brand assets, re-exported at iOS sizes.
- Reuse the existing privacy policy and data-deletion page URLs.

---

## Acceptance criteria

- The app builds a signed IPA on Codemagic and reaches TestFlight.
- Installed on a real iPhone, the full set of flows works: onboarding + sample dataset,
  create events/menus/dishes, catalog, guests, photos (camera, gallery multi-select,
  carousel reorder), shopping list, summary PDF, AI dish/menu, Spec 034 items.
- Camera/contacts/photos permissions prompt correctly with their localised strings.
- In-app account deletion removes the account and its data.
- The App Store listing is complete (screenshots, privacy labels, DSA) and the build is
  submitted for review.

## Sequencing (for the plan)

1. A (iOS project + permissions + icon/splash/langs) — needs Codemagic or a Mac to
   compile and verify.
2. B (Codemagic + signing + first TestFlight) — the uncertain block; do early so the
   loop exists.
3. C (code fixes) — iterate once builds reach a device.
4. D (in-app account deletion) — client + server; can proceed in parallel.
5. E + F (review inputs + listing) — before submission.

## Rafael's setup tasks (outside CC)

- App Store Connect: create the app record (bundle id com.pous.entertain), generate an
  **App Store Connect API key** for Codemagic signing.
- Codemagic: sign up (free), connect the repo, add the API key (CC guides the exact steps).
- An **iPhone** for the final test pass (the daughter's, per the roadmap).
- Screenshots and listing (Block F).

## Open questions for the plan

- Minimum iOS deployment target (CC recommends).
- Exact deletion scope for Block D (CC specifies before building).
- Current Apple wording on third-party AI disclosure (verify at submission time).
