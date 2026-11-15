# Support ask (shared Flutter module)

A small strip that, now and then, asks whether the user wants to support a free app. Tapping **Support**
opens a checkout page in the browser. The app itself makes **no network request** for this.

**This directory is a synced copy.** The canonical source is the private `support-widget` repository
(`~/projects/support-widget/flutter/lib/support/` on Juraj's machine). Never edit these files here: change the
canonical file, then run `support-widget/flutter/sync.sh <this repo>` (and `... --check` to see drift).
Everything about the whole system, and which module to change for which kind of change, is in
`support-widget/MODULES.md`.

## What is in here

| File | Job | Change it when |
|---|---|---|
| `support_engine.dart` | The rules: when an app may ask. Pure functions, no I/O. Port of `spec/engine.mjs`. | the rules change (always together with `spec/engine.mjs` and `spec/engine-vectors.json`) |
| `support_store.dart` | Persists the engine state as one JSON value under the key `support.v1` in shared_preferences. | the storage changes |
| `support_controller.dart` | The one object an app talks to: `launch()`, `recordAction()`, `evaluate()`, `support()`, `hide()`, `declineForever()`, `openCheckout()`. | the flow or the API changes |
| `support_launch.dart` | The URL contract (`supportUri`) and the system-browser launcher. | the URL parameters change (also on the server, `spec/ask.md` section 5, and every client) |
| `support_copy.dart` | The words, in en / sk / cs. No price, no minimum, no currency. | the wording or a language changes (also `spec/ask.md` section 6, `spec/ask-preview.html`) |
| `support_strip.dart` | The widget. Built from basic widgets, takes the host app's look through `SupportStyle`. | the strip's structure or behaviour changes (also `spec/ask.md`) |

## What the app owns (not synced)

Each app has one adapter file (KindBeamer: `lib/src/ui/support_ask.dart`, QREncoder: `lib/support_ask.dart`) with:

- the `SupportConfig`: the app id (its key on the server), the `ref` (the placement), and the trigger numbers;
- the `SupportStyle`: the app's own palette and type, so the strip looks like the app;
- where the strip is placed, and what counts as a moment of value.

Change those there, in the app. Changing them never needs a change in this directory.

## Rules the module keeps (do not break them)

1. No network code. `launchUrl` on the user's tap is the only outward call, and it hands off to the browser.
2. The text states no price, minimum or currency, so a change of price never needs an app release.
3. Never a modal, never over a task, never takes focus on its own, at most three asks in a lifetime.
4. The URL carries `lang` (only if the app is localized), `theme`, `ref` and optionally `book`. Nothing else.

## Tests

`test/support_ask/` holds the module's tests (also synced). `support_engine_test.dart` replays
`engine_vectors.json`, the same file the JavaScript reference runs; all must pass. The app's own
`*_placement_test.dart` tests the adapter and the placement.
