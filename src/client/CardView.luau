-- Рисует карту: номер слева сверху, ранг справа сверху, название, иллюстрация, описание внизу.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Cards)
local Ranks = require(Shared.Ranks)

local Theme = require(script.Parent.Theme)

local CardView = {}

--- Большая карта (панель подробностей). owned=false — силуэт.
function CardView.big(parent: Instance, id: number, owned: boolean, size: UDim2?): Frame
	local card = Cards.get(id) :: Cards.Card
	local rankColor = Ranks.color(card.rank)

	local frame = Theme.frame(parent, size or UDim2.fromOffset(230, 320), nil, Color3.fromRGB(24, 26, 36))
	Theme.corner(frame, 14)
	Theme.stroke(frame, owned and rankColor or Theme.muted, 3)

	local number = card.numbered and ("№%d"):format(card.id) or (card.spell and "СПЕЛЛ" or "СВОБ.")
	Theme.label(frame, number, UDim2.fromOffset(80, 22), UDim2.fromOffset(12, 8), {
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = Theme.muted,
	})

	local chip = Theme.label(frame, card.rank, UDim2.fromOffset(44, 26), UDim2.new(1, -56, 0, 8), {
		Font = Enum.Font.GothamBlack,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextColor3 = Color3.fromRGB(20, 20, 24),
		BackgroundTransparency = 0,
		BackgroundColor3 = rankColor,
	})
	Theme.corner(chip, 8)

	Theme.label(frame, owned and card.name or "???", UDim2.new(1, -24, 0, 44), UDim2.fromOffset(12, 40), {
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	local art = Theme.frame(frame, UDim2.new(1, -24, 0, 112), UDim2.fromOffset(12, 88), owned and rankColor:Lerp(Color3.fromRGB(20, 22, 30), 0.65) or Color3.fromRGB(38, 40, 52))
	Theme.corner(art, 10)
	Theme.label(art, owned and (Cards.ICONS[card.kind] or "🎴") or "❔", UDim2.fromScale(1, 1), nil, {
		TextSize = 60,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
	})

	Theme.label(frame, owned and card.desc or "Карты нет в книге. Найдите предмет и превратите его в карту.", UDim2.new(1, -24, 0, 104), UDim2.fromOffset(12, 208), {
		TextSize = 12,
		TextColor3 = Theme.muted,
	})
	return frame
end

return CardView
