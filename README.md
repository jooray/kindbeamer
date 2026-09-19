# KindBeamer

[![CI](https://github.com/jooray/kindbeamer/actions/workflows/ci.yml/badge.svg)](https://github.com/jooray/kindbeamer/actions/workflows/ci.yml)

KindBeamer sends your documents to your Kindle devices. It is an unofficial,
open-source replacement for Amazon's *Send to Kindle* desktop app: one Flutter
codebase covering **macOS (Apple Silicon and Intel)**, **Linux** and
**Android**, with no Rosetta needed.

It talks to the same Send to Kindle cloud service the official app uses, so your
documents arrive over Wi-Fi on the devices you pick, and in your Kindle Library
if you want them there.

> **Disclaimer:** this project is not affiliated with, endorsed by, or sponsored by
> Amazon. "Kindle" and "Send to Kindle" are trademarks of Amazon.com, Inc.
> Use at your own risk; Amazon may change or block the undocumented API at any time.

## Features

- Dark UI with the official app's layout (document title and author, per-device
  checkboxes, "Archive document in your Kindle Library", format banner) in its
  own slate and teal palette.
- Drop files anywhere on the window, pick them with a file dialog, or receive
  them from the OS share mechanisms listed below.
- Multi-document queue: drop a PDF and an EPUB at once, edit the metadata of
  each, send them in one go, with upload progress per document.
- Device picker listing every registered Kindle device and app on your account.
- Sign-in with your Amazon account over OAuth (PKCE) in an embedded browser
  window. The long-lived device credentials then go into the OS keychain or
  encrypted storage, and no password is ever stored.
- Input formats: PDF, EPUB, MOBI, AZW/AZW3, TXT, RTF, DOC, DOCX, HTML, PNG,
  JPG, GIF, BMP.
- Markdown as well. A dropped `.md` is typeset into a PDF sized for a 6" reader
  where `pandoc` and a PDF engine (or a headless Chrome) can run, which in
  practice means Linux. Everywhere else it becomes styled HTML and Kindle
  converts it on its side, including on macOS, whose sandbox will not run
  external tools.

### Share / open recipient matrix

| Platform | Mechanisms |
|---|---|
| macOS | drag & drop onto the window, Finder *Open With*, dock drop, macOS **Services** menu ("Send with KindBeamer") |
| Linux | drag & drop, file-manager *Open With* (`.desktop` file with MIME types, see `packaging/linux/`), command-line args |
| Android | system **share sheet** (single & multiple files), *Open with* for documents |

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

The Android build needs a JDK between 17 and 21, because Gradle 8.14 refuses
anything newer. If your default JDK is more recent:

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

Point the `Exec=` line at your installed binary or bundle first.

## Usage

1. Launch the app and press **Sign in**, then complete the Amazon login in the
   window that opens. (Linux has no embedded browser, so there the app opens
   your system browser and lets you paste the redirect URL instead.)
2. Drop one or more documents onto the window, or use **Add files…**, the share
   sheet, the Services menu.
3. Adjust the title and author of the selected document, tick the target
   devices, and choose whether to archive in your Kindle Library.
4. Press **Send**. The documents are uploaded to Amazon and delivered to the
   devices you ticked over Wi-Fi.

Signing in registers that installation as a device on your Amazon account, shown
as "KindBeamer (your computer's name)" or "KindBeamer (Android)". Each
installation registers on its own, so a laptop and a phone can both stay signed
in. **Settings → Sign out** unregisters the one you are on and deletes its local
credentials.

### Where credentials live

The Amazon device credentials go into the OS keychain or encrypted storage.
Where no keychain is reachable, on Linux without a secret service or in an
ad-hoc signed macOS build, the app falls back to a mode-600 file in its
application-support directory, and **Settings** says which of the two it used.

## How it works

See [SPECIFICATION.md](SPECIFICATION.md) for the architecture and a full
description of the wire protocol: OAuth PKCE device registration, signed
`stkservice.amazon.com` calls, S3 upload, delivery.

The protocol implementation is a clean-room Dart port of the approach taken by
[stkclient](https://github.com/maxdjohnson/stkclient) (MIT). Thanks to its
author for working the protocol out first.

## Development

```bash
flutter analyze
flutter test
```

The tests cover the RSA request signer and the device pid derivation against
reference vectors, OAuth code parsing, file ingestion (PDF and EPUB drops,
filtering, dedup), Markdown conversion, app state (device identity,
preferences, queue handling), the per-platform release declarations that only
fail in a release build, and the main window widget tree. CI runs the same
checks and builds macOS, Linux and Android on every push.

## License

MIT, see [LICENSE](LICENSE). The app icon was generated with Venice
`nano-banana-2`; the master art is `assets/icon/icon-1024.png`, and
`tools/make_icons.py` derives the per-platform sets from it (macOS
`.appiconset`, Android adaptive icon, Linux PNG).
