-- Образы героев для покупки в «Гардеробе»: чисто косметика, силу и урон не меняют.
-- Образ собирается кодом: цвета тела и одежды + приваренные к персонажу детали (причёска, аксессуары).
-- Размеры и смещения деталей головы заданы в долях размера головы (подходит и R15, и R6),
-- у остальных креплений (Torso, RightHand, Back) — в студах.
export type Piece = {
	on: string, -- "Head" | "Torso" | "RightHand" | "LeftHand" | "Back"
	shape: string, -- "Block" | "Ball" | "Cylinder"
	size: Vector3,
	offset: Vector3,
	rot: Vector3?, -- градусы
	color: Color3,
	material: Enum.Material?,
}

export type Skin = {
	id: string,
	name: string,
	price: number,
	desc: string,
	skin: Color3?, -- цвет кожи (голова и кисти)
	shirt: Color3, -- торс и руки
	pants: Color3, -- ноги
	pieces: { Piece },
}

local V = Vector3.new
local C = Color3.fromRGB

local function piece(on: string, shape: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material?, rot: Vector3?): Piece
	return { on = on, shape = shape, size = size, offset = offset, color = color, material = material, rot = rot }
end

--- Шапка волос и торчащие пряди по кругу (в долях размера головы).
local function hair(color: Color3, spikes: number, length: number, tilt: number, fringe: boolean?): { Piece }
	local list = {
		piece("Head", "Block", V(1.12, 0.32, 1.12), V(0, 0.5, 0), color, Enum.Material.SmoothPlastic),
		piece("Head", "Block", V(1.12, 0.7, 0.3), V(0, 0.2, 0.42), color, Enum.Material.SmoothPlastic),
	}
	if fringe then
		table.insert(list, piece("Head", "Block", V(1.1, 0.22, 0.2), V(0, 0.32, -0.46), color, Enum.Material.SmoothPlastic))
	end
	for index = 1, spikes do
		local angle = index / spikes * math.pi * 2
		local dx, dz = math.cos(angle), math.sin(angle)
		table.insert(list, piece(
			"Head",
			"Block",
			V(0.22, length, 0.22),
			V(dx * 0.34, 0.62 + length * 0.4, dz * 0.34),
			color,
			Enum.Material.SmoothPlastic,
			V(dz * tilt, 0, -dx * tilt)
		))
	end
	return list
end

local function join(...: { Piece }): { Piece }
	local out = {}
	for _, list in { ... } do
		for _, item in list do
			table.insert(out, item)
		end
	end
	return out
end

local Skins = {} :: { list: { Skin }, get: (string) -> Skin?, byId: { [string]: Skin } }

Skins.list = {
	{
		id = "gon",
		name = "Гон Фрикс",
		price = 6000,
		desc = "Зелёная куртка, торчащие чёрные волосы и удочка за спиной.",
		skin = C(240, 195, 150),
		shirt = C(60, 150, 70),
		pants = C(200, 180, 120),
		pieces = join(hair(C(25, 28, 30), 9, 0.55, 28), {
			piece("Back", "Cylinder", V(3.6, 0.18, 0.18), V(0.6, 0, 0.7), C(150, 105, 60), Enum.Material.Wood, V(0, 0, 80)),
			piece("Back", "Block", V(0.3, 0.5, 0.3), V(-0.9, -1.3, 0.7), C(60, 60, 70), Enum.Material.Metal),
			piece("Torso", "Block", V(2.1, 0.25, 1.1), V(0, -0.6, 0), C(110, 80, 50), Enum.Material.Leather),
		}),
	},
	{
		id = "killua",
		name = "Киллуа Золдик",
		price = 6000,
		desc = "Серебристые взъерошенные волосы и тёмная одежда ассасина.",
		skin = C(245, 215, 190),
		shirt = C(70, 80, 130),
		pants = C(45, 48, 60),
		pieces = join(hair(C(230, 235, 245), 11, 0.5, 40, true), {
			piece("Torso", "Block", V(2.1, 0.3, 1.1), V(0, -0.6, 0), C(40, 40, 50), Enum.Material.Leather),
			piece("RightHand", "Cylinder", V(0.15, 0.45, 0.45), V(0, -0.5, 0), C(200, 200, 215), Enum.Material.Metal),
		}),
	},
	{
		id = "kurapika",
		name = "Курапика",
		price = 9000,
		desc = "Синяя туника клана Курута, светлые волосы и цепь на руке.",
		skin = C(245, 215, 185),
		shirt = C(50, 80, 170),
		pants = C(235, 235, 240),
		pieces = join(hair(C(240, 215, 120), 0, 0.4, 0, true), {
			piece("Torso", "Block", V(2.15, 0.3, 1.15), V(0, -0.1, 0), C(240, 240, 245), Enum.Material.Fabric),
			piece("Torso", "Block", V(1.1, 1.5, 0.12), V(0, 0, -0.55), C(235, 235, 240), Enum.Material.Fabric),
			piece("RightHand", "Cylinder", V(0.25, 0.55, 0.55), V(0, 0.2, 0), C(190, 195, 210), Enum.Material.Metal, V(0, 0, 90)),
			piece("RightHand", "Block", V(0.12, 1.4, 0.12), V(0, -1.1, 0), C(190, 195, 210), Enum.Material.Metal),
			piece("RightHand", "Ball", V(0.35, 0.35, 0.35), V(0, -1.9, 0), C(120, 200, 255), Enum.Material.Neon),
		}),
	},
	{
		id = "leorio",
		name = "Леорио Парадинайт",
		price = 9000,
		desc = "Тёмный костюм, галстук, очки и чемоданчик.",
		skin = C(235, 190, 150),
		shirt = C(40, 42, 55),
		pants = C(35, 36, 48),
		pieces = join(hair(C(20, 20, 24), 0, 0.4, 0, true), {
			piece("Head", "Block", V(1.12, 0.2, 0.08), V(0, 0.05, -0.54), C(15, 15, 20), Enum.Material.SmoothPlastic),
			piece("Torso", "Block", V(0.3, 1.2, 0.1), V(0, 0.1, -0.55), C(190, 40, 50), Enum.Material.Fabric),
			piece("Torso", "Block", V(0.9, 0.3, 0.1), V(0, 0.8, -0.55), C(240, 240, 245), Enum.Material.Fabric),
			piece("RightHand", "Block", V(0.4, 1.0, 1.4), V(0, -1.1, 0), C(110, 70, 40), Enum.Material.Leather),
		}),
	},
	{
		id = "hisoka",
		name = "Хисока Морроу",
		price = 20000,
		desc = "Алые волосы, пиджак фокусника и колода карт в руке.",
		skin = C(240, 205, 180),
		shirt = C(230, 100, 160),
		pants = C(90, 40, 110),
		pieces = join(hair(C(235, 70, 80), 7, 0.9, 5, false), {
			piece("Head", "Block", V(0.12, 0.12, 0.05), V(-0.2, -0.05, -0.52), C(190, 40, 130), Enum.Material.Neon),
			piece("Head", "Block", V(0.1, 0.18, 0.05), V(0.2, -0.08, -0.52), C(90, 150, 255), Enum.Material.Neon),
			piece("Torso", "Block", V(2.15, 0.3, 1.1), V(0, 0.4, 0), C(250, 235, 120), Enum.Material.Fabric),
			piece("RightHand", "Block", V(0.7, 0.05, 1.0), V(0, -0.9, -0.2), C(245, 245, 250), Enum.Material.SmoothPlastic, V(0, 0, 12)),
			piece("RightHand", "Block", V(0.7, 0.05, 1.0), V(0.15, -0.9, -0.2), C(210, 40, 60), Enum.Material.SmoothPlastic, V(0, 0, -12)),
		}),
	},
	{
		id = "bisky",
		name = "Бисуке Кроуфорд",
		price = 20000,
		desc = "Розовое платье, светло-розовые косы с бантами.",
		skin = C(250, 220, 200),
		shirt = C(245, 140, 185),
		pants = C(245, 170, 205),
		pieces = join(hair(C(255, 215, 225), 0, 0.4, 0, true), {
			piece("Head", "Block", V(0.28, 1.5, 0.28), V(-0.62, -0.5, 0.2), C(255, 215, 225), Enum.Material.SmoothPlastic),
			piece("Head", "Block", V(0.28, 1.5, 0.28), V(0.62, -0.5, 0.2), C(255, 215, 225), Enum.Material.SmoothPlastic),
			piece("Head", "Block", V(0.4, 0.3, 0.3), V(-0.62, 0.3, 0.2), C(235, 60, 110), Enum.Material.Fabric),
			piece("Head", "Block", V(0.4, 0.3, 0.3), V(0.62, 0.3, 0.2), C(235, 60, 110), Enum.Material.Fabric),
			piece("Torso", "Block", V(2.3, 0.4, 1.2), V(0, -0.8, 0), C(235, 60, 110), Enum.Material.Fabric),
		}),
	},
}

Skins.byId = {}
for _, skin in Skins.list do
	Skins.byId[skin.id] = skin
end

function Skins.get(id: string): Skin?
	return Skins.byId[id]
end

return Skins
