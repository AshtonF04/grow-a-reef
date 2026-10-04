# Grow A Reef

A cosy Roblox reef-building simulator: plant coral fragments in sockets on your reef plot, let them grow in real time, claim Shells, and expand your reef.

## Setup

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in the repo root (installs Rojo, Wally, StyLua, Selene at the pinned versions).
2. Run `wally install` (installs ProfileStore into `ServerPackages/`).
3. Run `rojo serve`.
4. Open the place in Roblox Studio and press **Connect** in the Rojo plugin.
5. Game Settings → Security → "Enable Studio Access to API Services" must be on so saving works in Studio (Studio uses the separate `PlayerData_Studio` store).

Code in `src/` syncs into Studio. Things that only exist in the place file (plots, models) are listed in [`assets/manifest.md`](assets/manifest.md).

## Project layout

| Path | Syncs to | Contents |
| --- | --- | --- |
| `src/shared` | `ReplicatedStorage.Shared` | Types, configs, pure logic, remotes, utilities |
| `src/server` | `ServerScriptService.Server` | Server bootstrap and services |
| `src/client` | `StarterPlayerScripts.Client` | Client bootstrap, controllers and code-built UI |

## Branch naming

`feature/<Name>`, one branch per feature.

## PR rules

- Keep PRs under about 400 changed lines.
- One teammate reviews before merge.

## Definition of done

- Runs on phone and desktop.
- No new errors or warnings in Output.
- Save-data migration considered.
- Analytics event added (once analytics exists).
- Another teammate reviewed it.

## Studio-only changes

Any change that only exists in the place file (models, plots, tags) must update [`assets/manifest.md`](assets/manifest.md) in the same PR.

## Dev commands (Studio only)

During a playtest, run these in the **server** command bar. Passing `nil` as the player means "the first player".

```lua
_G.Dev.GrantShells(nil, 100)
_G.Dev.SetShells(nil, 0)
_G.Dev.GrantFragment(nil, "sun_coral", 3)
_G.Dev.UnlockAllSockets(nil)
_G.Dev.ResetData(nil)          -- fresh account (+ starter fragment)
_G.Dev.PrintState(nil)
_G.Dev.PrintTransactions(10)
_G.Dev.SetSimulateFailure(true) -- next load fails and kicks (tests the no-overwrite rule)
_G.Dev.Call("ServiceName", "Method", ...) -- call any server service method
```

Tools that don't share `_G` (plugins, MCP) can use `game.ServerStorage._DevBridge:Invoke("GrantShells", nil, 100)`. Neither exists outside Studio.

## Live dev chat commands (admins only)

In live servers and Studio, admins can type `/dev` commands in chat. The admin list is the UserId allowlist `ADMINS` in `src/server/Util/AdminCommands.luau` (currently Fungo_Dev). Everyone else's `/dev` does nothing. Replies appear only in the admin's chat, and every use is printed to the server log. **Live, these change real saved data.**

```
/dev help
/dev shells 500              set Shells          /dev addshells 100   grant Shells
/dev fragment sun_coral 3    grant fragments (negative removes)
/dev unlockall               unlock every socket
/dev finish [socketId|all]   finish growth now
/dev reset                   fresh first-join data
/dev state                   Shells, fragments, sockets
/dev txlog [n]               recent transactions → server log (F9 > Server)
```

Add `@name` to target another player in the same server, e.g. `/dev shells 50 @bob`.

## Running tests

With Studio connected to Rojo, run this in the command bar (Edit mode is fine):

```lua
require(game.ServerStorage.Tests.TestRunner).RunAll()
```

Specs are ModuleScripts in `tests/` named `*.spec.luau`. Each returns `{ [testName] = function() ... end }` and uses the helpers in `tests/Expect.luau`.

The economy pacing simulation (target: all six sockets in 15–25 minutes):

```lua
local S = require(game.ServerStorage.Tests.EconomySim) S.PrintReport(S.Run("greedy")) S.PrintReport(S.Run("fastest"))
```

Note: in a long Edit session, Studio caches required modules. If you change a config and results look stale, restart the session (or start a playtest) before rerunning.
