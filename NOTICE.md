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

Real audio comes from the same Renegade Game Studios community-resources release as the Cradle
source above, not a separate source:

<https://renegadegamestudios.com/blog/my-fathers-work-app-update-community-resources/>

Split the same way the "split ownership" convention already documented in each module's own
`README.md` splits every other asset type: `assets/audio/sfx/` and, as of Phase 5 Milestone 6.2,
`assets/audio/bgm/` are template-canonical (present identically in
`my-fathers-work-template/assets/audio/` and copied verbatim into all three official modules — a
module can still carry its own additional bgm files alongside these, they're just never deleted or
overwritten unless the filename collides); `assets/audio/vo/` stays module-own — narration is
inherently scenario-specific.

| File | Original release file |
|---|---|
| `my-fathers-work-template/assets/audio/sfx/click.ogg` (+ verbatim copy in all 3 modules) | `Assets/New SFX/click-to-continue.ogg` |
| `.../sfx/popup_open.ogg` (+ verbatim copy in all 3 modules) | `Assets/New SFX/Fathers work SFX pt 2/Set up-window appear.ogg` |
| `.../sfx/popup_close.ogg` (+ verbatim copy in all 3 modules) | `Assets/New SFX/Fathers work SFX pt 2/End of round.ogg` |
| `.../sfx/reveal.ogg` (+ verbatim copy in all 3 modules) | `Assets/New SFX/Fathers work SFX pt 2/Reveal.ogg` (the `reveal` layout is shared template chrome, used across all three scenarios — not module-specific, hence template-level rather than module-local) |
| `.../sfx/special_event.ogg` (+ verbatim copy in all 3 modules) | `Assets/New SFX/Fathers work SFX pt 2/Special Event-words appear.ogg` — matches `ViewSpecialEvent.clip` in the reference app, fired the instant its overlay appears. Synthesized as every special-event-marked passage's `audio.on_display` automatically by the extractor (`V2Serializer.HasSpecialEventMarker`, no `--audio-map`-style JSON needed); see `docs/extractor.md` § Special-Event On-Display SFX (code repo) |
| `my-fathers-work-template/assets/audio/bgm/setup_theme.ogg` (+ verbatim copy in all 3 modules) | `Assets/SFX/Fathers work Title theme.ogg` — same source file as the app theme's own `main-menu-theme.ogg` (`Masterwork/src/Masterwork.App.Theme.MyFathersWork/NOTICE.md`), copied separately here since module `audio://` resolution never reaches into the app theme project's own assets. Used as every onboarding (`Setup_0N`) passage's own `audio.music` override |
| `.../bgm/cost_of_disease_theme.ogg` (+ verbatim copy in all 3 modules) | `Assets/SFX/New_8_April/My Fathers Work-OST/Cost of disease theme loop-louder.ogg` |
| `.../bgm/chronicle_part_1.ogg` (+ verbatim copy in all 3 modules) | `Assets/SFX/New_8_April/My Fathers Work-OST/Chronicle Part one_1-2.ogg` |
| `.../bgm/chronicle_part_2.ogg` (+ verbatim copy in all 3 modules) | `Assets/SFX/New_8_April/My Fathers Work-OST/Chronicle Part Two_2-2.ogg` |
| `.../bgm/chronicle_part_3.ogg` (+ verbatim copy in all 3 modules) | `Assets/SFX/New_8_April/My Fathers Work-OST/Chronicle Part  Three.ogg` |

The four `bgm/` tracks above are each module's real `audio.music.default_tracks` (`order: 'sequence'`)
— identical across all three official modules, since none of them had a confirmed distinct
per-scenario theme of their own in the reference project's static `Main.unity` clip mapping. In the
original app these same four files played together as `ViewGenerationEnding`'s own end-of-generation
playlist; used here as each module's general default instead, not scoped to any one popup type.

**Voiceover (`assets/audio/vo/`), all three modules — Phase 5 Milestones 6/6.1.** Every module's VO
files are named `<slug>_m.ogg`/`<slug>_f.ogg` per `audio-map.json` (repo root) — that file is the
authoritative source→slug mapping (28 of `audio-inventory.md` §5's 28 real VO-covered passages are
mapped: 11 in *A Time of War*, 9 in *The Cost of Disease*, 8 in *Fear of the Unknown*), each male
file sourced from `Assets/SFX/Male VO oggs/<clip>.ogg` and each female file from
`Assets/SFX/female Takes VO oggs/<clip>.ogg` in the community-resources release.

*The Cost of Disease*'s `GloomyWolvesIntro` is a deliberate exception to the "both genders present"
rule: only `gloomywolvesintro_m.ogg` (the real male take) exists — `gloomywolvesintro_f` has **no**
backing file at all, on purpose. The original inventory's female-take mapping for this passage
resolved to a misnamed/mismatched file sitting in the *male*-take folder, not a genuine distinct
recording; rather than carrying that anomaly forward or guessing at a substitute, the map still
references the (non-existent) female slug so the gap is real and diagnosable — `AssetResolver` logs
a warning and resolves `null`, and `RenderedAudioTrackView` degrades to disabled controls with a
0:00/0:00 readout (`docs/mws-format-latest.md` §6 in the code repo) rather than a missing/broken
element. A genuine female take, if the community ever sources one, just needs to be dropped in at
that same filename — no other change required.

`cost-of-disease/assets/audio/vo/hospitalintro_m.fr-CA.ogg` is **not** a real French recording —
it's a byte-identical copy of `hospitalintro_m.ogg`, added solely to exercise the format's
`<slug>[.<culture>].<ext>` culture-suffix probe mechanism (docs/mws-format-latest.md §6.1 in the
code repo) against a real file pair, since no non-English voiceover exists anywhere in the source
material (confirmed against the full 99-file inventory — see `audio-inventory.md` §6). Treat it as
a placeholder for a genuine future localization, not a real one.

**No confirmed per-scenario theme music for *A Time of War* or *Fear of the Unknown*** — unlike
*The Cost of Disease*'s own `cost_of_disease_theme.ogg`, the reference project's static
`Main.unity` clip mapping (`audio-inventory.md` §3/§4) didn't resolve a distinct theme track for
either of the other two scenarios, so their manifests currently have no `audio.music.default_tracks`
entry rather than a guessed one.

Source file paths above are relative to the community-resources release's Unity project root
(`Assets/`). See `docs/mws-format-latest.md` §6 in the code repo for the `audio://` URI scheme these
files are addressed by (`bgm`/`sfx`/`vo` are folder-naming conventions, not enforced categories).
