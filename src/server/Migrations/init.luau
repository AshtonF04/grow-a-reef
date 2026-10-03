--!strict
-- Ordered save-data migrations. Each step upgrades a save from `from` to `to`.
-- Migrations must never delete data a player earned without explicit sign-off from both developers.

export type Migration = {
	from: number,
	to: number,
	run: (data: any) -> any,
}

local Migrations: { Migration } = {
	-- Empty at schema v1.
}

return Migrations
