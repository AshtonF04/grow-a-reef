--!strict
-- Short messages at the top centre of the screen, clear of the reef and the left HUD column (M5-01).
-- Three kinds, each with its own colour and icon so colour is never the only cue:
-- info (blue ℹ️), success (green ✅), error (red ⚠️). At most MAX_VISIBLE show at once; a new toast pushes
-- the oldest out. Repeating the newest toast's text just restarts its timer instead of stacking copies.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)

export type Kind = "info" | "success" | "error"

local Toast = {}

local MAX_VISIBLE = 3
local SHOW_SECONDS = 3
local WIDTH = 380
local HEIGHT = 48

local STYLES: { [Kind]: { icon: string, color: Color3, dark: Color3 } } = {
	info = { icon = "ℹ️", color = Theme.Colors.Blue, dark = Theme.Colors.BlueDark },
	success = { icon = "✅", color = Theme.Colors.Green, dark = Theme.Colors.GreenDark },
	error = { icon = "⚠️", color = Theme.Colors.Red, dark = Theme.Colors.RedDark },
}

type Entry = { frame: Frame, text: string, kind: Kind, expire: thread? }

local stack: Frame? = nil
local entries: { Entry } = {} -- oldest first
local order = 0

local function getStack(): Frame?
	if stack and stack.Parent then
		return stack
	end
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return nil
	end
	local screen = UIKit.new("ScreenGui", {
		Name = "Toasts",
		ResetOnSpawn = false,
		DisplayOrder = 50, -- above every panel
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	stack = UIKit.new("Frame", {
		Name = "Stack",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(WIDTH, (HEIGHT + 6) * MAX_VISIBLE),
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		UIKit.new("UIListLayout", {
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	-- Never wider than the screen minus the 16px gutters (phones)
	local camera = workspace.CurrentCamera
	if camera then
		local function fit()
			(stack :: Frame).Size = UDim2.fromOffset(math.min(WIDTH, camera.ViewportSize.X - 32), (HEIGHT + 6) * MAX_VISIBLE)
		end
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
		fit()
	end
	return stack
end

local function remove(entry: Entry)
	local index = table.find(entries, entry)
	if index == nil then
		return
	end
	table.remove(entries, index)
	if entry.expire then
		task.cancel(entry.expire)
	end
	local scale = entry.frame:FindFirstChildOfClass("UIScale")
	if scale then
		TweenService:Create(scale, TweenInfo.new(0.15), { Scale = 0 }):Play()
	end
	task.delay(0.16, function()
		entry.frame:Destroy()
	end)
end

local function schedule(entry: Entry)
	if entry.expire then
		task.cancel(entry.expire)
	end
	entry.expire = task.delay(SHOW_SECONDS, function()
		entry.expire = nil
		remove(entry)
	end)
end

function Toast.Show(kind: Kind, text: string)
	local parent = getStack()
	if parent == nil then
		return
	end
	local newest = entries[#entries]
	if newest and newest.text == text and newest.kind == kind then
		schedule(newest)
		return
	end
	if #entries >= MAX_VISIBLE then
		remove(entries[1])
	end

	local style = STYLES[kind]
	order += 1
	local frame = UIKit.new("Frame", {
		Name = "Toast_" .. kind,
		Size = UDim2.new(1, 0, 0, HEIGHT),
		BackgroundColor3 = style.color,
		LayoutOrder = order,
	}, {
		UIKit.corner(Theme.Corner.M),
		UIKit.stroke(style.dark, 3),
		UIKit.gloss(),
		UIKit.new("UIScale", { Scale = 0.6 }),
		UIKit.new("TextLabel", {
			Name = "Icon",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(28, 28),
			Text = style.icon,
			TextScaled = true,
			FontFace = Theme.Fonts.Body,
		}),
	})
	local label = UIKit.label({
		Name = "Message",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 46, 0.5, 0),
		Size = UDim2.new(1, -56, 1, -10),
		Text = text,
		FontFace = Theme.Fonts.Body,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	UIKit.new("UITextSizeConstraint", { MaxTextSize = Theme.TextSize.Body, Parent = label })
	local labelStroke = label:FindFirstChildOfClass("UIStroke")
	if labelStroke then
		labelStroke.Color = style.dark
	end
	frame.Parent = parent
	TweenService:Create(frame:FindFirstChildOfClass("UIScale") :: UIScale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()

	local entry: Entry = { frame = frame, text = text, kind = kind }
	table.insert(entries, entry)
	schedule(entry)
end

function Toast.Info(text: string)
	Toast.Show("info", text)
end

function Toast.Success(text: string)
	Toast.Show("success", text)
end

function Toast.Error(text: string)
	Toast.Show("error", text)
end

return Toast
