# Masterwork Modules

Extracted and hand-authored MWS (Masterwork Script) modules for
[Masterwork](https://github.com/GameGhost/Masterwork), a community companion app for the boardgame
*My Father's Work* (Renegade Game Studios).

## What's here

| Path | What it is |
|---|---|
| `cost-of-disease/`, `fear-of-the-unknown/`, `a-time-of-war/` | The three official scenarios — converted from Renegade's own Cradle scripts into the MWS format. |
| `my-fathers-work-template/` | A design workbench, not a playable scenario — exercises every layout/popup shape the app supports, so new visual treatment can be built and screenshotted here before being copied into a real module. |
| `mwf-common-assets/` | A shared asset pack (`.mwassets`, id `renegade.mwf_common_assets`) — the style/fonts/icons/images/audio and layout chrome all four modules above have in common, split out of `my-fathers-work-template`. Each module declares it as a `dependencies:` entry in its own `manifest.yaml`. |
| `progress-map.json` | Shared hub-progress data (from the reference app's own `PassageTracker`) used by extraction — see `CLAUDE.md`. |
| `scripts/` | PowerShell helpers, e.g. `apply-template.ps1` for pulling the template's shared styling/chrome into a real module. |

Packaged `.mwm`/`.mwassets` bundles — the zip formats the app actually loads — are build artifacts
and aren't committed to this repo. Check this repo's [Releases](../../releases) for the latest
packaged builds, or build your own (below).

## Building a module

Requires the [Masterwork](https://github.com/GameGhost/Masterwork) code repo checked out alongside
this one (i.e. as a sibling directory, `../Masterwork`).

1. Extract a module's own passages from its Cradle source — see that module's own `README.md` (e.g.
   `cost-of-disease/README.md`) for its exact extraction command.
2. Bundle the module folder into a `.mwm`, and `mwf-common-assets/` into a `.mwassets` (a module
   depends on it — see `CLAUDE.md`'s Bundling section for the other packing modes, including a
   standalone bundle that needs no separate asset-pack install):

   ```powershell
   .\scripts\repack.ps1 -Module cost-of-disease
   .\scripts\repack.ps1 -Mode asset -Module mwf-common-assets
   ```

3. Load both `.mwm`/`.mwassets` files into the app — via its own module-upload flow (Start New
   Game), or by dropping them into the app's module folder directly.

## Module format

Each module is a folder of `.mws.yaml` passage files plus a manifest. See
[`docs/mws-format-latest.md`](https://github.com/GameGhost/Masterwork/blob/main/docs/mws-format-latest.md)
in the Masterwork repo for the full format spec.

## More detail

See `CLAUDE.md` at this repo's root for the full repo layout, extraction commands, module-override
mechanics, and `.mwm` bundling details.
