-- Монстры острова: сборка из частей, простой ИИ, получение карты при поимке.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Cards)
local Monsters = require(Shared.Monsters)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)

local CardRegistry = require(script.Parent.CardRegistry)
local PlayerData = require(script.Parent.PlayerData)
local Hand = require(script.Parent.Hand)
local Status = require(script.Parent.Status)
local WorldBuilder = require(script.Parent.WorldBuilder)

local MonsterService = {}

local TICK = 0.1
local TREE_HITS = 4
local TREE_WINDOW = 2.5
local BODY_ATTACK_COOLDOWN = 1.2

type Mon = {
	key: string,
	def: Monsters.Monster,
	model: Model,
	root: Part,
	bar: Frame,
	hp: number,
	alive: boolean,
	home: Vector3,
	position: Vector3,
	heading: number,
	target: Player?,
	targetUntil: number,
	nextAttack: number,
	wanderTo: Vector3?,
	wanderAt: number,
	frozenUntil: number,
	blindUntil: number,
	faintUntil: number,
	calmProgress: number,
	calmedUntil: number,
	hits: { number },
	leader: Mon?,
	followers: { Mon },
}

local active: { Mon } = {}
local byPart: { [Instance]: Mon } = {}
local folder: Folder
local rng = Random.new()
local nextId = 0

local function groundParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { workspace:WaitForChild("World") }
	return params
end

local params: RaycastParams

local function groundAt(x: number, z: number): number
	local hit = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), params)
	return hit and hit.Position.Y or 0
end

local function buildModel(def: Monsters.Monster, key: string): (Model, Part, Frame)
	local model = Instance.new("Model")
	model.Name = def.name

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.Parent = model
	model.PrimaryPart = root

	local top = 0
	for _, spec in def.parts do
		local part = Instance.new("Part")
		part.Name = spec.name
		part.Size = spec.size
		part.Color = spec.color
		part.Material = spec.material or Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if spec.shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		elseif spec.shape == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		end
		part.CFrame = CFrame.new(spec.offset)
		if spec.shape == "Cylinder" then
			-- ось цилиндра у Roblox — X; вертикальный ствол поворачиваем
			part.CFrame = CFrame.new(spec.offset) * CFrame.Angles(0, 0, math.pi / 2)
		end
		part:SetAttribute("Monster", true)
		part.Parent = model
		top = math.max(top, spec.offset.Y + spec.size.Y / 2)
	end

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(90, 22)
	gui.StudsOffset = Vector3.new(0, top + 3, 0)
	gui.MaxDistance = 90
	gui.Adornee = root
	gui.Parent = root

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 12)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.4
	label.Font = Enum.Font.GothamBold
	label.TextSize = 11
	label.Text = def.name
	label.Parent = gui

	local back = Instance.new("Frame")
	back.Position = UDim2.new(0, 0, 0, 14)
	back.Size = UDim2.new(1, 0, 0, 6)
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
	back.BorderSizePixel = 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(110, 220, 120)
	fill.BorderSizePixel = 0
	fill.Parent = back
	if key == "KingBeetle" then
		back.Visible = false -- жук падает не от урона, а от серии сильных ударов
	end
	return model, root, fill
end

local function place(mon: Mon)
	local ground = groundAt(mon.position.X, mon.position.Z)
	mon.position = Vector3.new(mon.position.X, ground, mon.position.Z)
	local faint = os.clock() < mon.faintUntil
	local rollAngle = faint and math.pi / 2 or 0
	mon.model:PivotTo(CFrame.new(mon.position) * CFrame.Angles(0, mon.heading, rollAngle))
end

local function register(mon: Mon)
	table.insert(active, mon)
	for _, descendant in mon.model:GetDescendants() do
		if descendant:IsA("BasePart") then
			byPart[descendant] = mon
		end
	end
end

local function spawnMonster(key: string, position: Vector3, leader: Mon?): Mon
	local def = Monsters[key]
	local model, root, fill = buildModel(def, key)
	nextId += 1
	model:SetAttribute("MonsterId", nextId)
	local mon: Mon = {
		key = key,
		def = def,
		model = model,
		root = root,
		bar = fill,
		hp = def.hp,
		alive = true,
		home = position,
		position = position,
		heading = rng:NextNumber(0, math.pi * 2),
		target = nil,
		targetUntil = 0,
		nextAttack = 0,
		wanderTo = nil,
		wanderAt = 0,
		frozenUntil = 0,
		blindUntil = 0,
		faintUntil = 0,
		calmProgress = 0,
		calmedUntil = 0,
		hits = {},
		leader = leader,
		followers = {},
	}
	place(mon)
	model.Parent = folder
	register(mon)
	return mon
end

local function spawnAt(key: string): Mon?
	local def = Monsters[key]
	local point = Vector3.zero
	for _ = 1, 30 do
		local candidate = Util.randomPointIn(def.zone, rng)
		point = Vector3.new(candidate.X, groundAt(candidate.X, candidate.Z), candidate.Z)
		if point.Y > -0.5 and WorldBuilder.isFree(point + Vector3.new(0, 2, 0), 5) then
			break
		end
	end
	local mon = spawnMonster(key, point, nil)
	if def.pack then
		for _ = 1, def.pack.count do
			local offset = Vector3.new(rng:NextNumber(-10, 10), 0, rng:NextNumber(-10, 10))
			local member = spawnMonster(def.pack.member, point + offset, mon)
			table.insert(mon.followers, member)
		end
	end
	return mon
end

local function remove(mon: Mon)
	mon.alive = false
	for _, descendant in mon.model:GetDescendants() do
		byPart[descendant] = nil
	end
	mon.model:Destroy()
	local index = table.find(active, mon)
	if index then
		table.remove(active, index)
	end
end

--- Поймали/победили: карта в руку игроку, монстр исчезает и позже появляется снова.
local function capture(mon: Mon, player: Player)
	if not mon.alive then
		return
	end
	local def = mon.def
	local drops = Cards.withSource("m", def.drop)
	remove(mon)

	local profile = PlayerData.get(player)
	if profile then
		profile.flags.firstMonster = true
		local reward = math.floor(def.hp * 0.5)
		profile.yen += reward
		if #drops > 0 then
			local card = drops[1]
			local ok, reason = Hand.add(player, card.id, nil)
			if not ok then
				PlayerData.notify(player, (card.name .. ": " .. (reason or "не вышло взять карту")), "warn")
			end
		else
			PlayerData.notify(player, def.name .. " повержен (+" .. reward .. " йен).", "info")
		end
		PlayerData.push(player)
	end

	task.delay(def.respawn, function()
		-- пока карту нельзя создать — монстр не появляется
		local blocked = false
		for _, card in drops do
			if not CardRegistry.canMint(card.id) then
				blocked = true
			end
		end
		if def.count > 0 and not blocked then
			spawnAt(mon.key)
		elseif def.count > 0 then
			task.delay(def.respawn, function()
				spawnAt(mon.key)
			end)
		end
	end)
end

local function setBar(mon: Mon)
	mon.bar.Size = UDim2.fromScale(math.clamp(mon.hp / mon.def.hp, 0, 1), 1)
end

--- Удар игрока по части монстра. Вызывается из CombatService.
function MonsterService.hit(player: Player, part: BasePart, baseDamage: number): boolean
	local mon = byPart[part]
	if not mon or not mon.alive then
		return false
	end
	local def = mon.def
	local now = os.clock()

	-- жук-олень: нужна серия сильных ударов по дереву
	if def.behavior == "tree" then
		table.insert(mon.hits, now)
		while #mon.hits > 0 and now - mon.hits[1] > TREE_WINDOW do
			table.remove(mon.hits, 1)
		end
		PlayerData.notify(player, ("Дерево дрожит… ударов: %d/%d"):format(#mon.hits, TREE_HITS), "info")
		if #mon.hits >= TREE_HITS then
			capture(mon, player)
		end
		return true
	end

	-- лошадь и гипердождевик: ловятся только особым способом/быстрыми руками
	if def.behavior == "faint" and now < mon.faintUntil then
		capture(mon, player)
		return true
	end

	local damage = baseDamage * Status.damageDealtFactor(player)
	if def.weak and part.Name == def.weak.part then
		if def.weak.kill then
			capture(mon, player)
			return true
		end
		damage *= def.weak.mult
	end
	if def.behavior == "flee" and mon.key == "BubbleHorse" then
		-- лошадь ловится не уроном, а Зетсу→Тен рядом
		PlayerData.notify(player, "Лошадь пугается ударов. Подкрадитесь в Зетсу, затем включите Тен.", "info")
		mon.target = player
		mon.targetUntil = now + 4
		return true
	end

	mon.hp -= damage
	mon.target = player
	mon.targetUntil = now + 8
	setBar(mon)
	if mon.hp <= 0 then
		capture(mon, player)
	end
	return true
end

function MonsterService.isMonsterPart(part: Instance): boolean
	return byPart[part] ~= nil
end

local function characterRoot(player: Player): (Part?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return root :: Part, humanoid
	end
	return nil, nil
end

local function nearestPlayer(from: Vector3, maxDistance: number, respectFactor: boolean): (Player?, number)
	local best: Player? = nil
	local bestDistance = math.huge
	for _, player in Players:GetPlayers() do
		local profile = PlayerData.get(player)
		local root = characterRoot(player)
		if root and profile and profile.inGame then
			local limit = maxDistance
			if respectFactor then
				limit *= Status.aggroFactor(player)
			end
			local distance = (root.Position - from).Magnitude
			if distance <= limit and distance < bestDistance then
				best, bestDistance = player, distance
			end
		end
	end
	return best, bestDistance
end

local function step(mon: Mon, direction: Vector3, speed: number, dt: number)
	if direction.Magnitude < 0.01 then
		return
	end
	local unit = Vector3.new(direction.X, 0, direction.Z).Unit
	local nextPos = mon.position + unit * speed * dt
	-- в воду не заходим
	if groundAt(nextPos.X, nextPos.Z) < -0.8 then
		mon.wanderTo = nil
		return
	end
	mon.position = nextPos
	mon.heading = math.atan2(-unit.X, -unit.Z)
	place(mon)
end

local function wander(mon: Mon, dt: number, now: number)
	if not mon.wanderTo or now > mon.wanderAt then
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(5, 30)
		mon.wanderTo = mon.home + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		mon.wanderAt = now + rng:NextNumber(3, 7)
	end
	local delta = mon.wanderTo - mon.position
	if delta.Magnitude > 2 then
		step(mon, delta, mon.def.speed * 0.3, dt)
	end
end

local function tickMonster(mon: Mon, dt: number, now: number)
	local def = mon.def
	if def.behavior == "tree" then
		return
	end
	if now < mon.frozenUntil then
		return
	end

	-- радиокрыса падает в обморок при виде игрока
	if def.behavior == "faint" then
		if now < mon.faintUntil then
			return
		end
		local near = nearestPlayer(mon.position, def.aggro, true)
		if near then
			mon.faintUntil = now + 8
			place(mon)
			return
		end
		wander(mon, dt, now)
		return
	end

	-- пузырьковая лошадь: ловится по связке «Зетсу, затем Тен» рядом с ней
	if mon.key == "BubbleHorse" then
		local close, distance = nearestPlayer(mon.position, 14, false)
		if close and Status.stance(close) == "zetsu" then
			mon.calmProgress += dt
			if mon.calmProgress >= 2 then
				mon.calmedUntil = now + 8
				mon.calmProgress = 0
				PlayerData.notify(close, "Лошадь замерла. Быстро включите Тен!", "good")
			end
		else
			mon.calmProgress = math.max(0, mon.calmProgress - dt)
		end
		if now < mon.calmedUntil then
			if close and distance <= 10 and Status.stance(close) == "ten" and now - Status.stanceChangedAt(close) < 3 then
				capture(mon, close)
			end
			return
		end
	end

	if def.behavior == "flee" then
		local near = nearestPlayer(mon.position, def.aggro, true)
		if near then
			local root = characterRoot(near)
			if root then
				step(mon, mon.position - root.Position, def.speed, dt)
				return
			end
		end
		wander(mon, dt, now)
		return
	end

	-- chase: вожак ищет цель сам, волки идут за вожаком или за общей целью
	local target = mon.target
	if target and (now > mon.targetUntil or not characterRoot(target)) then
		target = nil
		mon.target = nil
	end
	if now >= mon.blindUntil and not target then
		local found = nearestPlayer(mon.position, def.aggro, true)
		if found then
			target = found
			mon.target = found
			mon.targetUntil = now + 6
		end
	end
	if mon.leader and mon.leader.alive and mon.leader.target and not target then
		target = mon.leader.target
		mon.target = target
		mon.targetUntil = now + 6
	end
	if now < mon.blindUntil then
		target = nil
	end

	if target then
		local root, humanoid = characterRoot(target)
		if root and humanoid then
			local delta = root.Position - mon.position
			local distance = Vector3.new(delta.X, 0, delta.Z).Magnitude
			if distance > 5.5 then
				step(mon, delta, def.speed, dt)
			elseif now >= mon.nextAttack then
				mon.nextAttack = now + BODY_ATTACK_COOLDOWN
				humanoid:TakeDamage(def.damage * Status.damageTakenFactor(target))
			end
			return
		end
	end

	-- далеко от дома — возвращаемся
	if (mon.position - mon.home).Magnitude > 90 then
		step(mon, mon.home - mon.position, def.speed * 0.6, dt)
		return
	end
	wander(mon, dt, now)
end

-- ===================== воздействия заклинаний =====================

function MonsterService.freezeNear(origin: Vector3, range: number, seconds: number)
	local until_ = os.clock() + seconds
	for _, mon in active do
		if (mon.position - origin).Magnitude <= range then
			mon.frozenUntil = until_
		end
	end
end

function MonsterService.blindNear(origin: Vector3, range: number, seconds: number)
	local until_ = os.clock() + seconds
	for _, mon in active do
		if (mon.position - origin).Magnitude <= range then
			mon.blindUntil = until_
			mon.target = nil
		end
	end
end

function MonsterService.lure(player: Player, range: number, seconds: number)
	local root = characterRoot(player)
	if not root then
		return
	end
	for _, mon in active do
		if mon.def.behavior == "chase" and (mon.position - root.Position).Magnitude <= range then
			mon.target = player
			mon.targetUntil = os.clock() + seconds
		end
	end
end

function MonsterService.pingNear(player: Player, range: number)
	local root = characterRoot(player)
	if not root then
		return
	end
	local positions = {}
	for _, mon in active do
		if (mon.position - root.Position).Magnitude <= range then
			table.insert(positions, mon.position + Vector3.new(0, 4, 0))
		end
	end
	Remotes.Hint:FireClient(player, { positions = positions, seconds = 30 })
	PlayerData.notify(player, ("Колокольчик звенит: монстров рядом — %d"):format(#positions), "info")
end

function MonsterService.start()
	folder = Instance.new("Folder")
	folder.Name = "Monsters"
	folder.Parent = workspace:WaitForChild("World")
	params = groundParams()

	for key, def in Monsters do
		for _ = 1, def.count do
			spawnAt(key)
		end
	end

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < TICK then
			return
		end
		local elapsed = accumulator
		accumulator = 0
		local now = os.clock()
		for index = #active, 1, -1 do
			local mon = active[index]
			if mon and mon.alive then
				tickMonster(mon, elapsed, now)
			end
		end
	end)
end

return MonsterService
