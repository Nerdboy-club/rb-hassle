-- Остров целиком собирается кодом: ландшафт Terrain + простые детали. Ничего вручную в Studio делать не нужно.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Zones = require(Shared.Zones)

local WorldBuilder = {}

local terrain = workspace.Terrain
local rng = Random.new(1987)
local world: Folder
local decor: Folder

local V3 = Vector3.new
local C3 = Color3.fromRGB

local WOOD = C3(120, 85, 55)

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

-- Города стоят на ровных дисках-полах (см. buildTownFloors): их высота известна точно, а не берётся лучом по террейну
local TOWN_TOP = 1.0
local townDiscs: { { x: number, z: number, r: number } } = {}

function WorldBuilder.terrainY(x: number, z: number): number
	for _, disc in townDiscs do
		local dx, dz = x - disc.x, z - disc.z
		if dx * dx + dz * dz < disc.r * disc.r then
			return TOWN_TOP
		end
	end
	-- только Terrain: не цепляем игроков, NPC, монстров и постройки
	if not terrainOnly then
		terrainOnly = RaycastParams.new()
		terrainOnly.FilterType = Enum.RaycastFilterType.Include
		terrainOnly.FilterDescendantsInstances = { terrain }
	end
	local hit = workspace:Raycast(V3(x, 400, z), V3(0, -800, 0), terrainOnly)
	return hit and hit.Position.Y or 0
end

local decorOnly: RaycastParams?

--- Перегорожен ли путь постройками (дома, деревья, камни): короткий луч на высоте груди от точки `from`.
function WorldBuilder.pathBlocked(from: Vector3, unit: Vector3, length: number): boolean
	if not decorOnly then
		decorOnly = RaycastParams.new()
		decorOnly.FilterType = Enum.RaycastFilterType.Include
		decorOnly.FilterDescendantsInstances = { decor }
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
			-- города на 1.5 stud выше окружающей травы: пол всегда выше травы, постройки не тонут
			local lift = zone.kind == "town" and 1.5 or 0
			terrain:FillCylinder(CFrame.new(zone.x, -11 + lift, zone.z), 20, zone.r * 0.95, zone.ground)
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

--- Ровные полы городов: диск выше террейна, поэтому постройки не «тонут» в текстуре.
--- Два уступа (-1 трава → 0 → 1 пол) вместо одной ступеньки.
local FLOOR_COLORS: { [Enum.Material]: Color3 } = {
	[Enum.Material.Grass] = C3(96, 152, 78),
	[Enum.Material.LeafyGrass] = C3(86, 140, 66),
	[Enum.Material.Slate] = C3(92, 96, 108),
	[Enum.Material.Sand] = C3(214, 196, 150),
	[Enum.Material.Cobblestone] = C3(134, 132, 128),
	[Enum.Material.Ground] = C3(120, 96, 70),
}

local function buildTownFloors()
	local floors = Instance.new("Folder")
	floors.Name = "TownFloors"
	floors.Parent = workspace
	for _, zone in Zones do
		if zone.kind == "town" and zone.ground then
			local radius = zone.r * 0.95
			local material = zone.ground :: Enum.Material
			local color = FLOOR_COLORS[material] or C3(120, 120, 120)
			for _, tier in { { radius + 10, 0 }, { radius, TOWN_TOP } } do
				local thickness = 6
				local disc = newPart(
					floors,
					"TownFloor",
					V3(thickness, tier[1] * 2, tier[1] * 2),
					CFrame.new(zone.x, tier[2] - thickness / 2, zone.z) * CFrame.Angles(0, 0, math.pi / 2),
					color,
					material,
					Enum.PartType.Cylinder
				)
				disc.CanCollide = true
				disc.CanQuery = true
			end
			table.insert(townDiscs, { x = zone.x, z = zone.z, r = radius })
		end
	end
end

-- ===================== мелкие детали =====================

local function tree(position: Vector3, scale: number, dead: boolean?)
	local height = 14 * scale
	column(decor, "Trunk", position, height, 2.2 * scale, WOOD, Enum.Material.Wood)
	if not dead then
		local crown = newPart(
			decor,
			"Crown",
			V3(11, 9, 11) * scale,
			CFrame.new(position + V3(0, height + 3 * scale, 0)),
			C3(52 + rng:NextInteger(0, 40), 130 + rng:NextInteger(0, 40), 60),
			Enum.Material.Grass,
			Enum.PartType.Ball
		)
		CollectionService:AddTag(crown, "Sway") -- клиент колышет ближние кроны (Ambient.luau)
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

local function house(center: Vector3, width: number, depth: number, height: number, wall: Color3, roof: Color3, yaw: number)
	local frame = CFrame.new(center) * CFrame.Angles(0, yaw, 0)
	-- каменный цоколь: уходит глубоко под землю, поэтому дом не «проваливается» на неровном рельефе
	newPart(decor, "Foundation", V3(width + 1.2, 4, depth + 1.2), frame * CFrame.new(0, -1.6, 0), C3(120, 118, 112), Enum.Material.Cobblestone)
	newPart(decor, "Wall", V3(width, height, depth), frame * CFrame.new(0, height / 2, 0), wall, Enum.Material.Brick)
	newPart(decor, "Roof", V3(width + 2, 1.4, depth + 2), frame * CFrame.new(0, height + 0.7, 0), roof, Enum.Material.Slate)
	local door = newPart(decor, "Door", V3(3, 5.5, 0.4), frame * CFrame.new(0, 2.75, depth / 2 + 0.1), C3(80, 55, 40), Enum.Material.Wood)
	door.CanCollide = false
	local window = newPart(decor, "Window", V3(2.4, 2.4, 0.3), frame * CFrame.new(width * 0.28, height * 0.6, depth / 2 + 0.1), C3(255, 235, 150), Enum.Material.Neon)
	window.CanCollide = false
end

local function plaza(zoneKey: string, radius: number, color: Color3)
	local zone = Zones[zoneKey]
	local y = WorldBuilder.terrainY(zone.x, zone.z)
	local disc = newPart(
		decor,
		"Plaza",
		V3(0.5, radius * 2, radius * 2),
		CFrame.new(zone.x, y + 0.25, zone.z) * CFrame.Angles(0, 0, math.pi / 2),
		color,
		Enum.Material.Cobblestone,
		Enum.PartType.Cylinder
	)
	disc.CanCollide = true
end

--- Фонарь: тонкий столб и светящийся шар (без PointLight — свет сотен ламп нагрузил бы клиент).
local function lamp(base: Vector3)
	column(decor, "LampPost", base, 9, 0.7, C3(45, 48, 58), Enum.Material.Metal)
	local bulb = newPart(decor, "LampBulb", V3(2, 2, 2), CFrame.new(base + V3(0, 9.6, 0)), C3(255, 226, 150), Enum.Material.Neon, Enum.PartType.Ball)
	bulb.CanCollide = false
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

local function buildTown(zoneKey: string, wall: Color3, roof: Color3, count: number?)
	local zone = Zones[zoneKey]
	local houses = count or math.clamp(math.floor(zone.r / 9), 6, 14)
	plaza(zoneKey, math.min(26, zone.r * 0.28), C3(170, 165, 150))
	for index = 1, houses do
		local angle = (index / houses) * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local radius = zone.r * rng:NextNumber(0.66, 0.9)
		local x = zone.x + math.cos(angle) * radius
		local z = zone.z + math.sin(angle) * radius
		local y = WorldBuilder.terrainY(x, z)
		house(
			V3(x, y, z),
			rng:NextInteger(9, 13),
			rng:NextInteger(9, 13),
			rng:NextInteger(7, 11),
			wall:Lerp(C3(255, 255, 255), rng:NextNumber(0, 0.25)),
			roof,
			angle + math.pi / 2
		)
	end
	townDetails(zoneKey, zoneKey ~= "Aiai" and zoneKey ~= "Masadora")
	local base = WorldBuilder.zonePoint(zoneKey, 0, 0)
	sign(decor, zone.name, base + V3(0, 22, 0), zone.color)
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

local function landmarkMasadora()
	local base = WorldBuilder.zonePoint("Masadora", 0, 0)
	local spire = newPart(decor, "Spire", V3(14, 56, 14), CFrame.new(base + V3(0, 28, 0)) * CFrame.Angles(0, math.pi / 4, 0), C3(170, 110, 255), Enum.Material.Neon)
	spire.Transparency = 0.15
	for index = 1, 8 do
		local angle = index * math.pi / 4
		newPart(
			decor,
			"Shard",
			V3(3, 9, 3),
			CFrame.new(base + V3(math.cos(angle) * 22, 10 + (index % 3) * 4, math.sin(angle) * 22)) * CFrame.Angles(0.4, angle, 0.3),
			C3(200, 150, 255),
			Enum.Material.Neon
		).CanCollide = false
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

local function landmarkSoufrabi()
	local zone = Zones.Soufrabi
	local lighthouse = WorldBuilder.zonePoint("Soufrabi", 40, -40)
	column(decor, "Lighthouse", lighthouse, 64, 11, C3(235, 235, 240), Enum.Material.Concrete)
	newPart(decor, "Lamp", V3(8, 6, 8), CFrame.new(lighthouse + V3(0, 67, 0)), C3(255, 235, 140), Enum.Material.Neon, Enum.PartType.Ball)
	-- причал уходит в воду; у пирата корабль у конца
	local direction = V3(zone.x, 0, zone.z).Unit
	for step = 0, 18 do
		local radius = 835 + step * 5
		local pos = direction * radius
		newPart(decor, "Plank", V3(8, 0.6, 5), CFrame.new(pos.X, 0.6, pos.Z) * CFrame.Angles(0, math.atan2(-direction.X, -direction.Z), 0), WOOD, Enum.Material.WoodPlanks)
	end
	moorBoats("Soufrabi", 4)
	local shipPos = direction * 980
	newPart(decor, "ShipHull", V3(14, 6, 34), CFrame.new(shipPos.X, 0, shipPos.Z) * CFrame.Angles(0, math.atan2(-direction.X, -direction.Z) + math.pi / 2, 0), C3(90, 60, 40), Enum.Material.Wood)
	column(decor, "Mast", V3(shipPos.X, 3, shipPos.Z), 26, 1.2, WOOD, Enum.Material.Wood)
	newPart(decor, "Flag", V3(8, 5, 0.3), CFrame.new(shipPos.X, 26, shipPos.Z), C3(20, 20, 24), Enum.Material.Fabric)
end

local function landmarkDorias()
	local zone = Zones.Dorias
	local building = WorldBuilder.zonePoint("Dorias", 0, 38)
	newPart(decor, "Casino", V3(52, 26, 38), CFrame.new(building + V3(0, 13, 0)), C3(40, 20, 45), Enum.Material.Concrete)
	newPart(decor, "Neon", V3(54, 2, 0.6), CFrame.new(building + V3(0, 24, -19.4)), C3(255, 60, 100), Enum.Material.Neon)
	newPart(decor, "Neon2", V3(54, 2, 0.6), CFrame.new(building + V3(0, 3, -19.4)), C3(255, 210, 60), Enum.Material.Neon)
	sign(decor, "КАЗИНО — только азартные игры дают особые карты", building + V3(0, 32, -19), zone.color)
	newPart(decor, "Roulette", V3(0.8, 10, 10), CFrame.new(zone.x + 12, WorldBuilder.terrainY(zone.x + 12, zone.z - 8) + 3, zone.z - 8) * CFrame.Angles(0, 0, math.pi / 2), C3(20, 90, 50), Enum.Material.Wood, Enum.PartType.Cylinder)
end

local function landmarkLimeiro()
	local keep = WorldBuilder.zonePoint("Limeiro", 0, -48)
	newPart(decor, "Keep", V3(46, 52, 38), CFrame.new(keep + V3(0, 26, 0)), C3(225, 215, 190), Enum.Material.Concrete)
	newPart(decor, "Gate", V3(12, 16, 1), CFrame.new(keep + V3(0, 8, 19.4)), C3(80, 55, 40), Enum.Material.Wood)
	for _, corner in { V3(-28, 0, -22), V3(28, 0, -22), V3(-28, 0, 22), V3(28, 0, 22) } do
		column(decor, "Tower", keep + corner, 66, 11, C3(235, 225, 200), Enum.Material.Concrete)
		newPart(decor, "TowerRoof", V3(14, 8, 14), CFrame.new(keep + corner + V3(0, 70, 0)), C3(190, 60, 70), Enum.Material.Slate, Enum.PartType.Ball)
	end
	newPart(decor, "Banner", V3(6, 14, 0.4), CFrame.new(keep + V3(0, 38, 19.5)), C3(200, 40, 60), Enum.Material.Fabric)
	sign(decor, "Замок Двана и Листа", keep + V3(0, 62, 19), C3(255, 235, 160))
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
	-- причал
	local direction = V3(zone.x, 0, zone.z).Unit
	for step = 0, 17 do
		local pos = direction * (840 + step * 5)
		newPart(decor, "Plank", V3(8, 0.6, 5), CFrame.new(pos.X, 0.6, pos.Z) * CFrame.Angles(0, math.atan2(-direction.X, -direction.Z), 0), WOOD, Enum.Material.WoodPlanks)
	end
end

local function landmarkAntokiba()
	local stage = WorldBuilder.zonePoint("Antokiba", 0, -45)
	local disc = newPart(decor, "ContestStage", V3(1, 44, 44), CFrame.new(stage + V3(0, 0.6, 0)) * CFrame.Angles(0, 0, math.pi / 2), C3(235, 180, 70), Enum.Material.Wood, Enum.PartType.Cylinder)
	disc.CanCollide = true
	for index = 1, 6 do
		local angle = index * math.pi / 3
		column(decor, "BannerPole", stage + V3(math.cos(angle) * 22, 0, math.sin(angle) * 22), 14, 0.7, WOOD, Enum.Material.Wood)
		newPart(decor, "Banner", V3(0.3, 5, 3), CFrame.new(stage + V3(math.cos(angle) * 22, 11, math.sin(angle) * 22)), C3(230, 80, 70), Enum.Material.Fabric)
	end
	sign(decor, "Ежемесячный конкурс", stage + V3(0, 18, 0), C3(255, 220, 120))
end

local function landmarkAiai()
	local base = WorldBuilder.zonePoint("Aiai", 0, 0)
	column(decor, "Fountain", base, 4, 14, C3(250, 205, 220), Enum.Material.Marble)
	newPart(decor, "Heart1", V3(5, 5, 5), CFrame.new(base + V3(-2.4, 8, 0)), C3(255, 90, 140), Enum.Material.Neon, Enum.PartType.Ball)
	newPart(decor, "Heart2", V3(5, 5, 5), CFrame.new(base + V3(2.4, 8, 0)), C3(255, 90, 140), Enum.Material.Neon, Enum.PartType.Ball)
	newPart(decor, "Heart3", V3(6, 6, 6), CFrame.new(base + V3(0, 5.2, 0)) * CFrame.Angles(0, math.pi / 4, math.pi / 4), C3(255, 90, 140), Enum.Material.Neon)
end

local function landmarkBandits()
	local base = WorldBuilder.zonePoint("Bandits", 0, 0)
	local fire = newPart(decor, "Campfire", V3(3, 3, 3), CFrame.new(base + V3(0, 1.5, 0)), C3(255, 130, 40), Enum.Material.Neon, Enum.PartType.Ball)
	fire.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = C3(255, 150, 60)
	light.Range = 30
	light.Parent = fire
end

local function landmarkRuins()
	local zone = Zones.Ruins
	for index = 1, 16 do
		local angle = index * 0.39
		local radius = zone.r * rng:NextNumber(0.35, 0.85)
		local base = V3(zone.x + math.cos(angle) * radius, 0, zone.z + math.sin(angle) * radius)
		base = V3(base.X, WorldBuilder.terrainY(base.X, base.Z), base.Z)
		column(decor, "Pillar", base, rng:NextInteger(7, 20), 3, C3(190, 190, 180), Enum.Material.Marble)
	end
	for index = 1, 3 do
		local center = V3(zone.x + (index - 2) * 36, 0, zone.z + 10)
		center = V3(center.X, WorldBuilder.terrainY(center.X, center.Z), center.Z)
		column(decor, "ArchL", center + V3(-5, 0, 0), 18, 3, C3(200, 200, 190), Enum.Material.Marble)
		column(decor, "ArchR", center + V3(5, 0, 0), 18, 3, C3(200, 200, 190), Enum.Material.Marble)
		newPart(decor, "Lintel", V3(14, 2.4, 3.4), CFrame.new(center + V3(0, 19, 0)), C3(205, 205, 195), Enum.Material.Marble)
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
	-- Луга: цветы
	local meadow = Zones.Meadow
	for _ = 1, 90 do
		local angle = rng:NextNumber(0, 6.28)
		local radius = meadow.r * math.sqrt(rng:NextNumber(0, 1))
		local x, z = meadow.x + math.cos(angle) * radius, meadow.z + math.sin(angle) * radius
		local flower = newPart(
			decor,
			"Flower",
			V3(1.2, 1.2, 1.2),
			CFrame.new(x, WorldBuilder.terrainY(x, z) + 0.8, z),
			Color3.fromHSV(rng:NextNumber(0, 1), 0.6, 1),
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		flower.CanCollide = false
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
			tree(V3(x, WorldBuilder.terrainY(x, z), z), rng:NextNumber(0.8, 1.2))
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
		if open or point.Y < -1.5 then
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

--- Вода, свет, дымка и мягкая цветокоррекция: чтобы остров выглядел живым, а не «серой коробкой».
function WorldBuilder.styleScene()
	terrain.WaterColor = C3(46, 140, 190)
	terrain.WaterTransparency = 0.55
	terrain.WaterReflectance = 0.7
	terrain.WaterWaveSize = 0.18
	terrain.WaterWaveSpeed = 9
	pcall(function()
		terrain.Decoration = false -- без объёмной «травы» террейна: колючие пучки торчали выше пола
	end)

	Lighting.ClockTime = 14.5
	Lighting.Brightness = 3
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.ColorShift_Top = C3(255, 238, 205)

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

	effect("Atmosphere", { Density = 0.28, Offset = 0.25, Color = C3(205, 220, 240), Decay = C3(255, 210, 170), Glare = 0.3, Haze = 1.2 })
	effect("BloomEffect", { Intensity = 0.4, Size = 26, Threshold = 0.92 })
	effect("SunRaysEffect", { Intensity = 0.07, Spread = 0.8 })
	effect("ColorCorrectionEffect", { Saturation = 0.18, Contrast = 0.08, Brightness = 0.02, TintColor = C3(255, 247, 235) })

	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
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

	-- мир строится после Terrain: рэйкасты по земле не должны упираться в уже построенное
	buildTerrain()
	buildTownFloors()

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
	buildLobby()
end

return WorldBuilder
