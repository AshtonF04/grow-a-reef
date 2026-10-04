--!strict
-- Pure, timestamp-based growth math. No Instances, no game, no services, no saved state.
-- The server saves plantedAt/readyAt; everything else is derived from those and the current time.
local Types = require(script.Parent.Parent.Types)
local GrowthConfig = require(script.Parent.Parent.Config.GrowthConfig)

type Placement = Types.Placement
type GrowthStage = Types.GrowthStage

local GrowthMath = {}

function GrowthMath.ComputeReadyAt(plantedAt: number, growSeconds: number, speedMultiplier: number?): number
	assert(growSeconds > 0, "growSeconds must be > 0")
	local speed = speedMultiplier or 1
	assert(speed > 0, "speedMultiplier must be > 0")
	return plantedAt + math.ceil(growSeconds / speed)
end

function GrowthMath.GetProgress(placement: Placement, now: number): number
	local total = placement.readyAt - placement.plantedAt
	if total <= 0 then
		return 1
	end
	return math.clamp((now - placement.plantedAt) / total, 0, 1)
end

function GrowthMath.GetSecondsRemaining(placement: Placement, now: number): number
	return math.max(0, placement.readyAt - now)
end

function GrowthMath.IsReady(placement: Placement, now: number): boolean
	return now >= placement.readyAt
end

function GrowthMath.GetStage(placement: Placement, now: number, conditionsMatched: boolean?): GrowthStage
	if GrowthMath.IsReady(placement, now) then
		return if conditionsMatched then "Flourishing" else "Mature"
	end
	if now - placement.plantedAt < GrowthConfig.FRAGMENT_SECONDS then
		return "Fragment"
	end
	if GrowthMath.GetProgress(placement, now) < GrowthConfig.STAGE_THRESHOLDS.Growing then
		return "Sprouting"
	end
	return "Growing"
end

function GrowthMath.GetVisualStage(stage: GrowthStage): string
	return GrowthConfig.VISUAL_STAGE[stage]
end

-- Timestamp of the next stage change, or nil if already ready. Lets the client schedule model swaps.
function GrowthMath.GetNextStageChangeAt(placement: Placement, now: number): number?
	if GrowthMath.IsReady(placement, now) then
		return nil
	end
	local fragmentEnd = placement.plantedAt + GrowthConfig.FRAGMENT_SECONDS
	local growingAt = placement.plantedAt
		+ (placement.readyAt - placement.plantedAt) * GrowthConfig.STAGE_THRESHOLDS.Growing
	for _, t in { fragmentEnd, growingAt, placement.readyAt } do
		if t > now and t <= placement.readyAt then
			return t
		end
	end
	return placement.readyAt
end

return GrowthMath
