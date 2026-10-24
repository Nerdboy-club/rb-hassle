-- Все числа игры в одном месте.
return {
	HandSeconds = 60, -- карта в руке: не вложил в книгу за минуту — снова станет предметом
	NumberedSlots = 100, -- «указанные» слоты книги
	FreeSlots = 45, -- свободные слоты
	StartYen = 3000,

	PickupRespawnSeconds = 45,
	PickupHoldSeconds = 0.5,

	AttackRange = 14,
	AttackCooldown = 0.5,
	BaseDamage = 8,

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
