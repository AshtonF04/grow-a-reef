--!strict

--[[

-- Claims a free plot for a player
function PlotService.AssignPlot(player: Player)

-- Releases a plot on leave
function ReleasePlot(player: Player)

-- Gets a plot for a player
function GetPlot(player: Player)

]]


-- Require roblox services
local CollectionService = game:GetService("CollectionService")

local PlotService = {}

function PlotService:Init()
    -- Get all plots in the workspace
    local plots = CollectionService:GetTagged("ReefPlot")
    local count = #plots
    if count <= 0 then
        warn("PlotService: No models tagged with 'ReefPlot' found")
        return
    end
end


return PlotService