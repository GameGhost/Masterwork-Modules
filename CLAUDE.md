# Masterwork-Modules — Claude Instructions

## This Repository

Holds extracted, playable MWS modules for the Masterwork project — the *build output* of the
extraction pipeline, plus everything hand-authored on top of it (overrides, layout chrome,
per-module assets, packaged `.mwm` bundles). **Not the code repo.**

- Code repo: `<Masterwork>` (a sibling of this repo, checked out alongside it) — the extractor, engine, and app that read/write this repo's content.
- Extraction also reads sprite/progress data from the original Unity project's reference assets
  (a private local reference workspace, not tracked in any public repo — see `docs/extractor.md`'s
  `--sprite-map`/`--progress-map` options in the code repo). Every scenario now holds its own copy
  of the Cradle C# source it's extracted from directly in this repo (`.source/`, see Extraction
  below), so extraction no longer needs to reach outside this repo for source content at all —
  only for the Unity sprite/progress data above.

This repo used to be part of that private local reference workspace; it moved into its own git repo
once module content needed real version control independent of local design/reference material.
Canonical module building now happens entirely within this repo, including holding each module's
own copy of the Cradle source it's extracted from (`.source/`, see Module Layout below).

**All four modules are here and fully modularized** — the three official scenarios (each with its
own `.source/` Cradle copy) plus `my-fathers-work-template` (fully hand-authored, no `.source/` at
all). Layout at the repo root:

```
Masterwork-Modules/
├── progress-map.json             — shared --progress-map input (see below), used by all three official scenarios
├── a-time-of-war/                 ─┐
├── cost-of-disease/                │ one folder per module
├── fear-of-the-unknown/            │
├── my-fathers-work-template/      ─┘ (hand-authored, no extraction step)
├── mwf-common-assets/             — shared asset pack (.mwassets), depended on by all four modules above
├── a-time-of-war.mwm              ─┐
├── cost-of-disease.mwm             │ packaged bundles (build artifacts, gitignored — built from
├── fear-of-the-unknown.mwm         │ each module/ or asset-pack dir, see Bundling below)
├── my-fathers-work-template.mwm   ─┘
└── mwf-common-assets.mwassets
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
may be copied and modified as needed. Still: **never commit `.source/*.cs` (or any other CC BY-NC-SA
reference material, beyond that specific release) to the `Masterwork` code repo** — that repo's own
licensing rule is narrower and doesn't carry this exception.

---

## Module Layout

Each module directory (e.g. `cost-of-disease/`) follows the same shape:

| Path | Owner | Purpose |
|---|---|---|
| `manifest.yaml` | hand-maintained | Module id/title/description, thumbnail, player count/playtime, entry passage, `passages`/`passages_override` path overrides, `style` stylesheet reference |
| `passages/` | extractor-owned | One `{NNN}-{PassageId}.mws.yaml` per passage — overwritten wholesale on every re-extraction. Never hand-edit files here |
| `passages-override/` | hand-maintained | `.mws.yaml` files applied after `passages/` at module load time (`ModuleLoader.LoadFromDirectory`) — a matching `passage_id` replaces the extracted version, a new one is simply added. Never touched by extraction, so it survives re-extraction, but can drift stale against the current MWS format version since nothing re-checks it automatically |
| `layouts/` | hand-authored | Layout-chrome files (`layouts/{layout_id}.mws.yaml`) rendered around passages/popups sharing that `layout` value — see `docs/mws-format-latest.md` §8 in the code repo. Normally **absent entirely** — every shared layout (`choice`, `note`, `prompt`, `ranking`, the score/setup popups, `narration`/`introduction`/`hub_early`/`hub_middle`/`hub_late` with roundNum already derived from `_ProgressRound`, ...) lives in `mwf-common-assets/layouts/` instead, reached via this module's own `dependencies:` entry. A file only appears here if this module's own `--progress-map` extraction assigns a *different* progress variable name than the shared default (see `scripts/apply-template.ps1 -ProgressVariable`) — none of the three official scenarios currently need this |
| `variables/` | hand-authored | Zero or more `.yaml` files declaring session variables the module needs that aren't discovered by extraction (e.g. bookkeeping variables for hand-authored passages) — same `variables:` schema as `_variables.yaml`, loaded after it with the same add/override-by-key semantics as `passages-override/`. See `docs/mws-format-latest.md` §9 in the code repo |
| `assets/` | hand-authored | This module's own scenario-specific content only — VO audio (`audio/vo/`), module-specific icons/images, `images/setup/`. `style.css`, `fonts/`, shared icons/images, and `audio/sfx`/`audio/bgm` all moved to `mwf-common-assets/assets/` — the app only emits structural `layout-{value}`/`style-{value}` CSS class hooks, everything they actually look like lives in whichever of these two places actually has the file |
| `_variables.yaml` | extractor-owned | All session variables discovered during extraction, with inferred types/defaults |
| `en-US.restext` | extractor-owned | Extracted locale strings (`Key=Value`). `Common_NNN` keys can renumber between runs — see `.source/en-US.common.restext` |
| `.source/*.cs` | extraction input | The canonical Cradle complete-class C# source this module is extracted from — from RGS's community-resources release, see Licensing above and `NOTICE.md` |
| `.source/en-US.common.restext` | hand-maintained | Curated `Key=Value` file giving *stable* names to strings that would otherwise get an auto-renumbered `Common_NNN` id (fed to `--common-restext`). Any override passage referencing a Common string should use one of these curated names. Lives in `.source/` because, like the Cradle source itself, it's an extraction *input*, not output — but unlike the `.cs` file it's hand-maintained, original content |

Extraction only ever writes `passages/`, `_variables.yaml`, and `en-US.restext` — everything else in
a module directory is hand-maintained and safe from being overwritten by a re-run.

---

## Extraction

Run from `<Masterwork>` (the code repo, a sibling of this one) after building the extractor. `$base`
points at this module's own `.source/` copy — canonical module building happens entirely within this
repo now. `<Masterwork-Modules>` below is the path to this repo's own local clone:

```powershell
$base        = "<Masterwork-Modules>/cost-of-disease/.source"
$spritemap   = "<path to a local copy of the Unity project's Assets/Resources/TheCostOfDisease_ItemObtain.json>"
$progressmap = "<Masterwork-Modules>/progress-map.json"
$audiomap    = "<Masterwork-Modules>/audio-map.json"
$modules     = "<Masterwork-Modules>"

# The Cost of Disease — passages go into the module's passages/ subfolder; _variables.yaml and
# en-US.restext go into the module root, next to manifest.yaml and passages-override/.
# --common-restext gives stable IDs to Common strings (cost-of-disease/.source/en-US.common.restext);
# --progress-map gives hub_early/hub_middle/hub_late layout overrides + end_of_round popups at the
# reference app's real progress-bar checkpoints (progress-map.json, see below); --audio-map
# synthesizes gendered audio_track VO narration nodes at this scenario's own intro passages
# (audio-map.json, shared by all three official scenarios — see its own header comment).
dotnet run --project src/Masterwork.Extractor -- `
  "$base\TheCostofDisease_Eng_v10.cs" `
  "$modules\cost-of-disease\passages" `
  --variables-out "$modules\cost-of-disease" `
  --restext-out "$modules\cost-of-disease" `
  --module-title "The Cost of Disease" `
  --sprite-map $spritemap `
  --common-restext "$base\en-US.common.restext" `
  --progress-map $progressmap `
  --audio-map $audiomap
```

`$base\TheCostofDisease_Eng_v10.cs` being inside `cost-of-disease/.source/` (not `passages-out-dir`)
is also why the "# {path}:{line}" source comments each passage carries resolve to
`../.source/TheCostofDisease_Eng_v10.cs` — a path valid within this repo, unlike a comment pointing
back to an external reference location.

Fear of the Unknown and A Time of War are fully modularized here too, following the identical
pattern (`{module}/.source/`, `--variables-out`/`--restext-out` pointed at the module root,
`{module}/passages` as the passages-out-dir) — see `docs/extractor.md` (code repo) for all three
scenarios' exact current commands side by side. Fear of the Unknown doesn't need `--sprite-map` (Cost
of Disease-only); A Time of War needs `--module-title` for the same auto-capitalization reason Cost
of Disease does.

See `docs/extractor.md` (code repo) for the full CLI flag reference, and
`docs/mws-format-latest.md` for the format spec.

### `progress-map.json`

Shared at the repo root (not nested under a single module) since it's keyed by passage name and
covers more than one module — all three official scenarios' hub passages are in it today, not just
Cost of Disease. Derived from the original Unity project's `Main.unity` scene's `PassageTracker`
MonoBehaviour (see `Masterwork.App.Theme.MyFathersWork/NOTICE.md` in the code repo for asset
provenance). Drives two things per hub passage:

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

## Bundling (`.mwm`/`.mwassets` packages)

`Masterwork.ModulePacker` (code repo) is the CLI that does the actual zipping, in three modes —
`scripts/repack.ps1` (`-Mode module|asset|standalone`, see its own `Get-Help` for the full
parameter/example reference) is the normal way to invoke it from this repo:

- **module** (default) — `ModulePackage.WriteToBytes(moduleDir)` bundles a module folder's
  `passages/`, `passages-override/`, `layouts/`, `variables/`, `assets/`, `manifest.yaml`,
  `_variables.yaml`, and `{locale}.restext` files into a `.mwm` (excluding `.source/` and a root
  `README.md`, neither of which belongs in a distributable bundle). `dependencies:` is left exactly
  as declared — this is what a real release ships. `ModulePackage.ReadFromBytes(bytes)` is the
  inverse, returning a `ModulePackageContents` record the app loads via `ModuleLoader.LoadFromSources`.
- **asset** — `AssetPackPackage.WriteToBytes(sourceDir)` bundles an asset-pack directory (no
  passages/passage-overrides, so its shape is narrower: `manifest.yaml`, an optional
  `_variables.yaml`, root-level `{locale}.restext` files, and `layouts/`/`assets/`) into a
  `.mwassets`.
- **standalone** — `ModulePackage.WriteStandaloneToBytes(moduleDir, assetPackDirs)` packs a module
  the same way **module** does, but also merges every listed asset pack's own `layouts/`/`assets/`/
  `_variables.yaml`/`{locale}.restext` directly into the same `.mwm` (a module-owned file wins on an
  exact path collision) and blanks `dependencies:` to `[]` in the packaged manifest. Loads correctly
  with nothing else installed — use it for manual-install testing, not for a real release artifact.
  `repack.ps1` resolves each module's declared dependency ids against this repo's own asset-pack
  directories automatically; it errors if a dependency's source isn't here to merge in.

### Signing

Packages are unsigned by default. Pass `-SignWith <path-to.pfx>` (password via `-SignPassword`, or
the `MASTERWORK_SIGNING_PASSWORD` environment variable) and every bundle that run produces is signed
in place afterwards, via the packer's own `sign` mode. An unsigned bundle still installs — the app
shows a one-time "unsigned content" prompt — so ordinary dev repacks need no key and nothing extra;
sign anything actually being distributed. `ModulePacker verify <package-file>` reports a bundle's
signature state (`Unsigned`/`Valid`/`Invalid`) and, when signed, the signer and thumbprint.

Every `.mwm`/`.mwassets` at the repo root — including any `{name}.standalone.mwm` — is a build
artifact (gitignored, safe to regenerate any time from its source directory), not a hand-maintained
file. All four modules (three official scenarios plus `my-fathers-work-template`) plus
`mwf-common-assets` ship this way; bundling never re-runs extraction or validates content, so
re-bundle after every content change you want reflected in the packaged file.

Each of the four modules declares `mwf-common-assets` as a `dependencies:` entry in its own
`manifest.yaml` (`id: 'renegade.mwf_common_assets'` + exact pinned `version`) and no longer keeps a
local copy of the content that moved there — a **module**-mode bundle only loads correctly once the
asset pack is installed too (or use **standalone** mode instead); until then `ModuleWarnings`'
`missing_dependency` note is the only symptom of it being absent, not a load failure.

---

## Documentation Cross-Reference

- `<Masterwork>/docs/mws-format-latest.md` — current authoritative MWS format spec
- `<Masterwork>/docs/engine.md` — session/timeline model, seeded randomness, popup sandbox transactions
- `<Masterwork>/docs/extractor.md` — extractor usage guide, including the full
  `--progress-map`/`--sprite-map`/`--common-restext` flag reference
