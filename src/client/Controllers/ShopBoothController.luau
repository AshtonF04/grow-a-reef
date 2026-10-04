--!strict
-- The hub shop stall (built by BuildWorld): a hold-E prompt on its ShopCounter part opens the fragment shop,
-- the shop closes again once you walk away, and Teleport() (HUD Shop button, "Go to Shop" on empty sockets)
-- drops you in front of the stall. The landing CFrame is a `ShopTeleport` attribute on workspace.World so it
-- works even while the stall is streamed out. The shopkeeper NPC (tagged ShopNPC) gets a gentle idle bob.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local EconomyConfig = require(game:GetService("ReplicatedStorage").Shared.Config.EconomyConfig)
local ShopController = require(script.Parent.ShopController)

local ShopBoothController = {}

local HOLD_SECONDS = 0.4
-- A little inside the server's SHOP_RANGE so the panel closes before purchases would start failing
local CLOSE_DISTANCE = EconomyConfig.SHOP_RANGE - 5
local WATCH_INTERVAL = 0.5
local WATCH_MAX_TICKS = 2400 -- 20 minutes; the watcher always ends

local counter: BasePart? = nil
local watchId = 0

local function rootPart(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Closes the shop once the player is too far from the counter (or the counter streams out)
local function watchDistance()
	watchId += 1
	local myId = watchId
	task.spawn(function()
		for _ = 1, WATCH_MAX_TICKS do
			task.wait(WATCH_INTERVAL)
			if myId ~= watchId or not ShopController.IsOpen() then
				return
			end
			local root = rootPart()
			local c = counter
			if root == nil or c == nil or c.Parent == nil or (root.Position - c.Position).Magnitude > CLOSE_DISTANCE then
				ShopController.Close()
				return
			end
		end
	end)
end

local function bindCounter(part: BasePart)
	if part:FindFirstChild("ShopPrompt") then
		return
	end
	counter = part
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ObjectText = "Reef Shop"
	prompt.ActionText = "Shop"
	prompt.HoldDuration = HOLD_SECONDS
	prompt.Style = Enum.ProximityPromptStyle.Custom -- drawn by PromptController
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function()
		ShopController.Open()
		watchDistance()
	end)
end

-- Bob the NPC's mesh parts up and down with one repeating tween each (client-side, anchored parts)
local function bindNPC(npc: Instance)
	if not npc:IsA("Model") then
		return
	end
	for _, part in npc:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "Root" then
			local info = TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
			TweenService:Create(part, info, { CFrame = part.CFrame * CFrame.new(0, 0.25, 0) }):Play()
		end
	end
end

local function observe(tag: string, callback: (Instance) -> ())
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst)
		task.spawn(callback, inst)
	end)
	for _, inst in CollectionService:GetTagged(tag) do
		task.spawn(callback, inst)
	end
end

function ShopBoothController.Teleport()
	local world = workspace:FindFirstChild("World")
	local target = world and world:GetAttribute("ShopTeleport")
	local character = Players.LocalPlayer.Character
	if typeof(target) ~= "CFrame" or character == nil or rootPart() == nil then
		warn("ShopBoothController: can't teleport to the shop right now")
		return
	end
	-- The client owns its character, so the move replicates
	character:PivotTo(target + Vector3.new(0, 3, 0))
	-- Swing the camera behind the player facing the stall; otherwise it keeps its old angle and the stall (and
	-- its prompt, which only shows on screen) can end up behind it
	local camera = workspace.CurrentCamera
	if camera then
		local focus = target.Position + target.LookVector * 8 + Vector3.new(0, 2, 0)
		camera.CFrame = CFrame.lookAt((target * CFrame.new(0, 6, 12)).Position, focus)
	end
end

function ShopBoothController.Init()
	observe("ShopCounter", function(inst)
		if inst:IsA("BasePart") then
			bindCounter(inst)
		end
	end)
	observe("ShopNPC", bindNPC)
end

return ShopBoothController
