local SRC = "C:/all_ai/noeldaun/rb-hassle/src/shared/"
local cache = {}
local env
local proxy = function(name)
	return setmetatable({}, { __index = function(_, k) return name .. "." .. tostring(k) end })
end
local function loadShared(name)
	if cache[name] then return cache[name] end
	local fn = assert(loadstring(SOURCES[name], name))
	local fakeScript = { Parent = setmetatable({}, { __index = function(_, k) return k end }) }
	local e = setmetatable({
		script = fakeScript,
		require = function(n) return loadShared(n) end,
		Color3 = { fromRGB = function(r, g, b) return { r = r, g = g, b = b, Lerp = function(self) return self end } end },
		Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end },
		Enum = setmetatable({}, { __index = function(_, k) return proxy(k) end }),
		math = math, string = string, table = table, tostring = tostring, tonumber = tonumber,
		ipairs = ipairs, pairs = pairs, type = type, Random = nil,
	}, { __index = _G })
	setfenv(fn, e)
	cache[name] = fn()
	return cache[name]
end

local Cards = loadShared("Cards")
local Ranks = loadShared("Ranks")
local Zones = loadShared("Zones")
local Monsters = loadShared("Monsters")
local Npcs = loadShared("Npcs")
local Spells = loadShared("Spells")
local Quiz = loadShared("Quiz")
local Util = loadShared("Util")

local problems = 0
local function bad(msg) problems += 1 print("PROBLEM: " .. msg) end

-- numbered
assert(#Cards.numberedIds == 100, "numbered " .. #Cards.numberedIds)
local rankCount, seen = {}, {}
for _, id in Cards.numberedIds do
	if seen[id] then bad("dup id " .. id) end
	seen[id] = true
	local c = Cards.get(id)
	rankCount[c.rank] = (rankCount[c.rank] or 0) + 1
	if not Ranks.info[c.rank] then bad("bad rank " .. id) end
	local s = Cards.parseSource(c.source)
	if s.type == "p" and not Zones[s.arg] then bad("card " .. id .. " zone " .. tostring(s.arg)) end
	if s.type == "m" then
		local found = false
		for _, m in Monsters do if m.drop == s.arg then found = true end end
		if not found then bad("card " .. id .. " monster " .. tostring(s.arg)) end
	end
end
for id = 1, 100 do if not seen[id] then bad("missing id " .. id) end end
local order = {}
for _, r in Ranks.order do table.insert(order, r .. "=" .. (rankCount[r] or 0)) end
print("ranks: " .. table.concat(order, " "))
print("spells:", #Spells.list, "free:", #Cards.freeIds)
assert(#Spells.list == 32)

-- monsters
for key, m in Monsters do
	if not Zones[m.zone] then bad("monster zone " .. key) end
	if m.drop and m.count > 0 and #Cards.withSource("m", m.drop) == 0 and key ~= "Wolf" then bad("no drop card for " .. key) end
end
-- npc zones
for id, n in Npcs do
	if not Zones[n.zone] then bad("npc zone " .. id) end
	if n.role == "shop" and not n.shop then bad("shop npc " .. id) end
end
-- shop sources
local shops = {}
for _, c in Cards.withSource("s", nil) do shops[Cards.parseSource(c.source).arg] = true end
local list = {}
for k in shops do table.insert(list, k) end
table.sort(list)
print("shops with stock:", table.concat(list, ","))
-- quiz
for i, q in Quiz do
	if #q.options ~= 4 or q.answer < 1 or q.answer > 4 then bad("quiz " .. i) end
end
print("quiz questions:", #Quiz)
-- zone detection
print("zoneAt Antokiba center:", Util.zoneAt(-40, 300), " origin:", Util.zoneAt(0, 0), " coast:", Util.zoneAt(870, 0))
print("problems:", problems)
