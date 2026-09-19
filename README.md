# KindBeamer

[![CI](https://github.com/jooray/kindbeamer/actions/workflows/ci.yml/badge.svg)](https://github.com/jooray/kindbeamer/actions/workflows/ci.yml)

KindBeamer beams your documents to your Kindle devices: an unofficial,
open-source replacement for Amazon's *Send to Kindle* desktop app.
One Flutter codebase for **macOS (Apple Silicon & Intel)**, **Linux** and **Android** —
no Rosetta required.

It talks to the same Send to Kindle cloud service the official app uses, so your
documents are delivered over Wi-Fi to the exact devices you pick, and (optionally)
archived in your Kindle Library.

> **Disclaimer:** this project is not affiliated with, endorsed by, or sponsored by
> Amazon. "Kindle" and "Send to Kindle" are trademarks of Amazon.com, Inc.
> Use at your own risk; Amazon may change or block the undocumented API at any time.

## Features

- Dark UI with the official app's layout — document title/author, per-device
  checkboxes, "Archive document in your Kindle Library", format banner — in its
  own slate-and-teal palette.
- **Drop files anywhere** on the window, pick them with a file dialog, or receive
  them from the OS share mechanisms (see matrix below).
- Multi-document queue: drop a PDF *and* an EPUB at once, edit metadata per file,
  send everything in one go, with per-document upload progress.
- Device picker listing every registered Kindle device/app on your account.
- Sign-in with your Amazon account via OAuth (PKCE) in an embedded browser window;
  long-lived device credentials are then stored in the OS keychain / encrypted
  storage. No password is ever stored.
- Supported input formats: PDF, EPUB, MOBI, AZW/AZW3, TXT, RTF, DOC, DOCX,
  HTML, PNG, JPG, GIF, BMP.
- **Markdown too**: a dropped `.md` is typeset into a PDF sized for a 6" reader
  when `pandoc` and a PDF engine (or a headless Chrome) are available — in
  practice on Linux — and otherwise rendered to styled HTML, which Kindle
  converts on its side. macOS takes the HTML route as well, because its sandbox
  does not allow running external tools.

### Share / open recipient matrix

| Platform | Mechanisms |
|---|---|
| macOS | drag & drop onto the window, Finder *Open With*, dock drop, macOS **Services** menu ("Send with KindBeamer"), command-line args |
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
flutter build macos      # build/macos/Build/Products/Release/KindBeamer.app
flutter build linux      # build/linux/x64/release/bundle/
flutter build apk        # build/app/outputs/flutter-apk/app-release.apk
```

The Android build needs a JDK between 17 and 21 — Gradle 8.14 refuses anything
newer. If your default JDK is more recent:

```bash
flutter config --jdk-dir=/path/to/jdk-17
```

### Linux installation (optional, for "Open With" support)

```bash
sudo install -Dm644 packaging/linux/dev.stkn.kindbeamer.png \
  /usr/share/icons/hicolor/512x512/apps/dev.stkn.kindbeamer.png
sudo desktop-file-install --mode=0755 \
  --dir=/usr/share/applications \
  packaging/linux/dev.stkn.kindbeamer.desktop
update-desktop-database /usr/share/applications
```

Point the `Exec=` line at your installed binary/bundle first.

## Usage

1. Launch the app and press **Sign in**; complete the Amazon login in the window
   that opens. (On Linux, which has no embedded browser, the app opens your
   system browser and lets you paste the redirect URL instead.)
2. Drop one or more documents onto the window (or use **Add files…**, the share
   sheet, Services menu, etc.).
3. Adjust title/author for the selected document, tick the target devices,
   choose whether to archive in your Kindle Library.
4. Press **Send**. Documents are uploaded to Amazon and delivered to the selected
   devices over Wi-Fi.

Signing in registers this installation as a device on your Amazon account (it
shows up as "KindBeamer"); **Settings → Sign out** unregisters it again and
deletes the local credentials.

### Where credentials live

The Amazon device credentials go into the OS keychain / encrypted storage. Where
no keychain is reachable — Linux without a secret service, or an ad-hoc signed
macOS build — the app falls back to a mode-600 file in its application-support
directory and says so in **Settings**.

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

The test suite covers the RSA request signer against a reference vector, OAuth
code parsing, file ingestion (PDF + EPUB drops, filtering, dedup), app state
(device serial persistence, preferences, queue handling) and the main window
widget tree. CI runs the same checks plus macOS, Linux and Android builds on
every push.

## License

MIT — see [LICENSE](LICENSE). App icon generated with Venice `nano-banana-2`;
the master art is `assets/icon/icon-1024.png` and the per-platform sets
(macOS `.appiconset`, Android adaptive icon, Linux PNG) are derived from it.
