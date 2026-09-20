# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

Technical readers: people who own Kindle devices and read their own documents
(DRM-free PDFs and EPUBs, articles saved to PDF, Markdown notes) on E-ink.
Comfortable installing from a tarball, clearing a quarantine flag, or using a
package manager; not necessarily willing to debug the app itself. The strongest
pull is Linux, where Amazon ships no desktop client at all; macOS users of the
official *Send to Kindle* app are the other main group, and Android users share
files from other apps.

## Product Purpose

Get a reader's own documents onto their Kindle devices over Wi-Fi, as a
no-nonsense replacement for Amazon's official *Send to Kindle* desktop app.
Success means a user picks files from wherever they already are, ticks the
devices they want, and the documents arrive — on macOS, Linux and Android,
without Rosetta, an Amazon website round-trip, or a server in between.

## Positioning

A clean-room, open-source implementation of Amazon's undocumented Send to
Kindle protocol in one Flutter codebase spanning macOS, Linux and Android.
Neighboring clients are either platform-specific, closed, or require shipping
credentials through a third party; KindBeamer keeps every credential on the
machine and registers each installation as its own Kindle device. On Linux it
is effectively the only option.

## Operating Context

- Documents arrive by drag & drop, a file dialog, or the OS mechanisms:
  Finder *Open With*, dock drop and the macOS **Services** menu; file-manager
  *Open With* and command-line arguments on Linux; the Android share sheet and
  *Open with*.
- The user signs in with their Amazon account over OAuth (PKCE) in an embedded
  browser; each installation registers itself as "KindBeamer (<computer name>)"
  or "KindBeamer (Android)" on the account. Linux without a secret service opens
  the system browser and takes a pasted redirect URL instead.
- Delivery targets are the Kindle devices and apps already registered to that
  account; documents optionally archive to the Kindle Library.
- Distribution: GitHub Releases (APK, DMG, Linux x64/arm64 tarballs) and
  Zapstore for Android. The README and the Zapstore listing are the public
  surfaces a new user meets first.
- Markdown is typeset to PDF with `pandoc` or headless Chrome where available
  (in practice Linux); elsewhere it becomes styled HTML that Amazon converts.
- Amazon's protocol is undocumented and can break or be blocked at any time;
  the app is not affiliated with Amazon.

## Capabilities and Constraints

- Input formats: PDF, EPUB, MOBI, AZW/AZW3, TXT, RTF, DOC, DOCX, HTML, PNG, JPG,
  GIF, BMP, plus Markdown. Multi-document queue with per-document metadata and
  per-document upload progress.
- One Flutter codebase; no server component, no analytics, MIT licensed. Amazon
  credentials live in the OS keychain/encrypted storage, falling back to a
  mode-600 file where no keychain is reachable, with Settings naming which was
  used.
- Desktop window is ~880×700 (minimum 620×520) and the same UI is fitted to
  phones via `SafeArea`; there is no separate mobile design.
- Non-goals today: USB/MTP sideloading, Kindle Library management, iOS and
  Windows packaging. Roadmap: migrating to the `/import/kindle-doc/send-to-kindle`
  endpoint, localization, a notarized macOS build and signed release APK in CI.
- The official app's flow — documents, metadata, device picker, archive toggle,
  send, in one window — is the incumbent default, not untouchable truth: a
  demonstrably better flow may replace it.

## Brand Commitments

- Name **KindBeamer**; the lowercase `kindbeamer` wordmark (teal "kind", light
  "beamer") is the app's identity, and the master icon art is
  `assets/icon/icon-1024.png` with derived platform icon sets.
- An openly unofficial project: the disclaimer ("not affiliated with, endorsed
  by, or sponsored by Amazon") stays visible wherever the app is presented, and
  copy never implies official status.
- Voice is plain, honest, first-person-free prose; no marketing inflation, and
  limitations and failure modes are stated rather than hidden.
- The dark UI is deliberately *not* the official client's charcoal-and-orange;
  it has its own slate-and-teal palette inherited from the current theme.

## Evidence on Hand

- `docs/screenshot-macos.png` — a real macOS window with a queued PDF, title and
  author filled in, device checkboxes ticked and the Send button.
- `SPECIFICATION.md` — architecture, wire protocol, format table, testing and
  build notes; the place to record protocol knowledge.
- `README.md` — install paths, feature list, share-recipient matrix.
- Reference implementations: `stkclient` (Python, MIT) and `stkclient-swift`
  supply protocol and test vectors; never regenerate vectors from our own code.
- Absences to respect: no testimonials, user numbers, press coverage,
  benchmarks or Amazon endorsement exist. Nothing may be invented about them.

## Product Principles

1. **Every path ends in a send.** The shortest possible route from a file on
   the machine to a device the user ticked; the official flow is the baseline to
   beat, never a reason to stop thinking.
2. **Everything local, nothing phoning home.** No server, no telemetry, no
   credential in anyone else's hands — the architecture is the trust story.
3. **Meet the file where it is.** Drag, Open With, share sheet, CLI argument:
   the OS mechanisms a user already has must all reach the same queue.
4. **Technical install, unremarkable app.** The audience can decode a failed
   install; they should never have to decode a failed send. Errors name the
   cause and the next step.
5. **Unofficial, and honest about it.** The disclaimer and the protocol's
   fragility are stated up front; the app never promises more than it controls.

## Accessibility & Inclusion

No product-specific requirement has been established beyond the phone-safe
layout (`SafeArea`) already in place.
