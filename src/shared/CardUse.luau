-- Что делает карта при «Получить». Общий модуль: сервер по нему применяет эффект, клиент показывает описание.
-- Карт без эффекта (коллекционные предметы вроде горшка или розы) «Получить» не тратит — они остаются в книге.
local Cards = require(script.Parent.Cards)
local Spells = require(script.Parent.Spells)

export type Consumable = { heal: number?, yen: number?, haste: number? }

local CardUse = {}

-- еда, зелья и деньги: id карты -> эффект
CardUse.CONSUMABLE = {
	[201] = { heal = 60 },
	[202] = { heal = 100 },
	[203] = { heal = 30 },
	[204] = { heal = 80 },
	[205] = { heal = 150, haste = 20 },
	[43] = { heal = 120 },
	[61] = { heal = 40 },
	[66] = { heal = 25 },
	[67] = { heal = 25 },
	[75] = { heal = 20 },
	[80] = { heal = 25 },
	[73] = { yen = 10000 },
	[59] = { yen = 1000 },
	[85] = { yen = 100 },
} :: { [number]: Consumable }

-- особые предметы: id карты -> описание
local SPECIAL: { [number]: string } = {
	[4] = "Меч Истины в руке: ваш урон ×2 навсегда.",
	[12] = "Золотой компас: показывает три ближайших предмета на минуту.",
	[54] = "Колокольчик: показывает монстров рядом с вами.",
}

--- Описание эффекта «Получить» или nil, если у карты эффекта нет (коллекционная карта).
function CardUse.describe(card: Cards.Card): string?
	local spell = Spells.get(card.id)
	if spell then
		return spell.desc
	end
	local effect = CardUse.CONSUMABLE[card.id]
	if effect then
		local parts = {}
		if effect.heal then
			table.insert(parts, ("лечит %d HP"):format(effect.heal))
		end
		if effect.haste then
			table.insert(parts, ("ускорение на %d с"):format(effect.haste))
		end
		if effect.yen then
			table.insert(parts, ("+%d йен в кошелёк"):format(effect.yen))
		end
		return table.concat(parts, ", ") .. "."
	end
	return SPECIAL[card.id]
end

--- Можно ли применить карту (иначе «Получить» ничего не даёт и карту не тратит).
function CardUse.usable(card: Cards.Card): boolean
	return card.kind ~= "wallet" and CardUse.describe(card) ~= nil
end

return CardUse
