return {
	CarsFolderName = "Cars", -- ServerStorage.Cars: Model'и машин (с VehicleSeat внутри)
	SpawnCooldownSeconds = 3,
	SpawnDistance = 14, -- студов перед игроком
	CarYawOffsetDegrees = 0, -- если машина появляется боком/задом: 90, -90 или 180

	-- 1 stud ~ 0.28 m (стандарт Roblox) для спидометра
	StudToMeters = 0.28,

	Traffic = {
		Enabled = true,
		Count = 12,
		PathsFolderName = "TrafficPaths", -- Workspace.TrafficPaths (см. README)
		TemplatesFolderName = "TrafficCars", -- ServerStorage.TrafficCars (опционально)
		TemplateYawOffsetDegrees = 0, -- если шаблон едет боком/задом: 90, -90, 180

		DefaultSpeedLimit = 50, -- studs/s (~50 km/h)
		Accel = 18, -- studs/s^2
		Brake = 45,
		MinSpawnGap = 30, -- минимальная дистанция между машинами при появлении
		MinPlayerSpawnDistance = 100, -- не появляться ближе этого к игрокам
		StuckSeconds = 20, -- машина стоит дольше -> переставляем в другое место
	},

	Shashki = {
		MinSpeedKmh = 80, -- ниже этой скорости очки не начисляются
		NearMissDistance = 9, -- studs между центрами машин (соседняя полоса ~12)
		PerCarCooldown = 2.5, -- одну и ту же машину повторно засчитываем не чаще
		BasePoints = 50,
		ComboWindow = 4, -- секунд без близкого проезда -> комбо сбрасывается
		MaxMultiplier = 10,
		CrashSpeedDrop = 0.4, -- потеря >40% скорости за 0.25 с = авария, комбо сгорает
	},
}
