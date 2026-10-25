-- Жизненный цикл игрока: лобби («реальный мир») → вход в игру → остров → выход / победа.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Cards = require(Shared.Cards)
local Ranks = require(Shared.Ranks)
local Remotes = require(Shared.Remotes)

local Hand = require(script.Parent.Hand)
local PlayerData = require(script.Parent.PlayerData)
local Status = require(script.Parent.Status)
local WorldBuilder = require(script.Parent.WorldBuilder)

local GameService = {}

local VOID_Y = -60
local metTimers: { [Player]: { [Player]: number } } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root :: BasePart or nil
end

local function teleport(player: Player, spawn: SpawnLocation?)
	local root = rootOf(player)
	if root and spawn then
		root.CFrame = spawn.CFrame + Vector3.new(0, 5, 0)
	end
end

--- Карты футляра на три слота: три самые редкие из книги (ранги по порядку SS → H).
local function chooseCase(profile: PlayerData.Profile)
	local rankIndex: { [string]: number } = {}
	for index, rank in Ranks.order do
		rankIndex[rank] = index
	end
	local owned = {}
	for id in profile.slots do
		table.insert(owned, id)
	end
	table.sort(owned, function(a, b)
		local ra = rankIndex[(Cards.get(a) :: Cards.Card).rank]
		local rb = rankIndex[(Cards.get(b) :: Cards.Card).rank]
		if ra ~= rb then
			return ra < rb
		end
		return a < b
	end)
	profile.case = {}
	for index = 1, math.min(Config.CaseSlots, #owned) do
		table.insert(profile.case, owned[index])
	end
end

--- На острове персонаж «стоит» на единой высоте мира (террейн + groundLift), а не в текстуре земли.
local function setLift(humanoid: Humanoid, on: boolean)
	local base = humanoid:GetAttribute("BaseHipHeight")
	if base == nil then
		base = humanoid.HipHeight
		humanoid:SetAttribute("BaseHipHeight", base)
	end
	humanoid.HipHeight = (base :: number) + (on and WorldBuilder.groundLift or 0)
end

function GameService.enterGame(player: Player)
	local profile = PlayerData.get(player)
	if not profile or profile.inGame then
		return
	end
	profile.inGame = true
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		setLift(humanoid, true)
	end
	if RunService:IsStudio() and Config.DevGiveAllSpells then
		local owned = {}
		for _, entry in profile.free do
			owned[entry.id] = true
		end
		local Binder = require(script.Parent.Binder)
		for _, id in Cards.spellIds do
			if not owned[id] then
				Binder.grant(player, id)
			end
		end
	end
	player.RespawnLocation = WorldBuilder.spawnPad
	teleport(player, WorldBuilder.spawnPad)
	Remotes.Phase:FireClient(player, profile.won and "win" or "game")
	PlayerData.notify(player, "Вы вошли в Greed Island. Найдите Эту у Дерева Шисо.", "good")
	PlayerData.push(player)
end

function GameService.exitGame(player: Player)
	local profile = PlayerData.get(player)
	if not profile or not profile.inGame then
		return
	end
	Hand.dropAll(player)
	Status.clear(player)
	require(script.Parent.ArenaService).leave(player)
	profile.inGame = false
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		setLift(humanoid, false)
	end
	if profile.won then
		chooseCase(profile)
	end
	player.RespawnLocation = WorldBuilder.lobbySpawn
	teleport(player, WorldBuilder.lobbySpawn)
	Remotes.Phase:FireClient(player, "lobby")
	if profile.won then
		PlayerData.notify(player, "Вы вышли из игры победителем. В футляре на три слота — три самые редкие карты.", "good")
	else
		PlayerData.notify(player, "Вы вышли из игры. Карты в книге сохранены; вернуться можно через JoyStation.", "info")
	end
	PlayerData.push(player)
	PlayerData.save(player)
end

--- Все 100 слотов заполнены.
function GameService.onComplete(player: Player)
	local profile = PlayerData.get(player)
	if not profile or profile.won then
		return
	end
	profile.won = true
	Remotes.Phase:FireClient(player, "win")
	PlayerData.notify(player, "Все 100 слотов заполнены! Вы прошли Greed Island. Выход — в башне Елены.", "good")
	PlayerData.push(player)
	PlayerData.save(player)
end

local function onCharacter(player: Player, character: Model)
	Status.onSpawn(player)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	local early = PlayerData.get(player)
	if early and early.inGame then
		setLift(humanoid, true)
	end
	humanoid.Died:Connect(function()
		local profile = PlayerData.get(player)
		if profile and profile.inGame then
			if Status.has(player, "revive") then
				PlayerData.notify(player, "Воскрешение сохранило карты в руке.", "good")
			else
				Hand.dropAll(player)
			end
		end
	end)
end

local function onPlayerAdded(player: Player)
	player.RespawnLocation = WorldBuilder.lobbySpawn
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end

	-- страховка: если персонаж почему-то не появился сам, загружаем его вручную
	task.delay(3, function()
		if player.Parent and not player.Character then
			warn("[GameService] персонаж не появился сам — загружаю вручную:", player.Name)
			player:LoadCharacter()
		end
	end)

	local profile = PlayerData.load(player)
	Remotes.Phase:FireClient(player, "lobby")
	if profile then
		PlayerData.push(player)
	end
end

local function trackMet(dt: number)
	local active = {}
	for _, player in Players:GetPlayers() do
		local profile = PlayerData.get(player)
		if profile and profile.inGame and rootOf(player) then
			table.insert(active, player)
		end
	end
	for index, first in active do
		for other = index + 1, #active do
			local second = active[other]
			local a = (rootOf(first) :: BasePart).Position
			local b = (rootOf(second) :: BasePart).Position
			if (a - b).Magnitude <= Config.MetRadius then
				metTimers[first] = metTimers[first] or {}
				metTimers[first][second] = (metTimers[first][second] or 0) + dt
				if metTimers[first][second] >= Config.MetSeconds then
					local pa = PlayerData.get(first) :: PlayerData.Profile
					local pb = PlayerData.get(second) :: PlayerData.Profile
					local changed = false
					if not pa.met[second.DisplayName] then
						pa.met[second.DisplayName] = true
						changed = true
					end
					if not pb.met[first.DisplayName] then
						pb.met[first.DisplayName] = true
						PlayerData.push(second)
					end
					if changed then
						PlayerData.push(first)
					end
				end
			else
				if metTimers[first] then
					metTimers[first][second] = nil
				end
			end
		end
	end
end

function GameService.start()
	Players.RespawnTime = Config.RespawnSeconds

	local joy = WorldBuilder.joyPrompt
	if joy then
		joy.Triggered:Connect(function(player)
			GameService.enterGame(player)
		end)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- Studio: бесконечные йены для проверки лавок, образов и заклинаний
	if RunService:IsStudio() and Config.DevInfiniteYen then
		task.spawn(function()
			while true do
				task.wait(1)
				for _, player in Players:GetPlayers() do
					local profile = PlayerData.get(player)
					if profile and profile.yen < 50000000 then
						profile.yen = 99999999
						PlayerData.push(player)
					end
				end
			end
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		local profile = PlayerData.get(player)
		if profile then
			-- карты заклинаний остаются в сохранённой книге игрока, поэтому в запас магазина их не возвращаем
			Hand.dropAll(player)
			PlayerData.save(player)
		end
		PlayerData.unload(player)
		metTimers[player] = nil
		for _, timers in metTimers do
			timers[player] = nil
		end
	end)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			PlayerData.save(player)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.AutosaveSeconds)
			for _, player in Players:GetPlayers() do
				PlayerData.save(player)
			end
		end
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 1 then
			return
		end
		local elapsed = accumulator
		accumulator = 0
		trackMet(elapsed)
		for _, player in Players:GetPlayers() do
			local root = rootOf(player)
			if root and root.Position.Y < VOID_Y then
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.Health = 0
				end
			end
		end
	end)
end

return GameService
