-- Стилизованная модель NPC: собирается кодом из простых частей, причёсок, одежды, аксессуаров и лица на SurfaceGui.
local RigBuilder = {}

-- Знак размаха конечностей при ходьбе: руки и ноги (вместе с рукавами, манжетами и обувью) качаются в противофазе.
local LIMB_SIGN: { [string]: number } = {
	LeftArm = 1,
	RightArm = -1,
	LeftArm_Sleeve = 1,
	RightArm_Sleeve = -1,
	LeftArm_Cuff = 1,
	RightArm_Cuff = -1,
	LeftArm_Shoulder = 1,
	RightArm_Shoulder = -1,
	LeftArm_Elbow = 1,
	RightArm_Elbow = -1,
	LeftArm_Hand = 1,
	RightArm_Hand = -1,
	RightArm_Mic = -1,
	LeftLeg = -1,
	RightLeg = 1,
	LeftLeg_Shoe = -1,
	RightLeg_Shoe = 1,
	LeftLeg_Knee = -1,
	RightLeg_Knee = 1,
	LeftLeg_Sole = -1,
	RightLeg_Sole = 1,
}

-- Высота сустава (плечо +1, бедро -1) от центра корня при scale = 1, вокруг которого качается деталь.
local LIMB_JOINT_Y: { [string]: number } = {
	LeftArm = 1,
	RightArm = 1,
	LeftArm_Sleeve = 1,
	RightArm_Sleeve = 1,
	LeftArm_Cuff = 1,
	RightArm_Cuff = 1,
	LeftArm_Shoulder = 1,
	RightArm_Shoulder = 1,
	LeftArm_Elbow = 1,
	RightArm_Elbow = 1,
	LeftArm_Hand = 1,
	RightArm_Hand = 1,
	RightArm_Mic = 1,
	LeftLeg = -1,
	RightLeg = -1,
	LeftLeg_Shoe = -1,
	RightLeg_Shoe = -1,
	LeftLeg_Knee = -1,
	RightLeg_Knee = -1,
	LeftLeg_Sole = -1,
	RightLeg_Sole = -1,
}

type PartEntry = {
	part: Part,
	offset: Vector3,
	rot: Vector3?,
}

local HAIR_PALETTE: { Color3 } = {
	Color3.fromRGB(28, 30, 38), -- угольно-чёрный
	Color3.fromRGB(75, 48, 34), -- тёмно-каштановый
	Color3.fromRGB(120, 80, 48), -- ореховый
	Color3.fromRGB(235, 195, 85), -- золотистый блонд
	Color3.fromRGB(218, 224, 236), -- серебристый
	Color3.fromRGB(185, 70, 45), -- рыже-медный
	Color3.fromRGB(46, 64, 118), -- тёмно-синий
	Color3.fromRGB(36, 82, 54), -- тёмно-зелёный (в духе Гона)
}

local IRIS_PALETTE: { Color3 } = {
	Color3.fromRGB(70, 130, 210),
	Color3.fromRGB(60, 155, 100),
	Color3.fromRGB(180, 125, 50),
	Color3.fromRGB(135, 85, 180),
	Color3.fromRGB(110, 70, 50),
	Color3.fromRGB(190, 65, 75),
}

local function nameHash(text: string): number
	local sum = #text * 31
	for i = 1, #text do
		sum = (sum * 37 + string.byte(text, i)) % 100003
	end
	return sum
end

local function block(name: string, size: Vector3, color: Color3, parent: Instance, material: Enum.Material?, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Shape = shape or Enum.PartType.Block
	part.Anchored = true
	part.CanCollide = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function addPart(
	parts: { PartEntry },
	model: Model,
	name: string,
	size: Vector3,
	color: Color3,
	offset: Vector3,
	rot: Vector3?,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local part = block(name, size, color, model, material, shape)
	table.insert(parts, { part = part, offset = offset, rot = rot })
	return part
end

local function roundFrame(parent: Instance, name: string, size: UDim2, pos: UDim2, color: Color3, radius: number?, rotation: number?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = pos
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	if rotation and rotation ~= 0 then
		frame.Rotation = rotation
	end
	frame.Parent = parent
	if radius and radius > 0 then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, radius)
		corner.Parent = frame
	end
	return frame
end

--- Выразительное лицо на передней грани головы (-Z = Enum.NormalId.Front).
local function buildFace(head: Part, role: string?, hash: number, hairColor: Color3, skinColor: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "FaceGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(140, 140)
	gui.LightInfluence = 0.2
	gui.MaxDistance = 90
	gui.Parent = head

	local irisColor = IRIS_PALETTE[hash % #IRIS_PALETTE + 1]
	if role == "eta" or role == "elena" then
		irisColor = Color3.fromRGB(95, 145, 230)
	elseif role == "goldgirl" then
		irisColor = Color3.fromRGB(235, 180, 50)
	elseif role == "razor" or role == "casino" then
		irisColor = Color3.fromRGB(190, 55, 65)
	elseif role == "catdiner" then
		irisColor = Color3.fromRGB(80, 185, 95)
	end

	local browColor = hairColor:Lerp(Color3.fromRGB(15, 15, 20), 0.35)
	local stern = role == "razor" or role == "goldguard" or role == "bandit" or role == "portmaster"
	local sick = role == "villager"
	local gentle = role == "eta" or role == "elena" or role == "goldgirl"
	local smirk = role == "casino" or role == "host"

	local eyeHeight = sick and 20 or (gentle and 28 or 24)
	local eyeY = sick and 56 or 50

	for side = 0, 1 do
		local x = side == 0 and 22 or 90
		local white = roundFrame(gui, side == 0 and "EyeL" or "EyeR", UDim2.fromOffset(28, eyeHeight), UDim2.fromOffset(x, eyeY), Color3.fromRGB(248, 250, 255), 6)
		local iris = roundFrame(white, "Iris", UDim2.fromOffset(18, eyeHeight - 4), UDim2.fromOffset(5, 2), irisColor, 6)
		local pupilW = role == "catdiner" and 5 or 10
		roundFrame(iris, "Pupil", UDim2.fromOffset(pupilW, eyeHeight - 10), UDim2.fromOffset(math.floor((18 - pupilW) / 2), 3), Color3.fromRGB(18, 18, 24), 4)
		roundFrame(white, "Glint", UDim2.fromOffset(6, 6), UDim2.fromOffset(16, 3), Color3.fromRGB(255, 255, 255), 3)
		roundFrame(white, "Lash", UDim2.fromOffset(28, 4), UDim2.fromOffset(0, 0), browColor, 2)
	end

	-- Брови с наклоном по характеру роли
	local browL = stern and 12 or (sick and -10 or (gentle and -3 or (smirk and -6 or 0)))
	local browR = stern and -12 or (sick and 10 or (gentle and 3 or (smirk and 4 or 0)))
	roundFrame(gui, "BrowL", UDim2.fromOffset(30, 6), UDim2.fromOffset(21, 39), browColor, 3, browL)
	roundFrame(gui, "BrowR", UDim2.fromOffset(30, 6), UDim2.fromOffset(89, 39), browColor, 3, browR)

	-- Тень носа
	roundFrame(gui, "Nose", UDim2.fromOffset(4, 9), UDim2.fromOffset(68, 76), skinColor:Lerp(Color3.fromRGB(40, 25, 20), 0.28), 2)

	-- Румянец у девушек, круги под глазами у больных, усы у кота
	if gentle then
		roundFrame(gui, "BlushL", UDim2.fromOffset(16, 8), UDim2.fromOffset(18, 80), Color3.fromRGB(245, 135, 155), 4).BackgroundTransparency = 0.35
		roundFrame(gui, "BlushR", UDim2.fromOffset(16, 8), UDim2.fromOffset(106, 80), Color3.fromRGB(245, 135, 155), 4).BackgroundTransparency = 0.35
	elseif sick then
		roundFrame(gui, "BagL", UDim2.fromOffset(24, 4), UDim2.fromOffset(24, 79), Color3.fromRGB(115, 125, 110), 2).BackgroundTransparency = 0.35
		roundFrame(gui, "BagR", UDim2.fromOffset(24, 4), UDim2.fromOffset(92, 79), Color3.fromRGB(115, 125, 110), 2).BackgroundTransparency = 0.35
	elseif role == "catdiner" then
		for row = 0, 1 do
			roundFrame(gui, "WhiskerL" .. row, UDim2.fromOffset(18, 3), UDim2.fromOffset(8, 82 + row * 8), browColor, 2, row == 0 and 6 or -6)
			roundFrame(gui, "WhiskerR" .. row, UDim2.fromOffset(18, 3), UDim2.fromOffset(114, 82 + row * 8), browColor, 2, row == 0 and -6 or 6)
		end
	end

	-- Рот
	if role == "catdiner" then
		roundFrame(gui, "MouthL", UDim2.fromOffset(14, 6), UDim2.fromOffset(56, 98), Color3.fromRGB(80, 40, 40), 3, -10)
		roundFrame(gui, "MouthR", UDim2.fromOffset(14, 6), UDim2.fromOffset(70, 98), Color3.fromRGB(80, 40, 40), 3, 10)
	elseif stern or sick then
		local angle = sick and -5 or 0
		roundFrame(gui, "Mouth", UDim2.fromOffset(24, 5), UDim2.fromOffset(58, 99), Color3.fromRGB(85, 50, 48), 2, angle)
	elseif smirk then
		local m = roundFrame(gui, "Mouth", UDim2.fromOffset(28, 9), UDim2.fromOffset(56, 96), Color3.fromRGB(65, 30, 35), 4, -5)
		roundFrame(m, "Teeth", UDim2.fromOffset(22, 4), UDim2.fromOffset(3, 1), Color3.fromRGB(245, 245, 250), 2)
	else
		local m = roundFrame(gui, "Mouth", UDim2.fromOffset(26, 10), UDim2.fromOffset(57, 96), Color3.fromRGB(175, 65, 75), 5)
		roundFrame(m, "Teeth", UDim2.fromOffset(20, 4), UDim2.fromOffset(3, 1), Color3.fromRGB(250, 250, 252), 2)
	end
end

--- Причёска из 2–3 деталей: выбирается по роли и детерминированному хэшу имени.
local function buildHair(parts: { PartEntry }, model: Model, role: string?, hash: number, factor: number, hairColor: Color3)
	if role == "eta" or role == "elena" or role == "goldgirl" then
		-- Длинные волосы для женских персонажей
		addPart(parts, model, "HairTop", Vector3.new(1.52, 0.4, 1.52) * factor, hairColor, Vector3.new(0, 2.32, 0.02) * factor)
		addPart(parts, model, "HairBack", Vector3.new(1.48, 1.85, 0.38) * factor, hairColor, Vector3.new(0, 1.35, 0.62) * factor)
		if role ~= "goldgirl" then
			addPart(parts, model, "HairBangs", Vector3.new(1.42, 0.28, 0.22) * factor, hairColor, Vector3.new(0, 2.26, -0.66) * factor)
		end
		return
	end

	-- Роли с крупными головными уборами или особым лимитом деталей используют аккуратную причёску из 2 частей
	local compact = role == "casino" or role == "razor" or role == "ging" or role == "catdiner" or role == "host" or role == "goldguard" or role == "bandit"
	local style = (hash % 4) + 1
	if role == "ging" or role == "razor" then
		style = 3 -- ёжик
	end

	if style == 1 then
		-- Короткая стрижка с чёлкой
		addPart(parts, model, "HairTop", Vector3.new(1.5, 0.4, 1.5) * factor, hairColor, Vector3.new(0, 2.32, 0.03) * factor)
		addPart(parts, model, "HairBack", Vector3.new(1.46, 0.9, 0.34) * factor, hairColor, Vector3.new(0, 1.82, 0.62) * factor)
		if not compact then
			addPart(parts, model, "HairBangs", Vector3.new(1.4, 0.28, 0.22) * factor, hairColor, Vector3.new(0, 2.24, -0.66) * factor)
		end
	elseif style == 2 then
		-- Длинная с хвостом сзади
		addPart(parts, model, "HairTop", Vector3.new(1.5, 0.4, 1.5) * factor, hairColor, Vector3.new(0, 2.32, 0.03) * factor)
		addPart(parts, model, "HairPonytail", Vector3.new(0.52, 1.3, 0.42) * factor, hairColor, Vector3.new(0, 1.32, 0.86) * factor, Vector3.new(-0.25, 0, 0))
		if not compact then
			addPart(parts, model, "HairBack", Vector3.new(1.44, 0.95, 0.32) * factor, hairColor, Vector3.new(0, 1.8, 0.6) * factor)
		end
	elseif style == 3 then
		-- Аниме-ёжик
		addPart(parts, model, "HairBase", Vector3.new(1.48, 0.36, 1.48) * factor, hairColor, Vector3.new(0, 2.3, 0.02) * factor)
		addPart(parts, model, "HairSpike1", Vector3.new(0.92, 0.62, 0.92) * factor, hairColor, Vector3.new(0, 2.56, 0.08) * factor, Vector3.new(-0.35, 0.78, 0.25))
		if not compact then
			addPart(parts, model, "HairSpike2", Vector3.new(0.82, 0.52, 0.82) * factor, hairColor, Vector3.new(0, 2.48, -0.18) * factor, Vector3.new(0.3, 0.4, -0.35))
		end
	else
		-- Лысый с бородой и усами
		addPart(parts, model, "BeardChin", Vector3.new(1.16, 0.5, 0.4) * factor, hairColor, Vector3.new(0, 1.08, -0.58) * factor)
		addPart(parts, model, "Mustache", Vector3.new(0.9, 0.2, 0.22) * factor, hairColor, Vector3.new(0, 1.35, -0.68) * factor)
		if not compact then
			addPart(parts, model, "BeardSide", Vector3.new(1.44, 0.44, 0.86) * factor, hairColor, Vector3.new(0, 1.22, -0.26) * factor)
		end
	end
end

--- Аксессуары и отличительные детали по роли NPC.
local function accessories(parts: { PartEntry }, model: Model, role: string?, factor: number, shirt: Color3)
	if role == "casino" then
		-- Король казино: высокий цилиндр с красной лентой и бархатный плащ
		local black = Color3.fromRGB(24, 22, 30)
		local red = Color3.fromRGB(215, 35, 55)
		local cylRot = Vector3.new(0, 0, math.pi / 2)
		addPart(parts, model, "HatBrim", Vector3.new(0.14, 2.0, 2.0) * factor, black, Vector3.new(0, 2.42, 0) * factor, cylRot, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(parts, model, "HatCrown", Vector3.new(1.05, 1.36, 1.36) * factor, black, Vector3.new(0, 2.98, 0) * factor, cylRot, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(parts, model, "HatBand", Vector3.new(0.22, 1.42, 1.42) * factor, red, Vector3.new(0, 2.58, 0) * factor, cylRot, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(parts, model, "Cape", Vector3.new(2.16, 2.65, 0.18) * factor, Color3.fromRGB(135, 18, 35), Vector3.new(0, -0.35, 0.58) * factor, Vector3.new(0.08, 0, 0), Enum.Material.Fabric)
	elseif role == "portmaster" then
		-- Начальник порта: капитанская фуражка с козырьком
		local cylRot = Vector3.new(0, 0, math.pi / 2)
		addPart(parts, model, "CapTop", Vector3.new(0.34, 1.7, 1.7) * factor, Color3.fromRGB(240, 242, 248), Vector3.new(0, 2.54, 0) * factor, cylRot, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		addPart(parts, model, "CapBand", Vector3.new(1.44, 0.24, 1.46) * factor, Color3.fromRGB(30, 45, 78), Vector3.new(0, 2.36, 0) * factor)
		addPart(parts, model, "CapVisor", Vector3.new(1.26, 0.1, 0.55) * factor, Color3.fromRGB(20, 22, 28), Vector3.new(0, 2.26, -0.78) * factor, Vector3.new(0.15, 0, 0))
	elseif role == "razor" then
		-- Рейзор: чёрная бандана-повязка и лёгкие наплечники
		local dark = Color3.fromRGB(24, 24, 30)
		local armor = Color3.fromRGB(75, 80, 95)
		addPart(parts, model, "Headband", Vector3.new(1.48, 0.28, 1.48) * factor, dark, Vector3.new(0, 2.16, 0) * factor, nil, Enum.Material.Fabric)
		addPart(parts, model, "ShoulderL", Vector3.new(1.24, 0.34, 1.2) * factor, armor, Vector3.new(-1.55, 0.92, 0) * factor, Vector3.new(0, 0, 0.18), Enum.Material.Metal)
		addPart(parts, model, "ShoulderR", Vector3.new(1.24, 0.34, 1.2) * factor, armor, Vector3.new(1.55, 0.92, 0) * factor, Vector3.new(0, 0, -0.18), Enum.Material.Metal)
	elseif role == "eta" or role == "elena" then
		-- Эта и Елена: две аккуратные заколки-бантика по бокам причёски
		local bowColor = role == "eta" and Color3.fromRGB(255, 215, 110) or Color3.fromRGB(245, 248, 255)
		addPart(parts, model, "ClipL", Vector3.new(0.42, 0.26, 0.24) * factor, bowColor, Vector3.new(-0.56, 2.34, -0.44) * factor, Vector3.new(0, 0, 0.32))
		addPart(parts, model, "ClipR", Vector3.new(0.42, 0.26, 0.24) * factor, bowColor, Vector3.new(0.56, 2.34, -0.44) * factor, Vector3.new(0, 0, -0.32))
	elseif role == "goldgirl" then
		-- Девушка из золотой пыли: бант и золотистые неоновые искры вокруг
		local gold = Color3.fromRGB(255, 220, 80)
		addPart(parts, model, "HairBow", Vector3.new(0.76, 0.3, 0.26) * factor, Color3.fromRGB(245, 110, 145), Vector3.new(0, 2.42, 0.56) * factor)
		addPart(parts, model, "Spark1", Vector3.new(0.28, 0.28, 0.28) * factor, gold, Vector3.new(-1.35, 1.85, -0.42) * factor, nil, Enum.Material.Neon, Enum.PartType.Ball)
		addPart(parts, model, "Spark2", Vector3.new(0.24, 0.24, 0.24) * factor, gold, Vector3.new(1.38, 1.1, 0.35) * factor, nil, Enum.Material.Neon, Enum.PartType.Ball)
		addPart(parts, model, "Spark3", Vector3.new(0.26, 0.26, 0.26) * factor, gold, Vector3.new(0.92, 2.48, -0.5) * factor, nil, Enum.Material.Neon, Enum.PartType.Ball)
	elseif role == "finalquiz" then
		-- Дван: золотая корона-обруч с самоцветом и длинный плащ
		addPart(parts, model, "CrownRing", Vector3.new(1.54, 0.26, 1.54) * factor, Color3.fromRGB(245, 205, 70), Vector3.new(0, 2.38, 0) * factor, nil, Enum.Material.Metal)
		addPart(parts, model, "CrownGem", Vector3.new(0.28, 0.38, 0.16) * factor, Color3.fromRGB(80, 210, 255), Vector3.new(0, 2.44, -0.76) * factor, nil, Enum.Material.Neon)
		addPart(parts, model, "Cape", Vector3.new(2.2, 2.7, 0.18) * factor, Color3.fromRGB(165, 35, 50), Vector3.new(0, -0.38, 0.58) * factor, Vector3.new(0.08, 0, 0), Enum.Material.Fabric)
	elseif role == "ging" then
		-- Гинг: зелёный капюшон куртки и походная/рыболовная кепка
		local green = Color3.fromRGB(48, 108, 64)
		local cap = Color3.fromRGB(215, 205, 175)
		addPart(parts, model, "Hood", Vector3.new(1.86, 0.62, 0.82) * factor, green, Vector3.new(0, 0.88, 0.36) * factor, nil, Enum.Material.Fabric)
		addPart(parts, model, "CapCrown", Vector3.new(1.52, 0.4, 1.52) * factor, cap, Vector3.new(0, 2.4, 0) * factor, nil, Enum.Material.Fabric)
		addPart(parts, model, "CapBrim", Vector3.new(1.36, 0.12, 0.64) * factor, cap, Vector3.new(0, 2.24, -0.78) * factor, Vector3.new(0.1, 0, 0), Enum.Material.Fabric)
	elseif role == "catdiner" then
		-- Кот из закусочной: кошачьи ушки, хвост и белый фартук
		local fur = shirt:Lerp(Color3.fromRGB(210, 140, 60), 0.4)
		addPart(parts, model, "CatEarL", Vector3.new(0.38, 0.52, 0.28) * factor, fur, Vector3.new(-0.48, 2.58, 0) * factor, Vector3.new(0, 0, 0.24))
		addPart(parts, model, "CatEarR", Vector3.new(0.38, 0.52, 0.28) * factor, fur, Vector3.new(0.48, 2.58, 0) * factor, Vector3.new(0, 0, -0.24))
		addPart(parts, model, "CatTail", Vector3.new(0.24, 1.55, 0.24) * factor, fur, Vector3.new(0, -0.55, 0.92) * factor, Vector3.new(-0.65, 0, 0.2))
		addPart(parts, model, "Apron", Vector3.new(1.65, 1.85, 0.12) * factor, Color3.fromRGB(245, 245, 250), Vector3.new(0, -0.35, -0.52) * factor, nil, Enum.Material.Fabric)
	elseif role == "host" then
		-- Распорядитель конкурса: шляпа с пером и микрофон в правой руке
		local hatColor = Color3.fromRGB(85, 45, 25)
		addPart(parts, model, "HatBrim", Vector3.new(1.86, 0.14, 1.86) * factor, hatColor, Vector3.new(0, 2.36, 0) * factor)
		addPart(parts, model, "HatCrown", Vector3.new(1.36, 0.56, 1.36) * factor, hatColor, Vector3.new(0, 2.66, 0) * factor)
		addPart(parts, model, "HatFeather", Vector3.new(0.16, 0.85, 0.32) * factor, Color3.fromRGB(250, 75, 90), Vector3.new(0.68, 2.84, 0.08) * factor, Vector3.new(-0.2, 0, -0.35))
		addPart(parts, model, "RightArm_Mic", Vector3.new(0.26, 0.78, 0.26) * factor, Color3.fromRGB(45, 48, 58), Vector3.new(1.5, -0.82, -0.62) * factor, Vector3.new(0.95, 0, 0), Enum.Material.Metal)
	elseif role == "goldguard" or role == "bandit" then
		-- Страж и бандит: шлем, нагрудник и меч за спиной
		local steel = Color3.fromRGB(165, 172, 188)
		local chest = role == "goldguard" and Color3.fromRGB(195, 180, 130) or Color3.fromRGB(95, 98, 112)
		addPart(parts, model, "Helmet", Vector3.new(1.54, 0.62, 1.54) * factor, steel, Vector3.new(0, 2.28, 0.04) * factor, nil, Enum.Material.Metal)
		addPart(parts, model, "Breastplate", Vector3.new(2.12, 1.55, 1.14) * factor, chest, Vector3.new(0, 0.15, 0) * factor, nil, Enum.Material.Metal)
		addPart(parts, model, "SwordBlade", Vector3.new(0.28, 2.7, 0.1) * factor, Color3.fromRGB(215, 222, 235), Vector3.new(0.1, 0.25, 0.64) * factor, Vector3.new(0, 0, 0.62), Enum.Material.Metal)
		addPart(parts, model, "SwordGuard", Vector3.new(0.92, 0.18, 0.22) * factor, Color3.fromRGB(220, 180, 70), Vector3.new(-0.48, 0.98, 0.66) * factor, Vector3.new(0, 0, 0.62), Enum.Material.Metal)
	elseif role == "shop" then
		-- Торговцы: фартук и берет торговца с брошью
		local hatColor = shirt:Lerp(Color3.fromRGB(50, 35, 25), 0.35)
		addPart(parts, model, "Apron", Vector3.new(1.68, 1.85, 0.12) * factor, Color3.fromRGB(242, 236, 220), Vector3.new(0, -0.35, -0.52) * factor, nil, Enum.Material.Fabric)
		addPart(parts, model, "MerchantHat", Vector3.new(1.62, 0.38, 1.62) * factor, hatColor, Vector3.new(0, 2.42, 0.04) * factor, Vector3.new(0.06, 0, 0.08), Enum.Material.Fabric)
		addPart(parts, model, "HatBrooch", Vector3.new(0.28, 0.28, 0.14) * factor, Color3.fromRGB(245, 205, 75), Vector3.new(0, 2.38, -0.74) * factor, nil, Enum.Material.Metal)
	elseif role == "villager" then
		-- Больные жители: повязка с компрессом на лбу
		addPart(parts, model, "Bandage", Vector3.new(1.48, 0.3, 1.48) * factor, Color3.fromRGB(242, 242, 236), Vector3.new(0, 2.15, 0) * factor, nil, Enum.Material.Fabric)
		addPart(parts, model, "Compress", Vector3.new(0.65, 0.34, 0.1) * factor, Color3.fromRGB(210, 232, 245), Vector3.new(0, 2.15, -0.73) * factor, nil, Enum.Material.Fabric)
	end
end

--- Модель стоит на земле (y пола — floorY), лицом к -Z (или повёрнута CFrame-ом позже).
function RigBuilder.build(displayName: string, shirt: Color3, skin: Color3?, scale: number?, role: string?): Model
	local factor = scale or 1
	local hash = nameHash(displayName)

	local skinColor = skin or Color3.fromRGB(240, 200, 160)
	if role == "villager" and not skin then
		-- Больные жители отличаются бледным зеленоватым оттенком кожи
		skinColor = Color3.fromRGB(204, 218, 182)
	elseif role == "catdiner" and not skin then
		skinColor = Color3.fromRGB(248, 215, 145)
	end

	local hairColor = HAIR_PALETTE[hash % #HAIR_PALETTE + 1]
	if role == "eta" then
		hairColor = Color3.fromRGB(215, 140, 210)
	elseif role == "elena" then
		hairColor = Color3.fromRGB(145, 190, 240)
	elseif role == "goldgirl" then
		hairColor = Color3.fromRGB(245, 205, 75)
	elseif role == "ging" or role == "razor" then
		hairColor = Color3.fromRGB(28, 30, 38)
	elseif role == "catdiner" then
		hairColor = Color3.fromRGB(220, 150, 70)
	end

	-- Брюки/ноги, ботинки, воротник, ремень и манжеты/перчатки
	local legColor = shirt:Lerp(Color3.fromRGB(38, 42, 58), 0.72)
	local shoeColor = legColor:Lerp(Color3.fromRGB(16, 16, 22), 0.65)
	local collarColor = shirt:Lerp(Color3.fromRGB(245, 245, 250), 0.45)
	local cuffColor = shirt:Lerp(Color3.fromRGB(240, 235, 220), 0.5)
	local beltColor = Color3.fromRGB(58, 40, 28)
	local buckleColor = Color3.fromRGB(235, 195, 70)

	local handColor = skinColor
	if role == "casino" or role == "portmaster" or role == "host" then
		handColor = Color3.fromRGB(242, 242, 248) -- белые перчатки
	elseif role == "goldguard" or role == "bandit" or role == "razor" then
		handColor = Color3.fromRGB(55, 55, 65) -- боевые перчатки
	end

	local model = Instance.new("Model")
	model.Name = displayName

	local rootPart = block("HumanoidRootPart", Vector3.new(2, 2, 1) * factor, shirt, model)
	rootPart.Transparency = 1
	rootPart.CanCollide = false
	rootPart:SetAttribute("OffsetX", 0)
	rootPart:SetAttribute("OffsetY", 0)
	rootPart:SetAttribute("OffsetZ", 0)
	model.PrimaryPart = rootPart

	-- Основные части тела: габариты по высоте сохранены (ноги -2, торс 0, голова +1.7)
	local parts: { PartEntry } = {}
	addPart(parts, model, "Torso", Vector3.new(2, 2, 1) * factor, shirt, Vector3.new(0, 0, 0))
	local head = addPart(parts, model, "Head", Vector3.new(1.4, 1.4, 1.4) * factor, skinColor, Vector3.new(0, 1.7, 0) * factor)
	addPart(parts, model, "LeftArm", Vector3.new(1, 2, 1) * factor, handColor, Vector3.new(-1.5, 0, 0) * factor)
	addPart(parts, model, "RightArm", Vector3.new(1, 2, 1) * factor, handColor, Vector3.new(1.5, 0, 0) * factor)
	addPart(parts, model, "LeftLeg", Vector3.new(1, 2, 1) * factor, legColor, Vector3.new(-0.5, -2, 0) * factor)
	addPart(parts, model, "RightLeg", Vector3.new(1, 2, 1) * factor, legColor, Vector3.new(0.5, -2, 0) * factor)

	-- Одежда: воротник, пояс с пряжкой, рукава верхней половины рук, манжеты и ботинки
	addPart(parts, model, "Collar", Vector3.new(1.48, 0.24, 1.06) * factor, collarColor, Vector3.new(0, 0.92, 0) * factor)
	addPart(parts, model, "Belt", Vector3.new(2.06, 0.28, 1.06) * factor, beltColor, Vector3.new(0, -0.82, 0) * factor)
	addPart(parts, model, "Buckle", Vector3.new(0.42, 0.34, 0.1) * factor, buckleColor, Vector3.new(0, -0.82, -0.52) * factor, nil, Enum.Material.Metal)
	addPart(parts, model, "LeftArm_Sleeve", Vector3.new(1.08, 1.04, 1.08) * factor, shirt, Vector3.new(-1.5, 0.48, 0) * factor)
	addPart(parts, model, "RightArm_Sleeve", Vector3.new(1.08, 1.04, 1.08) * factor, shirt, Vector3.new(1.5, 0.48, 0) * factor)
	addPart(parts, model, "LeftArm_Cuff", Vector3.new(1.1, 0.22, 1.1) * factor, cuffColor, Vector3.new(-1.5, -0.06, 0) * factor)
	addPart(parts, model, "RightArm_Cuff", Vector3.new(1.1, 0.22, 1.1) * factor, cuffColor, Vector3.new(1.5, -0.06, 0) * factor)
	addPart(parts, model, "LeftLeg_Shoe", Vector3.new(1.08, 0.36, 1.24) * factor, shoeColor, Vector3.new(-0.5, -2.82, -0.08) * factor)
	addPart(parts, model, "RightLeg_Shoe", Vector3.new(1.08, 0.36, 1.24) * factor, shoeColor, Vector3.new(0.5, -2.82, -0.08) * factor)
	addPart(parts, model, "LeftLeg_Sole", Vector3.new(1.12, 0.12, 1.3) * factor, shoeColor:Lerp(Color3.fromRGB(12, 12, 16), 0.45), Vector3.new(-0.5, -2.94, -0.08) * factor)
	addPart(parts, model, "RightLeg_Sole", Vector3.new(1.12, 0.12, 1.3) * factor, shoeColor:Lerp(Color3.fromRGB(12, 12, 16), 0.45), Vector3.new(0.5, -2.94, -0.08) * factor)

	-- Шея, уши, нос и подбородок: убирают эффект «голова на палке» и блочного лица.
	addPart(parts, model, "Neck", Vector3.new(0.62, 0.34, 0.62) * factor, skinColor:Lerp(Color3.fromRGB(120, 75, 55), 0.16), Vector3.new(0, 1.06, 0) * factor)
	if role ~= "catdiner" then
		addPart(parts, model, "LeftEar", Vector3.new(0.28, 0.38, 0.22) * factor, skinColor, Vector3.new(-0.73, 1.72, 0.01) * factor, nil, nil, Enum.PartType.Ball)
		addPart(parts, model, "RightEar", Vector3.new(0.28, 0.38, 0.22) * factor, skinColor, Vector3.new(0.73, 1.72, 0.01) * factor, nil, nil, Enum.PartType.Ball)
	end
	addPart(parts, model, "Nose", Vector3.new(0.2, 0.26, 0.2) * factor, skinColor:Lerp(Color3.fromRGB(120, 65, 50), 0.28), Vector3.new(0, 1.62, -0.74) * factor)
	addPart(parts, model, "Chin", Vector3.new(0.68, 0.2, 0.2) * factor, skinColor:Lerp(Color3.fromRGB(190, 135, 110), 0.12), Vector3.new(0, 1.12, -0.66) * factor)

	-- Округлые суставы и кисти: руки/ноги перестают быть набором одинаковых брусков.
	addPart(parts, model, "LeftArm_Shoulder", Vector3.new(1.12, 1.12, 1.12) * factor, shirt, Vector3.new(-1.45, 0.9, 0) * factor, nil, nil, Enum.PartType.Ball)
	addPart(parts, model, "RightArm_Shoulder", Vector3.new(1.12, 1.12, 1.12) * factor, shirt, Vector3.new(1.45, 0.9, 0) * factor, nil, nil, Enum.PartType.Ball)
	addPart(parts, model, "LeftArm_Elbow", Vector3.new(0.94, 0.94, 0.94) * factor, handColor:Lerp(cuffColor, 0.18), Vector3.new(-1.5, -0.35, 0) * factor, nil, nil, Enum.PartType.Ball)
	addPart(parts, model, "RightArm_Elbow", Vector3.new(0.94, 0.94, 0.94) * factor, handColor:Lerp(cuffColor, 0.18), Vector3.new(1.5, -0.35, 0) * factor, nil, nil, Enum.PartType.Ball)
	addPart(parts, model, "LeftArm_Hand", Vector3.new(0.92, 0.92, 0.92) * factor, handColor, Vector3.new(-1.5, -0.95, 0) * factor, nil, nil, Enum.PartType.Ball)
	addPart(parts, model, "RightArm_Hand", Vector3.new(0.92, 0.92, 0.92) * factor, handColor, Vector3.new(1.5, -0.95, 0) * factor, nil, nil, Enum.PartType.Ball)
	addPart(parts, model, "LeftLeg_Knee", Vector3.new(0.95, 0.95, 0.95) * factor, legColor:Lerp(Color3.fromRGB(30, 30, 40), 0.12), Vector3.new(-0.5, -2.1, 0) * factor, nil, nil, Enum.PartType.Ball)
	addPart(parts, model, "RightLeg_Knee", Vector3.new(0.95, 0.95, 0.95) * factor, legColor:Lerp(Color3.fromRGB(30, 30, 40), 0.12), Vector3.new(0.5, -2.1, 0) * factor, nil, nil, Enum.PartType.Ball)

	-- Мелкие детали одежды: карман, пуговицы и шлёвки ремня.
	addPart(parts, model, "ChestPocket", Vector3.new(0.55, 0.5, 0.08) * factor, shirt:Lerp(Color3.fromRGB(0, 0, 0), 0.18), Vector3.new(-0.45, 0.18, -0.52) * factor)
	for index = 1, 3 do
		addPart(parts, model, "ShirtButton", Vector3.new(0.11, 0.11, 0.08) * factor, collarColor, Vector3.new(0, 0.55 - (index - 1) * 0.28, -0.54) * factor, nil, nil, Enum.PartType.Ball)
		addPart(parts, model, "BeltLoop", Vector3.new(0.12, 0.4, 0.1) * factor, beltColor:Lerp(Color3.fromRGB(0, 0, 0), 0.22), Vector3.new(-0.7 + (index - 1) * 0.7, -0.82, -0.54) * factor)
	end

	buildHair(parts, model, role, hash, factor, hairColor)
	accessories(parts, model, role, factor, shirt)
	buildFace(head, role, hash, hairColor, skinColor)

	model:SetAttribute("RigOffsets", "")
	for _, entry in parts do
		entry.part:SetAttribute("OffsetX", entry.offset.X)
		entry.part:SetAttribute("OffsetY", entry.offset.Y)
		entry.part:SetAttribute("OffsetZ", entry.offset.Z)
		if entry.offset.Y >= 1.0 * factor and not string.find(entry.part.Name, "Spark") then
			entry.part:SetAttribute("HeadPart", true)
		end
		if entry.rot then
			entry.part:SetAttribute("RotX", entry.rot.X)
			entry.part:SetAttribute("RotY", entry.rot.Y)
			entry.part:SetAttribute("RotZ", entry.rot.Z)
		end
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayName = displayName
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.NameDisplayDistance = 40
	humanoid.Parent = model

	return model
end

--- Поставить модель так, чтобы подошвы стояли на groundY, лицом в точку lookAt.
--- swing — размах рук и ног в радианах (ходьба); breathe — вертикальное дыхание корпуса.
--- headYaw/headPitch — поворот головы относительно тела (радианы), чтобы NPC смотрел на игрока.
function RigBuilder.place(
	model: Model,
	position: Vector3,
	groundY: number,
	lookAt: Vector3?,
	scale: number?,
	swing: number?,
	breathe: number?,
	headYaw: number?,
	headPitch: number?
)
	local factor = scale or 1
	local yaw = headYaw or 0
	local pitch = headPitch or 0
	local center = Vector3.new(position.X, groundY + 3 * factor, position.Z)
	local facing = lookAt and Vector3.new(lookAt.X, center.Y, lookAt.Z) or (center + Vector3.new(0, 0, -1))
	if (facing - center).Magnitude < 0.05 then
		facing = center + Vector3.new(0, 0, -1) -- смотреть некуда: вырожденный CFrame.lookAt дал бы NaN
	end
	local base = CFrame.lookAt(center, facing)
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			local offset = Vector3.new(
				part:GetAttribute("OffsetX") or 0,
				part:GetAttribute("OffsetY") or 0,
				part:GetAttribute("OffsetZ") or 0
			)
			if breathe and breathe ~= 0 and part.Name ~= "HumanoidRootPart"
				and not string.find(part.Name, "Leg")
				and not string.find(part.Name, "Shoe")
				and not string.find(part.Name, "Sole")
			then
				offset += Vector3.new(0, breathe * factor, 0)
			end
			local rx = part:GetAttribute("RotX") or 0
			local ry = part:GetAttribute("RotY") or 0
			local rz = part:GetAttribute("RotZ") or 0
			local hasRot = rx ~= 0 or ry ~= 0 or rz ~= 0
			local sign = LIMB_SIGN[part.Name]
			if sign and swing and swing ~= 0 then
				-- качаем вокруг плеча (+factor) или бедра (-factor): рукава, манжеты и ботинки двигаются слитно с конечностью
				local jointY = (LIMB_JOINT_Y[part.Name] or 1) * factor
				local pivot = Vector3.new(0, jointY - offset.Y, -offset.Z)
				local cframe = base * CFrame.new(offset + pivot) * CFrame.Angles(swing * sign, 0, 0) * CFrame.new(-pivot)
				part.CFrame = hasRot and (cframe * CFrame.Angles(rx, ry, rz)) or cframe
			elseif (yaw ~= 0 or pitch ~= 0) and part:GetAttribute("HeadPart") then
				-- голова, волосы, шляпы и уши поворачиваются вокруг шеи, а не вокруг центра головы
				local pivot = Vector3.new(0, 1.06 * factor - offset.Y, -offset.Z)
				local cframe = base * CFrame.new(offset + pivot) * CFrame.Angles(pitch, yaw, 0) * CFrame.new(-pivot)
				part.CFrame = hasRot and (cframe * CFrame.Angles(rx, ry, rz)) or cframe
			elseif hasRot then
				part.CFrame = base * CFrame.new(offset) * CFrame.Angles(rx, ry, rz)
			else
				part.CFrame = base * CFrame.new(offset)
			end
		end
	end
end

-- ===================== R15-АВАТАР =====================
-- Настоящий скелет Roblox R15 (Players:CreateHumanoidModelFromDescription) со штатными анимациями
-- ожидания и ходьбы. Причёски, головные уборы и аксессуары ролей — те же детали, что у модели выше,
-- приваренные к голове/торсу/руке. Если что-то не получилось, NpcService оставляет модель из деталей.

local Players = game:GetService("Players")

-- Стандартные анимации R15 из скрипта Animate (принадлежат Roblox, работают в любом месте)
local IDLE_ANIM = "rbxassetid://507766666"
local WALK_ANIM = "rbxassetid://507777826"

type AvatarState = {
	root: BasePart,
	humanoid: Humanoid,
	neck: Motor6D?,
	neckC0: CFrame?,
	idle: AnimationTrack?,
	walk: AnimationTrack?,
	walking: boolean,
}

local avatars: { [Model]: AvatarState } = setmetatable({}, { __mode = "k" }) :: any

local FEMININE = { eta = true, elena = true, goldgirl = true }

local function weldTo(part: BasePart, target: BasePart, cframe: CFrame)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CFrame = cframe
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = target
	weld.Part1 = part
	weld.Parent = part
end

local function paint(model: Model, name: string, color: Color3, material: Enum.Material?)
	local part = model:FindFirstChild(name)
	if part and part:IsA("BasePart") then
		part.Color = color
		if material then
			part.Material = material
		end
	end
end

--- R15-модель NPC. Возвращает nil, если Roblox не смог собрать аватар (нет сети, сбой API).
function RigBuilder.buildAvatar(displayName: string, shirt: Color3, skin: Color3?, scale: number?, role: string?): Model?
	local factor = scale or 1
	local hash = nameHash(displayName)
	local ok, result = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		local feminine = role ~= nil and FEMININE[role] == true
		desc.HeightScale = factor * (feminine and 0.97 or 1.04)
		desc.WidthScale = factor * (feminine and 0.86 or 1)
		desc.DepthScale = factor * (feminine and 0.9 or 1)
		desc.HeadScale = factor
		desc.BodyTypeScale = feminine and 0.15 or 0.3
		desc.ProportionScale = 0
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not result then
		warn(`[RigBuilder] R15-аватар для «{displayName}» не собран: {result}`)
		return nil
	end
	local model = result :: Model
	model.Name = displayName

	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local head = model:FindFirstChild("Head") :: BasePart?
	local upper = model:FindFirstChild("UpperTorso") :: BasePart?
	local lower = model:FindFirstChild("LowerTorso") :: BasePart?
	local rightHand = model:FindFirstChild("RightHand") :: BasePart?
	if not (root and humanoid and head and upper and lower) then
		model:Destroy()
		return nil
	end

	-- Скрипт Animate на сервере не работает, анимациями управляем сами; цвета ставим вручную
	for _, child in model:GetChildren() do
		if child.Name == "Animate" or child:IsA("BodyColors") or child:IsA("Shirt") or child:IsA("Pants") then
			child:Destroy()
		end
	end
	model:PivotTo(CFrame.new())
	root.Anchored = true
	root.Transparency = 1
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			if descendant ~= root then
				descendant.Massless = true
			end
		end
	end

	-- Цвета: кожа, рубашка, брюки, обувь, перчатки
	local skinColor = skin or Color3.fromRGB(240, 200, 160)
	if role == "villager" and not skin then
		skinColor = Color3.fromRGB(204, 218, 182)
	elseif role == "catdiner" and not skin then
		skinColor = Color3.fromRGB(248, 215, 145)
	end
	local hairColor = HAIR_PALETTE[hash % #HAIR_PALETTE + 1]
	if role == "eta" then
		hairColor = Color3.fromRGB(215, 140, 210)
	elseif role == "elena" then
		hairColor = Color3.fromRGB(145, 190, 240)
	elseif role == "goldgirl" then
		hairColor = Color3.fromRGB(245, 205, 75)
	elseif role == "ging" or role == "razor" then
		hairColor = Color3.fromRGB(28, 30, 38)
	elseif role == "catdiner" then
		hairColor = Color3.fromRGB(220, 150, 70)
	end
	local legColor = shirt:Lerp(Color3.fromRGB(38, 42, 58), 0.72)
	local shoeColor = legColor:Lerp(Color3.fromRGB(16, 16, 22), 0.65)
	local collarColor = shirt:Lerp(Color3.fromRGB(245, 245, 250), 0.45)
	local handColor = skinColor
	if role == "casino" or role == "portmaster" or role == "host" then
		handColor = Color3.fromRGB(242, 242, 248)
	elseif role == "goldguard" or role == "bandit" or role == "razor" then
		handColor = Color3.fromRGB(55, 55, 65)
	end
	local sleeve = shirt
	local forearm = (role == "beach" or role == "catdiner") and skinColor or shirt:Lerp(Color3.fromRGB(0, 0, 0), 0.06)

	paint(model, "Head", skinColor)
	paint(model, "UpperTorso", shirt, Enum.Material.Fabric)
	paint(model, "LowerTorso", legColor, Enum.Material.Fabric)
	for _, side in { "Left", "Right" } do
		paint(model, side .. "UpperArm", sleeve, Enum.Material.Fabric)
		paint(model, side .. "LowerArm", forearm, forearm == skinColor and Enum.Material.SmoothPlastic or Enum.Material.Fabric)
		paint(model, side .. "Hand", handColor)
		paint(model, side .. "UpperLeg", legColor, Enum.Material.Fabric)
		paint(model, side .. "LowerLeg", legColor, Enum.Material.Fabric)
		paint(model, side .. "Foot", shoeColor)
	end

	-- Лицо: убираем штатную наклейку, рисуем выразительное аниме-лицо
	for _, child in head:GetChildren() do
		if child:IsA("Decal") then
			child:Destroy()
		end
	end
	buildFace(head :: any, role, hash, hairColor, skinColor)

	-- Детали одежды на торсе: воротник, пояс с пряжкой, пуговицы
	local top = upper.Position.Y + upper.Size.Y / 2
	local bottom = lower.Position.Y - lower.Size.Y / 2
	local torsoCenter = Vector3.new(0, (top + bottom) / 2, 0)
	local sx = upper.Size.X / 2
	local sy = (top - bottom) / 2
	local sz = upper.Size.Z
	local beltY = lower.Position.Y + lower.Size.Y * 0.3
	local function extra(name: string, size: Vector3, cframe: CFrame, color: Color3, target: BasePart, material: Enum.Material?)
		local p = block(name, size, color, model, material)
		weldTo(p, target, cframe)
	end
	extra("Collar", Vector3.new(upper.Size.X * 0.55, 0.16 * factor, upper.Size.Z * 1.06), CFrame.new(0, top - 0.06 * factor, 0), collarColor, upper, Enum.Material.Fabric)
	extra("Belt", Vector3.new(lower.Size.X * 1.04, 0.2 * factor, lower.Size.Z * 1.08), CFrame.new(0, beltY, 0), Color3.fromRGB(58, 40, 28), lower, Enum.Material.Leather)
	extra("Buckle", Vector3.new(0.3, 0.22, 0.06) * factor, CFrame.new(0, beltY, -lower.Size.Z * 0.56), Color3.fromRGB(235, 195, 70), lower, Enum.Material.Metal)
	for index = 1, 3 do
		local button = block("ShirtButton", Vector3.new(0.09, 0.09, 0.06) * factor, collarColor, model, nil, Enum.PartType.Ball)
		weldTo(button, upper, CFrame.new(0, top - 0.35 * factor - (index - 1) * 0.28 * factor, -upper.Size.Z * 0.52))
	end

	-- Причёска и аксессуары роли: собираем в масштабе 1 и переносим на кости R15
	local temp = Instance.new("Model")
	local entries: { PartEntry } = {}
	buildHair(entries, temp, role, hash, 1, hairColor)
	accessories(entries, temp, role, 1, shirt)
	local headScale = head.Size.Y / 1.4 -- старая голова 1.4 студа, новая — по размеру R15-головы
	for _, entry in entries do
		local p = entry.part
		local rot = entry.rot and CFrame.Angles(entry.rot.X, entry.rot.Y, entry.rot.Z) or CFrame.identity
		local offset = entry.offset
		if p.Name == "RightArm_Mic" and rightHand then
			p.Size *= factor
			weldTo(p, rightHand, rightHand.CFrame * CFrame.new(0, -0.15 * factor, -0.25 * factor) * CFrame.Angles(math.rad(80), 0, 0))
		elseif offset.Y >= 1.0 and not string.find(p.Name, "Spark") then
			p.Size *= headScale
			local local3 = (offset - Vector3.new(0, 1.7, 0)) * headScale
			weldTo(p, head, head.CFrame * CFrame.new(local3) * rot)
		else
			p.Size *= sy
			local local3 = Vector3.new(offset.X * sx, offset.Y * sy, offset.Z * sz)
			weldTo(p, upper, CFrame.new(torsoCenter + local3) * rot)
		end
		p.Parent = model
	end
	temp:Destroy()

	humanoid.DisplayName = displayName
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.NameDisplayDistance = 40
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	pcall(function()
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	end)
	model.PrimaryPart = root
	model:SetAttribute("Avatar", true)

	local neck = head:FindFirstChild("Neck")
	avatars[model] = {
		root = root,
		humanoid = humanoid,
		neck = if neck and neck:IsA("Motor6D") then neck else nil,
		neckC0 = if neck and neck:IsA("Motor6D") then neck.C0 else nil,
		idle = nil,
		walk = nil,
		walking = false,
	}
	return model
end

--- Запустить анимации. Вызывать, когда модель уже в workspace (иначе Animator не грузит треки).
function RigBuilder.startAvatar(model: Model)
	local state = avatars[model]
	if not state then
		return
	end
	pcall(function()
		local animator = state.humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
		animator.Parent = state.humanoid
		local idle = Instance.new("Animation")
		idle.AnimationId = IDLE_ANIM
		local walk = Instance.new("Animation")
		walk.AnimationId = WALK_ANIM
		state.idle = animator:LoadAnimation(idle)
		state.walk = animator:LoadAnimation(walk)
		if state.idle then
			state.idle.Looped = true
			state.idle.Priority = Enum.AnimationPriority.Idle
			state.idle:Play(0.3, 1, 0.9 + (nameHash(model.Name) % 20) / 100)
		end
		if state.walk then
			state.walk.Looped = true
			state.walk.Priority = Enum.AnimationPriority.Movement
		end
	end)
end

--- Поставить R15-аватар ногами на groundY лицом к lookAt; moving включает анимацию ходьбы.
--- headYaw/headPitch — поворот головы через сустав шеи (взгляд на игрока).
function RigBuilder.poseAvatar(model: Model, position: Vector3, groundY: number, lookAt: Vector3?, moving: boolean, walkSpeed: number, headYaw: number?, headPitch: number?)
	local state = avatars[model]
	if not state then
		return
	end
	local root = state.root
	local center = Vector3.new(position.X, groundY + state.humanoid.HipHeight + root.Size.Y / 2, position.Z)
	local facing = lookAt and Vector3.new(lookAt.X, center.Y, lookAt.Z) or (center + Vector3.new(0, 0, -1))
	if (facing - center).Magnitude < 0.05 then
		facing = center + Vector3.new(0, 0, -1)
	end
	root.CFrame = CFrame.lookAt(center, facing)

	if moving ~= state.walking then
		state.walking = moving
		if state.walk then
			if moving then
				state.walk:Play(0.25)
				state.walk:AdjustSpeed(math.clamp(walkSpeed / 7, 0.4, 1.5))
			else
				state.walk:Stop(0.35)
			end
		end
	end

	if state.neck and state.neckC0 then
		state.neck.C0 = state.neckC0 * CFrame.Angles(headPitch or 0, headYaw or 0, 0)
	end
end

return RigBuilder
