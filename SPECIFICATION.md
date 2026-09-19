# Specification — Send to Kindle Next

Unofficial cross-platform (macOS / Linux / Android) client for Amazon's
*Send to Kindle* cloud service, built with Flutter. This document describes the
architecture, the wire protocol and the platform integration.

> Not affiliated with Amazon. The protocol below is undocumented and was derived
> from observing the official clients; see `stkclient` for prior art.

## 1. Goals / non-goals

Goals:

- Faithful replacement for the official desktop app's core flow:
  pick documents → pick devices → send over Wi-Fi → optional library archive.
- Native feel on every platform, dark UI modeled on the official app.
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
      theme.dart                colors / dark theme
      home_page.dart            main window (header, doc list, devices, footer, drop)
      login_dialog.dart         embedded webview login + paste-URL fallback
      settings_dialog.dart      account / sign out / refresh
```

State management is a single `ChangeNotifier` (`AppState`) consumed through
`ListenableBuilder`; no external state package. UI is Material 3 with a custom
dark palette sampled from the official app (charcoal surfaces, Kindle orange
accent, blue primary action).

## 3. Authentication

1. App generates a PKCE verifier (32 random bytes, base64url, unpadded) and
   builds the signin URL `https://www.amazon.com/ap/signin` with the OpenID/OAuth2
   parameters used by official device clients, notably
   `openid.oa2.client_id=device:<client-id>`, `openid.oa2.scope=device_auth_access`,
   `openid.oa2.code_challenge_method=S256` and
   `openid.return_to=https://www.amazon.com/gp/sendtokindle`.
2. The URL is loaded in an embedded webview (macOS/Android/iOS/Windows). When the
   webview navigates to the `return_to` URL carrying
   `openid.oa2.authorization_code=…`, the code is captured and the webview closes.
   Platforms without a webview (Linux) open the system browser and offer a
   "paste the redirect URL" field.
3. `POST https://api.amazon.com/auth/token` exchanges the code (+ verifier) for
   an access token (`source_token_type=authorization_code`,
   `client_domain=DeviceLegacy`, same public client id).
4. `POST https://firs-ta-g7g.amazon.com/FirsProxy/registerDeviceWithToken` with an
   XML body (device type / serial / pid / software version mimicking the official
   Mac client) returns the long-lived device credentials as XML:
   `device_private_key` (PKCS#1 RSA PEM), `adp_token`, plus account metadata.
5. The access token is discarded; only the device credentials are persisted
   (keychain / encrypted shared preferences; plaintext file with default
   permissions only as a last-resort fallback on Linux without a secret service).

Sign-out calls `GET /FirsProxy/disownFiona?contentDeleted=false` (signed) and
deletes local credentials.

## 4. Request signing (`X-ADP-Request-Digest`)

Every call to `https://stkservice.amazon.com` and the Firs proxy carries:

- `X-ADP-Authentication-Token: <adp_token>`
- `X-ADP-Request-Digest: <base64(sig)>:<UTC iso8601 seconds>Z`

where `sig` is raw RSA over a custom PKCS#1-v1.5-style block:

```
sig_data  = METHOD \n PATH \n DATE \n BODY \n ADP_TOKEN      (UTF-8, SHA-256)
EM        = 0x01 || 0xFF * (256 - 32 - 2) || 0x00 || sha256(sig_data)
sig       = (EM as big-endian integer) ^ d mod n            (256-byte output)
```

Note the padding omits the ASN.1 DigestInfo prefix used by textbook PKCS#1; this
matches what the service verifies. `lib/src/amazon/signer.dart` implements this
with `BigInt.modPow` and a minimal DER parser for PKCS#1 PEM private keys, and is
validated against a reference vector generated with the original algorithm
(`test/signer_test.dart`).

## 5. Send-to-Kindle API

All bodies are JSON with a `ClientInfo` block (`appName: ShellExtension`,
`appVersion: 1.1.1.253`, per-platform `os`/`osArchitecture`) merged in.

| Step | Request | Purpose |
|---|---|---|
| list devices | `POST stkservice.amazon.com/GetListOfOwnedDevices` `{}` | `ownedDevices[]` with names, serials, capabilities |
| upload url | `POST stkservice.amazon.com/GetUploadUrl` `{"fileSize": n}` | presigned `uploadUrl` + `stkToken` |
| upload | `PUT <uploadUrl>` body = raw file bytes, `Content-Length` set | S3 |
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
serials ticked in the device list. Multiple queued documents are sent
sequentially, each with its own metadata and upload.

## 6. File intake ("share recipient")

Common path: `Ingest.filterAccepted` normalizes `file://` URLs, drops unknown
extensions and duplicates; `Ingest.itemsFor` stats each file and builds
`DocItem`s (default title = basename without extension).

| Source | Wiring |
|---|---|
| window drag & drop (desktop) | `desktop_drop` `DropTarget` around the whole window |
| file dialog | `file_selector` `openFiles` with extension type group |
| CLI args / "Open With" (desktop) | `main(List<String> args)` |
| macOS Services menu | `NSServices` entry (`sendFilesToKindle`) in `Info.plist`; `AppDelegate` installs an `NSPasteboard` service provider; paths are queued in-process and pulled over `MethodChannel('dev.stkn/services')` `takePendingFiles` on launch/resume |
| macOS Open With / dock drop | `CFBundleDocumentTypes` (pdf, epub, txt/html/doc(x)/mobi/azw…) |
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

Anything else is rejected at intake with a snackbar explaining the supported set.

## 8. Persistence

- `credentials.json` equivalent: OS keychain / encrypted storage key
  `stk_next_client` (JSON: `{version: 1, device_info: {...}}`), plaintext file in
  the app-support dir only if secure storage is unavailable.
- `settings.json` in the app-support dir: last selected device serials and the
  archive checkbox.
- Nothing else leaves the device; uploads go directly to Amazon endpoints.

## 9. UI

Single window, ~1024×860, dark:

- header: wordmark (`send to` light + `kindle` orange + `next` tag), *Add files…*
- "Your document": queued file list (select/remove), title + author fields for
  the selected item
- "Delivery options": checkbox list of owned devices; sign-in prompt when logged out
- archive checkbox in an outlined box; selected document size
- status strip: "Your document will be sent in <FORMAT> format." /
  "No valid document is selected to send." / send progress
- footer: Settings | Need Help? | Manage your Kindle links, Cancel + Send pills
  (Send enabled only when signed in, queue non-empty, ≥1 device selected)
- drag overlay: translucent veil, upload glyph, "Drop files here / to send to
  your Kindle" in orange

## 10. Testing

- `signer_test.dart`: PKCS#1 parsing + digest header against a vector produced by
  an independent Python implementation of the padding/signing math.
- `oauth_test.dart`: redirect parsing, signin URL parameters (PKCE, client id).
- `ingest_test.dart`: PDF+EPUB acceptance, rejection/dedup, `file://` handling,
  human-readable sizes.
- `home_page_test.dart`: window is a `DropTarget`; dropped PDF+EPUB populate the
  queue and drive the format banner; metadata editing; send gating; removal.

CI suggestion: `flutter analyze && flutter test`, then
`flutter build macos|linux|apk`.

## 11. Build notes / known issues

- Requires Flutter stable ≥ 3.47 on macOS 27 (older tooling fails packaging:
  macOS 27's `lipo -verify_arch` accepts a single architecture per invocation,
  which older `flutter_tools` `thinFramework` does not handle).
- macOS deployment target is 12.0; the Podfile post-install hook lifts older pod
  targets to match.
- Android release signing is left to the packager (default debug keystore for
  `flutter run`).

## 12. Roadmap

- USB/MTP transfer for 2024+ Kindles (no mass-storage mode on macOS).
- Library management (list/delete personal documents).
- Windows packaging; iOS build.
- Progress bars per document (S3 PUT with streamed body + length).
- Localization.
