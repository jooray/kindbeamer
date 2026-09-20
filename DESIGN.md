---
name: KindBeamer
description: A dark slate dispatch desk with one signal teal, for sending documents to Kindle devices.
colors:
  deep-slate: "#1F2630"
  panel-ink: "#1A202A"
  field-ink: "#131922"
  header-slate: "#2B3442"
  header-shade: "#222A36"
  status-slate: "#232B37"
  footer-ink: "#1B222C"
  slate-border: "#3B4657"
  slate-border-light: "#5C6B84"
  paper-white: "#E8EDF4"
  muted-slate: "#A7B4C4"
  faint-slate: "#6E7E92"
  pure-white: "#FFFFFF"
  signal-teal: "#38C7B4"
  signal-teal-deep: "#1FA392"
  link-blue: "#7FB5FF"
  row-selected: "#333333"
  disabled-fill: "#B9C2CC"
  disabled-text: "#5A6472"
typography:
  display:
    fontFamily: "platform UI font (SF Pro on macOS, Roboto on Android, fontconfig default on Linux)"
    fontSize: "26px"
    fontWeight: 600
    letterSpacing: "normal"
  headline:
    fontFamily: "platform UI font"
    fontSize: "20px"
    fontWeight: 400
    lineHeight: 1.3
    letterSpacing: "0.3px"
  title:
    fontFamily: "platform UI font"
    fontSize: "18px"
    fontWeight: 400
  body:
    fontFamily: "platform UI font"
    fontSize: "13.5px"
    fontWeight: 400
  label:
    fontFamily: "platform UI font"
    fontSize: "13px"
    fontWeight: 400
  action:
    fontFamily: "platform UI font"
    fontSize: "14px"
    fontWeight: 600
  caption:
    fontFamily: "platform UI font"
    fontSize: "12px"
    fontWeight: 400
rounded:
  checkbox: "3px"
  control: "4px"
  group: "6px"
  pill: "22px"
  stadium: "999px"
spacing:
  tight: "6px"
  sm: "8px"
  md: "10px"
  lg: "12px"
  xl: "14px"
  gutter: "18px"
  dialog: "24px"
components:
  button-send:
    backgroundColor: "{colors.signal-teal-deep}"
    textColor: "{colors.pure-white}"
    rounded: "{rounded.pill}"
    padding: "9px 22px"
    typography: "600 14px"
  button-send-disabled:
    backgroundColor: "{colors.disabled-fill}"
    textColor: "{colors.disabled-text}"
    rounded: "{rounded.pill}"
    padding: "9px 22px"
  button-cancel:
    backgroundColor: "{colors.pure-white}"
    textColor: "rgba(0, 0, 0, 0.87)"
    rounded: "{rounded.pill}"
    padding: "9px 22px"
    typography: "600 14px"
  button-outline:
    backgroundColor: "transparent"
    textColor: "{colors.paper-white}"
    rounded: "{rounded.stadium}"
    padding: "9px 16px"
    typography: "400 13px"
  button-filled:
    backgroundColor: "{colors.signal-teal-deep}"
    textColor: "rgba(0, 0, 0, 0.87)"
    rounded: "{rounded.stadium}"
    height: "40px"
    padding: "0 24px"
  field:
    backgroundColor: "{colors.field-ink}"
    textColor: "{colors.paper-white}"
    rounded: "{rounded.control}"
    padding: "8px 12px"
    typography: "400 13.5px"
  checkbox:
    backgroundColor: "{colors.signal-teal-deep}"
    textColor: "{colors.pure-white}"
    rounded: "{rounded.checkbox}"
    size: "18px"
  panel:
    backgroundColor: "{colors.panel-ink}"
    textColor: "{colors.paper-white}"
    rounded: "{rounded.control}"
  status-strip:
    backgroundColor: "{colors.status-slate}"
    textColor: "{colors.paper-white}"
    padding: "8px 14px"
    typography: "400 13px"
  header:
    backgroundColor: "{colors.header-slate}"
    textColor: "{colors.paper-white}"
    padding: "10px 18px"
---

# Design System: KindBeamer

## Overview

**Creative North Star: "The Quiet Dispatch"**

A dispatch desk at night: documents arrive from wherever they already are,
get addressed, and are sent on. Nothing about the app is loud — the darker the
room, the better it reads. The palette is one narrow slate family stepped from
canvas to well, lit by a single signal teal that means *this is live*.

The calm is borrowed from the device the app serves. E-ink serenity: low glare,
soft contrast, reading-first; the window should feel like paper's opposite
number, not a control room. Workmanlike and blunt is the other half of the
attitude — dense 13–14px rows, short labels, square-ish slabs, no ornament
carrying meaning it does not need to. The one expressive act is the wordmark,
and even that is only a colour split.

The confirmed anti-reference is Amazon's own client: no charcoal-and-orange,
no marketing gloss, no imitation of official chrome. This app is openly the
unofficial tool.

**Key Characteristics:**
- One dark slate world with narrow tonal steps between surfaces.
- Exactly one expressive colour, Signal Teal, reserved for state and the
  primary action.
- Borders and tonal steps do all the separating; nothing floats, nothing casts
  a shadow.
- The platform's UI font at fixed sizes; the wordmark is the only branded type.
- Utility density: short labels, full-width single column, status stated in
  sentences.

## Colors

One narrow slate family, dark-to-darker, with a single teal signal and one
subordinate link blue for text that leaves the task flow.

### Primary
- **Signal Teal** (#38C7B4): the live signal — focused field borders, the
  "kind" half of the wordmark, the 3px left edge of the status strip, the drop
  overlay's copy.
- **Deep Signal Teal** (#1FA392): the filled state — checkbox fills and the
  Send action. These are the largest teal areas the system permits.

### Secondary
- **Link Blue** (#7FB5FF): text links only — the footer's Settings / Need Help?
  / Manage your Kindle links and the sign-in error's recovery link. Never a
  fill, never a border.

### Neutral
- **Deep Slate** (#1F2630): the window canvas; every band sits on or above it.
- **Panel Ink** (#1A202A): panels — the document list, device picker and
  signed-out prompt; exactly one step darker than the canvas.
- **Field Ink** (#131922): input wells and the unselected checkbox fill; the
  darkest surface in the system.
- **Header Slate** (#2B3442) → **Header Shade** (#222A36): the header's
  vertical gradient, the system's only gradient.
- **Status Slate** (#232B37): the status strip band above the footer.
- **Footer Ink** (#1B222C): the action bar holding links and the two pills.
- **Slate Border** (#3B4657): the 1px outline on panels and fields.
- **Slate Border Light** (#5C6B84): outline buttons, the archive group, and the
  unselected checkbox stroke — the "attention" border.
- **Paper White** (#E8EDF4): primary text.
- **Muted Slate** (#A7B4C4): section headings and secondary text.
- **Faint Slate** (#6E7E92): hints, file sizes, separators, close icons.
- **Pure White** (#FFFFFF): pill-button labels and the checkbox check mark.
- **Row Selected** (#333333): the selected document row — deliberately the one
  neutral outside the slate family.
- **Disabled Fill** (#B9C2CC) / **Disabled Text** (#5A6472): the Send pill at
  rest.

### Named Rules
**The One Signal Rule.** Signal Teal appears only where something is live or
selected: focus, checked, sending, the wordmark's "kind", the strip's edge.
It is never a background for anything larger than a checkbox or an action pill.

**The Two-Accent Ceiling.** Link Blue exists to mark text links and nothing
else. A third accent hue is an implementation mistake, not a design decision.

## Typography

**Display Font:** platform UI font — SF Pro on macOS, Roboto on Android,
fontconfig default on Linux (no bundled face)
**Body Font:** the same family, always

**Character:** the system voice at fixed sizes. The app looks native on every
platform it ships to, and the only branded type moment is the wordmark, where
weight changes mid-word instead of a font changing.

### Hierarchy
- **Display** (600, 26px): the wordmark only — "kind" in Signal Teal at 600,
  "beamer" in Paper White at 300.
- **Headline** (400, 20px, 0.3px letter-spacing): section headings "Your
  document" and "Delivery options", in Muted Slate rather than Paper White.
- **Title** (400, 18px; 17px in the sign-in dialog): dialog titles.
- **Body** (400, 13.5px): metadata field text, document names, device names,
  the archive label.
- **Label** (400, 13px): footer links, "Add files…", status-strip text,
  captions in dialogs.
- **Action** (600, 14px): the Send and Cancel pills — the heaviest text in the
  app.
- **Caption** (400, 12–12.5px): file sizes, helper copy, the credential-backend
  note in Settings; Faint Slate.

### Named Rules
**The System-Voice Rule.** The platform UI font at fixed sizes is the rule and
the wordmark is the only exception. No bundled typeface, no display font, no
all-caps labels.

## Layout

Single column, top to bottom, four fixed bands: header, scrolling body, status
strip, action bar. The window is 880×700 with a 620×520 floor; on a phone the
same structure is fitted inside `SafeArea` rather than reflowed, so there is no
separate mobile composition.

The body is one vertical list inside an 18px gutter, with a rhythm clustered
tight: 6 / 8 / 10 / 12 / 14px gaps, 8px between a heading and its content, 14px
between the two sections. Both pills are bottom-right; links wrap bottom-left.

The only inner scrolling is inside panels: the device list is capped at 168px,
and the document list grows with its contents. Dialogs are centred slabs —
sign-in 640 wide × 560 tall maximum, Settings 460 wide — and the sign-in insets
collapse from 40/24px to 10/12px below 600px of width.

## Elevation & Depth

Flat by doctrine. Nothing casts a shadow; depth is entirely tonal steps
(canvas #1F2630 → panel #1A202A → well #131922) plus 1px borders. The header
gradient is the single departure from flat fills, and the drop overlay is a
flat 80% scrim (#141A22 at 80% opacity), not blurred glass. Material's own ink
ripples on rows and dialogs are behaviour, not the system's depth language —
they are incidental, not a model to extend.

### Named Rules
**The No-Shadow Rule.** No drop shadows, glows, blurs or glassmorphism. A
surface that needs to separate gets a 1px border or one tonal step, and
nothing else.

## Shapes

Tight corners for anything that holds content — 3px checkbox, 4px fields and
panels, 6px archive group — and full roundness for anything pressed as an
action: 22px pills for Send and Cancel, a stadium for "Add files…".

Borders are always 1px. Focus changes the field border's colour to Signal Teal
rather than thickening it. The wordmark has no container, badge or icon lockup
in the header.

### Named Rules
**The Slab-or-Pill Rule.** If it holds content it is a slab with a 3–6px
corner; if it is an action it is a pill. Nothing between: no 8–16px "card"
radius, no square action buttons.

## Components

### Buttons
- **Shape:** pills (22px); the header's "Add files…" is a stadium outline.
- **Send:** Deep Signal Teal fill, Pure White 14px/600 label, 9×22px padding.
  Disabled: Disabled Fill with Disabled Text, no press feedback at all.
- **Cancel:** Pure White fill with an 87% black label and the same pill
  geometry — the app's only light button, and deliberately the quieter twin of
  Send.
- **Add files…:** transparent with a 1px Slate Border Light outline, Paper
  White 13px label.
- **Filled (Sign in, Continue):** Deep Signal Teal fill at Material's 40px
  height, with the scheme's default foreground (black today — the one place
  contrast is not hand-tuned yet).
- **Outlined (dialogs):** Material defaults at a 4px radius, used for Refresh
  devices, Sign out and Close. Paper White label text.
- **Links:** Link Blue, 13px, underlined; the footer joins them with Faint
  Slate `|` separators.

### Fields
- Field Ink fill, 1px Slate Border, 4px corner, 12×8px padding, Paper White
  13.5px text, Faint Slate hints (`<Document Title>`, `<Document Author>`).
  Focus swaps the border to Signal Teal; there is no glow and no shadow.
  Fields are disabled, and show only their hints, until a document is selected.

### Checkboxes
- 3px corner with a 2px stroke: unselected is Field Ink with a Slate Border
  Light stroke; selected is Deep Signal Teal with a Pure White check. Rows are
  dense and the whole row is the target, so the box itself stays small.

### Panels
- Panel Ink fill, 1px Slate Border, 4px corner. Document list, device picker,
  signed-out prompt. A selected document row is a flat Row Selected fill with
  Paper White text; nothing else marks it.
- The device rows and the archive option share the dense CheckboxListTile
  pattern: checkbox first, label at 13.5px.

### Archive group
- The archive checkbox sits in its own 6px-corner box with the lighter Slate
  Border Light stroke — the only panel drawn with the light border, which is
  what makes it read as a separate decision from the device list above it.

### Status strip
- Status Slate fill, a 1px #151B23 top hairline and a 3px Signal Teal left
  edge; the text is centred, 13px, Paper White. It always states the send's
  current fact, including "No valid document is selected to send."

### Header
- 10×18px padding over a vertical gradient from Header Slate to Header Shade,
  closed with a 1px #1C1C1C hairline. Wordmark left, "Add files…" right.

### Dialogs
- Flat slabs in the canvas colour with no shadow of the system's own: sign-in
  is a 640×560 max panel built around the webview (title row with 20px side and
  16px top padding, close icon 18px) with the paste fallback below; Settings is
  a 460-wide, 24px-padded slab with an 18px title and outlined actions.

### Drop overlay
- The whole window under a #141A22 80% scrim, centred on a 110px #93A3B5
  upload icon, "Drop files here" at 26px and "to send to your Kindle" at 16px,
  both Signal Teal.

## Do's and Don'ts

### Do:
- **Do** put state changes in Signal Teal only: field focus, checked, sending,
  the wordmark's "kind", the status strip's left edge.
- **Do** separate surfaces with a 1px border or exactly one tonal step (Slate
  Border #3B4657 on Panel Ink #1A202A over Deep Slate #1F2630).
- **Do** keep section headings in Muted Slate at 20px/400 with 0.3px
  letter-spacing, not Paper White.
- **Do** keep the four bands in order: header, scrolling body, status strip,
  action bar — the same order on desktop and phone.
- **Do** state the current send fact in the strip, in a full sentence, at 13px
  Paper White.

### Don't:
- **Don't** add shadows, glows, blurs or glassmorphism (The No-Shadow Rule).
- **Don't** let teal cover more than a checkbox or an action pill; the Send
  button is the ceiling.
- **Don't** introduce a third accent hue; Link Blue is the whole budget for
  text links.
- **Don't** bundle a font or add a display face; the system UI font is the rule.
- **Don't** use 8–16px card radii or fully square actions (The Slab-or-Pill
  Rule).
- **Don't** adopt the official client's charcoal-and-orange or any
  Amazon-adjacent brand colour.
