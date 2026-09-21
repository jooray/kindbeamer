---
name: KindBeamer
description: A dispatch label printed on e-paper — one ink, one ground, and a postmark for the send.
colors:
  paper-ground: "#F2F1EC"
  paper-well: "#E9E8E2"
  paper-ink: "#16171A"
  paper-ink-mid: "#52545A"
  paper-ink-faint: "#646669"
  paper-mark: "#7D7F84"
  paper-rule: "#C2C1BB"
  paper-rule-faint: "#D8D7D1"
  night-ground: "#101113"
  night-well: "#191A1D"
  night-ink: "#E9E8E3"
  night-ink-mid: "#9B9DA2"
  night-ink-faint: "#85878C"
  night-mark: "#6C6E73"
  night-rule: "#3B3D41"
  night-rule-faint: "#2A2C2F"
typography:
  wordmark:
    fontFamily: "LibreFranklin"
    fontSize: "21px"
    fontWeight: 700
    letterSpacing: "-0.2px"
    fontVariation: "wght 700 / wght 300"
  display:
    fontFamily: "LibreFranklin"
    fontSize: "26px"
    fontWeight: 700
    letterSpacing: "6px"
    fontVariation: "wght 700"
  legend:
    fontFamily: "LibreFranklin"
    fontSize: "10.5px"
    fontWeight: 600
    letterSpacing: "1.4px"
    fontVariation: "wght 600"
  label:
    fontFamily: "LibreFranklin"
    fontSize: "9.5px"
    fontWeight: 600
    letterSpacing: "1.3px"
    fontVariation: "wght 600"
  caption:
    fontFamily: "LibreFranklin"
    fontSize: "9px"
    fontWeight: 600
    letterSpacing: "1.3px"
    fontVariation: "wght 600"
  body:
    fontFamily: "CourierPrime"
    fontSize: "13px"
    fontWeight: 400
    letterSpacing: "-0.2px"
  status:
    fontFamily: "CourierPrime"
    fontSize: "12.5px"
    fontWeight: 400
    lineHeight: 1.35
    letterSpacing: "-0.2px"
  measure:
    fontFamily: "CourierPrime"
    fontSize: "11px"
    fontWeight: 400
    letterSpacing: "-0.2px"
rounded:
  none: "0px"
spacing:
  hairline: "1px"
  legend-gap: "7px"
  barred-edge: "7px"
  section-gap: "13px"
  tick: "15px"
  gutter: "22px"
  row: "26px"
  touch-row: "48px"
  label-max-width: "900px"
components:
  button-press:
    backgroundColor: "transparent"
    textColor: "{colors.paper-ink}"
    typography: "{typography.legend}"
    rounded: "{rounded.none}"
    padding: "0 16px"
    height: "34px"
  button-press-hover:
    backgroundColor: "{colors.paper-well}"
    textColor: "{colors.paper-ink}"
  button-press-disabled:
    backgroundColor: "transparent"
    textColor: "{colors.paper-ink-faint}"
  button-press-dense:
    backgroundColor: "transparent"
    textColor: "{colors.paper-ink}"
    typography: "{typography.label}"
    padding: "0 12px"
    height: "28px"
  button-press-solid:
    backgroundColor: "{colors.paper-ink}"
    textColor: "{colors.paper-ground}"
    typography: "{typography.legend}"
    rounded: "{rounded.none}"
    padding: "0 16px"
    height: "34px"
  tick-box:
    backgroundColor: "transparent"
    rounded: "{rounded.none}"
    size: "{spacing.tick}"
  tick-box-on:
    backgroundColor: "{colors.paper-ink}"
    textColor: "{colors.paper-ground}"
    size: "{spacing.tick}"
  well:
    backgroundColor: "{colors.paper-well}"
    textColor: "{colors.paper-ink}"
    rounded: "{rounded.none}"
    padding: "5px 0"
  field-line:
    backgroundColor: "transparent"
    textColor: "{colors.paper-ink}"
    typography: "{typography.body}"
    rounded: "{rounded.none}"
    padding: "0 0 4px"
  lane-row:
    backgroundColor: "transparent"
    textColor: "{colors.paper-ink-mid}"
    typography: "{typography.body}"
    height: "{spacing.row}"
  lane-row-hover:
    backgroundColor: "{colors.paper-rule-faint}"
    textColor: "{colors.paper-ink}"
  postmark:
    backgroundColor: "transparent"
    textColor: "{colors.paper-mark}"
    size: "48px"
  postmark-delivered:
    backgroundColor: "{colors.paper-ink}"
    textColor: "{colors.paper-ground}"
    size: "48px"
  notice-band:
    backgroundColor: "{colors.paper-well}"
    textColor: "{colors.paper-ink}"
    rounded: "{rounded.none}"
    padding: "9px 10px 9px 22px"
  slip-dialog:
    backgroundColor: "{colors.paper-ground}"
    textColor: "{colors.paper-ink}"
    rounded: "{rounded.none}"
    padding: "18px 20px 20px"
    width: "480px"
---

# Design System: KindBeamer

## Overview

**Creative North Star: "The Dispatch Label"**

The window is a pre-addressed airmail label printed on e-paper, not an upload dialog. It arrives already filled in — contents, description, addressees from last time — and the only act left is franking it. The barred postal edging closes the window top and bottom, lettered sections A / B / C run down it like fields on a customs declaration, and the send is a postmark pressed into the sheet.

There is one ink and one ground, and nothing else. Every state the app can be in — selected, focused, ticked, sending, delivered, failed — is carried by fill, stroke, tick or inversion. The press face states what the form printed; the typewriter face states what was filled into it. Night is not a dark theme with tinted greys but the same sheet inverted, the way an e-reader inverts: ink becomes ground and nothing is tinted on the way across.

The refused defaults are specific and confirmed: the dark rounded card with a dashed cloud-upload drop zone, toggle switches, accent-coloured pills, and the official client's charcoal-and-orange. The slate-and-teal world this replaced is history, not a reference.

**Key Characteristics:**
- One ink on one ground; no hue anywhere, on either surface.
- Night is a true inversion, not a tinted dark palette.
- Flat: no shadow, no gradient, no radius — every corner is square (0px).
- Two voices: tracked uppercase press type for what was printed, Courier for what was typed.
- Rows share one height so counting needs no measuring.
- One inverted block per page, and it is SEND.

## Colors

Two complete inks, one per surface. There is no accent, no secondary and no tertiary — the palette is a neutral ramp and its inversion, and nothing in the app is allowed a hue.

### Primary

The ink itself is the primary: **Press Ink** (`{colors.paper-ink}` on paper, `{colors.night-ink}` at night). It carries primary text, solid ticks, the franking block, the barred edge, the focused field's rule and every drawn mark that is currently live. It is the only "accent" the system has, and it is spent on fills rather than on colour.

### Neutral

- **Warm Paper** (`{colors.paper-ground}`): the sheet the label is printed on; the scaffold, dialogs and the knocked-out foreground inside an inked block.
- **Paper Well** (`{colors.paper-well}`): one step into the paper, for the ruled boxes that hold typed content and for an outline button's hover ground.
- **Ink Mid** (`{colors.paper-ink-mid}`): printed legends, the light half of the wordmark, and anything said a second time (format tags, untick device names).
- **Ink Faint** (`{colors.paper-ink-faint}`): the third and last step of text — hints, lane numbers at rest, sizes, notes under a box. Held at 4.5:1 on both surfaces.
- **Mark Grey** (`{colors.paper-mark}`): drawn marks rather than words — an empty tick box, the dormant postmark's rings, a remove cross. Held at 3:1, the floor for a control's outline.
- **Field Rule** (`{colors.paper-rule}`) and **Inner Rule** (`{colors.paper-rule-faint}`): hairlines between fields and hairlines inside a field; the faint one doubles as the row-hover ground.
- **Night** repeats all seven roles inverted (`{colors.night-ground}`, `{colors.night-well}`, `{colors.night-ink-mid}`, `{colors.night-ink-faint}`, `{colors.night-mark}`, `{colors.night-rule}`, `{colors.night-rule-faint}`), selected by `Brightness` alone.

### Named Rules

**The No-Hue Rule.** There is no accent colour and none may be added. A state is expressed by fill, stroke weight, tick or inversion — never by a hue. Audit test: a screenshot printed on a mono laser printer must lose nothing.

**The True Inversion Rule.** Night maps role for role onto the paper set. Ink becomes ground, ground becomes ink; no channel is tinted, warmed or cooled on the way across, and no component branches on theme beyond picking its `Ink0`.

**The Three-Steps-of-Text Rule.** Text has exactly three weights of presence — ink, ink-mid, ink-faint — and drawn outlines get a fourth, mark. A fifth step is not available; if something needs to recede further, it should not be on the label.

## Typography

**Press Font:** Libre Franklin (`LibreFranklin`, variable `wght` axis, bundled)
**Typed Font:** Courier Prime (`CourierPrime`, 400 and 700, bundled)

**Character:** The press is the form: uppercase, tracked, weighted on the variable axis, the voice of something printed before the document existed. The typewriter is the user: file names, titles, sizes, device names and the state sentence are all things filled into the form afterwards. Both faces ship with the app, so the label reads identically on macOS, Linux and Android.

### Hierarchy

- **Wordmark** (Libre Franklin, 21px, −0.2px tracking): `kind` at wght 700 in ink against `beamer` at wght 300 in ink-mid. The split is the identity; in a one-ink world it is carried by weight, never by colour.
- **Display** (Libre Franklin, wght 700, 26px, 6px tracking): overlay headlines only — AFFIX DOCUMENT on the drop sheet, KEYS (15px, 6px tracking) on the key card.
- **Legend** (Libre Franklin, wght 600, 10.5px, 1.4px tracking): section legends and button labels; the section letter is set at wght 700 in full ink, the name at wght 600 in ink-mid.
- **Label** (Libre Franklin, wght 600, 9.5px, 1.3–1.6px tracking): field labels (TITLE, AUTHOR), dialog group headings, dense button labels.
- **Caption** (Libre Franklin, wght 600, 8.5–9px, 1.2–1.5px tracking): the disclaimer line under the wordmark, format tags, the franking note line, key hints printed beside a row.
- **Body** (Courier Prime, 400, 13px, −0.2px tracking): everything typed into the form — document names, device names, field values, dialog prose. The selected document row goes to 700, not to another colour.
- **Status** (Courier Prime, 400, 12.5px, 1.35 line-height): the one-sentence state beside the postmark.
- **Measure** (Courier Prime, 400, 11px): sizes, counts, tallies, lane numbers.

### Named Rules

**The Two-Voices Rule.** Press type states what the form printed; typed type states what was filled into it. A value the user supplied or a machine measured is never set in the press face, and a legend, button or key cap is never set in Courier.

**The Printed Key Cap Rule.** Wherever a key does the same thing as a control, the key is printed on the control in press caption type at 62% ink (`ENTER` on SEND, `ESC` on CLEAR, `A` on ALL, `E` on the library row, `⌘O` / `CTRL+O` on ADD). On touch builds the caps are dropped entirely — never faked, never drawn as a key-shaped box.

## Layout

The label is a single column centred at a maximum width of 900px, with a 22px gutter, inside a window of 720×585 (minimum 460×430). Structure from the top: barred edge (7px), printed header (13px/12px vertical padding), a strong hairline, the scrolling field stack (14px top and bottom), the optional notice band, the franking row, barred edge flipped. The overlays live between the two barred edges, so the postal border never leaves the window.

The queue is the only section whose length the user controls, so it is the only one capped: past three rows (3 × 26px desktop, 3 × 48dp touch) it scrolls inside its own well on a 3px square-ended thumb and the rest of the label stays where it was. When the whole field stack runs past the window, a ground-coloured chip prints CONTINUES BELOW in press caption type (8.5px, 1.5px tracking, ink-faint) at the bottom right of the scroll area, 22px in from the gutter — the sheet saying where it carries on rather than a fading edge.

Sections are lettered and separated by 13px, with 7px between a legend and the box it names. Rows are the rhythm: every document row, device lane and skeleton lane is exactly 26px tall on desktop (the library row is 26+6px, being the last row under a hairline inside the same box), so a count is read by eye rather than measured. Measurements sit in a fixed right-hand column — the size column is a hard 82px, right-aligned, in Courier — and never reflow as names change.

**Responsive behaviour** turns on one breakpoint at 520px and one platform flag:
- Device lanes go two-up above 520px, separated by a 1px inner rule, and single-column below.
- The franking row keeps status and buttons on one line above 520px; below it, the status sentence takes its own line and CLEAR / SEND split the width equally.
- On Android and iOS (`touchLayout`), rows and icon targets grow to 48dp and printed key caps disappear. Nothing else changes: there is no separate mobile design.

## Elevation & Depth

This system has no elevation. There are no shadows, no gradients, no blurs, no scrims with opacity and no Material surface tints — dialogs are drawn at `elevation: 0` with a 1.2px ink border, and the drop and key overlays are opaque full-window fills rather than translucent scrims. Depth is expressed three ways only: the one-step well (`paper-well` / `night-well`) for a box that expects content, hairline rules between zones, and inversion for the one block that matters.

### Named Rules

**The Flat Sheet Rule.** Nothing on the label floats. If an element needs to separate from its neighbour, it gets a hairline, a well, or a heavier strike of its own border — never a shadow.

**The One Inverted Block Rule.** SEND is the only inverted block on the page. Inversion is how the label marks its single irreversible act; a second inverted block would make the act ambiguous. The settings appearance buttons reuse the solid treatment to mark the one active choice, and nothing else may.

## Shapes

Every corner is square. Radius is 0 everywhere — buttons, wells, tick boxes, dialogs, scrollbar thumbs, the text cursor — and the direction contract's "no corner above 2px" landed as a flat zero in the build. Borders do the work radius would: a hairline (1px) at rest, 1.2px for an emphasised well, a dialog edge or an inked button, and 1.6px for hover or keyboard focus. There is no second colour to spend on a state, so a state is a heavier strike of the same rule.

The recurring silhouettes are the barred edge (a 7px band of ink parallelograms on a 26px period, slanted 1.15× the band height, flipped along the bottom), the square tick, the two-stroke cross, the ruled well, the underlined field, and the postmark disc — the only circle in the system.

## Components

### Buttons (PressButton)

Printed actions: a rectangle of ink rule with tracked uppercase inside it.
- **Shape:** square (0px), 1px ink border, 34px tall (dense: 28px) with 16px (dense: 12px) horizontal padding.
- **Outline (default):** transparent ground, ink label, optional key cap at 62% ink.
- **Hover / Focus:** ground fills to the well and the border strikes heavier (1.6px). No colour change, no lift, no ripple (`NoSplash`, transparent highlight).
- **Solid:** ink ground, ground-coloured label, 1.2px border. Reserved for SEND / SENDING / RETRY and for the active appearance choice. On hover or focus, a 1px knocked-out rule is inset 3px inside the edge — a hand stamp showing its shoulder.
- **Disabled:** faint ink label on a rule-coloured border; a disabled SEND drops back to the outline treatment rather than greying a fill.

### Tick Box

The only selection control; there are no switches, pills or radio buttons anywhere.
- **Off:** a 15px square, 1.2px mark-coloured stroke inset 0.6px, no fill.
- **On:** the square filled solid in ink with a 1.9px knocked-out check (square caps).
- **State is binary and instant** — no tint, no slide, no transition.

### Cross Mark

The remove mark: two strokes drawn on the tick's hairline, so the label keeps one drawn vocabulary and never borrows a glyph from a font.
- **Geometry:** two 1.2px square-capped lines corner to corner of a square box — 10px in a queue row, 11px in the notice band.
- **States:** mark grey at rest, full ink on hover; the hit target around it is 26px square on desktop and 48dp on touch.

### Wells and Fields

- **Well:** well-coloured ground with a 1px rule border, square, 5px vertical padding; the box the keyboard is pointed at takes a 1.2px ink border instead.
- **Field:** no box at all — a ruled baseline you write on. Press label in a fixed 64px column at the left, Courier value at 13px above a 1px rule; on focus the rule inks to full ink and thickens to 1.6px. The caret is a 1.4px square-ended bar; selection is ink at 22% alpha.
- **Disabled field:** faint-rule baseline, faint label, unchanged geometry.

### Rows (documents and lanes)

- Fixed height (26px desktop / 48dp touch), full-width hit target, hover inks the row ground to the faint rule.
- A document row prints a 6px solid ink square as its carriage mark when selected and sets its name in Courier 700 ink; unselected names are ink-mid 400.
- A device lane prints its key digit (1–9 then 0) at the far left in Courier 11px — ink 700 when ticked, faint 400 when not — then the tick box, then the name. Past the tenth device a lane has a tick and no digit.
- Format tags sit in press caption; sizes in a fixed 82px right-aligned Courier column, and the row ends with the drawn cross mark.
- The queue box holds three rows at full height; beyond that it scrolls within the well rather than pushing the label down.

### Postmark (signature component)

The only drawn-not-printed element in the app, 48px, carrying five states:
- **IDLE:** two mark-coloured hairline rings (1.2px outer, 0.9px inner), word and date in faint.
- **READY:** the same rings struck in full ink.
- **SENDING:** a 2.6px ink arc sweeps the outer ring from twelve o'clock in proportion to bytes sent; the word becomes the percentage.
- **DELIVERED (SENT):** the whole disc fills solid ink and all marks knock out in the ground colour.
- **HELD:** rings thicken to 1.8px / 1.4px in full ink — failure is a heavier strike, not a red.

Every state prints the word (Courier 9px/700), a 0.8px hairline across the disc, and the day and month (Courier 7.5px/400). A state change presses the stamp: a 190ms `easeOutCubic` scale from 1.22 to 1. That is the system's entire motion vocabulary.

### Franking Row

The row that closes the label: a 2px progress rule across the full width (rule-coloured, filling ink as bytes go), then the postmark, the state sentence in Courier 12.5px, a press-caption note under it, and CLEAR / SEND at the right. On delivery, two further 2px ink rules are struck across the label above the row — a franking cancels what it stamps.

### Overlays and Slips

- **Drop / Keys overlay:** an opaque full-window fill between the barred edges with a 1px inset border, the sheet turned over to print one instruction on its back. On paper it fills with ink and prints in ground; at night the page is already ink, so it fills with ground and prints in ink.
- **Dialog slips (Settings, Sign in):** ground-coloured, max 480px, square, 1.2px ink border, and a barred edge across the top and bottom of the slip itself so it reads as the same stock as the window. Group headings are press labels over a strong hairline.
- **Notice band:** a well-coloured strip above the franking row with a 1.2px ink top border, Courier 12px, self-dismissing after 8 seconds.

## Do's and Don'ts

### Do:

- **Do** express every state with fill, stroke weight, tick or inversion. There is no hue in this system and nothing may introduce one.
- **Do** map night role-for-role onto paper via `Ink0`; read colours through `Ink0.of(context)` rather than branching on brightness.
- **Do** set printed things (legends, buttons, key caps, tags) in tracked uppercase Libre Franklin, and filled-in things (names, titles, sizes, the state sentence) in Courier Prime.
- **Do** keep every row at one height — 26px on desktop, 48dp on touch — so counting needs no measuring.
- **Do** right-align measurements in the fixed Courier column (82px for sizes) so the column never reflows.
- **Do** make hover and focus a heavier strike of the same rule (1px → 1.6px), or the well as a ground.
- **Do** draw marks — ticks, crosses, the postmark — with painters, in the label's own geometry.
- **Do** drop printed key caps on touch builds and grow targets to 48dp; the same label, simply set larger.

### Don't:

- **Don't** add an accent colour, a tint, a gradient or a coloured status (no red error, no green success). HELD is a heavier ring; DELIVERED is a solid disc.
- **Don't** add shadow, elevation, blur or a translucent scrim. Separation is a hairline, a well, or an inversion.
- **Don't** round a corner. Radius is 0 across the system, including dialogs and scrollbars.
- **Don't** invert a second block. SEND owns inversion on the main surface.
- **Don't** use a toggle switch, a pill, a radio button or a dashed drop zone; selection is the square tick and the drop target is the whole window.
- **Don't** borrow a glyph from a text font as an icon, and don't reach for an icon set: the drawn vocabulary (`TickBox`, `CrossMark`, `Postmark`, `BarredEdge`) is the whole icon library.
- **Don't** introduce motion beyond the 190ms postmark press and the progress sweep; ripples and splashes are switched off globally.
- **Don't** set a platform UI font. Both faces are bundled so all three platforms print the same label.
