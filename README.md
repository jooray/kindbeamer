# KindBeamer

[![CI](https://github.com/jooray/kindbeamer/actions/workflows/ci.yml/badge.svg)](https://github.com/jooray/kindbeamer/actions/workflows/ci.yml)

KindBeamer sends your documents to your Kindle devices. It is an unofficial,
open-source replacement for Amazon's *Send to Kindle* desktop app: one Flutter
codebase covering **macOS (Apple Silicon and Intel)**, **Linux** and
**Android**, with no Rosetta needed.

<!-- jooray-links:start -->
### More from me

**Related projects**

- [rss2podcast](https://github.com/jooray/rss2podcast): turn blogs and articles into a podcast
- [markdown2audio](https://github.com/jooray/markdown2audio): convert Markdown to audio with StyleTTS
- [livecaster-llm](https://github.com/jooray/livecaster-llm): live co-pilot for podcast hosts

**Full project showcase:** [KindBeamer in my project showcase](https://juraj.bednar.io/showcase/#MED-01), or [all my projects](https://juraj.bednar.io/showcase/).

I write about building things on [my blog](https://juraj.bednar.io/en/blog-en/). I also wrote a cypherpunk novel, [Tamers of Entropy](https://tamersofentropy.net/), and there is a [trailer](https://tamersofentropy.net/#trailer).
<!-- jooray-links:end -->

It talks to the same Send to Kindle cloud service the official app uses, so your
documents arrive over Wi-Fi on the devices you pick, and in your Kindle Library
if you want them there.

<img src="docs/screenshot-macos.png" alt="KindBeamer on macOS: a dispatch label with a queued PDF, its title and author, seven Kindle devices in two numbered columns with three ticked, and a postmark beside the Send button" width="720">

> **Disclaimer:** this project is not affiliated with, endorsed by, or sponsored
> by Amazon. Use at your own risk; Amazon may change or block the undocumented
> API at any time.

## Install

### Browser extension

Firefox: [Firefox Add-ons](https://addons.mozilla.org/addon/kindbeamer/).
Chrome and other Chromium browsers: see [Installing the extension](#installing-the-extension).

### Android

Install it from [Zapstore](https://zapstore.dev/apps/dev.stkn.kindbeamer),
which will also keep it updated. Zapstore itself is at
[zapstore.dev](https://zapstore.dev).

Otherwise grab `KindBeamer-<version>.apk` from the
[latest release](https://github.com/jooray/kindbeamer/releases/latest) and open
it on the phone. Android will ask you to allow installs from that source.

### macOS

Download `KindBeamer-<version>.dmg` from the
[latest release](https://github.com/jooray/kindbeamer/releases/latest) and drag
the app into Applications.

The build is signed with a self-managed key rather than an Apple Developer
certificate, so Gatekeeper will refuse it on the first launch. Either right
click the app and choose Open, or clear the quarantine flag:

```bash
xattr -dr com.apple.quarantine /Applications/KindBeamer.app
```

### Linux

Take the tarball for your architecture from the
[latest release](https://github.com/jooray/kindbeamer/releases/latest):
`-linux-x64` for a normal PC, `-linux-arm64` for Omarchy on Apple silicon,
Asahi or an ARM box.

```bash
tar -xzf KindBeamer-1.0.1-linux-x64.tar.gz
./bundle/kindbeamer
```

It needs GTK 3 and glibc 2.34 or newer, which any current distribution has. On
Arch: `pacman -S gtk3 libsecret`, the second being what puts your Amazon
credentials in the keyring rather than a file. Move the bundle wherever you
keep such things and point the `.desktop` file in `packaging/linux/` at it for
"Open With" support.

## Features

- One window, laid out as a dispatch label: contents, description, the devices
  to deliver to, and a franking row that states the facts and sends. It opens
  already addressed — the file you dropped, a title from its name, the devices
  you ticked last time — so the usual visit is Enter.
- Monochrome e-paper, inverted at night and following the system by default.
  Nothing in the app is carried by colour, so it reads the same on any screen.
- A delivered send closes the window, unless Settings says otherwise; a failed
  one keeps it, with the reason on the label — in the app's own words, with the
  raw answer from Amazon folded away behind **Details**.
- When Amazon stops accepting this installation's registration, which it does
  when a session goes stale, the app opens the sign-in flow itself instead of
  leaving an error on screen. Signing in re-registers the same device, so your
  Kindles and the documents already on them are untouched.
- Keyboard-first: **Enter** sends, **Esc** clears then closes, **1-9** and
  **0** tick the device on that line, **A** takes all or none, **E** keeps the
  library copy, **R** switches a PDF's layout, **?** prints the key list.
- Drop files anywhere on the window, pick them with a file dialog, or receive
  them from the OS share mechanisms listed below.
- Multi-document queue: drop a PDF and an EPUB at once, edit the metadata of
  each, send them in one go, with upload progress per document.
- Every registered Kindle device and app on your account, in two numbered
  columns so a long list needs no scrolling.
- Sign-in with your Amazon account over OAuth (PKCE) in an embedded browser
  window. The long-lived device credentials then go into the OS keychain or
  encrypted storage, and no password is ever stored.
- PDFs arrive the way they were laid out, page for page, unless you tick
  *Reformatted for your Kindle* to have Amazon reflow them into a book whose
  text follows the reader's font size. The choice shows only while a PDF is
  queued, and the last one is kept for next time.
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
| macOS | drag & drop onto the window, Finder *Open With*, dock drop, macOS **Services** menu ("Send with KindBeamer"), the `kindbeamer` command (see [From a script](#from-a-script)) |
| Linux | drag & drop, file-manager *Open With* (`.desktop` file with MIME types, see `packaging/linux/`), command-line args, `--send` (see [From a script](#from-a-script)) |
| Android | system **share sheet** (single & multiple files), *Open with* for documents, **Print → KindBeamer** from any app (see [Printing to your Kindle](#printing-to-your-kindle-android)) |

### Printing to your Kindle (Android)

KindBeamer is also a printer. Print from any app that can print (in Chrome,
**⋮ → Share → Print**), choose **KindBeamer (Send to Kindle)**, and the PDF
lands in KindBeamer ready to send. A web page goes exactly as your browser shows it,
so pages behind a login or a paywall come out whole, and the paper defaults
to a Kindle-shaped 6 × 8 in page (a Kindle Scribe page and A5 are offered
too). Leave the layout on *Original PDF formatting* for page-perfect copies,
or tick *Reformatted for your Kindle* to have Amazon reflow the text.

Turn it on once: **Settings → Print settings** in KindBeamer opens the system's
printing screen, where KindBeamer is switched on. The first time you print to
it, Android asks to confirm that documents may pass through the print service.

What happens next is up to you, under **Settings → Print to Kindle**:

- **Check it first** (the default). Android does not let a printer open an
  app by itself, so a **Ready to send to your Kindle** notification appears;
  tap it and KindBeamer opens with the page queued. KindBeamer asks for
  permission to show that notification the first time a printed page reaches
  it. Without notifications the page still waits there, and is queued the
  next time you open KindBeamer.
- **Send printed pages right away to the ticked Kindles.** Printing is then
  the whole job: the page goes to the Kindles you ticked last, with your last
  layout and library-copy choice. Android's own "Printing…" notification
  shows it under way, and a **Sent to your Kindle** notification says where
  it went. If a send fails (not signed in, offline), the page waits in
  KindBeamer with the reason, a tap away.

## Usage

1. Launch the app and press **Sign in** (or just **Enter**), then complete the
   Amazon login in the window that opens. (Linux has no embedded browser, so
   there the app opens your system browser and lets you paste the redirect URL
   instead.)
2. Open a document with KindBeamer — *Open With*, the share sheet, the Services
   menu, a drop onto the window, **Add files…**, or a path on the command line.
3. Press **Enter**. The label already carries the title, the devices you used
   last time and the library copy; change any of them first if you want to.
4. The postmark inks round as the upload goes, strikes solid on delivery, and
   the window leaves. Only a failure stays on screen, and it names the cause.

### Keys

| Key | What it does |
|---|---|
| `Enter` | Send — or sign in, when signed out |
| `Esc` | Clear the queue; with nothing queued, close the window |
| `1`…`9`, `0` | Tick the device on that line |
| `A` | All devices, or none |
| `E` | Keep a copy in your Kindle Library |
| `Backspace` | Drop the marked document |
| `⌘O` / `Ctrl+O` | Add files |
| `⌘,` / `Ctrl+,` | Settings |
| `?` | The list above, on the window |

Digits typed into the title or author field stay in the field.

Signing in registers that installation as a device on your Amazon account, shown
as "KindBeamer (your computer's name)" or "KindBeamer (Android)". Each
installation registers on its own, so a laptop and a phone can both stay signed
in. **Settings → Sign out** unregisters the one you are on and deletes its local
credentials.

### From a script

Launched with `--send`, KindBeamer sends the files it was given and quits,
with nothing to click. It uses the sign-in and the settings the window keeps,
prints one line saying what happened, and leaves an exit status a script can
test. Sign in once in the window first.

```bash
kindbeamer [--all-devices | --device NAME ...] [--title TITLE] \
           [--author AUTHOR] [--original-pdf | --reformat-pdf] \
           [--dry-run] FILE...
```

- With no device option it delivers to the devices ticked in the window last
  time (the first device if none is ticked). `--all-devices` takes every
  device on the account. `--device` matches a device name, case-insensitively,
  or a serial number, and can be repeated. A send from the command line never
  changes the ticks the window remembers.
- `--title` (one file only) and `--author` override the metadata. The title
  otherwise comes from the file name. The library copy follows the window's
  setting.
- `--original-pdf` keeps a PDF's own pages; `--reformat-pdf` has Amazon reflow
  it for the Kindle. Without either, PDFs follow the window's last choice, and
  neither flag changes it. Other formats are unaffected.
- `--dry-run` loads the sign-in, lists the devices and checks the files, then
  stops short of uploading.
- Exit status: `0` sent, `1` failed, `2` bad usage (unknown option, unknown
  device, no sendable file), `3` not signed in or the registration was
  retired. Open the window and sign in to fix the last one.

```console
$ kindbeamer --device Daylight guide.pdf
KindBeamer: sent "guide" to Daylight
```

**macOS.** The app is sandboxed and may only read files that Launch Services
hands it, so the command is a wrapper script,
[`packaging/macos/kindbeamer`](packaging/macos/kindbeamer). It opens the files
with a fresh instance of the installed app (`open -n -W … --args --send …`,
which works even while the window is open), waits for it to quit, and turns
its result line into the exit status. Put it on your `PATH`:

```bash
install -m 755 packaging/macos/kindbeamer ~/.local/bin/kindbeamer
```

It looks for `/Applications/KindBeamer.app`, then
`~/Applications/KindBeamer.app`; set `KINDBEAMER_APP` to use another bundle.
Running `KindBeamer.app/Contents/MacOS/KindBeamer --send FILE` directly fails
with *cannot read*, because of the sandbox.

**Linux.** No wrapper needed: `./bundle/kindbeamer --send FILE` sends, prints
the result and exits with the status itself.

### Where credentials live

The Amazon device credentials go into the OS keychain or encrypted storage.
Where no keychain is reachable, on Linux without a secret service or in a
macOS build signed with a self-managed key, the app falls back to a mode-600
file in its application-support directory, and **Settings** says which of the
two it used.

## Browser extension

KindBeamer also comes as a browser extension for Firefox and for Chrome, Edge,
Brave and other Chromium browsers. It sends the page you are reading to your
Kindle. Press the KindBeamer button in the toolbar, or **Alt+Shift+B**, and a
tab opens next to the page:

- **An article** arrives with only the article itself: no menus, sidebars or
  comments, just the text and its pictures, previewed the way the book will
  read. Check the title and author, tick your Kindles and press **Send**.
  **EPUB** saves the same book to disk instead.
- **A PDF** open in the browser goes out as the file itself, with the same
  *Original PDF formatting* / *Reformatted for your Kindle* choice as the app
  (**R** switches it). If the browser has not let the extension read that
  site yet, an **Allow** button asks for access to just that site.

How it does it:

- The article is read with [Readability](https://github.com/mozilla/readability),
  the engine behind Firefox's Reader View, from the page as your browser shows
  it. Pages behind a login or a subscription you hold work too, as long as you
  can read them.
- Images are fetched and packed into an EPUB, re-encoded where Kindle would
  not take them (WebP, AVIF, SVG) and scaled to at most 1600px. Images hosted
  on another site need access to all sites, which the extension asks for the
  first time you send. If you decline, those images are left out.
- It talks to Amazon itself, the same way the app does. Sign in once with your
  Amazon account and the browser registers as a device of its own, named like
  *KindBeamer (Firefox on macOS)*. No email address and no server in between.
- It stores nothing but the device credentials and your last choices, in the
  extension's own storage.

### Installing the extension

**Firefox:** install it from
[Firefox Add-ons](https://addons.mozilla.org/addon/kindbeamer/), which also
keeps it updated.

**Chrome, Edge, Brave, Vivaldi** and other Chromium browsers: the files are on
the [extension releases](https://github.com/jooray/kindbeamer/releases?q=extension&expanded=true)
page.

1. Unzip `kindbeamer-chrome-*.zip` to a folder you will keep. The browser loads
   the extension from that folder every time it starts, so don't delete it.
2. Open `chrome://extensions` (`edge://extensions` in Edge) and turn on
   **Developer mode**.
3. Choose **Load unpacked** and pick the folder.

To update, unzip the new release over the same folder and press the reload
arrow on the extension's card. The extension keeps its sign-in.

In either browser, pin the button to the toolbar from the extensions menu (the
puzzle piece) if the browser put it there.

To build the extension yourself:

```bash
cd extension && node build.mjs      # dist/firefox, dist/chrome and a zip of each
```

## How it works

See [SPECIFICATION.md](SPECIFICATION.md) for the architecture and a full
description of the wire protocol: OAuth PKCE device registration, signed
`stkservice.amazon.com` calls, S3 upload, delivery.

The protocol implementation is a clean-room Dart port of the approach taken by
[stkclient](https://github.com/maxdjohnson/stkclient) (MIT). Thanks to its
author for working the protocol out first.

## Building from source

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

### Installing the Linux desktop entry

```bash
sudo install -Dm644 packaging/linux/dev.stkn.kindbeamer.png \
  /usr/share/icons/hicolor/512x512/apps/dev.stkn.kindbeamer.png
sudo desktop-file-install --mode=0755 \
  --dir=/usr/share/applications \
  packaging/linux/dev.stkn.kindbeamer.desktop
update-desktop-database /usr/share/applications
```

Point the `Exec=` line at your installed binary or bundle first.

### Tests

```bash
flutter analyze
flutter test
```

The tests cover the RSA request signer and the device pid derivation against
reference vectors, OAuth code parsing, file ingestion (PDF and EPUB drops,
filtering, dedup), Markdown conversion, app state (device identity,
preferences, queue handling), the per-platform release declarations that only
fail in a release build, and the main window widget tree. CI runs the same
checks and builds macOS, Android and Linux (x86-64 and arm64) on every push.

The browser extension has its own (Node 22 or later):

```bash
cd extension && node --test test/*.test.mjs
```

They check its request signer and pid derivation against the same reference
vectors, and the EPUB it writes (with `epubcheck`, when it is installed).

## BTW

The book in the screenshot is a real one, and mine.
[Tamers of Entropy](https://tamersofentropy.net/) is a lunarpunk novel about
identity, parallel spaces, AI, space and expanding consciousness. Paperback,
ebook and audiobook, in English, Slovak and Czech. There is a
[trailer](https://youtu.be/APLe95FRUhg).

## Related projects

KindBeamer exists because other people worked the protocol out first. None of
these projects are ours.

- [stkclient](https://github.com/maxdjohnson/stkclient) is a Python library for
  Amazon's Send to Kindle service. KindBeamer's protocol code is a clean-room
  Dart port of the approach it takes.
- [sendKindle](https://github.com/kparal/sendKindle) is the original
  command-line tool for mailing documents to a Kindle. Its last code change was
  in 2019 and the repository is now archived, so it takes no issues or pull
  requests. Its author asks anyone who wants it revived to fork it.
- [kindle-send](https://github.com/nikhil1raghav/kindle-send) sends web pages
  and documents from the terminal. It turns a URL into an EPUB first, which
  makes it a good fit for scripted page archiving.
- [sendtokindle](https://github.com/miracle2k/sendtokindle) is an earlier
  Ubuntu-only GUI for the same job. Nothing has been committed to it since
  2016, and its app indicator no longer fits current desktops.
- [KindleEar](https://github.com/cdhigh/KindleEar) runs Calibre recipes on a
  schedule and pushes news, RSS feeds and EPUBs to your Kindle.
- The [Send to Kindle Calibre plugin](https://github.com/bookfere/Send-to-Kindle-Calibre-Plugin)
  is for people who already live inside Calibre.

They differ mostly in how the file travels. stkclient goes to Amazon's service
over HTTP, the way KindBeamer does. The others hand the document to Amazon's
mail gateway, which means a mail account of your own and whatever attachment
limit it comes with.

## License

MIT, see [LICENSE](LICENSE). The app icon is drawn rather than generated:
`tools/make_icons.py` paints the master art at `assets/icon/icon-1024.png` and
derives the per-platform sets from it (macOS `.appiconset`, Android adaptive
icon, Linux PNG).
