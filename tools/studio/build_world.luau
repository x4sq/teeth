-- Studio command-bar / MCP execute_luau script (Edit DataModel). NOT part of the Rojo build.
-- Rebuilds Workspace.World's scenery from the repaired low-poly kit (see repair_lowpoly.luau).
-- Polar layout: the six plots sit at angles 0, 60 ... 300 degrees (radius 130, their paths run to the plaza);
-- everything else goes in the six sectors between them (centres 30, 90 ... 330 degrees).
-- Plots keep only their `Origin` and `Spawn` parts (PlotService needs those); all scenery is replaced.
local TS = game:GetService("ServerStorage").Templates
local K = TS.Kit
local W = workspace.World
local V = Vector3.new

for _, d in K.Hedge26:GetDescendants() do if d:IsA("MeshPart") then d.CanCollide = true end end
for _, name in { "PlazaCore", "FountainRing" } do -- round discs: hull collision, not the square box
	for _, d in K[name]:GetDescendants() do
		if d:IsA("MeshPart") then
			local s = d:GetAttribute("TintSlot")
			if s == "Spoke" then
				d.CanCollide = false
			elseif s and (s:sub(1, 4) == "Ring" or s == "Stone" or s == "StoneDark") then
				d.CollisionFidelity = Enum.CollisionFidelity.Hull
			end
		end
	end
end
for _, d in K.StreetLamp:GetDescendants() do
	if d:IsA("MeshPart") and d:GetAttribute("TintSlot") == "Glow" and not d:FindFirstChildOfClass("PointLight") then
		local l = Instance.new("PointLight")
		l.Brightness = 1.2; l.Range = 26; l.Color = Color3.fromRGB(255, 232, 180); l.Shadows = false
		l.Parent = d
	end
end

local function place(template, cf, parent, name)
	local m = template:Clone()
	m.Name = name or template.Name
	m:PivotTo(cf)
	m.Parent = parent
	return m
end
local function polar(r, deg, y)
	local a = math.rad(deg)
	return V(r * math.cos(a), y, r * math.sin(a))
end
local function faceCentre(pos) return CFrame.lookAt(pos, V(0, pos.Y, 0)) end -- model front is -Z
local function invisible(parent, name, size, pos)
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.Position = pos
	p.Anchored = true; p.CanCollide = true; p.CanQuery = false; p.CanTouch = false; p.Transparency = 1
	p.Parent = parent
end

-- plaza (the four SpawnLocations are kept, made invisible and lowered onto the paving)
local oldPlaza = W.Plaza
local plaza = Instance.new("Folder"); plaza.Name = "PlazaNew"; plaza.Parent = W
for i = 1, 4 do
	local sp = oldPlaza:FindFirstChild("PlazaSpawn" .. i)
	if sp then
		for _, c in sp:GetChildren() do if c:IsA("Decal") or c:IsA("Texture") then c:Destroy() end end
		sp.Size = V(8, 0.2, 8); sp.Position = V(sp.Position.X, 0.7, sp.Position.Z)
		sp.Transparency = 1; sp.CanCollide = false; sp.Parent = plaza
	end
end
oldPlaza:Destroy()
plaza.Name = "Plaza"
place(K.PlazaCore, CFrame.new(0, 0, 0), plaza)
place(K.FountainRing, CFrame.new(0, 0, 0), plaza)
for k = 0, 5 do
	local sector = 30 + 60 * k
	place(K.StreetLamp, faceCentre(polar(64, sector, 0.6)), plaza, "Lamp" .. k)
	for _, off in { -13, 13 } do place(K.Bench, faceCentre(polar(54, sector + off, 0.6)), plaza, "Bench") end
	place(K.FlowerBed, faceCentre(polar(44, sector, 0.8)), plaza, "FlowerBed")
	if k % 2 == 1 then
		place(K.CafeSet, CFrame.new(polar(54, sector, 0.6)), plaza, "Cafe")
	else
		for _, off in { -7, 7 } do
			place(K.Bush, CFrame.new(polar(58, sector + off, 0.6)) * CFrame.Angles(0, math.rad(sector * 7 + off * 11), 0), plaza, "Bush")
		end
	end
	place(k % 2 == 0 and K.TreeRound or K.TreePine, CFrame.new(polar(67, sector + 20, 0.6)) * CFrame.Angles(0, math.rad(k * 53), 0), plaza)
end

-- plots, in plot-local space: x right, z toward the plaza; the lot is x -52..52, z +10..-68
for i = 1, 6 do
	local plot = W.Plots["Plot" .. i]
	local origin = plot.Origin
	for _, c in plot:GetChildren() do
		if c ~= origin and c.Name ~= "Spawn" then c:Destroy() end
	end
	origin.Transparency = 1
	plot.Spawn.Transparency = 1; plot.Spawn.CanCollide = false
	local O = origin.CFrame
	local s = Instance.new("Folder"); s.Name = "Scenery"; s.Parent = plot
	local function at(x, y, z, yawDeg) return O * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yawDeg or 0), 0) end
	-- ground sits 0.15 low so the yard slab stays under the clinic floor (floor top 0.2)
	place(K.PlotGround, at(0, -0.15, 0), s)
	for _, sx in { -52, 52 } do
		for _, z in { -3, -29, -55 } do place(K.Fence26, at(sx, 0, z, 90), s, "FenceSide") end
	end
	for _, x in { -39, -13, 13, 39 } do place(K.Hedge26, at(x, 0, -68), s, "HedgeBack") end
	for _, sgn in { -1, 1 } do
		place(K.Hedge26, at(sgn * 39, 0, 8.5), s, "HedgeFront")
		place(K.Fence26, at(sgn * 22.5, 0, 8.5), s, "FenceFront")
	end
	place(K.GatePosts, at(0, 0, 8.5), s) -- gate meshes do not collide: two invisible pillars instead
	for _, sgn in { -1, 1 } do invisible(s, "GatePillar", V(2.2, 9.45, 3.4), (O * CFrame.new(sgn * 7.8, 4.7, 8.5)).Position) end
	place(K.Mailbox, at(11.5, 0, 14, 180), s)
	-- planting stays outside the largest clinic footprint (x +-44, z 0..-44)
	place(K.TreeRound, at(-45, 0.05, -58, i * 37), s)
	place(K.TreePine, at(45, 0.05, -58, i * 61), s)
	place(K.TreePine, at(-20, 0.05, -60, i * 17), s)
	place(K.TreeRound, at(20, 0.05, -60, i * 29), s)
	for _, sgn in { -1, 1 } do
		place(K.FlowerBed, at(sgn * 22, 0.05, 5.5), s)
		place(K.Bush, at(sgn * 34, 0.05, 5, i * 41), s)
	end
end

-- ground colour, a ring of trees framing the map, and invisible walls at the edge
workspace.Baseplate.Color = Color3.fromRGB(93, 170, 91)
workspace.Baseplate.Material = Enum.Material.SmoothPlastic
local forest = Instance.new("Folder"); forest.Name = "Forest"; forest.Parent = W
for n = 0, 59 do
	local a = n * 6 + (n % 3) * 1.7
	local r = 225 + ((n * 37) % 45)
	place(n % 2 == 0 and K.TreePine or K.TreeRound, CFrame.new(polar(r, a, 0)) * CFrame.Angles(0, math.rad(n * 47), 0), forest)
end
local bounds = Instance.new("Folder"); bounds.Name = "Bounds"; bounds.Parent = W
for _, d in { V(300, 40, 0), V(-300, 40, 0), V(0, 40, 300), V(0, 40, -300) } do
	invisible(bounds, "Wall", d.X ~= 0 and V(2, 120, 620) or V(620, 120, 2), d)
end
-- lighting used for the screenshots: Brightness 2.4, Exposure -0.1, Ambient 86,96,108, OutdoorAmbient 112,124,138,
-- Atmosphere.Haze 0.35, ColorCorrection Contrast 0.1 / Saturation 0.1 (Lighting is saved in the place, not by Rojo)
