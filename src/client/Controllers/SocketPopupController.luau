--!strict
-- Popup opened by holding the prompt on a locked socket: socket details (light, flow, best-fit corals),
-- the unlock price and Purchase / Exit. Purchase is only live for the next socket in unlockOrder when
-- the player can afford it; otherwise the status line says why.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CoralDefinitions = require(ReplicatedStorage.Shared.Config.CoralDefinitions)
local SocketDefinitions = require(ReplicatedStorage.Shared.Config.SocketDefinitions)
local HabitatIcons = require(ReplicatedStorage.Shared.Config.HabitatIcons)
local EconomyMath = require(ReplicatedStorage.Shared.Logic.EconomyMath)
local ClientNet = require(script.Parent.Parent.Net.ClientNet)
local StateController = require(script.Parent.StateController)
local Theme = require(script.Parent.Parent.UI.Theme)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local Toast = require(script.Parent.Parent.UI.Toast)

local SocketPopupController = {}

type Refs = {
	gui: ScreenGui,
	frame: Frame,
	scale: UIScale,
	title: TextLabel,
	light: Frame,
	flow: Frame,
	best: Frame,
	price: Frame,
	status: TextLabel,
	purchase: TextButton,
}

local refs: Refs? = nil
local currentSocket: string? = nil
local busy = false

-- Lowest-unlockOrder socket that is still locked, i.e. the only one ShopService will unlock
function SocketPopupController.GetNextLocked(): string?
	local state = StateController.Get()
	if state == nil then
		return nil
	end
	local best: string? = nil
	for socketId, def in SocketDefinitions do
		if state.unlocks.sockets[socketId] ~= true and (best == nil or def.unlockOrder < SocketDefinitions[best].unlockOrder) then
			best = socketId
		end
	end
	return best
end

local function setValue(row: Frame, text: string)
	(row:FindFirstChild("Value") :: TextLabel).Text = text
end

local function build(): Refs
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screen = UIKit.new("ScreenGui", {
		Name = "SocketPopup",
		ResetOnSpawn = false,
		Enabled = false,
		DisplayOrder = 7,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local window = UIKit.panel({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.92, 0, 0, 340),
		Parent = screen,
	}, "Socket", function()
		SocketPopupController.Close()
	end)
	UIKit.new("UISizeConstraint", { MaxSize = Vector2.new(420, 340), Parent = window.frame })
	local scale = UIKit.new("UIScale", { Parent = window.frame })

	local content = window.content
	UIKit.new("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = content,
	})
	UIKit.new("UIPadding", { PaddingTop = UDim.new(0, 6), Parent = content })

	local light = UIKit.statRow({ Name = "Light", LayoutOrder = 1, Parent = content }, "💡", "Light", "")
	local flow = UIKit.statRow({ Name = "Flow", LayoutOrder = 2, Parent = content }, "🌊", "Flow", "")
	local best = UIKit.statRow({ Name = "Best", LayoutOrder = 3, Parent = content }, "🪸", "Best fit", "")
	local bestValue = best:FindFirstChild("Value") :: TextLabel
	bestValue.TextScaled = true
	UIKit.new("UITextSizeConstraint", { MaxTextSize = Theme.TextSize.Body, Parent = bestValue })
	local price = UIKit.statRow({ Name = "Price", LayoutOrder = 4, Parent = content }, "🔒", "Unlock price", "")
	price.BackgroundColor3 = Theme.Colors.Navy

	local status = UIKit.label({
		Name = "Status",
		Size = UDim2.new(1, 0, 0, 26),
		FontFace = Theme.Fonts.Body,
		TextSize = Theme.TextSize.Small,
		LayoutOrder = 5,
		Parent = content,
	})

	local buttons = UIKit.new("Frame", {
		Name = "Buttons",
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundTransparency = 1,
		LayoutOrder = 6,
		Parent = content,
	}, {
		UIKit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local purchase = UIKit.button({
		Name = "Purchase",
		Size = UDim2.new(0.5, -6, 0, 50),
		Text = "Purchase",
		TextSize = Theme.TextSize.Title,
		LayoutOrder = 1,
		Parent = buttons,
	}, Theme.Colors.Green, Theme.Colors.GreenDark)
	purchase.Activated:Connect(function()
		SocketPopupController.Purchase()
	end)
	local exit = UIKit.button({
		Name = "Exit",
		Size = UDim2.new(0.5, -6, 0, 50),
		Text = "Exit",
		TextSize = Theme.TextSize.Title,
		LayoutOrder = 2,
		Parent = buttons,
	}, Theme.Colors.Red, Theme.Colors.RedDark)
	exit.Activated:Connect(function()
		SocketPopupController.Close()
	end)

	screen.Parent = playerGui
	return {
		gui = screen,
		frame = window.frame,
		scale = scale,
		title = window.title,
		light = light,
		flow = flow,
		best = best,
		price = price,
		status = status,
		purchase = purchase,
	}
end

-- Names of the corals that fully match this socket's light and flow
local function bestFit(socketId: string): string
	local socket = SocketDefinitions[socketId]
	local names = {}
	for _, coral in CoralDefinitions do
		if EconomyMath.IsConditionMatch(coral, socket) then
			table.insert(names, coral.displayName)
		end
	end
	table.sort(names)
	return if #names > 0 then table.concat(names, ", ") else "None yet"
end

function SocketPopupController.Refresh()
	local r = refs
	local socketId = currentSocket
	if r == nil or socketId == nil then
		return
	end
	local def = SocketDefinitions[socketId]
	local state = StateController.Get()
	if state and state.unlocks.sockets[socketId] == true then
		SocketPopupController.Close() -- unlocked (here or by DevTools): nothing left to buy
		return
	end

	r.title.Text = def.displayName
	setValue(r.light, HabitatIcons.Light[def.light] .. " " .. HabitatIcons.LightLabel[def.light])
	setValue(r.flow, HabitatIcons.Flow[def.flow] .. " " .. HabitatIcons.FlowLabel[def.flow])
	setValue(r.best, bestFit(socketId))
	setValue(r.price, ("%d 🐚"):format(def.unlockCostShells))

	local shells = StateController.GetShells()
	local nextId = SocketPopupController.GetNextLocked()
	local canBuy = false
	if nextId ~= socketId and nextId ~= nil then
		r.status.Text = ("Unlock %s first"):format(SocketDefinitions[nextId].displayName)
	elseif shells < def.unlockCostShells then
		r.status.Text = ("You have %d 🐚 · need %d more"):format(shells, def.unlockCostShells - shells)
	else
		r.status.Text = ("You have %d 🐚"):format(shells)
		canBuy = true
	end
	r.purchase.Active = canBuy and not busy
	if canBuy then
		UIKit.setButtonColor(r.purchase, Theme.Colors.Green, Theme.Colors.GreenDark)
	else
		UIKit.setButtonColor(r.purchase, Theme.Colors.Disabled, Theme.Colors.DisabledDark)
	end
end

function SocketPopupController.Open(socketId: string)
	if SocketDefinitions[socketId] == nil then
		return
	end
	if refs == nil then
		refs = build()
	end
	local r = refs :: Refs
	currentSocket = socketId
	r.gui.Enabled = true
	SocketPopupController.Refresh()
	r.scale.Scale = 0.85
	TweenService:Create(r.scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

function SocketPopupController.Close()
	currentSocket = nil
	if refs then
		refs.gui.Enabled = false
	end
end

function SocketPopupController.IsOpen(): boolean
	return refs ~= nil and refs.gui.Enabled
end

function SocketPopupController.Purchase()
	local r = refs
	local socketId = currentSocket
	if r == nil or socketId == nil or busy or not r.purchase.Active then
		return
	end
	busy = true
	r.purchase.Active = false
	local result = ClientNet.UnlockSocket(socketId)
	busy = false
	if result.ok then
		SocketPopupController.Close()
		Toast.Success(("%s unlocked!"):format(SocketDefinitions[socketId].displayName))
	else
		SocketPopupController.Refresh() -- ClientNet already showed why in an error toast
		r.status.Text = "Couldn't unlock, try again"
	end
end

function SocketPopupController.Init()
	StateController.Changed:Connect(function(sliceKey: string)
		if SocketPopupController.IsOpen() and (sliceKey == "currencies" or sliceKey == "unlocks" or sliceKey == "snapshot") then
			SocketPopupController.Refresh()
		end
	end)
end

return SocketPopupController
