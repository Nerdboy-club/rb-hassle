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

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "GreedIslandUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- масштаб интерфейса под размер экрана: на телефоне панели уменьшаются, а не налезают друг на друга
do
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = gui
	local function fit()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local size = camera.ViewportSize
		uiScale.Scale = math.clamp(math.min(size.X / 1000, size.Y / 640), 0.5, 1)
	end
	fit()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	-- список игроков справа сверху занимает место цели и эффекты
	pcall(function()
		game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
end

local book = BookUI.create(gui)
DialogUI.create(gui)
local shop = ShopUI.create(gui)
QuizUI.create(gui)
Effects.start()

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

-- слова кольца: «Книга» открывает переплёт, «Приращение» — режим приращения
local function say(text: string)
	local trimmed = text:gsub("^[%s/]+", "")
	trimmed = trimmed:gsub("%s+$", "")
	local word = lowerCyrillic(trimmed)
	if word == "книга" or word == "book" then
		book.open("normal")
	elseif word == "приращение" or word == "gain" then
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

-- ===== горячие клавиши и удар =====
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if State.phase == "lobby" then
		return
	end
	if input.KeyCode == Enum.KeyCode.B then
		book.toggle()
	elseif input.KeyCode == Enum.KeyCode.G then
		book.open("gain")
	elseif input.KeyCode == Enum.KeyCode.T then
		toggleStance("ten")
	elseif input.KeyCode == Enum.KeyCode.Z then
		toggleStance("zetsu")
	elseif input.KeyCode == Enum.KeyCode.Escape and shop.isOpen() then
		shop.close()
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if book.isOpen() or shop.isOpen() then
			return
		end
		local camera = workspace.CurrentCamera
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not camera or not root then
			return
		end
		local location = UserInputService:GetMouseLocation()
		if input.UserInputType == Enum.UserInputType.Touch then
			location = Vector2.new(input.Position.X, input.Position.Y)
		end
		local ray = camera:ViewportPointToRay(location.X, location.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character :: Instance }
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
		local target = hit and hit.Position or (ray.Origin + ray.Direction * 40)
		local origin = (root :: BasePart).Position + Vector3.new(0, 1.5, 0)
		local direction = target - origin
		if direction.Magnitude > 0.1 then
			Remotes.Attack:FireServer(direction.Unit)
		end
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
