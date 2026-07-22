# View Requirements

Working document for building out the real visual treatment of each layout, one section at a
time. **Add notes/corrections inline as we go** — headings marked `TBD`/`OPEN QUESTION` are things
I couldn't confirm from the screenshots and asset files I've looked at so far.

Status legend: 🔲 not started · 🟡 rough pass exists (from an earlier session, needs rework per the
notes below) · ✅ matches reference closely.

This revision supersedes the first draft. Source of truth is now
`Masterwork-Design/Reference/Screenshots/screenshot-summary.md` (the authoritative per-screenshot
catalog, naming convention `<prefix>-NN[L]-<description>.png`) cross-checked against the actual
asset files currently in `my-fathers-work-template/assets/`. Anywhere this doc names an asset file,
it's been confirmed to exist on disk under that exact name.

---

## 1. Cross-cutting architecture

These apply to (almost) every view and should be built once, generically, rather than per-layout.

### 1.1 Responsive strategy — resolved

Two treatments, switched at the existing `min-width: 48rem` breakpoint (`app.css`'s existing
mobile/desktop split — no new breakpoint needed):

- **Wide (≥48rem)**: full letterboxed frame. Background and border images stretch/squash to fill
  the viewport edge-to-edge; aspect ratio is **not** preserved.
- **Narrow (phone portrait, <48rem)**: an alternate treatment where the border art is shown only as
  thin strips at the top and bottom of the viewport, cropped and sized to the width of the
  progress-bar segment (see §1.4) rather than the full frame. Content extends to the left/right
  edges with just a basic reading margin — no side border art at all in this mode.

**Resolved (proven on `setup`)**: not a pre-cropped asset — a pure CSS `transform: scaleX(1.6667)`
on the border `<img>` under the narrow media query, which crops 20% off each side and stretches the
remaining 60% to fill the width. `1.6667` is a starting value (20%-off-each-side), easy to retune
per layout if a different border's usable frame proportions differ; switch to real pre-cropped
top/bottom assets later only if the stretch starts looking soft. This is now a proven, reusable
pattern — see §1.7.

### 1.2 Three-layer composite per view — confirmed

The frame art has a transparent/black interior and a built-in cutout for the progress bar (only on
the borders that have one — see §1.3). Every view with a border is a stack of (bottom to top):

1. **Content layer** — background image (full-bleed) + the actual passage/popup content. **This is
   the only layer that scrolls.** Title text sits either above the border (overlapping it) or
   pinned to the top of the view, outside the scrolling region.
2. **Progress bar layer** (only on views that have one — §1.4) — behind the border, in front of
   content, positioned to land inside the border's cutout.
3. **Border layer** — the frame PNG, full view size, `pointer-events: none` so clicks pass through.
4. **App chrome** (back button, timeline scrubber, options gear) — always on top, fixed position,
   structurally outside `PassageView` already (`Play.razor`) — layouts must not fight with it.

Popups follow the same model at popup-container size: fixed (or fixed-max) size frame, scrollable
content region inside.

**Implementation latitude (confirmed)**: layout `.mws.yaml` files can supply the border/progress
images via `image` nodes with a `style` field mapping to a CSS class; CSS then positions them,
disables interaction (`pointer-events: none`), and layers them via `z-index` as needed. Whether a
given image lives in the layout's `header`/`footer` region or is just absolutely-positioned via CSS
is an implementation detail — "whatever is easiest and most maintainable" per your note.

### 1.3 Border image assignments — confirmed

| Layout | Border asset | Progress-bar cutout? | Reference |
|---|---|---|---|
| `narration` (incl. `Preparations`, ending narration) | `narration_normal.png` | Yes | Module-01, 03, 13 |
| `introduction` | `narration_intro.png` | Yes | Module-02 |
| `hub_early` | `hub_red.png` | Yes | Module-05 |
| `hub_middle` | `hub_blue.png` | Yes | Module-06 |
| `hub_late` | `hub_brown.png` | Yes | Module-07 |
| `event` (`ck2`-tagged passages) | *same as `narration`* — see §2 `event`, this is not a distinct border | Yes | Module-03D |
| Setup passages (count/name/town) | `main.png` | **No** — plain perimeter border, no bottom notch | Setup-01/03/05 |
| Scoring/Ranking passages | `main.png` | No | Scoring-05 |

Corrects the first draft's assumption that every border shares the same cutout geometry — confirmed
from Setup-01's screenshot that `main.png` has **no** progress-bar notch (no round tracker is shown
on setup/scoring screens at all, which checks out — those happen outside any generation/round).

**Unused border assets** (in `assets/images/borders/` now but no screenshot reference identified
yet): `narration_gold.png`, `ending_gold.png`, `ending_normal.png`, `ending_circle_highlight.png`,
`vignette.png`. Leaving them in the pack for now per your note — fine to stay unreferenced.

**Border rendering, updated**: every bordered layout's frame (`main.png` included, even though
setup has no progress bar) now renders via one shared CSS `border-image` 9-slice, not a per-layout
`image` node — see §1.7/§1.8's amendment for why, and for how this let the round progress bar
(§1.4) assume one fixed frame thickness across every layout that has one.

### 1.4 Round progress bar (`narration`, `introduction`, `hub_early`/`middle`/`late`) — ✅ built and visually approved

Built and confirmed against `assets/images/progress/`, driven by an integer `roundNum` session
variable (1–9) each layout's `footer` region reads (see `layouts/narration.mws.yaml`/
`introduction.mws.yaml`/`layouts/hub_early.mws.yaml` et al. — hub's own progress bar was built and
visually confirmed this round, reusing the identical mechanism):

1. **Bar background** (`progress/background.png`) — one wide strip, pre-divided into 3 color
   segments (green/amber/red — one per generation). A `switch on: roundNum` with 9 cases picks one
   of 9 `.style-progress-bg-N` classes, each a `clip-path: inset(0 X% 0 0)` revealing `N/9` of the
   strip. Both the shared positioning rule (`[class*="style-progress-bg-"]`) and the 9 individual
   `clip-path` rules are `position: fixed` against the true viewport, same box the border image
   itself occupies, so they stay aligned regardless of `.mws-passage-body`'s own scroll position.
2. **Per-round label overlays** (`progress/{I1,I2,I3,II1,II2,II3,III1,III2,III3}-{diffuse,glow}.png`)
   — `-glow` = current round, `-diffuse` = a passed round, unreached rounds get no image node at all
   (a pair of nested `conditional`s per round in the layout `.mws.yaml`, not a single `switch`, since
   "not yet reached" needs to render nothing). Each of the 9 `.style-progress-label-N` rules sets
   only its own `left` (tuned per-label against the live bar) — the shared rule must **not** also
   set `left`, see the specificity note below.
3. **Border cutout, fixed-width-aware positioning**: every bordered layout's frame now renders at
   the same shared fixed `border-image-width` (px, §1.7/§1.8's amendment), so `left`/`width` here
   use `calc((100vw - Npx) / 100vw * Xvw + Ypx)` instead of a plain `Xvw + Ypx` — the
   `(100vw - Npx) / 100vw` factor rescales the usual vw-based proportion down to the viewport's
   *remaining* width after the border's own fixed margins, and `+ Ypx` shifts in by that same fixed
   margin, so the bar's position stays constant *relative to the border's own inner edge* at any
   viewport size, the same way a plain vh/vw value keeps something constant relative to the whole
   viewport. `N`/`Y` differ slightly between hub_* and narration/introduction — same shared
   border-image-width, but the bar's own cutout position within it isn't pixel-identical between the
   border assets (style.css's own comment has the exact numbers).

**Narrow-viewport variant**: a `@media (max-width: 45.99rem)` block recomputes `left`/`width` for
both the bar background and each of the 9 labels, matching the border's own narrow-mode
`scaleX(1.6667)` crop-and-stretch (§1.1) so the bar continues to land inside the now-stretched
cutout. Same shared-rule-vs-per-variant split as the wide rules.

**CSS specificity pitfall hit and fixed this session** — worth calling out since it'll recur:
the shared `[class*="style-progress-label-"]` rule briefly also set `left`, "as a placeholder."
Because that selector (`.mws-passage.layout-narration .mws-image[class*="..."]`) has *higher*
specificity than the individual `.mws-image.style-progress-label-N { left: ...; }` rules (4
class-level selector components vs. 2), the shared rule's `left` silently won regardless of which
label was rendered — every label sat at the same spot no matter the round. **Rule of thumb**: a
shared/grouped rule must only set properties every variant needs *identically* (position, sizing,
z-index); the one property that's supposed to differ per variant must never also appear in the
shared rule, or the per-variant override becomes dead code. A related, separate bug hit earlier in
the same area: hand-edited per-label narrow-mode overrides missing the comma between grouped
selector lines (`.layout-introduction .mws-image.style-progress-label-1\n.layout-narration ...`
without a `,` between them merges two selectors into one invalid combined descendant selector,
silently matching nothing).

Last session's rough pass (`layouts/narration.mws.yaml` etc., pre-dating this work) used a `foreach`
over all 9 labels as colored text pills, always showing all 9 — fully replaced by the above.

### 1.5 Type system — resolved and built

- Base scale: 100% = **16pt**, applied via the existing `--mws-text-scale` custom property on
  `body`. Content sized in `em` inherits this; border art (fixed-proportion raster) doesn't respond
  and isn't expected to.
- `text-sm` / `text-lg` / `text-xl` utility classes built (`style.css`, em-based, relative to the
  scaled base) — usable both in hand-authored passages/popups and in extractor-generated output
  (e.g. end-of-round/generation popup headers). `text-sm` added this session for content that reads
  better smaller (a long intro paragraph on `setup`'s town-name screen).
- Font **`germania-one`** wired into `style.css`: `.mws-passage-title`/`.mws-passage-subtitle`/
  `.mws-popup-header` and every standard graphical button (§1.6) use it. Body copy stays
  `Averia Libre` throughout, including form inputs (which don't inherit `font-family` from
  ancestors by default in most browsers — needs an explicit rule on the `<input>` itself, not just
  its wrapper).

### 1.6 Links, actions, and buttons

**Standard graphical buttons — resolved and built.** One shared rule in `style.css` (keyed by a
combined selector across every popup Okay button using this shape plus `.mws-link.style-btn-brown`
/ `-green` / `-red`) covers sizing/shape/states; each color variant only sets its own
`background-image`/`color`/`text-shadow`:
- `inputs/button_brown.png`, `inputs/button_green.png`, `inputs/button_red.png` — sizing is
  **`rem`-based, not `em`** (see §1.7 for why — this was the fix for buttons rendering at different
  sizes depending on which layout hosted them).
- Labels are **uppercase** (`text-transform: uppercase`).
- Hover = `brightness(1.15)` filter + an explicit per-variant `:hover` color (needed because
  app.css's own `.mws-link:hover` rule otherwise wins on specificity and silently reverts a link
  button's color to the default link blue).
- Pressed = `transform: scale(0.85); opacity: 0.75` (transform/opacity only, never
  width/height/padding, so it can't reflow neighboring content) — applied generally to every
  `.mws-popup-okay`/`.mws-popup-cancel` and every `.style-btn-{color}` link.
- Still open: red is built but not yet exercised by any real content (no popup here sets a
  `cancel:` field yet) — matches the general style note that Red should default to Cancel.

**Inline bracketed links — still not built** (deferred along with narration/hub, per §1.1). Always
render wrapped in square-bracket images, color keyed to context: **brown**
(`inputs/bracket-brown-left.png` / `bracket-brown-right.png`) on any parchment-background surface
(narration, introduction, popups, setup, scoring, ending); **blue**
(`inputs/bracket-blue-left.png` / `bracket-blue-right.png`) inside hub sections. Hover = brighter
text, pressed = darker text, no visited state.

`inputs/bracket-metal-left.png` / `bracket-metal-right.png` also exist but aren't called out by any
screenshot yet — **OPEN QUESTION**: guess is these are for the hub's non-section top-level links (as
opposed to blue-bracketed links inside a hub `section`)? Need confirmation or another screenshot.

### 1.7 App chrome & single-scroll architecture — proven on `setup`, reuse for every future layout

Built and visually approved (not just planned) on `setup` — this is now the reference
implementation for every other bordered layout, not something to re-derive per-layout:

- **`.mws-play-chrome` must be `position: fixed; top/left/right: 0`** in module CSS. App.css's
  default is `position: sticky`, which still occupies its own space in normal document flow and
  pushes `.mws-passage` down by however tall it renders — `sticky` alone doesn't give a
  layout-independent top clearance. Safe to override from module CSS since it's only injected while
  this module is actually playing (cleared on leaving `/play`).
- **`body { height: 100vh; overflow: hidden; }`** + the layout's own root class as
  `display: flex; flex-direction: column; height: 100vh; overflow: hidden;` with
  `padding-top` reserving clearance for the now-fixed chrome bar, and `.mws-passage-body` as the
  `flex: 1; min-height: 0; overflow-y: auto` child, is what gives a layout **exactly one
  scrollbar** (never a second, outer page-level one) and lets content scroll internally if it's
  taller than the available space — unified across wide and narrow, no per-breakpoint duplication
  needed.
- **A known app.css bug**: `@media (min-width: 48rem) { .mws-passage { max-width: 40rem;
  margin: 0 auto; padding: 1.5rem; } }` is a *generic* rule (no `layout-` qualifier) that silently
  caps every passage's outer box to 640px wide on anything ≥48rem. Every bordered layout needs its
  own `.mws-passage.layout-{id} { max-width: none; margin: 0; ... }` to override it (2-class
  selectors beat the bare 1-class one regardless of which sits in a media query) — **worth fixing
  in app.css directly instead of re-overriding per layout**, flagged under §3.
- **Popups must reset their own `font-size`.** A popup node's DOM position is a descendant of
  whatever passage hosts it — `position: fixed` only escapes layout/containing-block, not CSS
  inheritance — so a popup silently inherits the host passage's own font-size bump (e.g.
  `setup`'s `1.6em`) unless its own container rule sets an explicit `font-size`. Every popup layout
  needs this reset; `note`/`note_clear` do it (`font-size: 0.8em` on `.mws-popup-container`).
- **A `transform` on any ancestor hijacks `position: fixed` descendants.** If an element needs to
  center itself via `left: 50%; transform: translateX(-50%)` *and* contains a `position: fixed`
  descendant (e.g. a popup footer that must stay anchored to the true viewport), that transform
  makes the element the fixed descendant's containing block instead of the viewport — silently
  breaking the fixed positioning. Center via `left`/`right` insets instead when this applies (see
  `note`'s narrow-mode container).
- **Standard graphical buttons must size in `rem`, not `em`**, for the identical reason — sizing
  otherwise compounds against whatever ambient font-size the *hosting* layout happens to use, so
  the same button renders at different sizes in a popup vs. inline in a passage. See §1.6.
- **A decorative image with a baked-in transparent gutter/drop-shadow, or a full-viewport border
  frame, needs `border-image` 9-slicing, not `object-fit: fill`/`background-size: 100% 100%` — and
  `border-image` can't live on an `image` node, so it moved to a CSS pseudo-element.** Superseded
  from an earlier version of this note (originally: "give the gutter-y image its own `position:
  fixed` `image` node, matched to `.mws-passage-body`'s box" — that fixed *alignment* but not the
  gutter's own internal stretch distortion). Both `narration`/`introduction`'s parchment panel
  (`backgrounds/panel_parchment.png`) and every layout's outer border frame now render via
  `border-image`: the slice marks off a fixed region from each source edge, `border-image-width`
  renders it at a fixed on-screen thickness, and only the flat straight runs between corners
  stretch — each along a single axis only. `border-image` and an `<img>`'s own `src` bitmap don't
  mix (the `<img>` still paints its own content, undistorted-border or not), so this lives on a
  `content: ''` `::before`/`::after` pseudo-element instead — the `style-layer-border`/
  `style-layer-parchment` `image` nodes have been removed from every layout `.mws.yaml`. `z-index`
  order unchanged: background (-1) → parchment pseudo-element (0) → border pseudo-element (1) → text
  content (1, same layer as the border since it never visually overlaps it). See §1.8's amendment
  for the unit this settled on (fixed `px`, not `vh`/`vw`) and why.

### 1.8 `vh`/`vw` vs `rem`/`em` — sizing convention

Two independent scaling mechanisms are in play in this file, and mixing them up is what caused most
of the positioning bugs this session (the parchment gutter drift, the progress-bar padding not
tracking the border, buttons sized differently per host layout). Pick the unit by asking **what is
this element's size actually relative to?**

- **`vh`/`vw` — for anything whose size or position must track the *viewport-scaled border/
  background art*.** The background/border/parchment layers themselves are `100vw`/`100vh` with
  `object-fit: fill`, so they stretch/squash to the window on every resize (§1.1, §1.2). Anything
  that has to stay visually locked to a specific spot on that art — the round-progress-bar tray and
  its 9 labels (§1.4), the parchment content-panel and the `.mws-passage-body` box matched to it
  (§1.7), a bordered layout's own outer padding (`narration`/`introduction`'s `10vh 4vw` — the
  border's own frame thickness grows/shrinks with the viewport, so the padding keeping content clear
  of it has to grow/shrink the same way, or it drifts under/over the frame as the window resizes) —
  needs `vh`/`vw`, not `rem`/`em`/`%`. A `%` value is relative to the *element's own box*, which
  usually isn't the same thing as "the viewport the border art is scaled to," so it doesn't
  substitute for `vh`/`vw` here even though it looks similar.
- **`rem`/`em` — for text, and for chrome/art that should scale with the reading-text baseline
  rather than the viewport.** Already documented at the top of `style.css` (the FONT-SCALING
  CONVENTION note): `em` for anything sizing actual reading text (inherits the already-scaled
  computed size, so it tracks `--mws-text-scale`); `rem` for chrome that deliberately should *not*
  grow with text — border widths on small UI chrome, and fixed-aspect button/backing art (§1.6's
  standard buttons, sized in `rem` specifically so the same button doesn't render at a different
  size depending on which layout's own font-size happens to host it).
- **A third case that looks like it needs `vh`/`vw` but doesn't: centered floating dialogs sized to
  their own art's aspect ratio.** `note`/`note_clear`'s container no longer even needs a fixed
  `aspect-ratio` (see the amendment below — it moved to `border-image`, so `height: auto` sizes to
  content now), but the underlying point still holds: a popup isn't pinned to a specific spot on a
  full-viewport border image the way `.mws-passage-body` is, so it doesn't need viewport-locked
  coordinates at all — `rem`-based `max-width` plus `height: auto` already lets it size itself
  relative to the space available. If a future popup's own art needs to sit flush against a screen
  edge instead, reach for `vh`/`vw` then — the choice is about what the element's size is
  *conceptually* relative to, not a blanket rule.

**Amendment — border-image sizing settled on fixed `px`, not `vh`/`vw`, and this section's earlier
guidance is superseded for that specific case.** Every bordered layout's outer frame, and
narration/introduction's parchment panel, moved to `border-image` 9-slicing this round (§1.2/§1.3/
§1.7's own amendment) — `object-fit: fill`/`background-size: 100% 100%` stretched a border's corners
and straight edges by whatever non-uniform factor the current viewport aspect ratio produced;
`border-image` keeps each corner at a fixed on-screen thickness and only stretches the straight
edge runs between them, each along a single axis. That fix only works cleanly if
`border-image-width` is a *single* value shared across both axes (or literally the same computed
`px` regardless of viewport) — pairing `vh` for top/bottom with `vw` for left/right (this section's
original recommendation) still leaves the four *corner* regions scaling non-uniformly, since `vh`
and `vw` track different axes at different rates unless the viewport happens to be square. The
fix actually shipped: every bordered layout (`setup` included) now shares one fixed-`px`
`border-image-width`/`-slice`, and the content-clearance padding/box insets that have to stay
flush against that border (passage padding, the parchment panel's own box, `.mws-passage-body`'s
inset) moved to matching fixed `px` alongside it — a `vh`/`vw` clearance value paired with a
now-fixed-`px` border would drift out of sync with it as the viewport resized, the same class of
problem this section originally used `vh`/`vw` to solve, just inverted (now the border is the fixed
reference, not the viewport). The round progress bar (§1.4) still needs to track the *viewport*
proportionally (a bar filling `N/9` of the available width), so it uses `calc()` to combine both:
`(100vw - border-margin-px) / 100vw * Xvw + border-margin-px` rescales a normal vw-based proportion
down to the space remaining after the border's fixed margins, then shifts in by that same fixed
margin — the general shape to reach for whenever something needs to be proportional to the
viewport **and** flush against a fixed-thickness border at the same time.

---

## 2. Per-view catalog

Screenshot filenames below are exact, from `Masterwork-Design/Reference/Screenshots/`.

### `narration` — ✅ built and visually approved

Built and confirmed across many rounds of screenshot feedback: real three-layer composite
(`leather_large.png` background image node + a `panel_parchment.png` content-panel `border-image`
and a `narration_normal.png` outer-frame `border-image`, both CSS pseudo-elements — §1.7/§1.8's
amendment), the single-scrollbar/fixed-chrome architecture (§1.7), narrow-mode border crop (§1.1),
the real round progress bar (§1.4), embossed uppercase title/subtitle styling (multi-directional
`text-shadow` stack), and brown-bracket inline links (§1.6). Passage outer padding, the parchment
panel's own box, and `.mws-passage-body`'s inset are all fixed `px` now (§1.8's amendment) so they
stay flush against the border's own now-fixed-`px` thickness at any viewport size.

- **Reference**: `Module-01A/B-Preparations*.png`, `Module-03A-Standard-Narration.png`,
  `Module-03B/C` (hidden section behind a guard link, then revealed), `Module-03E` (inline centered
  image nodes), `Module-03F` (long title, wraps).
- **Structure**: title across the top edge of the frame (not scrolling) → scrollable parchment-page
  content region → round-tracker footer in the border's bottom cutout. Back + pause buttons pinned
  top-left (app chrome, not layout content).
- **Assets**: border `narration_normal.png`; content background `backgrounds/leather_large.png`
  (the module-specific-background-with-fallback idea from the first draft is deferred, see §3 item
  5 — the template currently just uses the shared leather background directly); content-panel
  `backgrounds/panel_parchment.png`; scrollbar — no image asset, just a thin CSS bar (white) over a
  dark track, per the summary notes. Inline links: brown brackets (§1.6).
- **`Module-01` "Preparations"** is just `narration` with a slightly larger title — no separate
  layout needed, treat as a narration passage.
- No subtitle appears in any narration screenshot, but the format still supports one — confirm
  subtitle styling once we have a screenshot that uses it (the ending narration, `Module-13`, does
  use both title and subtitle — see below).

### `introduction` — ✅ built and visually approved

Same shape as `narration` above, sharing every rule via the combined `.layout-narration,
.layout-introduction` selectors in `style.css` — only the border asset differs
(`narration_intro.png`'s ornate gold Celtic-knot border vs. `narration_normal.png`). Built and
confirmed alongside `narration` in the same rounds of feedback.

- **Reference**: `Module-02A/B-Generation-I-Introduction*.png`.
- **Structure**: same frame shape as `narration` but with `narration_intro.png`. Content panel is
  `backgrounds/panel_parchment.png` inside a scrollable area. Links use the same brown-bracket
  styling as narration.
- **OPEN QUESTION — title/subtitle prominence**: your note says title/subtitle are *inverted* in
  prominence here vs. elsewhere. Looking at `Module-02A`, "YELLOW FEVER" (large) sits above
  "GENERATION I" (small) — the same large-over-small relationship as the hub screenshots
  ("YELLOW FEVER" / "EARLY YEARS"). I don't see an inversion in the image itself, so I may be
  missing what you meant (a different screenshot? a CSS-class-naming inversion rather than a visual
  one?) — flagging rather than guessing. Still unresolved; the built version uses the same
  large-title/small-subtitle relationship as narration.
- **Assets**: background `backgrounds/leather_large.png`, same as narration (see its own entry
  above re: the deferred module-specific-background-with-fallback idea).

### `event` (`ck2`-tagged passages) — 🔲 not started — **decision made, needs an extractor change**

- **Reference**: `Module-03D-Standard-Narration-with-Special-Event-Overlay.png`.
- **What the screenshot actually shows**: a passage that is visually identical to a normal
  `narration` passage (same `narration_normal.png` border, same progress bar, same parchment
  content) with a large "SPECIAL EVENT" banner (orange embossed text, flanked by
  `popup/special_event_line_left.png` / `special_event_text.png` / `special_event_line_right.png`)
  overlaid across the middle of the page. Per the historical Unity behavior (`ViewSpecialEvent`),
  this banner fades in then fades out, leaving the ordinary narration content visible underneath —
  it is a **transient overlay effect**, not a distinct background/border treatment.
- **Decided**: fold `ck2` into the `narration` branch of `CradleExtractor.InferLayout`
  (`CradleExtractor.cs:1050-1053`) rather than aliasing a separate `event` layout — `event` stops
  existing as a distinct `layout:` value. A `ck2`-tagged passage instead needs some other marker
  (`style` field on the passage, or a dedicated flag) that `narration`'s chrome/CSS can key the
  banner overlay off of. **This is an extractor code change** — not yet made; needs to happen before
  re-extracting `cost-of-disease` (which currently has passages tagged `layout: event` from the old
  behavior) or any other module with `ck2`-tagged content.
- **OPEN QUESTION**: is the banner's fade-in/out timing/trigger meant to play once on passage entry
  (CSS animation, `animation-fill-mode: forwards` ending in `display: none` or `opacity: 0`), or does
  it need to be re-triggerable (e.g. on `StepBack`/replay)? Assuming "plays once per render" is fine
  unless you say otherwise.

### `hub_early` / `hub_middle` / `hub_late` — ✅ built and visually approved

Built and confirmed: real three-layer composite (`leather_splattered.png` background + a
`border-image` outer frame on a `.mws-passage::after` pseudo-element, §1.2/§1.7/§1.8 — no parchment
panel, unlike narration/introduction: content is a left-aligned, scrollable stack of individually
bordered `hub-card` sections directly over the leather background), the single-scrollbar/
fixed-chrome architecture (§1.7) with a real `scroll_bar_lg.png` scrollbar-thumb image, narrow-mode
border crop (§1.1), the real round progress bar (§1.4, using the same fixed-`px`-aware `calc()`
positioning as narration/introduction), the same embossed title/subtitle treatment as narration/
introduction, and blue-bracket inline links (§1.6). Each `hub-card` section frame
(`borders/hub_section.png`) is its own `border-image` 9-slice too — its interior is fully
transparent (no baked-in gutter/shadow the way `panel_parchment.png` has), filled with a plain
translucent color behind the border-image layer for legibility over the leather background.

- **Reference**: `Module-05A/B-Hub-Early-Years*.png` (red), `Module-06-Hub-Middle-Years.png` (blue),
  `Module-07-Hub-Late-Years.png` (brown).
- **Structure**: title + subtitle (e.g. "Yellow Fever" / "Early Years") pinned to the top → 
  scrollable vertical stack of bordered sections → round-tracker footer in the border cutout.
- **Assets**: background `backgrounds/leather_splattered.png`; outer border `hub_red.png` /
  `hub_blue.png` / `hub_brown.png` (per-generation, same shared `border-image` slice/width as every
  other bordered layout — §1.8's amendment); section border `borders/hub_section.png`; scrollbar
  `inputs/scroll_bar_lg.png` (a real image asset here, unlike narration's plain-CSS scrollbar);
  inline links use **blue** brackets (`bracket-blue-left/right.png`), matching hub's distinct
  link-color rule from §1.6.
- Sections are not collapsible — full text always visible, matches using `section` nodes with
  `collapsed: false`.
- Gold background highlight seen in the screenshot is a Unity-only effect with no corresponding
  asset — per your note, omit it for now.
- The showcase index (`Example_Entry`/`01_Entry.mws.yaml`) itself uses `layout: 'hub_early'` and was
  restructured into grouped `hub-card` sections (Story Passages / Hub Passages / Popups) with an
  explicit round selector, so it doubles as an extra live example of this layout's card styling.

### `setup` passage layout (player count / name entry / town name) — ✅ built and visually approved

Built and confirmed across multiple rounds of screenshot feedback, wide and narrow: real
three-layer composite (`leather_large.png` background + `main.png` border, `main.png` has no
progress-bar cutout per §1.3), the single-scrollbar/fixed-chrome architecture (§1.7), narrow-mode
border crop (§1.1), `setup-alert`/`setup-input`/`setup-input-label` content styles, and
`btn-players-2/3/4` picker buttons using the real `players_2/3/4.png` assets (the old "no engine
support for image-backed nav buttons" note was overly cautious — it's a plain CSS `background-image`
on the link, no engine change needed). All `Setup_01`–`Setup_07` passages use `layout: 'setup'` with
a shared title mechanism (passage-level `title:` field, not an inline text node, so every setup
screen's heading is pixel-identical). Input text color `#F2B781`, no native focus outline. Continue
links use the standard `btn-brown` button (§1.6) everywhere — every setup passage was previously
missing a `style:` on this link entirely, silently falling back to the default blue underlined link.

- **Reference**: `Setup-01-Player-Count.png`, `Setup-03A/B-Player-Name-Entry*.png`,
  `Setup-05-Town-Name-Entry.png`.
- **Decided**: one shared `setup` passage layout, not three separate layout files — chrome
  (`backgrounds/leather_large.png` background, `main.png` border, no progress-bar cutout, see §1.3)
  is identical across all three; content differences are per-passage authoring, same pattern
  `narration` already uses for varying content. No layout files exist yet for these, so this is a
  clean start, not a rename.
- **Screen-specific content** (authored per-passage against the shared `setup` chrome):
  - **Player count** (`Setup-01`): 3 large buttons (`inputs/players_2.png` / `players_3.png` /
    `players_4.png`, each with a "N Players" caption below), centered on one row, reflowing to
    stacked on narrow viewports.
  - **Player name entry** (`Setup-03`): an info/alert row (darkened translucent background, gold
    text — uses the `icons/alert.png` icon) + prompt + a text input (`inputs/input_large.png`) +
    Continue.
  - **Town name entry** (`Setup-05`): same shape as name entry, plus a large "The Village" title.
- A gold background highlight is again a Unity-only effect — omit per your note.

### `setup_scenario` — 🔲 not started — newly identified gap, not in the original catalog

`00_Preparations.mws.yaml` (title "Setup - Scenario Box") is real content, not a throwaway
placeholder — it's the actual bridge passage the setup flow (`_Setup_07_TownNameEntry.mws.yaml`)
hands off to before reaching the showcase hub, matching the reference app's real "get ready to
play" moment between finishing setup and starting round 1. It correctly uses `layout:
'setup_scenario'` — confirmed against `cost-of-disease/layouts/setup_scenario.mws.yaml` (a real,
distinct layout id there too, still an unbuilt stub in that module as well) — this is **not** the
same thing as this template's own `setup` layout (that one covers player-count/name/town-entry
chrome specifically; cost-of-disease's own `layout: 'setup'` is actually a *popup* layout, an
unrelated reuse of the word). Since no `layouts/setup_scenario.mws.yaml` exists in this module yet,
the passage currently renders with no bordered chrome at all — flagging as a real gap this session's
question surfaced, not fixing blind: needs its own small round of the same three-layer-composite
treatment (likely `main.png`/`leather_large.png`, matching its sibling setup screens, but not
confirmed against a reference screenshot yet) before it can be marked built.

### `note` / `note_clear` (popup) — ✅ built and visually approved

Built and confirmed across multiple rounds: `layouts/note.mws.yaml` + `layouts/note_clear.mws.yaml`
(both empty chrome, CSS-only) and `style.css`'s shared `layout-note`/`layout-note_clear` rules —
`popup_paper_torn.png` background sized to its own aspect ratio on wide, a viewport-percentage box
on narrow (§1.7's fixed-footer pattern), standard `btn-brown` Okay button.

**`note_clear` is a new layout not in the original plan** — identical to `note` in every rule except
the backdrop, which is transparent instead of the standard darkened one (a single
`.mws-popup-overlay.layout-note_clear { background: transparent; }` override). Used for
`Setup_02`'s intro popup and the greeting popups of `Setup_03`–`Setup_06`, which show over an
already-empty `setup`-layout passage — nothing underneath worth dimming. `Setup_07`'s town-name
confirmation popup uses plain `note` (with backdrop) instead — it's the moment that hands off out of
the setup flow into real module content, where dimming the passage behind it reads better.

- **Reference**: `Setup-02-Player-Intro.png`, `Setup-04-Player-Greeting.png`,
  `Setup-06-Town-Name-Greeting.png` — three different moments (scenario intro blurb, per-player
  greeting, town-name greeting) that all use the **same simple torn-parchment popup**: header-free,
  just body text + a single action button.
- **Assets**: `backgrounds/popup_paper_torn.png`, standard brown button.
- **Distinct from the `setup` popup layout below** — that one (`Module-04`) has an icon/pin
  illustration and a different background asset (`popup_parchment_border.png` vs
  `popup_paper_torn.png`). These are two different popup shapes that happen to share the word
  "setup" informally.

### `setup` (popup) — 🟡 needs asset-name reconciliation, otherwise close

- **Reference**: `Module-04A/B/C-Setup-Popup*.png` — instructional popup with a pinned icon
  illustration, appearing (A) triggered by a link, (B) auto-shown over an empty passage, (C)
  auto-shown over a hub passage.
- **Structure**: parchment background, "Setup" title (localizable), scrollable content area, fixed
  icon image with extra pin/stud decoration, two buttons centered on the bottom edge.
- **Assets**: `backgrounds/popup_parchment_border.png`; `popup/setup_icon_background.png`;
  `popup/setup_brass_stud.png` (there's also a `popup/setup_paperclip.png` not mentioned in the
  summary table — **OPEN QUESTION**: is the paperclip used here too, or a leftover from a different
  screen?); standard green Okay / red Cancel buttons.

### `end_of_round` / `end_of_generation` (popups) — 🟡 rework with the short-popup asset

- **Reference**: `Module-08A/B-End-of-Round-popup*.png` (alt B = different body text, same layout),
  `Module-12-End-of-Generation-popup.png` (same layout, different header text — should be the same
  popup layout with header text supplied by the popup node, not two separate layouts).
- **Structure**: fixed-size popup, header with clock icon, body text, single button centered on the
  bottom edge.
- **Assets**: `backgrounds/popup_parchment_border_short.png` (note: **short** variant — different
  from the plain `popup_parchment_border.png` used by `setup`/score-help; first draft had this
  slightly wrong), `popup/generation_time.png` (clock icon), standard green button.

### Bidding preamble popup — `Module-09` — 🟡 rework, reuses `end_of_round`'s short-popup shape

- **Reference**: `Module-09-Bidding-Preamble-popup.png`.
- **Structure**: parchment popup, text, single standard green button — structurally identical to
  `end_of_round`'s shape. **OPEN QUESTION**: should this literally be the same layout as
  `end_of_round`/`end_of_generation` (same `popup_parchment_border_short.png`), just with different
  content, or does it deserve its own layout id since it's semantically a different moment? Leaning
  toward reusing the same layout — no visual difference identified.

### `reveal_countdown` — 🟡 rework against real reference (now available)

- **Reference**: `Module-10A-Bidding-Popup-countdown.png` (shows a number, e.g. "1"),
  `Module-10B-Bidding-Popup-reveal.png` (shows "REVEAL" text).
- **Structure**: fixed background image (`backgrounds/popup_reveal.png`), large centered text (the
  countdown digit, then "REVEAL"), sized to fit the panel. Backdrop is a **lightened**
  semi-transparent overlay — unusual, most popups darken the background; this one brightens it.
  Dismissed by clicking **anywhere** on the popup once the countdown completes (not a specific
  button) — confirms the earlier note that this needs the whole-popup-clickable interaction, not
  just an unlocked button.
- **Confirms the two-stage chaining approach** from the original implementation plan (self-navigating
  passage flipping a `_revealStage` variable between two auto-display popups) is still the right
  mechanism — no engine change needed. The CSS detail changes though: instead of a hidden/disabled
  button becoming clickable, the **entire popup surface** needs `pointer-events` re-enabled only
  after the countdown animation completes (same `animation-fill-mode: forwards` timing trick, applied
  to the popup's click-catcher rather than a button).

### `prompt` (popup) — 🔲 not started — new layout, decided name

- **Reference**: `Module-11A-Input-popup.png`, `Module-11B-Input-popup-with-numeric-value.png`.
- **Structure**: fixed border popup, larger-than-normal prompt text (centered, no scrolling), a
  large input field centered on/below the bottom edge (text centered inside it, no numeric
  spinners), action buttons centered near the bottom (below the input).
- **Assets**: `backgrounds/popup_bordered.png`, `inputs/input_large.png`, standard brown (okay) /
  red (cancel) buttons.
- **Decided**: a genuinely new layout the first draft missed entirely (used for in-game numeric/text
  prompts, e.g. the bidding amount or the "Legacy of Charity" heart-token count shown in one of the
  reference screenshots), named `prompt`, kept separate from `choice` — `choice` is a dark box for
  radio-style selection, `prompt` is a parchment numeric/text input, visually and functionally
  different.

### `choice` — 🟡 rework, now has real assets for the previously-missing radio group

- **Reference**: `General-Standaline-Select-Dialog.png` ("Choose Audio Voice").
- **Structure**: dark bordered box (`backgrounds/panel_general.png`, window background
  `leather_large.png` if used as a passage rather than a popup), large centered header, centered
  content, Continue button.
- **Assets now exist for real radio buttons**: `inputs/radio_selected.png` / `radio_unselected.png`
  — the first draft's "no radio-group input type, using a checkbox as a stand-in" gap can likely be
  closed now, **but** this is still an MWS-format question: does the format need an actual
  radio-group input type, or can this be built as N boolean/checkbox-style inputs styled with the
  radio assets and app-level logic ensuring only one is set? **Flagging as a format discussion**,
  not blocking the CSS/asset work.

### `score_panel` (`ScoreEntry` / `TieBreaker1` / `TieBreaker2`) — 🟡 rework with real assets

- **Reference**: `Scoring-01-Score-Entry.png`, `Scoring-02-Score-Entry-Help-popup.png`,
  `Scoring-03A/B-Tie-Break-1*.png`, `Scoring-04A/B-Tie-Break-2*.png`.
- **Structure**: floating panel/popup look — window background `backgrounds/leather_purple.png`,
  window border `main.png`, inner popup panel `backgrounds/popup_parchment_border.png`. Table-style
  Player/Score (or Player/Checkbox) rows, one per player (2–4 based on player count). A small help
  button (`inputs/button_question.png`) opens a help popup with additional scoring detail.
- **Confirms the `section`-wrapping requirement**: each player row needs a highlighted background
  (`inputs/player_highlight.png`, described as "color inverted, semi-transparent") — per your note,
  this needs each score/tie-break row wrapped in a `section` node so the highlight can be applied as
  a section background, rather than the current flat sequence of `text`/`input` nodes. This is a
  **hand-authored passage change**, not a layout/CSS-only change — flagged again under §3.
  Score input: `inputs/input_small.png`. Continue: standard brown button.
- **Tie-Break 1** (checked-completion): checkbox assets `inputs/checkbox_outline.png` +
  `inputs/checkbox_checkmark.png`, same row/table shape as score entry otherwise.
  **Tie-Break 2** (estate-upgrade count): identical shape to score entry, numeric input.
- **Help popup**: same `popup_parchment_border.png` background, same `player_highlight.png` section
  styling per scoring-detail row, close button `inputs/button_close.png`.

### `ranking` — 🟡 rework with real assets

- **Reference**: `Scoring-05-Rankings-dual-winner.png`.
- **Structure**: standard background/border (`backgrounds/leather_large.png` + `main.png` — **not**
  a distinct "dark stone panel" as the first draft guessed), a ranking-specific inner panel
  (`backgrounds/panel_ranking.png`), one row per player: rank ordinal (left, orange/tan), player
  name (right), crown icon after the name **only for players who actually placed 1st** (confirmed —
  the "every row shows a crown" note from the first draft was a screenshot-state artifact, not
  intentional; `Scoring-05`'s "dual winner" filename literally documents a tie-for-first case where
  2 of 4 players get a crown and the other 2 don't). Standard brown Continue button below.
- **Asset name resolved**: `ranking_crown.png` lives at `assets/images/inputs/ranking_crown.png` (an
  `image://inputs/ranking_crown` reference), not `icons/crown.png` — the first draft's proposed fix
  (rename into `icons/`) is unnecessary; just use an `image` node instead of the `{icon:...}` inline
  pattern in `Scoring_04_Ranking.mws.yaml`, as originally suggested.

### `game_complete` (popup) — 🟡 asset name correction needed, otherwise close

- **Reference**: `Module-14-Ending-Gameover-popup.png`.
- **Structure**: large parchment popup, centered pinned photo-collage image overlapping the top
  edge, Okay button (`inputs/button_close.png`, no label) positioned over the popup's top-right
  corner.
- **Asset name correction**: background is `backgrounds/popup_parchment_border.png` (the **long**
  variant, not the `_short` one used by `end_of_round`) — worth double-checking last session's rough
  pass used the right one.

### Ending narration — 🟡 same as `narration`, confirm subtitle styling

- **Reference**: `Module-13A/B-Ending*.png`.
- **Structure**: identical to standard `narration` (title **and** subtitle both used here — the one
  screenshot that actually exercises the subtitle). The only addition is the "continue to game over"
  action, styled as a graphical floating button in the bottom-right corner of the view rather than an
  inline bracketed link — `inputs/button_forward_orange.png`. This is stylable via the popup/link's
  own `label`-style override, not a new layout.

---

## 3. Hand-authored passage / extractor-pipeline implications

**Done this session**: `en-US.restext` written for the template, covering every user-facing string
in the seven `Setup_*` and four `Scoring_*` hand-authored passages (`Setup_*`/`Scoring_*`/
`Common_*` keys — one shared `Common_Continue` reused everywhere the label is literally
"Continue"). None of these passages reference cost-of-disease's extracted restext keys
(`TCOD_TownName_*`, `PlayerNameIntro_*`, `NameEntryTownConfirm_*`, `Number_*_Lower`) anymore. Still
to do: copy this restext (plus the passages/layouts themselves) back into the real modules during
template integration — the keys are namespaced specifically so they won't collide with a target
module's own extracted restext.

Still open, layered on top of the pure CSS/asset/layout work above and probably deserving separate
scoping:

1. **`event` layout mapping** (§2 `event`) — decided: fold `ck2` into the `narration` branch of
   `CradleExtractor.InferLayout`, replacing the separate `"event"` layout value with some other
   marker `narration`'s chrome can key its banner overlay off of. Not yet implemented — re-running
   extraction on any module with `ck2`-tagged passages (`cost-of-disease` currently has some tagged
   `layout: event` from the old behavior) will need this landed first.
2. **Score/tie-break row `section` wrapping** (§2 `score_panel`) — `ScoreEntry`, `TieBreaker1`,
   `TieBreaker2` passage overrides need each player row restructured from flat `text`/`input`
   sequences into `section`-wrapped rows so `player_highlight.png` can be applied as a per-row
   background. Hand-authored override change, not extractor. Not started — `score_panel`/`ranking`
   only got their restext keys this session, no visual/structural work yet.
3. **`Scoring_04_Ranking.mws.yaml` still uses `{icon:crown}`**, which doesn't resolve — the asset is
   `assets/images/inputs/ranking_crown.png` (an `image://inputs/ranking_crown` reference), not an
   `icons/` asset. Needs an `image` node instead of the `{icon:...}` inline pattern. Confirmed still
   present, not yet fixed — will render as a missing-icon placeholder until it is.
4. **Radio-group input** (§2 `choice`) — format-level question (new input type vs. styled
   booleans); not blocking, but worth a decision before building `choice` for real.
5. **Standard-name-with-fallback background pattern** (§2 `narration`/`introduction`) —
   `scenario_narration_background.png` (module-specific) falling back to `backgrounds/leather_large.png`
   (shared) needs to be a supported resolution behavior, not just a convention — **OPEN QUESTION**:
   does `AssetResolver`/CSS already support an image-not-found fallback chain, or does this need new
   engine/CSS work (e.g. a CSS `background-image` list with multiple `url()` fallbacks isn't
   standard — more likely this means the module CSS always references
   `image://scenario_narration_background`, and each real module supplies that file, with
   `leather_large.png` used only in the *template* module where no module-specific art exists)?
6. **app.css's `.mws-passage` wide-viewport bug** (§1.7) — `@media (min-width: 48rem) {
   .mws-passage { max-width: 40rem; margin: 0 auto; padding: 1.5rem; } }` has no `layout-`
   qualifier, so it silently caps every passage to 640px wide unless that specific layout overrides
   it. `setup` does; every future layout will need to as well unless this gets fixed once in
   app.css directly instead. Worth doing since it'll otherwise bite every new layout the same way.
7. **`setup`'s own outer padding is still `rem`-based (`4rem 2.5rem 2.5rem`), not `vh`/`vw`** —
   unlike `narration`/`introduction`'s padding, which was switched to `vh`/`vw` this session for the
   §1.8 reason (it needs to track `main.png`'s own viewport-scaled frame thickness the same way
   `narration_normal.png`'s does). `setup` shares the identical fixed full-bleed border mechanism, so
   the same reasoning applies to it in principle. **Not changed this session** — `setup` is already
   ✅ visually approved from its own dedicated round of screenshot tuning, and blindly converting
   units risks a silent regression (the exact top/side/bottom values need the same live-tune-against-
   screenshots pass `narration`'s `10vh 4vw` got, not a blind unit conversion) that nothing here can
   verify without a fresh look. Worth doing next time `setup` is revisited, not urgent on its own.
   `note`/`note_clear`/the `setup` popup are a **different, intentional** case — see §1.8's third
   bullet — their `rem` + `aspect-ratio` sizing is correct as-is, not a gap to close.

## 4. Not in scope here (app-level, not module content)

Main menu, options/settings, pause popup (`Module-00`), help, scenario select
(`App-01`–`App-04`), log book/achievements gallery — either app-shell chrome (not a module's
`layouts/` folder) or Phase 3 (achievements, deferred). Listed for completeness only.
