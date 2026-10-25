-- Клиент: собирает интерфейс, горячие клавиши, удар, маркеры подсказок.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local BookUI = require(script.Parent.BookUI)
local DialogUI = require(script.Parent.DialogUI)
local Hud = require(script.Parent.Hud)
local Effects = require(script.Parent.Effects)
local QuizUI = require(script.Parent.QuizUI)
local ShopUI = require(script.Parent.ShopUI)
local State = require(script.Parent.State)
local TouchControls = require(script.Parent.TouchControls)
local Ambient = require(script.Parent.Ambient)
local AttackFx = require(script.Parent.AttackFx)
local ArenaUI = require(script.Parent.ArenaUI)
local ChoiceUI = require(script.Parent.ChoiceUI)

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "GreedIslandUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- список игроков справа сверху занимает место целей и эффектов
pcall(function()
	game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

local book = BookUI.create(gui)
DialogUI.create(gui)
local shop = ShopUI.create(gui)
local arena = ArenaUI.create(gui)
local choice = ChoiceUI.create(gui)
QuizUI.create(gui)
Effects.start()
pcall(Ambient.start)

-- заставка при входе
do
	local TweenService = game:GetService("TweenService")
	local splash = Instance.new("Frame")
	splash.Size = UDim2.fromScale(1, 1)
	splash.BackgroundColor3 = Color3.fromRGB(10, 12, 20)
	splash.BorderSizePixel = 0
	splash.ZIndex = 100
	splash.Parent = gui
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.2)
	title.Position = UDim2.fromScale(0, 0.38)
	title.BackgroundTransparency = 1
	title.Text = "GREED ISLAND"
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 64
	title.TextColor3 = Color3.fromRGB(255, 215, 110)
	title.ZIndex = 101
	title.Parent = splash
	local subtitle = title:Clone()
	subtitle.Position = UDim2.fromScale(0, 0.52)
	subtitle.Size = UDim2.fromScale(1, 0.08)
	subtitle.Text = "Соберите все 100 карт"
	subtitle.Font = Enum.Font.GothamMedium
	subtitle.TextSize = 24
	subtitle.TextColor3 = Color3.fromRGB(200, 208, 230)
	subtitle.Parent = splash
	task.delay(2.6, function()
		local info = TweenInfo.new(1)
		TweenService:Create(splash, info, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(title, info, { TextTransparency = 1 }):Play()
		TweenService:Create(subtitle, info, { TextTransparency = 1 }):Play()
		task.wait(1)
		splash:Destroy()
	end)
end

local function toggleStance(name: string)
	Remotes.Stance:FireServer(State.stance == name and "none" or name)
end

--- Нижний регистр с кириллицей (string.lower работает только с ASCII).
local function lowerCyrillic(text: string): string
	local out = {}
	for _, code in utf8.codepoint(text, 1, -1) and { utf8.codepoint(text, 1, -1) } or {} do
		if code >= 0x410 and code <= 0x42F then
			code += 32
		elseif code == 0x401 then
			code = 0x451
		elseif code < 128 then
			code = string.byte(string.lower(string.char(code)))
		end
		table.insert(out, utf8.char(code))
	end
	return table.concat(out)
end

-- слова кольца: «Книга» открывает переплёт, «Получить» — режим получить
local function say(text: string)
	local trimmed = text:gsub("^[%s/]+", "")
	trimmed = trimmed:gsub("%s+$", "")
	local word = lowerCyrillic(trimmed)
	if word == "книга" or word == "book" then
		book.open("normal")
	elseif word == "получить" or word == "приращение" or word == "gain" then
		book.open("gain")
	elseif word == "тен" or word == "ten" then
		Remotes.Stance:FireServer("ten")
	elseif word == "зетсу" or word == "zetsu" then
		Remotes.Stance:FireServer("zetsu")
	end
end

local hud = Hud.create(gui, {
	book = function()
		book.toggle()
	end,
	gain = function()
		book.open("gain")
	end,
	ten = function()
		toggleStance("ten")
	end,
	zetsu = function()
		toggleStance("zetsu")
	end,
	command = say,
})
hud.notify("Добро пожаловать в Greed Island. Подойдите к JoyStation и нажмите E.", "info")

-- ===== удар =====
local function sendAttack(direction: Vector3)
	if direction.Magnitude > 0.1 then
		Remotes.Attack:FireServer(direction.Unit)
		pcall(AttackFx.play, direction.Unit)
	end
end

--- Ближайший монстр в конусе вокруг направления aim (помощь в прицеливании).
local function monsterNear(origin: Vector3, aim: Vector3, maxDistance: number, minDot: number): Vector3?
	local best: Vector3? = nil
	local bestScore = math.huge
	local world = workspace:FindFirstChild("World")
	local monsters = world and world:FindFirstChild("Monsters")
	if monsters then
		for _, model in monsters:GetChildren() do
			local part = model:FindFirstChild("Root") :: BasePart?
			if part then
				local offset = part.Position + Vector3.new(0, 2, 0) - origin
				local distance = offset.Magnitude
				if distance < maxDistance and distance > 0.1 and offset.Unit:Dot(aim) > minDot then
					local score = distance * (2 - offset.Unit:Dot(aim))
					if score < bestScore then
						bestScore = score
						best = offset
					end
				end
			end
		end
	end
	return best
end

--- Удар в точку экрана (мышь): луч от камеры, направление от персонажа, с помощью прицела.
local function attackAt(location: Vector2)
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not camera or not root then
		return
	end
	local ray = camera:ViewportPointToRay(location.X, location.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character :: Instance }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	local target = hit and hit.Position or (ray.Origin + ray.Direction * 40)
	local origin = (root :: BasePart).Position + Vector3.new(0, 1.5, 0)
	local aim = target - origin
	if aim.Magnitude < 0.1 then
		aim = (root :: BasePart).CFrame.LookVector
	end
	-- курсор точно на монстре: бьём именно туда (слабые места); иначе помощь прицела
	if hit and hit.Instance:FindFirstAncestor("Monsters") then
		sendAttack(aim)
		return
	end
	sendAttack(monsterNear(origin, aim.Unit, 24, 0.8) or aim)
end

--- Удар кнопкой на телефоне: в ближайшего монстра впереди, иначе туда, куда смотрит персонаж.
local function attackForward()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local look = root.CFrame.LookVector
	sendAttack(monsterNear(origin, look, 24, 0.2) or look)
end

if TouchControls.isTouchDevice() then
	TouchControls.create(gui, {
		attack = attackForward,
		book = function()
			book.toggle()
		end,
		gain = function()
			book.open("gain")
		end,
		ten = function()
			toggleStance("ten")
		end,
		zetsu = function()
			toggleStance("zetsu")
		end,
	}, function()
		return book.isOpen() or shop.isOpen() or arena.isOpen() or choice.isOpen()
	end)
end
-- ===== горячие клавиши =====
local mouseHeld = false
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if State.phase == "lobby" then
		return
	end
	if input.KeyCode == Enum.KeyCode.Tab then
		book.toggle()
	elseif input.KeyCode == Enum.KeyCode.G then
		book.open("gain")
	elseif input.KeyCode == Enum.KeyCode.T then
		toggleStance("ten")
	elseif input.KeyCode == Enum.KeyCode.Y then
		toggleStance("zetsu")
	elseif input.KeyCode == Enum.KeyCode.Escape and shop.isOpen() then
		shop.close()
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not TouchControls.isTouchDevice() then
		if book.isOpen() or shop.isOpen() or arena.isOpen() then
			return
		end
		mouseHeld = true
		task.spawn(function()
			while mouseHeld and not (book.isOpen() or shop.isOpen() or arena.isOpen()) do
				attackAt(UserInputService:GetMouseLocation())
				task.wait(0.15)
			end
		end)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		mouseHeld = false
	end
end)

-- «/» ставит курсор в строку слов кольца
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Slash then
		local box = gui:FindFirstChildWhichIsA("TextBox", true)
		if box then
			task.defer(function()
				(box :: TextBox):CaptureFocus()
			end)
		end
	end
end)

-- ===== маркеры подсказок (Ясновидение, Золотой компас, Колокольчик) =====
Remotes.Hint.OnClientEvent:Connect(function(data)
	local folder = Instance.new("Folder")
	folder.Name = "HintBeacons"
	folder.Parent = workspace
	for _, position in data.positions do
		local pillar = Instance.new("Part")
		pillar.Anchored = true
		pillar.CanCollide = false
		pillar.CanQuery = false
		pillar.Material = Enum.Material.Neon
		pillar.Color = Color3.fromRGB(255, 225, 110)
		pillar.Transparency = 0.35
		pillar.Size = Vector3.new(0.8, 90, 0.8)
		pillar.Position = position + Vector3.new(0, 45, 0)
		pillar.Parent = folder
	end
	task.delay(data.seconds or 20, function()
		folder:Destroy()
	end)
end)

Remotes.BinderAction:FireServer({ action = "sync" })
