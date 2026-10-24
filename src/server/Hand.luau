-- Рука: предмет, подобранный на острове, становится картой, но у игрока есть только минута,
-- чтобы вложить её в книгу. Не успел — карта снова превращается в предмет.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Cards = require(Shared.Cards)

local CardRegistry = require(script.Parent.CardRegistry)
local PlayerData = require(script.Parent.PlayerData)
local Binder = require(script.Parent.Binder)

local Hand = {}

local MAX_IN_HAND = 6

--- Подобрать предмет: занять копию и положить карту в руку. node — узел в мире (вернётся при истечении).
function Hand.add(player: Player, id: number, node: Instance?): (boolean, string?)
	local profile = PlayerData.get(player)
	local card = Cards.get(id)
	if not profile or not card then
		return false, "нет профиля"
	end
	if #profile.hand >= MAX_IN_HAND then
		return false, "Руки заняты: вложите карты в книгу"
	end
	if not CardRegistry.mint(id) then
		return false, "Лимит этой карты на острове исчерпан — предмет не превращается в карту"
	end
	table.insert(profile.hand, {
		uid = PlayerData.nextUid(profile),
		id = id,
		expires = os.clock() + Config.HandSeconds,
		node = node,
	})
	PlayerData.notify(player, ("Предмет стал картой: %s. Вложите её в книгу за %d секунд!"):format(card.name, Config.HandSeconds), "good")
	PlayerData.push(player)
	return true
end

--- Вложить карту из руки в книгу.
function Hand.insert(player: Player, uid: number)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	for index, entry in profile.hand do
		if entry.uid == uid then
			local ok, reason = Binder.insert(player, entry.id)
			if not ok then
				PlayerData.notify(player, reason or "Не вышло вложить карту", "warn")
				return
			end
			table.remove(profile.hand, index)
			if entry.node then
				entry.node:SetAttribute("Consumed", true) -- узел исчезнет и появится заново позже
			end
			local card = Cards.get(entry.id)
			PlayerData.notify(player, "В книге: " .. (card and card.name or "карта"), "good")
			PlayerData.push(player)
			return
		end
	end
end

--- Отпустить карту обратно (истёк таймер или игрок погиб): предмет снова лежит на месте.
local function drop(entry: PlayerData.HandEntry)
	CardRegistry.release(entry.id)
	if entry.node then
		entry.node:SetAttribute("Taken", false)
	end
end

function Hand.dropAll(player: Player)
	local profile = PlayerData.get(player)
	if not profile or #profile.hand == 0 then
		return
	end
	for _, entry in profile.hand do
		drop(entry)
	end
	table.clear(profile.hand)
	PlayerData.push(player)
end

function Hand.extend(player: Player, seconds: number)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	for _, entry in profile.hand do
		entry.expires += seconds
	end
	PlayerData.push(player)
end

function Hand.start()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.5 then
			return
		end
		accumulator = 0
		local now = os.clock()
		for _, player in game:GetService("Players"):GetPlayers() do
			local profile = PlayerData.get(player)
			if profile and #profile.hand > 0 then
				local expired = false
				for index = #profile.hand, 1, -1 do
					local entry = profile.hand[index]
					if entry.expires <= now then
						table.remove(profile.hand, index)
						drop(entry)
						local card = Cards.get(entry.id)
						PlayerData.notify(
							player,
							(card and card.name or "Карта") .. " не успела попасть в книгу и снова стала предметом.",
							"warn"
						)
						expired = true
					end
				end
				if expired then
					PlayerData.push(player)
				end
			end
		end
	end)
end

return Hand
