-- Все числа игры в одном месте.
return {
	HandSeconds = 60, -- карта в руке: не вложил в книгу за минуту — снова станет предметом
	NumberedSlots = 100, -- «указанные» слоты книги
	FreeSlots = 45, -- свободные слоты
	StartYen = 3000,
	DevGiveAllSpells = true, -- только в Studio: при входе в игру в свободные слоты кладутся все 40 заклинаний (для проверки)

	PickupRespawnSeconds = 75, -- дольше, чтобы предметы нельзя было быстро фармить на продажу
	PickupHoldSeconds = 0.5,

	AttackRange = 14,
	AttackCooldown = 0.5,
	BaseDamage = 12,

	-- добыча с монстров делится по вкладу в урон; последний удар даёт небольшой бонус к доле
	LastHitBonus = 0.10,
	MinLootShare = 0.10, -- меньше этой доли вклада — карты и йен нет (только для открытого мира)

	-- арены редких боссов: свои копии босса для каждой группы
	ArenaSlotsPerBoss = 6, -- сколько боёв с одним боссом идёт одновременно
	ArenaMaxParty = 4,
	ArenaSeconds = 300, -- время на бой; не победили — все возвращаются, босс исчезает
	ArenaQueueSeconds = 45, -- ожидание случайных игроков в очереди
	ArenaCooldownSeconds = 30, -- после сдачи или поражения нельзя сразу войти снова
	ArenaHpScale = { 1, 1.6, 2.2, 2.8 }, -- множитель HP босса по размеру группы (1–4)
	ArenaRadius = 55,
	ArenaY = 2500,

	RespawnSeconds = 3,
	AutosaveSeconds = 60,
	DataStoreName = "GreedIslandV1",

	MetRadius = 25, -- «встреченные» игроки попадают в список книги
	MetSeconds = 3,

	StanceCooldown = 1,
	ZetsuAggroFactor = 0.15, -- в Зетсу монстры почти не замечают
	TenDamageFactor = 0.5, -- в Тен урон от монстров вдвое меньше

	InfoPrice = 400, -- «купить информацию» в торговых лавках
	BRankPurchases = 50, -- карты ранга B продаются после 50 покупок в одной лавке
	SellFraction = 0.4, -- сколько цены карты платит лавка

	ContestIntervalSeconds = 420, -- «ежемесячный» конкурс Антокибы
	ContestAnswerSeconds = 20,

	FinalQuizQuestions = 5,
	FinalQuizPass = 4,

	CaseSlots = 3, -- футляр на три слота после победы

	RealWorldPos = Vector3.new(0, 1500, 0),
	IslandRadius = 900,
}
