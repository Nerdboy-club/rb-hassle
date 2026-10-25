-- Арены редких боссов: у каждой группы своя копия босса на отдельной площадке высоко над островом.
-- Вход через портал в мире: соло, группа друзей (создаёт и запускает хозяин) или очередь со случайными игроками.
-- Добыча делится по вкладу в урон (см. MonsterService.distribute); во время боя уйти можно только сдавшись.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Cards)
local Config = require(Shared.Config)
local Monsters = require(Shared.Monsters)
local Remotes = require(Shared.Remotes)

local CardRegistry = require(script.Parent.CardRegistry)
local FxService = require(script.Parent.FxService)
local MonsterService = require(script.Parent.MonsterService)
local PlayerData = require(script.Parent.PlayerData)
local WorldBuilder = require(script.Parent.WorldBuilder)

local ArenaService = {}

local PORTAL_RADIUS = 14 -- на таком расстоянии от портала можно создавать и вступать в группы
local ENTRY_GRACE = 45 -- студов: дальше от портала участник группы к бою не допускается
local WIN_DELAY = 8 -- секунд на радость победителям, потом возвращение

type Fight = {
	id: number,
	bossKey: string,
	slot: number,
	center: Vector3,
	members: { Player },
	allowed: { [Player]: boolean },
	boss: any,
	deadline: number,
	state: string, -- "fight" | "won" | "over"
}

type Party = {
	id: number,
	bossKey: string,
	host: Player,
	members: { Player },
}

type QueueEntry = {
	player: Player,
	size: number,
	since: number,
}

local bossKeys: { string } = {}
local portals: { [string]: { position: Vector3, anchor: Part } } = {}
local slotBusy: { [string]: { boolean } } = {}
local fights: { [number]: Fight } = {}
local parties: { [number]: Party } = {}
local partyOf: { [Player]: Party } = {}
local queues: { [string]: { QueueEntry } } = {}
local queuedBoss: { [Player]: string } = {}
local inFight: { [Player]: Fight } = {}
local viewers: { [Player]: string } = {} -- у кого открыто меню арены и какого босса
local cooldownUntil: { [Player]: number } = {}
local lastAction: { [Player]: number } = {}
local nextFightId = 0
local nextPartyId = 0
local arenasFolder: Folder

local function center(bossIndex: number, slot: number): Vector3
	return Vector3.new(-2400 + (bossIndex - 1) * 400, Config.ArenaY, -2400 + (slot - 1) * 300)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root :: BasePart or nil
end

local function alive(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0 and rootOf(player) ~= nil
end

local function inGame(player: Player): boolean
	local profile = PlayerData.get(player)
	return profile ~= nil and profile.inGame
end

local function bossCard(bossKey: string): Cards.Card?
	local def = Monsters[bossKey]
	return Cards.withSource("m", def.drop)[1]
end

--- Можно ли сейчас получить карту босса (лимит копий на сервере не исчерпан).
local function bossAvailable(bossKey: string): (boolean, string?)
	local card = bossCard(bossKey)
	if card and not CardRegistry.canMint(card.id) then
		return false, ("Все копии карты «%s» уже у игроков. Босс появится, когда одна из них освободится."):format(card.name)
	end
	return true, nil
end

local function freeSlots(bossKey: string): number
	local free = 0
	for _, busy in slotBusy[bossKey] do
		if not busy then
			free += 1
		end
	end
	return free
end

local function notify(player: Player, text: string, kind: string?)
	PlayerData.notify(player, text, kind or "info")
end

-- ===================== меню =====================

local function partySnapshot(party: Party)
	local names = {}
	for _, member in party.members do
		table.insert(names, member.DisplayName)
	end
	return { id = party.id, host = party.host.DisplayName, hostId = party.host.UserId, members = names }
end

local function buildMenu(player: Player, bossKey: string)
	local def = Monsters[bossKey]
	local card = bossCard(bossKey)
	local available, reason = bossAvailable(bossKey)
	local myParty = partyOf[player]
	local queueCounts = { [2] = 0, [3] = 0, [4] = 0 }
	for _, entry in queues[bossKey] do
		queueCounts[entry.size] = (queueCounts[entry.size] or 0) + 1
	end
	local list = {}
	for _, party in parties do
		if party.bossKey == bossKey then
			table.insert(list, partySnapshot(party))
		end
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	return {
		bossKey = bossKey,
		bossName = def.name,
		cardName = card and card.name or nil,
		cardRank = card and card.rank or nil,
		available = available,
		reason = reason,
		freeSlots = freeSlots(bossKey),
		party = myParty and myParty.bossKey == bossKey and partySnapshot(myParty) or nil,
		isHost = myParty ~= nil and myParty.host == player,
		queued = queuedBoss[player] == bossKey and (function()
			for _, entry in queues[bossKey] do
				if entry.player == player then
					return entry.size
				end
			end
			return nil
		end)() or nil,
		queueCounts = queueCounts,
		parties = list,
		maxParty = Config.ArenaMaxParty,
		scale = Config.ArenaHpScale,
		cooldown = math.max(0, math.ceil((cooldownUntil[player] or 0) - os.clock())),
		busy = inFight[player] ~= nil,
	}
end

local function sendMenu(player: Player, bossKey: string)
	viewers[player] = bossKey
	Remotes.ArenaMenu:FireClient(player, buildMenu(player, bossKey))
end

local function refreshViewers(bossKey: string)
	for player, key in viewers do
		if key == bossKey and player.Parent then
			Remotes.ArenaMenu:FireClient(player, buildMenu(player, bossKey))
		end
	end
end

local function closeMenu(player: Player)
	if viewers[player] then
		viewers[player] = nil
		if player.Parent then
			Remotes.ArenaMenu:FireClient(player, { close = true })
		end
	end
end

-- ===================== группы и очередь =====================

local function removeFromQueue(player: Player)
	local bossKey = queuedBoss[player]
	if not bossKey then
		return
	end
	queuedBoss[player] = nil
	local list = queues[bossKey]
	for index = #list, 1, -1 do
		if list[index].player == player then
			table.remove(list, index)
		end
	end
	refreshViewers(bossKey)
end

local function leaveParty(player: Player, quiet: boolean?)
	local party = partyOf[player]
	if not party then
		return
	end
	local bossKey = party.bossKey
	if party.host == player then
		-- хозяин ушёл: группа распускается
		for _, member in party.members do
			partyOf[member] = nil
			if member ~= player and not quiet and member.Parent then
				notify(member, "Хозяин покинул группу — она распущена.", "warn")
			end
		end
		parties[party.id] = nil
	else
		partyOf[player] = nil
		local index = table.find(party.members, player)
		if index then
			table.remove(party.members, index)
		end
		if not quiet and party.host.Parent then
			notify(party.host, player.DisplayName .. " вышел из группы.", "info")
		end
	end
	refreshViewers(bossKey)
end

-- ===================== площадки =====================

local BOSS_COLORS: { [string]: Color3 } = {
	KingBeetle = Color3.fromRGB(70, 130, 70),
	WolfAlpha = Color3.fromRGB(70, 80, 120),
	Melanin = Color3.fromRGB(110, 70, 140),
}

local function buildArena(bossKey: string, bossIndex: number, slot: number)
	local middle = center(bossIndex, slot)
	local radius = Config.ArenaRadius
	local color = BOSS_COLORS[bossKey] or Color3.fromRGB(90, 90, 100)
	local model = Instance.new("Model")
	model.Name = ("Arena_%s_%d"):format(bossKey, slot)

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Shape = Enum.PartType.Cylinder
	floor.Size = Vector3.new(4, radius * 2, radius * 2)
	floor.CFrame = CFrame.new(middle - Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	floor.Color = color:Lerp(Color3.fromRGB(200, 200, 200), 0.25)
	floor.Material = Enum.Material.Slate
	floor.TopSurface = Enum.SurfaceType.Smooth
	floor.Parent = model

	-- прозрачная стена по кругу: убежать с арены нельзя
	local segments = 28
	local wallWidth = 2 * math.pi * (radius + 1) / segments + 1
	for index = 1, segments do
		local angle = index / segments * math.pi * 2
		local position = middle + Vector3.new(math.cos(angle) * (radius + 1), 35, math.sin(angle) * (radius + 1))
		local wall = Instance.new("Part")
		wall.Name = "Wall"
		wall.Anchored = true
		wall.Size = Vector3.new(2, 70, wallWidth)
		wall.CFrame = CFrame.lookAt(position, Vector3.new(middle.X, position.Y, middle.Z)) * CFrame.Angles(0, math.pi / 2, 0)
		wall.Material = Enum.Material.ForceField
		wall.Color = color
		wall.Transparency = 0.7
		wall.CanQuery = false
		wall.CastShadow = false
		wall.Parent = model
	end
	model.Parent = arenasFolder
end

local function buildPortal(bossKey: string)
	local def = Monsters[bossKey]
	local spec = def.arena
	if not spec then
		return
	end
	local base = WorldBuilder.zonePoint(spec.zone, spec.dx, spec.dz)
	local color = BOSS_COLORS[bossKey] or Color3.fromRGB(150, 150, 170)

	local ring = Instance.new("Part")
	ring.Name = "PortalRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.6, 14, 14)
	ring.CFrame = CFrame.new(base + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Color = color:Lerp(Color3.fromRGB(255, 255, 255), 0.35)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.25
	ring.Parent = arenasFolder

	for side = -1, 1, 2 do
		local pillar = Instance.new("Part")
		pillar.Name = "PortalPillar"
		pillar.Anchored = true
		pillar.Size = Vector3.new(2, 12, 2)
		pillar.CFrame = CFrame.new(base + Vector3.new(side * 6.5, 6, 0))
		pillar.Color = Color3.fromRGB(70, 72, 84)
		pillar.Material = Enum.Material.Slate
		pillar.Parent = arenasFolder
	end

	local anchor = Instance.new("Part")
	anchor.Name = "Portal_" .. bossKey
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(3, 3, 3)
	anchor.Position = base + Vector3.new(0, 3, 0)
	anchor.Parent = arenasFolder

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(300, 54)
	gui.StudsOffset = Vector3.new(0, 9, 0)
	gui.MaxDistance = 260
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	label.BackgroundTransparency = 0.25
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = ("Арена: %s"):format(def.name)
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2
	stroke.Parent = label

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Войти в арену"
	prompt.ObjectText = def.name
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player)
		if not inGame(player) then
			return
		end
		if inFight[player] then
			notify(player, "Вы уже в бою.", "warn")
			return
		end
		sendMenu(player, bossKey)
	end)

	portals[bossKey] = { position = base, anchor = anchor }
end

-- ===================== бой =====================

local function sendStatus(player: Player, fight: Fight?)
	if not player.Parent then
		return
	end
	if not fight or fight.state == "over" then
		Remotes.ArenaStatus:FireClient(player, { active = false })
		return
	end
	local names = {}
	for _, member in fight.members do
		table.insert(names, member.DisplayName)
	end
	Remotes.ArenaStatus:FireClient(player, {
		active = true,
		boss = Monsters[fight.bossKey].name,
		seconds = math.max(0, math.ceil(fight.deadline - os.clock())),
		members = names,
		won = fight.state == "won",
	})
end

local function returnPoint(bossKey: string): Vector3
	local portal = portals[bossKey]
	local base = portal and portal.position or WorldBuilder.zonePoint("Shiso", 0, 42)
	return base + Vector3.new(0, 4, 12)
end

--- Игрок покидает бой: сдался, погиб, ушёл из игры или бой закончился. Если жив — возвращается к порталу.
local function removeFromFight(player: Player, reason: string)
	local fight = inFight[player]
	if not fight then
		return
	end
	inFight[player] = nil
	fight.allowed[player] = nil
	local index = table.find(fight.members, player)
	if index then
		table.remove(fight.members, index)
	end

	if reason ~= "won" then
		cooldownUntil[player] = os.clock() + Config.ArenaCooldownSeconds
	end
	if player.Parent then
		sendStatus(player, nil)
		local root = rootOf(player)
		if reason ~= "died" and reason ~= "gone" and root and alive(player) then
			FxService.teleport(player, function()
				root.CFrame = CFrame.new(returnPoint(fight.bossKey))
			end)
		end
		if reason == "surrender" then
			notify(player, "Вы сдались. Босс сбросился — войти снова можно через полминуты.", "warn")
		elseif reason == "died" then
			notify(player, "Вы погибли в бою и выбыли из арены.", "warn")
		elseif reason == "timeout" then
			notify(player, "Время вышло — босс не побеждён. Возвращение к порталу.", "warn")
		end
	end
end

local function finishFight(fight: Fight, reason: string)
	if fight.state == "over" then
		return
	end
	fight.state = "over"
	local boss = fight.boss
	if boss then
		for _, follower in boss.followers do
			MonsterService.despawn(follower)
		end
		MonsterService.despawn(boss)
	end
	for index = #fight.members, 1, -1 do
		removeFromFight(fight.members[index], reason)
	end
	slotBusy[fight.bossKey][fight.slot] = false
	fights[fight.id] = nil
	refreshViewers(fight.bossKey)
end

local function onBossDefeated(fight: Fight)
	if fight.state ~= "fight" then
		return
	end
	fight.state = "won"
	-- стая вожака исчезает вместе с ним
	local boss = fight.boss
	if boss then
		for _, follower in boss.followers do
			MonsterService.despawn(follower)
		end
	end
	for _, member in fight.members do
		notify(member, ("Босс повержен! Возвращение через %d секунд."):format(WIN_DELAY), "good")
		sendStatus(member, fight)
	end
	task.delay(WIN_DELAY, function()
		finishFight(fight, "won")
	end)
end

--- Проверка и запуск боя для списка игроков. Возвращает true, если бой начался.
local function startFight(bossKey: string, candidates: { Player }, requireNearPortal: boolean): boolean
	local def = Monsters[bossKey]
	local portal = portals[bossKey]
	local members: { Player } = {}
	for _, player in candidates do
		local reasonText: string? = nil
		if not player.Parent or not inGame(player) or not alive(player) then
			reasonText = "вы не в игре или погибли"
		elseif inFight[player] then
			reasonText = "вы уже в бою"
		elseif (cooldownUntil[player] or 0) > os.clock() then
			reasonText = ("подождите ещё %d с после прошлого боя"):format(math.ceil((cooldownUntil[player] :: number) - os.clock()))
		elseif requireNearPortal and portal then
			local root = rootOf(player)
			if not root or (root.Position - portal.position).Magnitude > ENTRY_GRACE then
				reasonText = "вы отошли от портала"
			end
		end
		if reasonText then
			if player.Parent then
				notify(player, "Вход в арену не удался: " .. reasonText .. ".", "warn")
			end
		else
			table.insert(members, player)
		end
	end
	if #members == 0 then
		return false
	end
	local available, reason = bossAvailable(bossKey)
	if not available then
		for _, player in members do
			notify(player, reason or "Босс сейчас недоступен.", "warn")
		end
		return false
	end

	local slot: number? = nil
	for index, busy in slotBusy[bossKey] do
		if not busy then
			slot = index
			break
		end
	end
	if not slot then
		for _, player in members do
			notify(player, "Все арены этого босса заняты. Подождите немного и попробуйте снова.", "warn")
		end
		return false
	end

	local bossIndex = table.find(bossKeys, bossKey) :: number
	local middle = center(bossIndex, slot)
	nextFightId += 1
	local size = #members
	local scale = Config.ArenaHpScale[math.min(size, #Config.ArenaHpScale)]
	local fight: Fight = {
		id = nextFightId,
		bossKey = bossKey,
		slot = slot,
		center = middle,
		members = members,
		allowed = {},
		boss = nil,
		deadline = os.clock() + Config.ArenaSeconds,
		state = "fight",
	}
	slotBusy[bossKey][slot] = true
	fights[fight.id] = fight

	for index, player in members do
		fight.allowed[player] = true
		inFight[player] = fight
		leaveParty(player, true)
		removeFromQueue(player)
		closeMenu(player)
		-- участники стоят по кругу лицом к центру
		local angle = (index - 1) / size * math.pi * 2 + math.pi / 2
		local position = middle + Vector3.new(math.cos(angle) * 34, 5, math.sin(angle) * 34)
		local root = rootOf(player)
		if root then
			FxService.teleport(player, function()
				root.CFrame = CFrame.lookAt(position, Vector3.new(middle.X, position.Y, middle.Z))
			end)
		end
	end

	fight.boss = MonsterService.spawnBoss(bossKey, middle, {
		groundY = Config.ArenaY,
		allowed = fight.allowed,
		hpScale = scale,
		treeNeed = 4 + (size - 1),
		arena = fight,
		onDefeated = function()
			onBossDefeated(fight)
		end,
	})

	local minutes = math.floor(Config.ArenaSeconds / 60)
	for _, player in members do
		notify(player, ("Бой с боссом «%s» начался! Время: %d мин. Добыча делится по вкладу в урон, последний удар даёт бонус. Сдаться можно кнопкой сверху."):format(def.name, minutes), "good")
		sendStatus(player, fight)
	end
	refreshViewers(bossKey)
	return true
end

-- ===================== действия игрока =====================

local function handleAction(player: Player, data: any)
	if typeof(data) ~= "table" or typeof(data.action) ~= "string" then
		return
	end
	local action = data.action
	local now = os.clock()
	if now - (lastAction[player] or 0) < 0.15 then
		return -- ограничение частоты команд
	end
	lastAction[player] = now
	if action == "surrender" then
		local fight = inFight[player]
		removeFromFight(player, "surrender")
		if fight and #fight.members == 0 then
			finishFight(fight, "empty")
		end
		return
	end
	if action == "close" then
		closeMenu(player)
		return
	end

	local bossKey = viewers[player]
	if not bossKey or not portals[bossKey] then
		return -- меню не открыто — команды игнорируем
	end
	local portal = portals[bossKey]
	local root = rootOf(player)
	if not root or (root.Position - portal.position).Magnitude > PORTAL_RADIUS + 6 or not inGame(player) then
		closeMenu(player)
		return
	end
	if inFight[player] then
		return
	end

	if action == "solo" then
		if partyOf[player] or queuedBoss[player] then
			notify(player, "Сначала выйдите из группы или очереди.", "warn")
			return
		end
		startFight(bossKey, { player }, false)
	elseif action == "create" then
		if partyOf[player] or queuedBoss[player] then
			return
		end
		nextPartyId += 1
		local party: Party = { id = nextPartyId, bossKey = bossKey, host = player, members = { player } }
		parties[party.id] = party
		partyOf[player] = party
		refreshViewers(bossKey)
	elseif action == "join" then
		local party = typeof(data.id) == "number" and parties[data.id] or nil
		if not party or party.bossKey ~= bossKey or partyOf[player] or queuedBoss[player] then
			return
		end
		if #party.members >= Config.ArenaMaxParty then
			notify(player, "Группа уже полная.", "warn")
			return
		end
		table.insert(party.members, player)
		partyOf[player] = party
		notify(party.host, player.DisplayName .. " вступил в группу.", "good")
		refreshViewers(bossKey)
	elseif action == "leave" then
		leaveParty(player)
		removeFromQueue(player)
		sendMenu(player, bossKey)
	elseif action == "start" then
		local party = partyOf[player]
		if not party or party.host ~= player or party.bossKey ~= bossKey then
			return
		end
		local list = table.clone(party.members)
		if not startFight(bossKey, list, true) then
			refreshViewers(bossKey)
		end
	elseif action == "queue" then
		local size = data.size
		if typeof(size) ~= "number" or size < 2 or size > Config.ArenaMaxParty or size ~= math.floor(size) then
			return
		end
		if partyOf[player] or queuedBoss[player] then
			return
		end
		local available, reason = bossAvailable(bossKey)
		if not available then
			notify(player, reason or "Босс недоступен.", "warn")
			return
		end
		table.insert(queues[bossKey], { player = player, size = size, since = os.clock() })
		queuedBoss[player] = bossKey
		-- набралось нужное число — бой начинается сразу
		local group: { Player } = {}
		for _, entry in queues[bossKey] do
			if entry.size == size and #group < size then
				table.insert(group, entry.player)
			end
		end
		if #group >= size then
			startFight(bossKey, group, true)
		end
		refreshViewers(bossKey)
	elseif action == "unqueue" then
		removeFromQueue(player)
		sendMenu(player, bossKey)
	end
end

--- Раз в секунду: таймеры боёв, очередь, меню у игроков, ушедших от портала.
local function tick()
	local now = os.clock()
	for _, fight in table.clone(fights) do
		if fight.state == "fight" then
			if now >= fight.deadline then
				finishFight(fight, "timeout")
			else
				for _, member in table.clone(fight.members) do
					if not member.Parent or not inGame(member) then
						removeFromFight(member, "gone")
					elseif not alive(member) then
						removeFromFight(member, "died")
					else
						sendStatus(member, fight)
					end
				end
				if #fight.members == 0 then
					finishFight(fight, "empty")
				end
			end
		end
	end

	-- очередь: по истечении ожидания стартуем с теми, кто есть (если хотя бы двое)
	for bossKey, list in queues do
		local sizes: { [number]: { QueueEntry } } = {}
		for _, entry in list do
			sizes[entry.size] = sizes[entry.size] or {}
			table.insert(sizes[entry.size], entry)
		end
		for size, entries in sizes do
			local oldest = entries[1]
			for _, entry in entries do
				if entry.since < oldest.since then
					oldest = entry
				end
			end
			if now - oldest.since >= Config.ArenaQueueSeconds then
				local group: { Player } = {}
				for _, entry in entries do
					if #group < size then
						table.insert(group, entry.player)
					end
				end
				if #group >= 2 then
					startFight(bossKey, group, true)
				else
					for _, entry in entries do
						removeFromQueue(entry.player)
						notify(entry.player, "Случайных игроков не нашлось. Можно войти соло или собрать группу друзей.", "info")
						if entry.player.Parent then
							sendMenu(entry.player, bossKey)
						end
					end
				end
			end
		end
	end

	-- закрываем меню, если игрок ушёл от портала; очередь и группы без игрока не копим
	for player, bossKey in table.clone(viewers) do
		local portal = portals[bossKey]
		local root = rootOf(player)
		if not player.Parent or not portal or not root or (root.Position - portal.position).Magnitude > PORTAL_RADIUS + 8 then
			closeMenu(player)
		end
	end
	for player, bossKey in table.clone(queuedBoss) do
		local portal = portals[bossKey]
		local root = rootOf(player)
		if not player.Parent or not inGame(player) or not portal or not root or (root.Position - portal.position).Magnitude > ENTRY_GRACE then
			removeFromQueue(player)
			if player.Parent then
				notify(player, "Вы отошли от портала — очередь отменена.", "info")
			end
		end
	end
end

-- ===================== хуки для других сервисов =====================

function ArenaService.isBusy(player: Player): boolean
	return inFight[player] ~= nil
end

--- Игрок выходит из игры или из сервера: убрать из боя, группы и очереди.
function ArenaService.leave(player: Player)
	leaveParty(player, true)
	removeFromQueue(player)
	closeMenu(player)
	if inFight[player] then
		removeFromFight(player, player.Parent and "left" or "gone")
	end
end

function ArenaService.start()
	arenasFolder = Instance.new("Folder")
	arenasFolder.Name = "Arenas"
	arenasFolder.Parent = workspace

	for key, def in Monsters do
		if def.arena then
			table.insert(bossKeys, key)
		end
	end
	table.sort(bossKeys)

	for bossIndex, key in bossKeys do
		slotBusy[key] = {}
		queues[key] = {}
		for slot = 1, Config.ArenaSlotsPerBoss do
			slotBusy[key][slot] = false
			buildArena(key, bossIndex, slot)
		end
		buildPortal(key)
	end

	Remotes.ArenaAction.OnServerEvent:Connect(handleAction)

	local function watch(player: Player)
		local function onCharacter(character: Model)
			local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
			if humanoid then
				humanoid.Died:Connect(function()
					if inFight[player] then
						removeFromFight(player, "died")
					end
				end)
			end
		end
		player.CharacterAdded:Connect(onCharacter)
		if player.Character then
			task.spawn(onCharacter, player.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		ArenaService.leave(player)
		cooldownUntil[player] = nil
		viewers[player] = nil
		lastAction[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(tick)
			if not ok then
				warn("[ArenaService] tick: " .. tostring(err))
			end
		end
	end)
end

return ArenaService
