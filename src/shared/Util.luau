local Zones = require(script.Parent.Zones)

local Util = {}

function Util.formatYen(amount: number): string
	local text = tostring(math.floor(amount))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	return (formatted:gsub("^ ", "")) .. " Ұ"
end

--- Ключ зоны, внутри которой находится точка (город важнее дикой местности), либо nil.
function Util.zoneAt(x: number, z: number): string?
	local best: string? = nil
	local bestRatio = math.huge
	for key, zone in Zones do
		if key ~= "Coast" then
			local ratio = math.sqrt((x - zone.x) ^ 2 + (z - zone.z) ^ 2) / zone.r
			if ratio <= 1 then
				local weight = zone.kind == "wild" and ratio + 0.5 or ratio
				if weight < bestRatio then
					best, bestRatio = key, weight
				end
			end
		end
	end
	if not best and math.sqrt(x * x + z * z) > 840 then
		return "Coast"
	end
	return best
end

--- Случайная точка внутри зоны (для побережья — по кольцу у воды).
function Util.randomPointIn(zoneKey: string, rng: Random): Vector3
	local zone = Zones[zoneKey]
	if zoneKey == "Coast" then
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(850, 880)
		return Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	end
	local angle = rng:NextNumber(0, math.pi * 2)
	local radius = zone.r * math.sqrt(rng:NextNumber(0.05, 1)) * 0.85
	return Vector3.new(zone.x + math.cos(angle) * radius, 0, zone.z + math.sin(angle) * radius)
end

function Util.zoneName(zoneKey: string?): string
	local zone = zoneKey and Zones[zoneKey]
	return zone and zone.name or "Неизвестные земли"
end

return Util
