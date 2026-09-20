---
version: 1
slug: "lib-src-ui-home-page-dart"
primary_target: "lib/src/ui/home_page.dart"
related_targets: ["lib/src/ui/theme.dart","lib/src/ui/settings_dialog.dart","lib/src/ui/login_dialog.dart"]
---

Scope: the KindBeamer application window (home surface, settings and sign-in slips,
drop overlay) across macOS, Linux and Android. Visitor mode: Operate.

Audience: a reader who already has the file open and wants it on their Kindle
before they forget. Desktop is primary and keyboard-first (Omarchy/tiling on
Linux); Android is the share-sheet case. The task is one keystroke long.
Constraints: Amazon's protocol and its device list, no telemetry, the disclaimer,
the existing send/convert/credential layers, Flutter on three platforms.
Unresolved: nothing blocking; auto-dismiss defaults to on and is reversible in
Settings.

## Direction contract

THESIS: The window is a pre-addressed dispatch label, not an upload dialog. It
arrives already filled in — contents, description, addressees from last time —
so the only act left is franking it. Refuses the category default: the dark
rounded card with a dashed cloud-upload drop zone, toggle switches and an
accent-coloured pill.

OWN-WORLD: Monochrome e-paper. Warm-neutral paper #F2F1EC, ink #17181A, a true
inversion at night; no hue anywhere, so every state is carried by fill, stroke,
tick and inversion. Barred postal edging top and bottom, hairline rules, sections
lettered A-D with tracked uppercase Libre Franklin legends, Courier Prime for
everything typed into the form. Flat: no shadow, no gradient, no corner above 2px.
RAISE (Saville, declined): each fact printed exactly once, no label twice.
RAISE (botanical folio, declined): queue rows and device lanes share one fixed
scale and baseline so counting is automatic. RAISE (cloud quarry, declined):
measurements set in mono, right-aligned in a stable column that never reflows.
RAISE (Miura sheet, declined): one key propagates across the whole device field.
RAISE (darkroom, declined): the commit point is marked and what will land is
shown in full before it.

STORY: Open With → the label is already addressed → press Enter → the postmark
presses and fills as the bytes go → DELIVERED → the window leaves. Only failure
keeps it on screen, and it names the cause.

FIRST VIEWPORT: Barred edge, then a printed header — KINDBEAMER wordmark left,
ADD ⌘O and SETTINGS right. Section A CONTENTS: ruled box, one typewritten row
per document with format and size right-aligned. Section B DESCRIPTION: TITLE and
AUTHOR on the same ruled baselines, pre-filled. Section C DELIVER TO: numbered
lanes in two columns, digit 1-9,0 printed beside each tick box, count and an
ALL/NONE control at the right, and the library copy as the last row of the same
box under a hairline — three lettered sections, not four, so a three-document
label still fits one screen. The franking row closes the label: a hairline
progress rule, the postmark disc at the left, the state sentence beside it,
CLEAR ESC and SEND ENTER at the right. SEND is the only inverted block on the
page, and a delivery strikes two more rules across the label beside it.

FORM: the airmail / customs-declaration label, candidate 6 of 7 on the grounded
list; seed key 02a899d0, assigned index 6, scope direction, mode operate.

FINISH: unreviewed and undocumented is unfinished; this build ends with the
finish review, the verdict, DESIGN.md, and every shipping raster carrying its
provenance.
