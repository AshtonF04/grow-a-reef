--!strict

export type Placement = {
	coralId: string,
	plantedAt: number,
}

export type PlayerState = {
	playerID: string,
	shells: number,
	pearls: number,
	socketUnlocks: { [string]: boolean },
	placements: { [string]: Placement? },
	fragments: { [string]: number },
}

return {}
