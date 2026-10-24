-- Размещение NPC. Роль (role) разбирает server/NpcService.luau.
-- Позиция: зона + смещение (dx, dz) от её центра. Для побережья — абсолютные координаты.
export type Npc = {
	name: string,
	zone: string,
	dx: number,
	dz: number,
	shirt: Color3,
	skin: Color3?,
	role: string,
	shop: string?,
	scale: number?,
	index: number?,
}

local C = Color3.fromRGB

local Npcs: { [string]: Npc } = {
	eta = { name = "Эта — гейм-мастер входа", zone = "Shiso", dx = 16, dz = -8, shirt = C(240, 120, 170), role = "eta" },
	elena = { name = "Елена — гейм-мастер выхода", zone = "Port", dx = 40, dz = 40, shirt = C(120, 170, 240), role = "elena" },
	portmaster = { name = "Начальник порта", zone = "Port", dx = -10, dz = 10, shirt = C(60, 80, 120), role = "portmaster", scale = 1.2 },
	razor = { name = "Рейзор", zone = "Soufrabi", dx = 20, dz = -20, shirt = C(40, 40, 50), role = "razor", scale = 1.15 },
	casinoking = { name = "Король казино", zone = "Dorias", dx = 0, dz = -12, shirt = C(180, 30, 50), role = "casino", scale = 1.1 },
	dwan = { name = "Дван — страж замка", zone = "Limeiro", dx = 0, dz = 30, shirt = C(230, 210, 120), role = "finalquiz", scale = 1.1 },
	ging = { name = "Гинг Фрикс", zone = "Limeiro", dx = 24, dz = 24, shirt = C(40, 120, 70), role = "ging" },
	catdiner = { name = "Кот из «Кошачьей закусочной»", zone = "Antokiba", dx = 24, dz = 10, shirt = C(245, 205, 110), role = "catdiner", scale = 0.9 },
	host = { name = "Распорядитель конкурса", zone = "Antokiba", dx = -20, dz = -6, shirt = C(220, 140, 60), role = "host" },
	goldgirl = { name = "Девушка с золотой пылью", zone = "Aiai", dx = -8, dz = 6, shirt = C(250, 215, 90), role = "goldgirl" },
	goldguard = { name = "Страж Девушки из золотой пыли", zone = "Aiai", dx = 2, dz = 12, shirt = C(60, 60, 80), role = "goldguard", scale = 1.2 },
	beachnpc = { name = "NPC «Участок на пляже»", zone = "Coast", dx = 560, dz = 650, shirt = C(240, 160, 90), role = "beach" },
	shop_antokiba = { name = "Торговый дом Антокибы", zone = "Antokiba", dx = 14, dz = -24, shirt = C(180, 140, 80), role = "shop", shop = "antokiba" },
	shop_wigpen = { name = "Wig & Pen", zone = "Antokiba", dx = -30, dz = 22, shirt = C(130, 90, 160), role = "shop", shop = "wigpen" },
	shop_masadora = { name = "Торговый дом Масадоры", zone = "Masadora", dx = -16, dz = 14, shirt = C(110, 100, 170), role = "shop", shop = "masadora" },
	shop_spells = { name = "Магазин спелл-карт", zone = "Masadora", dx = 20, dz = -10, shirt = C(180, 90, 220), role = "shop", shop = "spells" },
}

-- Десять больных жителей горной деревни: лечатся картой «Лекарство».
for index = 1, 10 do
	Npcs["villager" .. index] = {
		name = "Больной житель",
		zone = "Bandits",
		dx = math.cos(index * 0.628) * 30,
		dz = math.sin(index * 0.628) * 30,
		shirt = Color3.fromRGB(120 + index * 8, 100, 90),
		role = "villager",
		index = index,
	}
end

return Npcs
