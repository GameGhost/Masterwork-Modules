# Template Guidelines & Reference

All layouts below are built and visually approved. This doc is no longer a working log — it's the
reference companion to `assets/style.css` and `layouts/*.mws.yaml`: the conventions every layout
follows, and a per-layout catalog of structure/assets, for whoever next builds a layout here or
applies this template to a real module (`cost-of-disease` first, then the other two). Not packaged
with the module (`Masterwork.ModuleFormat.ModulePackage` excludes it, same as `.source/`/`README.md`)
— reference only, never shipped in a `.mwm`.

---

## 1. Cross-cutting conventions

These apply to (almost) every layout and are built once, generically, rather than per-layout.

### 1.1 Responsive strategy

Two treatments, switched at `app.css`'s existing `min-width: 48rem` breakpoint (no new breakpoint
needed):

- **Wide (≥48rem)**: full letterboxed frame — background/border stretch to fill the viewport
  edge-to-edge.
- **Narrow (<48rem, phone portrait)**: the border art is cropped to thin top/bottom strips via a
  pure CSS `transform: scaleX(1.6667)` on the border layer under the narrow media query (crops 20%
  off each side, stretches the remaining 60% to fill the width — retune per-border if a different
  border's usable frame proportions differ). No side border art in this mode; content runs edge to
  edge with a basic reading margin.

A third, independent breakpoint — **short (`max-height: 40rem`, phone landscape)** — sits alongside
the two above rather than replacing either: width and height are orthogonal (a landscape phone is
often *wide* by the ≥48rem test above while still being short), so a layout can need both a wide- and
a narrow-width treatment *and* its own short-height tightening. Already used by `score_panel`/
`ranking` (outer padding and header spacing shrink toward a minimal buffer) and `note`/`note_clear`
(their own popup-container top offset switches from viewport-relative to a fixed px one — see that
rule's own comment for why: on a short viewport the popup needs to clear the *hosting passage's own
border*, a fixed-thickness frame regardless of viewport height, the same reasoning the narrow-width
variant already uses for the same property). Reach for this breakpoint whenever a layout's own
vertical spacing was tuned assuming a portrait-ish aspect ratio and would either overflow or waste
proportionally too much space once height gets scarce independent of width.

### 1.2 Three-layer composite

Every bordered view is a stack, bottom to top:

1. **Content layer** — background image (full-bleed) + the actual passage/popup content. The
   *only* layer that scrolls. Title sits either above the border (overlapping it) or pinned outside
   the scrolling region.
2. **Progress bar layer** (only on layouts that have one — §1.4) — behind the border, in front of
   content, landing inside the border's cutout.
3. **Border layer** — the frame, full view size, `pointer-events: none` so clicks pass through.
4. **App chrome** (back button, timeline scrubber, options gear) — always on top, fixed position,
   structurally outside `PassageView` (`Play.razor`) — layouts must not fight with it.

Popups follow the same model at popup-container size: fixed (or fixed-max) frame, scrollable
content region inside.

Layout `.mws.yaml` chrome files may supply border/progress images via `image` nodes with a `style`
field mapping to a CSS class, or CSS may position/composite them directly (pseudo-elements,
absolute positioning) — whichever is easiest per layout; the app never inspects a node's
`style`/`layout` to decide what goes where.

### 1.3 Border image assignments

| Layout | Border asset | Progress-bar cutout? |
|---|---|---|
| `narration` (incl. ending narration) | `narration_normal.png` | Yes |
| `introduction` | `narration_intro.png` | Yes |
| `hub_early` | `hub_red.png` | Yes |
| `hub_middle` | `hub_blue.png` | Yes |
| `hub_late` | `hub_brown.png` | Yes |
| `player_setup`, `score_panel`, `ranking` | `main.png` | No — plain perimeter, no notch |

Every bordered layout's frame renders via one shared CSS `border-image` 9-slice (not a per-layout
`image` node) — see §1.7/§1.8.

Unused border assets present in `assets/images/borders/` with no current layout: `narration_gold.png`,
`ending_gold.png`, `ending_normal.png`, `ending_circle_highlight.png`, `vignette.png` — fine to stay
in the pack unreferenced.

### 1.4 Round progress bar (`narration`/`introduction`/`hub_*`)

Driven by an integer `roundNum` session variable (1–9), read by each layout's `footer` region
(`layouts/narration.mws.yaml`, `hub_early.mws.yaml`, etc.):

1. **Bar background** (`progress/background.png`) — one strip pre-divided into 3 color segments
   (green/amber/red, one per generation). A `switch on: roundNum` picks one of 9
   `.style-progress-bg-N` classes, each `clip-path: inset(0 X% 0 0)` revealing `N/9` of the strip.
   `position: fixed` against the true viewport (the same box the border occupies), so it stays
   aligned regardless of `.mws-passage-body`'s own scroll position.
2. **Per-round label overlays** (`progress/{I1,I2,I3,II1,II2,II3,III1,III2,III3}-{diffuse,glow}.png`)
   — `-glow` = current round, `-diffuse` = passed, unreached rounds get no image node (nested
   `conditional`s per round, not a `switch`, since "not yet reached" must render nothing).
3. **Border-cutout-aware positioning**: since every bordered layout shares one fixed
   `border-image-width` (px), the bar's `left`/`width` use
   `calc((100vw - Npx) / 100vw * Xvw + Ypx)` — the `(100vw - Npx) / 100vw` factor rescales the
   usual vw-based proportion down to the viewport's *remaining* width after the border's fixed
   margin, and `+ Ypx` shifts in by that same margin, keeping the bar constant relative to the
   border's own inner edge at any viewport size. `N`/`Y` differ slightly between `hub_*` and
   `narration`/`introduction` (same border-image-width, different cutout position within it — see
   `style.css`'s own comment for the exact numbers).

Narrow-viewport variant: a `@media (max-width: 45.99rem)` block recomputes `left`/`width` for both
bar and labels to match the border's own narrow-mode crop-and-stretch (§1.1).

**CSS gotcha worth remembering**: a shared/grouped selector must only set properties every variant
needs *identically*. The one property meant to differ per variant (here, each label's own `left`)
must never also appear in the shared rule, or the higher-specificity shared rule silently wins and
the per-variant override becomes dead code.

### 1.5 Type system

- Base scale: 100% = 16pt, via `--mws-text-scale` on `body`. Content sized in `em` inherits this;
  border art (fixed-proportion raster) doesn't respond and isn't expected to.
- `text-sm`/`text-lg`/`text-xl` utility classes (em-based, relative to the scaled base) — usable in
  hand-authored and extractor-generated content alike.
- Font **`germania-one`**: `.mws-passage-title`/`.mws-passage-subtitle`/`.mws-popup-header` and
  every standard graphical button (§1.6). Body copy stays `Averia Libre` throughout, including
  `<input>` (doesn't inherit `font-family` by default in most browsers — needs its own explicit rule).

### 1.6 Links, actions, and buttons

**Standard graphical buttons** — one shared rule (`inputs/button_brown.png`/`_green`/`_red`) covers
sizing/shape/states; each color variant only sets its own `background-image`/`color`/`text-shadow`.
Sizing is **`rem`-based, not `em`** (§1.7 — otherwise the same button renders at different sizes
depending on which layout's own font-size hosts it). Labels uppercase. Hover =
`brightness(1.15)` filter + an explicit per-variant `:hover` color (needed because app.css's own
`.mws-link:hover` otherwise wins on specificity and reverts to the default link-blue). Pressed =
`transform: scale(0.85); opacity: 0.75` only (never width/height/padding, so it can't reflow
neighbors) — applies to every `.mws-popup-okay`/`.mws-popup-cancel` and `.style-btn-{color}` link.

**Inline bracketed links** — wrapped in square-bracket images, color keyed to context: **brown**
(`inputs/bracket-brown-{left,right}.png`) on parchment surfaces (narration, introduction, popups,
setup, scoring, ending); **blue** (`inputs/bracket-blue-{left,right}.png`) inside hub sections.
Hover = brighter text, pressed = darker, no visited state. `inputs/bracket-metal-{left,right}.png`
also exist, unreferenced by any current layout.

### 1.7 App chrome & single-scroll architecture

Reference implementation, reused by every bordered layout:

- **`.mws-play-chrome` must be `position: fixed; top/left/right: 0`** in module CSS — app.css's
  default `position: sticky` still occupies space in normal flow and pushes `.mws-passage` down.
  Safe to override from module CSS (only injected while this module is playing).
- **`body { height: 100vh; overflow: hidden; }`** + the layout's own root class as
  `display: flex; flex-direction: column; height: 100vh; overflow: hidden;` with `padding-top`
  reserving clearance for the fixed chrome bar, and `.mws-passage-body` as the
  `flex: 1; min-height: 0; overflow-y: auto` child — gives exactly one scrollbar (never a second,
  outer page-level one), unified across wide and narrow with no per-breakpoint duplication.
- **A known app.css gap**: `@media (min-width: 48rem) { .mws-passage { max-width: 40rem; margin: 0
  auto; padding: 1.5rem; } }` has no `layout-` qualifier, so it silently caps every passage to 640px
  wide on anything ≥48rem. Every bordered layout needs its own
  `.mws-passage.layout-{id} { max-width: none; margin: 0; ... }` override (a 2-class selector beats
  the bare 1-class one regardless of media-query nesting) — still unfixed in app.css itself as of
  this writing, so this override is required on any *new* layout too.
- **Popups must reset their own `font-size`.** A popup's DOM position is a descendant of whatever
  passage hosts it — `position: fixed` only escapes layout/containing-block, not CSS inheritance —
  so it silently inherits the host passage's own font-size bump unless its own container rule sets
  an explicit `font-size`.
- **A `transform` on any ancestor hijacks `position: fixed` descendants.** An element centered via
  `left: 50%; transform: translateX(-50%)` that also contains a `position: fixed` descendant (e.g. a
  popup footer meant to stay anchored to the true viewport) becomes that descendant's containing
  block instead of the viewport, silently breaking the fixed positioning. Center via `left`/`right`
  insets instead when this applies.
- **A decorative image with a baked-in transparent gutter/drop-shadow, or a full-viewport border
  frame, needs `border-image` 9-slicing, not `object-fit: fill`/`background-size: 100% 100%`** — and
  `border-image` can't live on an `image` node, so it's a CSS pseudo-element (`::before`/`::after`)
  instead. The slice marks off a fixed region from each source edge, `border-image-width` renders it
  at a fixed on-screen thickness, and only the flat straight runs between corners stretch (each
  along one axis only) — this is what every layout's outer frame, `panel_parchment.png`, etc. use.
  z-index order: background (-1) → parchment pseudo-element (0) → border pseudo-element (1) → text
  content (1, same layer as the border since it never visually overlaps it).

### 1.8 Unit conventions

Full authoritative rules live in `assets/style.css`'s own header comments (FONT-SCALING CONVENTION
and SIZING CONVENTION) — summarized here:

- **`vh`/`vw`** — for anything whose size/position must track the viewport-scaled border/background
  art (the progress-bar tray and its labels, a popup *area*'s own max-width/height and edge offsets
  capped by a fixed px/text-driven max — `note`'s `min-width: 50vh; max-width: 512px` pattern is the
  reference example).
- **Fixed `px`** — border widths themselves, and any offset *from* a border (viewport frame or a
  content box's own border/background) — so the offset never drifts out of sync with the border's
  own thickness as the viewport resizes. Every bordered layout's outer padding and its
  `border-image-width` share one fixed-px value for exactly this reason (an earlier `vh`/`vw` +
  fixed-`px`-border pairing drifted out of sync as the viewport resized — the general failure mode
  this rule prevents). Exception: text that deliberately overhangs a border (a title straddling a
  card's top edge) may use `em`/`rem` of the *text's own* size instead, since it's tracking the
  text, not the border.
- **`em`** — reading text, and anything that must size *with* reading text (inherits the
  already-`--mws-text-scale`-scaled computed size). `rem` does **not** respond to
  `--mws-text-scale` (it's root-relative, bypassing `body`'s own scaled font-size entirely) — reserve
  `rem` for chrome that should render identically regardless of a hosting layout's own font-size:
  standard button sizing (§1.6) and other fixed-aspect chrome art. `score_panel`/`ranking`'s few
  deliberate exceptions (structural sizing expressed in `em`, tracking text-scale on purpose because
  a baked-in background asset's own interior lines must stay in registration with the text) are each
  called out in their own CSS comment — don't generalize from them without the same underlying
  reason.
- **`rem`, not `em`, for padding/margin in ordinary relative flow** — favored over `em` specifically
  so a later font-size override on some ancestor can never silently compound into an unexpectedly
  large spacing value the way stacked `em` can.

---

## 2. Layout catalog

### `narration` / `introduction`

Real three-layer composite: `leather_large.png` background + `panel_parchment.png` content-panel
border-image + a per-layout outer-frame border-image (`narration_normal.png` /
`narration_intro.png` — otherwise identical, sharing every rule via combined selectors). Title
across the top edge (non-scrolling) → scrollable parchment-page content → round-tracker footer in
the border's bottom cutout. Brown-bracket inline links (§1.6). No subtitle in any reference
screenshot but the format still supports one (see ending narration below, which uses both).

"Preparations"-style passages are just `narration` with a slightly larger title — no separate
layout needed.

### Special-event overlay (not a distinct layout)

**Not tag-based** — the real signal is a bare `ViewSpecialEvent.instance.ShowEventPopup();`
statement inside a Cradle passage body (a non-yield-returned call, no story output of its own).
`PassageBodyVisitor.IsShowEventPopupCall` detects it at its call-site position and emits a
synthesized `{ Template: "Special Event", Style: "special-event" }` text node there (not forced to
the front — some call sites have real narrative content before them); the passage keeps
`layout: "narration"` like any other. `CanJoinGroup`'s text-consolidation pass must never merge a
`style: "special-event"` node into an adjacent text group, or the marker loses its identity.

Rendering: the node's own text is visually hidden (`color: transparent`, kept for screen readers) in
favor of three overlay images — center banner as the node's own `background-image`, two flanking
light-beam lines as `::before`/`::after` (works on a `text` node; wouldn't on an `image` node's
replaced-element `<img>`). `position: fixed; inset: 0`, full-viewport, `z-index: 999` (above passage
content, below `.mws-play-chrome`'s 1002). A `steps(1)`-keyframed `pointer-events` animation on the
same timeline as the opacity fade blocks clicks on the rest of the passage for the display's
duration without touching every link's own styling.

### `hub_early` / `hub_middle` / `hub_late`

`leather_splattered.png` background + a `border-image` outer frame (`hub_red`/`hub_blue`/
`hub_brown.png` per generation) — no parchment panel; content is a left-aligned, scrollable stack of
individually bordered `hub-card` sections (`borders/hub_section.png`, its own `border-image`
9-slice, fully transparent interior filled with a plain translucent color for legibility over the
leather). Title + subtitle pinned to the top, round-tracker footer, real `scroll_bar_lg.png`
scrollbar-thumb image, blue-bracket inline links. Sections are not collapsible (`collapsed: false`).

### `player_setup` (player count / name entry / town name)

One shared layout across all `Setup_01`–`Setup_07` passages (`leather_large.png` background +
`main.png` border, no progress-bar cutout) — chrome is identical across the three screens; content
differs per-passage the same way `narration` varies content. Shared title mechanism
(passage-level `title:`, not an inline text node). Input text color `#F2B781`, no native focus
outline. Continue uses the standard `btn-brown` button everywhere.

Distinct from the `setup` **popup** layout below, despite the name overlap — chosen specifically to
stay clear of that real, cross-module popup name.

- **Player count**: 3 buttons (`inputs/players_2.png`/`_3`/`_4`, "N Players" caption each), one row
  wide / stacked narrow.
- **Player name entry**: info/alert row (`icons/alert.png`, darkened translucent background, gold
  text) + prompt + text input (`inputs/input_large.png`) + Continue.
- **Town name entry**: same shape as name entry, plus a large "The Village" title.

### `note` / `note_clear` (popup)

`popup_paper_torn.png` background sized to its own aspect ratio wide, a viewport-percentage box
narrow (§1.7's fixed-footer pattern), standard `btn-brown` Okay. Header-free — just body text + one
action button. `note_clear` is identical except `background: transparent` on the overlay backdrop
(used when the passage underneath has nothing worth dimming); plain `note` keeps the darkened
backdrop for moments that hand off out of a flow into real content.

Distinct from the `setup` popup below — different background asset (`popup_paper_torn.png` vs
`popup_parchment_border.png`) and `setup` additionally has an icon/pin illustration.

### `setup` (popup)

The real, cross-module instructional icon popup (must stay named exactly `setup` to match every
other module's extracted content). `border-image` (not `background-size: 100% 100%` —
`popup_parchment_border.png`'s own gutter measured thin/uniform, ~1–1.5% each side), explicit
font-size reset (§1.7), fixed-viewport footer (`position: fixed` + `transform: translateX(-50%)`,
matching `note`) so buttons stay reachable regardless of scrollable content height.

Structure: parchment background, "Setup" title (localizable), scrollable content, fixed icon image
with pin/stud decoration, two buttons centered on the bottom edge. Assets:
`backgrounds/popup_parchment_border.png`, `popup/setup_icon_background.png`,
`popup/setup_brass_stud.png`. (`popup/setup_paperclip.png` also exists in the pack, unreferenced —
unresolved whether it belongs here.)

### `end_of_round` / `end_of_generation` (popups)

Two distinct layout ids sharing one CSS block (combined selectors — identical sizing, only
header/body text differs per instance, matching `docs/mws-format-latest.md` §7's own examples).
`popup_parchment_border_short.png` background. Clock icon is a `.style-popup-title::before` CSS
pseudo-element (not a `header:` image node — `{icon:...}` only resolves `icon://`, and
`generation_time.png` lives under `assets/images/popup/`). Fixed-size popup, icon + title on one
row, body text, single button centered on the bottom edge.

### `countdown_instructions` / `countdown_action` (bidding/voting)

One continuous parchment note — the instructions text never disappears; a small dark countdown pill
appears over the trigger button once clicked. Realized as a real nested `type: popup` (a popup node
inside another popup's own `content:`) — needs **zero engine changes**, `PassageYamlParser`/
`PassageRenderer`/`GameSession` already treat node lists recursively/uniformly. This retired the old
bespoke `VotingPopupContent` component and its `layout == "voting"/"bidding"` special case entirely
— every layout renders through the one generic path now.

- **`countdown_instructions`** (outer) — reuses `popup_parchment_border_short.png`. No `okay`/
  `cancel` of its own (pure container, carried away only by the nested popup's navigation). Content
  ends with the nested `countdown_action` popup, whose own `label` ("Start Bidding") renders inline
  as a standard green button. Give the trigger its own `style:` (e.g. `countdown-trigger`) and
  exclude that style from narration's blanket "every unstyled popup trigger gets inline brackets"
  rule (`:not(.style-btn-forward):not(.style-countdown-trigger)` — the general pattern any future
  graphical trigger hosted inside narration/introduction needs).
- **`countdown_action`** (inner, nested) — `backgrounds/popup_reveal.png` (676×338 weathered dark
  pill) for the countdown display. Text/shadow match the narration title's own embossed-metal look,
  at 2x size. Own backdrop darker than the outer note's, so opening it visibly deepens the dim.
  Dismissal is a click "anywhere on the popup" — the `mws-popup-okay` button covers the full
  viewport invisibly (`position: fixed; inset: 0; background: none; color: transparent`),
  `pointer-events: none` until a `steps(1)` keyframe (same duration as the countdown pill) flips it
  to `auto`. Nothing to keep in sync with JS or an engine timer.
- REVEAL and the digits are real, restext-backed text (`Countdown_Three/Two/One/Reveal`), not a CSS
  `content`-cycling pseudo-element (can't be localized) — four stacked text nodes, each
  `position: absolute` over the same spot, individually timed via discrete (`steps(1)`) opacity
  keyframes. Every keyframe set needs an explicit 100% stop, or the missing endpoint falls back to
  the *unanimated* base value, visibly resetting the display right after REVEAL.
- CSS gotcha: a nested popup's own `.mws-popup-container` selector must use `>` (direct-child), not
  a plain descendant selector, on the outer popup's own rules — otherwise the outer's rule also
  matches the inner popup's container (nested inside the outer's DOM subtree) and leaks styling onto it.

### `prompt` (popup)

`popup_bordered.png` (961×299, corner-bracket ornaments only, opaque art touches the canvas edge
with no connecting frame — `border-image` mainly keeps the corners from stretching). Fixed-size
`<input>` (`20rem` × `3.2rem`, not percentage/max-width-constrained, unlike `.style-setup-input`),
reusing `input_large.png`. Fixed border popup, larger prompt text (centered, no scroll), input
field, action buttons anchored to the true viewport (`note`'s fixed-footer technique) below.

Named `prompt`, not `input` — `input` is already a node type name (format spec §6) and this layout's
content always includes one; keeping the names distinct avoids "input the layout" vs. "input the
node" ambiguity.

### `choice` (popup)

Generic bordered popup, not a bespoke radio-select UI — `backgrounds/panel_general.png` (opaque
right to every edge, no transparent gutter; still `border-image`'d so corner rivets don't stretch
into ovals at a different aspect ratio), centered header, centered content, Continue button. Its
real ongoing job is exercising the **checkbox** input style
(`.mws-input input[type="checkbox"]` using `checkbox_outline.png`/`checkbox_checkmark.png`), which
`score_panel`'s Tie-Break 1 also needs — a true radio-group input type remains an open MWS-format
question (§3), not resolved by this layout.

### `score_panel` (`ScoreEntry` / `TieBreaker1` / `TieBreaker2`)

`leather_purple.png` background, shared `main.png` outer frame. Rows sit inside one outer
`section style: 'score-card'` (the card *is* `.mws-passage-body`'s own scrollable region, via
`popup_parchment_border.png` as a `border-image`) — Continue is a sibling *after* the card, not
inside it, so it sits in normal flow at the card's actual bottom edge. Each player row is a
`section style: 'score-row'`, sharing the header row's exact flex geometry for centering.
`inputs/player_highlight.png` is a white alpha shape, not a colored sprite — CSS supplies the purple
fill via `mask-image` + `background-color`. Score input: `inputs/input_small.png`, `max-width: 8rem`
with a fixed `2.6rem` height (not aspect-ratio-locked, so it can shrink narrow without distorting).
Continue: `style: 'btn-brown'`.

Help popup (`score_help` layout): `button_question.png` fixed-position trigger
(`style: 'help-trigger'`), `popup_parchment_border.png` card, real `button_close.png` Cancel. Corner
-overlap footer offset (`top/right: -26px`) needs a narrow-viewport override pulling it to a small
*positive* inset instead — at `94vw` there's no longer enough slack outside the card for a
negative-offset corner button, it renders off the visible viewport otherwise. `game_complete` below
has the identical footer pattern/fix at a smaller offset (`-12px`).

### `ranking`

`leather_large.png` + `main.png` (same as `narration`/`player_setup`, not a distinct panel).
`panel_ranking.png` cannot shrink to fit a short viewport like every other card here — its three
gold divider lines are pixel-baked into the art, not drawn by CSS. Measured directly off the asset:
divider centers sit at exactly 1/3, 1/2, 2/3 of the way through a "6 equal row-units" model (blank
unit / row / row / row / row / blank unit). The panel's own height is therefore a **fixed `em`**
value (`18em` = 6 × 3em/unit) with `aspect-ratio: 1734/698` supplying width from that height — never
aspect-ratio-driven-*by*-width, which would let the panel shrink out of registration with the lines.
`.mws-passage-body` is a plain scroll wrapper around the fixed panel (matching `hub_*`'s own
`flex:1;min-height:0;overflow` body) so a viewport too small for the fixed panel scrolls to it
instead of squeezing it.

Rows are CSS grid (`auto 1fr 1.4em` columns: degree / name / crown), not flex-with-margin-auto — the
crown column is a fixed-width track reserved whether or not that row's conditional crown node
actually rendered, keeping every name's right edge aligned regardless of who's tied for first (a
flex-row-with-margin-auto approach shifts the name whenever a neighboring row's crown adds trailing
width). Text/crown sizing doubles via one `font-size: 2em` on the row (everything nested — degree,
name, the crown's own pre-existing `width: 1.4em` — scales automatically as a result, no need to
touch each element's own size). Left/right panel padding is `em`, not the usual `px` (§1.8's noted
exception) since this whole panel is deliberately text-scaled, not viewport-scaled.

2-3 player games leave the unused row(s) blank — no baked-in 2-row/3-row art exists to switch to.

### `game_complete` (popup)

Large parchment popup — `popup_parchment_border.png`'s **long** 984×731 variant (not the `_short`
985×634 one `end_of_round`/`end_of_generation` use). Centered pinned photo-collage image overlapping
the top edge (negative margin pulls it up out of the card). Real `button_close.png` Okay button over
the popup's own top-right corner — same corner-overlap-offset narrow-viewport fix as `score_help`
above (smaller offset, `-12px`).

### Ending narration

Identical to standard `narration`, but the one layout that exercises both title *and* subtitle at
once ("Editor's Note" / "August 1923"). The "continue to game over" action is a graphical floating
button (`inputs/button_forward_orange.png`, `style: 'btn-forward'`) fixed to the viewport corner,
not an inline bracketed link/popup trigger — needs the same trigger-`style:` + narration-bracket-
exclusion pattern documented under `countdown_instructions` above
(`:not(.style-btn-forward)` already present in narration's own CSS).

---

## 3. Open items

- **Radio-group input** (`choice` layout) — format-level question (new input type vs. styled
  booleans), not currently addressed by anything built here.
- **`setup` popup's `popup/setup_paperclip.png`** — present in the asset pack, unreferenced by any
  built rule; unclear whether it belongs on this popup or is leftover from a different screen.
- **app.css's generic `@media (min-width: 48rem) { .mws-passage { max-width: 40rem; ... } }`**
  (§1.7) still has no `layout-` qualifier — every bordered layout must keep overriding it
  individually rather than this being fixed once at the source.

## 4. Out of scope here

Main menu, options/settings, pause popup, help, scenario select, log book/achievements gallery —
either app-shell chrome (not a module's `layouts/` folder) or Phase 3 (achievements, deferred).
