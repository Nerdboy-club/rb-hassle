-- Монстры острова. Модель собирается из частей (parts) на сервере; ИИ — в server/MonsterService.luau.
-- behavior:
--   chase   — замечает игрока и гонится
--   flee    — убегает от игрока (пузырьковая лошадь, гипердождевик)
--   faint   — при приближении игрока падает в обморок (радиокрыса)
--   tree    — неподвижный жук-олень: падает после серии сильных ударов
-- weak: имя части, удар по которой даёт множитель урона (kill=true — мгновенная карта)
export type Part = {
	name: string,
	shape: string,
	size: Vector3,
	offset: Vector3,
	color: Color3,
	material: Enum.Material?,
}

export type Monster = {
	name: string,
	zone: string,
	count: number,
	hp: number,
	speed: number,
	damage: number,
	aggro: number,
	behavior: string,
	drop: string, -- ключ источника m:<drop> в Cards.luau
	parts: { Part },
	weak: { part: string, mult: number, kill: boolean? }?,
	respawn: number,
	pack: { count: number, member: string }?,
}

local function part(name: string, shape: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material?): Part
	return { name = name, shape = shape, size = size, offset = offset, color = color, material = material }
end

local V = Vector3.new
local C = Color3.fromRGB

local Monsters: { [string]: Monster } = {
	Cyclops = {
		name = "Циклоп",
		zone = "Barren",
		count = 2,
		hp = 160,
		speed = 11,
		damage = 22,
		aggro = 50,
		behavior = "chase",
		drop = "Cyclops",
		parts = {
			part("Body", "Block", V(8, 12, 5), V(0, 6, 0), C(120, 130, 190)),
			part("Head", "Ball", V(6, 6, 6), V(0, 14, 0), C(130, 140, 200)),
			part("Eye", "Ball", V(2.4, 2.4, 1.6), V(0, 14.4, -2.8), C(250, 230, 120), Enum.Material.Neon),
			part("ArmL", "Block", V(2.5, 9, 2.5), V(-5.5, 6, 0), C(120, 130, 190)),
			part("ArmR", "Block", V(2.5, 9, 2.5), V(5.5, 6, 0), C(120, 130, 190)),
		},
		weak = { part = "Eye", mult = 6, kill = true },
		respawn = 90,
	},
	BubbleHorse = {
		name = "Пузырьковая лошадь",
		zone = "Cliffs",
		count = 1,
		hp = 60,
		speed = 26,
		damage = 0,
		aggro = 70,
		behavior = "flee",
		drop = "BubbleHorse",
		parts = {
			part("Body", "Block", V(3, 3.4, 7), V(0, 3.4, 0), C(245, 245, 245)),
			part("Head", "Block", V(2, 2.4, 3), V(0, 5.4, -4.2), C(250, 250, 250)),
			part("Mane", "Block", V(0.6, 2.4, 3.5), V(0, 5.6, -1.8), C(230, 60, 80)),
			part("Bubble", "Ball", V(2.2, 2.2, 2.2), V(0, 7.4, 0), C(255, 120, 150), Enum.Material.Glass),
		},
		respawn = 120,
	},
	RadioRat = {
		name = "Радиокрыса",
		zone = "Ruins",
		count = 2,
		hp = 30,
		speed = 14,
		damage = 0,
		aggro = 28,
		behavior = "faint",
		drop = "RadioRat",
		parts = {
			part("Body", "Ball", V(3.6, 3.2, 3.6), V(0, 1.8, 0), C(225, 200, 215)),
			part("Ear", "Block", V(0.6, 1.6, 0.6), V(-0.9, 3.8, 0), C(235, 170, 195)),
			part("Ear2", "Block", V(0.6, 1.6, 0.6), V(0.9, 3.8, 0), C(235, 170, 195)),
			part("Antenna", "Block", V(0.2, 3, 0.2), V(0, 5, 0), C(160, 160, 170)),
		},
		respawn = 60,
	},
	KingBeetle = {
		name = "Король белый жук-олень",
		zone = "Forest",
		count = 1,
		hp = 100,
		speed = 0,
		damage = 0,
		aggro = 0,
		behavior = "tree",
		drop = "KingBeetle",
		parts = {
			part("Trunk", "Cylinder", V(26, 5, 5), V(0, 13, 0), C(110, 80, 55), Enum.Material.Wood),
			part("Crown", "Ball", V(16, 12, 16), V(0, 28, 0), C(50, 130, 60), Enum.Material.Grass),
			part("Beetle", "Block", V(1.8, 1.2, 3.4), V(1.6, 19, -2.6), C(245, 245, 250), Enum.Material.SmoothPlastic),
			part("Horn", "Block", V(0.4, 0.4, 2.2), V(1.6, 19.8, -5), C(235, 235, 240)),
		},
		respawn = 150,
	},
	Melanin = {
		name = "Меланиновая ящерица",
		zone = "Swamp",
		count = 1,
		hp = 260,
		speed = 8,
		damage = 30,
		aggro = 45,
		behavior = "chase",
		drop = "Melanin",
		parts = {
			part("Body", "Block", V(12, 7, 22), V(0, 5, 0), C(140, 100, 190)),
			part("Head", "Block", V(8, 5, 8), V(0, 5.5, -14), C(150, 110, 200)),
			part("Mouth", "Block", V(6, 1.2, 6), V(0, 3, -15), C(220, 90, 130)),
			part("Weak", "Ball", V(2.4, 2.4, 2.4), V(0, 9, 3), C(70, 40, 90), Enum.Material.Neon),
			part("Tail", "Block", V(4, 3, 12), V(0, 3, 17), C(130, 90, 180)),
		},
		weak = { part = "Weak", mult = 8 },
		respawn = 150,
	},
	HyperPuff = {
		name = "Гипердождевик",
		zone = "Meadow",
		count = 3,
		hp = 16,
		speed = 38,
		damage = 0,
		aggro = 45,
		behavior = "flee",
		drop = "HyperPuff",
		parts = {
			part("Body", "Ball", V(2.6, 2.6, 2.6), V(0, 1.4, 0), C(255, 215, 235)),
			part("Eye1", "Ball", V(0.5, 0.5, 0.5), V(-0.5, 1.9, -1.1), C(30, 30, 40)),
			part("Eye2", "Ball", V(0.5, 0.5, 0.5), V(0.5, 1.9, -1.1), C(30, 30, 40)),
		},
		respawn = 45,
	},
	Wolf = {
		name = "Волк",
		zone = "Forest",
		count = 0, -- волки появляются только в составе стаи Альфа-волка
		hp = 70,
		speed = 20,
		damage = 12,
		aggro = 60,
		behavior = "chase",
		drop = "Wolf",
		parts = {
			part("Body", "Block", V(2.4, 2.4, 5), V(0, 2.6, 0), C(130, 130, 145)),
			part("Head", "Block", V(1.8, 1.8, 2.4), V(0, 3.2, -3.4), C(150, 150, 165)),
			part("Tail", "Block", V(0.8, 0.8, 2.6), V(0, 3, 3.6), C(110, 110, 125)),
		},
		respawn = 60,
	},
	WolfAlpha = {
		name = "Альфа-волк",
		zone = "Forest",
		count = 1,
		hp = 150,
		speed = 22,
		damage = 20,
		aggro = 70,
		behavior = "chase",
		drop = "WolfAlpha",
		parts = {
			part("Body", "Block", V(3.4, 3.4, 7), V(0, 3.4, 0), C(70, 70, 90)),
			part("Head", "Block", V(2.6, 2.6, 3.2), V(0, 4.4, -4.6), C(85, 85, 105)),
			part("Eyes", "Block", V(2.2, 0.5, 0.4), V(0, 4.8, -6.2), C(255, 90, 70), Enum.Material.Neon),
			part("Tail", "Block", V(1.1, 1.1, 3.4), V(0, 4, 5), C(60, 60, 80)),
		},
		respawn = 200,
		pack = { count = 3, member = "Wolf" },
	},
	OneEye = {
		name = "Безымянный одноглазый монстр",
		zone = "Cave",
		count = 2,
		hp = 80,
		speed = 15,
		damage = 14,
		aggro = 40,
		behavior = "chase",
		drop = "OneEye",
		parts = {
			part("Body", "Block", V(3, 3, 3), V(0, 2, 0), C(190, 90, 230)),
			part("Eye", "Ball", V(1.6, 1.6, 1), V(0, 2.3, -1.6), C(120, 200, 255), Enum.Material.Neon),
		},
		weak = { part = "Eye", mult = 3 },
		respawn = 70,
	},
	Slime = {
		name = "Безымянный слизистый монстр",
		zone = "Swamp",
		count = 2,
		hp = 120,
		speed = 9,
		damage = 16,
		aggro = 35,
		behavior = "chase",
		drop = "Slime",
		parts = {
			part("Body", "Ball", V(7, 5, 7), V(0, 2.4, 0), C(130, 220, 90), Enum.Material.Glass),
			part("Core", "Ball", V(2.4, 2.4, 2.4), V(0, 2.6, 0), C(60, 140, 50), Enum.Material.Neon),
		},
		weak = { part = "Core", mult = 3 },
		respawn = 70,
	},
	Worm = {
		name = "Безымянный червь-монстр",
		zone = "Barren",
		count = 1,
		hp = 140,
		speed = 12,
		damage = 20,
		aggro = 45,
		behavior = "chase",
		drop = "Worm",
		parts = {
			part("Head", "Ball", V(5, 5, 5), V(0, 3, -4), C(120, 60, 150)),
			part("Mouth", "Ball", V(3, 3, 1.4), V(0, 3, -6.6), C(240, 100, 130), Enum.Material.Neon),
			part("Mid", "Ball", V(4.2, 4.2, 4.2), V(0, 2.6, 0), C(110, 55, 140)),
			part("Tail", "Ball", V(3.4, 3.4, 3.4), V(0, 2, 4), C(100, 50, 130)),
		},
		weak = { part = "Mouth", mult = 3 },
		respawn = 100,
	},
}

return Monsters
