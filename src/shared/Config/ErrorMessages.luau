--!strict
-- Friendly text for every Types.ErrorCode, shown as error toasts by ClientNet (M5-01).
-- RateLimited is never shown (ClientNet stays silent for it); it's listed so the table stays complete.
local Types = require(script.Parent.Parent.Types)

local MESSAGES: { [Types.ErrorCode]: string } = {
	InvalidArgs = "Something went wrong. Try again!",
	RateLimited = "Slow down a little!",
	NotLoaded = "Your reef is still loading…",
	UnknownCoral = "That coral doesn't exist.",
	UnknownSocket = "That spot doesn't exist.",
	SocketLocked = "That spot is locked. Unlock it first!",
	SocketOccupied = "Something is already growing there.",
	SocketEmpty = "Nothing is growing there yet.",
	ZoneLocked = "That coral needs a deeper zone.",
	PrerequisiteMissing = "Unlock the earlier spots first.",
	NotEnoughFragments = "You're out of that fragment. Visit the Reef Shop!",
	NotEnoughShells = "Not enough Shells yet.",
	NotEnoughPearls = "Not enough Pearls yet.",
	NotReady = "That coral is still growing.",
	AlreadyUnlocked = "That spot is already unlocked.",
	TooFar = "Walk up to the Reef Shop to buy.",
	Internal = "The reef hiccuped. Try again!",
}

local ErrorMessages = {}

function ErrorMessages.Get(code: string): string
	return MESSAGES[code :: Types.ErrorCode] or MESSAGES.Internal
end

-- Codes that never show a toast
function ErrorMessages.IsSilent(code: string): boolean
	return code == "RateLimited"
end

return table.freeze(ErrorMessages)
