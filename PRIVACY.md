# Privacy policy

*KindBeamer app (macOS, Linux, Android) and KindBeamer browser extension
(Firefox, Chrome and other Chromium browsers). Last updated 15 November 2026.*

KindBeamer is open-source software with no server of its own. Its author
receives nothing from it: no documents, no account details, no usage
statistics. KindBeamer talks to one party, Amazon, to deliver what you ask it
to send.

## What goes to Amazon

Only Amazon's Send to Kindle service, and only for what you start:

- **Signing in.** You sign in on Amazon's own sign-in page. KindBeamer never
  sees your password. Amazon then issues this app or browser its own device
  credentials, a private key and a token, which register it as a device on
  your account.
- **Your Kindle devices.** KindBeamer asks Amazon for the list of Kindles on
  your account, so you can choose where to deliver.
- **What you send.** When you press Send, the document goes to Amazon,
  together with the title and author shown on the label and the devices you
  ticked. That is the file you added, the PDF you printed to KindBeamer, or,
  in the extension, the article or PDF from the page you beamed.
- **Signing out** tells Amazon to unregister the device.

Amazon handles this data under its own privacy notice.

## What stays on your device

- The device credentials Amazon issued, kept in the operating system's
  keychain or encrypted storage (the app) or in the extension's own storage
  (the browser). Signing out or uninstalling deletes them.
- Your preferences: the devices you ticked last, the library copy, the PDF
  layout, appearance, and this installation's device serial number.
- A small counter for the support note (below): days of use, sends, how often
  the note was shown, and whether you turned it off.
- Printed pages (Android) wait in the app's private cache until they are sent,
  and are deleted after a day.

## The browser extension

- It reads a page only when you press its button or shortcut, and only that
  tab. The article is extracted inside your browser. Nothing leaves the
  browser until you press **Send**, and then it goes to Amazon only.
- The article's images, and a PDF you beam, are downloaded straight from the
  sites that host them, by your browser, as you would load them yourself.
  Access to other sites is optional. The extension asks for it only to fetch
  those images and PDFs, and you can refuse.
- **EPUB** saves the book to your own disk and sends nothing.

## The support note

After you have used the app for a few days, a small note may appear in the
window while a document is being sent, asking whether you want to support
KindBeamer's development, with an e-book as thanks. It appears at most three
times. *Not now* closes it, and *Don't ask again* turns it off for good. The
app makes no network request for the note. If you tap *Support* (on the note,
or in Settings, where the entry stays), your own browser opens a page at
hackyourself.io/support. The link carries only the app's name, whether the app
is showing its light or dark appearance, and where you tapped. Paying and
getting the book happen on that page, in your browser, not in the app.

## What KindBeamer does not do

No analytics, telemetry, advertising or tracking, and no data shared with or
sold to anyone. Apart from Amazon, the only network requests are the ones
your own browser makes for a page's images or PDF, and the page you open
yourself by tapping *Support*.

KindBeamer is not affiliated with, endorsed by, or sponsored by Amazon.

## Changes and contact

Changes to this policy are recorded in the project's history at
<https://github.com/jooray/kindbeamer/commits/main/PRIVACY.md>. Questions go to
<https://github.com/jooray/kindbeamer/issues>.
