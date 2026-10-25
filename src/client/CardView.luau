-- Рисует карту в стиле оригинала: номер слева сверху, название по центру, ранг справа сверху, иллюстрация, описание внизу.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Cards)
local Ranks = require(Shared.Ranks)

local Theme = require(script.Parent.Theme)

local CardView = {}

--- Большая карта в стиле карт Острова Жадности: чёрная рамка, номер слева сверху,
--- название сверху в центре, ранг справа сверху, иллюстрация, красная панель с описанием.
--- owned=false — силуэт.
function CardView.big(parent: Instance, id: number, owned: boolean, size: UDim2?): Frame
	local card = Cards.get(id) :: Cards.Card
	local rankColor = Ranks.color(card.rank)
	local BLACK = Color3.fromRGB(12, 12, 15)
	local WHITE = Color3.fromRGB(240, 240, 244)

	local frame = Theme.frame(parent, size or UDim2.fromOffset(230, 320), nil, BLACK)
	Theme.corner(frame, 10)
	Theme.stroke(frame, owned and Color3.fromRGB(70, 72, 84) or Color3.fromRGB(50, 52, 62), 2)

	-- верхняя полоса: № | название | ранг
	local number = card.numbered and ("№%d"):format(card.id) or (card.spell and "СПЕЛЛ" or "СВОБ.")
	Theme.label(frame, number, UDim2.fromOffset(60, 20), UDim2.fromOffset(8, 6), {
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = WHITE,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
	Theme.label(frame, owned and card.name or "???", UDim2.new(1, -118, 0, 32), UDim2.fromOffset(62, 0), {
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = WHITE,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local chip = Theme.label(frame, card.rank, UDim2.fromOffset(36, 20), UDim2.new(1, -44, 0, 6), {
		Font = Enum.Font.GothamBlack,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextColor3 = BLACK,
		BackgroundTransparency = 0,
		BackgroundColor3 = rankColor,
	})
	Theme.corner(chip, 5)

	-- иллюстрация с зеленовато-синим оттенком, как на оригинальных картах
	local tint = owned and Color3.fromRGB(34, 110, 100):Lerp(rankColor, 0.25) or Color3.fromRGB(38, 40, 52)
	local art = Theme.frame(frame, UDim2.new(1, -16, 0, 130), UDim2.fromOffset(8, 36), tint)
	Theme.corner(art, 4)
	Theme.stroke(art, WHITE, 1)
	local shine = Instance.new("UIGradient")
	shine.Rotation = 60
	shine.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 160, 170))
	shine.Parent = art
	Theme.label(art, owned and (Cards.ICONS[card.kind] or "🎴") or "❔", UDim2.fromScale(1, 1), nil, {
		TextSize = 64,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
	})

	-- нижняя красная панель с описанием
	local desc = Theme.frame(frame, UDim2.new(1, -16, 1, -176), UDim2.fromOffset(8, 168), Color3.fromRGB(122, 26, 34))
	Theme.corner(desc, 4)
	Theme.stroke(desc, WHITE, 1)
	Theme.padding(desc, 6)
	Theme.label(desc, owned and card.desc or "Карты нет в книге. Найдите предмет и превратите его в карту.", UDim2.fromScale(1, 1), nil, {
		TextSize = 11,
		TextColor3 = WHITE,
	})
	return frame
end

return CardView
