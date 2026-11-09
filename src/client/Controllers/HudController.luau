--!strict
-- HudController - the always-on screen: cash, patient timer, goal, menu bar, playtime reward,
-- announcement banners and the "what do I do now" hint. Clean low-poly look (see UI.luau).
--
-- Layout is built around Roblox's own UI, which we cannot move:
--   top strip        Roblox menu / chat buttons  -> the ScreenGui respects the inset, so y = 0 is below it
--   top left         chat window                 -> nothing of ours on the left edge
--   top right        player list                 -> nothing of ours on the right edge
--   bottom left      touch thumbstick            -> nothing of ours in the bottom corners
--   bottom right     touch jump button
-- So everything lives in two centred stacks: status + goal + banners at the top centre, and the
-- menu bar + hint at the bottom centre.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local UI = require(script.Parent.Parent.UI)
local C = UI.Colors

local HudController = Knit.CreateController({ Name = "HudController" })

local BANNER_COLORS = {
	info = C.Slate,
	good = C.Green,
	warn = C.Coral,
	goal = C.Gold,
	alert = C.Pink,
}

local MENU_BUTTONS = {
	{ id = "Shop", letter = "S", label = "SHOP", color = C.Coral },
	{ id = "Upgrades", letter = "U", label = "UPGRADE", color = C.Teal },
	{ id = "Hire", letter = "H", label = "HIRE", color = C.Sky },
	{ id = "Clinic", letter = "C", label = "CLINIC", color = C.Green },
	{ id = "Style", letter = "A", label = "STYLE", color = Color3.fromRGB(150, 110, 220) },
}
local BUTTON_W, BUTTON_H, BUTTON_GAP = 74, 66, 8
local BAR_W = (#MENU_BUTTONS + 1) * BUTTON_W + #MENU_BUTTONS * BUTTON_GAP
local TOP_W = 440

function HudController:KnitStart()
	local state = Knit.GetController("StateController")
	local fx = Knit.GetController("FxController")
	local menu = Knit.GetController("MenuController")
	local player = Players.LocalPlayer

	local gui = UI.new("ScreenGui", {
		Name = "TeethHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = false, -- stay below Roblox's top bar and inside device safe areas
		DisplayOrder = 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- two centred stacks, each scaled as a whole (panels and their drop shadows together)
	local scales = {}
	local function stack(anchorY: number, offsetY: number, width: number, height: number): Frame
		local holder = UI.new("Frame", {
			AnchorPoint = Vector2.new(0.5, anchorY),
			Position = UDim2.new(0.5, 0, anchorY, offsetY),
			Size = UDim2.fromOffset(width, height),
			BackgroundTransparency = 1,
			Parent = gui,
		})
		table.insert(scales, UI.new("UIScale", { Parent = holder }))
		return holder
	end
	local top = stack(0, 6, TOP_W, 88)
	local bottom = stack(1, -10, BAR_W, BUTTON_H)
	local function rescale()
		local view = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
			or Vector2.new(1280, 720)
		local s = math.clamp(math.min(view.X / 1100, view.Y / 640), 0.6, 1.25)
		for _, scale in scales do
			scale.Scale = s
		end
	end
	rescale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end

	-- ---- top: cash + next patient ---------------------------------------------------------------
	local status = UI.panel({
		Name = "Status",
		Size = UDim2.fromOffset(TOP_W, 46),
		BackgroundColor3 = C.Slate,
		Parent = top,
	})
	UI.badge(status, "$", C.Gold, 36, UDim2.fromOffset(6, 5))
	local cashLabel = UI.label({
		Position = UDim2.fromOffset(48, 0),
		Size = UDim2.fromOffset(180, 46),
		Font = UI.Fonts.Title,
		TextSize = 26,
		TextColor3 = C.White,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false,
		Text = "$0",
		Parent = status,
	})
	UI.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -82, 0, 0),
		Size = UDim2.fromOffset(120, 46),
		Font = UI.Fonts.Bold,
		TextSize = 13,
		TextColor3 = C.Mint,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "NEXT PATIENT",
		Parent = status,
	})
	local timer = UI.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 0),
		Size = UDim2.fromOffset(64, 46),
		Font = UI.Fonts.Title,
		TextSize = 24,
		TextColor3 = C.White,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "...",
		Parent = status,
	})

	-- ---- top: goal ------------------------------------------------------------------------------
	local goal = UI.panel({
		Name = "Goal",
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.fromOffset(TOP_W, 34),
		BackgroundColor3 = C.Cream,
		Parent = top,
	})
	local tag = UI.label({
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.fromOffset(46, 22),
		BackgroundTransparency = 0,
		BackgroundColor3 = C.Yellow,
		Font = UI.Fonts.Title,
		TextSize = 12,
		Text = "GOAL",
		Parent = goal,
	})
	UI.corner(tag, 4)
	UI.stroke(tag, C.Ink, 2)
	local goalText = UI.label({
		Position = UDim2.fromOffset(62, 0),
		Size = UDim2.fromOffset(188, 34),
		Font = UI.Fonts.Bold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "...",
		Parent = goal,
	})
	local barBack = UI.new("Frame", {
		Position = UDim2.fromOffset(258, 7),
		Size = UDim2.fromOffset(100, 20),
		BackgroundColor3 = Color3.fromRGB(205, 215, 220),
		BorderSizePixel = 0,
		Parent = goal,
	})
	UI.corner(barBack, 4)
	UI.stroke(barBack, C.Ink, 2)
	local barFill = UI.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.Green,
		BorderSizePixel = 0,
		Parent = barBack,
	})
	UI.corner(barFill, 4)
	local barText = UI.label({
		Size = UDim2.fromScale(1, 1),
		Font = UI.Fonts.Title,
		TextSize = 12,
		Parent = barBack,
	})
	local reward = UI.label({
		Position = UDim2.fromOffset(366, 6),
		Size = UDim2.fromOffset(66, 22),
		BackgroundTransparency = 0,
		BackgroundColor3 = C.Green,
		TextColor3 = C.White,
		Font = UI.Fonts.Title,
		TextSize = 13,
		Parent = goal,
	})
	UI.corner(reward, 4)
	UI.stroke(reward, C.Ink, 2)

	-- ---- top: banners drop in under the goal ----------------------------------------------------
	local banners = UI.new("Frame", {
		Position = UDim2.fromOffset(0, 98),
		Size = UDim2.fromOffset(TOP_W, 200),
		BackgroundTransparency = 1,
		Parent = top,
	})
	UI.new("UIListLayout", { Padding = UDim.new(0, 8), Parent = banners })
	local function banner(text: string, kind: string?)
		local frame = UI.new("Frame", {
			Size = UDim2.fromOffset(TOP_W, 46),
			BackgroundColor3 = BANNER_COLORS[kind or "info"] or C.Slate,
			BorderSizePixel = 0,
			Parent = banners,
		})
		UI.corner(frame, 5)
		UI.stroke(frame, C.Ink, 3)
		local label = UI.label({
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -20, 1, 0),
			Font = UI.Fonts.Title,
			TextSize = 15,
			TextColor3 = C.White,
			Text = text,
			Parent = frame,
		})
		task.delay(if kind == "alert" then 6 else 4, function()
			UI.tween(frame, 0.4, { BackgroundTransparency = 1 })
			UI.tween(label, 0.4, { TextTransparency = 1 })
			task.wait(0.45)
			frame:Destroy()
		end)
	end
	state.Announced:Connect(function(text, kind)
		banner(text, kind)
		if kind == "good" or kind == "goal" then
			fx:Play("good")
		elseif kind == "warn" then
			fx:Play("warn")
		elseif kind == "alert" then
			fx:Play("alert")
		end
	end)

	-- ---- bottom: menu bar (five menus + the playtime gift) --------------------------------------
	local row = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = bottom,
	})
	UI.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, BUTTON_GAP),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	local function barButton(
		order: number,
		letter: string,
		text: string,
		color: Color3,
		onClick: () -> ()
	)
		local button = UI.button({
			Size = UDim2.fromOffset(BUTTON_W, BUTTON_H),
			LayoutOrder = order,
			BackgroundColor3 = color,
			Text = "",
			Parent = row,
			OnClick = function()
				fx:Play("click")
				onClick()
			end,
		})
		UI.badge(button, letter, C.Ink, 32, UDim2.fromOffset((BUTTON_W - 32) / 2, 4))
		local label = UI.label({
			Position = UDim2.fromOffset(0, 40),
			Size = UDim2.new(1, 0, 0, 20),
			Font = UI.Fonts.Title,
			TextSize = 11,
			TextColor3 = C.White,
			TextWrapped = false,
			Text = text,
			Parent = button,
		})
		return button, label
	end
	for i, def in MENU_BUTTONS do
		barButton(i, def.letter, def.label, def.color, function()
			menu:Toggle(def.id)
		end)
	end
	local gift, giftTime = barButton(#MENU_BUTTONS + 1, "G", "GIFT", C.Gold, function()
		state:Send("Reward_Claim", "playtime")
	end)

	-- ---- bottom: hint and boost sit just above the bar ------------------------------------------
	local hintPanel = UI.panel({
		Position = UDim2.fromOffset(0, -54),
		Size = UDim2.fromOffset(BAR_W, 44),
		BackgroundColor3 = C.Slate,
		Visible = false,
		Parent = bottom,
	})
	local hint = UI.label({
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -20, 1, 0),
		Font = UI.Fonts.Bold,
		TextSize = 14,
		TextColor3 = C.White,
		Parent = hintPanel,
	})
	local boostLabel = UI.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -90),
		Size = UDim2.fromOffset(170, 28),
		BackgroundTransparency = 0,
		BackgroundColor3 = C.Pink,
		Font = UI.Fonts.Title,
		TextSize = 14,
		TextColor3 = C.White,
		Visible = false,
		Parent = bottom,
	})
	UI.corner(boostLabel, 4)
	UI.stroke(boostLabel, C.Ink, 2)

	-- ---- live values ----------------------------------------------------------------------------
	local cashTarget, cashShown = 0, 0
	local giftReadyAt = math.huge
	local boostEndsAt = 0
	local function refreshHint()
		local s = state.State
		local waiting = 0
		for _, chair in state.Chairs do
			if chair.state == "waiting" or chair.state == "treating" then
				waiting += 1
			end
		end
		if waiting > 0 then
			hint.Text = "A patient is waiting! Walk to their chair and press E (or tap the button)."
			hintPanel.Visible = true
		elseif s and s.treated == 0 then
			hint.Text = "Your first patient is on the way..."
			hintPanel.Visible = true
		else
			hintPanel.Visible = false
		end
	end
	state.ChairsChanged:Connect(refreshHint)
	state.TimerChanged:Connect(function(seconds)
		timer.Text = UI.clock(seconds)
	end)
	state.Changed:Connect(function(s)
		cashTarget = s.cash
		goalText.Text = s.goal.text
		reward.Text = UI.money(s.goal.reward)
		barFill.Size = UDim2.fromScale(math.clamp(s.goal.progress / s.goal.target, 0, 1), 1)
		barText.Text = `{s.goal.progress} / {s.goal.target}`
		giftReadyAt = os.clock() + s.playtimeIn
		boostEndsAt = os.clock() + s.boostLeft
		refreshHint()
	end)

	RunService.RenderStepped:Connect(function(dt)
		if cashShown ~= cashTarget then
			cashShown += (cashTarget - cashShown) * math.min(1, dt * 9)
			if math.abs(cashTarget - cashShown) < 1 then
				cashShown = cashTarget
			end
			cashLabel.Text = UI.money(cashShown)
		end
		local left = giftReadyAt - os.clock()
		if left <= 0 then
			giftTime.Text = "CLAIM!"
			gift.BackgroundColor3 = C.Green
		else
			giftTime.Text = UI.clock(left)
			gift.BackgroundColor3 = C.Gold
		end
		local boost = boostEndsAt - os.clock()
		boostLabel.Visible = boost > 0
		if boost > 0 then
			boostLabel.Text = `2X CASH  {UI.clock(boost)}`
		end
	end)
end

return HudController
