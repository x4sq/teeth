-- Studio command-bar / MCP execute_luau script (Edit DataModel). NOT part of the Rojo build.
-- Repairs the 31 freshly imported low-poly models in ServerStorage.Templates.{Props,Kit}:
-- the importer drops colours, leaves parts unanchored and may rotate the model by a fixed yaw.
-- For every model it (1) fits the yaw from the build record (size + one reference mesh centre),
-- (2) sets WorldPivot to the Kiln origin, (3) colours each mesh from the hex in its name
-- (`Slot_RRGGBB`) and tags TintSlot, (4) sets materials, anchoring and collision.
--
-- REC comes from art/lowpoly/_build/<Name>.json:
--   Name = { sx, sy, sz, originMinX, originMinZ, refMeshName, refCentreX, refCentreZ }
-- Paste the table generated from those files here (see HANDOVER.md for the one-liner).
local REC = {} -- e.g. Bench = { 6.4, 3.8, 2.35, -3.2, -1.1, "Wood_C8956A", 0, 0.07 }, ...

local TS = game:GetService("ServerStorage").Templates
local NOCOLLIDE_ALL = { Shell0 = true, Shell1 = true, Shell2 = true, Shell3 = true, GatePosts = true, CafeSet = true, RugRunner = true, Bush = true }
local NOCOLLIDE_SLOT = { Leaf = true, LeafA = true, LeafB = true, Water = true, Glass = true, UmbrellaA = true, UmbrellaB = true }

local function gather(model)
	local pts, parts = {}, {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			table.insert(parts, p)
			local h = p.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						table.insert(pts, p.CFrame:PointToWorldSpace(Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)))
					end
				end
			end
		end
	end
	return pts, parts
end

local function bounds(pts, cx, cz, psi)
	local c, s = math.cos(psi), math.sin(psi)
	local loX, hiX, loZ, hiZ = math.huge, -math.huge, math.huge, -math.huge
	for _, p in pts do
		local dx, dz = p.X - cx, p.Z - cz
		local x, z = dx * c - dz * s, dx * s + dz * c
		loX, hiX, loZ, hiZ = math.min(loX, x), math.max(hiX, x), math.min(loZ, z), math.max(hiZ, z)
	end
	return loX, hiX, loZ, hiZ
end

local function evaluate(pts, cx, cz, psi, r, refPos)
	local loX, hiX, loZ, hiZ = bounds(pts, cx, cz, psi)
	local err = math.abs((hiX - loX) - r.sx) + math.abs((hiZ - loZ) - r.sz)
	if refPos then
		local c, s = math.cos(psi), math.sin(psi)
		local dx, dz = refPos.X - cx, refPos.Z - cz
		local rx, rz = dx * c - dz * s, dx * s + dz * c
		err += math.abs(rx - (loX + hiX) / 2 - r.vx) + math.abs(rz - (loZ + hiZ) / 2 - r.vz)
	end
	return err
end

local function search(pts, cx, cz, r, refPos)
	local best, bestErr = 0, math.huge
	for k = 0, 719 do
		local psi = math.rad(k * 0.5)
		local e = evaluate(pts, cx, cz, psi, r, refPos)
		if e < bestErr then best, bestErr = psi, e end
	end
	local centre = best
	for k = -12, 12 do
		local psi = centre + math.rad(k * 0.05)
		local e = evaluate(pts, cx, cz, psi, r, refPos)
		if e < bestErr then best, bestErr = psi, e end
	end
	return best, bestErr
end

local function process(model, batchPsi)
	local d = REC[model.Name]
	local r = { sx = d[1], sy = d[2], sz = d[3], omx = d[4], omz = d[5], ref = d[6], vx = d[7] - (d[4] + d[1] / 2), vz = d[8] - (d[5] + d[3] / 2) }
	local pts, parts = gather(model)
	local cx, cz = 0, 0
	for _, p in pts do cx += p.X; cz += p.Z end
	cx, cz = cx / #pts, cz / #pts
	local refPos, count = nil, 0
	for _, p in parts do if p.Name == r.ref then refPos = p.Position; count += 1 end end
	if count ~= 1 then refPos = nil end
	local psi, err
	if batchPsi then
		err = evaluate(pts, cx, cz, batchPsi, r, refPos)
		if err < 0.8 then psi = batchPsi end
	end
	if not psi then psi, err = search(pts, cx, cz, r, refPos) end
	model:PivotTo(CFrame.new(cx, 0, cz) * CFrame.Angles(0, -psi, 0) * CFrame.new(-cx, 0, -cz) * model:GetPivot())
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in gather(model) do
		lo = Vector3.new(math.min(lo.X, p.X), math.min(lo.Y, p.Y), math.min(lo.Z, p.Z))
		hi = Vector3.new(math.max(hi.X, p.X), math.max(hi.Y, p.Y), math.max(hi.Z, p.Z))
	end
	model.WorldPivot = CFrame.new(lo.X - r.omx, lo.Y, lo.Z - r.omz)
	local unmatched = 0
	for _, m in model:GetDescendants() do
		if m:IsA("MeshPart") then
			local slot, hex = m.Name:match("^(%w+)_(%x%x%x%x%x%x)") -- %w: Floor2 has a digit
			if slot then
				m.Color = Color3.fromRGB(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
				m:SetAttribute("TintSlot", slot)
			else
				unmatched += 1
			end
			local s = slot or ""
			m.Material = if s == "Chrome" then Enum.Material.Metal elseif s == "Glow" or s == "Screen" then Enum.Material.Neon else Enum.Material.SmoothPlastic
			if s == "Glass" then m.Transparency = 0.5 elseif s == "Water" then m.Transparency = 0.3 end
			m.Anchored = true
			m.CollisionFidelity = Enum.CollisionFidelity.Box
			m.CanCollide = not (NOCOLLIDE_ALL[model.Name] or NOCOLLIDE_SLOT[s] or s:sub(1, 5) == "Bloom")
		end
	end
	local ext = hi - lo
	return psi, {
		yawDeg = math.round(math.deg(psi) * 10) / 10, err = math.round(err * 100) / 100, unmatched = unmatched,
		sizeOk = math.abs(ext.X - r.sx) < 0.2 and math.abs(ext.Y - r.sy) < 0.2 and math.abs(ext.Z - r.sz) < 0.2,
	}
end

local report, batchPsi = {}, nil
local desk = TS.Props:FindFirstChild("ReceptionDesk") -- long and asymmetric: its yaw is the most reliable
if desk then batchPsi, report.ReceptionDesk = process(desk, nil) end
for _, folder in { TS.Props, TS.Kit } do
	for _, model in folder:GetChildren() do
		if model:IsA("Model") and REC[model.Name] and model.Name ~= "ReceptionDesk" then
			local _, info = process(model, batchPsi)
			report[model.Name] = info
		end
	end
	task.wait()
end
local bad = {}
for n, i in report do if not i.sizeOk or i.unmatched > 0 then table.insert(bad, n) end end
return { problems = bad, batchYawDeg = batchPsi and math.round(math.deg(batchPsi) * 10) / 10 }
