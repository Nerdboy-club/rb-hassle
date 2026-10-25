-- Глобальные счётчики копий. У каждого ранга свой лимит конвертации: пока копий столько,
-- сколько разрешено, предмет нельзя превратить в карту — ни одному игроку на сервере.
-- Лимит освобождается, когда карту «вернули в исходное состояние» или игрок вышел.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Cards)
local Ranks = require(Shared.Ranks)

local CardRegistry = {}

local copies: { [number]: number } = {}

--- Срабатывает с id карты, когда её наличие изменилось (узлы в мире обновляют вид).
CardRegistry.changed = Instance.new("BindableEvent")

local function fire(id: number)
	CardRegistry.changed:Fire(id)
end

function CardRegistry.count(id: number): number
	return copies[id] or 0
end

function CardRegistry.limit(id: number): number
	local card = Cards.get(id)
	if not card or not card.numbered then
		return math.huge
	end
	return Ranks.limit(card.rank)
end

--- Можно ли сейчас превратить предмет этой карты в новую карту.
function CardRegistry.canMint(id: number): boolean
	return CardRegistry.count(id) < CardRegistry.limit(id)
end

--- Занять копию. false — лимит выбран.
function CardRegistry.mint(id: number): boolean
	if not CardRegistry.canMint(id) then
		return false
	end
	copies[id] = CardRegistry.count(id) + 1
	fire(id)
	return true
end

--- Занять копию без проверки лимита (загрузка сохранённой книги игрока).
function CardRegistry.force(id: number)
	copies[id] = CardRegistry.count(id) + 1
	fire(id)
end

function CardRegistry.release(id: number)
	copies[id] = math.max(0, CardRegistry.count(id) - 1)
	fire(id)
end

--- Копия израсходована навсегда («Получить»): счётчик остаётся занятым, предмет не вернётся.
function CardRegistry.consume(id: number)
	-- счётчик не меняем: карта ушла из игры, лимит остаётся выбранным
	fire(id)
end

return CardRegistry
