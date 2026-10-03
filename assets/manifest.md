# Asset Manifest

Things the code depends on that live **only in the Studio place file** (not in git).
Any PR that adds or changes a Studio-only instance must update this table.

| Instance path | What it is | Owner | Status |
| --- | --- | --- | --- |
| `Workspace/PlayerPlots/Plot_N` | Plot models tagged `ReefPlot`. Each has a `Base` PrimaryPart, 6 Parts named exactly after the socket ids (`sandy_patch`, `sun_ledge`, `surge_channel`, `kelp_shade`, `rock_crevice`, `deep_nook`) tagged `ReefSocket`, and a `SpawnLocation` named `PlotSpawn`. | World | planned (M2) |
| `ReplicatedStorage/Assets/Corals/<modelName>/{Bud,Young,Mature}` | Coral models per growth stage. `<modelName>` matches `CoralDefinition.modelName`. Each Model has an invisible anchored `Root` PrimaryPart at the centre of its base; every part is non-collide/query/touch; tip parts tagged `CoralTip`. | World | planned (M3) |
| `StarterGui/HUD` | **Removed.** The HUD (and every other screen) is now built from code in `src/client/UI` + `src/client/Controllers` so it lives in git. | Sys | n/a (code-built) |
