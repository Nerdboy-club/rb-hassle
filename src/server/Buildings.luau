-- Сборка разнообразных зданий из простых деталей без внешних ассетов.
-- Архитектура соответствует городам Острова Жадности из аниме Hunter × Hunter:
--   cottage   — фахверковые европейские домики (Антокиба, Рубикута, Бунзен)
--   masadora  — песчаниковая восточно-средиземноморская архитектура с куполом и арками (Масадора)
--   villa     — романтичные средиземноморские виллы с черепицей, балконом и перголой (Аиай)
--   castle    — королевская крепость с зубцами, угловой башенкой и знамёнами (Лимейро)
--   shop      — лавка с полосатым тентом, витриной и прилавком
--   inn       — двухэтажный трактир с выступающим верхним этажом (jettying)
--   tower     — высокая средневековая башня со шпилем
--   stone     — каменный особняк с контрфорсами (Дориас)
--   cabin     — бревенчатый сруб с поленницей (Деревня горных бандитов)
local Buildings = {}

local V3 = Vector3.new
local C3 = Color3.fromRGB

local GLASS_COLOR = C3(255, 230, 150)
local DARK_WOOD = C3(72, 48, 30)
local MED_WOOD = C3(112, 78, 48)
local LIGHT_WOOD = C3(155, 115, 72)
local STONE_GRAY = C3(128, 126, 120)
local DARK_METAL = C3(44, 46, 54)
local GOLD_ACCENT = C3(235, 195, 75)

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

--- Мягкий дымок из печной трубы.
local function addChimneySmoke(attachPart: BasePart)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Smoke"
	emitter.Rate = 1.4
	emitter.Lifetime = NumberRange.new(3.5, 5.5)
	emitter.Speed = NumberRange.new(1.4, 2.4)
	emitter.SpreadAngle = Vector2.new(14, 14)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(0.5, 1.8),
		NumberSequenceKeypoint.new(1, 3.4),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.72),
		NumberSequenceKeypoint.new(0.6, 0.84),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(C3(215, 215, 222))
	emitter.Acceleration = V3(0.5, 0.9, 0.3)
	emitter.Parent = attachPart
end

--- Настенный фонарь у входа с тёплым источником света.
local function addWallLamp(model: Instance, attachCF: CFrame, lightColor: Color3?)
	part(model, "LampBracket", V3(0.22, 0.22, 0.7), attachCF * CFrame.new(0, 0, 0.35), DARK_METAL, Enum.Material.Metal, false)
	local bulb = part(model, "LampBulb", V3(0.75, 0.9, 0.75), attachCF * CFrame.new(0, -0.25, 0.65), GLASS_COLOR, Enum.Material.Neon, false, Enum.PartType.Ball)
	bulb.Transparency = 0.15
	local light = Instance.new("PointLight")
	light.Color = lightColor or C3(255, 216, 140)
	light.Brightness = 1.3
	light.Range = 16
	light.Shadows = true
	light.Parent = bulb
end

--- Светящееся окно с рамой, подоконником, переплётом и опциональными ставнями/цветами.
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
	part(model, "WindowFrame", V3(w + 0.35, h + 0.35, 0.22), faceCF * CFrame.new(0, 0, 0.04), frameColor, Enum.Material.Wood, false)
	local glass = part(model, "WindowGlass", V3(w, h, 0.16), faceCF * CFrame.new(0, 0, 0.12), GLASS_COLOR, Enum.Material.Neon, false)
	glass.Transparency = 0.25
	-- Вертикальный и горизонтальный переплёт оконной рамы (крестовина как в аниме)
	part(model, "WindowMullionV", V3(0.14, h, 0.22), faceCF * CFrame.new(0, 0, 0.14), frameColor, Enum.Material.Wood, false)
	part(model, "WindowMullionH", V3(w, 0.14, 0.22), faceCF * CFrame.new(0, 0, 0.14), frameColor, Enum.Material.Wood, false)
	part(model, "WindowSill", V3(w + 0.65, 0.24, 0.55), faceCF * CFrame.new(0, -h / 2 - 0.12, 0.22), frameColor, Enum.Material.Wood, false)

	if shutterColor then
		local sw = math.max(0.45, w * 0.42)
		part(model, "ShutterL", V3(sw, h + 0.1, 0.18), faceCF * CFrame.new(-w / 2 - sw / 2 - 0.08, 0, 0.12), shutterColor, Enum.Material.WoodPlanks, false)
		part(model, "ShutterR", V3(sw, h + 0.1, 0.18), faceCF * CFrame.new(w / 2 + sw / 2 + 0.08, 0, 0.12), shutterColor, Enum.Material.WoodPlanks, false)
	end

	if withFlowers then
		local boxY = -h / 2 - 0.42
		part(model, "FlowerBox", V3(w + 0.4, 0.45, 0.65), faceCF * CFrame.new(0, boxY, 0.32), MED_WOOD, Enum.Material.Wood, false)
		local flowerColors = { C3(245, 70, 95), C3(255, 205, 60), C3(195, 90, 245), C3(255, 140, 60) }
		for i = -1, 1 do
			local idx = rng and rng:NextInteger(1, #flowerColors) or (i + 2)
			part(
				model,
				"Flower",
				V3(0.44, 0.44, 0.44),
				faceCF * CFrame.new(i * (w * 0.3), boxY + 0.32, 0.34),
				flowerColors[idx],
				Enum.Material.SmoothPlastic,
				false,
				Enum.PartType.Ball
			)
		end
	end
end

--- Двускатная крыша со скатами вдоль X (конёк вдоль Z).
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
	local gableH = roofH * (width / 2) / halfSpan
	wedge(
		model,
		"GableLeft",
		V3(depth, gableH, width / 2),
		frame * CFrame.new(-width / 4, height + gableH / 2, 0) * CFrame.Angles(0, -math.pi / 2, 0),
		wallColor,
		Enum.Material.Plaster,
		true
	)
	wedge(
		model,
		"GableRight",
		V3(depth, gableH, width / 2),
		frame * CFrame.new(width / 4, height + gableH / 2, 0) * CFrame.Angles(0, math.pi / 2, 0),
		wallColor,
		Enum.Material.Plaster,
		true
	)
	part(model, "RidgeBeam", V3(0.45, 0.45, spanZ + 0.2), frame * CFrame.new(0, height + roofH, 0), beamColor, Enum.Material.Wood, false)
	-- Карнизные свесы (деревянная окантовка крыши по краям)
	part(model, "EaveTrimL", V3(0.35, 0.35, spanZ + 0.2), frame * CFrame.new(-halfSpan, height + 0.15, 0), beamColor, Enum.Material.Wood, false)
	part(model, "EaveTrimR", V3(0.35, 0.35, spanZ + 0.2), frame * CFrame.new(halfSpan, height + 0.15, 0), beamColor, Enum.Material.Wood, false)
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
		Enum.Material.Plaster,
		true
	)
	wedge(
		model,
		"GableBack",
		V3(width, gableH, depth / 2),
		frame * CFrame.new(0, height + gableH / 2, -depth / 4),
		wallColor,
		Enum.Material.Plaster,
		true
	)
	part(model, "RidgeBeam", V3(spanX + 0.2, 0.45, 0.45), frame * CFrame.new(0, height + roofH, 0), beamColor, Enum.Material.Wood, false)
	-- Карнизные свесы спереди и сзади
	part(model, "EaveTrimF", V3(spanX + 0.2, 0.35, 0.35), frame * CFrame.new(0, height + 0.15, halfSpan), beamColor, Enum.Material.Wood, false)
	part(model, "EaveTrimB", V3(spanX + 0.2, 0.35, 0.35), frame * CFrame.new(0, height + 0.15, -halfSpan), beamColor, Enum.Material.Wood, false)
end

-- ===================== СТИЛЬ 1: COTTAGE (фахверк Антокибы) =====================
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
	local lightWall = shiftColor(wall, C3(252, 246, 235), 0.38)
	local beamColor = shiftColor(roof, DARK_WOOD, 0.65)
	local shutterColor = shiftColor(roof, C3(65, 105, 80), 0.45)

	part(model, "Wall", V3(width, height, depth), frame * CFrame.new(0, height / 2, 0), lightWall, Enum.Material.Plaster, true)

	-- Фахверковые балки: вертикальные стойки по углам и фасаду, пояса и раскосы
	local bw = 0.42
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(model, "CornerBeam", V3(bw, height, bw), frame * CFrame.new(sx * (width / 2 - 0.1), height / 2, sz * (depth / 2 - 0.1)), beamColor, Enum.Material.Wood, false)
		end
	end
	part(model, "BeltTop", V3(width + 0.28, bw, depth + 0.28), frame * CFrame.new(0, height - bw / 2, 0), beamColor, Enum.Material.Wood, false)
	part(model, "BeltMid", V3(width + 0.26, bw * 0.85, depth + 0.26), frame * CFrame.new(0, height * 0.52, 0), beamColor, Enum.Material.Wood, false)

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

	-- Двускатная крыша с кирпичной трубой и дымом
	local roofH = math.clamp(width * 0.44, 3.8, 5.6)
	addGableRoofZ(model, frame, width, depth, height, roofH, 1.35, roof, lightWall, beamColor, Enum.Material.Slate)

	-- Резные деревянные кронштейны под карнизом (сказочный европейский стиль)
	for _, sx in { -1, 1 } do
		wedge(
			model,
			"EaveBracketF",
			V3(0.38, 0.75, 0.75),
			frame * CFrame.new(sx * (width / 2 - 0.2), height - 0.38, depth / 2 + 0.35) * CFrame.Angles(0, sx > 0 and 0 or math.pi, 0),
			beamColor,
			Enum.Material.Wood,
			false
		)
		wedge(
			model,
			"EaveBracketB",
			V3(0.38, 0.75, 0.75),
			frame * CFrame.new(sx * (width / 2 - 0.2), height - 0.38, -depth / 2 - 0.35) * CFrame.Angles(0, sx > 0 and math.pi or 0, 0),
			beamColor,
			Enum.Material.Wood,
			false
		)
	end

	local chimX = -width * 0.26
	local chimZ = -depth * 0.2
	local chimTop = height + roofH + 1.6
	part(model, "Chimney", V3(1.5, chimTop - height * 0.6, 1.5), frame * CFrame.new(chimX, (chimTop + height * 0.6) / 2, chimZ), C3(155, 78, 62), Enum.Material.Brick, false)
	local chimCap = part(model, "ChimneyCap", V3(1.85, 0.35, 1.85), frame * CFrame.new(chimX, chimTop + 0.15, chimZ), STONE_GRAY, Enum.Material.Cobblestone, false)
	addChimneySmoke(chimCap)

	-- Входная группа
	local doorX = -width * 0.18
	part(model, "PorchStep", V3(3.8, 0.5, 2.2), frame * CFrame.new(doorX, 0.25, depth / 2 + 0.9), STONE_GRAY, Enum.Material.Cobblestone, true)
	part(model, "DoorFrame", V3(3.1, 5.5, 0.28), frame * CFrame.new(doorX, 2.75, depth / 2 + 0.05), beamColor, Enum.Material.Wood, false)
	part(model, "Door", V3(2.6, 5.1, 0.24), frame * CFrame.new(doorX, 2.65, depth / 2 + 0.12), MED_WOOD, Enum.Material.WoodPlanks, false)
	part(model, "DoorHandle", V3(0.2, 0.2, 0.3), frame * CFrame.new(doorX + 0.85, 2.5, depth / 2 + 0.26), GOLD_ACCENT, Enum.Material.Metal, false)
	wedge(model, "DoorCanopy", V3(3.6, 0.9, 1.4), frame * CFrame.new(doorX, 5.8, depth / 2 + 0.65) * CFrame.Angles(0, math.pi, 0), roof, Enum.Material.Slate, false)
	addWallLamp(model, frame * CFrame.new(doorX - 2.0, 4.3, depth / 2))

	addWindow(model, frame * CFrame.new(width * 0.24, height * 0.54, depth / 2), 2.1, 2.1, beamColor, shutterColor, true, rng)
	addWindow(model, frame * CFrame.new(width / 2, height * 0.56, 0) * CFrame.Angles(0, math.pi / 2, 0), 2.0, 2.0, beamColor, shutterColor, false, rng)
	addWindow(model, frame * CFrame.new(-width / 2, height * 0.56, 0) * CFrame.Angles(0, -math.pi / 2, 0), 2.0, 2.0, beamColor, shutterColor, false, rng)
end

-- ===================== СТИЛЬ 2: MASADORA (город магии: песчаник, купол, арки) =====================
local function buildMasadora(
	model: Instance,
	frame: CFrame,
	width: number,
	depth: number,
	height: number,
	wall: Color3,
	roof: Color3,
	rng: Random
)
	local sandWall = shiftColor(wall, C3(232, 206, 168), 0.55)
	local stoneTrim = shiftColor(sandWall, C3(185, 155, 115), 0.35)
	local domeColor = shiftColor(roof, C3(40, 160, 205), 0.4) -- яркая бирюзовая майолика восточного города

	-- Основной песчаниковый массив
	part(model, "Wall", V3(width, height, depth), frame * CFrame.new(0, height / 2, 0), sandWall, Enum.Material.Cobblestone, true)

	-- Декоративный бирюзовый фриз из глазурованной плитки под парапетом
	part(model, "MosaicBand", V3(width + 0.4, 0.4, depth + 0.4), frame * CFrame.new(0, height - 0.2, 0), domeColor, Enum.Material.SmoothPlastic, false)

	-- Зубчатый парапет по крыше (crenellations)
	part(model, "RoofSlab", V3(width + 0.8, 0.6, depth + 0.8), frame * CFrame.new(0, height + 0.3, 0), stoneTrim, Enum.Material.Slate, true)
	local numMerlons = 4
	local mw = (width + 0.8) / (numMerlons * 2 - 1)
	for i = 1, numMerlons do
		local mx = -(width + 0.8) / 2 + (i - 1) * mw * 2 + mw / 2
		part(model, "MerlonF", V3(mw, 1.1, 0.45), frame * CFrame.new(mx, height + 1.15, depth / 2 + 0.4), stoneTrim, Enum.Material.Cobblestone, false)
		part(model, "MerlonB", V3(mw, 1.1, 0.45), frame * CFrame.new(mx, height + 1.15, -depth / 2 - 0.4), stoneTrim, Enum.Material.Cobblestone, false)
	end

	-- Восточный купол с золотым шпилем
	local domeDiam = math.min(width, depth) * 0.72
	local domeH = domeDiam * 0.48
	cylinder(model, "DomeDrum", frame * CFrame.new(0, height + 0.9, 0), 1.2, domeDiam, stoneTrim, Enum.Material.Cobblestone, true)
	part(
		model,
		"Dome",
		V3(domeDiam, domeH * 2, domeDiam),
		frame * CFrame.new(0, height + 1.5, 0),
		domeColor,
		Enum.Material.SmoothPlastic,
		true,
		Enum.PartType.Ball
	)
	cylinder(model, "DomeSpire", frame * CFrame.new(0, height + 1.5 + domeH + 1.2, 0), 2.4, 0.35, GOLD_ACCENT, Enum.Material.Metal, false)
	part(model, "DomeOrb", V3(0.8, 0.8, 0.8), frame * CFrame.new(0, height + 1.5 + domeH + 2.4, 0), GOLD_ACCENT, Enum.Material.Metal, false, Enum.PartType.Ball)

	-- Глубокая подковообразная арка портала
	local doorW = 3.2
	local doorH = 5.2
	part(model, "PortalArchL", V3(0.7, doorH, 0.8), frame * CFrame.new(-doorW / 2 - 0.35, doorH / 2, depth / 2 + 0.35), stoneTrim, Enum.Material.Cobblestone, true)
	part(model, "PortalArchR", V3(0.7, doorH, 0.8), frame * CFrame.new(doorW / 2 + 0.35, doorH / 2, depth / 2 + 0.35), stoneTrim, Enum.Material.Cobblestone, true)
	cylinder(model, "PortalArchTop", frame * CFrame.new(0, doorH, depth / 2 + 0.35), 0.8, doorW + 1.4, stoneTrim, Enum.Material.Cobblestone, false)
	part(model, "DoorWood", V3(doorW, doorH - 0.4, 0.25), frame * CFrame.new(0, (doorH - 0.4) / 2, depth / 2 + 0.1), DARK_WOOD, Enum.Material.WoodPlanks, false)

	-- Магический восточный фонарь с аметистовым свечением
	addWallLamp(model, frame * CFrame.new(doorW / 2 + 1.4, doorH * 0.75, depth / 2), C3(210, 150, 255))

	-- Высокие арочные окна
	addWindow(model, frame * CFrame.new(width * 0.3, height * 0.58, depth / 2), 1.4, 2.8, stoneTrim, nil, false, rng)
	addWindow(model, frame * CFrame.new(-width * 0.3, height * 0.58, depth / 2), 1.4, 2.8, stoneTrim, nil, false, rng)
	addWindow(model, frame * CFrame.new(width / 2, height * 0.58, 0) * CFrame.Angles(0, math.pi / 2, 0), 1.5, 2.8, stoneTrim, nil, false, rng)
end

-- ===================== СТИЛЬ 3: VILLA (романтичная вилла Аиай) =====================
local function buildVilla(
	model: Instance,
	frame: CFrame,
	width: number,
	depth: number,
	height: number,
	wall: Color3,
	roof: Color3,
	rng: Random
)
	local villaWall = shiftColor(wall, C3(252, 238, 224), 0.45) -- тёплый персиково-кремовый
	local terraCotta = shiftColor(roof, C3(205, 95, 60), 0.55) -- тёплая обожжённая глина
	local woodTrim = shiftColor(roof, DARK_WOOD, 0.55)
	local shutterCol = C3(60, 115, 100) -- итальянский шалфей

	part(model, "Wall", V3(width, height, depth), frame * CFrame.new(0, height / 2, 0), villaWall, Enum.Material.Plaster, true)

	-- Черепичная пологая четырёхскатная крыша с широким карнизом
	local roofH = math.clamp(depth * 0.34, 2.8, 4.2)
	addGableRoofX(model, frame, width, depth, height, roofH, 1.4, terraCotta, villaWall, woodTrim, Enum.Material.Slate)

	-- Романтичный балкон второго этажа с балюстрадой
	local balW = width * 0.58
	local balD = 2.4
	local balY = height * 0.54
	part(model, "BalconyBase", V3(balW, 0.45, balD), frame * CFrame.new(0, balY, depth / 2 + balD / 2), terraCotta, Enum.Material.Cobblestone, true)
	part(model, "BalconyRailTop", V3(balW, 0.24, 0.24), frame * CFrame.new(0, balY + 1.35, depth / 2 + balD - 0.12), woodTrim, Enum.Material.Wood, false)
	for i = -2, 2 do
		cylinder(model, "Baluster", frame * CFrame.new(i * (balW * 0.22), balY + 0.7, depth / 2 + balD - 0.12), 1.2, 0.24, villaWall, Enum.Material.SmoothPlastic, false)
	end

	-- Деревянная пергола над балконом (навес с рейками)
	local pergH = balY + 3.2
	part(model, "PergolaBeamL", V3(0.25, 0.35, balD + 0.6), frame * CFrame.new(-balW / 2 + 0.2, pergH, depth / 2 + balD / 2), woodTrim, Enum.Material.Wood, false)
	part(model, "PergolaBeamR", V3(0.25, 0.35, balD + 0.6), frame * CFrame.new(balW / 2 - 0.2, pergH, depth / 2 + balD / 2), woodTrim, Enum.Material.Wood, false)
	for r = 1, 4 do
		part(model, "PergolaSlat", V3(balW + 0.4, 0.18, 0.28), frame * CFrame.new(0, pergH + 0.25, depth / 2 + (r - 0.5) * (balD / 4)), woodTrim, Enum.Material.Wood, false)
	end

	-- Вьющаяся зелень/плющ на углу дома
	local ivyColor = C3(65, 135, 70)
	for leaf = 1, 5 do
		local ly = height * (0.2 + leaf * 0.13)
		part(model, "IvyLeaf", V3(0.85, 0.85, 0.85), frame * CFrame.new(width / 2 + 0.2, ly, depth / 2 + 0.2) * CFrame.Angles(0.3, leaf * 0.6, 0.2), ivyColor, Enum.Material.Grass, false, Enum.PartType.Ball)
	end

	-- Арочные французские двери и окна со ставнями
	local doorX = -width * 0.18
	part(model, "DoorStep", V3(3.2, 0.4, 1.8), frame * CFrame.new(doorX, 0.2, depth / 2 + 0.7), terraCotta, Enum.Material.Cobblestone, true)
	part(model, "DoorFrame", V3(2.8, 5.2, 0.25), frame * CFrame.new(doorX, 2.6, depth / 2 + 0.08), woodTrim, Enum.Material.Wood, false)
	part(model, "DoorSlab", V3(2.4, 4.8, 0.22), frame * CFrame.new(doorX, 2.5, depth / 2 + 0.14), MED_WOOD, Enum.Material.WoodPlanks, false)
	addWallLamp(model, frame * CFrame.new(doorX - 1.8, 4.2, depth / 2))

	addWindow(model, frame * CFrame.new(0, balY + 1.6, depth / 2), 2.0, 2.6, woodTrim, shutterCol, false, rng)
	addWindow(model, frame * CFrame.new(width * 0.28, height * 0.32, depth / 2), 1.8, 2.2, woodTrim, shutterCol, true, rng)
end

-- ===================== СТИЛЬ 4: CASTLE (королевский замок Лимейро) =====================
local function buildCastle(
	model: Instance,
	frame: CFrame,
	width: number,
	depth: number,
	height: number,
	wall: Color3,
	roof: Color3,
	rng: Random
)
	local granite = shiftColor(wall, C3(138, 140, 146), 0.5)
	local darkStone = shiftColor(granite, C3(80, 82, 88), 0.4)
	local bannerBlue = C3(30, 60, 130)

	part(model, "Wall", V3(width, height, depth), frame * CFrame.new(0, height / 2, 0), granite, Enum.Material.Cobblestone, true)

	-- Зубчатый парапет по всему периметру замка
	part(model, "BattleFloor", V3(width + 0.8, 0.5, depth + 0.8), frame * CFrame.new(0, height + 0.25, 0), darkStone, Enum.Material.Slate, true)
	local mCount = 5
	local mStep = (width + 0.8) / (mCount * 2 - 1)
	for i = 1, mCount do
		local mx = -(width + 0.8) / 2 + (i - 1) * mStep * 2 + mStep / 2
		part(model, "CrenelF", V3(mStep, 1.3, 0.5), frame * CFrame.new(mx, height + 1.15, depth / 2 + 0.4), darkStone, Enum.Material.Cobblestone, false)
		part(model, "CrenelB", V3(mStep, 1.3, 0.5), frame * CFrame.new(mx, height + 1.15, -depth / 2 - 0.4), darkStone, Enum.Material.Cobblestone, false)
	end

	-- Круглая угловая дозорная башенка (барбакан) со шпилем
	local turDiam = 3.6
	local turX = width / 2 + 0.4
	local turZ = depth / 2 + 0.4
	cylinder(model, "TurretCorbel", frame * CFrame.new(turX, height * 0.45, turZ), 1.2, turDiam * 0.85, darkStone, Enum.Material.Cobblestone, true)
	cylinder(model, "TurretBody", frame * CFrame.new(turX, height * 0.75, turZ), height * 0.7, turDiam, granite, Enum.Material.Cobblestone, true)
	-- Коническая остроконечная крыша башенки
	cylinder(model, "TurretRoof", frame * CFrame.new(turX, height * 1.18, turZ), 3.4, turDiam + 0.4, roof, Enum.Material.Slate, true)
	cylinder(model, "TurretSpire", frame * CFrame.new(turX, height * 1.18 + 2.4, turZ), 2.2, 0.35, GOLD_ACCENT, Enum.Material.Metal, false)

	-- Королевские сине-золотые знамёна на фасаде
	for _, sx in { -1, 1 } do
		local bx = sx * (width * 0.34)
		part(model, "BannerPole", V3(0.2, 0.2, 1.4), frame * CFrame.new(bx, height * 0.82, depth / 2 + 0.7), DARK_METAL, Enum.Material.Metal, false)
		part(model, "BannerCloth", V3(1.4, 4.2, 0.15), frame * CFrame.new(bx, height * 0.82 - 2.1, depth / 2 + 1.2), bannerBlue, Enum.Material.Fabric, false)
		part(model, "BannerTrim", V3(1.4, 0.35, 0.18), frame * CFrame.new(bx, height * 0.82 - 4.2, depth / 2 + 1.2), GOLD_ACCENT, Enum.Material.Fabric, false)
	end

	-- Главные арочные ворота с решёткой (герса / portcullis)
	local gateW = 3.6
	local gateH = 5.6
	part(model, "GateArch", V3(gateW + 1.2, gateH + 0.6, 0.7), frame * CFrame.new(0, (gateH + 0.6) / 2, depth / 2 + 0.2), darkStone, Enum.Material.Cobblestone, true)
	part(model, "GateDoor", V3(gateW, gateH, 0.25), frame * CFrame.new(0, gateH / 2, depth / 2 + 0.12), DARK_WOOD, Enum.Material.WoodPlanks, false)
	-- Металлическая решётка ворот
	for bar = -1, 1 do
		part(model, "IronBar", V3(0.18, gateH, 0.18), frame * CFrame.new(bar * 0.9, gateH / 2, depth / 2 + 0.26), DARK_METAL, Enum.Material.Metal, false)
	end
	addWallLamp(model, frame * CFrame.new(-gateW / 2 - 1.2, 4.6, depth / 2))
	addWallLamp(model, frame * CFrame.new(gateW / 2 + 1.2, 4.6, depth / 2))

	-- Стрельчатые окна
	addWindow(model, frame * CFrame.new(0, height * 0.76, depth / 2), 1.5, 3.2, darkStone, nil, false, rng)
	addWindow(model, frame * CFrame.new(-width / 2, height * 0.65, 0) * CFrame.Angles(0, -math.pi / 2, 0), 1.4, 3.0, darkStone, nil, false, rng)
end

-- ===================== СТИЛЬ 5: CABIN (сруб горных бандитов) =====================
local function buildCabin(
	model: Instance,
	frame: CFrame,
	width: number,
	depth: number,
	height: number,
	wall: Color3,
	roof: Color3,
	rng: Random
)
	local logColor = shiftColor(wall, C3(90, 62, 40), 0.6)
	local shakeRoof = shiftColor(roof, C3(75, 55, 42), 0.45)
	local stoneChim = C3(115, 112, 108)

	-- Стены из горизонтальных брёвен с выступающими торцами по углам
	part(model, "WallCore", V3(width, height, depth), frame * CFrame.new(0, height / 2, 0), logColor, Enum.Material.Wood, true)
	local numLogs = math.floor(height / 1.1)
	for l = 1, numLogs do
		local ly = (l - 0.5) * (height / numLogs)
		-- Выступающие перерубы бревен по 4 углам
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				part(
					model,
					"LogEnd",
					V3(0.9, 0.9, 0.9),
					frame * CFrame.new(sx * (width / 2 + 0.3), ly, sz * (depth / 2 + 0.3)),
					logColor,
					Enum.Material.Wood,
					false,
					Enum.PartType.Ball
				)
			end
		end
	end

	-- Двускатная крыша из дранки с каменным коньком
	local roofH = math.clamp(width * 0.38, 3.2, 4.6)
	addGableRoofZ(model, frame, width, depth, height, roofH, 1.4, shakeRoof, logColor, DARK_WOOD, Enum.Material.WoodPlanks)

	-- Грубый каменный очаг/труба с дымком
	local chimX = width * 0.35
	local chimZ = 0
	local chimTop = height + roofH + 1.4
	local chim = part(model, "FieldstoneChimney", V3(2.2, chimTop, 2.2), frame * CFrame.new(chimX, chimTop / 2, chimZ), stoneChim, Enum.Material.Cobblestone, true)
	addChimneySmoke(chim)

	-- Поленница дров у боковой стены
	local stackZ = -depth * 0.1
	part(model, "WoodRack", V3(0.4, 2.2, 3.8), frame * CFrame.new(-width / 2 - 0.4, 1.1, stackZ), DARK_WOOD, Enum.Material.Wood, false)
	for row = 1, 3 do
		for col = 1, 3 do
			cylinder(
				model,
				"ChoppedLog",
				frame * CFrame.new(-width / 2 - 0.5, 0.4 + (row - 1) * 0.65, stackZ - 1.2 + (col - 1) * 0.9) * CFrame.Angles(0, math.pi / 2, 0),
				1.8,
				0.55,
				MED_WOOD,
				Enum.Material.Wood,
				false
			)
		end
	end

	-- Простая деревянная дверь и подвесной фонарь
	local doorX = -width * 0.15
	part(model, "DoorStep", V3(3.0, 0.35, 1.6), frame * CFrame.new(doorX, 0.18, depth / 2 + 0.6), stoneChim, Enum.Material.Cobblestone, true)
	part(model, "DoorPlank", V3(2.5, 4.8, 0.25), frame * CFrame.new(doorX, 2.4, depth / 2 + 0.12), DARK_WOOD, Enum.Material.WoodPlanks, false)
	addWallLamp(model, frame * CFrame.new(doorX + 1.8, 3.8, depth / 2))

	addWindow(model, frame * CFrame.new(width * 0.22, height * 0.52, depth / 2), 1.6, 1.6, DARK_WOOD, nil, false, rng)
end

-- ===================== СТИЛЬ 6: SHOP (торговая лавка с тентом) =====================
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

	local doorX = -width * 0.26
	part(model, "DoorStep", V3(3.2, 0.4, 1.6), frame * CFrame.new(doorX, 0.2, depth / 2 + 0.6), STONE_GRAY, Enum.Material.Cobblestone, true)
	part(model, "DoorFrame", V3(2.9, 5.3, 0.26), frame * CFrame.new(doorX, 2.65, depth / 2 + 0.05), trimColor, Enum.Material.Wood, false)
	part(model, "Door", V3(2.4, 4.9, 0.22), frame * CFrame.new(doorX, 2.55, depth / 2 + 0.12), MED_WOOD, Enum.Material.WoodPlanks, false)

	local winW = math.max(3.4, width * 0.42)
	local winX = width * 0.18
	addWindow(model, frame * CFrame.new(winX, height * 0.46, depth / 2), winW, 3.0, trimColor, nil, false, rng)

	-- Полосатый тканевый навес
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

	-- Торговая вывеска
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

	-- Прилавок с товарами
	local counterZ = depth / 2 + 1.55
	part(model, "CounterBase", V3(winW, 2.1, 1.3), frame * CFrame.new(winX, 1.05, counterZ), MED_WOOD, Enum.Material.WoodPlanks, true)
	part(model, "CounterTop", V3(winW + 0.35, 0.24, 1.55), frame * CFrame.new(winX, 2.2, counterZ), LIGHT_WOOD, Enum.Material.Wood, false)
	part(model, "GoodsCrate1", V3(1.1, 0.9, 1.0), frame * CFrame.new(winX - 0.9, 2.75, counterZ) * CFrame.Angles(0, 0.2, 0), C3(175, 130, 75), Enum.Material.WoodPlanks, false)
	part(model, "GoodsCrate2", V3(0.95, 0.8, 0.95), frame * CFrame.new(winX + 0.35, 2.7, counterZ + 0.05) * CFrame.Angles(0, -0.25, 0), stripeA, Enum.Material.SmoothPlastic, false)

	addWallLamp(model, frame * CFrame.new(doorX + 1.75, 4.3, depth / 2))
	addWindow(model, frame * CFrame.new(width / 2, height * 0.55, 0) * CFrame.Angles(0, math.pi / 2, 0), 2.0, 2.0, trimColor, nil, false, rng)
end

-- ===================== СТИЛЬ 7: INN (трактир с выступом jettying) =====================
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

	-- 1-й этаж каменный, 2-й этаж с выступом (кантилевер)
	local h1 = height * 0.48
	local h2 = height - h1
	part(model, "FirstFloor", V3(width, h1, depth), frame * CFrame.new(0, h1 / 2, 0), STONE_GRAY, Enum.Material.Cobblestone, true)
	part(model, "SecondFloor", V3(width + 0.9, h2, depth + 0.9), frame * CFrame.new(0, h1 + h2 / 2, 0), innWall, Enum.Material.Plaster, true)

	-- Резные деревянные кронштейны под выступом
	for _, sx in { -1, 1 } do
		wedge(model, "CorbelF", V3(0.5, 0.9, 0.45), frame * CFrame.new(sx * (width * 0.4), h1 - 0.45, depth / 2 + 0.22) * CFrame.Angles(math.pi, 0, 0), beamColor, Enum.Material.Wood, false)
		wedge(model, "CorbelB", V3(0.5, 0.9, 0.45), frame * CFrame.new(sx * (width * 0.4), h1 - 0.45, -depth / 2 - 0.22), beamColor, Enum.Material.Wood, false)
	end

	addGableRoofX(model, frame, width + 0.9, depth + 0.9, height, roofH, 1.35, roof, innWall, beamColor, Enum.Material.Slate)

	-- Две трубы с дымом
	for _, sx in { -1, 1 } do
		local chim = part(model, "InnChimney", V3(1.4, height + roofH * 0.7, 1.4), frame * CFrame.new(sx * (width * 0.32), (height + roofH * 0.7) / 2, -depth * 0.2), C3(145, 72, 58), Enum.Material.Brick, false)
		addChimneySmoke(chim)
	end

	-- Вход с дубовой дверью
	local doorX = -width * 0.2
	part(model, "DoorStep", V3(3.2, 0.4, 1.6), frame * CFrame.new(doorX, 0.2, depth / 2 + 0.6), STONE_GRAY, Enum.Material.Cobblestone, true)
	part(model, "Door", V3(2.5, 4.8, 0.24), frame * CFrame.new(doorX, 2.4, depth / 2 + 0.1), DARK_WOOD, Enum.Material.WoodPlanks, false)
	addWallLamp(model, frame * CFrame.new(doorX - 1.8, 3.8, depth / 2))

	-- Уличная лавка и бочка с элем
	part(model, "TavernBench", V3(3.4, 1.1, 1.0), frame * CFrame.new(width * 0.24, 0.55, depth / 2 + 1.2), MED_WOOD, Enum.Material.Wood, false)
	cylinder(model, "AleKeg", frame * CFrame.new(width * 0.24 + 2.2, 1.1, depth / 2 + 1.2), 2.0, 1.5, DARK_WOOD, Enum.Material.Wood, false)

	addWindow(model, frame * CFrame.new(width * 0.24, h1 / 2, depth / 2), 2.2, 2.0, beamColor, nil, false, rng)
	addWindow(model, frame * CFrame.new(-width * 0.22, height * 0.72, depth / 2 + 0.45), 1.8, 2.2, beamColor, nil, true, rng)
	addWindow(model, frame * CFrame.new(width * 0.22, height * 0.72, depth / 2 + 0.45), 1.8, 2.2, beamColor, nil, true, rng)
end

-- ===================== СТИЛЬ 8: TOWER (высокая каменная башня со шпилем) =====================
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

	for _, frac in { 0.36, 0.68, 0.98 } do
		part(model, "FloorBelt", V3(width + 0.7, 0.45, depth + 0.7), frame * CFrame.new(0, height * frac, 0), beltColor, Enum.Material.Slate, false)
	end

	-- Коническая ступенчатая крыша со шпилем
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
	cylinder(model, "Spire", frame * CFrame.new(0, coneY + 1.4, 0), 2.8, 0.45, GOLD_ACCENT, Enum.Material.Metal, false)

	-- Вход и балкон
	part(model, "DoorStep", V3(3.0, 0.45, 1.5), frame * CFrame.new(0, 0.22, depth / 2 + 0.6), beltColor, Enum.Material.Cobblestone, true)
	part(model, "Door", V3(2.2, 4.7, 0.22), frame * CFrame.new(0, 2.45, depth / 2 + 0.12), DARK_WOOD, Enum.Material.Wood, false)
	addWallLamp(model, frame * CFrame.new(-1.7, 4.2, depth / 2))

	local balY = height * 0.52
	local balW = math.max(3.6, width * 0.62)
	local balD = 2.2
	part(model, "BalconyFloor", V3(balW, 0.38, balD), frame * CFrame.new(0, balY, depth / 2 + balD / 2), beltColor, Enum.Material.Cobblestone, true)
	part(model, "BalconyRailFront", V3(balW, 0.22, 0.22), frame * CFrame.new(0, balY + 1.25, depth / 2 + balD - 0.12), trimColor, Enum.Material.Wood, false)

	addWindow(model, frame * CFrame.new(0, balY + 1.6, depth / 2), 1.5, 2.4, trimColor, nil, false, rng)
	addWindow(model, frame * CFrame.new(0, height * 0.83, depth / 2), 1.3, 2.0, trimColor, nil, false, rng)
end

-- ===================== СТИЛЬ 9: STONE (каменный особняк с контрфорсами) =====================
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

	local roofH = math.clamp(width * 0.38, 3.2, 4.8)
	addGableRoofZ(model, frame, width, depth, height, roofH, 1.2, roof, stoneWall, buttressColor, Enum.Material.Slate)

	-- Арочная дверь
	local doorW = 2.8
	local doorRectH = 4.2
	part(model, "Threshold", V3(doorW + 1.2, 0.45, 1.8), frame * CFrame.new(0, 0.22, depth / 2 + 0.7), trimColor, Enum.Material.Cobblestone, true)
	cylinder(model, "ArchRing", frame * CFrame.new(0, doorRectH, depth / 2 + 0.08), 0.45, doorW + 0.7, trimColor, Enum.Material.Cobblestone, false)
	part(model, "DoorSlab", V3(doorW, doorRectH, 0.28), frame * CFrame.new(0, doorRectH / 2, depth / 2 + 0.14), DARK_WOOD, Enum.Material.Wood, false)
	addWallLamp(model, frame * CFrame.new(-2.2, 4.4, depth / 2))

	addWindow(model, frame * CFrame.new(width * 0.28, height * 0.56, depth / 2), 1.2, 2.8, trimColor, nil, false, rng)
	addWindow(model, frame * CFrame.new(-width * 0.28, height * 0.56, depth / 2), 1.2, 2.8, trimColor, nil, false, rng)
end

--- Общие реалистичные детали фасада: каменный цоколь, водосточные трубы и жёлоб.
local function addShellDetails(
	model: Instance,
	frame: CFrame,
	width: number,
	depth: number,
	height: number,
	wall: Color3,
	kind: string
)
	if kind ~= "cottage" and kind ~= "villa" and kind ~= "shop" and kind ~= "inn" and kind ~= "stone" then
		return
	end
	local stone = shiftColor(wall, STONE_GRAY, 0.55)
	local courseY = 0.8
	local courseH = 1.6
	part(model, "PlinthLeft", V3(0.5, courseH, depth + 0.6), frame * CFrame.new(-width / 2 - 0.2, courseY, 0), stone, Enum.Material.Cobblestone, false)
	part(model, "PlinthRight", V3(0.5, courseH, depth + 0.6), frame * CFrame.new(width / 2 + 0.2, courseY, 0), stone, Enum.Material.Cobblestone, false)
	part(model, "PlinthBack", V3(width + 0.6, courseH, 0.5), frame * CFrame.new(0, courseY, -depth / 2 - 0.2), stone, Enum.Material.Cobblestone, false)

	local pipeH = height + 0.4
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			cylinder(
				model,
				"Downspout",
				frame * CFrame.new(sx * (width / 2 + 0.3), pipeH / 2 + 0.2, sz * (depth / 2 + 0.3)),
				pipeH,
				0.2,
				DARK_METAL,
				Enum.Material.Metal,
				false
			)
		end
	end
	part(model, "Gutter", V3(width + 0.8, 0.2, 0.3), frame * CFrame.new(0, height + 0.1, depth / 2 + 0.55), DARK_METAL, Enum.Material.Metal, false)
end

--- Главный диспетчер сборки зданий.
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

	-- Цоколь уходит вглубь террейна, чтобы здания стояли монолитно на любом рельефе
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

	if kind == "masadora" then
		buildMasadora(model, frame, width, depth, height, wall, roof, rng)
	elseif kind == "villa" then
		buildVilla(model, frame, width, depth, height, wall, roof, rng)
	elseif kind == "castle" then
		buildCastle(model, frame, width, depth, height, wall, roof, rng)
	elseif kind == "cabin" then
		buildCabin(model, frame, width, depth, height, wall, roof, rng)
	elseif kind == "shop" then
		buildShop(model, frame, width, depth, height, wall, roof, rng)
	elseif kind == "inn" then
		buildInn(model, frame, width, depth, height, wall, roof, rng)
	elseif kind == "tower" then
		buildTower(model, frame, width, depth, height, wall, roof, rng)
	elseif kind == "stone" then
		buildStone(model, frame, width, depth, height, wall, roof, rng)
	else
		buildCottage(model, frame, width, depth, height, wall, roof, rng)
	end

	addShellDetails(model, frame, width, depth, height, wall, kind)
end

return Buildings
