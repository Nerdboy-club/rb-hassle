local PlayerData = load("PlayerData")
local Binder = load("Binder")
local Hand = load("Hand")
local Registry = load("CardRegistry")
local Cards = load("Cards")

local player = { UserId = 1, DisplayName = "T", Parent = true }
local profile = PlayerData.load(player)
profile.inGame = true
check(profile.yen == 3000, "стартовые йены")
Binder.grant(player, 95); Binder.grant(player, 95); Binder.grant(player, 203)
profile.yen = 4321
profile.flags.metEta = true
PlayerData.save(player)
check(DB.p_1 ~= nil, "профиль записан")
PlayerData.unload(player)
check(Registry.count(95) == 0, "после unload копии освобождены")
local p2 = PlayerData.load(player)
check(p2.slots[95] and #p2.free == 2 and p2.yen == 4321 and p2.flags.metEta, "round-trip: слот, свободные, йены, флаги")
check(Registry.count(95) == 2, "после загрузки копии заняты снова")
PlayerData.unload(player)

-- выход игрока во время загрузки
local ghost = { UserId = 2, DisplayName = "G", Parent = nil }
DB.p_2 = { slots = { 1, 2, 3 }, free = {}, yen = 10 }
local before = Registry.count(1)
PlayerData.load(ghost)
check(PlayerData.get(ghost) == nil and Registry.count(1) == before, "вышедший во время загрузки не занимает лимит и профиль")

-- сбой DataStore: профиль не затирает сохранение
dbFail = true
local p3 = { UserId = 3, DisplayName = "F", Parent = true }
DB.p_3 = { slots = { 95 }, free = {}, yen = 777 }
local prof3 = PlayerData.load(p3)
dbFail = false
prof3.yen = 1
PlayerData.save(p3)
check(DB.p_3.yen == 777, "при сбое загрузки старое сохранение не затёрто")
PlayerData.unload(p3)

-- рука: лимит 6
local p4 = { UserId = 4, DisplayName = "H", Parent = true }
local prof4 = PlayerData.load(p4)
prof4.inGame = true
local added = 0
for i = 1, 8 do if Hand.add(p4, 203, nil) then added += 1 end end
check(added == 6 and #prof4.hand == 6, "в руке не больше шести карт")
Hand.dropAll(p4)
check(#prof4.hand == 0, "dropAll очищает руку")
print("ALL OK")
