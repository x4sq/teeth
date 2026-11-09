--!strict
-- TreatmentController - the mouth minigame. The server hands us a mouth (a list of issues); we draw it
-- and let the player fix each one, reporting "cleaned issue N with tool T". We never decide pay: the
-- server validates every report and answers with Treat_Feedback / Treat_Result.
--
-- You pick a tool (tray buttons or keys 1-4), it follows the pointer, and it only works on its own
-- problem, each with its own motion (rules and numbers in Core/ToolWork and GameConfig.minigame):
--   Toothbrush  hold and scrub over yellow teeth
--   Floss       slide up and down in a gap with food in it
--   Filler      hold still on a chipped tooth until it is filled
--   Pliers      grab a rotten tooth and drag it out of the gum
-- When a tool has nothing left to do, the next tool with work is picked for you.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ToolWork = require(ReplicatedStorage.Shared.Core.ToolWork)
local UI = require(script.Parent.Parent.UI)
local C = UI.Colors

local TreatmentController = Knit.CreateController({ Name = "TreatmentController" })

local CFG = GameConfig.minigame
local TOOL_KEYS: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.One] = "Toothbrush",
	[Enum.KeyCode.Two] = "Floss",
	[Enum.KeyCode.Three] = "Spatula",
	[Enum.KeyCode.Four] = "Pliers",
}
local HOW: { [string]: string } = {
	Toothbrush = "Hold and scrub the yellow teeth until they shine.",
	Floss = "Slide the floss up and down between the teeth to pull the food out.",
	Spatula = "Hold the filler still on a chipped tooth until the chip is gone.",
	Pliers = "Grab a rotten tooth and drag it out of the gum.",
}
local SEND_GAP = GameConfig.minSecondsBetweenCleans + 0.06 -- the server rejects reports closer than its floor

local TOOTH_WHITE = Color3.fromRGB(252, 252, 250)
local MOUTH_DARK = Color3.fromRGB(96, 18, 38)
local GUM = Color3.fromRGB(236, 128, 146)
local TW, TH = ToolWork.TOOTH_W, ToolWork.TOOTH_H

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch
end

local function fadeOut(frame: GuiObject)
	UI.tween(frame, 0.25, { BackgroundTransparency = 1 })
	task.delay(0.27, function()
		frame.Visible = false
	end)
end

function TreatmentController:KnitStart()
	local state = Knit.GetController("StateController")
	self._state, self._fx = state, Knit.GetController("FxController")
	self._session = nil :: any
	self._issues = {} :: { any }
	self._teeth = {} :: { [number]: Frame }
	self._tool = "Toothbrush"
	self._speed = 1
	self._down = false
	self._pointer = nil :: Vector2?
	self._grab = nil :: any
	self._queue = {} :: { any }
	self._nextSend = 0
	self._deadline = nil :: number?
	self._player = Players.LocalPlayer

	self:_build()

	state.TreatOpen:Connect(function(payload)
		self:Open(payload)
	end)
	state.TreatFeedback:Connect(function(payload)
		self:_onFeedback(payload)
	end)
	state.TreatResult:Connect(function(payload)
		self:_onResult(payload)
	end)
	state.TreatClosed:Connect(function(sessionId)
		if self._session and self._session.sessionId == sessionId then
			self:_hide()
		end
	end)

	-- One pointer for the whole mouth; what it touches is worked out by position (Core/ToolWork),
	-- so scrubbing across several teeth in one stroke just works. The dim behind the card marks
	-- every click as "processed", so that flag is ignored for the pointer.
	UserInputService.InputBegan:Connect(function(input, processed)
		if not self._session then
			return
		end
		if isPress(input) then
			self:_press(self:_toStage(input))
		elseif not processed and TOOL_KEYS[input.KeyCode] then
			self:_selectTool(TOOL_KEYS[input.KeyCode])
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if self._session and isMove(input) then
			self:_move(self:_toStage(input))
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if isPress(input) then
			self:_release(input.UserInputType == Enum.UserInputType.Touch)
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		self:_tick(dt)
	end)
end

--- Pointer position in stage pixels (the stage is scaled with the card).
function TreatmentController:_toStage(input: InputObject): Vector2
	local screen = Vector2.new(input.Position.X, input.Position.Y)
	return (screen - self._stage.AbsolutePosition) / self._scale.Scale
end

--- Walking and the camera are off while the mouth is open (the pointer belongs to the tools).
function TreatmentController:_setControls(on: boolean)
	local ok, err = pcall(function()
		local module = self._player:WaitForChild("PlayerScripts"):FindFirstChild("PlayerModule")
		if module then
			local controls = (require :: any)(module):GetControls()
			if on then
				controls:Enable()
			else
				controls:Disable()
			end
		end
	end)
	if not ok then
		warn("[TreatmentController] could not toggle controls:", err)
	end
end

-- ---- skeleton ---------------------------------------------------------------------------------

function TreatmentController:_build()
	local gui = UI.new("ScreenGui", {
		Name = "TeethTreatment",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = self._player:WaitForChild("PlayerGui"),
	})
	self._gui = gui
	UI.new("TextButton", { -- dim; also swallows clicks so nothing behind is pressed
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 0,
		Parent = gui,
	})
	self._vignette = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(220, 40, 60),
		BackgroundTransparency = 0.86,
		Visible = false,
		Parent = gui,
	})

	-- the holder carries the scale so the card and its drop shadow shrink together
	local holder = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(860, 524),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local card = UI.panel({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Cream,
		Parent = holder,
	})
	self._scale = UI.new("UIScale", { Parent = holder })
	local function rescale()
		local view = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
			or Vector2.new(1280, 720)
		self._scale.Scale = math.clamp(math.min(view.X / 900, view.Y / 580), 0.4, 1.3)
	end
	rescale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end

	-- header: who is in the chair, the zombie countdown, close
	self._title = UI.label({
		Position = UDim2.fromOffset(20, 10),
		Size = UDim2.fromOffset(520, 40),
		Font = UI.Fonts.Title,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	self._zombie = UI.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -74, 0, 12),
		Size = UDim2.fromOffset(110, 38),
		BackgroundTransparency = 0,
		BackgroundColor3 = C.Pink,
		TextColor3 = C.White,
		Font = UI.Fonts.Title,
		TextSize = 24,
		Visible = false,
		Parent = card,
	})
	UI.corner(self._zombie, 5)
	UI.stroke(self._zombie, C.Ink, 2)
	UI.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 10),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = C.Coral,
		Text = "X",
		TextSize = 24,
		Parent = card,
		OnClick = function()
			self._fx:Play("click")
			if self._session then
				self._state:Send("Treat_Close", self._session.sessionId)
			end
			self:_hide()
		end,
	})

	-- what to do with the tool in your hand
	self._hint = UI.label({
		Position = UDim2.fromOffset(20, 58),
		Size = UDim2.new(1, -40, 0, 34),
		BackgroundTransparency = 0,
		BackgroundColor3 = C.Slate,
		Font = UI.Fonts.Bold,
		TextSize = 17,
		TextColor3 = C.White,
		Parent = card,
	})
	UI.corner(self._hint, 5)

	-- mouth: lips, dark inside, gums top and bottom, tongue; teeth and problems go on the stage
	local SW, SH = ToolWork.STAGE_W, ToolWork.STAGE_H
	local origin = UDim2.fromOffset((860 - SW) / 2, 104)
	local mouth = UI.new("Frame", {
		Position = origin,
		Size = UDim2.fromOffset(SW, SH),
		BackgroundColor3 = MOUTH_DARK,
		ClipsDescendants = true,
		Parent = card,
	})
	UI.new("UICorner", { CornerRadius = UDim.new(0, 40), Parent = mouth })
	UI.new("UIStroke", { Color = Color3.fromRGB(214, 70, 98), Thickness = 10, Parent = mouth })
	local tongue = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(340, 60),
		BackgroundColor3 = Color3.fromRGB(200, 84, 104),
		Parent = mouth,
	})
	UI.new("UICorner", { CornerRadius = UDim.new(0, 28), Parent = tongue })
	for _, top in { true, false } do
		local gum = UI.new("Frame", {
			AnchorPoint = Vector2.new(0.5, if top then 0 else 1),
			Position = UDim2.fromScale(0.5, if top then 0 else 1),
			Size = UDim2.new(1, -40, 0, 74),
			BackgroundColor3 = GUM,
			Parent = mouth,
		})
		UI.new("UICorner", { CornerRadius = UDim.new(0, 24), Parent = gum })
	end
	-- not clipped: a pulled tooth and the tool in your hand may leave the mouth
	self._stage = UI.new("Frame", {
		Position = origin,
		Size = UDim2.fromOffset(SW, SH),
		BackgroundTransparency = 1,
		Parent = card,
	})
	self:_buildCursors()

	-- tool tray (bottom left) and progress + submit (bottom right)
	self._toolButtons = {} :: { [string]: any }
	for i, tool in GameConfig.toolOrder do
		local button = UI.button({
			Position = UDim2.fromOffset(20 + (i - 1) * 158, 424),
			Size = UDim2.fromOffset(150, 80),
			BackgroundColor3 = C.White,
			Text = "",
			Parent = card,
			OnClick = function()
				self._fx:Play("click")
				self:_selectTool(tool)
			end,
		})
		UI.badge(button, tostring(i), C.Deep, 34, UDim2.fromOffset(4, 4))
		UI.label({
			Position = UDim2.fromOffset(42, 6),
			Size = UDim2.new(1, -48, 0, 30),
			Font = UI.Fonts.Title,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = string.upper(GameConfig.toolNames[tool]),
			Parent = button,
		})
		local level = UI.label({
			Position = UDim2.fromOffset(10, 38),
			Size = UDim2.new(1, -20, 0, 16),
			TextSize = 13,
			TextColor3 = C.Deep,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = button,
		})
		local left = UI.label({
			Position = UDim2.fromOffset(10, 56),
			Size = UDim2.new(1, -20, 0, 18),
			Font = UI.Fonts.Bold,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = button,
		})
		self._toolButtons[tool] = {
			button = button,
			stroke = button:FindFirstChildOfClass("UIStroke"),
			level = level,
			left = left,
		}
	end
	local barBack = UI.new("Frame", {
		Position = UDim2.fromOffset(660, 424),
		Size = UDim2.fromOffset(180, 26),
		BackgroundColor3 = C.Slate,
		Parent = card,
	})
	UI.corner(barBack, 5)
	UI.stroke(barBack, C.Ink, 2)
	self._barFill = UI.new(
		"Frame",
		{ Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Green, Parent = barBack }
	)
	UI.corner(self._barFill, 5)
	self._barText = UI.label({
		Size = UDim2.fromScale(1, 1),
		Font = UI.Fonts.Title,
		TextSize = 15,
		TextColor3 = C.White,
		Parent = barBack,
	})
	self._submit = UI.button({
		Position = UDim2.fromOffset(660, 456),
		Size = UDim2.fromOffset(180, 48),
		BackgroundColor3 = C.Grey,
		Text = "DONE",
		Font = UI.Fonts.Title,
		TextSize = 24,
		Parent = card,
		OnClick = function()
			self:_onSubmit()
		end,
	})

	self._result = UI.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(560, 150),
		BackgroundTransparency = 0,
		BackgroundColor3 = C.Deep,
		TextColor3 = C.White,
		Font = UI.Fonts.Title,
		TextSize = 40,
		Visible = false,
		ZIndex = 50,
		Parent = card,
	})
	UI.corner(self._result, 8)
	UI.stroke(self._result, C.Ink, 3)
end

--- The tool in your hand: a few flat shapes per tool, moved to the pointer every time it moves.
function TreatmentController:_buildCursors()
	self._cursor = UI.new("Frame", {
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 30,
		Parent = self._stage,
	})
	local function holder(tool: string, rotation: number): Frame
		return UI.new("Frame", {
			Name = tool,
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			Rotation = rotation,
			Visible = false,
			Parent = self._cursor,
		})
	end
	local function piece(parent: Frame, x: number, y: number, w: number, h: number, color: Color3)
		local f = UI.new("Frame", {
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = 30,
			Parent = parent,
		})
		UI.stroke(f, C.Ink, 2)
		return f
	end
	local brush = holder("Toothbrush", 25)
	piece(brush, -5, 6, 10, 52, C.Teal)
	piece(brush, -14, -12, 28, 18, C.White)
	piece(brush, -14, -20, 28, 8, C.Sky)
	local floss = holder("Floss", 0)
	piece(floss, -38, -1, 76, 3, C.White)
	piece(floss, -46, -10, 10, 20, C.Teal)
	piece(floss, 36, -10, 10, 20, C.Teal)
	local filler = holder("Spatula", -25)
	piece(filler, -4, 8, 8, 44, C.Slate)
	piece(filler, -10, -16, 20, 26, Color3.fromRGB(255, 236, 170))
	local pliers = holder("Pliers", 0)
	piece(pliers, -9, -6, 7, 52, C.Slate).Rotation = 10
	piece(pliers, 2, -6, 7, 52, C.Slate).Rotation = -10
	piece(pliers, -5, 8, 10, 10, C.Yellow)
end

-- ---- open / close -----------------------------------------------------------------------------

function TreatmentController:Open(payload: any)
	self._session = payload
	self._deadline = if payload.seconds then os.clock() + payload.seconds else nil
	self._down, self._grab, self._pointer = false, nil, nil
	self._queue = {}
	self._result.Visible = false
	self._cursor.Visible = false
	self._title.Text = `{string.upper(payload.rarity or "")} PATIENT`
	self._zombie.Visible = payload.rarity == "Zombie"
	self._vignette.Visible = payload.rarity == "Zombie"
	self:_buildMouth(payload)
	self._tool = ""
	self:_selectTool(self:_nextTool() or "Toothbrush")
	self:_refresh()
	self._gui.Enabled = true
	self:_setControls(false)
end

function TreatmentController:_hide()
	self._session = nil
	self._deadline = nil
	self._down, self._grab = false, nil
	if self._gui.Enabled then
		self._gui.Enabled = false
		self:_setControls(true)
	end
end

function TreatmentController:_buildMouth(payload: any)
	for _, child in self._stage:GetChildren() do
		if child ~= self._cursor then
			child:Destroy()
		end
	end
	local stage = self._stage
	local function block(
		x: number,
		y: number,
		w: number,
		h: number,
		color: Color3,
		z: number
	): Frame
		return UI.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = z,
			Parent = stage,
		})
	end

	self._teeth = {}
	for id = 1, payload.mouth.teeth do
		local x, y = ToolWork.toothCentre(id)
		local tooth = block(x, y, TW, TH, TOOTH_WHITE, 2)
		UI.corner(tooth, 8)
		UI.stroke(tooth, Color3.fromRGB(200, 206, 214), 2)
		self._teeth[id] = tooth
	end

	self._issues = {}
	for index, issue in payload.mouth.issues do
		local kind: string = issue.kind
		local cx, cy = ToolWork.centre(kind, issue.toothId)
		local upper = ToolWork.isUpper(kind, issue.toothId)
		local out = if upper then 1 else -1 -- toward the biting edge, away from the gum
		local rec: any = {
			index = index,
			kind = kind,
			tool = ToolWork.ToolFor[kind],
			cx = cx,
			cy = cy,
			upper = upper,
			done = false,
			progress = 0,
		}
		-- rec.set(p) draws progress p (0 = untouched); rec.finish(instant) draws it fixed
		if kind == "dirt" then
			local stain = block(cx, cy, TW, TH, Color3.fromRGB(226, 186, 66), 3)
			UI.corner(stain, 8)
			local specks = {}
			for d = 0, 2 do
				local speck = UI.new("Frame", {
					Position = UDim2.fromScale(0.15 + 0.28 * d, 0.2 + 0.25 * ((index + d) % 3)),
					Size = UDim2.fromOffset(9, 9),
					BackgroundColor3 = Color3.fromRGB(128, 78, 36),
					BorderSizePixel = 0,
					ZIndex = 3,
					Parent = stain,
				})
				table.insert(specks, speck)
			end
			function rec.set(p: number)
				stain.Visible = true
				stain.BackgroundTransparency = 0.1 + 0.9 * p
				for _, speck in specks do
					speck.BackgroundTransparency = p
				end
			end
			function rec.finish()
				stain.Visible = false
			end
		elseif kind == "debris" then
			local blob = block(cx, cy, 20, 30, Color3.fromRGB(120, 196, 64), 4)
			blob.Rotation = (index * 37) % 40 - 20
			UI.corner(blob, 6)
			UI.stroke(blob, Color3.fromRGB(70, 130, 36), 2)
			function rec.set(p: number)
				blob.Visible = true
				blob.BackgroundTransparency = 0
				blob.Size = UDim2.fromOffset(20 * (1 - 0.6 * p), 30 * (1 - 0.6 * p))
			end
			function rec.finish(instant: boolean?)
				if instant then
					blob.Visible = false
				else
					UI.tween(
						blob,
						0.25,
						{ Position = blob.Position + UDim2.fromOffset(0, out * 60) }
					)
					fadeOut(blob)
				end
			end
		elseif kind == "chip" then
			-- a corner broken off the biting edge; the filling appears in it as you hold
			local nx, ny = cx + TW / 2 - 6, cy + out * (TH / 2 - 4)
			local notch = block(nx, ny, 24, 24, MOUTH_DARK, 3)
			notch.Rotation = 45
			local putty = block(nx, ny, 24, 24, Color3.fromRGB(255, 236, 170), 4)
			putty.Rotation = 45
			local bar = block(cx, cy - out * (TH / 2 + 8), 0, 6, C.Yellow, 5)
			function rec.set(p: number)
				notch.Visible, putty.Visible = true, true
				putty.BackgroundTransparency = 1 - p
				bar.Visible = p > 0
				bar.Size = UDim2.fromOffset(TW * p, 6)
			end
			function rec.finish()
				notch.Visible, putty.Visible, bar.Visible = false, false, false
			end
		else -- rot: the whole tooth is bad and comes out; a clean one takes its place
			local base = self._teeth[issue.toothId]
			local bad = block(cx, cy, TW, TH, Color3.fromRGB(104, 84, 60), 3)
			UI.corner(bad, 8)
			UI.stroke(bad, Color3.fromRGB(60, 46, 34), 2)
			for d = 0, 1 do
				UI.new("Frame", {
					Position = UDim2.fromScale(0.2 + 0.35 * d, 0.25 + 0.3 * d),
					Size = UDim2.fromOffset(13, 13),
					BackgroundColor3 = Color3.fromRGB(110, 150, 60),
					BorderSizePixel = 0,
					ZIndex = 3,
					Parent = bad,
				})
			end
			function rec.set(p: number)
				base.Visible = false
				bad.Visible = true
				bad.BackgroundTransparency = 0
				bad.Position = UDim2.fromOffset(cx, cy + out * p * 70)
			end
			function rec.finish(instant: boolean?)
				base.Visible = true
				if instant then
					bad.Visible = false
				else
					UI.tween(bad, 0.3, { Position = bad.Position + UDim2.fromOffset(0, out * 80) })
					fadeOut(bad)
					base.Size = UDim2.fromOffset(TW * 0.4, TH * 0.4)
					UI.tween(base, 0.3, { Size = UDim2.fromOffset(TW, TH) }, Enum.EasingStyle.Back)
				end
			end
		end
		rec.set(0)
		if issue.cleaned then
			rec.done = true
			rec.finish(true)
		end
		table.insert(self._issues, rec)
	end
end

-- ---- tools ------------------------------------------------------------------------------------

function TreatmentController:_left(): { [string]: number }
	local left = { Toothbrush = 0, Floss = 0, Spatula = 0, Pliers = 0 }
	for _, rec in self._issues do
		if not rec.done then
			left[rec.tool] += 1
		end
	end
	return left
end

--- The first tool, in tray order, that still has work.
function TreatmentController:_nextTool(): string?
	local left = self:_left()
	for _, tool in GameConfig.toolOrder do
		if left[tool] > 0 and self._session.unlocked[tool] then
			return tool
		end
	end
	return nil
end

function TreatmentController:_selectTool(tool: string)
	local session = self._session
	if not session then
		return
	end
	if not session.unlocked[tool] then
		self._hint.Text = `{GameConfig.toolNames[tool]} unlocks with your 2nd chair.`
		return
	end
	self._tool = tool
	self._grab = nil
	self._speed = ToolWork.speed(session.levels[tool], CFG)
	self._hint.Text = HOW[tool]
	for name, _ in HOW do
		local glyph = self._cursor:FindFirstChild(name)
		if glyph then
			glyph.Visible = name == tool
		end
	end
	self:_refreshTools()
end

--- The first unfinished problem under the pointer (for one tool, or any).
function TreatmentController:_issueAt(p: Vector2, tool: string?): any
	for _, rec in self._issues do
		if
			not rec.done
			and (tool == nil or rec.tool == tool)
			and ToolWork.inReach(rec.kind, rec.cx, rec.cy, p.X, p.Y)
		then
			return rec
		end
	end
	return nil
end

function TreatmentController:_work(rec: any, delta: number)
	rec.progress = math.clamp(rec.progress + delta, 0, 1)
	rec.set(rec.progress)
	if rec.progress >= 1 then
		self:_complete(rec)
	end
end

function TreatmentController:_press(p: Vector2)
	self._down = true
	self._pointer = p
	self:_placeCursor(p)
	local mine = self:_issueAt(p, self._tool)
	if mine then
		if mine.kind == "rot" then
			self._grab = mine
		end
		return
	end
	local other = self:_issueAt(p, nil)
	if other then
		-- right spot, wrong tool: say which one and flash its button
		self._hint.Text = `That needs the {GameConfig.toolNames[other.tool]}. Pick it below.`
		self._fx:Play("warn")
		local ui = self._toolButtons[other.tool]
		ui.button.BackgroundColor3 = C.Yellow
		UI.tween(ui.button, 0.5, { BackgroundColor3 = C.White })
	end
end

function TreatmentController:_move(p: Vector2)
	local last = self._pointer
	self._pointer = p
	self:_placeCursor(p)
	if not self._down or not last then
		return
	end
	local dx, dy = p.X - last.X, p.Y - last.Y
	if self._tool == "Pliers" then
		local rec = self._grab
		if rec and not rec.done then
			self:_work(rec, ToolWork.advance("rot", rec.upper, dx, dy, 0, self._speed, CFG))
		end
	elseif self._tool == "Toothbrush" or self._tool == "Floss" then
		for _, rec in self._issues do
			if
				not rec.done
				and rec.tool == self._tool
				and ToolWork.inReach(rec.kind, rec.cx, rec.cy, p.X, p.Y)
			then
				self:_work(rec, ToolWork.advance(rec.kind, rec.upper, dx, dy, 0, self._speed, CFG))
				if rec.kind == "dirt" and math.random() < 0.2 then
					self:_bubble(p)
				end
			end
		end
	end
end

function TreatmentController:_release(touch: boolean)
	self._down = false
	local rec = self._grab
	self._grab = nil
	if rec and not rec.done then
		rec.progress = 0 -- let go too early: the tooth slips back
		rec.set(0)
	end
	if touch then
		self._pointer = nil
		self._cursor.Visible = false
	end
end

function TreatmentController:_placeCursor(p: Vector2)
	self._cursor.Position = UDim2.fromOffset(p.X, p.Y)
	self._cursor.Visible = p.X > -40
		and p.X < ToolWork.STAGE_W + 40
		and p.Y > -30
		and p.Y < ToolWork.STAGE_H + 30
end

--- A little soap bubble that floats up and fades.
function TreatmentController:_bubble(p: Vector2)
	local size = math.random(8, 16)
	local bubble = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(p.X + math.random(-20, 20), p.Y + math.random(-14, 14)),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Color3.fromRGB(200, 240, 255),
		BackgroundTransparency = 0.3,
		ZIndex = 7,
		Parent = self._stage,
	})
	UI.corner(bubble, 8)
	UI.tween(
		bubble,
		0.6,
		{ Position = bubble.Position - UDim2.fromOffset(0, 26), BackgroundTransparency = 1 }
	)
	task.delay(0.65, function()
		bubble:Destroy()
	end)
end

function TreatmentController:_complete(rec: any)
	if rec.done or not self._session then
		return
	end
	rec.done = true
	rec.finish(false)
	self._fx:Play("scrub")
	table.insert(self._queue, rec) -- sent from _tick, spaced so the server never sees them "too fast"
	if self:_left()[self._tool] == 0 then
		local nextTool = self:_nextTool()
		if nextTool then
			self:_selectTool(nextTool)
		else
			self._hint.Text = "All clean! Press DONE."
		end
	end
	self:_refresh()
end

function TreatmentController:_onFeedback(payload: any)
	if not self._session or payload.sessionId ~= self._session.sessionId then
		return
	end
	local rec = self._issues[payload.issueIndex]
	if not rec then
		return
	end
	if payload.ok then
		self._fx:Play("cash")
		local pop = UI.label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(rec.cx, rec.cy),
			Size = UDim2.fromOffset(120, 30),
			Font = UI.Fonts.Title,
			TextSize = 26,
			TextColor3 = C.Green,
			Text = `+{UI.money(payload.amount or 0)}`,
			ZIndex = 20,
			Parent = self._stage,
		})
		UI.new("UIStroke", { Thickness = 2, Color = C.Ink, Parent = pop })
		UI.tween(
			pop,
			0.9,
			{ Position = pop.Position - UDim2.fromOffset(0, 46), TextTransparency = 1 }
		)
		task.delay(0.95, function()
			pop:Destroy()
		end)
	elseif rec.done then
		-- the server said no: put the problem back so the player can try again
		rec.done, rec.progress = false, 0
		rec.set(0)
		self._hint.Text = "Hmm, that didn't count. Try again!"
		self:_refresh()
	end
end

function TreatmentController:_onSubmit()
	local session = self._session
	if not session then
		return
	end
	if #self._queue > 0 then
		return -- the last fixes are still on their way to the server
	end
	if self:_fraction() >= session.threshold then
		self._fx:Play("click")
		self._state:Send("Treat_Submit", session.sessionId)
	else
		self._hint.Text =
			`Fix at least {math.floor(session.threshold * 100)}% of the mouth before you finish.`
	end
end

function TreatmentController:_onResult(payload: any)
	if not self._session or payload.sessionId ~= self._session.sessionId then
		return
	end
	if payload.ok then
		self._fx:Play("good")
		self._result.Text = if payload.perfect
			then `PERFECT!  +{UI.money(payload.bonus)}`
			else `NICE JOB!  +{UI.money(payload.bonus)}`
		self._result.Visible = true
		self._session = nil
		task.delay(1.6, function()
			if not self._session then
				self._result.Visible = false
				self:_hide()
			end
		end)
	else
		self._hint.Text = "Not clean enough yet!"
	end
end

-- ---- readouts ---------------------------------------------------------------------------------

function TreatmentController:_fraction(): number
	local total = #self._issues
	if total == 0 then
		return 1
	end
	local done = 0
	for _, rec in self._issues do
		if rec.done then
			done += 1
		end
	end
	return done / total
end

function TreatmentController:_refreshTools()
	local session = self._session
	if not session then
		return
	end
	local left = self:_left()
	for tool, ui in self._toolButtons do
		local unlocked = session.unlocked[tool]
		local selected = tool == self._tool
		ui.level.Text = if unlocked then `Level {session.levels[tool] or 1}` else "Locked"
		ui.left.Text = if not unlocked
			then "2nd chair"
			elseif left[tool] == 0 then "Nothing to do"
			else `{left[tool]} to fix`
		ui.left.TextColor3 = if unlocked and left[tool] > 0 then C.Coral else C.Grey
		ui.stroke.Color = if selected then C.Teal else C.Ink
		ui.stroke.Thickness = if selected then 5 else 2
		ui.button.BackgroundTransparency = if unlocked then 0 else 0.5
	end
end

function TreatmentController:_refresh()
	local session = self._session
	if not session then
		return
	end
	local fraction = self:_fraction()
	UI.tween(self._barFill, 0.15, { Size = UDim2.fromScale(fraction, 1) })
	self._barText.Text = `{math.floor(fraction * 100)}% CLEAN`
	self._submit.BackgroundColor3 = if fraction >= session.threshold then C.Green else C.Grey
	self:_refreshTools()
end

function TreatmentController:_tick(dt: number)
	local session = self._session
	if not session then
		return
	end
	if self._deadline then
		self._zombie.Text = UI.clock(math.max(0, self._deadline - os.clock()))
	end
	-- the filler works by holding still on the chip
	local p = self._pointer
	if self._down and p and self._tool == "Spatula" then
		local rec = self:_issueAt(p, "Spatula")
		if rec then
			self:_work(rec, ToolWork.advance("chip", rec.upper, 0, 0, dt, self._speed, CFG))
		end
	end
	if #self._queue > 0 and os.clock() >= self._nextSend then
		local rec = table.remove(self._queue, 1)
		self._nextSend = os.clock() + SEND_GAP
		self._state:Send("Treat_Clean", session.sessionId, rec.index, rec.tool)
	end
end

return TreatmentController
