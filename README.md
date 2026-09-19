# Send to Kindle Next

An unofficial, open-source replacement for Amazon's *Send to Kindle* desktop app.
One Flutter codebase for **macOS (Apple Silicon & Intel)**, **Linux** and **Android** —
no Rosetta required.

It talks to the same Send to Kindle cloud service the official app uses, so your
documents are delivered over Wi-Fi to the exact devices you pick, and (optionally)
archived in your Kindle Library.

> **Disclaimer:** this project is not affiliated with, endorsed by, or sponsored by
> Amazon. "Kindle" and "Send to Kindle" are trademarks of Amazon.com, Inc.
> Use at your own risk; Amazon may change or block the undocumented API at any time.

## Features

- Dark UI modeled on the official Send to Kindle app: document title/author,
  per-device checkboxes, "Archive document in your Kindle Library", format banner.
- **Drop files anywhere** on the window, pick them with a file dialog, or receive
  them from the OS share mechanisms (see matrix below).
- Multi-document queue: drop a PDF *and* an EPUB at once, edit metadata per file,
  send everything in one go.
- Device picker listing every registered Kindle device/app on your account.
- Sign-in with your Amazon account via OAuth (PKCE) in an embedded browser window;
  long-lived device credentials are then stored in the OS keychain / encrypted
  storage. No password is ever stored.
- Supported input formats: PDF, EPUB, MOBI, AZW/AZW3, TXT, RTF, DOC, DOCX,
  HTML, PNG, JPG, GIF, BMP.

### Share / open recipient matrix

| Platform | Mechanisms |
|---|---|
| macOS | drag & drop onto the window, Finder *Open With*, dock drop, macOS **Services** menu ("Send to Kindle Next"), command-line args |
| Linux | drag & drop, file-manager *Open With* (`.desktop` file with MIME types, see `packaging/linux/`), command-line args |
| Android | system **share sheet** (single & multiple files), *Open with* for PDF/EPUB |

## Getting started

Requirements: Flutter 3.47+ (stable).

```bash
flutter pub get
flutter run -d macos     # or: -d linux, an Android device/emulator
```

Release builds:

```bash
flutter build macos      # build/macos/Build/Products/Release/send_to_kindle_next.app
flutter build linux      # build/linux/x64/release/bundle/
flutter build apk        # build/app/outputs/flutter-apk/app-release.apk
```

### Linux installation (optional, for "Open With" support)

```bash
sudo desktop-file-install --mode=0755 \
  --dir=/usr/share/applications \
  packaging/linux/dev.stkn.send_to_kindle_next.desktop
update-mime-database /usr/share/mime   # if needed
```

Point the `Exec=` line at your installed binary/bundle first.

## Usage

1. Launch the app and press **Sign in**; complete the Amazon login in the window
   that opens. (On platforms without an embedded browser the app opens your
   system browser and lets you paste the redirect URL instead.)
2. Drop one or more documents onto the window (or use **Add files…**, the share
   sheet, Services menu, etc.).
3. Adjust title/author for the selected document, tick the target devices,
   choose whether to archive in your Kindle Library.
4. Press **Send**. Documents are uploaded to Amazon and delivered to the selected
   devices over Wi-Fi.

## How it works

See [SPECIFICATION.md](SPECIFICATION.md) for the architecture and a full
description of the wire protocol (OAuth PKCE device registration, signed
`stkservice.amazon.com` calls, S3 upload, delivery).

The protocol implementation is a clean-room Dart port of the approach pioneered
by [stkclient](https://github.com/maxdjohnson/stkclient) (MIT), with gratitude.

## Development

```bash
flutter analyze
flutter test
```

The test suite covers the RSA request signer against a reference vector,
OAuth code parsing, file ingestion (PDF + EPUB drops, filtering, dedup) and the
main window widget tree.

## License

MIT — see [LICENSE](LICENSE).
