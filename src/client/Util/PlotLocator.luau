--!strict
-- Finds the local player's plot from the replicated PlotId attribute (set by PlotService.AssignPlot).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local PlotLocator = {}

-- Yields until the player has a plot (or timeout). Returns nil if none arrives.
function PlotLocator.WaitForOwnPlot(timeout: number?): Model?
	local player = Players.LocalPlayer
	local deadline = os.clock() + (timeout or 30)
	while os.clock() < deadline do
		local plotId = player:GetAttribute("PlotId")
		if type(plotId) == "string" then
			local plots = workspace:WaitForChild("PlayerPlots", 10)
			local plot = plots and plots:WaitForChild(plotId, 10)
			if plot and plot:IsA("Model") then
				return plot
			end
		end
		player:GetAttributeChangedSignal("PlotId"):Wait()
	end
	return nil
end

-- Calls callback(socketId, socket) for every socket on the plot now and whenever one streams in later
function PlotLocator.ObserveSockets(plot: Model, callback: (string, BasePart) -> ())
	local seen: { [Instance]: boolean } = {}
	local function consider(inst: Instance)
		if not seen[inst] and inst:IsA("BasePart") and inst:IsDescendantOf(plot) then
			seen[inst] = true
			task.spawn(callback, inst.Name, inst)
		end
	end
	CollectionService:GetInstanceAddedSignal("ReefSocket"):Connect(consider)
	CollectionService:GetInstanceRemovedSignal("ReefSocket"):Connect(function(inst)
		seen[inst] = nil
	end)
	for _, inst in CollectionService:GetTagged("ReefSocket") do
		consider(inst)
	end
end

-- Socket Parts on a plot, keyed by socket id (the Part's name)
function PlotLocator.GetSockets(plot: Model): { [string]: BasePart }
	local sockets = {}
	for _, inst in plot:GetDescendants() do
		if inst:IsA("BasePart") and CollectionService:HasTag(inst, "ReefSocket") then
			sockets[inst.Name] = inst
		end
	end
	return sockets
end

return PlotLocator
