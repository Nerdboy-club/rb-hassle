-- Эффекты карт заклинаний. cast() вызывается из Binder.gain; возвращает false, если заклинание не сработало
-- (тогда карта не тратится).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Cards)
local Remotes = require(Shared.Remotes)
local Spells = require(Shared.Spells)
local Util = require(Shared.Util)
local Zones = require(Shared.Zones)

local FxService = require(script.Parent.FxService)
local PlayerData = require(script.Parent.PlayerData)
local Status = require(script.Parent.Status)
local Hand = require(script.Parent.Hand)
local ItemService = require(script.Parent.ItemService)
local MonsterService = require(script.Parent.MonsterService)
local WorldBuilder = require(script.Parent.WorldBuilder)

local SpellService = {}

local CAST_RADIUS = 30

local function root(player: Player): Part?
	local character = player.Character
	local part = character and character:FindFirstChild("HumanoidRootPart")
	return part and part :: Part or nil
end

local function humanoid(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function nearestOther(player: Player, range: number): Player?
	local mine = root(player)
	if not mine then
		return nil
	end
	local best: Player? = nil
	local bestDistance = range
	for _, other in Players:GetPlayers() do
		local profile = PlayerData.get(other)
		local theirs = root(other)
		if other ~= player and theirs and profile and profile.inGame then
			local distance = (theirs.Position - mine.Position).Magnitude
			if distance <= bestDistance then
				best, bestDistance = other, distance
			end
		end
	end
	return best
end

--- Вредное заклинание против игрока: отражение и блокировка защищают.
local function harmful(caster: Player, victim: Player): boolean
	if Status.has(victim, "reflect") then
		Status.remove(victim, "reflect")
		PlayerData.notify(victim, "Ваше Отражение вернуло заклинание отправителю!", "good")
		PlayerData.notify(caster, "Заклинание отразилось — оно не подействовало.", "warn")
		return false
	end
	return true
end

local handlers: { [string]: (Player, { [string]: any }, string?) -> boolean } = {}

function handlers.exit(player)
	local part = root(player)
	if part then
		FxService.flash("teleportOut", part.Position)
	end
	require(script.Parent.GameService).exitGame(player)
	return true
end

-- куда можно лететь заклинанием «Полёт»
local FLY_ZONES = { "Shiso", "Antokiba", "Rubicuta", "Masadora", "Aiai", "Soufrabi", "Dorias", "Limeiro", "Port" }

local function flyTo(player: Player, zoneKey: string): boolean
	if require(script.Parent.ArenaService).isBusy(player) then
		PlayerData.notify(player, "В бою на арене телепортироваться нельзя. Сдайтесь или победите босса.", "warn")
		return false
	end
	local zone = Zones[zoneKey]
	local part = root(player)
	if not zone or not part then
		return false
	end
	local point = WorldBuilder.zonePoint(zoneKey, 0, zone.kind == "town" and 36 or 0)
	FxService.teleport(player, function()
		part.CFrame = CFrame.new(point + Vector3.new(0, 4, 0))
	end)
	PlayerData.notify(player, "Вы перенеслись: " .. zone.name, "good")
	return true
end

function handlers.teleport(player, params)
	return flyTo(player, params.zone)
end

--- «Полёт»: пункт назначения выбирает игрок (выбор приходит параметром choice).
function handlers.fly(player, _params, choice)
	if not choice or not table.find(FLY_ZONES, choice) then
		return false
	end
	return flyTo(player, choice)
end

function handlers.reveal(player, params)
	ItemService.reveal(player, params.range, params.count, params.duration)
	return true
end

function handlers.scout(player)
	local lines = {}
	for _, other in Players:GetPlayers() do
		local profile = PlayerData.get(other)
		if other ~= player and profile and profile.inGame then
			table.insert(lines, ("%s — %d карт"):format(other.DisplayName, PlayerData.ownedNumbered(profile)))
		end
	end
	PlayerData.notify(player, #lines > 0 and ("Разведка: " .. table.concat(lines, "; ")) or "Разведка: рядом никого нет.", "info")
	return true
end

function handlers.heal(player, params)
	local human = humanoid(player)
	if not human then
		return false
	end
	human.Health = math.min(human.MaxHealth, human.Health + params.amount)
	return true
end

function handlers.groupHeal(player, params)
	local mine = root(player)
	if not mine then
		return false
	end
	for _, other in Players:GetPlayers() do
		local theirs = root(other)
		local human = humanoid(other)
		if theirs and human and (theirs.Position - mine.Position).Magnitude <= params.range then
			human.Health = math.min(human.MaxHealth, human.Health + params.amount)
		end
	end
	return true
end

function handlers.haste(player, params)
	Status.apply(player, "haste", params.duration, params.mult)
	return true
end

function handlers.jump(player, params)
	Status.apply(player, "jump", params.duration, params.power)
	return true
end

function handlers.shield(player, params)
	Status.apply(player, "shield", params.duration, params.factor)
	return true
end

function handlers.stealth(player, params)
	Status.apply(player, "stealth", params.duration)
	return true
end

function handlers.silent(player, params)
	Status.apply(player, "silent", params.duration)
	return true
end

function handlers.calm(player, params)
	Status.apply(player, "calm", params.duration)
	return true
end

function handlers.magnet(player, params)
	Status.apply(player, "magnet", params.duration, params.range)
	return true
end

function handlers.lure(player, params)
	MonsterService.lure(player, params.range, params.duration)
	return true
end

function handlers.freeze(player, params)
	local part = root(player)
	if not part then
		return false
	end
	MonsterService.freezeNear(part.Position, params.range, params.duration)
	return true
end

function handlers.blind(player, params)
	local part = root(player)
	if not part then
		return false
	end
	MonsterService.blindNear(part.Position, params.range, params.duration)
	return true
end

function handlers.rage(player, params)
	Status.apply(player, "rage", params.duration, { mult = params.mult, taken = params.taken })
	return true
end

function handlers.reflect(player, params)
	Status.apply(player, "reflect", params.duration)
	return true
end

function handlers.block(player, params)
	Status.apply(player, "block", params.duration)
	return true
end

function handlers.steal(player)
	local victim = nearestOther(player, CAST_RADIUS)
	if not victim then
		PlayerData.notify(player, "Рядом нет игроков — заклинание не сработало.", "warn")
		return false
	end
	if Status.has(victim, "block") then
		PlayerData.notify(player, "Карты этого игрока под Блокировкой.", "warn")
		return true
	end
	if not harmful(player, victim) then
		return true
	end
	local mine = PlayerData.get(player)
	local theirs = PlayerData.get(victim)
	if not mine or not theirs or #theirs.free == 0 or #mine.free >= 45 then
		PlayerData.notify(player, "Нечего красть или некуда класть.", "warn")
		return true
	end
	local index = math.random(1, #theirs.free)
	local entry = table.remove(theirs.free, index)
	table.insert(mine.free, { uid = PlayerData.nextUid(mine), id = entry.id })
	local card = Cards.get(entry.id)
	PlayerData.notify(player, "Украдено: " .. (card and card.name or "карта"), "good")
	PlayerData.notify(victim, "У вас украли карту: " .. (card and card.name or "карта"), "warn")
	PlayerData.push(player)
	PlayerData.push(victim)
	return true
end

function handlers.slow(player, params)
	local victim = nearestOther(player, params.range)
	if not victim then
		PlayerData.notify(player, "Рядом нет игроков.", "warn")
		return false
	end
	if harmful(player, victim) then
		Status.apply(victim, "slow", params.duration, 0.4)
		PlayerData.notify(victim, "На вас наложили Тяжесть.", "warn")
	end
	return true
end

function handlers.cancel(player)
	Status.clear(player)
	return true
end

function handlers.revive(player, params)
	Status.apply(player, "revive", params.duration)
	return true
end

function handlers.recall(player, params)
	Hand.extend(player, params.seconds)
	return true
end

function handlers.fortune(player, params)
	Status.apply(player, "fortune", params.duration)
	return true
end

function handlers.quick(player, params)
	Status.apply(player, "quick", params.duration)
	return true
end

function handlers.reach(player, params)
	Status.apply(player, "reach", params.duration, params.range)
	return true
end

function handlers.hpboost(player, params)
	Status.apply(player, "hpboost", params.duration, params.amount)
	local human = humanoid(player)
	if human then
		human.Health = human.MaxHealth
	end
	return true
end

--- Заклинания, где игрок сам выбирает цель (сейчас только «Полёт»).
function SpellService.needsChoice(spell: Spells.Spell): boolean
	return spell.effect == "fly"
end

type Pending = { spellId: number, ref: { slot: number?, uid: number? }, expires: number }
local pendingChoice: { [Player]: Pending } = {}

--- Показать игроку выбор; карта не тратится, пока он не выберет.
function SpellService.askChoice(player: Player, spell: Spells.Spell, ref: { slot: number?, uid: number? })
	local options = {}
	for _, key in FLY_ZONES do
		table.insert(options, { id = key, label = Zones[key].name })
	end
	pendingChoice[player] = { spellId = spell.id, ref = ref, expires = os.clock() + 60 }
	Remotes.SpellChoice:FireClient(player, { spellId = spell.id, title = spell.name .. ": куда лететь?", options = options })
end

local function onChoose(player: Player, data: any)
	if type(data) ~= "table" then
		return
	end
	local pending = pendingChoice[player]
	pendingChoice[player] = nil
	if not pending or os.clock() > pending.expires or data.spellId ~= pending.spellId or type(data.option) ~= "string" then
		return -- отмена, устаревший или подделанный выбор
	end
	require(script.Parent.Binder).gain(player, pending.ref, data.option, pending.spellId)
end

function SpellService.cast(player: Player, spell: Spells.Spell, choice: string?): boolean
	local handler = handlers[spell.effect]
	if not handler then
		return false
	end
	local cast = handler(player, spell.params, choice)
	if cast then
		if spell.effect ~= "fly" and spell.effect ~= "teleport" and spell.effect ~= "exit" then
			FxService.cast(player, spell.effect, spell.params.duration)
		end
		PlayerData.notify(player, "Заклинание «" .. spell.name .. "» сработало.", "good")
		-- запас магазина пополняется, когда заклинания используют
		require(script.Parent.ShopService).restockSpell(spell.id)
	end
	return cast
end

--- «Магнит» тянет предметы в руку, пока действует.
function SpellService.start()
	Remotes.SpellChoose.OnServerEvent:Connect(onChoose)
	Players.PlayerRemoving:Connect(function(player)
		pendingChoice[player] = nil
	end)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.5 then
			return
		end
		accumulator = 0
		for _, player in Players:GetPlayers() do
			local range = Status.get(player, "magnet")
			local part = root(player)
			if range and part then
				-- руки заняты — не пытаемся (иначе каждые полсекунды сыпались бы уведомления)
				if not Hand.isFull(player) then
					for _, node in ItemService.nodesNear(part.Position, range) do
						if not ItemService.pickup(player, node :: Part) then
							break
						end
					end
				end
			end
		end
	end)
end

--- Мелочь для текста: куда ведёт заклинание телепорта (используется клиентом через описание).
SpellService.zoneName = Util.zoneName

return SpellService
