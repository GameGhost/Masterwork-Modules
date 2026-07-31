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
