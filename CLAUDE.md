# Grow A Reef

Cosy Roblox reef simulator: plant coral fragments in sockets on your plot, they grow in real time (timestamp-based), claim Shells, buy fragments and unlock sockets. Low-poly cartoon underwater style.

## Toolchain
- Rokit-managed: Rojo 7.7, Wally, StyLua, Selene (`rokit.toml`). ProfileStore via Wally → `ServerPackages/` (git-ignored, run `wally install`).
- `rojo serve default.project.json` syncs into Studio. **Changing `default.project.json` structure (new mapped paths) needs a Rojo restart, and the user must click Connect in the Studio plugin.** Edits to existing synced folders don't.
- Lint with `selene src tests tools` before every playtest (catches Luau syntax errors early). Don't run StyLua over the whole repo: older files use 4-space indents, newer ones use tabs.

## Layout (Rojo mappings)
| Path | Studio location |
| --- | --- |
| `src/shared` | `ReplicatedStorage.Shared`: Types, Config (Coral/Socket/Growth/Economy defs), Logic (pure GrowthMath, EconomyMath), Net/Remotes, Util |
| `src/server` | `ServerScriptService.Server`: `init.server.luau` bootstrap, Services, Util (DevTools, TransactionLog, Validate, RateLimiter), Migrations |
| `src/client` | `StarterPlayerScripts.Client`: controllers (State, HUD, Placement, ReefVisual, PlantTray, Shop, Ambient), Net/ClientNet, UI (Theme, UIKit, CoralIcon), Util/PlotLocator |
| `tests/` | `ServerStorage.Tests`: `*.spec.luau`, TestRunner, Expect, EconomySim |
| `tools/worldgen/` | `ServerStorage.WorldGen`: world/coral builder scripts + `Meshgen/` (EditableMesh procedural meshes) |

Studio-only content (plots, world, coral meshes) is documented in `assets/manifest.md`.

## Architecture rules
- Server init order lives in `init.server.luau`: Data → PlayerState → Inventory → Placement → Growth → Shop → Plot → Net. `CharacterAutoLoads = false`; PlotService spawns characters.
- Services return `Result` (`Result.result` / `Result.error`, not Ok/Err). Validate everything first, then mutate with no yields in between.
- Only InventoryService changes currencies/inventory (logged to TransactionLog). Only PlacementService changes unlocks/placements.
- Server writes facts as socket attributes (`Unlocked`, `CoralId`, `PlantedAt`, `ReadyAt`); clients derive models and timers. No Heartbeat for growth.
- All remotes go through `NetService.Bind` (arg check, rate limit, loaded check, pcall).
- UI is built in code (no StarterGui instances). Plots are `PersistentPerPlayer` for streaming.
- Corals: `ReplicatedStorage/Assets/Corals/<modelName>/{Bud,Young,Mature}`, each a Model with an invisible `Root` PrimaryPart at the base centre. They are **AI-generated meshes** (published assets). The old Part versions are in `ServerStorage/CoralPartsBackup`; `BuildCorals.luau` only writes there.

## Testing in Studio (via MCP)
- `execute_luau` runs in its own VM: `require` gives fresh module copies and `_G` isn't shared. To reach live game state, use the Studio-only bridge: `game.ServerStorage._DevBridge:Invoke("FnName", ...)`. `"Call"` invokes any service method, e.g. `Invoke("Call", "GrowthService", "Plant", player, "sandy_patch", "sun_coral")`. Functions can't be passed across VMs.
- DevTools: GrantShells, SetShells, GrantFragment, UnlockAllSockets, FinishGrowth, ResetData, GetStateJSON, PrintTransactions, SetSimulateFailure.
- Unit tests: `require(game.ServerStorage.Tests.TestRunner).RunAll()` (Edit mode). Long Edit sessions cache config modules; if results look stale, clone the modules first.
- Files created after a playtest starts aren't in that session. Stop and restart the playtest.
- Trigger prompts with `ProximityPrompt:InputHoldBegin()/End()` from the client; click UI with `user_mouse_input` and `instance_path`.

## Safety and workflow
- **Never write unbounded loops in Studio scripts.** One once froze Studio. Use fixed iteration counts and pcall.
- **Screenshots: only take them when the user asks.** Verify with code (attributes, counts, console output) instead.
- **Context budget:** auto-compact is set to a **200k-token** window for Opus 5.5 (`/autocompact`; the model default is 1M). That's a user-level Claude Code setting, so re-run `/autocompact` on a new machine. Keep sessions lean: avoid dumping large files or console logs, read only the lines you need, and suggest `/clear` between unrelated tasks.
- AI `generate_mesh`: run jobs **one at a time**, since parallel jobs hit "Too Many Requests". Ask for "fully three-dimensional, round from every side" to avoid flat results.
- Backups: `python3 tools/backup/receiver.py` (port 34900) + the Backup.luau snippet saves `studio_backup/<Service>.rbxm`. Back up before big Studio changes. Remind the user to save/publish the place, since Studio-only content isn't in git.
- Git: branch per milestone, one commit per ticket with the `[KAN-xx]` prefix. Never push or open PRs unless asked.
- Jira (growareef.atlassian.net, project KAN, cloudId `123f81cd-37a3-4ec4-b6e4-6dd812f3de74`): move each ticket to Done (transitionId 41) as soon as it's verified.

## Current state (2026-10-03)
- M0–M4 MVP slice done on stacked branches `feature/M0-Bootstrap` → `feature/M1-Persistence` → `feature/M2-Plots` → `feature/M3-CoreLoop` → `feature/M4-Economy` → `feature/MeshCompare` (AI coral meshes). Nothing pushed.
- Open tickets: KAN-26 (M1 gate: two-server session-lock test + merge/tag), KAN-33 (M2 gate: multi-player/overflow test), KAN-52 (tuned economy values need both devs' review), KAN-53 (M4 gate: 390×844 phone emulator check).
- Economy tuned by EconomySim to 20.2 min for all six sockets (Sun 120s/12, sockets 10/40/50/90/110).
- To do manually: set Max Players to 6 in Game Settings.
- The Glow trait (M6-04) can't use `CoralTip` tags now that each coral is a single mesh, so it needs another approach.
