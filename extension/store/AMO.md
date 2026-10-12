# addons.mozilla.org listing

What to paste into each field when submitting KindBeamer to
addons.mozilla.org (AMO). Kept in the repo so the next version's listing starts
from the last one.

## Upload

- **File:** `kindbeamer-firefox-<version>.zip` from the GitHub release (or
  `extension/dist/` after `node build.mjs`).
- **Where to distribute:** *On this site* (listed). Mozilla signs it and
  Firefox then updates it automatically.
- **Compatibility:** Firefox and Firefox for Android (the manifest sets 128 as
  the minimum for both).
- **Source code:** *No*, no code generators, minifiers or bundlers. The
  uploaded files are `extension/src/` as written, plus a manifest that
  `build.mjs` writes. `vendor/Readability.js` is Mozilla's
  `@mozilla/readability` 0.6.0, unmodified from npm.
- **Data collection** comes from the manifest: *website content* and
  *authentication information*, both required, both sent to Amazon only
  (see the privacy policy).

## Describe add-on

**Name:** KindBeamer

**Add-on URL:** `kindbeamer`

**Summary** (250 characters max):

> Send the article you are reading to your Kindle: picked out of the page
> with its pictures, previewed, and delivered straight to Amazon. PDFs too,
> as they are or reflowed. No email address, no server in between.

**Description:**

> Press the KindBeamer button (or Alt+Shift+B) on any article, and a tab opens
> beside it with just the article: no menus, sidebars, ads or comments. It
> keeps the text and its pictures, previewed the way the book will read.
> Check the title and author, tick your Kindles, press Send.
>
> • Extracted with Readability, the engine behind Firefox Reader View, from
>   the page as you see it, so articles behind a login or a subscription you
>   hold work too.
> • Images are packed into a proper EPUB, converted where Kindle would not
>   take them (WebP, AVIF, SVG) and sized for an e-reader.
> • PDFs open in Firefox go out as the file itself, with their original
>   layout or reformatted by Amazon to follow your Kindle's font size.
> • EPUB saves the book to your disk instead of sending it.
> • Straight to Amazon: sign in once on Amazon's own page and Firefox
>   registers as a device of its own on your account. No Send-to-Kindle
>   email address, no forwarding service, no server of ours. Nothing is
>   stored except the device credentials and your last choices.
> • Keyboard-friendly: Enter sends, 1–9 tick a device, A takes all or none,
>   R switches a PDF's layout, Esc closes.
>
> KindBeamer is also a desktop and Android app; see the homepage.
>
> KindBeamer is open source (MIT) and is not affiliated with, endorsed by, or
> sponsored by Amazon. Kindle is a trademark of Amazon.com, Inc.

**Categories:** Feeds, News & Blogging · Other (Firefox for Android: Other)

**Tags:** kindle, send to kindle, epub, reader view, e-reader

**Support email:** leave empty.
**Support website:** https://github.com/jooray/kindbeamer/issues
**Homepage:** https://jooray.github.io/kindbeamer/

**License:** MIT/X11 License

**Privacy policy:** tick *This add-on has a privacy policy* and paste
`PRIVACY.md` from the repository root, or this short form:

> KindBeamer sends data only to Amazon, and only what you ask it to send. It
> reads a page only when you press its button. When you press Send, it
> uploads that article or PDF to Amazon's Send to Kindle service, with the
> title, the author and the Kindles you chose. You sign in on Amazon's own
> page and KindBeamer never sees your password; the device credentials
> Amazon issues are kept in the extension's storage until you sign out or
> remove the extension. Images and PDFs are downloaded by your browser from
> the sites that host them. No analytics, no tracking, no data to the
> developer or anyone else. Full policy:
> https://jooray.github.io/kindbeamer/privacy.html

## Screenshots

`store/screenshot-1-article.png`, `screenshot-2-article-night.png` and
`screenshot-3-pdf.png` (1280×800). The device lanes are renamed to generic
Kindles in them.

Captions:

1. An article, extracted with its pictures and addressed to two Kindles.
2. The same at night: the page follows the system's dark mode.
3. A PDF from the web, sent with its original layout or reflowed.

## Version notes

> First release on addons.mozilla.org. Sends the article you are reading to
> your Kindle as an EPUB with its images, or a PDF open in Firefox as the file
> (original layout or reflowed). It signs in to Amazon directly, with no email
> address, and the EPUB can also be saved to disk.

## Notes to reviewer

> To try it without an Amazon account: open any article (for example
> https://juraj.bednar.io/en/blog-en/2026/10/10/confidential-inference-on-routstr-without-trusted-hardware/),
> press the toolbar button, and press EPUB; the downloaded book is the same one
> Send would deliver. Sending needs an Amazon account: "Sign in with Amazon"
> opens Amazon's own sign-in page in a tab, which closes itself once Amazon
> redirects to its sendtokindle landing page.
>
> Permissions: activeTab + scripting inject Readability into the current tab
> only when the button is pressed. storage holds the Amazon device credentials
> and preferences. https://*.amazon.com/* covers the sign-in, Send to Kindle
> API and upload endpoints. The optional <all_urls> is requested on a click
> only to download the article's images and PDFs from the sites hosting them.
>
> No remote code. vendor/Readability.js is @mozilla/readability 0.6.0 from npm,
> unmodified (the library behind Firefox Reader View). Source:
> https://github.com/jooray/kindbeamer/tree/main/extension
>
> The two "unsafe assignment to innerHTML" warnings are both inside that
> library: Readability.js:1549 restores its own cached copy of the page between
> extraction passes, and :1928 unwraps <noscript> image fallbacks. Both work on
> a detached copy made with document.cloneNode(true) (extract.js), which
> renders nothing, runs no scripts and loads nothing. The extension's own code
> does not use innerHTML. Article HTML is parsed with DOMParser into an inert
> document and passed through an element/attribute whitelist (article.js)
> before it is shown or packaged.
>
> Test account: there is no test Amazon account to share. Sending needs the
> reviewer's own Amazon account; registering adds a device named
> "KindBeamer (Firefox on …)" to it, which Sign out removes again. Everything
> except the final upload can be checked without an account through the EPUB
> button.
