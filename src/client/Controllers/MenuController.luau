--!strict
-- MenuController - one modal panel that shows Upgrades, Hire, Clinic, Style or Shop. Every number comes
-- from the server's state; clicks only send requests. The panel re-renders whenever state changes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local UI = require(script.Parent.Parent.UI)
local C = UI.Colors

local MenuController = Knit.CreateController({ Name = "MenuController" })

local TITLES = {
	Shop = "Shop",
	Upgrades = "Tool Upgrades",
	Hire = "Hire Dentists",
	Clinic = "Your Clinic",
	Style = "Style Your Clinic",
}

local PRODUCT_INFO = {
	DoubleCashPass = {
		name = "2x Cash (forever)",
		info = "Every dollar you earn counts double, permanently.",
	},
	InstantClean = {
		name = "Instant Clean",
		info = "Finish the open treatment now for double cash.",
	},
	CashBoost10m = {
		name = "10 Minute 2x Cash",
		info = "Double cash for 10 minutes. Stacks with the pass!",
	},
	StarterBundle = { name = "Starter Bundle", info = "A pile of cash and a free Filler upgrade." },
}

local SLOT_NAMES = {
	Floor = "Floor",
	Wall = "Walls",
	Trim = "Trim & awning",
	Upholstery = "Chair cushions",
	DeskBody = "Reception desk",
	Door = "Cabinet doors",
	DecorFloor1 = "Floor spot 1",
	DecorFloor2 = "Floor spot 2",
	DecorFloor3 = "Floor spot 3",
	DecorFloor4 = "Floor spot 4",
	DecorWall1 = "Wall spot 1",
	DecorWall2 = "Wall spot 2",
	DecorWall3 = "Wall spot 3",
	DecorWall4 = "Wall spot 4",
}

function MenuController:KnitStart()
	local state = Knit.GetController("StateController")
	local fx = Knit.GetController("FxController")
	local player = Players.LocalPlayer
	self._state, self._fx = state, fx
	self._current = nil :: string?

	local gui = UI.new("ScreenGui", {
		Name = "TeethMenus",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 8,
		Enabled = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local scale = UI.new("UIScale", { Parent = gui })
	local function rescale()
		local view = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
			or Vector2.new(1280, 720)
		scale.Scale = math.clamp(math.min(view.X / 760, view.Y / 560), 0.55, 1.2)
	end
	rescale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end

	local panel = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(580, 480),
		BackgroundColor3 = C.White,
		Visible = false,
		Parent = gui,
	})
	UI.corner(panel, 18)
	UI.stroke(panel, C.Ink, 4)
	local header = UI.new(
		"Frame",
		{ Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = C.Teal, Parent = panel }
	)
	UI.corner(header, 16)
	self._title = UI.label({
		Size = UDim2.new(1, -70, 1, 0),
		Position = UDim2.fromOffset(18, 0),
		Font = UI.Fonts.Title,
		TextSize = 28,
		TextColor3 = C.White,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = header,
	})
	UI.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = C.Coral,
		Text = "X",
		TextSize = 22,
		Parent = header,
		OnClick = function()
			self:Close()
		end,
	})
	self._list = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 66),
		Size = UDim2.new(1, -24, 1, -78),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = panel,
	})
	UI.new(
		"UIListLayout",
		{ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = self._list }
	)
	self._panel = panel

	state.Changed:Connect(function()
		if self._current then
			self:_render()
		end
	end)
end

function MenuController:Toggle(id: string)
	if self._current == id then
		self:Close()
	else
		self:Open(id)
	end
end

function MenuController:Open(id: string)
	self._current = id
	self._panel.Visible = true
	self._title.Text = TITLES[id] or id
	self:_render()
end

function MenuController:Close()
	self._current = nil
	self._panel.Visible = false
end

-- ---- row helpers ------------------------------------------------------------------------------

local order = 0
local function card(parent: Instance, height: number): Frame
	order += 1
	local frame = UI.new("Frame", {
		Size = UDim2.new(1, -6, 0, height),
		BackgroundColor3 = Color3.fromRGB(226, 238, 242),
		LayoutOrder = order,
		Parent = parent,
	})
	UI.corner(frame, 6)
	UI.stroke(frame, C.Ink, 2)
	return frame
end

local function heading(parent: Instance, text: string)
	order += 1
	UI.label({
		Size = UDim2.new(1, -6, 0, 30),
		Font = UI.Fonts.Title,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = text,
		LayoutOrder = order,
		Parent = parent,
	})
end

local function note(parent: Instance, text: string, height: number?)
	order += 1
	UI.label({
		Size = UDim2.new(1, -6, 0, height or 40),
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(80, 96, 108),
		Text = text,
		LayoutOrder = order,
		Parent = parent,
	})
end

function MenuController:_actionButton(
	parent: Instance,
	text: string,
	color: Color3,
	onClick: (() -> ())?
): TextButton
	return UI.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(150, 46),
		BackgroundColor3 = color,
		Text = text,
		TextSize = 19,
		Parent = parent,
		OnClick = function()
			self._fx:Play("click")
			if onClick then
				onClick()
			end
		end,
	})
end

-- ---- panels -----------------------------------------------------------------------------------

function MenuController:_upgrades(s: any)
	note(self._list, "Better tools earn more per tooth. Each level adds 50% to that tool's pay.")
	for _, tool in GameConfig.toolOrder do
		local row = card(self._list, 70)
		local level = s.toolLevels[tool]
		local cost = s.toolCosts[tool]
		local locked = tool == "Pliers" and not s.pliersUnlocked
		UI.label({
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.new(1, -190, 0, 28),
			Font = UI.Fonts.Title,
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = GameConfig.toolNames[tool],
			Parent = row,
		})
		UI.label({
			Position = UDim2.fromOffset(14, 38),
			Size = UDim2.new(1, -190, 0, 24),
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = if locked
				then "LOCKED: unlocks with your 2nd chair"
				else `Level {level} of {GameConfig.maxToolLevel}`,
			Parent = row,
		})
		if locked then
			self:_actionButton(row, "Locked", C.Grey, nil)
		elseif cost == false then
			self:_actionButton(row, "MAX", C.Gold, nil)
		else
			self:_actionButton(
				row,
				UI.money(cost),
				if s.cash >= cost then C.Green else C.Grey,
				function()
					self._state:Send("Upgrade_Buy", tool)
				end
			)
		end
	end
end

function MenuController:_hire(s: any)
	local rate = GameConfig.staffCashPerSecond * (1 + 0.5 * s.tier)
	note(
		self._list,
		`Dentists treat patients for you and earn about ${rate} per second each, even while you're away (up to 8 hours).`,
		56
	)
	local row = card(self._list, 90)
	UI.label({
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -190, 0, 30),
		Font = UI.Fonts.Title,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = `Dentists: {s.dentists} / {s.maxDentists}`,
		Parent = row,
	})
	UI.label({
		Position = UDim2.fromOffset(14, 42),
		Size = UDim2.new(1, -190, 0, 40),
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = if s.dentists >= s.maxDentists
			then "Expand your clinic to hire more."
			else "Your team grows with your clinic.",
		Parent = row,
	})
	if s.dentists >= s.maxDentists then
		self:_actionButton(row, "Full", C.Grey, nil)
	else
		self:_actionButton(
			row,
			`Hire {UI.money(s.hireCost)}`,
			if s.cash >= s.hireCost then C.Green else C.Grey,
			function()
				self._state:Send("Staff_Hire")
			end
		)
	end
end

function MenuController:_clinic(s: any)
	local row = card(self._list, 96)
	UI.label({
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 32),
		Font = UI.Fonts.Title,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = s.tierName,
		Parent = row,
	})
	UI.label({
		Position = UDim2.fromOffset(14, 44),
		Size = UDim2.new(1, -28, 0, 44),
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = `{s.chairs} treatment chair{if s.chairs == 1 then "" else "s"}. Patients arrive faster as your clinic grows.`,
		Parent = row,
	})
	if s.nextTierName then
		local next = card(self._list, 96)
		UI.label({
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.new(1, -190, 0, 32),
			Font = UI.Fonts.Title,
			TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = `Next: {s.nextTierName}`,
			Parent = next,
		})
		UI.label({
			Position = UDim2.fromOffset(14, 44),
			Size = UDim2.new(1, -190, 0, 44),
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "More chairs, more rooms, and new equipment.",
			Parent = next,
		})
		self:_actionButton(
			next,
			`Expand {UI.money(s.nextTierCost)}`,
			if s.cash >= s.nextTierCost then C.Green else C.Grey,
			function()
				self._state:Send("Clinic_Expand")
			end
		)
	else
		note(
			self._list,
			"Your clinic is the biggest it can be. Time to decorate it in the Style menu!",
			40
		)
	end
end

function MenuController:_swatchRow(parent: Instance, slot: string, custom: any)
	local row = card(parent, 96)
	UI.label({
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(1, -28, 0, 24),
		Font = UI.Fonts.Bold,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = SLOT_NAMES[slot],
		Parent = row,
	})
	local holder = UI.new("Frame", {
		Position = UDim2.fromOffset(10, 34),
		Size = UDim2.new(1, -20, 1, -40),
		BackgroundTransparency = 1,
		Parent = row,
	})
	UI.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(34, 24),
		CellPadding = UDim2.fromOffset(6, 4),
		Parent = holder,
	})
	for _, swatch in GameConfig.colorPalette do
		local hex = string.upper(swatch.hex)
		local owned = swatch.cost == 0 or custom.owned[hex]
		local selected = string.upper(custom.colors[slot] or "") == hex
		local button = UI.button({
			BackgroundColor3 = Color3.fromHex(hex),
			Text = if owned then "" else "$",
			TextSize = 12,
			Parent = holder,
			OnClick = function()
				self._fx:Play("click")
				self._state:Send("Clinic_Customize", { colors = { [slot] = hex } })
			end,
		})
		UI.corner(button, 8)
		UI.stroke(
			button,
			if selected then C.Ink else Color3.fromRGB(180, 190, 196),
			if selected then 3 else 1
		)
		if not owned then
			UI.label({ Size = UDim2.fromScale(1, 1), Text = "", Parent = button })
		end
	end
end

function MenuController:_decorRow(parent: Instance, slot: string, custom: any)
	local row = card(parent, 92)
	UI.label({
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(1, -28, 0, 24),
		Font = UI.Fonts.Bold,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = SLOT_NAMES[slot],
		Parent = row,
	})
	local holder = UI.new("Frame", {
		Position = UDim2.fromOffset(10, 32),
		Size = UDim2.new(1, -20, 1, -38),
		BackgroundTransparency = 1,
		Parent = row,
	})
	UI.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		Wraps = true,
		Parent = holder,
	})
	local wantsFloor = slot:sub(1, 10) == "DecorFloor"
	local function option(id: string, label: string, cost: number)
		local owned = cost == 0 or custom.owned[id]
		local selected = (custom.decor[slot] or "") == id
		local button = UI.button({
			Size = UDim2.fromOffset(if id == "" then 56 else 108, 40),
			BackgroundColor3 = if selected then C.Deep else C.Teal,
			Text = if owned then label else `{label} {UI.money(cost)}`,
			TextSize = 12,
			Parent = holder,
			OnClick = function()
				self._fx:Play("click")
				self._state:Send("Clinic_Customize", { decor = { [slot] = id } })
			end,
		})
		UI.stroke(button, if selected then C.Yellow else C.Deep, if selected then 3 else 1)
	end
	option("", "None", 0)
	for id, item in GameConfig.decor do
		if (item.kind == "floor") == wantsFloor then
			option(id, item.name, item.cost)
		end
	end
end

function MenuController:_style(s: any)
	note(
		self._list,
		"Pick colours and decorations. Swatches marked $ and items with a price cost cash the first time; after that they're yours.",
		56
	)
	heading(self._list, "Colours")
	for _, slot in GameConfig.colorSlots do
		self:_swatchRow(self._list, slot, s.customize)
	end
	heading(self._list, "Decorations")
	for _, slot in GameConfig.decorSlots do
		self:_decorRow(self._list, slot, s.customize)
	end
end

function MenuController:_shop(s: any)
	note(self._list, "Support the game with Robux. Items marked Soon are on their way!", 32)
	for _, key in { "DoubleCashPass", "InstantClean", "CashBoost10m", "StarterBundle" } do
		local info = PRODUCT_INFO[key]
		local row = card(self._list, 84)
		UI.label({
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.new(1, -190, 0, 28),
			Font = UI.Fonts.Title,
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = info.name,
			Parent = row,
		})
		UI.label({
			Position = UDim2.fromOffset(14, 38),
			Size = UDim2.new(1, -190, 0, 40),
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = info.info,
			Parent = row,
		})
		local available = s.products[key]
		self:_actionButton(
			row,
			if available then "Buy" else "Soon",
			if available then C.Green else C.Grey,
			function()
				self._state:Send("Shop_Buy", key)
			end
		)
	end
	local sound = card(self._list, 64)
	UI.label({
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -190, 1, 0),
		Font = UI.Fonts.Title,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Sound effects",
		Parent = sound,
	})
	local fx = self._fx
	self:_actionButton(
		sound,
		if fx.Muted then "Off" else "On",
		if fx.Muted then C.Grey else C.Green,
		function()
			fx.Muted = not fx.Muted
			self:_render()
		end
	)
end

function MenuController:_render()
	local s = self._state.State
	if not s or not self._current then
		return
	end
	for _, child in self._list:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	order = 0
	local id = self._current
	if id == "Upgrades" then
		self:_upgrades(s)
	elseif id == "Hire" then
		self:_hire(s)
	elseif id == "Clinic" then
		self:_clinic(s)
	elseif id == "Style" then
		self:_style(s)
	elseif id == "Shop" then
		self:_shop(s)
	end
end

return MenuController
