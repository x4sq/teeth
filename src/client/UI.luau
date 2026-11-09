--!strict
-- UI - the shared look: clean low-poly. Flat bold colours, hard offset shadows, bevelled buttons,
-- small corner radii (never pills or blobs), thick dark outlines and geometric badges. No emoji
-- anywhere (they render inconsistently), no images: everything is built from frames and text.

local TweenService = game:GetService("TweenService")

local UI = {}

UI.Colors = {
	Teal = Color3.fromRGB(46, 170, 181),
	Deep = Color3.fromRGB(20, 99, 110),
	Mint = Color3.fromRGB(191, 237, 227),
	Cream = Color3.fromRGB(255, 246, 229),
	White = Color3.fromRGB(247, 251, 252),
	Yellow = Color3.fromRGB(255, 200, 61),
	Coral = Color3.fromRGB(255, 122, 107),
	Slate = Color3.fromRGB(47, 62, 78),
	Green = Color3.fromRGB(76, 201, 110),
	Grey = Color3.fromRGB(170, 180, 188),
	Ink = Color3.fromRGB(27, 37, 48),
	Gold = Color3.fromRGB(233, 185, 73),
	Pink = Color3.fromRGB(226, 84, 108),
	Sky = Color3.fromRGB(110, 198, 255),
}

UI.Fonts = {
	Title = Enum.Font.GothamBlack,
	Body = Enum.Font.GothamMedium,
	Bold = Enum.Font.GothamBold,
}

local MAX_RADIUS = 8

--- Create an Instance with properties; `Parent` is applied last so nothing renders half-built.
function UI.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance: any = Instance.new(className)
	local parent = nil
	for key, value in props or {} do
		if key == "Parent" then
			parent = value
		else
			instance[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	instance.Parent = parent
	return instance
end

--- Small corners only: this is a low-poly look, so any requested radius is capped.
function UI.corner(parent: Instance, radius: number?): UICorner
	return UI.new(
		"UICorner",
		{ CornerRadius = UDim.new(0, math.min(radius or 6, MAX_RADIUS)), Parent = parent }
	)
end

--- What used to be a pill is now a lightly rounded bar.
function UI.pill(parent: Instance): UICorner
	return UI.new("UICorner", { CornerRadius = UDim.new(0, 5), Parent = parent })
end

function UI.stroke(parent: Instance, color: Color3, thickness: number?): UIStroke
	return UI.new("UIStroke", {
		Color = color,
		Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function UI.padding(parent: Instance, px: number): UIPadding
	local p = UDim.new(0, px)
	return UI.new(
		"UIPadding",
		{ PaddingLeft = p, PaddingRight = p, PaddingTop = p, PaddingBottom = p, Parent = parent }
	)
end

function UI.label(props: { [string]: any }): TextLabel
	local merged = {
		BackgroundTransparency = 1,
		Font = UI.Fonts.Body,
		TextColor3 = UI.Colors.Ink,
		TextSize = 18,
		TextWrapped = true,
		Text = "",
	}
	for k, v in props do
		merged[k] = v
	end
	return UI.new("TextLabel", merged)
end

--- A lit-from-above bevel: a light strip along the top edge and a dark one along the bottom.
local function bevel(frame: GuiObject)
	UI.new("Frame", {
		Name = "BevelLight",
		Size = UDim2.new(1, 0, 0.16, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		Active = false,
		Parent = frame,
	})
	UI.new("Frame", {
		Name = "BevelDark",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0.16, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		Active = false,
		Parent = frame,
	})
end

--- A panel: flat body, dark outline, bevel, and a hard offset shadow behind it. Returns the body.
function UI.panel(props: { [string]: any }): Frame
	local parent = props.Parent
	local position: UDim2 = props.Position or UDim2.new()
	local shadow = UI.new("Frame", {
		Name = "Shadow",
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
		Position = position + UDim2.fromOffset(4, 5),
		Size = props.Size or UDim2.fromOffset(100, 100),
		BackgroundColor3 = Color3.fromRGB(10, 18, 28),
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Visible = if props.Visible == nil then true else props.Visible,
		Parent = parent,
	})
	UI.corner(shadow, 6)
	local merged = { BackgroundColor3 = UI.Colors.White, BorderSizePixel = 0 }
	for k, v in props do
		merged[k] = v
	end
	local body: Frame = UI.new("Frame", merged)
	UI.corner(body, 6)
	UI.stroke(body, UI.Colors.Ink, 3)
	bevel(body)
	-- keep the shadow glued to the panel if it moves, resizes or hides
	local function sync()
		shadow.Position = body.Position + UDim2.fromOffset(4, 5)
		shadow.Size = body.Size
		shadow.Visible = body.Visible
	end
	body:GetPropertyChangedSignal("Position"):Connect(sync)
	body:GetPropertyChangedSignal("Size"):Connect(sync)
	body:GetPropertyChangedSignal("Visible"):Connect(sync)
	return body
end

--- A bevelled button. props.OnClick runs on activation (mouse, touch and gamepad).
function UI.button(props: { [string]: any }): TextButton
	local onClick = props.OnClick
	local merged = {
		AutoButtonColor = false,
		BackgroundColor3 = UI.Colors.Teal,
		BorderSizePixel = 0,
		Font = UI.Fonts.Bold,
		TextColor3 = UI.Colors.White,
		TextSize = 18,
		Text = "",
	}
	for k, v in props do
		if k ~= "OnClick" then
			merged[k] = v
		end
	end
	local button: TextButton = UI.new("TextButton", merged)
	UI.corner(button, 5)
	UI.stroke(button, UI.Colors.Ink, 2)
	bevel(button)
	local base = button.BackgroundColor3
	button.MouseEnter:Connect(function()
		TweenService:Create(
			button,
			TweenInfo.new(0.08),
			{ BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), 0.2) }
		):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.08), { BackgroundColor3 = base }):Play()
	end)
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

--- A badge: a diamond with a letter, used instead of icons. `size` is the holder's width.
function UI.badge(
	parent: Instance,
	letter: string,
	color: Color3,
	size: number,
	position: UDim2?
): Frame
	local holder: Frame = UI.new("Frame", {
		Size = UDim2.fromOffset(size, size),
		Position = position or UDim2.new(),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local diamond = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size * 0.72, size * 0.72),
		Rotation = 45,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = holder,
	})
	UI.stroke(diamond, UI.Colors.Ink, 2)
	UI.label({
		Size = UDim2.fromScale(1, 1),
		Font = UI.Fonts.Title,
		TextSize = math.floor(size * 0.5),
		TextColor3 = UI.Colors.White,
		Text = letter,
		Parent = holder,
	})
	return holder
end

function UI.tween(
	instance: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?
): Tween
	local tween =
		TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad), goal)
	tween:Play()
	return tween
end

--- 1234 -> "$1,234"; 1500000 -> "$1.5M".
function UI.money(n: number): string
	n = math.floor(n)
	local suffixes = { "", "K", "M", "B", "T", "Q" }
	if n >= 1e6 then
		local i = 1
		local v = n :: number
		while v >= 1000 and i < #suffixes do
			v /= 1000
			i += 1
		end
		return string.format("$%.1f%s", v, suffixes[i])
	end
	local s = tostring(n)
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return "$" .. out:gsub("^,", "")
end

--- 75 -> "1:15"
function UI.clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return UI
