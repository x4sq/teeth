-- Studio command-bar / MCP execute_luau script (Edit DataModel). NOT part of the Rojo build.
-- Rebuilds ServerStorage.Templates.Tiers.Tier0..3 from the repaired low-poly kit (see repair_lowpoly.luau).
-- Keeps each tier's `Slots` PrimaryPart (ChairSlotN / DecorFloorN / DecorWallN / QueueN / DoorEntry /
-- PatientSpawn attachments), its attributes and its `ClinicSign`; everything else is replaced by the
-- Shell mesh, the props at their previous placements, a rug, and invisible collider Parts (the shell
-- meshes do not collide, otherwise their box collision would fill the whole building).
-- Frame: origin = centre of the front-door line at floor level, street at +Z, floor top y = 0.2.
local TS = game:GetService("ServerStorage").Templates
local P, K = TS.Props, TS.Kit
local DEFS = { [0] = { xr = 14, D = 24 }, { xr = 26, D = 24 }, { xr = 38, D = 36 }, { xr = 44, D = 44 } }
local ROLE = { Chair = "DentalChair", Tray = "InstrumentTray", Lamp = "DentalLamp", Sink = "SinkCabinet", Sterilizer = "Sterilizer",
	ReceptionDesk = "ReceptionDesk", WaitingChair = "WaitingChair", XRay = "XRayMachine", RoofMascot = "ToothSign" }
local V = Vector3.new
-- attachments moved clear of windows (wall decor) and columns (queue)
local MOVE = {
	[0] = { DecorWall1 = V(13.5, 6.5, -4.5), DecorWall2 = V(13.5, 6.5, -19.5), DecorWall3 = V(-2.5, 6.5, -23.5), DecorWall4 = V(-13.5, 6.5, -19.5) },
	[1] = { DecorWall1 = V(25.5, 6.5, -4.5), DecorWall2 = V(25.5, 6.5, -19.5), DecorWall4 = V(-25.5, 6.5, -19.5) },
	[2] = { DecorWall3 = V(15, 6.5, -35.5), DecorWall4 = V(-37.5, 6.5, -28), DecorFloor3 = V(12, 0.2, -34.2) },
	[3] = { DecorWall3 = V(29, 6.5, -43.5), DecorWall4 = V(-43.5, 6.5, -31) },
}

for _, d in P.DentalLamp:GetDescendants() do -- lamp: light on the glow, collision on the base only
	if d:IsA("MeshPart") then
		d.CanCollide = (d.Position.Y - d.Size.Y / 2) < P.DentalLamp:GetPivot().Position.Y + 0.6
		if d:GetAttribute("TintSlot") == "Glow" and not d:FindFirstChildOfClass("PointLight") then
			local l = Instance.new("PointLight")
			l.Brightness = 0.9; l.Range = 12; l.Color = Color3.fromRGB(255, 244, 214); l.Shadows = false
			l.Parent = d
		end
	end
end

local function collider(parent, name, size, pos)
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.Position = pos
	p.Anchored = true; p.CanCollide = true; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false; p.Transparency = 1
	p.Parent = parent
end

for t = 0, 3 do
	local tier = TS.Tiers["Tier" .. t]
	local xr, D = DEFS[t].xr, DEFS[t].D
	local placed = {}
	for _, c in tier:GetChildren() do
		if c:IsA("Model") then
			table.insert(placed, { name = c.Name, role = c.Name:gsub("%d+$", ""), cf = c:GetPivot() })
			c:Destroy()
		elseif c.Name ~= "Slots" and c.Name ~= "ClinicSign" then
			c:Destroy()
		end
	end
	local shell = K["Shell" .. t]:Clone()
	shell.Name = "Shell"
	shell:PivotTo(CFrame.new(0, -0.2, 0)) -- the mesh floor starts at its own y = 0; the design floor is centred on 0
	shell.Parent = tier
	for _, it in placed do
		local src = P:FindFirstChild(ROLE[it.role] or "")
		if src then
			local clone = src:Clone()
			clone.Name = it.name
			local cf = it.cf
			if it.role == "WaitingChair" then cf = CFrame.new(cf.X, 0.2, cf.Z) end
			if it.role == "RoofMascot" then cf = CFrame.new(0, 29.5, -6.5) * CFrame.Angles(0, math.pi, 0) end
			clone:PivotTo(cf)
			clone.Parent = tier
		else
			warn("no template for", it.name)
		end
	end
	local rug = K.RugRunner:Clone()
	rug.Name = "Rug"; rug:PivotTo(CFrame.new(0, 0.2, -6)); rug.Parent = tier
	local col = Instance.new("Folder"); col.Name = "Colliders"; col.Parent = tier
	collider(col, "Floor", V(2 * xr, 0.4, D), V(0, 0, -D / 2))
	collider(col, "BackWall", V(2 * xr + 1, 11.8, 1), V(0, 6.1, -D))
	for _, sx in { -xr, xr } do collider(col, "SideWall", V(1, 11.8, D), V(sx, 6.1, -D / 2)) end
	for _, s in { -1, 1 } do collider(col, "FrontWall", V(xr - 3.5, 11.8, 1), V(s * (xr + 3.5) / 2, 6.1, 0)) end -- 7 wide doorway
	if t >= 2 then
		collider(col, "PartitionA", V(1, 11.8, D - 22.5), V(-26, 6.1, -(D + 22.5) / 2)) -- X-ray room, door at z -22.5..-17.5
		collider(col, "PartitionB", V(1, 11.8, 3.5), V(-26, 6.1, -15.75))
		for _, cx in { -6.5, 6.5 } do collider(col, "Column", V(1.8, 9, 1.8), V(cx, 4.7, 5.2)) end
	end
	tier.ClinicSign.Size = V(10, 2.2, 0.2) -- sits on the shell's sign frame
	tier.ClinicSign.Position = V(0, 11.5, 1.05)
	for name, pos in MOVE[t] do
		local a = tier.Slots:FindFirstChild(name)
		if a then a.WorldPosition = pos end
	end
	if t >= 2 then
		for i, x in { -5, -2, 1, 4 } do tier.Slots["Queue" .. i].WorldPosition = V(x, 0.2, 5) end
	end
end
-- afterwards: Tier2/3 Sterilizer2 was nudged to x -35.5 (z -34.2 / -42.2) to clear the west wall
