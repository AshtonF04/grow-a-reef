# Handoff

Read this instead of the old chat. The code on disk is the source of truth. This file only keeps decisions and playtest notes that are easy to lose.

Branch: `grok-dev`. Progress is memory-only. Leaving the server wipes it.

## What the game is

A personal reef garden. The player unlocks planting spots (sockets), plants coral fragments, waits, and harvests shells. Each socket has light (`Bright` or `Dim`) and flow (`Low`, `Medium`, or `High`). Coral wants a matching pair. Sun Coral wants Bright / Medium, which is Sandy Patch.

## Rules already agreed

- Sandy Patch starts unlocked. Its cost is 0.
- Planting spends one fragment.
- Harvest pays `baseYield` shells (18 for Sun Coral) and returns one fragment of that coral.
- Sockets unlock in `unlockOrder`. The server checks this. The client cannot edit shells.
- Light and flow are shown in the guide. Harvest payout does not change for a mismatch yet.
- Pearls, traits, zones, and saving (DataStores) are not implemented.
- Authored grow time stays on the coral (Sun Coral is 300 seconds). `DevGrowSeconds` in `src/shared/Config/GameConfig.luau` overrides every species. It is `20` right now. Set it to `nil` for real timers.

## How a session runs

Rojo syncs files into Studio. The reef itself is created when the server starts. After a script change, stop Play and press Play again.

Server log on success: `[reef] ready. Sun Coral matures in 0:20 here.`

Play loop: plant Sun Coral on the glowing Sandy Patch (guide button, or walk up and press E), wait, harvest, then open the next socket with shells. One fragment means only one spot can hold coral at a time.

## Where the code lives

- `src/shared/ReefRules.luau` — unlock, plant, harvest, timers, guide text. Both sides use this.
- `src/shared/Config/` — coral, sockets, layout, `GameConfig`.
- `src/server/init.server.luau` — remotes and player join. Remotes: `state_changed`, `action_notice`, `request_state`, `unlock_socket`, `plant_coral`, `harvest_coral`.
- `src/server/PlayerStateService.luau` — wallet and placements. `plantedAt` is `workspace:GetServerTimeNow()`.
- `src/server/WorldService.luau` — lighting, water, fish, bubbles, sign, spawn. Built once at startup.
- `src/server/PlotService.luau` — per-player shoal and socket pads.
- `src/client/HUDService.luau` — the right-hand guide. Built in code. There is no Studio GUI.
- `src/client/ReefVisuals.luau` — coral, billboards, prompts. Client-only, so a server camera will not show the coral.
- `src/client/WorldAmbience.luau` — kelp sway, currents, bubbles, fish, caustic flicker.
- `default.project.json` — Rojo map. Lighting is also pushed again by `WorldService` at runtime.

Toolchain: Rojo 7.7.0 is installed (Aftman). Rokit, StyLua, and Selene are listed in `rokit.toml` but were not on PATH. Do not start a second `rojo serve` if Studio is already connected.

## Playtest (first Play, client view)

The loop ran. Output showed the ready line and the player join. The guide showed shells, a growing Sandy Patch, “Sun Coral thrives here,” and a countdown. Sun Ledge’s card showed a flow mismatch and no fragment, which is correct while the only fragment is planted.

Seen, not fixed yet:

- Sun Ledge’s pad floats above the sand.
- World labels overlap (Sun Ledge, Kelp Shade, the Sandy Patch marker).
- Growing coral reads as a small polyp cluster. Fine at low scale, easy to miss on the sand.
- Kelp reads as thin sticks. Fish, bubbles, and the water line are doing their job.
- Placeholder blocks, not a modeled reef. That was intentional for this pass.

## Do not do next without asking

- Do not add DataStores, pearls, traits, or a mismatch payout unless the vision doc says to.
- Do not hand-build a ScreenGui in Studio. The guide is code.
- The owner has a PDF vision for the whole game. In the next chat, read that PDF before changing design. Fit new work to it. Do not invent a second game.
