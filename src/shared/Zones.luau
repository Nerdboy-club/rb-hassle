-- Карта острова: центр (x, z), радиус, тип. Ось +z — на юг; старт у Дерева Шисо.
-- kind: town — город (дома, площадь), wild — дикая местность, special — особое место.
export type Zone = {
	name: string,
	x: number,
	z: number,
	r: number,
	kind: string,
	ground: Enum.Material?,
	color: Color3,
}

local Zones: { [string]: Zone } = {
	Shiso = { name = "Дерево Шисо", x = 0, z = 560, r = 70, kind = "special", ground = Enum.Material.Grass, color = Color3.fromRGB(110, 190, 90) },
	Antokiba = { name = "Антокиба — город призов", x = -40, z = 300, r = 110, kind = "town", ground = Enum.Material.Grass, color = Color3.fromRGB(230, 190, 90) },
	Rubicuta = { name = "Рубикута", x = 230, z = 330, r = 90, kind = "town", ground = Enum.Material.Grass, color = Color3.fromRGB(220, 110, 110) },
	Masadora = { name = "Масадора — магический город", x = -430, z = 220, r = 130, kind = "town", ground = Enum.Material.Slate, color = Color3.fromRGB(150, 110, 230) },
	Aiai = { name = "Аиай — город любви", x = 420, z = 120, r = 100, kind = "town", ground = Enum.Material.Grass, color = Color3.fromRGB(250, 140, 180) },
	Soufrabi = { name = "Суфраби — порт пиратов", x = 640, z = 420, r = 120, kind = "town", ground = Enum.Material.Sand, color = Color3.fromRGB(90, 150, 210) },
	Dorias = { name = "Дориас — город азарта", x = -560, z = -150, r = 120, kind = "town", ground = Enum.Material.Cobblestone, color = Color3.fromRGB(230, 70, 90) },
	Limeiro = { name = "Лимейро — столица", x = 20, z = -620, r = 150, kind = "town", ground = Enum.Material.Cobblestone, color = Color3.fromRGB(235, 220, 160) },
	Port = { name = "Порт Острова Жадности", x = -640, z = 520, r = 90, kind = "town", ground = Enum.Material.Sand, color = Color3.fromRGB(110, 170, 200) },
	Bunzen = { name = "Бунзен", x = 700, z = -280, r = 100, kind = "town", ground = Enum.Material.LeafyGrass, color = Color3.fromRGB(100, 150, 80) },
	Bandits = { name = "Деревня горных бандитов", x = -330, z = -470, r = 90, kind = "town", ground = Enum.Material.Ground, color = Color3.fromRGB(150, 120, 90) },
	Barren = { name = "Бесплодные земли", x = 280, z = -330, r = 220, kind = "wild", ground = Enum.Material.Sandstone, color = Color3.fromRGB(200, 170, 120) },
	Forest = { name = "Лес", x = 600, z = -120, r = 170, kind = "wild", ground = Enum.Material.LeafyGrass, color = Color3.fromRGB(60, 140, 70) },
	Swamp = { name = "Топи", x = -200, z = -120, r = 130, kind = "wild", ground = Enum.Material.Mud, color = Color3.fromRGB(90, 110, 70) },
	Cave = { name = "Пещера", x = 60, z = -300, r = 70, kind = "wild", ground = Enum.Material.Rock, color = Color3.fromRGB(110, 110, 120) },
	Cliffs = { name = "Скалы", x = -300, z = 560, r = 140, kind = "wild", ground = Enum.Material.Rock, color = Color3.fromRGB(150, 140, 130) },
	Ruins = { name = "Руины", x = 160, z = -30, r = 110, kind = "wild", ground = Enum.Material.Slate, color = Color3.fromRGB(170, 170, 160) },
	Meadow = { name = "Луга", x = 120, z = 480, r = 150, kind = "wild", ground = Enum.Material.Grass, color = Color3.fromRGB(130, 200, 100) },
	-- побережье не имеет центра: точки берутся по кольцу у воды (см. Util.randomPointIn)
	Coast = { name = "Побережье", x = 0, z = 0, r = 870, kind = "wild", ground = Enum.Material.Sand, color = Color3.fromRGB(240, 220, 160) },
}

return Zones
