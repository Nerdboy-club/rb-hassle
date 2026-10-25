-- Сборка разнообразных домов из простых деталей (Part, WedgePart, цилиндры, шары) без внешних ассетов.
local Buildings = {}

local V3 = Vector3.new
local C3 = Color3.fromRGB

local GLASS_COLOR = C3(255, 225, 140)
local DARK_WOOD = C3(78, 52, 34)
local MED_WOOD = C3(118, 82, 52)
local LIGHT_WOOD = C3(158, 118, 76)
local STONE_GRAY = C3(126, 124, 118)
local DARK_METAL = C3(48, 50, 58)

local function shiftColor(color: Color3, target: Color3, alpha: number): Color3
	return color:Lerp(target, alpha)
end

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	collide: boolean?,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanQuery = collide == true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function wedge(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	collide: boolean?
): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Size = size
	w.CFrame = cframe
	w.Color = color
	w.Material = material or Enum.Material.Slate
	w.Anchored = true
	w.CanCollide = collide == true
	w.CanQuery = collide == true
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Parent = parent
	return w
end

--- Вертикальный цилиндр (в Roblox ось цилиндра направлена вдоль локальной оси X).
local function cylinder(
	parent: Instance,
	name: string,
	cframe: CFrame,
	height: number,
	diameter: number,
	color: Color3,
	material: Enum.Material?,
	collide: boolean?
): Part
	return part(
		parent,
		name,
		V3(height, diameter, diameter),
		cframe * CFrame.Angles(0, 0, math.pi / 2),
		color,
		material,
		collide,
		Enum.PartType.Cylinder
	)
end

--- Светящееся изнутри окно с рамой, подоконником и опциональными ставнями/цветочным ящиком.
local function addWindow(
	model: Instance,
	faceCF: CFrame,
	w: number,
	h: number,
	frameColor: Color3,
	shutterColor: Color3?,
	withFlowers: boolean?,
	rng: Random?
)
	-- Рама позади стекла и переплёт
	part(model, "WindowFrame", V3(w + 0.35, h + 0.35, 0.22), faceCF * CFrame.new(0, 0, 0.04), frameColor, Enum.Material.Wood, false)
	local glass = part(model, "WindowGlass", V3(w, h, 0.16), faceCF * CFrame.new(0, 0, 0.12), GLASS_COLOR, Enum.Material.Neon, false)
	glass.Transparency = 0.25
	part(model, "WindowMullionV", V3(0.14, h, 0.22), faceCF * CFrame.new(0, 0, 0.14), frameColor, Enum.Material.Wood, false)
	-- Подоконник
	part(model, "WindowSill", V3(w + 0.65, 0.24, 0.55), faceCF * CFrame.new(0, -h / 2 - 0.12, 0.22), frameColor, Enum.Material.Wood, false)

	if shutterColor then
		local sw = math.max(0.45, w * 0.42)
		part(model, "ShutterL", V3(sw, h + 0.1, 0.18), faceCF * CFrame.new(-w / 2 - sw / 2 - 0.08, 0, 0.12), shutterColor, Enum.Material.WoodPlanks, false)
		part(model, "ShutterR", V3(sw, h + 0.1, 0.18), faceCF * CFrame.new(w / 2 + sw / 2 + 0.08, 0, 0.12), shutterColor, Enum.Material.WoodPlanks, false)
	end

	if withFlowers then
		local boxY = -h / 2 - 0.42
		part(model, "FlowerBox", V3(w + 0.4, 0.45, 0.65), faceCF * CFrame.new(0, boxY, 0.32), MED_WOOD, Enum.Material.Wood, false)
		local flowerColors = { C3(235, 75, 95), C3(250, 200, 70), C3(190, 95, 240) }
		for i = -1, 1 do
			local idx = rng and rng:NextInteger(1, #flowerColors) or (i + 2)
			part(
				model,
				"Flower",
				V3(0.42, 0.42, 0.42),
				faceCF * CFrame.new(i * (w * 0.3), boxY + 0.32, 0.34),
				flowerColors[idx],
				Enum.Material.SmoothPlastic,
				false,
				Enum.PartType.Ball
			)
		end
	end
end

--- Настенный фонарь у входа (без PointLight).
local function addWallLamp(model: Instance, attachCF: CFrame)
	part(model, "LampBracket", V3(0.22, 0.22, 0.7), attachCF * CFrame.new(0, 0, 0.35), DARK_METAL, Enum.Material.Metal, false)
	local bulb = part(model, "LampBulb", V3(0.75, 0.9, 0.75), attachCF * CFrame.new(0, -0.25, 0.65), GLASS_COLOR, Enum.Material.Neon, false, Enum.PartType.Ball)
	bulb.Transparency = 0.15
end

--- Двускатная крыша со скатами вдоль X (конёк вдоль Z) и фронтонами спереди/сзади.
local function addGableRoofZ(
	model: Instance,
	frame: CFrame,
	width: number,
	depth: number,
	height: number,
	roofH: number,
	overhang: number,
	roofColor: Color3,
	wallColor: Color3,
	beamColor: Color3,
	roofMat: Enum.Material
)
	local halfSpan = width / 2 + overhang
	local spanZ = depth + overhang * 2
	-- Левый и правый скаты (вертикальные грани клиньев смыкаются по X = 0 без щели)
	wedge(
		model,
		"RoofLeft",
		V3(spanZ, roofH, halfSpan),
		frame * CFrame.new(-halfSpan / 2, height + roofH / 2, 0) * CFrame.Angles(0, -math.pi / 2, 0),
		roofColor,
		roofMat,
		true
	)
	wedge(
		model,
		"RoofRight",
		V3(spanZ, roofH, halfSpan),
		frame * CFrame.new(halfSpan / 2, height + roofH / 2, 0) * CFrame.Angles(0, math.pi / 2, 0),
		roofColor,
		roofMat,
		true
	)
	-- Фронтон (треугольная часть стены под крышей) и коньковая балка
	local gableH = roofH * (width / 2) / halfSpan
	wedge(
		model,
		"GableLeft",
		V3(depth, gableH, width / 2),
		frame * CFrame.new(-width / 4, height + gableH / 2, 0) * CFrame.Angles(0, -math.pi / 2, 0),
		wallColor,
		Enum.Material.SmoothPlastic,
		true
	)
	wedge(
		model,
		"GableRight",
		V3(depth, gableH, width / 2),
		frame * CFrame.new(width / 4, height + gableH / 2, 0) * CFrame.Angles(0, math.pi / 2, 0),
		wallColor,
		Enum.Material.SmoothPlastic,
		true
	)
	part(model, "RidgeBeam", V3(0.45, 0.45, spanZ + 0.2), frame * CFrame.new(0, height + roofH, 0), beamColor, Enum.Material.Wood, false)
end

--- Двускатная крыша со скатами спереди (+Z) и сзади (-Z), конёк вдоль X.
local function addGableRoofX(
	model: Instance,
	frame: CFrame,
	width: number,
	depth: number,
	height: number,
	roofH: number,
	overhang: number,
	roofColor: Color3,
	wallColor: Color3,
	beamColor: Color3,
	roofMat: Enum.Material
)
	local halfSpan = depth / 2 + overhang
	local spanX = width + overhang * 2
	-- Передний (+Z) и задний (-Z) скаты смыкаются по Z = 0
	wedge(
		model,
		"RoofFront",
		V3(spanX, roofH, halfSpan),
		frame * CFrame.new(0, height + roofH / 2, halfSpan / 2) * CFrame.Angles(0, math.pi, 0),
		roofColor,
		roofMat,
		true
	)
	wedge(
		model,
		"RoofBack",
		V3(spanX, roofH, halfSpan),
		frame * CFrame.new(0, height + roofH / 2, -halfSpan / 2),
		roofColor,
		roofMat,
		true
	)
	local gableH = roofH * (depth / 2) / halfSpan
	wedge(
		model,
		"GableFront",
		V3(width, gableH, depth / 2),
		frame * CFrame.new(0, height + gableH / 2, depth / 4) * CFrame.Angles(0, math.pi, 0),
		wallColor,
		Enum.Material.SmoothPlastic,
		true
	)
	wedge(
		model,
		"GableBack",
		V3(width, gableH, depth / 2),
		frame * CFrame.new(0, height + gableH / 2, -depth / 4),
		wallColor,
		Enum.Material.SmoothPlastic,
		true
	)
	part(model, "RidgeBeam", V3(spanX + 0.2, 0.45, 0.45), frame * CFrame.new(0, height + roofH, 0), beamColor, Enum.Material.Wood, false)
end

-- ===================== СТИЛЬ 1: COTTAGE (фахверковый коттедж) =====================
local function buildCottage(
	model: Instance,
	frame: CFrame,
	width: number,
	depth: number,
	height: number,
	wall: Color3,
	roof: Color3,
	rng: Random
)
	local lightWall = shiftColor(wall, C3(250, 244, 232), 0.35)
	local beamColor = shiftColor(roof, DARK_WOOD, 0.65)
	local shutterColor = shiftColor(roof, C3(70, 110, 85), 0.45)

	part(model, "Wall", V3(width, height, depth), frame * CFrame.new(0, height / 2, 0), lightWall, Enum.Material.SmoothPlastic, true)

	-- Фахверк: угловые стойки, горизонтальные пояса и раскосы
	local bw = 0.42
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(model, "CornerBeam", V3(bw, height, bw), frame * CFrame.new(sx * (width / 2 - 0.1), height / 2, sz * (depth / 2 - 0.1)), beamColor, Enum.Material.Wood, false)
		end
	end
	part(model, "BeltTop", V3(width + 0.28, bw, depth + 0.28), frame * CFrame.new(0, height - bw / 2, 0), beamColor, Enum.Material.Wood, false)
	part(model, "BeltMid", V3(width + 0.26, bw * 0.85, depth + 0.26), frame * CFrame.new(0, height * 0.52, 0), beamColor, Enum.Material.Wood, false)
	-- Диагональные балки на фасаде
	local braceH = height * 0.44
	for _, sx in { -1, 1 } do
		part(
			model,
			"Brace",
			V3(0.28, braceH, 0.24),
			frame * CFrame.new(sx * (width * 0.36), height * 0.74, depth / 2 + 0.05) * CFrame.Angles(0, 0, sx * 0.45),
			beamColor,
			Enum.Material.Wood,
			false
		)
	end

	-- Двускатная крыша с свесом 1.3 стада + кирпичная труба
	local roofH = math.clamp(width * 0.36, 3.2, 4.8)
	addGableRoofZ(model, frame, width, depth, height, roofH, 1.3, roof, lightWall, beamColor, Enum.Material.Slate)

	local chimX = -width * 0.26
	local chimZ = -depth * 0.2
	local chimTop = height + roofH + 1.6
	part(model, "Chimney", V3(1.5, chimTop - height * 0.6, 1.5), frame * CFrame.new(chimX, (chimTop + height * 0.6) / 2, chimZ), C3(155, 78, 62), Enum.Material.Brick, false)
	part(model, "ChimneyCap", V3(1.85, 0.35, 1.85), frame * CFrame.new(chimX, chimTop + 0.15, chimZ), STONE_GRAY, Enum.Material.Cobblestone, false)

	-- Крыльцо-ступенька, дверь с козырьком и лампа
	local doorX = -width * 0.18
	part(model, "PorchStep", V3(3.8, 0.5, 2.2), frame * CFrame.new(doorX, 0.25, depth / 2 + 0.9), STONE_GRAY, Enum.Material.Cobblestone, true)
	part(model, "DoorFrame", V3(3.1, 5.5, 0.28), frame * CFrame.new(doorX, 2.75, depth / 2 + 0.05), beamColor, Enum.Material.Wood, false)
	part(model, "Door", V3(2.6, 5.1, 0.24), frame * CFrame.new(doorX, 2.65, depth / 2 + 0.12), MED_WOOD, Enum.Material.WoodPlanks, false)
	part(model, "DoorHandle", V3(0.2, 0.2, 0.3), frame * CFrame.new(doorX + 0.85, 2.5, depth / 2 + 0.26), C3(215, 180, 75), Enum.Material.Metal, false)
	wedge(model, "DoorCanopy", V3(3.6, 0.9, 1.4), frame * CFrame.new(doorX, 5.8, depth / 2 + 0.65) * CFrame.Angles(0, math.pi, 0), roof, Enum.Material.Slate, false)
	addWallLamp(model, frame * CFrame.new(doorX - 2.0, 4.3, depth / 2))

	-- Окна со ставнями и цветочным ящиком спереди + боковые окна
	addWindow(model, frame * CFrame.new(width * 0.24, height * 0.54, depth / 2), 2.1, 2.1, beamColor, shutterColor, true, rng)
	addWindow(model, frame * CFrame.new(width / 2, height * 0.56, 0) * CFrame.Angles(0, math.pi / 2, 0), 2.0, 2.0, beamColor, shutterColor, false, rng)
	addWindow(model, frame * CFrame.new(-width / 2, height * 0.56, 0) * CFrame.Angles(0, -math.pi / 2, 0), 2.0, 2.0, beamColor, shutterColor, false, rng)
end

-- ===================== СТИЛЬ 2: STONE (каменный дом с контрфорсами) =====================
local function buildStone(
	model: Instance,
	frame: CFrame,
	width: number,
	depth: number,
	height: number,
	wall: Color3,
	roof: Color3,
	rng: Random
)
	local stoneWall = shiftColor(wall, STONE_GRAY, 0.35)
	local buttressColor = shiftColor(stoneWall, C3(90, 90, 96), 0.35)
	local trimColor = shiftColor(stoneWall, C3(180, 178, 170), 0.3)

	part(model, "Wall", V3(width, height, depth), frame * CFrame.new(0, height / 2, 0), stoneWall, Enum.Material.Cobblestone, true)
	part(model, "Cornice", V3(width + 0.7, 0.5, depth + 0.7), frame * CFrame.new(0, height - 0.2, 0), trimColor, Enum.Material.Slate, false)

	-- Контрфорсы по четырём углам
	local buttH = height * 0.78
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local bx = sx * (width / 2 + 0.35)
			local bz = sz * (depth / 2 + 0.35)
			part(model, "Buttress", V3(1.3, buttH, 1.3), frame * CFrame.new(bx, buttH / 2, bz), buttressColor, Enum.Material.Cobblestone, true)
			local capYaw = sz > 0 and math.pi or 0
			wedge(model, "ButtressCap", V3(1.3, 1.2, 1.3), frame * CFrame.new(bx, buttH + 0.6, bz) * CFrame.Angles(0, capYaw, 0), trimColor, Enum.Material.Slate, false)
		end
	end

	-- Двускатная черепичная крыша со ступенчатыми рядами
	local roofH = math.clamp(width * 0.38, 3.2, 4.8)
	local overhang = 1.2
	addGableRoofZ(model, frame, width, depth, height, roofH, overhang, roof, stoneWall, buttressColor, Enum.Material.Slate)

	local halfSpan = width / 2 + overhang
	local slopeAngle = math.atan2(roofH, halfSpan)
	local spanZ = depth + overhang * 2 + 0.15
	for row = 1, 3 do
		local t = (row - 0.5) / 3
		local offset = t * halfSpan * 0.85
		local y = height + roofH * (1 - t * 0.85) + 0.16
		local tileColor = row % 2 == 0 and shiftColor(roof, C3(40, 35, 35), 0.2) or shiftColor(roof, C3(230, 200, 180), 0.15)
		part(
			model,
			"TileRowL",
			V3(halfSpan * 0.3, 0.25, spanZ),
			frame * CFrame.new(-offset, y, 0) * CFrame.Angles(0, 0, slopeAngle),
			tileColor,
			Enum.Material.Slate,
			false
		)
		part(
			model,
			"TileRowR",
			V3(halfSpan * 0.3, 0.25, spanZ),
			frame * CFrame.new(offset, y, 0) * CFrame.Angles(0, 0, -slopeAngle),
			tileColor,
			Enum.Material.Slate,
			false
		)
	end

	-- Арочная дверь (прямоугольное полотно + цилиндрический полукруг сверху и каменная арка)
	local doorW = 2.8
	local doorRectH = 4.2
	part(model, "Threshold", V3(doorW + 1.2, 0.45, 1.8), frame * CFrame.new(0, 0.22, depth / 2 + 0.7), trimColor, Enum.Material.Cobblestone, true)
	part(model, "ArchRing", V3(0.45, doorW + 0.7, doorW + 0.7), frame * CFrame.new(0, doorRectH, depth / 2 + 0.08) * CFrame.Angles(0, math.pi / 2, 0), trimColor, Enum.Material.Cobblestone, false, Enum.PartType.Cylinder)
	part(model, "DoorSlab", V3(doorW, doorRectH, 0.28), frame * CFrame.new(0, doorRectH / 2, depth / 2 + 0.14), DARK_WOOD, Enum.Material.Wood, false)
	part(model, "DoorArch", V3(0.28, doorW, doorW), frame * CFrame.new(0, doorRectH, depth / 2 + 0.14) * CFrame.Angles(0, math.pi / 2, 0), DARK_WOOD, Enum.Material.Wood, false, Enum.PartType.Cylinder)
	part(model, "DoorRing", V3(0.24, 0.35, 0.35), frame * CFrame.new(0.75, 2.4, depth / 2 + 0.3), DARK_METAL, Enum.Material.Metal, false, Enum.PartType.Cylinder)
	addWallLamp(model, frame * CFrame.new(-2.2, 4.4, depth / 2))

	-- Узкие окна с каменными рамами
	addWindow(model, frame * CFrame.new(width * 0.28, height * 0.56, depth / 2), 1.2, 2.8, trimColor, nil, false, rng)
	addWindow(model, frame * CFrame.new(-width * 0.28, height * 0.56, depth / 2), 1.2, 2.8, trimColor, nil, false, rng)
	addWindow(model, frame * CFrame.new(width / 2, height * 0.56, 0) * CFrame.Angles(0, math.pi / 2, 0), 1.2, 2.8, trimColor, nil, false, rng)
	addWindow(model, frame * CFrame.new(-width / 2, height * 0.56, 0) * CFrame.Angles(0, -math.pi / 2, 0), 1.2, 2.8, trimColor, nil, false, rng)
end

-- ===================== СТИЛЬ 3: SHOP (торговая лавка) =====================
local function buildShop(
	model: Instance,
	frame: CFrame,
	width: number,
	depth: number,
	height: number,
	wall: Color3,
	roof: Color3,
	rng: Random
)
	local shopWall = shiftColor(wall, C3(245, 235, 215), 0.25)
	local trimColor = shiftColor(roof, DARK_WOOD, 0.55)
	local stripeA = shiftColor(roof, C3(220, 65, 55), 0.35)
	local stripeB = C3(248, 242, 228)

	part(model, "Wall", V3(width, height, depth), frame * CFrame.new(0, height / 2, 0), shopWall, Enum.Material.Brick, true)
	addGableRoofX(model, frame, width, depth, height, math.clamp(depth * 0.32, 2.6, 4.0), 1.15, roof, shopWall, trimColor, Enum.Material.Slate)

	-- Входная дверь слева и большая витрина-окно справа
	local doorX = -width * 0.26
	part(model, "DoorStep", V3(3.2, 0.4, 1.6), frame * CFrame.new(doorX, 0.2, depth / 2 + 0.6), STONE_GRAY, Enum.Material.Cobblestone, true)
	part(model, "DoorFrame", V3(2.9, 5.3, 0.26), frame * CFrame.new(doorX, 2.65, depth / 2 + 0.05), trimColor, Enum.Material.Wood, false)
	part(model, "Door", V3(2.4, 4.9, 0.22), frame * CFrame.new(doorX, 2.55, depth / 2 + 0.12), MED_WOOD, Enum.Material.WoodPlanks, false)

	local winW = math.max(3.4, width * 0.42)
	local winX = width * 0.18
	addWindow(model, frame * CFrame.new(winX, height * 0.46, depth / 2), winW, 3.0, trimColor, nil, false, rng)

	-- Навес с полосатым тентом (чередование двух цветов из клиньев)
	local stripes = 6
	local awningW = width - 0.6
	local stripeW = awningW / stripes
	for i = 1, stripes do
		local sx = -awningW / 2 + (i - 0.5) * stripeW
		local col = (i % 2 == 1) and stripeA or stripeB
		wedge(
			model,
			"AwningStripe",
			V3(stripeW + 0.02, 1.35, 2.6),
			frame * CFrame.new(sx, height * 0.73, depth / 2 + 1.3) * CFrame.Angles(0, math.pi, 0),
			col,
			Enum.Material.Fabric,
			false
		)
	end
	part(model, "AwningPostL", V3(0.25, 2.2, 0.25), frame * CFrame.new(-awningW / 2 + 0.2, height * 0.58, depth / 2 + 1.2) * CFrame.Angles(0.55, 0, 0), trimColor, Enum.Material.Wood, false)
	part(model, "AwningPostR", V3(0.25, 2.2, 0.25), frame * CFrame.new(awningW / 2 - 0.2, height * 0.58, depth / 2 + 1.2) * CFrame.Angles(0.55, 0, 0), trimColor, Enum.Material.Wood, false)

	-- Вывеска на кронштейне с текстом «Лавка» на обеих сторонах
	local signX = -width / 2 + 0.4
	local signY = height * 0.82
	part(model, "SignBracket", V3(0.25, 0.25, 2.8), frame * CFrame.new(signX, signY + 0.85, depth / 2 + 1.3), DARK_METAL, Enum.Material.Metal, false)
	local signBoard = part(
		model,
		"ShopSign",
		V3(2.4, 1.3, 0.22),
		frame * CFrame.new(signX, signY, depth / 2 + 1.7) * CFrame.Angles(0, math.pi / 2, 0),
		LIGHT_WOOD,
		Enum.Material.WoodPlanks,
		false
	)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 42
		gui.MaxDistance = 90
		gui.Parent = signBoard
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextColor3 = C3(42, 26, 14)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.Text = "Лавка"
		label.Parent = gui
	end

	-- Прилавок с ящиками перед входом (под витриной)
	local counterZ = depth / 2 + 1.55
	part(model, "CounterBase", V3(winW, 2.1, 1.3), frame * CFrame.new(winX, 1.05, counterZ), MED_WOOD, Enum.Material.WoodPlanks, true)
	part(model, "CounterTop", V3(winW + 0.35, 0.24, 1.55), frame * CFrame.new(winX, 2.2, counterZ), LIGHT_WOOD, Enum.Material.Wood, false)
	part(model, "GoodsCrate1", V3(1.1, 0.9, 1.0), frame * CFrame.new(winX - 0.9, 2.75, counterZ) * CFrame.Angles(0, 0.2, 0), C3(175, 130, 75), Enum.Material.WoodPlanks, false)
	part(model, "GoodsCrate2", V3(0.95, 0.8, 0.95), frame * CFrame.new(winX + 0.35, 2.7, counterZ + 0.05) * CFrame.Angles(0, -0.25, 0), stripeA, Enum.Material.SmoothPlastic, false)
	part(model, "FloorCrate", V3(1.5, 1.5, 1.5), frame * CFrame.new(winX + winW / 2 + 0.95, 0.75, depth / 2 + 1.1) * CFrame.Angles(0, 0.35, 0), LIGHT_WOOD, Enum.Material.WoodPlanks, false)

	addWallLamp(model, frame * CFrame.new(doorX + 1.75, 4.3, depth / 2))
	addWindow(model, frame * CFrame.new(width / 2, height * 0.55, 0) * CFrame.Angles(0, math.pi / 2, 0), 2.0, 2.0, trimColor, nil, false, rng)
end

-- ===================== СТИЛЬ 4: TOWER (высокая башенка) =====================
local function buildTower(
	model: Instance,
	frame: CFrame,
	width: number,
	depth: number,
	height: number,
	wall: Color3,
	roof: Color3,
	rng: Random
)
	local towerWall = shiftColor(wall, STONE_GRAY, 0.25)
	local beltColor = shiftColor(towerWall, C3(85, 82, 90), 0.35)
	local trimColor = shiftColor(roof, DARK_WOOD, 0.5)

	part(model, "Wall", V3(width, height, depth), frame * CFrame.new(0, height / 2, 0), towerWall, Enum.Material.Cobblestone, true)

	-- Угловые пилястры и межэтажные пояски
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(
				model,
				"Pilaster",
				V3(0.65, height, 0.65),
				frame * CFrame.new(sx * (width / 2 - 0.1), height / 2, sz * (depth / 2 - 0.1)),
				beltColor,
				Enum.Material.Slate,
				false
			)
		end
	end
	for _, frac in { 0.36, 0.68, 0.98 } do
		part(model, "FloorBelt", V3(width + 0.7, 0.45, depth + 0.7), frame * CFrame.new(0, height * frac, 0), beltColor, Enum.Material.Slate, false)
	end

	-- Конусная крыша из пирамидального основания (4 клина) и ступенчатых цилиндров со шпилем
	local overhang = 1.1
	local spanX = width + overhang * 2
	local spanZ = depth + overhang * 2
	local baseH = 2.2
	wedge(model, "RoofN", V3(spanX, baseH, spanZ / 2), frame * CFrame.new(0, height + baseH / 2, -spanZ / 4), roof, Enum.Material.Slate, true)
	wedge(model, "RoofS", V3(spanX, baseH, spanZ / 2), frame * CFrame.new(0, height + baseH / 2, spanZ / 4) * CFrame.Angles(0, math.pi, 0), roof, Enum.Material.Slate, true)
	wedge(model, "RoofW", V3(spanZ, baseH, spanX / 2), frame * CFrame.new(-spanX / 4, height + baseH / 2, 0) * CFrame.Angles(0, -math.pi / 2, 0), roof, Enum.Material.Slate, true)
	wedge(model, "RoofE", V3(spanZ, baseH, spanX / 2), frame * CFrame.new(spanX / 4, height + baseH / 2, 0) * CFrame.Angles(0, math.pi / 2, 0), roof, Enum.Material.Slate, true)

	local maxD = math.min(spanX, spanZ) * 0.92
	local coneY = height + baseH * 0.65
	for tier = 1, 4 do
		local tierH = 1.45
		local diam = maxD * (1 - (tier - 1) * 0.22)
		cylinder(model, "ConeTier", frame * CFrame.new(0, coneY + tierH / 2, 0), tierH, diam, roof, Enum.Material.Slate, true)
		coneY += tierH * 0.88
	end
	cylinder(model, "Spire", frame * CFrame.new(0, coneY + 1.4, 0), 2.8, 0.45, DARK_METAL, Enum.Material.Metal, false)

	-- Вход и балкон на втором ярусе
	part(model, "DoorStep", V3(3.0, 0.45, 1.5), frame * CFrame.new(0, 0.22, depth / 2 + 0.6), beltColor, Enum.Material.Cobblestone, true)
	part(model, "DoorFrame", V3(2.7, 5.1, 0.26), frame * CFrame.new(0, 2.55, depth / 2 + 0.05), beltColor, Enum.Material.Slate, false)
	part(model, "Door", V3(2.2, 4.7, 0.22), frame * CFrame.new(0, 2.45, depth / 2 + 0.12), DARK_WOOD, Enum.Material.Wood, false)
	addWallLamp(model, frame * CFrame.new(-1.7, 4.2, depth / 2))

	local balY = height * 0.52
	local balW = math.max(3.6, width * 0.62)
	local balD = 2.2
	part(model, "BalconyFloor", V3(balW, 0.38, balD), frame * CFrame.new(0, balY, depth / 2 + balD / 2), beltColor, Enum.Material.Cobblestone, true)
	wedge(model, "BalconyCorbelL", V3(0.45, 1.2, balD * 0.85), frame * CFrame.new(-balW * 0.35, balY - 0.78, depth / 2 + balD * 0.42) * CFrame.Angles(math.pi, 0, 0), beltColor, Enum.Material.Slate, false)
	wedge(model, "BalconyCorbelR", V3(0.45, 1.2, balD * 0.85), frame * CFrame.new(balW * 0.35, balY - 0.78, depth / 2 + balD * 0.42) * CFrame.Angles(math.pi, 0, 0), beltColor, Enum.Material.Slate, false)
	part(model, "BalconyRailFront", V3(balW, 0.22, 0.22), frame * CFrame.new(0, balY + 1.25, depth / 2 + balD - 0.12), trimColor, Enum.Material.Wood, false)
	for _, sx in { -1, 0, 1 } do
		part(model, "BalconyPost", V3(0.24, 1.2, 0.24), frame * CFrame.new(sx * (balW / 2 - 0.14), balY + 0.65, depth / 2 + balD - 0.12), trimColor, Enum.Material.Wood, false)
	end

	-- Окна на разных этажах
	addWindow(model, frame * CFrame.new(0, balY + 1.6, depth / 2), 1.5, 2.4, trimColor, nil, false, rng)
	addWindow(model, frame * CFrame.new(0, height * 0.83, depth / 2), 1.3, 2.0, trimColor, nil, false, rng)
	addWindow(model, frame * CFrame.new(width / 2, height * 0.48, 0) * CFrame.Angles(0, math.pi / 2, 0), 1.3, 2.2, trimColor, nil, false, rng)
	addWindow(model, frame * CFrame.new(-width / 2, height * 0.82, 0) * CFrame.Angles(0, -math.pi / 2, 0), 1.3, 2.0, trimColor, nil, false, rng)
	addWindow(model, frame * CFrame.new(0, height * 0.68, -depth / 2) * CFrame.Angles(0, math.pi, 0), 1.3, 2.2, trimColor, nil, false, rng)
end

-- ===================== СТИЛЬ 5: INN (двухэтажный трактир) =====================
local function buildInn(
	model: Instance,
	frame: CFrame,
	width: number,
	depth: number,
	height: number,
	wall: Color3,
	roof: Color3,
	rng: Random
)
	local innWall = shiftColor(wall, C3(245, 232, 210), 0.25)
	local beamColor = shiftColor(roof, DARK_WOOD, 0.6)
	local roofH = math.clamp(depth * 0.38, 3.4, 5.0)

	part(model, "Wall", V3(width, height, depth), frame * CFrame.new(0, height / 2, 0), innWall, Enum.Material.SmoothPlastic, true)
	-- Межэтажный поясок посередине и верхний карниз
	part(model, "MidBelt", V3(width + 0.5, 0.5, depth + 0.5), frame * CFrame.new(0, height * 0.5, 0), beamColor, Enum.Material.Wood, false)
	part(model, "TopBelt", V3(width + 0.45, 0.4, depth + 0.45), frame * CFrame.new(0, height - 0.2, 0), beamColor, Enum.Material.Wood, false)

	-- Двускатная крыша со скатом вперёд (+Z) и двумя слуховыми окнами
	addGableRoofX(model, frame, width, depth, height, roofH, 1.35, roof, innWall, beamColor, Enum.Material.Slate)

	for _, sx in { -1, 1 } do
		local dx = sx * (width * 0.25)
		local dy = height + roofH * 0.46
		local dz = depth * 0.24
		part(model, "DormerBody", V3(2.2, 1.8, 2.2), frame * CFrame.new(dx, dy, dz), innWall, Enum.Material.SmoothPlastic, false)
		wedge(
			model,
			"DormerRoofL",
			V3(2.5, 0.85, 1.3),
			frame * CFrame.new(dx - 0.65, dy + 1.3, dz) * CFrame.Angles(0, -math.pi / 2, 0),
			roof,
			Enum.Material.Slate,
			false
		)
		wedge(
			model,
			"DormerRoofR",
			V3(2.5, 0.85, 1.3),
			frame * CFrame.new(dx + 0.65, dy + 1.3, dz) * CFrame.Angles(0, math.pi / 2, 0),
			roof,
			Enum.Material.Slate,
			false
		)
		part(model, "DormerFrame", V3(1.45, 1.35, 0.2), frame * CFrame.new(dx, dy, dz + 1.04), beamColor, Enum.Material.Wood, false)
		local dGlass = part(model, "DormerGlass", V3(1.2, 1.1, 0.16), frame * CFrame.new(dx, dy, dz + 1.08), GLASS_COLOR, Enum.Material.Neon, false)
		dGlass.Transparency = 0.25
	end

	-- Крыльцо с перилами и два фонаря у входа
	local porchW = math.min(width * 0.56, 6.8)
	local porchD = 2.6
	local porchZ = depth / 2 + porchD / 2
	part(model, "PorchDeck", V3(porchW, 0.55, porchD), frame * CFrame.new(0, 0.27, porchZ), MED_WOOD, Enum.Material.WoodPlanks, true)
	part(model, "PorchStep", V3(2.8, 0.3, 0.9), frame * CFrame.new(0, 0.15, depth / 2 + porchD + 0.4), STONE_GRAY, Enum.Material.Cobblestone, true)
	wedge(model, "PorchRoof", V3(porchW + 0.6, 1.1, porchD + 0.4), frame * CFrame.new(0, height * 0.48 + 0.55, porchZ) * CFrame.Angles(0, math.pi, 0), roof, Enum.Material.Slate, false)

	for _, sx in { -1, 1 } do
		local px = sx * (porchW / 2 - 0.2)
		part(model, "PorchPost", V3(0.35, height * 0.48, 0.35), frame * CFrame.new(px, height * 0.24, depth / 2 + porchD - 0.2), beamColor, Enum.Material.Wood, false)
		part(model, "PorchRailSide", V3(0.22, 0.22, porchD), frame * CFrame.new(px, 1.55, porchZ), beamColor, Enum.Material.Wood, false)
		addWallLamp(model, frame * CFrame.new(px, 3.8, depth / 2 + porchD - 0.1))
	end

	-- Двустворчатая дверь трактира
	part(model, "DoorFrame", V3(3.6, 4.8, 0.28), frame * CFrame.new(0, 2.65, depth / 2 + 0.05), beamColor, Enum.Material.Wood, false)
	part(model, "DoorL", V3(1.5, 4.4, 0.22), frame * CFrame.new(-0.78, 2.55, depth / 2 + 0.12), MED_WOOD, Enum.Material.WoodPlanks, false)
	part(model, "DoorR", V3(1.5, 4.4, 0.22), frame * CFrame.new(0.78, 2.55, depth / 2 + 0.12), MED_WOOD, Enum.Material.WoodPlanks, false)

	-- Вывеска-кружка на кронштейне
	local mugCF = frame * CFrame.new(porchW / 2 + 0.6, height * 0.54, depth / 2 + 1.4)
	part(model, "MugBracket", V3(0.24, 0.24, 1.8), frame * CFrame.new(porchW / 2 + 0.6, height * 0.54 + 0.75, depth / 2 + 0.8), DARK_METAL, Enum.Material.Metal, false)
	cylinder(model, "MugBody", mugCF, 1.15, 0.95, C3(215, 165, 65), Enum.Material.Wood, false)
	cylinder(model, "MugFoam", mugCF * CFrame.new(0, 0.62, 0), 0.28, 1.02, C3(250, 248, 240), Enum.Material.SmoothPlastic, false)
	part(model, "MugHandle", V3(0.18, 0.65, 0.35), mugCF * CFrame.new(0, 0, 0.55), DARK_METAL, Enum.Material.Metal, false)

	-- Окна первого и второго этажей
	for _, sx in { -1, 1 } do
		addWindow(model, frame * CFrame.new(sx * (width * 0.34), height * 0.27, depth / 2), 1.8, 1.8, beamColor, nil, false, rng)
		addWindow(model, frame * CFrame.new(sx * (width * 0.3), height * 0.74, depth / 2), 1.8, 1.8, beamColor, nil, false, rng)
	end
end

--- Собирает дом выбранного стиля внутри `parent` (без PrimaryPart, не более 70 деталей).
function Buildings.house(
	parent: Instance,
	center: Vector3,
	width: number,
	depth: number,
	height: number,
	wall: Color3,
	roof: Color3,
	yaw: number,
	style: string
)
	local kind = style or "cottage"
	local model = Instance.new("Model")
	model.Name = "House_" .. kind
	model.Parent = parent

	local seed = math.floor(center.X * 31 + center.Z * 17)
	local rng = Random.new(seed)
	local frame = CFrame.new(center) * CFrame.Angles(0, yaw, 0)

	-- Цоколь уходит на 3.6 стада ниже center.Y (верх на center.Y + 0.4), чтобы дом не проваливался на склонах
	local foundColor = shiftColor(wall, STONE_GRAY, 0.7)
	part(
		model,
		"Foundation",
		V3(width + 1.2, 4, depth + 1.2),
		frame * CFrame.new(0, -1.6, 0),
		foundColor,
		Enum.Material.Cobblestone,
		true
	)

	if kind == "stone" then
		buildStone(model, frame, width, depth, height, wall, roof, rng)
	elseif kind == "shop" then
		buildShop(model, frame, width, depth, height, wall, roof, rng)
	elseif kind == "tower" then
		buildTower(model, frame, width, depth, height, wall, roof, rng)
	elseif kind == "inn" then
		buildInn(model, frame, width, depth, height, wall, roof, rng)
	else
		buildCottage(model, frame, width, depth, height, wall, roof, rng)
	end
end

return Buildings
