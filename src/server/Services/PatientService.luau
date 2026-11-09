--!strict
-- PatientService - the patient lifecycle for every clinic: a spawn timer, an NPC that walks in to the
-- reception line, is seated on a free chair, waits to be treated, and finally walks out again.
--
-- Patients are plain Roblox avatars dressed by Looks. They walk door -> reception line, then are placed
-- on the chair (the rows of stations are too tightly packed to path between reliably).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Looks = require(ReplicatedStorage.Shared.Config.Looks)
local Net = require(ReplicatedStorage.Shared.Net)
local PatientTable = require(ReplicatedStorage.Shared.Core.PatientTable)
local Rng = require(ReplicatedStorage.Shared.Core.Rng)

local PatientService = Knit.CreateService({ Name = "PatientService" })

-- tier-local positions (the clinic model's origin is the front-door line; +Z is the street)
local SPAWN_POINT = Vector3.new(0, 3.5, 16)
local DOOR_POINT = Vector3.new(0, 3.5, 1.5)
local RECEPTION_POINT = Vector3.new(0, 3.5, -8)
-- patient root pose on a chair, in chair space (reclined along the backrest)
local LIE_OFFSET = CFrame.new(0, 4.4, 1.9) * CFrame.Angles(math.rad(58), 0, 0)

function PatientService:KnitInit()
	self._timer = Net.server("Spawn_Timer")
	self._announce = Net.server("Announce")
	self._token = {} :: { [Player]: number }
	self._patients = {} :: { [Player]: { [Model]: boolean } }
	local folder = workspace:FindFirstChild("Patients") or Instance.new("Folder")
	folder.Name = "Patients"
	folder.Parent = workspace
	self._folder = folder
end

local function walkTo(humanoid: Humanoid, target: Vector3, timeout: number): boolean
	humanoid:MoveTo(target)
	local finished = false
	local connection = humanoid.MoveToFinished:Connect(function()
		finished = true
	end)
	local started = os.clock()
	while not finished and os.clock() - started < timeout do
		task.wait(0.1)
	end
	connection:Disconnect()
	return finished
end

local function addNameTag(patient: Model, rarity: string)
	local head = patient:FindFirstChild("Head")
	local look = Looks.ByRarity[rarity]
	if not head or not look then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Size = UDim2.fromOffset(190, 54)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.MaxDistance = 90
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = look.nameTag
	label.TextStrokeTransparency = 0.3
	label.Text = `{look.label}\nx{GameConfig.rarityMultiplier[rarity]} Cash`
	label.Parent = gui
end

function PatientService:_track(player: Player, patient: Model)
	local set = self._patients[player]
	if not set then
		set = {}
		self._patients[player] = set
	end
	set[patient] = true
end

--- Remove every patient belonging to `player` (clinic rebuilt, plot released, player left).
function PatientService:Clear(player: Player)
	local set = self._patients[player]
	self._patients[player] = nil
	if set then
		for patient in set do
			patient:Destroy()
		end
	end
end

function PatientService:_createPatient(rarity: string, rng: any): Model?
	local ok, patient = pcall(function()
		return Players:CreateHumanoidModelFromDescription(
			Looks.describe(rarity, rng),
			Enum.HumanoidRigType.R15
		)
	end)
	if not ok or not patient then
		warn(`[PatientService] could not create a patient avatar: {patient}`)
		return nil
	end
	patient.Name = "Patient"
	local humanoid = patient:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = GameConfig.walkSpeed
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	addNameTag(patient, rarity)
	return patient
end

function PatientService:_deliver(player: Player, chairId: number, rarity: string, rng: any)
	local clinicService = Knit.GetService("ClinicService")
	local clinic = clinicService:GetClinic(player)
	local patient = self:_createPatient(rarity, rng)
	-- the world may have changed while the avatar loaded
	if not patient or clinicService:GetClinic(player) ~= clinic or clinic == nil then
		if patient then
			patient:Destroy()
		end
		clinicService:SetChair(player, chairId, "empty")
		return
	end
	local pivot = clinic:GetPivot()
	local function at(localPos: Vector3): Vector3
		return pivot:PointToWorldSpace(localPos)
	end

	patient:PivotTo(CFrame.new(at(SPAWN_POINT)))
	patient.Parent = self._folder
	self:_track(player, patient)
	local humanoid = patient:FindFirstChildOfClass("Humanoid")
	local root = patient:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		patient:Destroy()
		clinicService:SetChair(player, chairId, "empty")
		return
	end

	for _, point in { DOOR_POINT, RECEPTION_POINT } do
		if patient.Parent == nil then
			return
		end
		if not walkTo(humanoid, at(point), 8) and patient.Parent then
			patient:PivotTo(CFrame.new(at(point)))
		end
	end
	if patient.Parent == nil or clinicService:GetClinic(player) ~= clinic then
		return
	end

	-- lie down on the chair
	local chairs = clinicService:GetChairs(player)
	local chair = chairs and chairs[chairId]
	if not chair then
		patient:Destroy()
		return
	end
	humanoid.PlatformStand = true
	root.Anchored = true
	patient:PivotTo(chair.cf * LIE_OFFSET)
	clinicService:SetChair(player, chairId, "waiting", rarity, patient)

	-- a patient nobody treats eventually gives up
	task.delay(GameConfig.patientWaitSeconds, function()
		local current = clinicService:GetChairs(player)
		local c = current and current[chairId]
		if c and c.patient == patient and c.state == "waiting" then
			self:Leave(player, chairId)
		end
	end)
end

--- The patient on `chairId` gets up and walks out; the chair is free immediately.
function PatientService:Leave(player: Player, chairId: number)
	local clinicService = Knit.GetService("ClinicService")
	local clinic = clinicService:GetClinic(player)
	local chairs = clinicService:GetChairs(player)
	local chair = chairs and chairs[chairId]
	if not chair then
		return
	end
	local patient = chair.patient
	clinicService:SetChair(player, chairId, "empty")
	if not patient or patient.Parent == nil or not clinic then
		return
	end
	local humanoid = patient:FindFirstChildOfClass("Humanoid")
	local root = patient:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		patient:Destroy()
		return
	end
	local pivot = clinic:GetPivot()
	root.Anchored = false
	humanoid.PlatformStand = false
	patient:PivotTo(CFrame.new(pivot:PointToWorldSpace(RECEPTION_POINT)))
	Debris:AddItem(patient, 14)
	task.spawn(function()
		for _, point in { DOOR_POINT, SPAWN_POINT } do
			if patient.Parent == nil then
				return
			end
			walkTo(humanoid, pivot:PointToWorldSpace(point), 6)
		end
	end)
end

function PatientService:_run(player: Player)
	local token = (self._token[player] or 0) + 1
	self._token[player] = token
	task.spawn(function()
		local rng = Rng.new(os.time() + player.UserId)
		local dataService = Knit.GetService("DataService")
		local clinicService = Knit.GetService("ClinicService")
		while self._token[player] == token and player.Parent == Players do
			local data = dataService:Get(player)
			if not data then
				return
			end
			for remaining = PatientTable.spawnDelay(data.tier, GameConfig), 1, -1 do
				if self._token[player] ~= token then
					return
				end
				self._timer:FireClient(player, remaining)
				task.wait(1)
			end
			if self._token[player] ~= token then
				return
			end
			local chairs = clinicService:GetChairs(player)
			local free
			for _, chair in chairs or {} do
				if chair.state == "empty" then
					free = chair
					break
				end
			end
			if free then
				local rarity = PatientTable.roll(rng, math.min(1, data.tier * 0.15), GameConfig)
				clinicService:SetChair(player, free.id, "arriving", rarity, nil)
				if rarity ~= "Common" then
					self._announce:FireAllClients(
						`A {string.upper(rarity)} PATIENT IS HEADING TO {string.upper(
							player.DisplayName
						)}'S CLINIC!`,
						"alert"
					)
				end
				task.spawn(function()
					self:_deliver(player, free.id, rarity, rng)
				end)
			end
		end
	end)
end

function PatientService:KnitStart()
	local clinicService = Knit.GetService("ClinicService")
	clinicService.Rebuilt:Connect(function(player)
		self:Clear(player)
		self:_run(player)
	end)
	Knit.GetService("PlotService").Released:Connect(function(player)
		self._token[player] = (self._token[player] or 0) + 1
		self:Clear(player)
	end)
	Knit.GetService("DataService").Leaving:Connect(function(player)
		self._token[player] = (self._token[player] or 0) + 1
		self:Clear(player)
	end)
end

return PatientService
