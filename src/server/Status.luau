-- Временные эффекты (заклинания) и стойки Нен: Тен — защита, Зетсу — скрытность.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local PlayerData = require(script.Parent.PlayerData)

local Status = {}

local BASE_WALK = 16
local BASE_JUMP = 50
local BASE_HEALTH = 100

local LABELS: { [string]: string } = {
	haste = "Ускорение",
	jump = "Прыжок",
	shield = "Щит",
	stealth = "Невидимость",
	magnet = "Магнит",
	calm = "Усмирение",
	rage = "Ярость",
	reflect = "Отражение",
	block = "Блокировка",
	slow = "Тяжесть",
	revive = "Воскрешение",
	fortune = "Удача",
	quick = "Двойной удар",
	reach = "Дальний удар",
	hpboost = "Сила гиганта",
	silent = "Тихий шаг",
}

type Effect = { untilAt: number, value: any }

local effects: { [Player]: { [string]: Effect } } = {}
local stances: { [Player]: string } = {}
local stanceChangedAt: { [Player]: number } = {}

local function ensure(player: Player): { [string]: Effect }
	local list = effects[player]
	if not list then
		list = {}
		effects[player] = list
	end
	return list
end

--- Активное значение эффекта либо nil.
function Status.get(player: Player, name: string): any
	local list = effects[player]
	local effect = list and list[name]
	if effect and effect.untilAt > os.clock() then
		return effect.value
	end
	return nil
end

function Status.has(player: Player, name: string): boolean
	return Status.get(player, name) ~= nil
end

function Status.stance(player: Player): string
	return stances[player] or "none"
end

local function applyHumanoid(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local walk = BASE_WALK * (Status.get(player, "haste") or 1)
	local slow = Status.get(player, "slow")
	if slow then
		walk *= slow
	end
	humanoid.WalkSpeed = walk
	local jump = Status.get(player, "jump")
	humanoid.UseJumpPower = true
	humanoid.JumpPower = jump or BASE_JUMP
	local boost = Status.get(player, "hpboost") or 0
	local wanted = BASE_HEALTH + boost
	if humanoid.MaxHealth ~= wanted then
		local ratio = humanoid.Health / humanoid.MaxHealth
		humanoid.MaxHealth = wanted
		humanoid.Health = math.clamp(ratio * wanted, 1, wanted)
	end
end

function Status.push(player: Player)
	local list = {}
	local now = os.clock()
	for name, effect in ensure(player) do
		if effect.untilAt > now then
			table.insert(list, { name = LABELS[name] or name, seconds = math.ceil(effect.untilAt - now) })
		end
	end
	Remotes.Status:FireClient(player, { effects = list, stance = Status.stance(player) })
end

function Status.apply(player: Player, name: string, duration: number, value: any)
	ensure(player)[name] = { untilAt = os.clock() + duration, value = value == nil and true or value }
	applyHumanoid(player)
	Status.push(player)
end

function Status.remove(player: Player, name: string)
	local list = effects[player]
	if list then
		list[name] = nil
	end
	applyHumanoid(player)
	Status.push(player)
end

function Status.clear(player: Player)
	effects[player] = {}
	applyHumanoid(player)
	Status.push(player)
end

function Status.setStance(player: Player, stance: string)
	if stance ~= "ten" and stance ~= "zetsu" and stance ~= "none" then
		return
	end
	local now = os.clock()
	if now - (stanceChangedAt[player] or 0) < Config.StanceCooldown then
		return
	end
	if (stances[player] or "none") == stance then
		return
	end
	stances[player] = stance
	stanceChangedAt[player] = now
	Status.push(player)
end

--- Когда игрок в последний раз менял стойку (для пузырьковой лошади: Зетсу, затем Тен).
function Status.stanceChangedAt(player: Player): number
	return stanceChangedAt[player] or 0
end

--- Во сколько раз игрок получает больше или меньше урона от монстров.
function Status.damageTakenFactor(player: Player): number
	local factor = 1
	factor *= Status.get(player, "shield") or 1
	local rage = Status.get(player, "rage")
	if rage and type(rage) == "table" then
		factor *= rage.taken
	end
	if Status.stance(player) == "ten" then
		factor *= Config.TenDamageFactor
	end
	return factor
end

--- Множитель урона игрока по монстрам.
function Status.damageDealtFactor(player: Player): number
	local factor = 1
	local rage = Status.get(player, "rage")
	if rage and type(rage) == "table" then
		factor *= rage.mult
	end
	local profile = PlayerData.get(player)
	if profile and profile.flags.sword then
		factor *= 2
	end
	return factor
end

--- Насколько монстры замечают игрока: 0 — совсем не видят.
function Status.aggroFactor(player: Player): number
	if Status.has(player, "stealth") or Status.has(player, "silent") or Status.has(player, "calm") then
		return 0
	end
	if Status.stance(player) == "zetsu" then
		return Config.ZetsuAggroFactor
	end
	return 1
end

function Status.attackCooldown(player: Player): number
	return Config.AttackCooldown * (Status.has(player, "quick") and 0.5 or 1)
end

function Status.attackRange(player: Player): number
	return Status.get(player, "reach") or Config.AttackRange
end

function Status.start()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.5 then
			return
		end
		accumulator = 0
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local list = effects[player]
			if list then
				local changed = false
				for name, effect in list do
					if effect.untilAt <= now then
						list[name] = nil
						changed = true
					end
				end
				if changed then
					applyHumanoid(player)
				end
				if changed or next(list) ~= nil then
					Status.push(player)
				end
			end
		end
	end)

	Remotes.Stance.OnServerEvent:Connect(function(player, stance)
		if type(stance) == "string" then
			Status.setStance(player, stance)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		effects[player] = nil
		stances[player] = nil
		stanceChangedAt[player] = nil
	end)
end

--- Вызывается при каждом появлении персонажа: эффекты сбрасываются, стойка снимается.
function Status.onSpawn(player: Player)
	effects[player] = {}
	stances[player] = "none"
	applyHumanoid(player)
	Status.push(player)
end

return Status
