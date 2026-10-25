-- Точка входа сервера. Порядок важен: сначала мир, затем сервисы, которые на него опираются.
-- Каждый шаг защищён pcall: ошибка в одном сервисе не должна оставлять игрока без персонажа и остальные сервисы не запущенными.
local function safely(label: string, step: () -> ())
	local ok, err = pcall(step)
	if not ok then
		warn(`[Main] {label}: {err}`)
	end
end

local WorldBuilder = require(script.Parent.WorldBuilder)
safely("WorldBuilder.build", WorldBuilder.build)

local services = {
	"Hand",
	"Status",
	"ItemService",
	"MonsterService",
	"CombatService",
	"ShopService",
	"QuizService",
	"SkinService",
	"NpcService",
	"ArenaService",
	"SpellService",
	"BinderActions",
	"GameService",
}

for _, name in services do
	safely(name, function()
		local module = require(script.Parent[name])
		module.start()
	end)
end
