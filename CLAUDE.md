# Masterwork-Modules — Claude Instructions

## This Repository

Holds extracted, playable MWS modules for the Masterwork project — the *build output* of the
extraction pipeline, plus everything hand-authored on top of it (overrides, layout chrome,
per-module assets, packaged `.mwm` bundles). **Not the code repo, not the design/reference repo.**
Sibling of both:

- Code repo: `c:\Projects\Masterwork` — the extractor, engine, and app that read/write this repo's content.
- Design repo: `c:\Projects\Masterwork-Design` — Unity reference assets (`Reference/UnityOriginalApp/`)
  that extraction still reads sprite/progress data *from*. Its `Reference/ScriptsComplete/` and
  `Reference/ScriptsPartial/` (the raw Cradle C# source) are now **historical reference only** — see
  Extraction below. See `Masterwork-Design/CLAUDE.md` for that repo's own instructions.

This repo used to be `Masterwork-Design/Modules/`; it moved into its own git repo once module
content needed real version control independent of the design/reference material. Canonical module
building now happens entirely within this repo, including holding each module's own copy of the
Cradle source it's extracted from (`.source/`, see Module Layout below) — extraction no longer reads
`.cs` files from `Masterwork-Design` at all.

Layout at the repo root:

```
Masterwork-Modules/
├── progress-map.json          — shared --progress-map input (see below), used by cost-of-disease
├── cost-of-disease/           — one folder per module
├── cost-of-disease.mwm        — packaged bundle (built from cost-of-disease/, see Bundling below)
└── ...                        — future modules (fear-of-the-unknown, a-time-of-war) land here too
```

---

## Licensing

Module content in this repo (passages, overrides, layout chrome, per-module assets, manifests) is
project-internal — original MWS content, even though it was derived by running the extractor
against Renegade Game Studios' own Cradle source. The one exception is each module's own
`.source/*.cs` file — the canonical Cradle source extraction reads from. That file comes from RGS's
own community-resources release for *My Father's Work* (the same release, same archive/link, that
`Masterwork/src/Masterwork.App.Theme.MyFathersWork/NOTICE.md` documents for the app's theme
assets) — see this repo's own `NOTICE.md` for the full citation. Per that release, individual files
may be copied and modified as needed. Still: **never commit `.source/*.cs` (or anything else drawn
from `Masterwork-Design/Reference/` beyond that specific release) to the `Masterwork` code repo** —
that repo's own licensing rule is narrower and doesn't carry this exception.

---

## Module Layout

Each module directory (e.g. `cost-of-disease/`) follows the same shape:

| Path | Owner | Purpose |
|---|---|---|
| `manifest.yaml` | hand-maintained | Module id/title/description, thumbnail, player count/playtime, entry passage, `passages`/`passages_override` path overrides, `style` stylesheet reference |
| `passages/` | extractor-owned | One `{NNN}-{PassageId}.mws.yaml` per passage — overwritten wholesale on every re-extraction. Never hand-edit files here |
| `passages-override/` | hand-maintained | `.mws.yaml` files applied after `passages/` at module load time (`ModuleLoader.LoadFromDirectory`) — a matching `passage_id` replaces the extracted version, a new one is simply added. Never touched by extraction, so it survives re-extraction, but can drift stale against the current MWS format version since nothing re-checks it automatically |
| `layouts/` | hand-authored | Layout-chrome files (`layouts/{layout_id}.mws.yaml`) rendered around passages/popups sharing that `layout` value — see `docs/mws-format-latest.md` §8 in the code repo |
| `variables/` | hand-authored | Zero or more `.yaml` files declaring session variables the module needs that aren't discovered by extraction (e.g. bookkeeping variables for hand-authored passages) — same `variables:` schema as `_variables.yaml`, loaded after it with the same add/override-by-key semantics as `passages-override/`. See `docs/mws-format-latest.md` §9 in the code repo |
| `assets/` | hand-authored | `style.css` plus `audio/`, `fonts/`, `icons/`, `images/` — the app only emits structural `layout-{value}`/`style-{value}` CSS class hooks, everything they actually look like lives here |
| `_variables.yaml` | extractor-owned | All session variables discovered during extraction, with inferred types/defaults |
| `en-US.restext` | extractor-owned | Extracted locale strings (`Key=Value`). `Common_NNN` keys can renumber between runs — see `.source/en-US.common.restext` |
| `.source/*.cs` | extraction input | The canonical Cradle complete-class C# source this module is extracted from — from RGS's community-resources release, see Licensing above and `NOTICE.md` |
| `.source/en-US.common.restext` | hand-maintained | Curated `Key=Value` file giving *stable* names to strings that would otherwise get an auto-renumbered `Common_NNN` id (fed to `--common-restext`). Any override passage referencing a Common string should use one of these curated names. Lives in `.source/` because, like the Cradle source itself, it's an extraction *input*, not output — but unlike the `.cs` file it's hand-maintained, original content |

Extraction only ever writes `passages/`, `_variables.yaml`, and `en-US.restext` — everything else in
a module directory is hand-maintained and safe from being overwritten by a re-run.

---

## Extraction

Run from `c:\Projects\Masterwork` (the code repo) after building the extractor. `$base` points at
this module's own `.source/` copy, not at `Masterwork-Design` — `Reference/ScriptsComplete/` and
`Reference/ScriptsPartial/` there are historical only now that canonical module building happens
here:

```powershell
$base        = "c:\Projects\Masterwork-Modules\cost-of-disease\.source"
$spritemap   = "c:\Projects\Masterwork-Design\Reference\UnityOriginalApp\Assets\Resources\TheCostOfDisease_ItemObtain.json"
$progressmap = "c:\Projects\Masterwork-Modules\progress-map.json"
$modules     = "c:\Projects\Masterwork-Modules"

# The Cost of Disease — passages go into the module's passages/ subfolder; _variables.yaml and
# en-US.restext go into the module root, next to manifest.yaml and passages-override/.
# --common-restext gives stable IDs to Common strings (cost-of-disease/.source/en-US.common.restext);
# --progress-map gives hub_early/hub_middle/hub_late layout overrides + end_of_round popups at the
# reference app's real progress-bar checkpoints (progress-map.json, see below).
dotnet run --project src/Masterwork.Extractor -- `
  "$base\TheCostofDisease_Eng_v10.cs" `
  "$modules\cost-of-disease\passages" `
  --variables-out "$modules\cost-of-disease" `
  --restext-out "$modules\cost-of-disease" `
  --module-title "The Cost of Disease" `
  --sprite-map $spritemap `
  --common-restext "$base\en-US.common.restext" `
  --progress-map $progressmap
```

`$base\TheCostofDisease_Eng_v10.cs` being inside `cost-of-disease/.source/` (not `passages-out-dir`)
is also why the "# {path}:{line}" source comments each passage carries resolve to
`../.source/TheCostofDisease_Eng_v10.cs` — a path valid within this repo, unlike a comment pointing
back into `Masterwork-Design`.

Fear of the Unknown and A Time of War haven't been modularized into this repo yet — their extraction
still outputs flat into `Masterwork-Design\Reference\ScriptsComplete\{fear-of-the-unknown,
a-time-of-war}\`, reading from `Reference/ScriptsComplete/` there since no `Masterwork-Modules/`
copy of their source exists yet (see `Masterwork-Design/CLAUDE.md`). When they do get modularized,
copy their source into a `.source/` folder here first, following the same shape as Cost of
Disease's above.

See `docs/extractor.md` (code repo) for the full CLI flag reference, and
`docs/mws-format-latest.md` for the format spec.

### `progress-map.json`

Shared at the repo root (not nested under a single module) since it's keyed by passage name and
could in principle cover more than one module — currently only Cost of Disease uses it. Derived
from `Masterwork-Design/Reference/UnityOriginalApp/Assets/Scenes/Main.unity`'s `PassageTracker`
MonoBehaviour. Drives two things per hub passage:

- **`layout`** — overrides tag-based layout inference with `hub_early`/`hub_middle`/`hub_late`.
- **`progress`** (1-9) plus **`end_of_round_body`/`end_of_round_body2`** — at the matching
  `PassageTracker.instance.CheckProgress(...)` call site, the extractor synthesizes a
  `layout: end_of_round` acknowledgement popup (matching the reference app's `ViewEndOfRound`)
  whose `onclose` sets a `_ProgressRound` session variable; a module's `layouts/hub_early.mws.yaml`
  etc. turns that into the visible progress indicator.

See the file's own `_comment` field and `docs/mws-format-latest.md` §8's timing note (code repo)
for the full mechanism. If this file goes missing, re-extraction still succeeds (`--progress-map`
is optional) but every hub passage falls back to the generic `hub` layout with no progress
popup/variable — the extractor logs a warning for every `CheckProgress` call site left unmatched.

### Module overrides

Hand-authored passages are never accepted by the extractor at extraction time — they live in each
module's own `passages-override/` folder instead, applied at **module load time** (see the Module
Layout table above). Keep overrides in **current MWS format** (matching `mws-format-latest.md` in
the code repo); when the format advances, update overrides before the next module load. See
`docs/extractor.md` § Module Overrides (code repo) for the full mechanism.

---

## Bundling (`.mwm` packages)

`Masterwork.ModuleFormat.ModulePackage` (code repo) reads/writes a module directory as a `.mwm` zip
— `ModulePackage.WriteToBytes(moduleDir)` bundles a module folder's `passages/`,
`passages-override/`, `layouts/`, `variables/`, `assets/`, `manifest.yaml`, `_variables.yaml`, and
`{locale}.restext` files directly into the archive (explicitly excluding `.source/` and a root
`README.md`, neither of which belongs in a distributable bundle); `ModulePackage.ReadFromBytes(bytes)`
is the inverse, returning a `ModulePackageContents` record the app loads via
`ModuleLoader.LoadFromSources`. Bundling is a pure repackaging step — it doesn't re-run extraction
or validate content, so re-bundle after every content change you want reflected in the `.mwm`.

`cost-of-disease.mwm` at the repo root is the packaged build of `cost-of-disease/` — treat it as a
build artifact (safe to regenerate any time from the folder), not a hand-maintained file.

---

## Documentation Cross-Reference

- `c:\Projects\Masterwork\docs\mws-format-latest.md` — current authoritative MWS format spec
- `c:\Projects\Masterwork\docs\extractor.md` — extractor usage guide, including the full
  `--progress-map`/`--sprite-map`/`--common-restext` flag reference
- `Masterwork-Design/CLAUDE.md` — source file provenance, design doc versioning, licensing for
  `Reference/`
