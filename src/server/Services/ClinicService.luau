--!strict
-- ClinicService - builds a player's clinic on their plot from the tier templates in
-- ServerStorage.Templates.Tiers, applies their colours (TintSlot attributes) and decor (slot
-- attachments), owns the chairs, and handles expansion and customization requests.
--
-- Chair state machine (one table per chair): "empty" -> "arriving" -> "waiting" -> "treating" -> "empty".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local ClinicTiers = require(ReplicatedStorage.Shared.Core.ClinicTiers)
local Customize = require(ReplicatedStorage.Shared.Core.Customize)
local RateLimit = require(ReplicatedStorage.Shared.Core.RateLimit)

local ClinicService = Knit.CreateService({ Name = "ClinicService" })

-- template TintSlot names that follow another colour slot
local SLOT_ALIAS: { [string]: string } = { Sill = "Wall", Lintel = "Wall", Floor2 = "Floor" }
-- aliased slots drawn slightly darker than their source colour (the checker floor's second tile)
local SLOT_DARKEN: { [string]: number } = { Floor2 = 0.07 }

export type Chair = {
	id: number,
	cf: CFrame,
	state: string,
	rarity: string?,
	patient: Model?,
	prompt: ProximityPrompt,
}

function ClinicService:KnitInit()
	self.Rebuilt = Signal.new() -- (player) the clinic model was replaced; chairs are fresh and empty
	self._clinics = {} :: { [Player]: { model: Model, plot: Model, chairs: { Chair } } }
	self._limiter = RateLimit.new(2, 4)
	self._chairsRemote = Net.server("Chairs_Sync")
	self._expandRemote = Net.server("Clinic_Expand")
	self._customizeRemote = Net.server("Clinic_Customize")
end

-- ---- appearance -------------------------------------------------------------------------------

local function applyTints(root: Instance, colors: { [string]: string })
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			local slot = d:GetAttribute("TintSlot")
			if type(slot) == "string" then
				local hex = colors[SLOT_ALIAS[slot] or slot]
				if hex then
					local ok, color = pcall(Color3.fromHex, hex)
					if ok then
						d.Color = color:Lerp(Color3.new(), SLOT_DARKEN[slot] or 0)
					end
				end
			end
		end
	end
end

function ClinicService:_applyDecor(
	clinic: { model: Model },
	decor: { [string]: string },
	colors: { [string]: string }
)
	local model = clinic.model
	local old = model:FindFirstChild("Decor")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Decor"
	folder.Parent = model
	local templates = ServerStorage:FindFirstChild("Templates")
	local library = templates and templates:FindFirstChild("Decor")
	local slots = model.PrimaryPart
	if not library or not slots then
		return
	end
	for slotName, id in decor do
		local template = library:FindFirstChild(id)
		local attachment = slots:FindFirstChild(slotName)
		if template and attachment and attachment:IsA("Attachment") then
			local item = template:Clone()
			item.Name = `{slotName}_{id}`
			item:PivotTo(attachment.WorldCFrame)
			item.Parent = folder
			applyTints(item, colors)
		end
	end
end

function ClinicService:_setSign(model: Model, owner: Player)
	local sign = model:FindFirstChild("ClinicSign")
	local label = sign and sign:FindFirstChild("Title", true)
	if label and label:IsA("TextLabel") then
		label.Text = string.upper(string.sub(`{owner.DisplayName}'s Dental`, 1, 22))
	end
end

-- ---- chairs -----------------------------------------------------------------------------------

function ClinicService:GetChairs(player: Player): { Chair }?
	local clinic = self._clinics[player]
	return clinic and clinic.chairs
end

function ClinicService:GetClinic(player: Player): Model?
	local clinic = self._clinics[player]
	return clinic and clinic.model
end

function ClinicService:_syncChairs(player: Player)
	local clinic = self._clinics[player]
	if not clinic then
		return
	end
	local list = {}
	for _, chair in clinic.chairs do
		table.insert(list, { id = chair.id, state = chair.state, rarity = chair.rarity })
	end
	self._chairsRemote:FireClient(player, list)
end

--- Change a chair's state; the prompt is only usable while a patient is waiting or being treated.
function ClinicService:SetChair(
	player: Player,
	chairId: number,
	state: string,
	rarity: string?,
	patient: Model?
)
	local chairs = self:GetChairs(player)
	local chair = chairs and chairs[chairId]
	if not chair then
		return
	end
	chair.state, chair.rarity, chair.patient = state, rarity, patient
	chair.prompt.Enabled = state == "waiting" or state == "treating"
	chair.prompt.ActionText = if state == "treating"
		then "Continue treatment"
		else `Treat {string.lower(rarity or "patient")}`
	self:_syncChairs(player)
end

-- ---- build / destroy --------------------------------------------------------------------------

function ClinicService:_destroy(player: Player)
	local clinic = self._clinics[player]
	if clinic then
		self._clinics[player] = nil
		clinic.model:Destroy()
	end
end

function ClinicService:Build(player: Player)
	local data = Knit.GetService("DataService"):Get(player)
	local plot = Knit.GetService("PlotService"):Get(player)
	if not data or not plot then
		return
	end
	self:_destroy(player)

	local tiers = ServerStorage:FindFirstChild("Templates")
		and ServerStorage.Templates:FindFirstChild("Tiers")
	local template = tiers and tiers:FindFirstChild("Tier" .. data.tier)
	local origin = plot:FindFirstChild("Origin")
	if not template or not origin or not origin:IsA("BasePart") then
		warn(
			`[ClinicService] missing Tier{data.tier} template or plot Origin - cannot build a clinic`
		)
		return
	end

	local model = template:Clone()
	model.Name = "Clinic"
	model:PivotTo(origin.CFrame)
	model.Parent = plot
	local slots = model.PrimaryPart :: BasePart

	applyTints(model, data.customize.colors)
	local clinic = { model = model, plot = plot, chairs = {} :: { Chair } }
	self:_applyDecor(clinic, data.customize.decor, data.customize.colors)
	self:_setSign(model, player)

	for i = 1, model:GetAttribute("Chairs") :: number do
		local attachment = slots:FindFirstChild("ChairSlot" .. i)
		if attachment and attachment:IsA("Attachment") then
			local cf = attachment.WorldCFrame
			local trigger = Instance.new("Part")
			trigger.Name = "ChairTrigger" .. i
			trigger.Size = Vector3.new(8, 6, 9)
			trigger.CFrame = cf * CFrame.new(0, 3, 0)
			trigger.Anchored, trigger.CanCollide, trigger.CanTouch, trigger.Transparency =
				true, false, false, 1
			trigger.Parent = model
			local prompt = Instance.new("ProximityPrompt")
			prompt.ObjectText = "Dental chair"
			prompt.ActionText = "Treat patient"
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 14
			prompt.RequiresLineOfSight = false
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.Enabled = false
			prompt.Parent = trigger
			prompt.Triggered:Connect(function(who: Player)
				if who == player then
					Knit.GetService("TreatmentService"):Begin(player, i)
				end
			end)
			table.insert(clinic.chairs, {
				id = i,
				cf = cf,
				state = "empty",
				rarity = nil,
				patient = nil,
				prompt = prompt,
			})
		end
	end

	self._clinics[player] = clinic
	self.Rebuilt:Fire(player)
	self:_syncChairs(player)
end

-- ---- requests ---------------------------------------------------------------------------------

function ClinicService:Expand(player: Player)
	local progress = Knit.GetService("ProgressService")
	local data = Knit.GetService("DataService"):Get(player)
	if not data then
		return
	end
	local ok, why = ClinicTiers.canExpand(data, GameConfig)
	if not ok then
		progress:Announce(
			player,
			if why == "max tier"
				then "Your clinic is already the biggest it can be!"
				else "Not enough cash to expand yet.",
			"warn"
		)
		return
	end
	if Knit.GetService("TreatmentService"):HasSession(player) then
		progress:Announce(player, "Finish your current treatment before expanding.", "warn")
		return
	end
	local nextTier = GameConfig.tiers[data.tier + 1]
	if not progress:SpendCash(player, nextTier.cost) then
		return
	end
	data.tier += 1
	self:Build(player)
	progress:Record(player, { kind = "expand", tier = data.tier })
	progress:Announce(player, `Your clinic grew into a {nextTier.name}!`, "good")
	progress:MarkDirty(player)
end

function ClinicService:Customize(player: Player, payload: any)
	local progress = Knit.GetService("ProgressService")
	local data = Knit.GetService("DataService"):Get(player)
	local clinic = self._clinics[player]
	if not data or not clinic then
		return
	end
	local custom = data.customize
	local valid, why = Customize.validate(payload, custom.owned, GameConfig)
	if not valid then
		warn(`[ClinicService] rejected customization from {player.Name}: {why}`)
		return
	end
	local ids, cost = Customize.purchases(payload, custom.owned, GameConfig)
	if cost > 0 and not progress:SpendCash(player, cost) then
		progress:Announce(player, "Not enough cash for those items.", "warn")
		return
	end
	for _, id in ids do
		custom.owned[id] = true
	end
	for slot, hex in payload.colors or {} do
		custom.colors[slot] = string.upper(hex)
	end
	for slot, id in payload.decor or {} do
		custom.decor[slot] = if id == "" then nil else id
	end
	applyTints(clinic.model, custom.colors)
	self:_applyDecor(clinic, custom.decor, custom.colors)
	progress:Record(player, { kind = "customize" })
	progress:MarkDirty(player)
end

function ClinicService:KnitStart()
	local plots = Knit.GetService("PlotService")
	plots.Assigned:Connect(function(player)
		self:Build(player)
	end)
	plots.Released:Connect(function(player)
		self:_destroy(player)
	end)
	self._expandRemote.OnServerEvent:Connect(function(player)
		if self._limiter:take(player, os.clock()) then
			self:Expand(player)
		end
	end)
	self._customizeRemote.OnServerEvent:Connect(function(player, payload)
		if self._limiter:take(player, os.clock()) then
			self:Customize(player, payload)
		end
	end)
	Knit.GetService("DataService").Leaving:Connect(function(player)
		self._limiter:forget(player)
	end)
end

return ClinicService
