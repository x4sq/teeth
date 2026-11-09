--!strict
-- TreatmentService - the server side of the mouth minigame. The server owns the Mouth and decides every
-- payout; the client only draws it and reports "I cleaned issue N with tool T". Everything the client
-- sends is validated: session ownership, index, tool, unlocked tools, and a rate limit.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local ClinicTiers = require(ReplicatedStorage.Shared.Core.ClinicTiers)
local MouthModel = require(ReplicatedStorage.Shared.Core.MouthModel)
local Payout = require(ReplicatedStorage.Shared.Core.Payout)
local RateLimit = require(ReplicatedStorage.Shared.Core.RateLimit)
local Rng = require(ReplicatedStorage.Shared.Core.Rng)

local TreatmentService = Knit.CreateService({ Name = "TreatmentService" })

type Session = {
	id: string,
	chairId: number,
	rarity: string,
	mouth: any,
	lastClean: number,
	expiresAt: number?,
	closed: boolean,
	earned: number,
}

function TreatmentService:KnitInit()
	self._sessions = {} :: { [Player]: Session }
	self._limiter = RateLimit.new(GameConfig.cleanRate.perSecond, GameConfig.cleanRate.burst)
	self._open = Net.server("Treat_Open")
	self._feedback = Net.server("Treat_Feedback")
	self._result = Net.server("Treat_Result")
	self._closed = Net.server("Treat_Closed")
	self._announce = Net.server("Announce")
	self._clean = Net.server("Treat_Clean")
	self._submit = Net.server("Treat_Submit")
	self._close = Net.server("Treat_Close")
end

function TreatmentService:HasSession(player: Player): boolean
	return self._sessions[player] ~= nil
end

local function isString(v: any, max: number): boolean
	return type(v) == "string" and #v <= max
end

function TreatmentService:_payload(player: Player, session: Session): any
	local data = Knit.GetService("DataService"):Get(player)
	local issues = {}
	for _, issue in session.mouth.issues do
		table.insert(
			issues,
			{ toothId = issue.toothId, kind = issue.kind, cleaned = issue.cleaned }
		)
	end
	return {
		sessionId = session.id,
		rarity = session.rarity,
		mouth = { teeth = session.mouth.teeth, issues = issues },
		levels = data and data.toolLevels or {},
		unlocked = {
			Toothbrush = true,
			Floss = true,
			Spatula = true,
			Pliers = data ~= nil and ClinicTiers.pliersUnlocked(data.tier, GameConfig),
		},
		seconds = if session.expiresAt then math.max(0, session.expiresAt - os.clock()) else nil,
		threshold = GameConfig.submitThreshold,
	}
end

--- Open (or resume) the treatment on `chairId`. Called by the chair's ProximityPrompt.
function TreatmentService:Begin(player: Player, chairId: number)
	local clinic = Knit.GetService("ClinicService")
	local data = Knit.GetService("DataService"):Get(player)
	local chairs = clinic:GetChairs(player)
	local chair = chairs and chairs[chairId]
	if not data or not chair then
		return
	end
	local existing = self._sessions[player]
	if existing then
		if existing.chairId == chairId and not existing.closed then
			self._open:FireClient(player, self:_payload(player, existing)) -- resume
		end
		return
	end
	if chair.state ~= "waiting" or not chair.rarity then
		return
	end

	local seed = os.time() * 7919 + player.UserId + chairId * 104729
	local session: Session = {
		id = HttpService:GenerateGUID(false),
		chairId = chairId,
		rarity = chair.rarity,
		mouth = MouthModel.generate(
			Rng.new(seed),
			seed,
			chair.rarity,
			ClinicTiers.pliersUnlocked(data.tier, GameConfig),
			GameConfig
		),
		lastClean = 0,
		expiresAt = if chair.rarity == "Zombie" then os.clock() + GameConfig.zombieSeconds else nil,
		closed = false,
		earned = 0,
	}
	self._sessions[player] = session
	clinic:SetChair(player, chairId, "treating", chair.rarity, chair.patient)
	self._open:FireClient(player, self:_payload(player, session))

	if session.expiresAt then
		task.delay(GameConfig.zombieSeconds, function()
			if self._sessions[player] == session and not session.closed then
				self:_end(player, session, false, "time")
			end
		end)
	end
end

--- Finish a session: free the chair, send the patient home, tell the client. `success` pays nothing here.
function TreatmentService:_end(player: Player, session: Session, success: boolean, reason: string?)
	if session.closed then
		return
	end
	session.closed = true
	if self._sessions[player] == session then
		self._sessions[player] = nil
	end
	if player.Parent == Players then
		Knit.GetService("PatientService"):Leave(player, session.chairId)
		if not success then
			self._closed:FireClient(player, session.id)
			if reason == "time" then
				self._announce:FireClient(
					player,
					"The patient got away! Be quicker next time.",
					"warn"
				)
			end
		end
	end
end

function TreatmentService:_clean_issue(player: Player, session: Session, index: any, tool: any)
	local data = Knit.GetService("DataService"):Get(player)
	if not data then
		return
	end
	local progress = Knit.GetService("ProgressService")
	local function reject(reason: string)
		self._feedback:FireClient(
			player,
			{ sessionId = session.id, issueIndex = index, ok = false, reason = reason }
		)
	end
	if not self._limiter:take(player, os.clock()) then
		return reject("too fast")
	end
	local now = os.clock()
	if now - session.lastClean < GameConfig.minSecondsBetweenCleans then
		return reject("too fast")
	end
	if not isString(tool, 16) or not table.find(GameConfig.toolOrder, tool) then
		return reject("unknown tool")
	end
	if tool == "Pliers" and not ClinicTiers.pliersUnlocked(data.tier, GameConfig) then
		return reject("locked tool")
	end
	local ok, why = MouthModel.clean(session.mouth, index, tool)
	if not ok then
		return reject(why or "rejected")
	end
	session.lastClean = now
	local issue = session.mouth.issues[index]
	local amount = Payout.perIssue(issue.kind, data.toolLevels[tool], session.rarity, GameConfig)
		* progress:GetMultiplier(player)
	session.earned += amount
	progress:AddCash(player, amount)
	if issue.kind == "chip" then
		progress:Record(player, { kind = "chip" })
	end
	self._feedback:FireClient(
		player,
		{ sessionId = session.id, issueIndex = index, ok = true, amount = amount }
	)
end

function TreatmentService:_submit_session(player: Player, session: Session, free: boolean?)
	local data = Knit.GetService("DataService"):Get(player)
	if not data or session.closed then
		return
	end
	local progress = Knit.GetService("ProgressService")
	if not MouthModel.canSubmit(session.mouth, GameConfig.submitThreshold) then
		self._result:FireClient(
			player,
			{ sessionId = session.id, ok = false, reason = "not clean enough" }
		)
		return
	end
	local perfect = MouthModel.cleanedFraction(session.mouth) >= 1
	local bonus = Payout.submit(session.mouth, session.rarity, perfect, GameConfig)
		* progress:GetMultiplier(player)
	if free then
		bonus *= 2
	end
	progress:AddCash(player, bonus)
	data.treated += 1
	progress:Record(player, { kind = "treated", rarity = session.rarity })
	self._result:FireClient(
		player,
		{ sessionId = session.id, ok = true, bonus = bonus, perfect = perfect }
	)
	self:_end(player, session, true, nil)
	progress:MarkDirty(player)
end

--- Robux "Instant Clean": every remaining issue is fixed and paid at double, then the treatment submits.
function TreatmentService:InstantFinish(player: Player): boolean
	local session = self._sessions[player]
	local data = Knit.GetService("DataService"):Get(player)
	if not session or session.closed or not data then
		return false
	end
	local progress = Knit.GetService("ProgressService")
	for index, issue in session.mouth.issues do
		if not issue.cleaned then
			issue.cleaned = true
			local tool = MouthModel.ToolFor[issue.kind]
			local amount = Payout.perIssue(
				issue.kind,
				data.toolLevels[tool],
				session.rarity,
				GameConfig
			) * 2 * progress:GetMultiplier(player)
			progress:AddCash(player, amount)
			if issue.kind == "chip" then
				progress:Record(player, { kind = "chip" })
			end
			self._feedback:FireClient(
				player,
				{ sessionId = session.id, issueIndex = index, ok = true, amount = amount }
			)
		end
	end
	self:_submit_session(player, session, true)
	return true
end

function TreatmentService:KnitStart()
	self._clean.OnServerEvent:Connect(function(player, sessionId, index, tool)
		local session = self._sessions[player]
		if
			session
			and not session.closed
			and isString(sessionId, 64)
			and sessionId == session.id
		then
			self:_clean_issue(player, session, index, tool)
		end
	end)
	self._submit.OnServerEvent:Connect(function(player, sessionId)
		local session = self._sessions[player]
		if
			session
			and not session.closed
			and isString(sessionId, 64)
			and sessionId == session.id
		then
			self:_submit_session(player, session, false)
		end
	end)
	self._close.OnServerEvent:Connect(function() end) -- the session stays open on its chair; the prompt resumes it

	local function abandon(player: Player)
		local session = self._sessions[player]
		self._sessions[player] = nil
		self._limiter:forget(player)
		if session then
			session.closed = true
		end
	end
	Knit.GetService("DataService").Leaving:Connect(abandon)
	-- a rebuilt clinic or released plot has no chairs any more: drop the session without paying
	Knit.GetService("ClinicService").Rebuilt:Connect(abandon)
	Knit.GetService("PlotService").Released:Connect(abandon)
end

return TreatmentService
