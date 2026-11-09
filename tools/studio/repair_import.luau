-- Run through the Studio MCP `execute_luau` (Edit datamodel). Repairs what Studio's importer drops.
-- For every Model in ServerStorage.Templates.Props:
--   * colour from the `_RRGGBB` suffix of each MeshPart name, TintSlot attribute from the prefix
--   * material by slot, anchored, box collision
--   * WorldPivot moved to the prop's Kiln origin (ground point it was designed around)
-- ORIGIN_MIN is `boundsStuds.min` {x, z} printed by kiln_to_roblox.mjs for each prop; SIZE is `sizeStuds`.
local ORIGIN_MIN = {
	DentalChair = { -2.196, -4.332 }, DentalLamp = { -1.286, -3.929 }, InstrumentTray = { -1.071, -1.25 },
	ReceptionDesk = { -5.982, -1.893 }, SinkCabinet = { -1.893, -1.168 }, XRayMachine = { -1.643, -4.018 },
	Sterilizer = { -1.357, -1.28 }, WaterCooler = { -0.714, -1.071 }, ToothSign = { -3.036, -3.036 },
}
local SIZE = {
	DentalChair = { 4.39, 5.95, 9.81 }, DentalLamp = { 2.57, 6.25, 5.21 }, InstrumentTray = { 2.14, 3.75, 2.5 },
	ReceptionDesk = { 11.96, 5.89, 3.79 }, SinkCabinet = { 3.79, 4.14, 2.28 }, XRayMachine = { 3.29, 6.61, 5.66 },
	Sterilizer = { 2.64, 2.05, 2.35 }, WaterCooler = { 1.43, 5.27, 1.79 }, ToothSign = { 6.07, 7.75, 6.07 },
}
local NEON = { Glow = true, Screen = true }

local function aabb(model)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			local h = p.Size / 2
			for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
				local w = p.CFrame:PointToWorldSpace(Vector3.new(sx * h.X, sy * h.Y, sz * h.Z))
				lo = Vector3.new(math.min(lo.X, w.X), math.min(lo.Y, w.Y), math.min(lo.Z, w.Z))
				hi = Vector3.new(math.max(hi.X, w.X), math.max(hi.Y, w.Y), math.max(hi.Z, w.Z))
			end end end
		end
	end
	return lo, hi
end

local report = {}
local folder = game:GetService("ServerStorage").Templates.Props
for _, model in folder:GetChildren() do
	if model:IsA("Model") then
		local slots, grey = {}, 0
		for _, d in model:GetDescendants() do
			if d:IsA("MeshPart") then
				local slot, hex = d.Name:match("^(%a+)_(%x%x%x%x%x%x)")
				if slot then
					d.Color = Color3.fromRGB(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
					d:SetAttribute("TintSlot", slot)
					slots[slot] = true
				else
					grey += 1
				end
				d.Material = if slot == "Chrome" then Enum.Material.Metal elseif NEON[slot or ""] then Enum.Material.Neon else Enum.Material.SmoothPlastic
				if slot == "Water" then d.Transparency = 0.15 end
				d.Anchored = true
				d.CollisionFidelity = Enum.CollisionFidelity.Box
			end
		end
		local lo, hi = aabb(model)
		local om, want = ORIGIN_MIN[model.Name], SIZE[model.Name]
		local info = { meshes = #model:GetDescendants(), unmatched = grey }
		if om and want then
			model.WorldPivot = CFrame.new(lo.X - om[1], lo.Y, lo.Z - om[2])
			local ext = hi - lo
			info.extents = string.format("%.2f x %.2f x %.2f", ext.X, ext.Y, ext.Z)
			info.sizeOk = math.abs(ext.X - want[1]) < 0.15 and math.abs(ext.Y - want[2]) < 0.15 and math.abs(ext.Z - want[3]) < 0.15
		end
		local list = {}
		for s in slots do table.insert(list, s) end
		table.sort(list)
		info.tintSlots = table.concat(list, ",")
		report[model.Name] = info
	end
end
game:GetService("ChangeHistoryService"):SetWaypoint("Repair imported props")
return report
