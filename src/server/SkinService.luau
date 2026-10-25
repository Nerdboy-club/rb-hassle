-- Образы героев: покупка в «Гардеробе» и надевание на персонажа игрока.
-- Образ — косметика: перекрашивает тело и одежду и приваривает детали (причёска, аксессуары).
-- Оригинальный вид (цвета, рубашка, штаны, аксессуары) запоминается и возвращается при снятии образа.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Skins = require(Shared.Skins)
local Util = require(Shared.Util)

local PlayerData = require(script.Parent.PlayerData)

local SkinService = {}

local SHIRT_PARTS = { "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Torso", "Left Arm", "Right Arm" }
local SKIN_PARTS = { "Head", "LeftHand", "RightHand" }
local PANTS_PARTS = { "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot", "Left Leg", "Right Leg" }
local FOLDER_NAME = "OutfitParts"
local PAGE_SIZE = 3 -- образов на странице диалога

type Saved = {
	colors: { [BasePart]: Color3 },
	clothes: { Instance }, -- клоны Shirt/Pants/Accessory, снятые с персонажа
}

local saved: { [Model]: Saved } = setmetatable({}, { __mode = "k" }) :: any

local function attachPoint(character: Model, name: string): BasePart?
	local found: Instance? = nil
	if name == "Head" then
		found = character:FindFirstChild("Head")
	elseif name == "Torso" or name == "Back" then
		found = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	elseif name == "RightHand" then
		found = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	elseif name == "LeftHand" then
		found = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
	end
	return found and found:IsA("BasePart") and found :: BasePart or nil
end

local function paint(character: Model, names: { string }, color: Color3, record: { [BasePart]: Color3 })
	for _, name in names do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			if not record[part] then
				record[part] = part.Color
			end
			part.Color = color
		end
	end
end

--- Снять образ: вернуть цвета, одежду и убрать приваренные детали.
local function clear(character: Model)
	local folder = character:FindFirstChild(FOLDER_NAME)
	if folder then
		folder:Destroy()
	end
	local memory = saved[character]
	if memory then
		for part, color in memory.colors do
			if part.Parent then
				part.Color = color
			end
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		for _, item in memory.clothes do
			if item:IsA("Accessory") then
				if humanoid then
					humanoid:AddAccessory(item)
				end
			else
				item.Parent = character
			end
		end
		saved[character] = nil
	end
	character:SetAttribute("Outfit", nil)
end

local function buildPiece(character: Model, folder: Folder, spec: Skins.Piece)
	local anchor = attachPoint(character, spec.on)
	if not anchor then
		return
	end
	local part = Instance.new("Part")
	part.Name = "OutfitPart"
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.Color = spec.color
	part.Material = spec.material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	local size = spec.size
	local offset = spec.offset
	if spec.on == "Head" then
		-- размеры и смещения головы заданы в долях её размера
		local head = anchor.Size
		size = Vector3.new(size.X * head.X, size.Y * head.Y, size.Z * head.Z)
		offset = Vector3.new(offset.X * head.X, offset.Y * head.Y, offset.Z * head.Z)
	elseif spec.on == "Back" then
		offset = Vector3.new(offset.X, offset.Y, offset.Z) -- Z: от торса назад (+Z у персонажа — спина)
	end
	local rot = spec.rot or Vector3.zero
	local angles = CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
	if spec.shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	elseif spec.shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	end
	part.Size = size
	part.CFrame = anchor.CFrame * CFrame.new(offset) * angles
	part.Parent = folder

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = part
	weld.Parent = part
end

--- Надеть образ, выбранный в профиле (или снять, если образа нет). Безопасно вызывать повторно.
function SkinService.apply(player: Player)
	local character = player.Character
	local profile = PlayerData.get(player)
	if not character or not profile then
		return
	end
	clear(character)
	local skin = profile.outfit and Skins.get(profile.outfit) or nil
	if not skin then
		return
	end

	local memory: Saved = { colors = {}, clothes = {} }
	saved[character] = memory
	-- снимаем штатную одежду и аксессуары: они перекрыли бы образ
	for _, child in character:GetChildren() do
		if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") or child:IsA("Accessory") then
			table.insert(memory.clothes, child:Clone())
			child:Destroy()
		end
	end
	if skin.skin then
		paint(character, SKIN_PARTS, skin.skin, memory.colors)
	end
	paint(character, SHIRT_PARTS, skin.shirt, memory.colors)
	paint(character, PANTS_PARTS, skin.pants, memory.colors)

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = character
	for _, spec in skin.pieces do
		local ok, err = pcall(buildPiece, character, folder, spec)
		if not ok then
			warn("[SkinService] деталь образа не создана: " .. tostring(err))
		end
	end
	character:SetAttribute("Outfit", skin.id)
end

local function owned(profile: PlayerData.Profile, skinId: string): boolean
	return profile.flags["skin_" .. skinId] == true
end

-- ===================== диалог «Гардероб» =====================

type Option = { id: string, label: string }

local function listPage(ctx, page: number)
	local profile = ctx.profile
	local pages = math.ceil(#Skins.list / PAGE_SIZE)
	page = math.clamp(page, 1, pages)
	local options: { Option } = {}
	for index = (page - 1) * PAGE_SIZE + 1, math.min(page * PAGE_SIZE, #Skins.list) do
		local skin = Skins.list[index]
		local status = profile.outfit == skin.id and "✔ надет" or (owned(profile, skin.id) and "куплен" or Util.formatYen(skin.price))
		table.insert(options, { id = "skin:" .. skin.id, label = ("%s · %s"):format(skin.name, status) })
	end
	if pages > 1 then
		table.insert(options, { id = "page:" .. (page % pages + 1), label = ("▶ Дальше (%d/%d)"):format(page, pages) })
	end
	if profile.outfit then
		table.insert(options, { id = "unwear", label = "Снять образ" })
	end
	table.insert(options, { id = "bye", label = "Уйти" })
	ctx.say("Образы героев — только внешний вид, на силу и урон они не влияют. Выбирайте!", options)
end

local function skinPage(ctx, skinId: string)
	local skin = Skins.get(skinId)
	if not skin then
		listPage(ctx, 1)
		return
	end
	local profile = ctx.profile
	local options: { Option } = {}
	local line
	if profile.outfit == skin.id then
		line = "Этот образ сейчас на вас."
		table.insert(options, { id = "unwear", label = "Снять образ" })
	elseif owned(profile, skin.id) then
		line = "Образ уже куплен."
		table.insert(options, { id = "wear:" .. skin.id, label = "Надеть" })
	else
		line = ("Цена: %s. У вас: %s."):format(Util.formatYen(skin.price), Util.formatYen(profile.yen))
		table.insert(options, { id = "buy:" .. skin.id, label = "Купить за " .. Util.formatYen(skin.price) })
	end
	table.insert(options, { id = "page:1", label = "◀ К списку" })
	table.insert(options, { id = "bye", label = "Уйти" })
	ctx.say(("%s\n\n%s\n%s"):format(skin.name, skin.desc, line), options)
end

SkinService.role = {
	talk = function(ctx)
		listPage(ctx, 1)
	end,
	choose = function(ctx, option: string)
		local profile = ctx.profile
		local kind, arg = string.match(option, "^(%a+):?(.*)$")
		if kind == "page" then
			listPage(ctx, tonumber(arg) or 1)
		elseif kind == "skin" then
			skinPage(ctx, arg)
		elseif kind == "buy" then
			local skin = Skins.get(arg)
			if not skin then
				listPage(ctx, 1)
			elseif owned(profile, skin.id) then
				skinPage(ctx, skin.id)
			elseif profile.yen < skin.price then
				ctx.say("Не хватает йен на этот образ.", { { id = "skin:" .. skin.id, label = "Назад" }, { id = "bye", label = "Уйти" } })
			else
				profile.yen -= skin.price
				profile.flags["skin_" .. skin.id] = true
				profile.outfit = skin.id
				SkinService.apply(ctx.player)
				PlayerData.notify(ctx.player, ("Образ «%s» куплен и надет."):format(skin.name), "good")
				PlayerData.push(ctx.player)
				skinPage(ctx, skin.id)
			end
		elseif kind == "wear" then
			local skin = Skins.get(arg)
			if skin and owned(profile, skin.id) then
				profile.outfit = skin.id
				SkinService.apply(ctx.player)
				PlayerData.push(ctx.player)
				skinPage(ctx, skin.id)
			else
				listPage(ctx, 1)
			end
		elseif kind == "unwear" then
			profile.outfit = nil
			SkinService.apply(ctx.player)
			PlayerData.push(ctx.player)
			listPage(ctx, 1)
		else
			ctx.close()
		end
	end,
}

function SkinService.start()
	local function watch(player: Player)
		player.CharacterAppearanceLoaded:Connect(function()
			SkinService.apply(player)
		end)
		-- профиль мог загрузиться позже внешнего вида персонажа
		task.spawn(function()
			for _ = 1, 60 do
				if PlayerData.get(player) or not player.Parent then
					break
				end
				task.wait(0.5)
			end
			if player.Parent and player.Character then
				SkinService.apply(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return SkinService
