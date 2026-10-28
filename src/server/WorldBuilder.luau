-- Остров целиком собирается кодом: ландшафт Terrain + простые детали. Ничего вручную в Studio делать не нужно.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Zones = require(Shared.Zones)
local Npcs = require(Shared.Npcs)
local Buildings = require(script.Parent.Buildings)

local WorldBuilder = {}

local terrain = workspace.Terrain
local rng = Random.new(1987)
local world: Folder
local decor: Folder

local V3 = Vector3.new
local C3 = Color3.fromRGB

local WOOD = C3(120, 85, 55)
local DARK_WOOD = C3(72, 48, 30)
local DARK_METAL = C3(44, 46, 54)
local GOLD_ACCENT = C3(235, 195, 75)

--- Результат build(): ссылки на точки, которые нужны другим сервисам.
WorldBuilder.spawnPad = nil :: SpawnLocation?
WorldBuilder.lobbySpawn = nil :: SpawnLocation?
WorldBuilder.joyPrompt = nil :: ProximityPrompt?

local function newPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Shape = shape or Enum.PartType.Block
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

--- Вертикальный цилиндр (у Roblox ось цилиндра — X).
local function column(parent: Instance, name: string, base: Vector3, height: number, diameter: number, color: Color3, material: Enum.Material?): Part
	return newPart(
		parent,
		name,
		V3(height, diameter, diameter),
		CFrame.new(base + V3(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		color,
		material,
		Enum.PartType.Cylinder
	)
end

local function cylinder(parent: Instance, name: string, cframe: CFrame, height: number, diameter: number, color: Color3, material: Enum.Material?, collide: boolean?): Part
	local created = newPart(parent, name, V3(height, diameter, diameter), cframe * CFrame.Angles(0, 0, math.pi / 2), color, material, Enum.PartType.Cylinder)
	created.CanCollide = collide == true
	created.CanQuery = collide == true
	return created
end

local function wedge(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, collide: boolean?): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Size = size
	w.CFrame = cframe
	w.Color = color
	w.Material = material or Enum.Material.SmoothPlastic
	w.Anchored = true
	w.CanCollide = collide == true
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Parent = parent
	return w
end

local function sign(parent: Instance, text: string, position: Vector3, color: Color3?)
	local anchor = newPart(parent, "Sign", V3(1, 1, 1), CFrame.new(position), C3(255, 255, 255), nil)
	anchor.Transparency = 1
	anchor.CanCollide = false
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(340, 52)
	gui.MaxDistance = 320
	gui.StudsOffset = V3(0, 0, 0)
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.25
	label.BackgroundColor3 = C3(20, 22, 30)
	label.TextColor3 = color or C3(255, 255, 255)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = text
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or C3(255, 255, 255)
	stroke.Thickness = 2
	stroke.Transparency = 0.3
	stroke.Parent = label
end

--- Высота земли (только Terrain: ray игнорирует всё, что построено в world).
local terrainOnly: RaycastParams?

-- Текстуры террейна выступают над его физической поверхностью: всё, что стоит на земле, ставим чуть выше,
-- чтобы дома, предметы и деревья не тонули. Единая высота для всего мира.
local GROUND_LIFT = 0.9
WorldBuilder.groundLift = GROUND_LIFT

-- Площади городов — ровные диски из деталей: на них стоят NPC, фонари и достопримечательности,
-- поэтому высота внутри площади известна точно и персонаж не тонет в бугристой текстуре террейна.
local plazaDiscs: { { x: number, z: number, r: number, top: number } } = {}

function WorldBuilder.terrainY(x: number, z: number): number
	for _, disc in plazaDiscs do
		local dx, dz = x - disc.x, z - disc.z
		if dx * dx + dz * dz < disc.r * disc.r then
			return disc.top
		end
	end
	-- только Terrain: не цепляем игроков, NPC, монстров и постройки
	if not terrainOnly then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { terrain }
		terrainOnly = params
	end
	local hit = workspace:Raycast(V3(x, 400, z), V3(0, -800, 0), terrainOnly)
	return (hit and hit.Position.Y or 0) + GROUND_LIFT
end

local decorOnly: RaycastParams?

--- Перегорожен ли путь постройками (дома, деревья, камни): короткий луч на высоте груди от точки `from`.
function WorldBuilder.pathBlocked(from: Vector3, unit: Vector3, length: number): boolean
	if not decorOnly then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { decor }
		decorOnly = params
	end
	return workspace:Raycast(from + V3(0, 2.5, 0), unit * length, decorOnly) ~= nil
end

--- Свободна ли точка от построек (для появления предметов).
function WorldBuilder.isFree(point: Vector3, radius: number): boolean
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { world }
	return #workspace:GetPartBoundsInRadius(point + V3(0, 3, 0), radius, overlap) == 0
end

--- Точка в зоне со смещением; y — по земле.
function WorldBuilder.zonePoint(zoneKey: string, dx: number, dz: number): Vector3
	local zone = Zones[zoneKey]
	local x = zone.x + dx
	local z = zone.z + dz
	if zoneKey == "Coast" then
		x, z = dx, dz
	end
	return V3(x, WorldBuilder.terrainY(x, z), z)
end

-- ===================== ландшафт =====================

local function buildTerrain()
	terrain:Clear()
	terrain:FillCylinder(CFrame.new(0, -9, 0), 14, 1600, Enum.Material.Water)
	terrain:FillCylinder(CFrame.new(0, -10.5, 0), 19, 930, Enum.Material.Sand)
	terrain:FillCylinder(CFrame.new(0, -11, 0), 20, 880, Enum.Material.Grass) -- верх на 1 stud ниже: постройки не тонут в траве

	for key, zone in Zones do
		if key ~= "Coast" and zone.ground then
			terrain:FillCylinder(CFrame.new(zone.x, -11, zone.z), 20, zone.r * 0.95, zone.ground)
		end
	end

	-- скалы (Cliffs)
	for _, hill in { { -340, 520, 46 }, { -280, 600, 38 }, { -240, 500, 30 }, { -360, 590, 34 }, { -300, 540, 54 } } do
		terrain:FillBall(V3(hill[1], 0, hill[2]), hill[3], Enum.Material.Rock)
	end
	-- мезы Бесплодных земель
	for index = 1, 7 do
		local angle = index * 0.9
		local x = 280 + math.cos(angle) * (110 + index * 12)
		local z = -330 + math.sin(angle) * (110 + index * 12)
		terrain:FillBlock(CFrame.new(x, 14, z), V3(rng:NextInteger(26, 44), 28, rng:NextInteger(26, 44)), Enum.Material.Sandstone)
	end
	-- пещера: скальная масса, внутри полость и вход с юга
	local cave = Zones.Cave
	terrain:FillBall(V3(cave.x, 0, cave.z), 46, Enum.Material.Rock)
	terrain:FillBall(V3(cave.x, 14, cave.z), 14, Enum.Material.Air)
	terrain:FillBlock(CFrame.new(cave.x, 7, cave.z + 26), V3(12, 14, 34), Enum.Material.Air)
	-- холмы лугов
	for _, hill in { { 40, 440, 22 }, { 180, 520, 26 }, { 90, 560, 18 } } do
		terrain:FillBall(V3(hill[1], 0, hill[2]), hill[3], Enum.Material.Grass)
	end
	-- болотные лужи
	local swamp = Zones.Swamp
	for index = 1, 6 do
		local angle = index * 1.05
		local px = swamp.x + math.cos(angle) * (30 + index * 9)
		local pz = swamp.z + math.sin(angle) * (30 + index * 9)
		terrain:FillCylinder(CFrame.new(px, -3, pz), 4, rng:NextInteger(9, 14), Enum.Material.Water)
	end
end

-- ===================== мелкие детали =====================

--- Наклонная ветка/корень/ствол: цилиндр от одной точки к другой.
local function limb(name: string, from: Vector3, to: Vector3, diameter: number, color: Color3, material: Enum.Material?): Part
	local delta = to - from
	if delta.Magnitude < 0.01 then
		delta = V3(0.01, 0, 0)
	end
	local length = delta.Magnitude
	local unit = delta.Unit
	local up = math.abs(unit.Y) > 0.98 and V3(0, 0, 1) or V3(0, 1, 0)
	local mid = from + delta * 0.5
	return newPart(
		decor,
		name,
		V3(length, diameter, diameter),
		CFrame.lookAt(mid, to, up) * CFrame.Angles(0, math.pi / 2, 0),
		color,
		material,
		Enum.PartType.Cylinder
	)
end

local function leafClump(name: string, center: Vector3, size: Vector3, color: Color3): Part
	local clump = newPart(
		decor,
		name,
		size,
		CFrame.new(center) * CFrame.Angles(rng:NextNumber(-0.16, 0.16), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.16, 0.16)),
		color,
		Enum.Material.LeafyGrass,
		Enum.PartType.Ball
	)
	clump.CanCollide = false
	clump.CanQuery = false
	CollectionService:AddTag(clump, "Sway")
	return clump
end

local function leafSpray(name: string, center: Vector3, size: Vector3, color: Color3, yaw: number, pitch: number): Part
	local leaf = newPart(
		decor,
		name,
		size,
		CFrame.new(center) * CFrame.Angles(pitch, yaw, rng:NextNumber(-0.12, 0.12)),
		color,
		Enum.Material.LeafyGrass
	)
	leaf.CanCollide = false
	leaf.CanQuery = false
	CollectionService:AddTag(leaf, "Sway")
	return leaf
end

--- Реалистичное лиственное дерево: сужающийся ствол, корни, ветки, тонкие побеги и рваная крона.
local function tree(position: Vector3, scale: number, dead: boolean?)
	local height = 14 * scale
	local lean = V3(rng:NextNumber(-0.7, 0.7), 0, rng:NextNumber(-0.7, 0.7)) * scale
	local p0 = position
	local p1 = position + V3(lean.X * 0.3, height * 0.34, lean.Z * 0.3)
	local p2 = position + V3(lean.X * 0.68, height * 0.68, lean.Z * 0.68)
	local p3 = position + V3(lean.X, height, lean.Z)
	local trunkColor = dead and C3(96, 80, 64) or WOOD
	local barkColor = trunkColor:Lerp(C3(40, 28, 18), 0.28)

	limb("Trunk", p0, p1, 2.9 * scale, trunkColor, Enum.Material.Wood)
	limb("Trunk", p1, p2, 2.15 * scale, trunkColor, Enum.Material.Wood)
	limb("Trunk", p2, p3, 1.45 * scale, trunkColor, Enum.Material.Wood)

	for index = 1, 3 do
		local angle = index * math.pi * 2 / 3 + rng:NextNumber(-0.3, 0.3)
		local x = math.cos(angle) * 1.15 * scale
		local z = math.sin(angle) * 1.15 * scale
		limb("BarkRidge", p0 + V3(x, 0.45 * scale, z), p1 + V3(x * 0.7, 0.2 * scale, z * 0.7), 0.2 * scale, barkColor, Enum.Material.Wood)
	end

	for _ = 1, 3 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local rootEnd = position
			+ V3(math.cos(angle) * rng:NextNumber(1.8, 3.4) * scale, 0.15, math.sin(angle) * rng:NextNumber(1.8, 3.4) * scale)
		limb("Root", position + V3(0, 0.8 * scale, 0), rootEnd, 0.72 * scale, DARK_WOOD, Enum.Material.Wood)
	end

	local branchEnds = {}
	for _ = 1, (dead and 4 or 3) do
		local angle = rng:NextNumber(0, math.pi * 2)
		local startY = height * rng:NextNumber(0.55, 0.86)
		local start = position + V3(lean.X * (startY / height), startY, lean.Z * (startY / height))
		local reach = rng:NextNumber(3.5, 6.8) * scale
		local endp = start + V3(math.cos(angle) * reach, rng:NextNumber(1.4, 3.8) * scale, math.sin(angle) * reach)
		limb("Branch", start, endp, 0.85 * scale, trunkColor, Enum.Material.Wood)
		table.insert(branchEnds, endp)
	end

	for index = 1, 4 do
		local start = branchEnds[(index - 1) % #branchEnds + 1]
		local angle = rng:NextNumber(0, math.pi * 2)
		local endp = start
			+ V3(math.cos(angle) * rng:NextNumber(1.2, 2.4) * scale, rng:NextNumber(0.8, 2.3) * scale, math.sin(angle) * rng:NextNumber(1.2, 2.4) * scale)
		limb("Twig", start, endp, 0.34 * scale, trunkColor, Enum.Material.Wood)
	end

	if dead then
		return
	end

	local crownPos = p3 + V3(0, 2.0 * scale, 0)
	local green = C3(50 + rng:NextInteger(0, 26), 112 + rng:NextInteger(0, 34), 52 + rng:NextInteger(0, 18))
	leafClump("Crown", crownPos, V3(8.6, 7.2, 8.6) * scale, green)
	for _ = 1, 5 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(3.6, 5.8) * scale
		local size = rng:NextNumber(4.2, 6.8) * scale
		local center = crownPos
			+ V3(math.cos(angle) * radius, rng:NextNumber(-2.4, 2.6) * scale, math.sin(angle) * radius)
		leafClump(
			"CrownLobe",
			center,
			V3(size, size * 0.82, size),
			green:Lerp(C3(72 + rng:NextInteger(0, 20), 142 + rng:NextInteger(0, 20), 64), rng:NextNumber(0.1, 0.4))
		)
	end
	for _ = 1, 4 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local center = crownPos
			+ V3(math.cos(angle) * 5.2 * scale, rng:NextNumber(-2.8, -0.2) * scale, math.sin(angle) * 5.2 * scale)
		leafSpray(
			"LeafSpray",
			center,
			V3(rng:NextNumber(2.2, 3.6) * scale, 0.12, rng:NextNumber(1.0, 1.8) * scale),
			green:Lerp(C3(90, 150, 70), rng:NextNumber(0.15, 0.4)),
			angle,
			rng:NextNumber(-0.28, 0.28)
		)
	end
end

--- Пальма для побережья: изогнутый ствол с кольцами, перистые вайи и кокосы.
local function palm(position: Vector3, scale: number)
	local height = 17 * scale
	local side = V3(
		rng:NextNumber(1.2, 2.8) * (rng:NextBoolean() and 1 or -1),
		0,
		rng:NextNumber(1.2, 2.8) * (rng:NextBoolean() and 1 or -1)
	) * scale
	local p0 = position
	local p1 = position + V3(side.X * 0.35, height * 0.34, side.Z * 0.35)
	local p2 = position + V3(side.X * 0.72, height * 0.68, side.Z * 0.72)
	local p3 = position + V3(side.X, height, side.Z)
	local trunkColor = C3(132, 104, 72)
	limb("PalmTrunk", p0, p1, 2.4 * scale, trunkColor, Enum.Material.Wood)
	limb("PalmTrunk", p1, p2, 2.0 * scale, trunkColor, Enum.Material.Wood)
	limb("PalmTrunk", p2, p3, 1.6 * scale, trunkColor, Enum.Material.Wood)

	for index = 1, 3 do
		local t = index / 4
		column(decor, "PalmRing", p0:Lerp(p3, t), 0.16 * scale, (2.55 - t * 0.8) * scale, trunkColor:Lerp(C3(80, 60, 40), 0.3), Enum.Material.Wood)
	end

	local leafColor = C3(66 + rng:NextInteger(0, 20), 132 + rng:NextInteger(0, 24), 58)
	for index = 1, 6 do
		local angle = (index / 6) * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local reach = rng:NextNumber(6.0, 8.5) * scale
		local endp = p3 + V3(math.cos(angle) * reach, rng:NextNumber(-2.0, 0.8) * scale, math.sin(angle) * reach)
		local frond = limb("PalmFrond", p3, endp, 0.18 * scale, leafColor:Lerp(C3(90, 152, 70), rng:NextNumber(0, 0.3)), Enum.Material.LeafyGrass)
		CollectionService:AddTag(frond, "Sway")
		for leaflet = 1, 3 do
			local t = 0.2 + leaflet * 0.22
			local base = p3:Lerp(endp, t)
			local sideAngle = angle + (leaflet % 2 == 0 and math.pi / 2 or -math.pi / 2)
			local spread = rng:NextNumber(0.9, 1.5) * scale
			local tip = base
				+ V3(math.cos(sideAngle) * spread + math.cos(angle) * 0.7 * scale, rng:NextNumber(-0.55, 0.15) * scale, math.sin(sideAngle) * spread + math.sin(angle) * 0.7 * scale)
			local leaf = limb("PalmLeaflet", base, tip, 0.14 * scale, leafColor:Lerp(C3(100, 160, 70), rng:NextNumber(0, 0.35)), Enum.Material.LeafyGrass)
			CollectionService:AddTag(leaf, "Sway")
		end
	end
	for index = 1, 3 do
		local angle = (index / 3) * math.pi * 2
		local coconut = newPart(
			decor,
			"Coconut",
			V3(1.2, 1.2, 1.2) * scale,
			CFrame.new(p3 + V3(math.cos(angle) * 0.9 * scale, -0.8 * scale, math.sin(angle) * 0.9 * scale)),
			C3(105, 78, 52),
			Enum.Material.Wood,
			Enum.PartType.Ball
		)
		coconut.CanCollide = false
	end
end

--- Пышный куст: несколько ярусов листвы, тонкие ветки, отдельные листья и ягоды.
local function bush(position: Vector3, scale: number)
	local x, z = position.X, position.Z
	local y = WorldBuilder.terrainY(x, z)
	local stemH = 1.5 * scale
	local leaf = C3(58 + rng:NextInteger(0, 18), 112 + rng:NextInteger(0, 28), 54 + rng:NextInteger(0, 14))

	for index = 1, 3 do
		local angle = index * math.pi * 2 / 3 + rng:NextNumber(-0.35, 0.35)
		local start = V3(x, y, z)
		local endp = V3(
			x + math.cos(angle) * rng:NextNumber(0.7, 1.3) * scale,
			y + stemH * rng:NextNumber(0.7, 1.2),
			z + math.sin(angle) * rng:NextNumber(0.7, 1.3) * scale
		)
		limb("BushStem", start, endp, 0.2 * scale, DARK_WOOD, Enum.Material.Wood)
	end

	leafClump("BushCore", V3(x, y + stemH * 0.9, z), V3(2.6, 2.2, 2.6) * scale, leaf:Lerp(C3(40, 90, 45), 0.3))
	for index = 1, 5 do
		local angle = index * math.pi * 2 / 5 + rng:NextNumber(-0.35, 0.35)
		local radius = rng:NextNumber(1.0, 2.2) * scale
		local size = rng:NextNumber(1.6, 2.8) * scale
		local center = V3(x, y + stemH * rng:NextNumber(0.8, 1.6), z)
			+ V3(math.cos(angle) * radius, rng:NextNumber(-0.4, 0.8) * scale, math.sin(angle) * radius)
		leafClump("BushLobe", center, V3(size, size * 0.8, size), leaf:Lerp(C3(80, 145, 62), rng:NextNumber(0, 0.35)))
	end
	for index = 1, 3 do
		local angle = index * math.pi * 2 / 3 + rng:NextNumber(-0.4, 0.4)
		local center = V3(x, y + stemH * rng:NextNumber(1.0, 1.7), z)
			+ V3(math.cos(angle) * rng:NextNumber(1.8, 2.6) * scale, rng:NextNumber(-0.2, 0.7) * scale, math.sin(angle) * rng:NextNumber(1.8, 2.6) * scale)
		leafSpray("BushLeaf", center, V3(rng:NextNumber(1.2, 2.0) * scale, 0.08, rng:NextNumber(0.5, 0.9) * scale), leaf:Lerp(C3(90, 155, 70), 0.3), angle, rng:NextNumber(-0.22, 0.22))
	end
	for _ = 1, 3 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local start = V3(x, y + stemH * 0.7, z)
		local endp = start
			+ V3(math.cos(angle) * rng:NextNumber(1.2, 2.2) * scale, rng:NextNumber(1.0, 2.4) * scale, math.sin(angle) * rng:NextNumber(1.2, 2.2) * scale)
		local twig = limb("BushTwig", start, endp, 0.16 * scale, DARK_WOOD, Enum.Material.Wood)
		twig.CanCollide = false
	end
	for index = 1, 2 do
		local angle = index * math.pi + rng:NextNumber(-0.4, 0.4)
		local berry = newPart(
			decor,
			"BushBerry",
			V3(0.28, 0.28, 0.28) * scale,
			CFrame.new(V3(x + math.cos(angle) * 1.9 * scale, y + stemH * 1.35, z + math.sin(angle) * 1.9 * scale)),
			index == 1 and C3(210, 65, 75) or C3(235, 175, 65),
			Enum.Material.SmoothPlastic,
			Enum.PartType.Ball
		)
		berry.CanCollide = false
	end
end

local function rock(position: Vector3, size: number, color: Color3?)
	local part = newPart(
		decor,
		"Rock",
		V3(size, size * 0.7, size * rng:NextNumber(0.8, 1.2)),
		CFrame.new(position + V3(0, size * 0.2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
		color or C3(120, 120, 128),
		Enum.Material.Slate,
		Enum.PartType.Ball
	)
	part.CanCollide = true
end

local function house(center: Vector3, width: number, depth: number, height: number, wall: Color3, roof: Color3, yaw: number, style: string?)
	Buildings.house(decor, center, width, depth, height, wall, roof, yaw, style or "cottage")
end

local function plaza(zoneKey: string, radius: number, color: Color3)
	local zone = Zones[zoneKey]
	-- площадь должна накрывать всех NPC города
	for _, npc in Npcs do
		if npc.zone == zoneKey then
			radius = math.max(radius, math.sqrt(npc.dx * npc.dx + npc.dz * npc.dz) + 7)
		end
	end
	local y = WorldBuilder.terrainY(zone.x, zone.z)
	local top = y + 0.5
	local thickness = 4 -- уходит вглубь, чтобы не было щелей над бугристым террейном
	local function disc(size: number, surface: number, tint: Color3)
		local part = newPart(
			decor,
			"Plaza",
			V3(thickness, size * 2, size * 2),
			CFrame.new(zone.x, surface - thickness / 2, zone.z) * CFrame.Angles(0, 0, math.pi / 2),
			tint,
			Enum.Material.Cobblestone,
			Enum.PartType.Cylinder
		)
		part.CanCollide = true
	end
	disc(radius + 4, y + 0.1, color:Lerp(C3(120, 118, 110), 0.5)) -- плавный край
	disc(radius, top, color)
	table.insert(plazaDiscs, { x = zone.x, z = zone.z, r = radius, top = top })
end

--- Фонарь: резной чугунный столб, кронштейн и тёплое золотистое свечение.
local function lamp(base: Vector3)
	column(decor, "LampBase", base, 1.2, 1.3, C3(38, 40, 48), Enum.Material.Metal)
	column(decor, "LampPost", base + V3(0, 1.2, 0), 8.5, 0.55, C3(45, 48, 58), Enum.Material.Metal)
	newPart(decor, "LampBracket", V3(0.25, 0.25, 1.6), CFrame.new(base + V3(0, 9.6, 0.6)), C3(45, 48, 58), Enum.Material.Metal)
	newPart(decor, "LampCap", V3(1.6, 0.35, 1.6), CFrame.new(base + V3(0, 10.2, 1.2)), C3(38, 40, 48), Enum.Material.Metal)
	wedge(decor, "LampPeak", V3(1.2, 0.7, 1.2), CFrame.new(base + V3(0, 10.6, 1.2)), C3(38, 40, 48), Enum.Material.Metal, false)
	local bulb = newPart(decor, "LampBulb", V3(1.1, 1.3, 1.1), CFrame.new(base + V3(0, 9.5, 1.2)), C3(255, 230, 160), Enum.Material.Neon, Enum.PartType.Ball)
	bulb.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = C3(255, 220, 150)
	light.Brightness = 1.6
	light.Range = 24
	light.Shadows = false
	light.Parent = bulb
end

--- Колодец: каменный сруб, вода внутри и крыша на двух столбах.
local function well(base: Vector3)
	column(decor, "WellBase", base, 3, 6, C3(150, 148, 140), Enum.Material.Cobblestone)
	local water = column(decor, "WellWater", base + V3(0, 2.7, 0), 0.3, 4.6, C3(60, 130, 190), Enum.Material.Glass)
	water.CanCollide = false
	column(decor, "WellPostL", base + V3(-3.2, 0, 0), 8, 0.6, WOOD, Enum.Material.Wood)
	column(decor, "WellPostR", base + V3(3.2, 0, 0), 8, 0.6, WOOD, Enum.Material.Wood)
	newPart(decor, "WellRoof", V3(8, 0.7, 5), CFrame.new(base + V3(0, 8.4, 0)), C3(120, 70, 55), Enum.Material.Slate)
end

--- Ящик и бочка рядом.
local function crates(base: Vector3, yaw: number)
	local frame = CFrame.new(base) * CFrame.Angles(0, yaw, 0)
	newPart(decor, "Crate", V3(2.6, 2.6, 2.6), frame * CFrame.new(0, 1.3, 0), C3(150, 108, 62), Enum.Material.WoodPlanks)
	newPart(decor, "Crate", V3(2, 2, 2), frame * CFrame.new(0.4, 3.6, 0.2) * CFrame.Angles(0, 0.5, 0), C3(165, 120, 70), Enum.Material.WoodPlanks)
	column(decor, "Barrel", base + frame:VectorToWorldSpace(V3(3.4, 0, 0.6)), 3, 2.2, C3(110, 78, 50), Enum.Material.Wood)
end

--- Фонари по кругу площади, колодец и несколько ящиков: город выглядит обжитым.
local function townDetails(zoneKey: string, withWell: boolean)
	local zone = Zones[zoneKey]
	local plazaRadius = math.min(26, zone.r * 0.28)
	for index = 0, 5 do
		local angle = math.rad(15 + index * 60)
		local x = zone.x + math.cos(angle) * (plazaRadius + 3)
		local z = zone.z + math.sin(angle) * (plazaRadius + 3)
		lamp(V3(x, WorldBuilder.terrainY(x, z), z))
	end
	if withWell then
		local x, z = zone.x - 9, zone.z + 9
		well(V3(x, WorldBuilder.terrainY(x, z), z))
	end
	for _ = 1, 3 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = zone.r * rng:NextNumber(0.5, 0.6)
		local x, z = zone.x + math.cos(angle) * radius, zone.z + math.sin(angle) * radius
		crates(V3(x, WorldBuilder.terrainY(x, z), z), rng:NextNumber(0, 6.28))
	end
end

local TOWN_STYLES: { [string]: { string } } = {
	Antokiba = { "cottage", "cottage", "shop", "cottage", "inn" },
	Rubicuta = { "cottage", "cottage", "shop", "cottage", "inn" },
	Aiai = { "villa", "villa", "shop", "villa", "inn" },
	Bunzen = { "cottage", "cottage", "inn", "cottage", "shop" },
	Masadora = { "masadora", "masadora", "tower", "masadora" },
	Soufrabi = { "cottage", "shop", "cottage", "inn" },
	Port = { "cottage", "shop", "cottage", "shop" },
	Dorias = { "inn", "stone", "tower", "stone" },
	Limeiro = { "castle", "tower", "castle", "shop" },
	Bandits = { "cabin" },
}

local function pickHouseStyle(zoneKey: string, index: number): string
	if zoneKey == "Bandits" then
		return "cabin"
	end
	if zoneKey == "Masadora" and index % 3 == 0 then
		return "tower"
	end
	if zoneKey == "Limeiro" and index % 3 == 0 then
		return "tower"
	end
	local palette = TOWN_STYLES[zoneKey] or TOWN_STYLES.Antokiba
	return palette[(index - 1) % #palette + 1]
end

local function buildTown(zoneKey: string, wall: Color3, roof: Color3, count: number?)
	local zone = Zones[zoneKey]
	local plazaRadius = math.min(32, zone.r * 0.32)
	plaza(zoneKey, plazaRadius, C3(175, 170, 155))

	-- 4 мощёных каменных проспекта, расходящихся от центра площади к границам города
	for dirIdx = 0, 3 do
		local dirAngle = dirIdx * math.pi / 2
		local dirVec = V3(math.cos(dirAngle), 0, math.sin(dirAngle))
		for seg = 1, math.floor(zone.r * 0.65 / 10) do
			local dist = plazaRadius + seg * 10
			local roadX, roadZ = zone.x + dirVec.X * dist, zone.z + dirVec.Z * dist
			local roadY = WorldBuilder.terrainY(roadX, roadZ)
			local roadPart = newPart(
				decor,
				"Avenue",
				V3(12, 0.4, 10.2),
				CFrame.new(roadX, roadY + 0.15, roadZ) * CFrame.Angles(0, -dirAngle, 0),
				C3(160, 155, 142),
				Enum.Material.Cobblestone
			)
			roadPart.CanCollide = true
		end
	end

	-- Внутреннее кольцо площади (магазины, таверны и особняки, фасадом к центру)
	local innerCount = math.clamp(math.floor(zone.r / 14), 5, 8)
	for i = 1, innerCount do
		local angle = (i / innerCount) * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local rad = plazaRadius + rng:NextNumber(9, 14)
		local x, z = zone.x + math.cos(angle) * rad, zone.z + math.sin(angle) * rad
		local y = WorldBuilder.terrainY(x, z)
		local w = rng:NextInteger(19, 26)
		local d = rng:NextInteger(19, 26)
		local h = rng:NextInteger(17, 23)
		local style = pickHouseStyle(zoneKey, i)
		if style == "tower" then
			w = rng:NextInteger(14, 17)
			d = w
			h = rng:NextInteger(30, 40)
		end
		house(
			V3(x, y, z),
			w,
			d,
			h,
			wall:Lerp(C3(255, 255, 255), rng:NextNumber(0, 0.25)),
			roof,
			angle + math.pi, -- фасад к центру площади
			style
		)
	end

	-- Внешнее кольцо улочек (жилые кварталы и коттеджи)
	local outerCount = math.clamp(math.floor(zone.r / 10), 7, 12)
	for i = 1, outerCount do
		local angle = ((i + 0.5) / outerCount) * math.pi * 2 + rng:NextNumber(-0.12, 0.12)
		local rad = math.min(zone.r * rng:NextNumber(0.72, 0.85), zone.r * 0.97 - 16)
		local x, z = zone.x + math.cos(angle) * rad, zone.z + math.sin(angle) * rad
		local y = WorldBuilder.terrainY(x, z)
		local w = rng:NextInteger(16, 22)
		local d = rng:NextInteger(16, 22)
		local h = rng:NextInteger(14, 19)
		local style = pickHouseStyle(zoneKey, i + innerCount)
		if style == "tower" then
			w = rng:NextInteger(12, 15)
			d = w
			h = rng:NextInteger(26, 34)
		end
		house(
			V3(x, y, z),
			w,
			d,
			h,
			wall:Lerp(C3(255, 255, 255), rng:NextNumber(0, 0.25)),
			roof,
			angle + math.pi + rng:NextNumber(-0.35, 0.35),
			style
		)
	end

	-- Торговые лотки с навесами на площади города
	for stall = 1, 3 do
		local sAngle = stall * 1.8 + rng:NextNumber(0, 0.3)
		local sDist = plazaRadius * 0.55
		local sx, sz = zone.x + math.cos(sAngle) * sDist, zone.z + math.sin(sAngle) * sDist
		local sy = WorldBuilder.terrainY(sx, sz)
		local sFrame = CFrame.new(sx, sy, sz) * CFrame.Angles(0, sAngle + math.pi / 2, 0)
		newPart(decor, "MarketTable", V3(5, 2.2, 2.4), sFrame * CFrame.new(0, 1.1, 0), WOOD, Enum.Material.WoodPlanks)
		newPart(decor, "MarketCrateA", V3(1.2, 0.9, 1.2), sFrame * CFrame.new(-1.4, 2.5, 0.2), C3(180, 130, 80), Enum.Material.WoodPlanks)
		newPart(decor, "MarketCrateB", V3(1.1, 0.8, 1.1), sFrame * CFrame.new(1.2, 2.45, -0.2), C3(210, 80, 70), Enum.Material.SmoothPlastic)
		-- Тканевый полосатый навес лотка
		wedge(decor, "StallCanopy", V3(5.4, 1.2, 3), sFrame * CFrame.new(0, 4.6, 0) * CFrame.Angles(0, math.pi, 0), stall % 2 == 0 and C3(220, 60, 60) or C3(50, 120, 200), Enum.Material.Fabric, false)
		column(decor, "StallPostL", sFrame:PointToWorldSpace(V3(-2.4, 0, 1.3)), 4.6, 0.25, WOOD, Enum.Material.Wood)
		column(decor, "StallPostR", sFrame:PointToWorldSpace(V3(2.4, 0, 1.3)), 4.6, 0.25, WOOD, Enum.Material.Wood)
	end

	townDetails(zoneKey, zoneKey ~= "Aiai" and zoneKey ~= "Masadora")
	local base = WorldBuilder.zonePoint(zoneKey, 0, 0)
	sign(decor, zone.name, base + V3(0, 24, 0), zone.color)
end

-- ===================== достопримечательности =====================

local function landmarkShiso()
	local zone = Zones.Shiso
	local base = WorldBuilder.zonePoint("Shiso", 0, 0)
	column(decor, "ShisoTrunk", base, 60, 12, C3(110, 78, 52), Enum.Material.Wood)
	newPart(decor, "ShisoCrown", V3(95, 55, 95), CFrame.new(base + V3(0, 72, 0)), C3(70, 170, 80), Enum.Material.Grass, Enum.PartType.Ball)
	for index = 1, 14 do
		local angle = index * 0.45
		local fruit = newPart(
			decor,
			"Fruit",
			V3(2.4, 2.4, 2.4),
			CFrame.new(base + V3(math.cos(angle) * 30, 58 + (index % 4) * 6, math.sin(angle) * 30)),
			C3(230, 60, 60),
			Enum.Material.SmoothPlastic,
			Enum.PartType.Ball
		)
		fruit.CanCollide = false
	end
	sign(decor, "Дерево Шисо — начало игры", base + V3(0, 30, -14), zone.color)

	local pad = Instance.new("SpawnLocation")
	pad.Name = "IslandSpawn"
	pad.Size = V3(10, 1, 10)
	pad.Position = V3(zone.x, WorldBuilder.terrainY(zone.x, zone.z + 42) + 0.5, zone.z + 42)
	pad.Anchored = true
	pad.Neutral = true
	pad.Enabled = true
	pad.Transparency = 0.4
	pad.Color = C3(120, 220, 255)
	pad.Material = Enum.Material.Neon
	pad.Parent = decor
	WorldBuilder.spawnPad = pad
end

--- Сказочный город Масадора: Дворец карт заклинаний с парящей картой и кристаллами маны.
local function landmarkMasadora()
	local base = WorldBuilder.zonePoint("Masadora", 0, 0)

	-- Центральный Дворец спелл-карт (3 яруса сказочного песчаника)
	local pColor = C3(240, 215, 175)
	local domeCyan = C3(45, 165, 215)
	local trimGold = C3(245, 205, 80)

	newPart(decor, "SpellTempleB1", V3(32, 14, 32), CFrame.new(base + V3(0, 7, 0)), pColor, Enum.Material.Cobblestone)
	newPart(decor, "SpellTempleB2", V3(24, 12, 24), CFrame.new(base + V3(0, 20, 0)), pColor, Enum.Material.Cobblestone)
	-- Бирюзовый купол
	newPart(decor, "TempleDome", V3(20, 16, 20), CFrame.new(base + V3(0, 32, 0)), domeCyan, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	column(decor, "TempleSpire", base + V3(0, 40, 0), 12, 0.8, trimGold, Enum.Material.Metal)

	-- Парящая гигантская карта заклинаний в воздухе над храмом
	local cardFrame = CFrame.new(base + V3(0, 54, 0)) * CFrame.Angles(0, 0.4, 0.1)
	local cardBody = newPart(decor, "FloatingSpellCard", V3(10, 15, 0.5), cardFrame, C3(30, 25, 50), Enum.Material.SmoothPlastic)
	newPart(decor, "CardBorder", V3(10.6, 15.6, 0.4), cardFrame, trimGold, Enum.Material.Neon)
	local runeDisc = newPart(decor, "CardRune", V3(0.5, 7, 7), cardFrame * CFrame.Angles(0, 0, math.pi / 2), C3(180, 110, 255), Enum.Material.Neon, Enum.PartType.Cylinder)
	runeDisc.CanCollide = false
	local cLight = Instance.new("PointLight")
	cLight.Color = C3(200, 140, 255)
	cLight.Range = 45
	cLight.Brightness = 2.4
	cLight.Parent = cardBody

	-- Кристаллы маны, растущие из мостовой
	local crystalColors = { C3(120, 210, 255), C3(210, 120, 255), C3(255, 215, 80) }
	for index = 1, 8 do
		local angle = index * math.pi / 4
		local cPos = base + V3(math.cos(angle) * 26, 0, math.sin(angle) * 26)
		local cY = WorldBuilder.terrainY(cPos.X, cPos.Z)
		local cr = newPart(
			decor,
			"ManaCrystal",
			V3(2.6, 9, 2.6),
			CFrame.new(cPos.X, cY + 3.8, cPos.Z) * CFrame.Angles(0.35, angle, 0.25),
			crystalColors[(index - 1) % #crystalColors + 1],
			Enum.Material.Neon
		)
		cr.CanCollide = false
		local p = Instance.new("PointLight")
		p.Color = cr.Color
		p.Range = 16
		p.Brightness = 1.4
		p.Parent = cr
	end
end

--- Лодка у причала. Корпус помечен тегом Bob: клиент слегка качает ближние лодки (Ambient.luau).
local function rowboat(position: Vector3, yaw: number, hull: Color3)
	local frame = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	local body = newPart(decor, "BoatHull", V3(4, 1.4, 9), frame, hull, Enum.Material.Wood)
	CollectionService:AddTag(body, "Bob")
	body:SetAttribute("BobPhase", rng:NextNumber(0, 6.28))
	local inner = newPart(decor, "BoatInner", V3(3, 0.3, 7.6), frame * CFrame.new(0, 0.6, 0), hull:Lerp(C3(255, 230, 190), 0.45), Enum.Material.WoodPlanks)
	inner.CanCollide = false
	newPart(decor, "BoatSeat", V3(3.2, 0.3, 0.9), frame * CFrame.new(0, 0.95, -1.2), WOOD, Enum.Material.Wood).CanCollide = false
	newPart(decor, "BoatOar", V3(0.25, 0.25, 6), frame * CFrame.new(2.1, 1.2, 0.5) * CFrame.Angles(0, 0.35, 0.25), C3(190, 160, 110), Enum.Material.Wood).CanCollide = false
	return body
end

--- Лодки по бокам причала зоны (направление — от центра острова к городу).
local function moorBoats(zoneKey: string, count: number)
	local zone = Zones[zoneKey]
	local direction = V3(zone.x, 0, zone.z).Unit
	local side = V3(-direction.Z, 0, direction.X)
	local yaw = math.atan2(-direction.X, -direction.Z)
	local colors = { C3(150, 90, 60), C3(70, 100, 150), C3(180, 150, 80), C3(120, 70, 80) }
	for index = 1, count do
		local along = 936 + (index % 2) * 12
		local lateral = (index % 2 == 0 and 1 or -1) * (9 + math.floor(index / 2) * 7)
		local pos = direction * along + side * lateral
		rowboat(V3(pos.X, -1.4, pos.Z), yaw, colors[(index - 1) % #colors + 1])
	end
end

--- Приморский пиратский порт Суфраби: полосатый маяк Рейзора и пиратский парусник.
local function landmarkSoufrabi()
	local zone = Zones.Soufrabi
	local lighthouse = WorldBuilder.zonePoint("Soufrabi", 42, -42)

	-- Маяк из чередующихся красно-белых ярусов
	local lhBase = 12
	for tier = 0, 5 do
		local tierH = 11
		local col = (tier % 2 == 0) and C3(245, 245, 248) or C3(215, 55, 55)
		local diam = lhBase * (1 - tier * 0.08)
		column(decor, "LhTier", lighthouse + V3(0, tier * tierH, 0), tierH, diam, col, Enum.Material.Concrete)
	end
	-- Фонарное помещение на вершине со смотровой галереей
	local topY = 66
	newPart(decor, "LhBalcony", V3(11, 1.2, 11), CFrame.new(lighthouse + V3(0, topY, 0)), C3(45, 48, 55), Enum.Material.Metal)
	local glassPart = column(decor, "LhGlass", lighthouse + V3(0, topY + 1.2, 0), 6.5, 7.5, C3(255, 245, 180), Enum.Material.Glass)
	glassPart.Transparency = 0.4
	local beacon = newPart(decor, "LhBeacon", V3(3, 3, 3), CFrame.new(lighthouse + V3(0, topY + 4.5, 0)), C3(255, 240, 160), Enum.Material.Neon, Enum.PartType.Ball)
	beacon.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = C3(255, 235, 160)
	light.Range = 85
	light.Brightness = 3
	light.Parent = beacon

	-- Причал и пиратский галеон Рейзора
	local direction = V3(zone.x, 0, zone.z).Unit
	for step = 0, 18 do
		local radius = 835 + step * 5
		local pos = direction * radius
		newPart(decor, "Plank", V3(8, 0.6, 5), CFrame.new(pos.X, 0.6, pos.Z) * CFrame.Angles(0, math.atan2(-direction.X, -direction.Z), 0), WOOD, Enum.Material.WoodPlanks)
	end
	moorBoats("Soufrabi", 4)

	local shipPos = direction * 980
	local shipYaw = math.atan2(-direction.X, -direction.Z) + math.pi / 2
	local shipFrame = CFrame.new(shipPos.X, 0, shipPos.Z) * CFrame.Angles(0, shipYaw, 0)
	newPart(decor, "ShipHull", V3(15, 7, 38), shipFrame, C3(85, 55, 35), Enum.Material.Wood)
	newPart(decor, "ShipDeck", V3(13, 0.6, 36), shipFrame * CFrame.new(0, 3.6, 0), C3(165, 125, 80), Enum.Material.WoodPlanks)
	for mastIdx = -1, 1 do
		local mPos = shipFrame:PointToWorldSpace(V3(0, 3.5, mastIdx * 11))
		column(decor, "Mast", mPos, 28, 1.2, WOOD, Enum.Material.Wood)
		newPart(decor, "Sail", V3(12, 14, 0.3), CFrame.new(mPos + V3(0, 14, 0)) * CFrame.Angles(0, shipYaw, 0), C3(240, 235, 220), Enum.Material.Fabric)
	end
	newPart(decor, "PirateFlag", V3(0.2, 5, 8), CFrame.new(shipFrame:PointToWorldSpace(V3(0, 30, 11))), C3(20, 20, 25), Enum.Material.Fabric)
end

--- Казино Дориаса: неоновый дворец азарта.
local function landmarkDorias()
	local zone = Zones.Dorias
	local building = WorldBuilder.zonePoint("Dorias", 0, 38)
	newPart(decor, "Casino", V3(54, 28, 40), CFrame.new(building + V3(0, 14, 0)), C3(38, 22, 44), Enum.Material.Concrete)
	newPart(decor, "Neon1", V3(56, 2, 0.6), CFrame.new(building + V3(0, 26, -20.4)), C3(255, 60, 120), Enum.Material.Neon)
	newPart(decor, "Neon2", V3(56, 2, 0.6), CFrame.new(building + V3(0, 3, -20.4)), C3(255, 215, 60), Enum.Material.Neon)
	sign(decor, "КАЗИНО ДОРИАСА — рулетка и дуэль с Королём", building + V3(0, 34, -20), zone.color)
	newPart(decor, "Roulette", V3(0.8, 11, 11), CFrame.new(zone.x + 12, WorldBuilder.terrainY(zone.x + 12, zone.z - 8) + 3, zone.z - 8) * CFrame.Angles(0, 0, math.pi / 2), C3(20, 95, 50), Enum.Material.Wood, Enum.PartType.Cylinder)
end

--- Королевский Замок Лимейро: резиденция Двана и Листа, бастионы, герса ворот и помост викторины.
local function landmarkLimeiro()
	local keep = WorldBuilder.zonePoint("Limeiro", 0, -48)
	local granite = C3(210, 205, 195)
	local darkSlate = C3(65, 68, 75)
	local bannerBlue = C3(25, 55, 135)
	local goldTrim = C3(245, 200, 70)

	-- Центральный донжон замка (высота 55 студов)
	newPart(decor, "CastleKeep", V3(48, 56, 42), CFrame.new(keep + V3(0, 28, 0)), granite, Enum.Material.Cobblestone)
	-- Черепичная остроконечная крыша донжона
	wedge(decor, "KeepRoofF", V3(50, 16, 22), CFrame.new(keep + V3(0, 64, 11)) * CFrame.Angles(0, math.pi, 0), darkSlate, Enum.Material.Slate, true)
	wedge(decor, "KeepRoofB", V3(50, 16, 22), CFrame.new(keep + V3(0, 64, -11)), darkSlate, Enum.Material.Slate, true)

	-- Две могучие круглые бастионные башни по бокам главных ворот (высота 80 студов!)
	for _, sx in { -1, 1 } do
		local bPos = keep + V3(sx * 28, 0, 20)
		column(decor, "BastionTower", bPos, 78, 14, granite, Enum.Material.Cobblestone)
		newPart(decor, "TowerParapet", V3(16, 1.5, 16), CFrame.new(bPos + V3(0, 78, 0)), darkSlate, Enum.Material.Slate)
		-- Остроконечная коническая крыша башни
		cylinder(decor, "TowerCone", CFrame.new(bPos + V3(0, 84, 0)), 12, 14.5, darkSlate, Enum.Material.Slate, true)
		column(decor, "TowerFinial", bPos + V3(0, 92, 0), 6, 0.7, goldTrim, Enum.Material.Metal)

		-- Королевское сине-золотое знамя на каждой башне
		local banner = newPart(decor, "TowerBanner", V3(3.4, 18, 0.3), CFrame.new(bPos + V3(0, 52, 7.5)), bannerBlue, Enum.Material.Fabric)
		banner.CanCollide = false
		local bannerGold = newPart(decor, "BannerGold", V3(3.4, 1.2, 0.35), CFrame.new(bPos + V3(0, 43, 7.5)), goldTrim, Enum.Material.Fabric)
		bannerGold.CanCollide = false
	end

	-- Главный портал замка с каменной аркой и железной герсой (порткулиса)
	local gatePos = keep + V3(0, 0, 21)
	newPart(decor, "GateArchL", V3(2.5, 20, 3), CFrame.new(gatePos + V3(-8, 10, 0)), darkSlate, Enum.Material.Cobblestone)
	newPart(decor, "GateArchR", V3(2.5, 20, 3), CFrame.new(gatePos + V3(8, 10, 0)), darkSlate, Enum.Material.Cobblestone)
	newPart(decor, "GateLintel", V3(18, 3.5, 3), CFrame.new(gatePos + V3(0, 21.5, 0)), darkSlate, Enum.Material.Cobblestone)
	-- Железная решётка
	for b = -3, 3 do
		local bar = newPart(decor, "PortcullisBar", V3(0.35, 19, 0.35), CFrame.new(gatePos + V3(b * 2, 10, 0.2)), C3(40, 42, 50), Enum.Material.Metal)
		bar.CanCollide = false
	end

	-- Помост финальной викторины перед замком с красной дорожкой и золотыми чашами огня
	local quizPos = keep + V3(0, 0, 42)
	newPart(decor, "QuizPlatform", V3(28, 2, 22), CFrame.new(quizPos + V3(0, 1, 0)), C3(180, 175, 165), Enum.Material.Cobblestone)
	newPart(decor, "RedCarpet", V3(8, 0.2, 22), CFrame.new(quizPos + V3(0, 2.1, 0)), C3(185, 35, 45), Enum.Material.Fabric)
	for _, sx in { -1, 1 } do
		local fPos = quizPos + V3(sx * 12, 2, 0)
		column(decor, "BrazierPedestal", fPos, 4.5, 2.2, darkSlate, Enum.Material.Cobblestone)
		local brazierFire = newPart(decor, "BrazierFire", V3(2.2, 2.2, 2.2), CFrame.new(fPos + V3(0, 5.2, 0)), C3(255, 140, 40), Enum.Material.Neon, Enum.PartType.Ball)
		brazierFire.CanCollide = false
		local fLight = Instance.new("PointLight")
		fLight.Color = C3(255, 160, 50)
		fLight.Range = 28
		fLight.Brightness = 2.5
		fLight.Parent = brazierFire
	end

	sign(decor, "Королевский Замок Двана и Листа", keep + V3(0, 78, 22), C3(255, 235, 150))
end

local function landmarkPort()
	local zone = Zones.Port
	local tower = WorldBuilder.zonePoint("Port", 58, 52)
	column(decor, "ElenaTower", tower, 78, 14, C3(195, 215, 235), Enum.Material.Concrete)
	local ring = newPart(decor, "PortalRing", V3(1.5, 22, 22), CFrame.new(tower + V3(0, 86, 0)) * CFrame.Angles(0, 0, math.pi / 2), C3(120, 200, 255), Enum.Material.Neon, Enum.PartType.Cylinder)
	ring.Transparency = 0.35
	ring.CanCollide = false
	sign(decor, "Башня выхода из игры", tower + V3(0, 94, 0), C3(160, 220, 255))
	moorBoats("Port", 3)
	local direction = V3(zone.x, 0, zone.z).Unit
	for step = 0, 17 do
		local pos = direction * (840 + step * 5)
		newPart(decor, "Plank", V3(8, 0.6, 5), CFrame.new(pos.X, 0.6, pos.Z) * CFrame.Angles(0, math.atan2(-direction.X, -direction.Z), 0), WOOD, Enum.Material.WoodPlanks)
	end
end

--- Сцена ежемесячного фестиваля и конкурса Антокибы.
local function landmarkAntokiba()
	local stage = WorldBuilder.zonePoint("Antokiba", 0, -45)

	-- Деревянный театральный помост сцены
	newPart(decor, "ContestStage", V3(42, 3, 26), CFrame.new(stage + V3(0, 1.5, 0)), C3(165, 120, 75), Enum.Material.WoodPlanks)
	-- Задний театральный занавес с красным бархатом
	newPart(decor, "StageCurtain", V3(40, 16, 0.6), CFrame.new(stage + V3(0, 11, -12)), C3(185, 35, 45), Enum.Material.Fabric)
	newPart(decor, "StageValance", V3(42, 2.5, 1.2), CFrame.new(stage + V3(0, 18, -11.5)), GOLD_ACCENT, Enum.Material.Fabric)

	-- Микрофонная стойка для Распорядителя
	column(decor, "MicStand", stage + V3(0, 3, 4), 4.2, 0.2, DARK_METAL, Enum.Material.Metal)
	newPart(decor, "MicHead", V3(0.5, 0.7, 0.5), CFrame.new(stage + V3(0, 7.3, 4)), C3(200, 200, 210), Enum.Material.Metal, Enum.PartType.Ball)

	-- Праздничные гирлянды флажков вокруг сцены
	for index = 1, 6 do
		local angle = index * math.pi / 3
		local polePos = stage + V3(math.cos(angle) * 24, 0, math.sin(angle) * 24)
		column(decor, "FestivalPole", polePos, 16, 0.6, WOOD, Enum.Material.Wood)
		newPart(decor, "Pennant", V3(0.2, 4, 3), CFrame.new(polePos + V3(0, 13, 0)), (index % 2 == 0) and C3(240, 70, 70) or C3(250, 210, 60), Enum.Material.Fabric)
	end
	sign(decor, "Ежемесячный конкурс Антокибы", stage + V3(0, 21, -12), C3(255, 220, 120))
end

--- Город любви Аиай: Гигантское парящее сердце в небе и романтичный фонтан Купидона.
local function landmarkAiai()
	local base = WorldBuilder.zonePoint("Aiai", 0, 0)

	-- Гигантское парящее розовое сердце в небе над городом (символ Аиай из аниме!)
	local skyY = base.Y + 70
	local heartCenter = V3(base.X, skyY, base.Z)
	local hCol = C3(255, 65, 145)

	-- Форма сердца: две сферы сверху и перевёрнутый клин снизу
	local h1 = newPart(decor, "SkyHeartL", V3(15, 15, 15), CFrame.new(heartCenter + V3(-6.5, 5, 0)), hCol, Enum.Material.Neon, Enum.PartType.Ball)
	local _h2 = newPart(decor, "SkyHeartR", V3(15, 15, 15), CFrame.new(heartCenter + V3(6.5, 5, 0)), hCol, Enum.Material.Neon, Enum.PartType.Ball)
	local hWedge = wedge(decor, "SkyHeartWedge", V3(16, 16, 23), CFrame.new(heartCenter + V3(0, -3.5, 0)) * CFrame.Angles(0, math.pi / 2, math.pi), hCol, Enum.Material.Neon, false)

	-- Золотистый нимб вокруг сердца
	local halo = column(decor, "HeartHalo", heartCenter + V3(0, 2, 0), 1.2, 34, GOLD_ACCENT, Enum.Material.Neon)
	halo.CanCollide = false

	-- Розовый источник света над городом
	local hLight = Instance.new("PointLight")
	hLight.Color = C3(255, 120, 185)
	hLight.Range = 120
	hLight.Brightness = 2.8
	hLight.Parent = h1

	-- Падающие частицы лепестков роз над городом
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "LovePetals"
	emitter.Rate = 6
	emitter.Lifetime = NumberRange.new(8, 14)
	emitter.Speed = NumberRange.new(1.2, 2.5)
	emitter.SpreadAngle = Vector2.new(45, 45)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(0.5, 1.4),
		NumberSequenceKeypoint.new(1, 0.9),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.8, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(C3(255, 130, 180))
	emitter.Acceleration = V3(0.2, -1.8, 0.2)
	emitter.Parent = hWedge

	-- Мраморный фонтан Купидона на площади города
	column(decor, "FountainBase", base, 2.4, 18, C3(245, 240, 235), Enum.Material.Marble)
	column(decor, "FountainWater", base + V3(0, 1.8, 0), 0.3, 16.5, C3(50, 160, 215), Enum.Material.Glass)
	column(decor, "FountainPillar", base + V3(0, 2.4, 0), 5.5, 3.2, C3(245, 240, 235), Enum.Material.Marble)
	column(decor, "FountainTier2", base + V3(0, 7.5, 0), 1.2, 9, C3(245, 240, 235), Enum.Material.Marble)
	newPart(decor, "CupidStatue", V3(2.5, 3.8, 2.5), CFrame.new(base + V3(0, 10.5, 0)), GOLD_ACCENT, Enum.Material.Metal)
end

--- Горная деревня бандитов: частокол, сторожевые вышки и лагерный костёр.
local function landmarkBandits()
	local base = WorldBuilder.zonePoint("Bandits", 0, 0)

	-- Большой лагерный костёр
	local fire = newPart(decor, "Campfire", V3(4, 2, 4), CFrame.new(base + V3(0, 1, 0)), C3(255, 125, 35), Enum.Material.Neon, Enum.PartType.Ball)
	fire.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = C3(255, 145, 55)
	light.Range = 36
	light.Brightness = 2.8
	light.Parent = fire

	-- Брёвна для сидения вокруг костра
	for i = 1, 4 do
		local bAngle = i * math.pi / 2
		local bPos = base + V3(math.cos(bAngle) * 7.5, 0.6, math.sin(bAngle) * 7.5)
		column(decor, "SitLog", bPos, 6, 1.3, DARK_WOOD, Enum.Material.Wood)
	end
end

--- Руины древнего города: обломки колонн, арка, замшелые камни и разрушенная стена.
local function landmarkRuins()
	local base = WorldBuilder.zonePoint("Ruins", 0, 0)
	local stone = C3(150, 148, 140)
	local dark = C3(112, 112, 108)
	local moss = C3(86, 118, 70)

	-- Растрескавшиеся каменные плиты
	for _, spec in { { -10, -6, 14, 12 }, { 6, 4, 16, 14 }, { 0, -14, 10, 8 } } do
		local slab = newPart(
			decor,
			"RuinSlab",
			V3(spec[3], 0.8, spec[4]),
			CFrame.new(base + V3(spec[1], 0.4, spec[2])) * CFrame.Angles(0, rng:NextNumber(-0.08, 0.08), 0),
			stone,
			Enum.Material.Cobblestone
		)
		slab.CanCollide = true
	end

	-- Колоннада: часть колонн уцелела, часть обрушена
	local columns = {
		{ -13, -10, 15 },
		{ -13, 10, 15 },
		{ 13, -10, 9 },
		{ 13, 10, 6 },
		{ 0, -17, 7 },
	}
	for index, spec in columns do
		local x, z, height = spec[1], spec[2], spec[3]
		local pos = base + V3(x, 0, z)
		newPart(decor, "RuinPlinth", V3(4.4, 1, 4.4), CFrame.new(pos + V3(0, 0.5, 0)), dark, Enum.Material.Cobblestone)
		column(decor, "RuinColumn", pos + V3(0, 1, 0), height, 2.6, stone, Enum.Material.Cobblestone)
		if height >= 12 then
			newPart(decor, "RuinCapital", V3(4.2, 1.2, 4.2), CFrame.new(pos + V3(0, height + 1.6, 0)), stone, Enum.Material.Cobblestone)
		end
		if index % 2 == 1 then
			local patch = newPart(
				decor,
				"RuinMoss",
				V3(2.4, 0.5, 2.4),
				CFrame.new(pos + V3(rng:NextNumber(-0.8, 0.8), 0.35, rng:NextNumber(-0.8, 0.8))),
				moss,
				Enum.Material.Grass,
				Enum.PartType.Ball
			)
			patch.CanCollide = false
		end
	end

	-- Арка между двумя высокими колоннами
	newPart(decor, "RuinArch", V3(3.6, 2.2, 27), CFrame.new(base + V3(-13, 16.2, 0)), stone, Enum.Material.Cobblestone)

	-- Обрушенные барабаны колонн
	for _ = 1, 5 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local center = base + V3(rng:NextNumber(-10, 10), 1.3, rng:NextNumber(-14, 12))
		local half = V3(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(2.5, 4.0)
		limb("FallenDrum", center - half, center + half, 2.4, stone, Enum.Material.Cobblestone)
	end

	-- Разрушенная стена
	for index = 1, 4 do
		local h = rng:NextNumber(4, 9)
		newPart(
			decor,
			"RuinWall",
			V3(2.4, h, 5.2),
			CFrame.new(V3(base.X + 18, base.Y + h / 2, base.Z - 12 + index * 5)) * CFrame.Angles(0, rng:NextNumber(-0.1, 0.1), 0),
			stone,
			Enum.Material.Cobblestone
		)
	end

	-- Замшелые валуны вокруг
	for _ = 1, 8 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(8, 24)
		rock(base + V3(math.cos(angle) * radius, 0, math.sin(angle) * radius), rng:NextNumber(1.5, 4.0), dark)
	end
end

local function scatter()
	-- Лес: плотные деревья
	local forest = Zones.Forest
	for _ = 1, 150 do
		local point = Vector3.new(0, 0, 0)
		local angle = rng:NextNumber(0, 6.28)
		local radius = forest.r * math.sqrt(rng:NextNumber(0, 1))
		point = V3(forest.x + math.cos(angle) * radius, 0, forest.z + math.sin(angle) * radius)
		tree(V3(point.X, WorldBuilder.terrainY(point.X, point.Z), point.Z), rng:NextNumber(0.9, 1.7))
	end
	-- Бунзен: деревья по краю
	local bunzen = Zones.Bunzen
	for _ = 1, 30 do
		local angle = rng:NextNumber(0, 6.28)
		local radius = bunzen.r * rng:NextNumber(0.95, 1.25)
		local x, z = bunzen.x + math.cos(angle) * radius, bunzen.z + math.sin(angle) * radius
		tree(V3(x, WorldBuilder.terrainY(x, z), z), rng:NextNumber(1.1, 1.8))
	end
	-- Топи: сухие деревья
	local swamp = Zones.Swamp
	for _ = 1, 22 do
		local angle = rng:NextNumber(0, 6.28)
		local radius = swamp.r * math.sqrt(rng:NextNumber(0, 1))
		local x, z = swamp.x + math.cos(angle) * radius, swamp.z + math.sin(angle) * radius
		tree(V3(x, WorldBuilder.terrainY(x, z), z), rng:NextNumber(0.9, 1.4), true)
	end
	-- Луга: цветы на тонких стеблях и кустики травы
	local meadow = Zones.Meadow
	for _ = 1, 90 do
		local angle = rng:NextNumber(0, 6.28)
		local radius = meadow.r * math.sqrt(rng:NextNumber(0, 1))
		local x, z = meadow.x + math.cos(angle) * radius, meadow.z + math.sin(angle) * radius
		local y = WorldBuilder.terrainY(x, z)
		local stem = newPart(decor, "FlowerStem", V3(0.12, 1.3, 0.12), CFrame.new(x, y + 0.65, z), C3(82, 116, 58), Enum.Material.Grass)
		stem.CanCollide = false
		local bloom = newPart(
			decor,
			"Flower",
			V3(0.7, 0.5, 0.7),
			CFrame.new(x, y + 1.35, z),
			Color3.fromHSV(rng:NextNumber(0, 1), 0.55, 0.95),
			Enum.Material.SmoothPlastic,
			Enum.PartType.Ball
		)
		bloom.CanCollide = false
	end

	-- Пучки травы по лугам, опушке леса и окраинам городов
	local function grassTuft(x: number, z: number)
		local y = WorldBuilder.terrainY(x, z)
		for blade = 1, 2 do
			local height = rng:NextNumber(1.1, 2.2)
			local bladePart = newPart(
				decor,
				"GrassBlade",
				V3(0.16, height, 0.16),
				CFrame.new(x + rng:NextNumber(-0.5, 0.5), y + height / 2, z + rng:NextNumber(-0.5, 0.5))
					* CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(0, 6.28), rng:NextNumber(-0.12, 0.12)),
				C3(78, 112, 52),
				Enum.Material.Grass
			)
			bladePart.CanCollide = false
		end
	end
	for _ = 1, 150 do
		local angle = rng:NextNumber(0, 6.28)
		local radius = meadow.r * math.sqrt(rng:NextNumber(0, 1))
		grassTuft(meadow.x + math.cos(angle) * radius, meadow.z + math.sin(angle) * radius)
	end
	for _ = 1, 80 do
		local angle = rng:NextNumber(0, 6.28)
		local radius = forest.r * rng:NextNumber(0.9, 1.15)
		grassTuft(forest.x + math.cos(angle) * radius, forest.z + math.sin(angle) * radius)
	end

	-- Кусты на лугах и в лесу: пышные, с торчащими ветками
	for index = 1, 70 do
		local zone = index % 2 == 0 and meadow or forest
		local angle = rng:NextNumber(0, 6.28)
		local radius = zone.r * math.sqrt(rng:NextNumber(0, 1))
		local x, z = zone.x + math.cos(angle) * radius, zone.z + math.sin(angle) * radius
		bush(V3(x, 0, z), rng:NextNumber(0.8, 1.6))
	end

	-- Камыш по топям и у кромки воды
	for _ = 1, 70 do
		local angle = rng:NextNumber(0, 6.28)
		local radius = swamp.r * math.sqrt(rng:NextNumber(0, 1))
		local x, z = swamp.x + math.cos(angle) * radius, swamp.z + math.sin(angle) * radius
		local y = WorldBuilder.terrainY(x, z)
		if y > -0.8 then
			for reed = 1, 2 do
				local height = rng:NextNumber(2.4, 4.4)
				local stem = newPart(
					decor,
					"Reed",
					V3(0.12, height, 0.12),
					CFrame.new(x + rng:NextNumber(-0.6, 0.6), y + height / 2, z + rng:NextNumber(-0.6, 0.6))
						* CFrame.Angles(rng:NextNumber(-0.08, 0.08), 0, rng:NextNumber(-0.08, 0.08)),
					C3(126, 142, 78),
					Enum.Material.Grass
				)
				stem.CanCollide = false
			end
		end
	end
	-- Бесплодные земли и скалы: валуны
	for _, zoneKey in { "Barren", "Cliffs", "Cave" } do
		local zone = Zones[zoneKey]
		for _ = 1, 22 do
			local angle = rng:NextNumber(0, 6.28)
			local radius = zone.r * math.sqrt(rng:NextNumber(0, 1))
			local x, z = zone.x + math.cos(angle) * radius, zone.z + math.sin(angle) * radius
			rock(V3(x, WorldBuilder.terrainY(x, z), z), rng:NextNumber(3, 9), zone.color:Lerp(C3(90, 90, 95), 0.4))
		end
	end
	-- Побережье: пальмы и валуны
	for index = 1, 60 do
		local angle = (index / 60) * math.pi * 2 + rng:NextNumber(-0.04, 0.04)
		local radius = rng:NextNumber(852, 872)
		local x, z = math.cos(angle) * radius, math.sin(angle) * radius
		if index % 3 == 0 then
			rock(V3(x, WorldBuilder.terrainY(x, z), z), rng:NextNumber(3, 6))
		else
			palm(V3(x, WorldBuilder.terrainY(x, z), z), rng:NextNumber(0.8, 1.2))
		end
	end
end

-- ===================== тропы и указатели =====================

-- пары городов, между которыми проложены тропы цвета земли
local TRAILS = {
	{ "Shiso", "Antokiba" },
	{ "Antokiba", "Rubicuta" },
	{ "Antokiba", "Masadora" },
	{ "Antokiba", "Port" },
	{ "Antokiba", "Limeiro" },
	{ "Rubicuta", "Aiai" },
	{ "Aiai", "Soufrabi" },
	{ "Aiai", "Bunzen" },
	{ "Masadora", "Dorias" },
	{ "Dorias", "Bandits" },
	{ "Bandits", "Limeiro" },
	{ "Limeiro", "Bunzen" },
}

local function shortName(zoneKey: string): string
	local name = Zones[zoneKey].name
	local cut = string.find(name, " — ", 1, true)
	return cut and string.sub(name, 1, cut - 1) or name
end

--- Отрезок тропы: траву красим землёй (ландшафт, без деталей — ничего не нагружает).
local function paintTrail(from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	local steps = math.max(1, math.ceil(length / 8))
	for index = 0, steps do
		local p = from:Lerp(to, index / steps)
		local region = Region3.new(V3(p.X - 5, -8, p.Z - 5), V3(p.X + 5, 4, p.Z + 5)):ExpandToGrid(4)
		terrain:ReplaceMaterial(region, 4, Enum.Material.Grass, Enum.Material.Ground)
		terrain:ReplaceMaterial(region, 4, Enum.Material.LeafyGrass, Enum.Material.Ground)
	end
end

--- Указатель у дороги: столб и табличка лицом к городу, откуда идёт путник.
local function signpost(zoneKey: string, otherKey: string)
	local zone, other = Zones[zoneKey], Zones[otherKey]
	local direction = V3(other.x - zone.x, 0, other.z - zone.z)
	local distance = direction.Magnitude
	direction = direction.Unit
	local side = V3(-direction.Z, 0, direction.X)
	local radius = zone.r * 0.95 + 10
	local x = zone.x + direction.X * radius + side.X * 9
	local z = zone.z + direction.Z * radius + side.Z * 9
	local base = V3(x, WorldBuilder.terrainY(x, z), z)
	column(decor, "SignPost", base, 8, 0.8, WOOD, Enum.Material.Wood)
	local board = newPart(
		decor,
		"SignBoard",
		V3(8, 3, 0.5),
		CFrame.lookAt(base + V3(0, 7, 0), base + V3(0, 7, 0) - direction),
		C3(150, 112, 70),
		Enum.Material.WoodPlanks
	)
	board.CanCollide = false
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.MaxDistance = 90
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = C3(45, 28, 12)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = ("→ %s\n%d м"):format(shortName(otherKey), math.floor(distance))
	label.Parent = gui
end

--- Невысокий забор по окраине города; в сторону каждой тропы оставлен проход.
local function fenceTown(zoneKey: string, color: Color3)
	local zone = Zones[zoneKey]
	local gaps: { number } = {}
	for _, pair in TRAILS do
		local otherKey = ""
		if pair[1] == zoneKey then
			otherKey = pair[2]
		elseif pair[2] == zoneKey then
			otherKey = pair[1]
		end
		local other = Zones[otherKey]
		if other then
			table.insert(gaps, math.atan2(other.z - zone.z, other.x - zone.x))
		end
	end
	local radius = zone.r * 0.97
	local count = math.floor(radius * math.pi * 2 / 7)
	local previous: Vector3? = nil
	for index = 0, count do
		local angle = (index / count) * math.pi * 2
		local open = false
		for _, gap in gaps do
			-- разность углов с учётом обхода круга
			local delta = math.abs((angle - gap + math.pi) % (math.pi * 2) - math.pi)
			if delta < 0.32 then
				open = true
				break
			end
		end
		local x, z = zone.x + math.cos(angle) * radius, zone.z + math.sin(angle) * radius
		local point = V3(x, WorldBuilder.terrainY(x, z), z)
		if open or point.Y < -0.8 then
			previous = nil
		else
			newPart(decor, "FencePost", V3(0.7, 3.4, 0.7), CFrame.new(point + V3(0, 1.7, 0)), color, Enum.Material.Wood)
			if previous then
				local mid = (previous + point) / 2 + V3(0, 2.5, 0)
				local rail = newPart(decor, "FenceRail", V3(0.3, 0.5, (point - previous).Magnitude), CFrame.lookAt(mid, point + V3(0, 2.5, 0)), color, Enum.Material.Wood)
				rail.CanCollide = false
			end
			previous = point
		end
	end
end

local function buildTrails()
	for _, pair in TRAILS do
		local a, b = Zones[pair[1]], Zones[pair[2]]
		local direction = V3(b.x - a.x, 0, b.z - a.z).Unit
		local plazaA = math.min(26, a.r * 0.28)
		local plazaB = math.min(26, b.r * 0.28)
		paintTrail(V3(a.x, 0, a.z) + direction * plazaA, V3(b.x, 0, b.z) - direction * plazaB)
		signpost(pair[1], pair[2])
		signpost(pair[2], pair[1])
	end
	fenceTown("Rubicuta", C3(210, 190, 160))
	fenceTown("Aiai", C3(250, 240, 240))
	fenceTown("Bunzen", C3(130, 100, 70))
	fenceTown("Bandits", C3(95, 72, 50))
end

-- ===================== реальный мир (лобби) =====================

local function buildLobby()
	local origin = Config.RealWorldPos
	local lobby = Instance.new("Folder")
	lobby.Name = "RealWorld"
	lobby.Parent = world
	newPart(lobby, "Floor", V3(70, 2, 70), CFrame.new(origin), C3(235, 235, 240), Enum.Material.Marble)
	for _, wall in { { V3(70, 22, 2), V3(0, 12, -35) }, { V3(70, 22, 2), V3(0, 12, 35) }, { V3(2, 22, 70), V3(-35, 12, 0) }, { V3(2, 22, 70), V3(35, 12, 0) } } do
		local part = newPart(lobby, "Wall", wall[1], CFrame.new(origin + wall[2]), C3(215, 220, 230), Enum.Material.SmoothPlastic)
		part.Transparency = 0.2
	end
	newPart(lobby, "Ceiling", V3(70, 2, 70), CFrame.new(origin + V3(0, 23, 0)), C3(235, 235, 240), Enum.Material.SmoothPlastic)
	local light = newPart(lobby, "Light", V3(30, 0.4, 30), CFrame.new(origin + V3(0, 21.8, 0)), C3(255, 250, 235), Enum.Material.Neon)
	light.CanCollide = false
	-- крыша закрывает солнце: освещаем комнату изнутри
	for _, offset in { V3(0, -4, 0), V3(-20, -4, -20), V3(20, -4, 20) } do
		local lamp = Instance.new("PointLight")
		lamp.Brightness = 1.6
		lamp.Range = 60
		lamp.Color = C3(255, 246, 228)
		local holder = newPart(lobby, "LampPoint", V3(0.4, 0.4, 0.4), CFrame.new(origin + V3(0, 20, 0) + offset), C3(255, 250, 235), Enum.Material.Neon)
		holder.CanCollide = false
		holder.CanQuery = false
		holder.Transparency = 1
		lamp.Parent = holder
	end

	local console = newPart(lobby, "JoyStation", V3(10, 7, 6), CFrame.new(origin + V3(0, 4.5, -22)), C3(40, 44, 60), Enum.Material.Metal)
	local screen = newPart(lobby, "Screen", V3(8, 4, 0.4), CFrame.new(origin + V3(0, 6, -18.8)), C3(80, 220, 140), Enum.Material.Neon)
	screen.CanCollide = false
	sign(lobby, "JoyStation — Greed Island", origin + V3(0, 13, -22), C3(120, 255, 180))

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EnterGame"
	prompt.ActionText = "Войти в Greed Island"
	prompt.ObjectText = "JoyStation"
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = console
	WorldBuilder.joyPrompt = prompt

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = V3(8, 1, 8)
	spawn.Position = origin + V3(0, 1.5, 8)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Enabled = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = lobby
	WorldBuilder.lobbySpawn = spawn
end

--- Вода, свет, реалистичная атмосфера и кинематографичная цветокоррекция в духе аниме Greed Island.
function WorldBuilder.styleScene()
	terrain.WaterColor = C3(24, 88, 116) -- глубокая морская вода с бирюзовым оттенком
	terrain.WaterTransparency = 0.38
	terrain.WaterReflectance = 0.55
	terrain.WaterWaveSize = 0.24
	terrain.WaterWaveSpeed = 7
	pcall(function()
		game:GetService("MaterialService").Use2022Materials = true -- объёмные PBR-материалы 2022+
	end)
	pcall(function()
		terrain.Decoration = true -- анимированная 3D-трава на террейне
	end)
	-- Естественная палитра материалов вместо кислотных стандартных цветов
	pcall(function()
		terrain:SetMaterialColor(Enum.Material.Grass, C3(94, 126, 64))
		terrain:SetMaterialColor(Enum.Material.LeafyGrass, C3(76, 112, 54))
		terrain:SetMaterialColor(Enum.Material.Sand, C3(206, 190, 148))
		terrain:SetMaterialColor(Enum.Material.Rock, C3(112, 112, 118))
		terrain:SetMaterialColor(Enum.Material.Slate, C3(96, 98, 104))
		terrain:SetMaterialColor(Enum.Material.Ground, C3(112, 94, 72))
		terrain:SetMaterialColor(Enum.Material.Mud, C3(82, 70, 54))
		terrain:SetMaterialColor(Enum.Material.Sandstone, C3(188, 160, 112))
		terrain:SetMaterialColor(Enum.Material.Cobblestone, C3(136, 132, 124))
		terrain:SetMaterialColor(Enum.Material.Concrete, C3(158, 156, 148))
	end)

	pcall(function()
		Lighting.Technology = Enum.Technology.Future -- мягкие тени от объектов, блики PBR и отражения
	end)
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.35
	Lighting.ClockTime = 15.6 -- послеполуденное солнце с длинными мягкими тенями
	Lighting.Brightness = 2.15
	Lighting.ExposureCompensation = 0.08
	Lighting.EnvironmentDiffuseScale = 0.55
	Lighting.EnvironmentSpecularScale = 0.55
	Lighting.GeographicLatitude = 34
	Lighting.OutdoorAmbient = C3(112, 126, 142) -- прохладный небесный заполняющий свет
	Lighting.Ambient = C3(62, 66, 74)
	Lighting.ColorShift_Top = C3(255, 236, 205) -- тёплый солнечный свет
	Lighting.ColorShift_Bottom = C3(118, 136, 110) -- отсвет травы и листвы

	local function effect(className: string, props: { [string]: any }): Instance
		local existing = Lighting:FindFirstChildOfClass(className)
		if existing then
			existing:Destroy()
		end
		local instance = Instance.new(className)
		for name, value in props do
			(instance :: any)[name] = value
		end
		instance.Parent = Lighting
		return instance
	end

	-- Лёгкая естественная дымка у горизонта
	effect("Atmosphere", {
		Density = 0.24,
		Offset = 0.12,
		Color = C3(186, 208, 232),
		Decay = C3(255, 214, 178),
		Glare = 0.18,
		Haze = 0.9,
	})
	-- Аккуратное свечение окон, магии, карт и солнечных бликов
	effect("BloomEffect", {
		Intensity = 0.2,
		Size = 22,
		Threshold = 1.05,
	})
	-- Тонкие солнечные лучи сквозь кроны Дерева Шисо и башни городов
	effect("SunRaysEffect", {
		Intensity = 0.07,
		Spread = 0.8,
	})
	-- Умеренная цветокоррекция: живые, но не кислотные цвета
	effect("ColorCorrectionEffect", {
		Saturation = 0.1,
		Contrast = 0.1,
		Brightness = 0,
		TintColor = C3(255, 250, 244),
	})
	-- Кинематографичная глубина резкости: персонаж чёткий, горы вдали мягкие
	effect("DepthOfFieldEffect", {
		FocusDistance = 55,
		InFocusRadius = 90,
		NearIntensity = 0,
		FarIntensity = 0.1,
	})

	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.45
	clouds.Density = 0.55
	clouds.Color = C3(255, 255, 255)
	clouds.Parent = terrain
end

function WorldBuilder.build()
	world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace
	decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = world

	-- Лобби строим первым: даже если ландшафт или поздний декор упадёт, игрок попадёт в комнату.
	buildLobby()

	-- мир строится после Terrain: рэйкасты по земле не должны упираться в уже построенное
	buildTerrain()

	WorldBuilder.styleScene()

	buildTown("Antokiba", C3(240, 220, 170), C3(180, 90, 70))
	buildTown("Rubicuta", C3(230, 200, 190), C3(190, 50, 60))
	buildTown("Masadora", C3(190, 175, 220), C3(100, 70, 160))
	buildTown("Aiai", C3(250, 215, 225), C3(230, 100, 150))
	buildTown("Soufrabi", C3(200, 205, 215), C3(60, 80, 110))
	buildTown("Dorias", C3(200, 160, 170), C3(110, 20, 40), 8)
	buildTown("Limeiro", C3(235, 225, 195), C3(180, 60, 60), 10)
	buildTown("Port", C3(210, 215, 220), C3(70, 100, 130), 6)
	buildTown("Bunzen", C3(170, 190, 140), C3(70, 100, 60), 8)
	buildTown("Bandits", C3(165, 140, 115), C3(80, 60, 45), 7)

	landmarkShiso()
	landmarkMasadora()
	landmarkSoufrabi()
	landmarkDorias()
	landmarkLimeiro()
	landmarkPort()
	landmarkAntokiba()
	landmarkAiai()
	landmarkBandits()
	landmarkRuins()
	scatter()
	buildTrails()
end

return WorldBuilder
