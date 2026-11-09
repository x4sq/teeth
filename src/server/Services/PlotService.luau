--!strict
-- PlotService - gives each player one of the plots in Workspace.World.Plots and puts them on it.
--
-- A plot is a Model "PlotN" with an `Origin` part (the clinic's front-door line, +Z toward the plaza)
-- and a `Spawn` part. Ownership lives in the plot's `OwnerId` attribute (0 = free).
-- More players than plots: the extras wait in a queue and are given a plot the moment one frees up.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Net = require(ReplicatedStorage.Shared.Net)

local PlotService = Knit.CreateService({ Name = "PlotService" })

function PlotService:KnitInit()
	self.Assigned = Signal.new() -- (player, plot)
	self.Released = Signal.new() -- (player, plot)
	self._plots = {} :: { Model }
	self._owner = {} :: { [Player]: Model }
	self._waiting = {} :: { Player }
	self._announce = Net.server("Announce")
end

function PlotService:Get(player: Player): Model?
	return self._owner[player]
end

local function moveToSpawn(player: Player, plot: Model)
	local character = player.Character
	local spawn = plot:FindFirstChild("Spawn")
	if character and spawn and spawn:IsA("BasePart") then
		character:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
	end
end

--- Give `player` a free plot (or queue them). Safe to call twice.
function PlotService:Assign(player: Player): Model?
	if self._owner[player] then
		return self._owner[player]
	end
	if player.Parent ~= Players then
		return nil
	end
	for _, plot in self._plots do
		local owner = plot:GetAttribute("OwnerId")
		if owner == nil or owner == 0 then
			plot:SetAttribute("OwnerId", player.UserId)
			plot:SetAttribute("OwnerName", player.DisplayName)
			self._owner[player] = plot
			moveToSpawn(player, plot)
			self.Assigned:Fire(player, plot)
			return plot
		end
	end
	if not table.find(self._waiting, player) then
		table.insert(self._waiting, player)
		self._announce:FireClient(
			player,
			"All clinics are busy. You'll get one as soon as a spot opens up!",
			"info"
		)
	end
	return nil
end

function PlotService:Release(player: Player)
	local queued = table.find(self._waiting, player)
	if queued then
		table.remove(self._waiting, queued)
	end
	local plot = self._owner[player]
	if not plot then
		return
	end
	self._owner[player] = nil
	plot:SetAttribute("OwnerId", 0)
	plot:SetAttribute("OwnerName", "")
	self.Released:Fire(player, plot)
	while #self._waiting > 0 do
		local nextPlayer = table.remove(self._waiting, 1) :: Player
		if nextPlayer.Parent == Players and self:Get(nextPlayer) == nil then
			if Knit.GetService("DataService"):Get(nextPlayer) ~= nil then
				self:Assign(nextPlayer)
				break
			end
		end
	end
end

function PlotService:KnitStart()
	local world = workspace:WaitForChild("World", 30)
	local plots = world and world:FindFirstChild("Plots")
	if not plots then
		warn("[PlotService] Workspace.World.Plots is missing - no clinics can be built")
		return
	end
	for _, plot in plots:GetChildren() do
		if plot:IsA("Model") and plot:FindFirstChild("Origin") then
			plot:SetAttribute("OwnerId", 0)
			table.insert(self._plots, plot)
		end
	end
	table.sort(self._plots, function(a, b)
		return a.Name < b.Name
	end)

	local data = Knit.GetService("DataService")
	data.Loaded:Connect(function(player)
		self:Assign(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:Release(player)
	end)
	-- respawns put the character back on the owner's plot
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			local plot = self._owner[player]
			if plot then
				task.defer(moveToSpawn, player, plot)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
		if data:Get(player) then
			self:Assign(player)
		end
	end
end

return PlotService
