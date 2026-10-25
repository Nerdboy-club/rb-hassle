-- Арены редких боссов: меню у портала (соло / группа друзей / случайные игроки) и панель идущего боя.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)

local ArenaUI = {}

local SIZE_NAMES = { [2] = "Дуо", [3] = "Трио", [4] = "Квартет" }

local function send(action: string, extra: { [string]: any }?)
	local payload = { action = action }
	for key, value in extra or {} do
		payload[key] = value
	end
	Remotes.ArenaAction:FireServer(payload)
end

function ArenaUI.create(gui: ScreenGui)
	-- ===== меню у портала =====
	local panel = Theme.frame(gui, UDim2.fromOffset(580, 520), UDim2.fromScale(0.5, 0.5), Theme.panel)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Visible = false
	panel.ZIndex = 12
	Theme.corner(panel, 14)
	Theme.stroke(panel, Theme.accent, 2)
	local scale = Instance.new("UIScale")
	scale.Parent = panel

	local title = Theme.label(panel, "", UDim2.new(1, -90, 0, 28), UDim2.fromOffset(16, 10), {
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		TextColor3 = Theme.gold,
	})
	local closeButton = Theme.button(panel, "✕", UDim2.fromOffset(34, 30), UDim2.new(1, -46, 0, 10), Theme.panelLight)
	closeButton.Activated:Connect(function()
		send("close")
	end)

	local body = Instance.new("ScrollingFrame")
	body.Size = UDim2.new(1, -24, 1, -56)
	body.Position = UDim2.fromOffset(12, 46)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 5
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.Parent = panel
	local bodyLayout = Instance.new("UIListLayout")
	bodyLayout.Padding = UDim.new(0, 8)
	bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	bodyLayout.Parent = body

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local function text(content: string, color: Color3?, size: number?, height: number?): TextLabel
		local label = Theme.label(body, content, UDim2.new(1, -8, 0, height or 20), nil, {
			TextSize = size or 13,
			TextColor3 = color or Theme.text,
			AutomaticSize = Enum.AutomaticSize.Y,
		})
		label.LayoutOrder = nextOrder()
		return label
	end
	local function heading(content: string)
		local label = text(content, Theme.accent, 15, 22)
		label.Font = Enum.Font.GothamBold
	end
	local function row(): Frame
		local frame = Theme.frame(body, UDim2.new(1, -8, 0, 34), nil, Theme.panel)
		frame.BackgroundTransparency = 1
		frame.LayoutOrder = nextOrder()
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, 8)
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Parent = frame
		return frame
	end
	local function button(parent: Instance, label: string, width: number, color: Color3?, callback: () -> ()): TextButton
		local created = Theme.button(parent, label, UDim2.fromOffset(width, 32), nil, color or Theme.panelLight)
		created.TextSize = 13
		created.Activated:Connect(callback)
		return created
	end

	local function render(data)
		for _, child in body:GetChildren() do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
		order = 0
		title.Text = ("Арена: %s"):format(data.bossName)

		if data.cardName then
			text(("Награда: карта «%s» (ранг %s). Свободных арен: %d."):format(data.cardName, data.cardRank, data.freeSlots), Theme.text, 13)
		end
		text("У каждой группы своя копия босса. HP растёт с размером группы (×" .. table.concat(data.scale, " ·×") .. "). Добыча делится по вкладу в урон, последний удар даёт +10% к доле. Убежать нельзя — только сдаться.", Theme.muted, 12)
		if not data.available then
			text(data.reason or "Босс недоступен.", Theme.warn, 13)
		end
		if data.cooldown and data.cooldown > 0 then
			text(("Новый вход возможен через %d с."):format(data.cooldown), Theme.warn, 13)
		end

		local blocked = (not data.available) or data.freeSlots <= 0 or (data.cooldown or 0) > 0

		heading("Соло")
		local soloRow = row()
		local solo = button(soloRow, "⚔ Начать бой один", 220, Theme.good, function()
			send("solo")
		end)
		solo.TextColor3 = Color3.fromRGB(12, 20, 14)
		solo.Active = not blocked and not data.party and not data.queued
		solo.AutoButtonColor = solo.Active

		heading("С друзьями")
		if data.party then
			text(("Ваша группа (%d/%d): %s"):format(#data.party.members, data.maxParty, table.concat(data.party.members, ", ")), Theme.text, 13)
			local partyRow = row()
			if data.isHost then
				local start = button(partyRow, "⚔ Начать бой группой", 220, Theme.good, function()
					send("start")
				end)
				start.TextColor3 = Color3.fromRGB(12, 20, 14)
				start.Active = not blocked
				start.AutoButtonColor = start.Active
			else
				text("Ждите, пока хозяин группы начнёт бой.", Theme.muted, 12)
			end
			button(partyRow, data.isHost and "Распустить группу" or "Выйти из группы", 170, Theme.bad, function()
				send("leave")
			end)
		elseif data.queued then
			text("Вы в очереди — группу создать нельзя.", Theme.muted, 12)
		else
			local createRow = row()
			button(createRow, "➕ Создать группу", 190, Theme.accent, function()
				send("create")
			end).TextColor3 = Color3.fromRGB(10, 18, 26)
			if #data.parties == 0 then
				text("Открытых групп пока нет. Создайте свою — друзья смогут вступить у этого портала.", Theme.muted, 12)
			end
			for _, party in data.parties do
				local line = row()
				Theme.label(line, ("%s: %s (%d/%d)"):format("Группа", table.concat(party.members, ", "), #party.members, data.maxParty), UDim2.fromOffset(330, 30), nil, {
					TextSize = 13,
					TextYAlignment = Enum.TextYAlignment.Center,
				})
				local join = button(line, "Вступить", 100, Theme.panelLight, function()
					send("join", { id = party.id })
				end)
				join.Active = #party.members < data.maxParty
				join.AutoButtonColor = join.Active
			end
		end

		heading("Случайные игроки")
		if data.queued then
			text(("Ищем игроков: %s. Если никто не найдётся за ~45 секунд, можно войти соло."):format(SIZE_NAMES[data.queued] or data.queued), Theme.muted, 12)
			local cancelRow = row()
			button(cancelRow, "Отменить поиск", 170, Theme.bad, function()
				send("unqueue")
			end)
		elseif data.party then
			text("Покиньте группу, чтобы встать в очередь.", Theme.muted, 12)
		else
			local queueRow = row()
			for size = 2, data.maxParty do
				local waiting = data.queueCounts[size] or 0
				local label = ("%s%s"):format(SIZE_NAMES[size] or size, waiting > 0 and (" · ждут: " .. waiting) or "")
				local queueButton = button(queueRow, label, 170, Theme.panelLight, function()
					send("queue", { size = size })
				end)
				queueButton.Active = not blocked
				queueButton.AutoButtonColor = queueButton.Active
			end
		end
	end

	Remotes.ArenaMenu.OnClientEvent:Connect(function(data)
		if data.close then
			panel.Visible = false
			return
		end
		panel.Visible = true
		render(data)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape and panel.Visible then
			send("close")
			panel.Visible = false
		end
	end)

	-- ===== панель идущего боя =====
	local fightPanel = Theme.frame(gui, UDim2.fromOffset(330, 74), UDim2.new(0.5, 0, 0, 96), Theme.bg)
	fightPanel.AnchorPoint = Vector2.new(0.5, 0)
	fightPanel.BackgroundTransparency = 0.12
	fightPanel.Visible = false
	fightPanel.ZIndex = 9
	Theme.corner(fightPanel, 10)
	Theme.stroke(fightPanel, Theme.warn, 2)
	local fightTitle = Theme.label(fightPanel, "", UDim2.new(1, -16, 0, 20), UDim2.fromOffset(10, 6), {
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = Theme.gold,
	})
	local fightInfo = Theme.label(fightPanel, "", UDim2.new(1, -120, 0, 40), UDim2.fromOffset(10, 28), {
		TextSize = 12,
		TextColor3 = Theme.muted,
	})
	local surrender = Theme.button(fightPanel, "🏳 Сдаться", UDim2.fromOffset(100, 30), UDim2.new(1, -108, 1, -38), Theme.bad)
	surrender.TextSize = 13
	surrender.Activated:Connect(function()
		send("surrender")
	end)

	Remotes.ArenaStatus.OnClientEvent:Connect(function(data)
		if not data.active then
			fightPanel.Visible = false
			return
		end
		fightPanel.Visible = true
		local minutes = math.floor(data.seconds / 60)
		local seconds = data.seconds % 60
		if data.won then
			fightTitle.Text = ("Победа над «%s»!"):format(data.boss)
			surrender.Visible = false
		else
			fightTitle.Text = ("⚔ %s · %d:%02d"):format(data.boss, minutes, seconds)
			surrender.Visible = true
		end
		fightInfo.Text = "Бойцы: " .. table.concat(data.members, ", ")
	end)

	local function fit()
		local camera = workspace.CurrentCamera
		if camera then
			scale.Scale = math.clamp(math.min(camera.ViewportSize.X / 640, camera.ViewportSize.Y / 560), 0.5, 1)
		end
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end

	return {
		isOpen = function()
			return panel.Visible
		end,
	}
end

return ArenaUI
