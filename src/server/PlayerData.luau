-- Профиль игрока: книга (слоты), рука, йены, прогресс. Сохраняется в DataStore (если он доступен).
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Cards = require(Shared.Cards)

local CardRegistry = require(script.Parent.CardRegistry)

export type FreeEntry = { uid: number, id: number }
export type HandEntry = { uid: number, id: number, expires: number, node: Instance? }

export type Profile = {
	slots: { [number]: boolean },
	free: { FreeEntry },
	hand: { HandEntry },
	yen: number,
	met: { [string]: boolean },
	purchases: { [string]: number },
	cured: { [number]: boolean },
	flags: { [string]: boolean },
	won: boolean,
	case: { number },
	inGame: boolean,
	nextUid: number,
}

local PlayerData = {}

local profiles: { [Player]: Profile } = {}
local store: DataStore? = nil

do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[PlayerData] DataStore недоступен, прогресс не сохраняется:", result)
	end
end

local function emptyProfile(): Profile
	return {
		slots = {},
		free = {},
		hand = {},
		yen = Config.StartYen,
		met = {},
		purchases = {},
		cured = {},
		flags = {},
		won = false,
		case = {},
		inGame = false,
		nextUid = 1,
	}
end

local function key(player: Player): string
	return "p_" .. player.UserId
end

--- Профиль -> таблица для DataStore (только числа/строки/bool).
local function serialize(profile: Profile): { [string]: any }
	local slots = {}
	for id in profile.slots do
		table.insert(slots, id)
	end
	local free = {}
	for _, entry in profile.free do
		table.insert(free, entry.id)
	end
	local cured = {}
	for index in profile.cured do
		table.insert(cured, index)
	end
	local flags = {}
	for name, value in profile.flags do
		if value then
			table.insert(flags, name)
		end
	end
	return {
		slots = slots,
		free = free,
		yen = profile.yen,
		purchases = profile.purchases,
		cured = cured,
		flags = flags,
		won = profile.won,
		case = profile.case,
	}
end

local function deserialize(raw: any): Profile
	local profile = emptyProfile()
	if type(raw) ~= "table" then
		return profile
	end
	for _, id in raw.slots or {} do
		if Cards.isNumbered(id) then
			profile.slots[id] = true
			CardRegistry.force(id)
		end
	end
	for _, id in raw.free or {} do
		if Cards.get(id) then
			table.insert(profile.free, { uid = profile.nextUid, id = id })
			profile.nextUid += 1
			if Cards.isNumbered(id) then
				CardRegistry.force(id)
			end
		end
	end
	profile.yen = tonumber(raw.yen) or Config.StartYen
	profile.purchases = raw.purchases or {}
	for _, index in raw.cured or {} do
		profile.cured[index] = true
	end
	for _, name in raw.flags or {} do
		profile.flags[name] = true
	end
	profile.won = raw.won == true
	profile.case = raw.case or {}
	return profile
end

function PlayerData.get(player: Player): Profile?
	return profiles[player]
end

--- Загрузка при входе. Если DataStore недоступен — чистый профиль.
function PlayerData.load(player: Player): Profile
	local raw = nil
	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return (store :: DataStore):GetAsync(key(player))
			end)
			if ok then
				raw = result
				break
			end
			warn("[PlayerData] загрузка не удалась:", result)
			task.wait(attempt)
		end
	end
	local profile = deserialize(raw)
	profiles[player] = profile
	return profile
end

function PlayerData.save(player: Player)
	local profile = profiles[player]
	if not profile or not store then
		return
	end
	local ok, err = pcall(function()
		(store :: DataStore):SetAsync(key(player), serialize(profile))
	end)
	if not ok then
		warn("[PlayerData] сохранение не удалось:", err)
	end
end

--- Освободить копии игрока и забыть профиль (выход с сервера).
function PlayerData.unload(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	for id in profile.slots do
		CardRegistry.release(id)
	end
	for _, entry in profile.free do
		if Cards.isNumbered(entry.id) then
			CardRegistry.release(entry.id)
		end
	end
	for _, entry in profile.hand do
		CardRegistry.release(entry.id)
		if entry.node then
			entry.node:SetAttribute("Taken", false)
		end
	end
	profiles[player] = nil
end

--- Снимок для клиента.
function PlayerData.push(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local slots = {}
	for id in profile.slots do
		table.insert(slots, id)
	end
	table.sort(slots)

	local free = {}
	for _, entry in profile.free do
		table.insert(free, { uid = entry.uid, id = entry.id })
	end

	local hand = {}
	local now = os.clock()
	for _, entry in profile.hand do
		table.insert(hand, { uid = entry.uid, id = entry.id, left = math.max(0, entry.expires - now) })
	end

	local curedCount = 0
	for _ in profile.cured do
		curedCount += 1
	end

	local flagList = {}
	for name, value in profile.flags do
		if value then
			table.insert(flagList, name)
		end
	end

	local met = {}
	for name in profile.met do
		table.insert(met, name)
	end
	table.sort(met)

	Remotes.State:FireClient(player, {
		slots = slots,
		free = free,
		hand = hand,
		yen = profile.yen,
		met = met,
		won = profile.won,
		case = profile.case,
		inGame = profile.inGame,
		cured = curedCount,
		flags = flagList,
	})
end

function PlayerData.nextUid(profile: Profile): number
	local uid = profile.nextUid
	profile.nextUid += 1
	return uid
end

function PlayerData.notify(player: Player, text: string, kind: string?)
	Remotes.Notify:FireClient(player, { text = text, kind = kind or "info" })
end

function PlayerData.ownedNumbered(profile: Profile): number
	local count = 0
	for _ in profile.slots do
		count += 1
	end
	return count
end

return PlayerData
