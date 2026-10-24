-- Книга: 100 указанных слотов + 45 свободных. Вложить, вернуть в исходное состояние, «Приращение».
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Cards = require(Shared.Cards)
local Spells = require(Shared.Spells)

local CardRegistry = require(script.Parent.CardRegistry)
local PlayerData = require(script.Parent.PlayerData)

local Binder = {}

-- Эффекты «Приращения» для несложных карт: {heal, haste секунд, yen}
local CONSUMABLE: { [number]: { heal: number?, yen: number?, haste: number? } } = {
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
}

function Binder.hasId(profile: PlayerData.Profile, id: number): boolean
	if profile.slots[id] then
		return true
	end
	for _, entry in profile.free do
		if entry.id == id then
			return true
		end
	end
	return false
end

function Binder.has(player: Player, id: number): boolean
	local profile = PlayerData.get(player)
	return profile ~= nil and Binder.hasId(profile, id)
end

function Binder.freeCount(profile: PlayerData.Profile, id: number): number
	local count = 0
	for _, entry in profile.free do
		if entry.id == id then
			count += 1
		end
	end
	return count
end

function Binder.freeSpace(profile: PlayerData.Profile): number
	return Config.FreeSlots - #profile.free
end

--- Удалить одну копию карты из свободных слотов.
function Binder.takeFree(profile: PlayerData.Profile, id: number): boolean
	for index, entry in profile.free do
		if entry.id == id then
			table.remove(profile.free, index)
			return true
		end
	end
	return false
end

function Binder.isComplete(profile: PlayerData.Profile): boolean
	return PlayerData.ownedNumbered(profile) >= Config.NumberedSlots
end

--- Положить уже занятую (minted) карту: свой слот, иначе свободный. (ok, где)
function Binder.insert(player: Player, id: number): (boolean, string?)
	local profile = PlayerData.get(player)
	if not profile then
		return false, "нет профиля"
	end
	if Cards.isNumbered(id) and not profile.slots[id] then
		profile.slots[id] = true
		PlayerData.push(player)
		Binder.afterInsert(player, profile)
		return true, "slot"
	end
	if Binder.freeSpace(profile) <= 0 then
		return false, "Свободные слоты книги заполнены"
	end
	table.insert(profile.free, { uid = PlayerData.nextUid(profile), id = id })
	PlayerData.push(player)
	return true, "free"
end

--- Занять копию и положить в книгу (награды, покупки). Откатывает счётчик, если не поместилось.
function Binder.grant(player: Player, id: number): (boolean, string?)
	local card = Cards.get(id)
	if not card then
		return false, "нет такой карты"
	end
	if card.numbered and not CardRegistry.mint(id) then
		return false, "Лимит этой карты на острове исчерпан"
	end
	local ok, reason = Binder.insert(player, id)
	if not ok and card.numbered then
		CardRegistry.release(id)
	end
	return ok, reason
end

function Binder.afterInsert(player: Player, profile: PlayerData.Profile)
	if not profile.won and Binder.isComplete(profile) then
		require(script.Parent.GameService).onComplete(player)
	end
end

--- Вернуть карту «в исходное состояние»: предмет снова лежит в мире, лимит освобождается.
function Binder.release(player: Player, ref: { slot: number?, uid: number? })
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	if ref.slot and profile.slots[ref.slot] then
		if ref.slot == Cards.BLESSING_ID then
			PlayerData.notify(player, "Благословение правителя нельзя вернуть.", "warn")
			return
		end
		profile.slots[ref.slot] = nil
		CardRegistry.release(ref.slot)
		PlayerData.notify(player, "Карта вернулась в исходное состояние — теперь это снова предмет.", "info")
	elseif ref.uid then
		for index, entry in profile.free do
			local card = Cards.get(entry.id)
			if entry.uid == ref.uid and card and card.numbered then
				table.remove(profile.free, index)
				CardRegistry.release(entry.id)
				PlayerData.notify(player, "Копия вернулась в исходное состояние.", "info")
				break
			end
		end
	end
	PlayerData.push(player)
end

local function heal(player: Player, amount: number)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
	end
end

--- «Приращение»: превратить карту в настоящую вещь. Обратно в карту она уже не станет.
function Binder.gain(player: Player, ref: { slot: number?, uid: number? })
	local profile = PlayerData.get(player)
	if not profile then
		return
	end

	local id: number? = nil
	local freeIndex: number? = nil
	if ref.slot and profile.slots[ref.slot] then
		id = ref.slot
	elseif ref.uid then
		for index, entry in profile.free do
			if entry.uid == ref.uid then
				id, freeIndex = entry.id, index
				break
			end
		end
	end
	if not id then
		return
	end
	local card = Cards.get(id)
	if not card or card.kind == "wallet" then
		return
	end
	if id == Cards.BLESSING_ID then
		PlayerData.notify(player, "Благословение правителя нужно для победы — его нельзя использовать.", "warn")
		return
	end

	local spell = Spells.get(id)
	if spell then
		local cast = require(script.Parent.SpellService).cast(player, spell)
		if not cast then
			return
		end
	end

	if ref.slot then
		profile.slots[ref.slot] = nil
	elseif freeIndex then
		table.remove(profile.free, freeIndex)
	end
	if card.numbered then
		CardRegistry.consume(id)
	end

	local effect = CONSUMABLE[id]
	if effect then
		if effect.heal then
			heal(player, effect.heal)
		end
		if effect.yen then
			profile.yen += effect.yen
		end
		if effect.haste then
			require(script.Parent.Status).apply(player, "haste", effect.haste, 1.4)
		end
	elseif id == 4 then
		profile.flags.sword = true
		PlayerData.notify(player, "Меч Истины в вашей руке: урон ×2 навсегда.", "good")
	elseif id == 12 then
		require(script.Parent.ItemService).hintNearest(player, 3)
	elseif id == 54 then
		require(script.Parent.MonsterService).pingNear(player, 160)
	elseif not spell then
		PlayerData.notify(player, card.name .. ": предмет материализован, но в карту уже не вернётся.", "info")
	end

	PlayerData.push(player)
end

return Binder
