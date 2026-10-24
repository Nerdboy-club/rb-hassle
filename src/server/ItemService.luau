-- Предметы, лежащие в мире. Подобрал — предмет становится картой в руке (см. Hand.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Cards = require(Shared.Cards)
local Ranks = require(Shared.Ranks)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)

local CardRegistry = require(script.Parent.CardRegistry)
local PlayerData = require(script.Parent.PlayerData)
local Hand = require(script.Parent.Hand)
local WorldBuilder = require(script.Parent.WorldBuilder)

local ItemService = {}

-- сколько узлов лежит в мире у карты данного ранга
local NODES_PER_RANK = { SS = 1, S = 1, A = 1, B = 1, C = 2, D = 2, E = 3, F = 3, G = 4, H = 4 }
local GREY = Color3.fromRGB(110, 110, 118)

local nodes: { Part } = {}
local nodesByCard: { [number]: { Part } } = {}
local rng = Random.new()
local folder: Folder

local function refresh(node: Part)
	local id = node:GetAttribute("CardId")
	local card = Cards.get(id)
	local prompt = node:FindFirstChildOfClass("ProximityPrompt")
	if not card or not prompt then
		return
	end
	local hidden = node:GetAttribute("Taken") == true or node:GetAttribute("Consumed") == true
	node.Transparency = hidden and 1 or 0
	local light = node:FindFirstChildOfClass("PointLight")
	if light then
		light.Enabled = not hidden
	end
	if hidden then
		prompt.Enabled = false
		return
	end
	local available = CardRegistry.canMint(id)
	node.Color = available and Ranks.color(card.rank) or GREY
	prompt.Enabled = available
	prompt.ActionText = available and "Подобрать" or "Лимит исчерпан"
end

local function findSpot(zoneKey: string): Vector3
	local point = Vector3.new(0, 0, 0)
	for _ = 1, 30 do
		local candidate = Util.randomPointIn(zoneKey, rng)
		local y = WorldBuilder.terrainY(candidate.X, candidate.Z)
		point = Vector3.new(candidate.X, y + 1.6, candidate.Z)
		-- в воду и в стены не кладём
		if y > -0.5 and WorldBuilder.isFree(point, 3) then
			return point
		end
	end
	return point
end

local function spawnNode(card: Cards.Card, zoneKey: string)
	local node = Instance.new("Part")
	node.Name = "Pickup"
	node.Shape = Enum.PartType.Ball
	node.Size = Vector3.new(2.4, 2.4, 2.4)
	node.Material = Enum.Material.Neon
	node.Color = Ranks.color(card.rank)
	node.Anchored = true
	node.CanCollide = false
	node.Position = findSpot(zoneKey)
	node:SetAttribute("CardId", card.id)
	node:SetAttribute("Taken", false)
	node:SetAttribute("Consumed", false)

	local light = Instance.new("PointLight")
	light.Range = 10
	light.Brightness = 1.5
	light.Color = Ranks.color(card.rank)
	light.Parent = node

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Подобрать"
	prompt.ObjectText = "Предмет · ранг " .. card.rank
	prompt.HoldDuration = Config.PickupHoldSeconds
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = node

	node.Parent = folder
	table.insert(nodes, node)
	nodesByCard[card.id] = nodesByCard[card.id] or {}
	table.insert(nodesByCard[card.id], node)

	prompt.Triggered:Connect(function(player)
		ItemService.pickup(player, node)
	end)

	node:GetAttributeChangedSignal("Taken"):Connect(function()
		refresh(node)
	end)
	node:GetAttributeChangedSignal("Consumed"):Connect(function()
		refresh(node)
		if node:GetAttribute("Consumed") == true then
			task.delay(Config.PickupRespawnSeconds, function()
				node:SetAttribute("Consumed", false)
				node:SetAttribute("Taken", false)
			end)
		end
	end)
end

--- Подобрать узел: предмет становится картой в руке. Возвращает true при успехе.
function ItemService.pickup(player: Player, node: Part): boolean
	local profile = PlayerData.get(player)
	if not profile or not profile.inGame then
		return false
	end
	if node:GetAttribute("Taken") or node:GetAttribute("Consumed") then
		return false
	end
	node:SetAttribute("Taken", true)
	local ok, reason = Hand.add(player, node:GetAttribute("CardId"), node)
	if not ok then
		node:SetAttribute("Taken", false)
		PlayerData.notify(player, reason or "Не удалось подобрать", "warn")
		return false
	end
	return true
end

--- Узлы, доступные прямо сейчас: ближайшие к точке, в радиусе range.
local function visibleNodesNear(origin: Vector3, range: number): { Part }
	local found = {}
	for _, node in nodes do
		if node:GetAttribute("Taken") ~= true and node:GetAttribute("Consumed") ~= true and CardRegistry.canMint(node:GetAttribute("CardId")) then
			if (node.Position - origin).Magnitude <= range then
				table.insert(found, node)
			end
		end
	end
	table.sort(found, function(a, b)
		return (a.Position - origin).Magnitude < (b.Position - origin).Magnitude
	end)
	return found
end

function ItemService.nodesNear(origin: Vector3, range: number): { Part }
	return visibleNodesNear(origin, range)
end

--- Показать игроку маркеры ближайших предметов (клиент рисует лучи).
function ItemService.reveal(player: Player, range: number, count: number, seconds: number)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local positions = {}
	for index, node in visibleNodesNear(root.Position, range) do
		if index > count then
			break
		end
		table.insert(positions, node.Position)
	end
	Remotes.Hint:FireClient(player, { positions = positions, seconds = seconds })
	PlayerData.notify(player, ("Найдено предметов: %d"):format(#positions), "info")
end

function ItemService.hintNearest(player: Player, count: number)
	ItemService.reveal(player, math.huge, count, 60)
end

function ItemService.start()
	folder = Instance.new("Folder")
	folder.Name = "Items"
	folder.Parent = workspace:WaitForChild("World")

	for _, id in Cards.numberedIds do
		local card = Cards.get(id) :: Cards.Card
		local source = Cards.parseSource(card.source)
		if source.type == "p" and source.arg then
			for _ = 1, NODES_PER_RANK[card.rank] or 1 do
				spawnNode(card, source.arg)
			end
		end
	end

	CardRegistry.changed.Event:Connect(function(id)
		for _, node in nodesByCard[id] or {} do
			refresh(node)
		end
	end)
end

return ItemService
