# Handoff

Read this instead of the old chat. The code on disk is the source of truth. This file only keeps decisions and playtest notes that are easy to lose.

Branch: `grok-dev`. The owner's vision doc is `Development & Design Document.pdf` (in the owner's Downloads, not in the repo). Fit new work to it. Do not invent a second game.

## What the game is

A personal reef garden. The player unlocks planting spots (sockets), plants coral fragments, waits, and harvests shells. Each socket has light (`Bright` or `Dim`) and flow (`Low`, `Medium`, or `High`). The six sockets cover all six light/flow pairs, and each of the six Sunlit Shelf corals flourishes on exactly one of them.

| Coral | Home socket | Grow | Base yield | Nursery cost |
| --- | --- | --- | --- | --- |
| Sun | Sandy Patch | 5:00 | 18 | 10 |
| Branch (fast pick) | Surge Channel | 2:00 | 9 | 15 |
| Brain (valuable pick) | Sun Ledge | 15:00 | 60 | 40 |
| Plate | Kelp Shade | 10:00 | 36 | 30 |
| Star | Rock Crevice | 20:00 | 80 | 60 |
| Bubble | Deep Nook | 30:00 | 120 | 90 |

All yields and costs are placeholders. The doc says economy values are a human decision.

## Rules already agreed

- Sandy Patch starts unlocked. Its cost is 0. The player starts with one Sun Coral fragment.
- Planting spends one fragment. Harvest pays shells and returns one fragment of that coral.
- Flourishing: if light and flow both match, harvest pays `baseYield × FlourishMultiplier` (1.5). Any mismatch pays plain `baseYield`. Conditions never punish (doc: "poor conditions slow bonuses; they never erase work").
- The Nursery (guide tab) sells fragments for shells. Max 20 per coral.
- Sockets unlock in `unlockOrder`. The server checks every action. The client cannot edit shells.
- Growth stages come from the timestamp: Fragment (<15%), Sprouting (<50%), Growing, Mature. The client pops the coral and bursts sparkles at each step.
- `DevTimeScale` in `GameConfig` multiplies every grow time. It is `1/15` right now (Sun Coral 0:20). Set it to `nil` for real timers.
- Pearls, traits, fish discovery, quests, and the collection book are not implemented yet.

## Saving

`src/server/SaveService.luau` stores one record per player in DataStore `ReefProfiles`, key `reef_<userId>`, schema `version = 1`.

- Load takes a session lock with `UpdateAsync`. If another server holds a fresh lock it retries, then takes the lock on the last try. A save refuses to write if another server took the lock.
- A failed load is never saved over. The player plays with a fresh reef and a warning toast, and that session is not saved.
- Saves happen every 60 seconds, on leave (which also releases the lock), and on shutdown via `BindToClose`.
- `PlayerStateService` cleans every loaded record. It drops unknown ids, clamps negatives and NaN, floors counts, caps fragments, and clamps a `plantedAt` that is in the future.
- Returning players get a welcome-back toast saying what grew while they were away.
- Studio: saving needs a published place and File > Game Settings > Security > Enable Studio Access to API Services. Without that, the server logs `[reef] saving is off: ...` and the game still runs.

## How a session runs

Rojo syncs files into Studio. The reef itself is created when the server starts. After a script change, stop Play and press Play again.

Server log on success: `[reef] ready. Sun Coral matures in 0:20 here.` then `[reef] <name> entered the reef (saving on|off)`.

## Where the code lives

- `src/shared/ReefRules.luau`: unlock, buy, plant, harvest checks, fit and yield, stages, best fragment, next step (returns text, kind, target socket). Both sides use this.
- `src/shared/Config/`: `CoralDefinitions`, `CoralLooks` (palettes), `SocketDefinitions`, `SocketLayout`, `GameConfig`.
- `src/server/init.server.luau`: remotes, load/save lifecycle, per-player throttle (0.2 seconds per action type). Remotes: `state_changed`, `action_notice`, `request_state`, `unlock_socket`, `plant_coral`, `harvest_coral`, `buy_fragment`.
- `src/server/SaveService.luau`: DataStore load, save, and lock.
- `src/server/PlayerStateService.luau`: state, record cleaning, and the actions.
- `src/server/WorldService.luau`, `PlotService.luau`: world and per-player plot, built at runtime.
- `src/client/HUDService.luau`: guide panel with Reef and Nursery tabs. The Nursery tab glows gold when the next step is to buy. Spot cards have a Swap button when you own more than one species.
- `src/client/PlantChoice.luau`: which fragment the player picked for each spot. Shared by the guide and the E prompt.
- `src/client/ReefVisuals.luau`: six coral builders (parts only), stage pops, harvest burst, flourish sparkles, guide glow on the next-step socket, and marker declutter (hides labels that overlap a nearer or more important one, or sit under the guide panel).
- `src/client/WorldAmbience.luau`: kelp sway, currents, bubbles, fish, caustic flicker.
- `tests/`: `./tests/run.ps1 -Luau path\to\luau.exe` bundles the shared rules and `PlayerStateService` and runs `reef.spec.luau` in the Luau CLI (62 checks, plus a bot that plays from a fresh reef to all six sockets planted).

Toolchain: Rojo 7.7.0 (Aftman). Type-check with `luau-lsp analyze --definitions=<globalTypes.None.d.luau> --sourcemap=<rojo sourcemap> --no-strict-dm-types src`. The only known warning is a `pcall(applyLighting)` false positive in `WorldService`. Do not start a second `rojo serve` if Studio is already connected.

## Economy measurement

The test bot fills all six sockets in about 45 minutes of real timers by following the guide's next step. The doc's target is 15–25 minutes for the first six sockets. It needs tuning (costs, yields, or Sun Coral's 5-minute timer). The doc's onboarding also wants the first reward inside two minutes.

## Not yet verified in Studio

This pass was written without a Studio playtest. It type-checks, builds with Rojo, and passes the rules tests. On the first Play, check these:

- Coral shapes and stage scale look right on each pad (`CORAL_SIZE`, `STAGE_SCALE` in `ReefVisuals`).
- Pads no longer float (Sun Ledge, Rock Crevice, and Surge Channel offsets set to 0).
- Marker declutter doesn't flicker badly while the camera moves.
- Save and rejoin on a published copy with API access on.

## Doc roadmap: what's next

Week 3 in the doc: two fish (habitat score threshold, clownfish first), one mutation or trait reveal, first-10-minutes onboarding, collection book skeleton, sound and particles, analytics events. After that, Week 4: Reef Keeper requests and an offline summary card.

## Do not do next without asking

- Do not add pearls, paid products, or trading. The doc delays them.
- Do not hand-build a ScreenGui in Studio. The guide is code.
