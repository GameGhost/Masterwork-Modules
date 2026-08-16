# Source provenance

Each module's `.source/` folder holds the canonical Cradle script source(s) it's extracted from
(`en-US.common.restext` alongside it is hand-maintained, not part of this).

These `.cs` files — currently `cost-of-disease/.source/TheCostofDisease_Eng_v10.cs` — come from
Renegade Game Studios' own community-resources release for *My Father's Work*, the same release
and the same archive/link that `Masterwork` (the code repo)'s
`src/Masterwork.App.Theme.MyFathersWork/NOTICE.md` documents for the app's visual theme assets:

<https://renegadegamestudios.com/blog/my-fathers-work-app-update-community-resources/>

Per that release, individual files may be copied and modified as needed. This repo keeps each
module's own copy of just the script(s) it's extracted from, not the full archive.

Everything else in a module directory — extracted/hand-authored passages, layout chrome,
overrides, module-specific assets, manifests, and the packaged `.mwm` bundles — is this project's
own original content, not derived from the RGS release above. `.mwm` bundles never include
`.source/` (see `ModulePackage.WriteToBytes` in the code repo), so a packaged module never
redistributes the Cradle script itself, only Masterwork's own MWS conversion of it.

## Audio assets

Real audio (Phase 4 Milestone C pilot content) comes from the same Renegade Game Studios
community-resources release as the Cradle source above, not a separate source:

<https://renegadegamestudios.com/blog/my-fathers-work-app-update-community-resources/>

Split the same way the "split ownership" convention already documented in each module's own
`README.md` splits every other asset type: `assets/audio/sfx/` is template-canonical (present
identically in `my-fathers-work-template/assets/audio/sfx/` and copied verbatim into all three
official modules — including four pre-existing files this milestone didn't touch); `assets/audio/bgm/`
and `assets/audio/vo/` are `cost-of-disease`-specific, the only module with any real `audio:` content
wired up so far.

| File | Original release file |
|---|---|
| `my-fathers-work-template/assets/audio/sfx/click.ogg` (+ verbatim copy in all 3 modules) | `Assets/New SFX/click-to-continue.ogg` |
| `.../sfx/popup_open.ogg` (+ verbatim copy in all 3 modules) | `Assets/New SFX/Fathers work SFX pt 2/Set up-window appear.ogg` |
| `.../sfx/popup_close.ogg` (+ verbatim copy in all 3 modules) | `Assets/New SFX/Fathers work SFX pt 2/End of round.ogg` |
| `.../sfx/reveal.ogg` (+ verbatim copy in all 3 modules) | `Assets/New SFX/Fathers work SFX pt 2/Reveal.ogg` (the `reveal` layout is shared template chrome, used across all three scenarios — not cost-of-disease-specific, hence template-level rather than module-local) |
| `cost-of-disease/assets/audio/bgm/cost_of_disease_theme.ogg` | `Assets/SFX/New_8_April/My Fathers Work-OST/Cost of disease theme loop-louder.ogg` |
| `cost-of-disease/assets/audio/vo/hospitalintro_m.ogg` | `Assets/SFX/Male VO oggs/HospitalIntro.ogg` |
| `cost-of-disease/assets/audio/vo/hospitalintro_f.ogg` | `Assets/SFX/female Takes VO oggs/Hospitalintro.ogg` |

`vo/hospitalintro_m.fr-CA.ogg` is **not** a real French recording — it's a byte-identical copy of
`hospitalintro_m.ogg`, added solely to exercise the format's `<slug>[.<culture>].<ext>` culture-suffix
probe mechanism (docs/mws-format-latest.md §6.1 in the code repo) against a real file pair, since no
non-English voiceover exists anywhere in the source material (confirmed against the full 99-file
inventory — see the Masterwork-Design design workspace's own `audio-inventory.md` §6). Treat it as a
placeholder for a genuine future localization, not a real one.

Source file paths above are relative to the community-resources release's Unity project root
(`Assets/`). See `docs/mws-format-latest.md` §6 in the code repo for the `audio://` URI scheme these
files are addressed by (`bgm`/`sfx`/`vo` are folder-naming conventions, not enforced categories).
