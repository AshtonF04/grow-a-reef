--!strict
export type LightLevel = "Bright" | "Dim"
export type FlowLevel = "Low" | "Medium" | "High"

export type ErrorCode = "InvalidArgs" | "RateLimited" | "NotLoaded" | "UnknownCoral" | "UnknownSocket" | "SocketLocked" | "SocketOccupied" | "SocketEmpty" | "ZoneLocked" | "ZoneLocked" | "NotEnoughFragments" | "NotEnoughShells" | "NotEnoughPearls" | "NotReady" | "AlreadyUnlocked" | "Internal"

export type Result<T> = { ok: true, value: T} | { ok: false, err: ErrorCode }

export type GrowthStage = "Fragment" | "Sprouting" | "Growing" | "Mature" | "Flourishing"
export type Placement = { coralId: string, plantedAt: number, readyAt: number, trait: string? }

export type PlayerData = {
  version: number,
  currencies: { shells: number, pearls: number },
  unlocks: { zone: number, sockets: { [string]: boolean } },
  inventory: { fragments: { [string]: number } },
  placements: { [string]: Placement },              -- key = socketId
  discoveries: { corals: { [string]: boolean }, fish: { [string]: boolean }, traits: { [string]: boolean } },
  tutorial: { version: number, step: string, done: boolean },
  meta: { firstJoin: number, lastSeen: number },
}

export type ClientState = {
    currencies: { shells: number, pearls: number },
    unlocks: { zone: number, sockets: { [string]: boolean } },
    inventory: { fragments: { [string]: number } },
    placements: { [string]: Placement },              -- key = socketId
    discoveries: { corals: { [string]: boolean }, fish: { [string]: boolean }, traits: { [string]: boolean } },
    tutorial: { version: number, step: string, done: boolean },

}

export type ClaimReward = { shells: number, fragmentCoralId: string, trait: string?, newDiscoveries: { string } }
export type SocketSnapshot = { socketId: string, coralId: string, stage: GrowthStage, progress: number, readyAt: number, ready: boolean }

return {}