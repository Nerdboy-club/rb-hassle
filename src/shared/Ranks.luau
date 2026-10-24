-- Десять рангов карт: от самого сложного (SS) до самого простого (H).
-- limit — сколько копий одной карты может существовать на сервере одновременно
-- (от >100 до трёх): пока лимит выбран, предмет нельзя превратить в карту.
local Ranks = {}

Ranks.order = { "SS", "S", "A", "B", "C", "D", "E", "F", "G", "H" }

Ranks.info = {
	SS = { color = Color3.fromRGB(255, 70, 110), limit = 3 },
	S = { color = Color3.fromRGB(255, 140, 60), limit = 5 },
	A = { color = Color3.fromRGB(255, 205, 60), limit = 8 },
	B = { color = Color3.fromRGB(150, 220, 70), limit = 12 },
	C = { color = Color3.fromRGB(70, 210, 150), limit = 20 },
	D = { color = Color3.fromRGB(70, 190, 230), limit = 30 },
	E = { color = Color3.fromRGB(100, 140, 240), limit = 45 },
	F = { color = Color3.fromRGB(150, 120, 230), limit = 60 },
	G = { color = Color3.fromRGB(180, 180, 195), limit = 80 },
	H = { color = Color3.fromRGB(140, 140, 150), limit = 120 },
}

function Ranks.color(rank: string): Color3
	local info = Ranks.info[rank]
	return info and info.color or Color3.fromRGB(200, 200, 200)
end

function Ranks.limit(rank: string): number
	local info = Ranks.info[rank]
	return info and info.limit or 1
end

return Ranks
