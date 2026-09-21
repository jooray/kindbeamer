# Specification — KindBeamer

Unofficial cross-platform (macOS / Linux / Android) client for Amazon's
*Send to Kindle* cloud service, built with Flutter. This document describes the
architecture, the wire protocol and the platform integration.

> Not affiliated with Amazon. The protocol below is undocumented and was derived
> from observing the official clients; see `stkclient` for prior art.

## 1. Goals / non-goals

Goals:

- Replacement for the official desktop app's core flow:
  pick documents → pick devices → send over Wi-Fi → optional library archive,
  shortened to a window that opens already addressed and sends on Enter.
- Native feel on every platform; a monochrome e-paper window that inverts at
  night, keyboard-first on the desktop.
- Act as a share/open recipient everywhere the OS allows it.
- No server component; credentials stay on the device.

Non-goals (for now):

- USB/MTP sideloading (the official app's "USB File Manager").
- Kindle library browsing / management / deletion.
- iOS, Windows (the codebase should port; not packaged yet).

## 2. Architecture

```
lib/
  main.dart                     entrypoint, window setup, initial file intake
  src/
    amazon/
      models.dart               DeviceInfo, OwnedDevice, API responses, ApiError
      signer.dart               X-ADP-Request-Digest RSA signing + PKCS#1 PEM parse
      api.dart                  HTTP layer (token exchange, register, STK calls, upload)
      oauth.dart                PKCE flow: signin URL, redirect parsing
      client.dart               StkClient facade (devices, sendFile, logout, serde)
    state/
      app_state.dart            ChangeNotifier: session, devices, doc queue, send loop
      credentials_store.dart    keychain/encrypted-storage persistence + file fallback
      documents.dart            DocItem, DocFormat table, Ingest filtering
    platform/
      intake.dart               Android share intents, macOS Services channel
    ui/
      theme.dart                ink palette (paper/night), type, metrics
      label_parts.dart          barred edge, legend, well, tick, postmark, buttons
      home_page.dart            the label (contents, description, delivery, franking)
      login_dialog.dart         embedded webview login + paste-URL fallback
      settings_dialog.dart      account / after a delivery / appearance / links
```

State management is a single `ChangeNotifier` (`AppState`) consumed through
`ListenableBuilder`; no external state package. UI is Material 3 carrying a
monochrome e-paper palette with no accent hue at all: state is fill, stroke,
tick and inversion, which is what lets the same window read as paper by day and
as an inverted e-reader at night. Two bundled OFL faces: Libre Franklin for
what the form prints, Courier Prime for what is filled into it.

## 3. Authentication

1. App generates a PKCE verifier (32 random bytes, base64url, unpadded) and
   builds the signin URL `https://www.amazon.com/ap/signin` with the OpenID/OAuth2
   parameters used by official device clients, notably
   `openid.oa2.client_id=device:<client-id>`, `openid.oa2.scope=device_auth_access`,
   `openid.oa2.code_challenge_method=S256` and
   `openid.return_to=https://www.amazon.com/sendtokindle/maplanding` (the same
   return target the official desktop apps use).
2. The URL is loaded in an embedded webview (macOS/Android/iOS/Windows) that
   presents the platform's stock browser user agent, because Amazon serves a
   degraded sign-in page to unknown ones. After login Amazon redirects to the
   `return_to` URL carrying `openid.oa2.authorization_code=…`; that page then
   bounces (after ~100 ms) to the `sendtokindle://` scheme URL of the official
   app. The webview captures the code from whichever hop it observes:

   - `shouldOverrideUrlLoading` (`useShouldOverrideUrlLoading: true`) — the only
     hook that sees the `sendtokindle://` navigation, which the webview would
     otherwise swallow without a word;
   - `onLoadStart` / `onLoadStop` / `onUpdateVisitedHistory` for the landing page
     itself, plus a `window.location.href` read after load in case the code only
     ever existed in a server-side redirect hop;
   - `onReceivedError` and a back/forward history scan as the last nets.

   Whichever fires first wins (`_complete` is idempotent), the dialog shows a
   "Completing sign-in…" veil and closes. Platforms without a webview (Linux)
   open the system browser and offer a "paste the redirect URL" field.

   (Flow confirmed by analyzing the official macOS Qt binary: it registers the
   `sendtokindle:` URL scheme and uses the `…/sendtokindle/maplanding` return
   target, whose served JS performs the scheme bounce.)
3. `POST https://api.amazon.com/auth/token` exchanges the code (+ verifier) for
   an access token (`source_token_type=authorization_code`,
   `client_domain=DeviceLegacy`, same public client id).
4. `POST https://firs-ta-g7g.amazon.com/FirsProxy/registerDeviceWithToken` with an
   XML body (device type / serial / pid / software version mimicking the official
   Mac client) returns the long-lived device credentials as XML.

   The `deviceSerialNumber` / `pid` pair is generated per installation and kept
   in `settings.json`. The two are not independent — registering a fresh serial
   against the reference pid answers HTTP 200 with
   `<error><message>Internal Error</message></error>`, which is what makes both
   reference ports (`stkclient`, `stkclient-swift`) ship one hard-coded pair and
   accept one registration per account.

   The pid is the Mobipocket PID derivation applied to the serial, the same
   function DeDRM's `kindlepid.py` uses (`lib/src/amazon/device_id.dart`):

   ```
   crc      = CRC-32(serial)            (0xEDB88320 table, no initial or final inversion)
   folded[i] = XOR of serial bytes at positions ≡ i (mod 8)
   pid[i]   = ALPHABET[(b >> 7) + ((b >> 5 & 3) ^ (b & 0x1f))]
              where b = folded[i] ^ crc_bytes[i & 3]
   ALPHABET = ABCDEFGHIJKLMNPQRSTUVWXYZ123456789    (34 characters, no O, no 0)
   ```

   It reproduces the reference pair exactly — `pidFor('ZYSQ37GQ5JQDAIKDZ3WYH6I74MJCVEGG')`
   is `D21NN3GG` — which is how the derivation was confirmed without spending a
   sign-in per guess (`test/device_id_test.dart` pins it). Serials keep the shape
   the reference has: unpadded base32 of 20 random bytes, `[A-Z2-7]{32}`.

   So each installation registers as its own device and two machines can hold a
   session at the same time, each appearing in the account's device list under
   `device_model` — `KindBeamer (<hostname>)`, or `KindBeamer (Android)`, within
   the 51 characters the official client allows.

   The response body:
   `device_private_key` (PKCS#1 RSA PEM), `adp_token`, plus account metadata.
5. The access token is discarded; only the device credentials are persisted
   (keychain / encrypted shared preferences; a mode-600 file as a last-resort
   fallback where no keychain is reachable — Linux without a secret service, or
   an ad-hoc signed macOS build, which has no keychain access group). The
   Settings dialog says which of the two is in use.

Sign-out calls `GET /FirsProxy/disownFiona?contentDeleted=false` (signed) and
deletes local credentials.

## 4. Request signing (`X-ADP-Request-Digest`)

Every call to `https://stkservice.amazon.com` and the Firs proxy carries:

- `X-ADP-Authentication-Token: <adp_token>`
- `X-ADP-Request-Digest: <base64(sig)>:<UTC iso8601 seconds>Z`

where `sig` is raw RSA over a custom PKCS#1-v1.5-style block:

```
sig_data  = METHOD \n PATH \n DATE \n BODY \n ADP_TOKEN      (UTF-8, SHA-256)
EM        = 0x01 || 0xFF * (k - 35) || 0x00 || sha256(sig_data)   (k - 1 bytes)
sig       = (EM as big-endian integer) ^ d mod n                  (k-byte output)
```

where `k` is the modulus size in bytes (256 for the 2048-bit keys the service
issues), so `EM` is **255** bytes — one short of the modulus — with 221 `0xFF`
bytes. Two details that look cosmetic and are not: the padding omits the ASN.1
DigestInfo prefix of textbook PKCS#1, and `EM` must not be padded out to the full
`k` bytes. Getting the length wrong costs an extra `0xFF`, and every signed call
comes back `403 Couldn't decrypt the request's signature using the device info's
public key`.

`lib/src/amazon/signer.dart` implements this with `BigInt.modPow` and a minimal
DER parser for PKCS#1 PEM private keys. `test/signer_test.dart` checks it against
a vector computed with `stkclient`'s own padding constant — not one generated
from this implementation, which is how the off-by-one survived its first test.

## 5. Send-to-Kindle API

All bodies are JSON with a `ClientInfo` block (`appName: ShellExtension`,
`appVersion: 1.1.1.253`, per-platform `os`/`osArchitecture`) merged in.

| Step | Request | Purpose |
|---|---|---|
| list devices | `POST stkservice.amazon.com/GetListOfOwnedDevices` `{}` | `ownedDevices[]` with names, serials, capabilities |
| upload url | `POST stkservice.amazon.com/GetUploadUrl` `{"fileSize": n}` | presigned `uploadUrl` + `stkToken` |
| upload | `PUT <uploadUrl>` body = the file streamed from disk, `Content-Length` set | S3 |
| deliver | `POST stkservice.amazon.com/SendToKindle` | see below |
| logout | `GET firs-ta-g7g.amazon.com/FirsProxy/disownFiona?contentDeleted=false` | unregister device |

`SendToKindle` body:

```json
{
  "DocumentMetadata": {"author": "", "crc32": 0, "inputFormat": "PDF", "title": "…"},
  "archive": true,
  "deliveryMechanism": "WIFI",
  "outputFormat": "MOBI",
  "stkToken": "…",
  "targetDevices": ["SERIAL", "…"]
}
```

`inputFormat` is derived from the file extension (see §7); `archive` mirrors the
"Archive document in your Kindle Library" checkbox; `targetDevices` are the
serials ticked in the device list.

`title` and `author` must be at least one character each — an empty author is
refused with `400 … 'documentMetadata.author' failed to satisfy constraint:
Member must have length greater than or equal to 1` — so a blank title falls back
to the file's base name, a blank author to `Unknown`, and both are truncated at
255 characters (the official client truncates too, logging "Truncating author
to"). `GetListOfOwnedDevices` can also return the same device twice under one
serial, which is collapsed on the way in: keyed by serial, duplicates would tick
and untick together in the device list. Multiple queued documents are sent
sequentially, each with its own metadata and upload. The S3 `PUT` is fed from
`File.openRead()` through `StreamedRequest.sink.addStream`, so the socket sets
the pace and the file never sits in memory in one piece; bytes written are
reported per whole percent and shown in the status strip.

## 6. File intake ("share recipient")

Common path: `Ingest.filterAccepted` normalizes `file://` URLs, drops unknown
extensions and duplicates; `Ingest.itemsFor` stats each file and builds
`DocItem`s (default title = basename without extension); `Ingest.unsupported`
feeds the "skipped N files" notice for mixed drops.

On macOS both native sources (Services, `application(_:open:)`) hand their paths
to one `FileIntake` queue. Files can land there before the engine is up, so
native only ever *queues* and nudges — Dart drains with `takePendingFiles` over
`MethodChannel('dev.stkn.kindbeamer/intake')` at startup, on the `filesAvailable`
callback and on app resume. Nothing is lost during launch and nothing arrives
twice.

| Source | Wiring |
|---|---|
| window drag & drop (desktop) | `desktop_drop` `DropTarget` around the whole window |
| file dialog | `file_selector` `openFiles` with extension type group |
| CLI args (Linux/Windows) | `main(List<String> args)` |
| macOS Services menu | `NSServices` entry (`sendFilesToKindle`) in `Info.plist`; `AppDelegate` installs an `NSPasteboard` service provider |
| macOS Open With / dock drop / `open -a` | `CFBundleDocumentTypes` (pdf, epub, kindle formats, text, images) + `application(_:open:)` in `AppDelegate` |
| Android share sheet & open-with | `ACTION_SEND` / `SEND_MULTIPLE` / `VIEW` intent filters with document MIME types; `receive_sharing_intent` streams media file paths into the same ingest |
| Linux Open With | `.desktop` file with `MimeType=` list (`packaging/linux/`) + argv intake |

## 7. Formats

| Extension | `inputFormat` |
|---|---|
| pdf | PDF |
| epub | EPUB |
| mobi | MOBI |
| azw3 / azw | AZW3 / AZW |
| txt | TXT |
| rtf | RTF |
| doc / docx | DOC / DOCX |
| html / htm | HTML |
| png | PNG |
| jpg / jpeg | JPG |
| gif | GIF |
| bmp | BMP |
| md / markdown | *converted first, see below* |

Anything else is rejected at intake with a snackbar explaining the supported set.

### Markdown

The service has no Markdown input format, so a `.md` is converted as soon as it
is queued — before the format banner and the size are shown, so what the UI says
is what is sent. `lib/src/convert/markdown.dart` tries, in order:

1. `pandoc` with a PDF engine (`xelatex`, `pdflatex`, `lualatex`, `tectonic`,
   then `typst`, `weasyprint`, `wkhtmltopdf`, `prince`) — pages are 6×8in with
   0.4in margins, not A4, because a PDF does not reflow and a letter-sized page
   on a 6" reader is a page of specks;
2. headless Chrome printing the rendered HTML, for a desktop with a browser but
   no TeX;
3. in-process Markdown → styled HTML, which the service converts on its side.

Which path a platform actually takes:

| Platform | Path | Why |
|---|---|---|
| Linux | pandoc → PDF | no sandbox in the way |
| macOS | HTML | the App Sandbox denies spawning binaries outside the app; the tools are found and the spawn then fails, so the fallback carries it |
| Android | HTML | no command line tools to speak of |

The macOS behaviour is a deliberate trade: dropping `com.apple.security.app-sandbox`
would enable the PDF path (and keychain credential storage), and the official
Send to Kindle app indeed ships with no entitlements at all — but the sandbox is
worth more here than typeset output, given HTML is converted competently on
Amazon's side. The conversion therefore always produces something the service
accepts, and sending is blocked only while it runs.

## 8. Persistence

- Device credentials: OS keychain / encrypted storage under `kindbeamer_client`
  (JSON: `{version: 1, device_info: {...}}`), falling back to
  `credentials.json` (mode 600) in the app-support dir when no keychain is
  reachable. The pre-rename key `stk_next_client` is still read so an existing
  session survives the upgrade.
- `settings.json` in the app-support dir: last selected device serials, the
  library-copy tick, `close_on_success`, `appearance`, and this installation's
  device serial (the pid is derived from it, so it is not stored).
- Nothing else leaves the device; uploads go directly to Amazon endpoints.

## 9. UI

Single window, 720×645 (minimum 460×430), drawn as a dispatch label between two
barred airmail edges. Paper (#F2F1EC on #16171A ink) or night (a true
inversion); `Appearance` follows the system unless Settings pins one.

- header: wordmark (`kind` bold + `beamer` light, the split carried by weight
  rather than colour), *Add* and *Settings*
- **A CONTENTS**: the queued files, one typewritten row each with format and
  size in a fixed right-hand column; a converter's note prints under the box
- **B DESCRIPTION**: `TITLE` and `AUTHOR` on ruled lines, pre-filled from the
  file name; they edit the marked document
- **C DELIVER TO**: owned devices as numbered lanes in two columns (one column
  below 520px), `n OF m` and an ALL/NONE control on the legend line, and the
  library copy as the last row of the same box. The lanes are replaced by a
  sign-in prompt when logged out, skeleton lanes while they load, "no devices on
  this account" when the list comes back empty, and a `Trouble` well when it
  fails — what happened, what to do, `DETAILS` folding the raw answer away, and
  the one action that recovers it
- franking row: a progress rule, the postmark (idle / ready / the rim inking
  round while sending / struck solid on delivery / doubled in ink when held),
  the state sentence with a facts line under it, `CLEAR`/`CLOSE` and `SEND`
  (enabled only when signed in, queue non-empty, ≥1 device selected)
- drop and `?` overlays: the window turns over between its own barred edges —
  inverted in paper, plain in night, so a dark room is never flashed
- keys: `Enter` send (or sign in), `Esc` clear then close, `1`-`9`/`0` tick a
  lane, `A` all/none, `E` library copy, `Backspace` drop the marked document,
  mod+`O` add, mod+`,` settings, `?` the key list. Digits reaching a focused
  text field are left to it.
- after a delivery the window closes itself (`close_on_success`, default on);
  a failure always keeps it, with the reason and `RETRY`

### Failure

`Trouble` (`state/app_state.dart`) is what reaches the window instead of an
exception: a sentence in the app's own words, the recovery, the raw text, and
whether the recovery is a fresh pairing. `ApiError.isRegistrationRejected` (401,
403, or `DeviceInfoToken` in the body) is what separates the two kinds:

- **Registration rejected** — the credentials on this machine are dead and
  nothing retries past that, so the label opens the sign-in flow itself (once
  per failure, whether it surfaced from the device list at startup or from a
  send) and explains behind it. Enter and the franking block pair rather than
  retry; the device serial is kept, so signing in re-registers the same device
  rather than adding another.
- **Service or network** — `TRY AGAIN`, and Enter does the same.

A failed send puts its sentence in the franking row and its raw answer in the
band above it, dismissible; the device list keeps both inside section C.
- touch builds print no key caps, use 46dp rows, and say "tap" where the
  desktop says "press"

`tool/demo_main.dart` renders any of these states against a stand-in account
for screenshots; it never touches a real session.

## 10. Testing

- `signer_test.dart`: PKCS#1 parsing + digest header against a vector produced by
  an independent Python implementation of the padding/signing math.
- `oauth_test.dart`: redirect parsing, signin URL parameters (PKCE, client id).
- `ingest_test.dart`: PDF+EPUB acceptance, rejection/dedup, `file://` handling,
  unsupported-path reporting, human-readable sizes.
- `app_state_test.dart`: prefs round-trip, device identity persistence and
  migration, selection after removal, skip notice, send gating.
- `device_id_test.dart`: the pid derivation against the reference pair, plus the
  shape of generated serials and pids.
- `platform_capabilities_test.dart`: the per-platform network declarations and
  file-type registrations that only fail in a release build.
- `home_page_test.dart`: the label's sections and drop target; dropped PDF+EPUB
  populate the queue and drive the franking line; the conversion footnote;
  metadata editing; send gating and the sign-in prompt; the number, `A` and `E`
  keys; a digit typed into a field staying in the field; a whole delivery
  through a stand-in client, ending in a struck postmark and a window that
  closes itself; a failed send keeping the queue and offering `RETRY`; the key
  sheet; `CLEAR` then `CLOSE`.
- `support/fake_client.dart`: the stand-in `StkClient` those tests send through
  — it signs nothing and reaches no network.

CI (`.github/workflows/ci.yml`) runs `dart format --set-exit-if-changed`,
`flutter analyze` and `flutter test`, then builds macOS, Linux and Android and
uploads each as an artifact.

## 11. Build notes / known issues

- Requires Flutter stable ≥ 3.47 on macOS 27 (older tooling fails packaging:
  macOS 27's `lipo -verify_arch` accepts a single architecture per invocation,
  which older `flutter_tools` `thinFramework` does not handle).
- macOS deployment target is 12.0; the Podfile post-install hook lifts older pod
  targets to match.
- Android release signing reads `~/.apk-signing-keystore/signing.properties`
  when present and falls back to the debug keystore, so a fresh checkout builds
  without the publisher's key.
- The `INTERNET` permission has to be declared in the *main* Android manifest.
  Flutter's template declares it only in the debug and profile manifests (for
  the Dart VM service), so a release APK without it installs and runs while
  quietly having no network: a blank sign-in webview and every API call failing.
  This is the same class of bug as the missing macOS entitlement below, and
  `test/platform_capabilities_test.dart` now guards both.
- macOS builds here are ad-hoc signed (`CODE_SIGN_IDENTITY = "-"`), which means
  no keychain access group: `flutter_secure_storage` fails and the app falls
  back to the mode-600 credentials file inside its sandbox container. Signing
  with a real team identity restores keychain storage with no code change.
- The macOS sandbox needs `com.apple.security.network.client` (webview + API)
  and `com.apple.security.files.user-selected.read-only` (file dialog); both are
  in `Debug`/`Release` entitlements. Dropping either yields a blank sign-in
  webview or unreadable documents *only in release*, which is a miserable bug to
  chase.

## 12. Roadmap

- USB/MTP transfer for 2024+ Kindles (no mass-storage mode on macOS).
- Library management (list/delete personal documents).
- Windows packaging; iOS build.
- The official client now prefers a proxy endpoint,
  `/import/kindle-doc/send-to-kindle`, over the `/SendToKindle` used here (it
  calls the latter its "Legacy STK Service"); worth moving to before Amazon
  retires it.
- Localization.
- Notarized macOS build + signed Android release in CI.
