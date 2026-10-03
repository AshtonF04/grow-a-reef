# Grow A Reef

A cosy Roblox reef-building simulator: plant coral fragments in sockets on your reef plot, let them grow in real time, claim Shells, and expand your reef.

## Setup

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in the repo root (installs Rojo, Wally, StyLua, Selene at the pinned versions).
2. Run `rojo serve`.
3. Open the place in Roblox Studio and press **Connect** in the Rojo plugin.

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
