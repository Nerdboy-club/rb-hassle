-- HUD: баланс, кольцо (кнопки заклинаний кольца), рука, эффекты, уведомления, название зоны.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Cards)
local Ranks = require(Shared.Ranks)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)

local State = require(script.Parent.State)
local Theme = require(script.Parent.Theme)
local Guide = require(script.Parent.Guide)
local TouchControls = require(script.Parent.TouchControls)

local Hud = {}

local KIND_COLORS = {
	info = Theme.accent,
	good = Theme.good,
	warn = Theme.warn,
}

function Hud.create(screen: ScreenGui, actions: { [string]: (...any) -> () })
	-- корень HUD: масштабируется под экран (телефон), панели книги/лавки/диалога масштабируют себя сами
	local gui = Instance.new("Frame")
	gui.Name = "HudRoot"
	gui.BackgroundTransparency = 1
	gui.BorderSizePixel = 0
	gui.Parent = screen
	local hudScale = Instance.new("UIScale")
	hudScale.Parent = gui
	local function fitHud()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local size = camera.ViewportSize
		local factor = math.clamp(math.min(size.X / 1000, size.Y / 640), 0.7, 1)
		hudScale.Scale = factor
		gui.Size = UDim2.fromScale(1 / factor, 1 / factor)
	end
	fitHud()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitHud)
	end

	-- ===== баланс и фаза =====
	-- над кнопками кольца (на телефоне кнопок кольца нет — панель внизу слева)
	local top = Theme.frame(gui, UDim2.fromOffset(190, 62), UDim2.new(0, 14, 1, TouchControls.isTouchDevice() and -14 or -240), Theme.bg)
	top.AnchorPoint = Vector2.new(0, 1)
	top.BackgroundTransparency = 0.15
	Theme.corner(top, 10)
	local yenLabel = Theme.label(top, "", UDim2.new(1, -16, 0, 24), UDim2.fromOffset(10, 4), {
		TextYAlignment = Enum.TextYAlignment.Center,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextColor3 = Theme.gold,
	})
	local hpTrack = Theme.frame(top, UDim2.new(1, -20, 0, 18), UDim2.fromOffset(10, 34), Color3.fromRGB(50, 24, 28))
	Theme.corner(hpTrack, 6)
	local hpFill = Theme.frame(hpTrack, UDim2.fromScale(1, 1), nil, Theme.bad)
	Theme.corner(hpFill, 6)
	local hpLabel = Theme.label(hpTrack, "", UDim2.fromScale(1, 1), nil, {
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
	})
	hpLabel.ZIndex = 2
	RunService.Heartbeat:Connect(function()
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.MaxHealth > 0 then
			local ratio = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
			hpFill.Size = UDim2.fromScale(ratio, 1)
			hpLabel.Text = ("HP %d / %d"):format(math.ceil(humanoid.Health), humanoid.MaxHealth)
		end
	end)

	-- ===== кнопки кольца =====
	local ring = Theme.frame(gui, UDim2.fromOffset(190, 218), UDim2.new(0, 14, 1, -14), Theme.bg)
	ring.AnchorPoint = Vector2.new(0, 1)
	ring.BackgroundTransparency = 0.15
	Theme.corner(ring, 12)
	Theme.padding(ring, 8)
	local ringLayout = Instance.new("UIListLayout")
	ringLayout.Padding = UDim.new(0, 6)
	ringLayout.Parent = ring

	local stanceButtons: { [string]: TextButton } = {}
	local function ringButton(text: string, key: string, callback: () -> ()): TextButton
		local button = Theme.button(ring, text, UDim2.new(1, 0, 0, 34), nil, Theme.panelLight)
		button.TextSize = 13
		button.Activated:Connect(callback)
		return button
	end
	ringButton("📖 Книга  [Tab]", "B", actions.book)
	ringButton("✨ Получить  [G]", "G", actions.gain)
	stanceButtons.ten = ringButton("🛡 Тен  [T]", "T", actions.ten)
	stanceButtons.zetsu = ringButton("🌫 Зетсу  [Y]", "Z", actions.zetsu)
	local commandBox = Instance.new("TextBox")
	commandBox.Size = UDim2.new(1, 0, 0, 34)
	commandBox.BackgroundColor3 = Theme.panel
	commandBox.TextColor3 = Theme.text
	commandBox.PlaceholderText = "Скажите слово кольца…  [/]"
	commandBox.PlaceholderColor3 = Theme.muted
	commandBox.Font = Enum.Font.Gotham
	commandBox.TextSize = 13
	commandBox.ClearTextOnFocus = true
	commandBox.BorderSizePixel = 0
	commandBox.Parent = ring
	Theme.corner(commandBox, 8)

	commandBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			actions.command(commandBox.Text)
		end
		commandBox.Text = ""
	end)

	-- ===== рука (всегда на виду) =====
	local handFrame = Theme.frame(gui, UDim2.fromOffset(230, 60), UDim2.fromOffset(14, 58), Theme.bg)
	handFrame.BackgroundTransparency = 1
	local handLayout = Instance.new("UIListLayout")
	handLayout.Padding = UDim.new(0, 4)
	handLayout.Parent = handFrame

	-- ===== эффекты =====
	local effectsLabel = Theme.label(gui, "", UDim2.fromOffset(240, 120), UDim2.new(1, -254, 0, 116), {
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 13,
		TextColor3 = Theme.accent,
	})

	-- ===== цели: ведут новичка по игре =====
	local goals = Theme.frame(gui, UDim2.fromOffset(270, 96), UDim2.new(1, -284, 0, 12), Theme.bg)
	goals.BackgroundTransparency = 0.18
	Theme.corner(goals, 10)
	Theme.stroke(goals, Theme.panelLight, 1)
	Theme.padding(goals, 8)
	local goalsLabel = Theme.label(goals, "", UDim2.fromScale(1, 1), nil, { TextSize = 13 })

	local guide = Guide.create(gui)

	local OBJECTIVES = {
		{ text = "Поговорите с Этой у Дерева Шисо (E)", done = function(d) return State.hasFlag("metEta") end, target = function() return Guide.npcPosition("eta") end, title = "Эта" },
		{ text = "Подберите предмет (E) и вложите карту в книгу за минуту (Tab)", done = function(d) return #d.slots >= 2 end },
		{ text = "Победите монстра: бейте его (ЛКМ), и выпадет карта", done = function(d) return State.hasFlag("firstMonster") end, target = function() return Guide.nearestMonster(State.playerPosition()) end, title = "Монстр" },
		{ text = "Соберите 10 карт", done = function(d) return #d.slots >= 10 end },
		{ text = "Купите заклинание в Масадоре", done = function(d) return State.hasFlag("boughtSpell") end, target = function() return Guide.npcPosition("shop_spells") end, title = "Магазин спеллов" },
		{ text = "Соберите 50 карт", done = function(d) return #d.slots >= 50 end },
		{ text = "Вылечите жителей деревни горных бандитов («Лекарство» — в Wig & Pen)", done = function(d) return State.hasFlag("bandits") end, target = function()
			if State.owns(201) then
				return Guide.zonePosition("Bandits")
			end
			return Guide.npcPosition("shop_wigpen")
		end, title = "Лекарство: Wig & Pen / деревня" },
		{ text = "Соберите 99 карт и пройдите викторину Двана в Лимейро", done = function(d) return d.won end, target = function() return Guide.npcPosition("dwan") end, title = "Дван (Лимейро)" },
		{ text = "Купите или выбейте билет в порту и выйдите через башню Елены", done = function(d) return false end, target = function() return Guide.npcPosition("elena") end, title = "Елена (порт)" },
	}

	local function refreshGoals()
		local data = State.data
		if not data or State.phase == "lobby" then
			goals.Visible = false
			guide.set(nil)
			return
		end
		goals.Visible = true
		local lines = { "ЦЕЛИ" }
		local shown = 0
		for _, objective in OBJECTIVES do
			if not objective.done(data) then
				shown += 1
				table.insert(lines, "• " .. objective.text)
				if shown >= 3 then
					break
				end
			end
		end
		goalsLabel.Text = table.concat(lines, "\n")
		-- стрелка ведёт к первой невыполненной цели, у которой есть место
		local aim = nil
		for _, objective in OBJECTIVES do
			if not objective.done(data) then
				aim = objective
				break
			end
		end
		if aim and aim.target then
			guide.set(aim.target, aim.title)
		else
			guide.set(nil)
		end
	end

	-- ===== экран победы =====
	local winOverlay = Theme.frame(gui, UDim2.fromScale(1, 1), nil, Color3.fromRGB(0, 0, 0))
	winOverlay.BackgroundTransparency = 1
	winOverlay.Visible = false
	winOverlay.ZIndex = 40
	local winTitle = Theme.label(winOverlay, "ПОБЕДА", UDim2.fromScale(1, 0.2), UDim2.fromScale(0, 0.32), {
		Font = Enum.Font.GothamBlack,
		TextSize = 72,
		TextColor3 = Theme.gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTransparency = 1,
	})
	winTitle.ZIndex = 41
	local winSub = Theme.label(winOverlay, "Все 100 слотов заполнены. Greed Island пройден.", UDim2.fromScale(1, 0.1), UDim2.fromScale(0, 0.52), {
		Font = Enum.Font.GothamMedium,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
	})
	winSub.ZIndex = 41

	local wasWon: boolean? = nil
	local function checkWin()
		local data = State.data
		if not data then
			return
		end
		if wasWon == false and data.won then
			winOverlay.Visible = true
			TweenService:Create(winOverlay, TweenInfo.new(0.8), { BackgroundTransparency = 0.45 }):Play()
			TweenService:Create(winTitle, TweenInfo.new(0.8), { TextTransparency = 0 }):Play()
			TweenService:Create(winSub, TweenInfo.new(0.8), { TextTransparency = 0 }):Play()
			task.delay(6, function()
				TweenService:Create(winOverlay, TweenInfo.new(1), { BackgroundTransparency = 1 }):Play()
				TweenService:Create(winTitle, TweenInfo.new(1), { TextTransparency = 1 }):Play()
				TweenService:Create(winSub, TweenInfo.new(1), { TextTransparency = 1 }):Play()
				task.wait(1)
				winOverlay.Visible = false
			end)
		end
		wasWon = data.won
	end

	-- ===== уведомления =====
	local toasts = Theme.frame(gui, UDim2.fromOffset(440, 220), UDim2.new(0.5, 0, 0, 54), Theme.bg)
	toasts.AnchorPoint = Vector2.new(0.5, 0)
	toasts.BackgroundTransparency = 1
	local toastLayout = Instance.new("UIListLayout")
	toastLayout.Padding = UDim.new(0, 6)
	toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	toastLayout.Parent = toasts

	local function notify(text: string, kind: string?)
		local color = KIND_COLORS[kind or "info"] or Theme.accent
		local toast = Theme.label(toasts, text, UDim2.fromOffset(420, 44), nil, {
			BackgroundTransparency = 0.12,
			BackgroundColor3 = Theme.bg,
			TextSize = 14,
			TextYAlignment = Enum.TextYAlignment.Center,
			AutomaticSize = Enum.AutomaticSize.Y,
		})
		Theme.corner(toast, 10)
		Theme.stroke(toast, color, 2)
		Theme.padding(toast, 8)
		-- не больше четырёх одновременно: старые убираем сразу
		local shown = {}
		for _, child in toasts:GetChildren() do
			if child:IsA("TextLabel") then
				table.insert(shown, child)
			end
		end
		while #shown > 4 do
			local old = table.remove(shown, 1)
			if old then
				old:Destroy()
			end
		end
		task.delay(5, function()
			if toast.Parent then
				local tween = TweenService:Create(toast, TweenInfo.new(0.5), { BackgroundTransparency = 1, TextTransparency = 1 })
				tween:Play()
				tween.Completed:Wait()
				toast:Destroy()
			end
		end)
	end
	Remotes.Notify.OnClientEvent:Connect(function(data)
		notify(data.text, data.kind)
	end)

	-- ===== название зоны =====
	local zoneLabel = Theme.label(gui, "", UDim2.fromOffset(700, 60), UDim2.new(0.5, 0, 0.22, 0), {
		Font = Enum.Font.GothamBlack,
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextStrokeTransparency = 0.3,
		TextTransparency = 1,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
	})
	zoneLabel.AnchorPoint = Vector2.new(0.5, 0.5)

	local function showZone(name: string)
		zoneLabel.Text = name
		zoneLabel.TextTransparency = 0
		zoneLabel.TextStrokeTransparency = 0.3
		task.delay(2.5, function()
			if zoneLabel.Text == name then
				TweenService:Create(zoneLabel, TweenInfo.new(1), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			end
		end)
	end

	-- ===== подсказка в лобби / победа =====
	local phaseLabel = Theme.label(gui, "", UDim2.fromOffset(640, 70), UDim2.new(0.5, 0, 0.35, 0), {
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextStrokeTransparency = 0.5,
	})
	phaseLabel.AnchorPoint = Vector2.new(0.5, 0.5)

	local function refresh()
		local data = State.data
		local inGame = State.phase ~= "lobby"
		ring.Visible = inGame and not TouchControls.isTouchDevice() -- на телефоне кнопки справа (TouchControls)
		handFrame.Visible = inGame
		top.Visible = inGame
		effectsLabel.Visible = inGame
		if data then
			yenLabel.Text = ("%s  ·  %d/100 карт"):format(Util.formatYen(data.yen), #data.slots)
		else
			yenLabel.Text = "Загрузка…"
		end
		if State.phase == "lobby" then
			phaseLabel.Text = "Реальный мир. Подойдите к JoyStation и нажмите E, чтобы войти в Greed Island."
			phaseLabel.Visible = true
		elseif State.phase == "win" then
			phaseLabel.Text = ""
			phaseLabel.Visible = false
		else
			phaseLabel.Visible = false
		end
		for name, button in stanceButtons do
			local active = State.stance == name
			button.BackgroundColor3 = active and Theme.accent or Theme.panelLight
			button.TextColor3 = active and Color3.fromRGB(10, 18, 26) or Theme.text
		end
	end
	State.changed.Event:Connect(function()
		refresh()
		refreshGoals()
		checkWin()
	end)
	refresh()
	refreshGoals()

	-- ===== периодические обновления: рука, эффекты, зона =====
	local lastZone: string? = nil
	local handButtons: { [number]: TextButton } = {}
	local handStrokes: { [number]: UIStroke } = {}
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.5 then
			return
		end
		accumulator = 0

		-- рука: кнопки не пересоздаём каждые полсекунды (нажатие не должно пропадать), а обновляем на месте
		local data = State.data
		local seen: { [number]: boolean } = {}
		if data and State.phase ~= "lobby" then
			for order, entry in data.hand do
				local card = Cards.get(entry.id)
				if card then
					seen[entry.uid] = true
					local left = State.handLeft(entry)
					local text = ("%s %s · %d с — вложить"):format(Cards.ICONS[card.kind] or "🎴", card.name, math.ceil(left))
					local button = handButtons[entry.uid]
					if not button then
						button = Theme.button(handFrame, text, UDim2.fromOffset(230, TouchControls.isTouchDevice() and 38 or 28), nil, Ranks.color(card.rank):Lerp(Theme.bg, 0.55))
						button.TextSize = TouchControls.isTouchDevice() and 13 or 12
						handStrokes[entry.uid] = Theme.stroke(button, Ranks.color(card.rank), 2)
						local uid = entry.uid
						button.Activated:Connect(function()
							Remotes.BinderAction:FireServer({ action = "insert", uid = uid })
						end)
						handButtons[entry.uid] = button
					end
					button.Text = text
					button.LayoutOrder = order
					handStrokes[entry.uid].Color = left < 15 and Theme.bad or Ranks.color(card.rank)
				end
			end
		end
		for uid, button in handButtons do
			if not seen[uid] then
				button:Destroy()
				handButtons[uid] = nil
				handStrokes[uid] = nil
			end
		end

		-- эффекты
		local lines = {}
		for _, effect in State.effects do
			local left = math.max(0, effect.seconds - math.floor(os.clock() - State.statusAt))
			if left > 0 then
				table.insert(lines, ("%s · %d с"):format(effect.name, left))
			end
		end
		effectsLabel.Text = table.concat(lines, "\n")

		-- зона
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and State.phase ~= "lobby" then
			local position = (root :: BasePart).Position
			local zone = Util.zoneAt(position.X, position.Z)
			if zone ~= lastZone then
				lastZone = zone
				if zone then
					showZone(Util.zoneName(zone))
				end
			end
		else
			lastZone = nil
		end
	end)

	return { notify = notify }
end

return Hud
