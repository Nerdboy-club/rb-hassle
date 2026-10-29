-- Книга: 100 указанных слотов, 45 свободных, рука, список встреченных игроков, справка.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CardUse = require(Shared.CardUse)
local Cards = require(Shared.Cards)
local Config = require(Shared.Config)
local Ranks = require(Shared.Ranks)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)
local Zones = require(Shared.Zones)

local CardView = require(script.Parent.CardView)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Theme)
local BookModel = require(script.Parent.BookModel)

local BookUI = {}

type Bind = { kind: string, id: number, uid: number? }

local KEY_NAMES: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.One] = "1",
	[Enum.KeyCode.Two] = "2",
	[Enum.KeyCode.Three] = "3",
	[Enum.KeyCode.Four] = "4",
	[Enum.KeyCode.Five] = "5",
	[Enum.KeyCode.Six] = "6",
	[Enum.KeyCode.Seven] = "7",
	[Enum.KeyCode.Eight] = "8",
	[Enum.KeyCode.Nine] = "9",
	[Enum.KeyCode.Zero] = "0",
	[Enum.KeyCode.Space] = "Пробел",
	[Enum.KeyCode.LeftShift] = "Shift",
	[Enum.KeyCode.RightShift] = "Shift",
	[Enum.KeyCode.LeftControl] = "Ctrl",
	[Enum.KeyCode.RightControl] = "Ctrl",
	[Enum.KeyCode.LeftAlt] = "Alt",
	[Enum.KeyCode.RightAlt] = "Alt",
	[Enum.KeyCode.Return] = "Enter",
	[Enum.KeyCode.Backspace] = "Backspace",
}

local RESERVED_KEYS: { [Enum.KeyCode]: boolean } = {
	[Enum.KeyCode.Tab] = true,
	[Enum.KeyCode.G] = true,
	[Enum.KeyCode.T] = true,
	[Enum.KeyCode.Y] = true,
	[Enum.KeyCode.E] = true,
	[Enum.KeyCode.Escape] = true,
	[Enum.KeyCode.Slash] = true,
	[Enum.KeyCode.Unknown] = true,
}

local function keyName(code: Enum.KeyCode): string
	return KEY_NAMES[code] or code.Name
end

local function cardName(id: number): string
	local card = Cards.get(id)
	return card and card.name or ("карта %d"):format(id)
end

local HELP = table.concat({
	"КАК ИГРАТЬ",
	"• Подберите предмет — он станет картой в руке. У вас минута, чтобы вложить её в книгу, иначе карта снова станет предметом.",
	"• Цель — заполнить все 100 слотов. Копии-дубликаты и карты заклинаний лежат в 45 свободных слотах.",
	"• У каждого ранга свой лимит копий на сервере: пока он выбран, предмет в карту не превращается. «Вернуть в исходное» освобождает лимит.",
	"• «Получить» (G) превращает карту в настоящую вещь: заклинание срабатывает, зелье лечит, йены попадают в кошелёк. Обратно в карту она уже не вернётся.",
	"• В книге можно закрепить карту за клавишей: «Добавить бинд» → выберите карту → нажмите клавишу. Бинд срабатывает только при открытой книге.",
	"• Тен (T) снижает урон от монстров, Зетсу (Y) скрывает вас от них. Пузырьковая лошадь ловится связкой «Зетсу, затем Тен».",
	"• Йены существуют только в виде карты «Кошелёк». Заклинания продаются лишь в Масадоре, особые карты Дориаса — только за азартные игры.",
	"• Закончите игру — заполните все 100 слотов (последняя карта — Благословение правителя в Лимейро). Выход — через башню Елены.",
}, "\n\n")

function BookUI.create(gui: ScreenGui, blocked: (() -> boolean)?)
	local isOpen = false
	local tab = "slots"
	local mode = "normal" -- "gain": подсказка про Получить
	local selected: { kind: string, id: number, uid: number? }? = nil
	local bindings: { [Enum.KeyCode]: Bind } = {}
	local bindMode = false
	local awaitingKey = false
	local pendingBind: Bind? = nil
	local lastBindUse = 0
	local isBlocked = blocked or function()
		return false
	end

	local root = Theme.frame(gui, UDim2.fromOffset(960, 600), UDim2.fromScale(0.5, 0.5), Theme.bg)
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Visible = false
	root.ZIndex = 10
	Theme.corner(root, 16)
	Theme.stroke(root, Theme.accent, 2)

	local scale = Instance.new("UIScale")
	scale.Parent = root

	local title = Theme.label(root, "📖 Книга", UDim2.fromOffset(300, 30), UDim2.fromOffset(18, 10), {
		Font = Enum.Font.GothamBold,
		TextSize = 22,
	})
	local stats = Theme.label(root, "", UDim2.fromOffset(520, 20), UDim2.fromOffset(18, 40), {
		TextSize = 13,
		TextColor3 = Theme.muted,
	})

	local closeButton = Theme.button(root, "✕", UDim2.fromOffset(36, 32), UDim2.new(1, -50, 0, 10), Theme.panelLight)

	-- вкладки
	local tabsFrame = Theme.frame(root, UDim2.fromOffset(560, 30), UDim2.new(1, -620, 0, 10), Theme.bg)
	tabsFrame.BackgroundTransparency = 1
	local tabsLayout = Instance.new("UIListLayout")
	tabsLayout.FillDirection = Enum.FillDirection.Horizontal
	tabsLayout.Padding = UDim.new(0, 4)
	tabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	tabsLayout.Parent = tabsFrame

	-- рука
	local handFrame = Theme.frame(root, UDim2.new(1, -36, 0, 54), UDim2.fromOffset(18, 70), Theme.panel)
	Theme.corner(handFrame, 10)
	local handLabel = Theme.label(handFrame, "В руке", UDim2.fromOffset(60, 54), UDim2.fromOffset(10, 0), {
		TextYAlignment = Enum.TextYAlignment.Center,
		TextColor3 = Theme.muted,
		Font = Enum.Font.GothamMedium,
	})
	local handRow = Theme.frame(handFrame, UDim2.new(1, -80, 1, 0), UDim2.fromOffset(70, 0), Theme.panel)
	handRow.BackgroundTransparency = 1
	local handLayout = Instance.new("UIListLayout")
	handLayout.FillDirection = Enum.FillDirection.Horizontal
	handLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	handLayout.Padding = UDim.new(0, 8)
	handLayout.Parent = handRow

	-- тело
	local body = Theme.frame(root, UDim2.new(1, -36, 1, -148), UDim2.fromOffset(18, 132), Theme.panel)
	Theme.corner(body, 12)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -290, 1, -16)
	scroll.Position = UDim2.fromOffset(8, 8)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = body

	local detail = Theme.frame(body, UDim2.fromOffset(266, 520), UDim2.new(1, -274, 0, 8), Theme.panel)
	detail.BackgroundTransparency = 1

	local banner = Theme.label(root, "", UDim2.fromOffset(600, 20), UDim2.fromOffset(18, 114), {
		TextColor3 = Theme.gold,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
	})

	local bindButton = Theme.button(root, "＋ Добавить бинд", UDim2.fromOffset(170, 22), UDim2.new(1, -188, 0, 109), Theme.panelLight)
	bindButton.TextSize = 12

	local confirm = Theme.frame(root, UDim2.fromScale(1, 1), nil, Color3.fromRGB(0, 0, 0))
	confirm.BackgroundTransparency = 0.45
	confirm.Visible = false
	confirm.Active = true
	confirm.ZIndex = 30
	Theme.corner(confirm, 16)

	local keyPrompt = Theme.frame(root, UDim2.fromScale(1, 1), nil, Color3.fromRGB(0, 0, 0))
	keyPrompt.BackgroundTransparency = 0.45
	keyPrompt.Visible = false
	keyPrompt.ZIndex = 24
	keyPrompt.Active = true
	Theme.corner(keyPrompt, 16)
	local keyBox = Theme.frame(keyPrompt, UDim2.fromOffset(440, 160), UDim2.fromScale(0.5, 0.5), Theme.panel)
	keyBox.AnchorPoint = Vector2.new(0.5, 0.5)
	keyBox.ZIndex = 25
	Theme.corner(keyBox, 12)
	Theme.stroke(keyBox, Theme.accent, 2)
	local keyTitle = Theme.label(keyBox, "", UDim2.new(1, -32, 0, 28), UDim2.fromOffset(16, 14), {
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = Theme.gold,
	})
	keyTitle.ZIndex = 26
	local keyHint = Theme.label(keyBox, "", UDim2.new(1, -32, 0, 48), UDim2.fromOffset(16, 48), {
		TextSize = 14,
		TextColor3 = Theme.muted,
	})
	keyHint.ZIndex = 26
	local keyCancel = Theme.button(keyBox, "Отмена", UDim2.fromOffset(180, 34), UDim2.new(0.5, -90, 1, -46), Theme.panelLight)
	keyCancel.ZIndex = 26

	local function clear(container: Instance)
		for _, child in container:GetChildren() do
			if not child:IsA("UIPadding") then
				child:Destroy()
			end
		end
	end

	local function ask(text: string, onYes: () -> ())
		clear(confirm)
		confirm.Visible = true
		local box = Theme.frame(confirm, UDim2.fromOffset(440, 170), UDim2.fromScale(0.5, 0.5), Theme.panel)
		box.AnchorPoint = Vector2.new(0.5, 0.5)
		box.ZIndex = 31
		Theme.corner(box, 12)
		Theme.stroke(box, Theme.warn, 2)
		local message = Theme.label(box, text, UDim2.new(1, -32, 0, 90), UDim2.fromOffset(16, 14), {
			TextSize = 15,
		})
		message.ZIndex = 32
		local yes = Theme.button(box, "Да", UDim2.fromOffset(190, 36), UDim2.fromOffset(16, 118), Theme.good)
		yes.TextColor3 = Color3.fromRGB(10, 20, 14)
		yes.ZIndex = 32
		local no = Theme.button(box, "Отмена", UDim2.fromOffset(190, 36), UDim2.fromOffset(234, 118), Theme.panelLight)
		no.ZIndex = 32
		yes.Activated:Connect(function()
			confirm.Visible = false
			onYes()
		end)
		no.Activated:Connect(function()
			confirm.Visible = false
		end)
	end

	local render: () -> ()

	local function findOwned(bind: Bind): boolean
		local data = State.data
		if not data then
			return false
		end
		if bind.kind == "slot" then
			return State.ownsSlot(bind.id)
		end
		for _, entry in data.free do
			if entry.uid == bind.uid and entry.id == bind.id then
				return true
			end
		end
		return false
	end

	local function pruneBindings()
		if not State.data then
			return
		end
		for code, bind in bindings do
			if not findOwned(bind) then
				bindings[code] = nil
			end
		end
	end

	local function resetBindFlow()
		bindMode = false
		awaitingKey = false
		pendingBind = nil
		keyPrompt.Visible = false
	end

	local function closeKeyPrompt()
		resetBindFlow()
		render()
	end

	local function askKey(bind: Bind)
		bindMode = false
		pendingBind = bind
		awaitingKey = true
		selected = { kind = bind.kind, id = bind.id, uid = bind.uid }
		keyTitle.Text = ("Клавиша для «%s»"):format(cardName(bind.id))
		keyHint.Text = "Нажмите клавишу. Бинд работает только при открытой книге и сразу использует карту."
		keyPrompt.Visible = true
		render()
	end

	local function useBind(bind: Bind, code: Enum.KeyCode)
		local now = os.clock()
		if now - lastBindUse < 0.6 then
			return
		end
		lastBindUse = now
		if not findOwned(bind) then
			bindings[code] = nil
			render()
			banner.Text = ("Карта «%s» больше не в книге — бинд снят."):format(cardName(bind.id))
			return
		end
		selected = { kind = bind.kind, id = bind.id, uid = bind.uid }
		Remotes.BinderAction:FireServer({
			action = "gain",
			slot = bind.kind == "slot" and bind.id or nil,
			uid = bind.uid,
		})
		render()
		banner.Text = ("Бинд сработал: «%s»."):format(cardName(bind.id))
	end

	keyCancel.Activated:Connect(closeKeyPrompt)

	local function select(kind: string, id: number, uid: number?)
		if bindMode then
			local card = Cards.get(id)
			if not card then
				return
			end
			local owned = kind == "free" or State.ownsSlot(id)
			if not owned then
				return
			end
			if not CardUse.usable(card) then
				banner.Text = "У этой карты нет эффекта — выберите другую."
				return
			end
			askKey({ kind = kind, id = id, uid = uid })
			return
		end
		selected = { kind = kind, id = id, uid = uid }
		render()
	end

	local function renderDetail()
		clear(detail)
		local data = State.data
		if not selected or not data then
			Theme.label(detail, "Выберите карту.", UDim2.fromScale(1, 0.2), nil, { TextColor3 = Theme.muted, TextSize = 14 })
			return
		end
		local card = Cards.get(selected.id)
		if not card then
			return
		end
		local owned = selected.kind == "free" or State.ownsSlot(selected.id)
		CardView.big(detail, selected.id, owned, UDim2.fromOffset(250, 320))
		if not owned then
			return
		end

		local y = 332
		local function action(text: string, color: Color3, callback: () -> ())
			local button = Theme.button(detail, text, UDim2.fromOffset(250, 34), UDim2.fromOffset(0, y), color)
			y += 40
			button.Activated:Connect(callback)
			return button
		end

		local payload = { slot = selected.kind == "slot" and selected.id or nil, uid = selected.uid }
		local canRelease = card.numbered and card.id ~= Cards.BLESSING_ID
		if canRelease then
			action("↩ Вернуть в исходное", Theme.panelLight, function()
				ask(
					"Карта снова станет предметом на острове, а лимит копий этого ранга освободится. Вернуть?",
					function()
						Remotes.BinderAction:FireServer({ action = "release", slot = payload.slot, uid = payload.uid })
						selected = nil
					end
				)
			end)
		end
		if card.kind ~= "wallet" and card.id ~= Cards.BLESSING_ID and CardUse.usable(card) then
			local gainColor = mode == "gain" and Theme.gold or Theme.panelLight
			local button = action(card.spell and "✨ Использовать заклинание" or "✨ Получить", gainColor, function()
				local text = card.spell and ("Прочитать заклинание «%s»? Карта израсходуется."):format(card.name)
					or ("«%s» станет настоящей вещью и больше не вернётся в карту. Продолжить?"):format(card.name)
				ask(text, function()
					Remotes.BinderAction:FireServer({ action = "gain", slot = payload.slot, uid = payload.uid })
					selected = nil
				end)
			end)
			if mode == "gain" then
				button.TextColor3 = Color3.fromRGB(20, 18, 8)
			end
		end
	end

	local function cell(parent: Instance, text: string, color: Color3?, strokeColor: Color3?, isSelected: boolean, onClick: () -> ()): TextButton
		local button = Instance.new("TextButton")
		button.Text = text
		button.BackgroundColor3 = color or Theme.panelLight
		button.TextColor3 = Theme.text
		button.Font = Enum.Font.GothamMedium
		button.TextSize = 13
		button.AutoButtonColor = true
		button.BorderSizePixel = 0
		button.Parent = parent
		Theme.corner(button, 8)
		if strokeColor or isSelected then
			Theme.stroke(button, isSelected and Color3.fromRGB(255, 255, 255) or (strokeColor :: Color3), isSelected and 3 or 2)
		end
		button.Activated:Connect(onClick)
		return button
	end

	local renderMap: () -> ()
	local renderRanks: (any) -> ()

	local function renderBinds()
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 8)
		layout.Parent = scroll
		Theme.label(scroll, "Бинды карт", UDim2.new(1, -12, 0, 24), nil, {
			Font = Enum.Font.GothamBold,
			TextSize = 17,
		})
		Theme.label(
			scroll,
			"Нажмите «Добавить бинд», выберите карту и клавишу. Бинд работает только при открытой книге и сразу использует карту.",
			UDim2.new(1, -12, 0, 40),
			nil,
			{ TextSize = 13, TextColor3 = Theme.muted }
		)
		local ordered: { { code: Enum.KeyCode, bind: Bind } } = {}
		for code, bind in bindings do
			table.insert(ordered, { code = code, bind = bind })
		end
		table.sort(ordered, function(a, b)
			return keyName(a.code) < keyName(b.code)
		end)
		if #ordered == 0 then
			Theme.label(scroll, "Пока нет биндов.", UDim2.new(1, -12, 0, 30), nil, { TextColor3 = Theme.muted })
			return
		end
		for index, entry in ordered do
			local bind = entry.bind
			local row = Theme.frame(scroll, UDim2.new(1, -12, 0, 44), nil, Theme.panelLight)
			row.LayoutOrder = index
			Theme.corner(row, 8)
			Theme.label(
				row,
				("%s — %s"):format(keyName(entry.code), cardName(bind.id)),
				UDim2.new(1, -190, 0, 20),
				UDim2.fromOffset(10, 4),
				{ Font = Enum.Font.GothamBold, TextSize = 14 }
			)
			local place = bind.kind == "slot" and ("Слот %d"):format(bind.id) or "Свободный слот"
			Theme.label(row, place, UDim2.new(1, -190, 0, 16), UDim2.fromOffset(10, 24), {
				TextSize = 12,
				TextColor3 = Theme.muted,
			})
			local use = Theme.button(row, "Использовать", UDim2.fromOffset(100, 28), UDim2.new(1, -170, 0, 8), Theme.good)
			use.TextSize = 12
			use.Activated:Connect(function()
				useBind(bind, entry.code)
			end)
			local remove = Theme.button(row, "Снять", UDim2.fromOffset(60, 28), UDim2.new(1, -64, 0, 8), Theme.panel)
			remove.TextSize = 12
			remove.Activated:Connect(function()
				bindings[entry.code] = nil
				render()
			end)
		end
	end

	local function renderGrid()
		clear(scroll)
		local data = State.data
		if not data then
			return
		end

		if tab == "slots" then
			local layout = Instance.new("UIGridLayout")
			layout.CellSize = UDim2.fromOffset(52, 66)
			layout.CellPadding = UDim2.fromOffset(5, 5)
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Parent = scroll
			for index = 1, Config.NumberedSlots do
				local card = Cards.get(index) :: Cards.Card
				local owned = table.find(data.slots, index) ~= nil
				local rankColor = Ranks.color(card.rank)
				local text = owned and ("%d\n%s"):format(index, Cards.ICONS[card.kind] or "🎴") or ("%d\n·"):format(index)
				local button = cell(
					scroll,
					text,
					owned and rankColor:Lerp(Theme.bg, 0.7) or Theme.panelLight,
					owned and rankColor or nil,
					selected ~= nil and selected.kind == "slot" and selected.id == index,
					function()
						select("slot", index)
					end
				)
				button.LayoutOrder = index
				button.TextColor3 = owned and Theme.text or Theme.muted
			end
		elseif tab == "free" then
			local layout = Instance.new("UIGridLayout")
			layout.CellSize = UDim2.fromOffset(98, 70)
			layout.CellPadding = UDim2.fromOffset(5, 5)
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Parent = scroll
			for index = 1, Config.FreeSlots do
				local entry = data.free[index]
				if entry then
					local card = Cards.get(entry.id) :: Cards.Card
					local rankColor = Ranks.color(card.rank)
					local label = card.numbered and ("№%d %s"):format(card.id, card.name) or card.name
					local button = cell(
						scroll,
						(Cards.ICONS[card.kind] or "🎴") .. "\n" .. label,
						rankColor:Lerp(Theme.bg, 0.72),
						rankColor,
						selected ~= nil and selected.kind == "free" and selected.uid == entry.uid,
						function()
							select("free", entry.id, entry.uid)
						end
					)
					button.TextSize = 11
					button.TextWrapped = true
					button.LayoutOrder = index
				else
					local button = cell(scroll, "·", Theme.panelLight, nil, false, function() end)
					button.TextColor3 = Theme.muted
					button.LayoutOrder = index
				end
			end
		elseif tab == "binds" then
			renderBinds()
		elseif tab == "map" then
			renderMap()
		elseif tab == "ranks" then
			renderRanks(data)
		elseif tab == "players" then
			local lines = { ("Встречено игроков: %d"):format(#data.met), "" }
			for _, name in data.met do
				table.insert(lines, "• " .. name)
			end
			if #data.met == 0 then
				table.insert(lines, "Пока никого. Подойдите к другому игроку на острове — его имя появится здесь.")
			end
			Theme.label(scroll, table.concat(lines, "\n"), UDim2.new(1, -12, 0, 400), nil, { TextSize = 15 })
		elseif tab == "help" then
			Theme.label(scroll, HELP, UDim2.new(1, -16, 0, 800), nil, { TextSize = 14 })
		elseif tab == "case" then
			local layout = Instance.new("UIListLayout")
			layout.Padding = UDim.new(0, 8)
			layout.Parent = scroll
			Theme.label(scroll, "Футляр на три слота — единственное, что можно вынести из игры.", UDim2.new(1, -12, 0, 30), nil, {
				TextColor3 = Theme.gold,
			})
			for _, id in data.case do
				local card = Cards.get(id)
				if card then
					Theme.label(
						scroll,
						("%s  №%d  %s  (ранг %s)"):format(Cards.ICONS[card.kind] or "🎴", card.id, card.name, card.rank),
						UDim2.new(1, -12, 0, 26),
						nil,
						{ TextSize = 16, TextColor3 = Ranks.color(card.rank) }
					)
				end
			end
		end
	end

	-- кнопки руки обновляются на месте: пересоздание каждые полсекунды съедало нажатия
	local handButtons: { [number]: TextButton } = {}
	local handStrokes: { [number]: UIStroke } = {}
	local handEmpty: TextLabel? = nil

	local function renderHand()
		local data = State.data
		local seen: { [number]: boolean } = {}
		if data then
			for order, entry in data.hand do
				local card = Cards.get(entry.id) :: Cards.Card
				seen[entry.uid] = true
				local left = State.handLeft(entry)
				local rankColor = Ranks.color(card.rank)
				local text = ("%s %s · %d с\nвложить"):format(Cards.ICONS[card.kind] or "🎴", card.name, math.ceil(left))
				local button = handButtons[entry.uid]
				if not button then
					button = Theme.button(handRow, text, UDim2.fromOffset(180, 42), nil, rankColor:Lerp(Theme.bg, 0.55))
					button.TextSize = 12
					handStrokes[entry.uid] = Theme.stroke(button, rankColor, 2)
					local uid = entry.uid
					button.Activated:Connect(function()
						Remotes.BinderAction:FireServer({ action = "insert", uid = uid })
					end)
					handButtons[entry.uid] = button
				end
				button.Text = text
				button.LayoutOrder = order
				handStrokes[entry.uid].Color = left < 15 and Theme.bad or rankColor
			end
		end
		for uid, button in handButtons do
			if not seen[uid] then
				button:Destroy()
				handButtons[uid] = nil
				handStrokes[uid] = nil
			end
		end
		local empty = data ~= nil and #data.hand == 0
		if empty and not handEmpty then
			handEmpty = Theme.label(handRow, "пусто — подберите предмет на острове", UDim2.fromOffset(300, 54), nil, {
				TextColor3 = Theme.muted,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextSize = 13,
			})
		elseif not empty and handEmpty then
			handEmpty:Destroy()
			handEmpty = nil
		end
	end

	local mapMarker: Frame? = nil
	local MAP_SIZE = 500
	local MAP_SCALE = MAP_SIZE / 1900

	local function mapPosition(x: number, z: number): UDim2
		return UDim2.fromOffset(MAP_SIZE / 2 + x * MAP_SCALE, MAP_SIZE / 2 + z * MAP_SCALE)
	end

	renderMap = function()
		local holder = Theme.frame(scroll, UDim2.fromOffset(MAP_SIZE, MAP_SIZE), UDim2.fromOffset(10, 0), Color3.fromRGB(46, 120, 170))
		Theme.corner(holder, MAP_SIZE / 2)
		local island = Theme.frame(holder, UDim2.fromOffset(1760 * MAP_SCALE, 1760 * MAP_SCALE), UDim2.fromOffset(MAP_SIZE / 2, MAP_SIZE / 2), Color3.fromRGB(120, 190, 100))
		island.AnchorPoint = Vector2.new(0.5, 0.5)
		Theme.corner(island, MAP_SIZE)
		for key, zone in Zones do
			if key ~= "Coast" then
				local size = zone.r * 2 * MAP_SCALE
				local disc = Theme.frame(holder, UDim2.fromOffset(size, size), mapPosition(zone.x, zone.z), zone.color)
				disc.AnchorPoint = Vector2.new(0.5, 0.5)
				disc.BackgroundTransparency = zone.kind == "town" and 0.1 or 0.55
				Theme.corner(disc, size)
				local short = string.split(zone.name, " — ")[1]
				local label = Theme.label(holder, short, UDim2.fromOffset(110, 14), mapPosition(zone.x, zone.z), {
					TextSize = 10,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Center,
					TextStrokeTransparency = 0.4,
				})
				label.AnchorPoint = Vector2.new(0.5, 0.5)
				label.ZIndex = 3
			end
		end
		local marker = Theme.frame(holder, UDim2.fromOffset(12, 12), mapPosition(0, 0), Theme.bad)
		marker.AnchorPoint = Vector2.new(0.5, 0.5)
		marker.ZIndex = 5
		Theme.corner(marker, 6)
		Theme.stroke(marker, Color3.fromRGB(255, 255, 255), 2)
		mapMarker = marker
		scroll.CanvasSize = UDim2.fromOffset(0, MAP_SIZE + 10)
	end

	renderRanks = function(data: any)
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 8)
		layout.Parent = scroll
		Theme.label(scroll, "Прогресс по рангам", UDim2.new(1, -12, 0, 24), nil, { Font = Enum.Font.GothamBold, TextSize = 17 })
		for _, rank in Ranks.order do
			local total, owned = 0, 0
			for _, id in Cards.numberedIds do
				local card = Cards.get(id) :: Cards.Card
				if card.rank == rank then
					total += 1
					if table.find(data.slots, id) then
						owned += 1
					end
				end
			end
			local row = Theme.frame(scroll, UDim2.new(1, -12, 0, 30), nil, Theme.panelLight)
			Theme.corner(row, 8)
			local fill = Theme.frame(row, UDim2.fromScale(total > 0 and owned / total or 0, 1), nil, Ranks.color(rank))
			fill.BackgroundTransparency = 0.35
			Theme.corner(fill, 8)
			Theme.label(row, ("%s   %d / %d   ·   лимит копий на сервере: %d"):format(rank, owned, total, Ranks.limit(rank)), UDim2.new(1, -16, 1, 0), UDim2.fromOffset(10, 0), {
				TextYAlignment = Enum.TextYAlignment.Center,
				Font = Enum.Font.GothamMedium,
				TextSize = 13,
			})
		end
	end

	local tabButtons: { [string]: TextButton } = {}

	local function renderTabs()
		local data = State.data
		local list = {
			{ id = "slots", label = "Карты" },
			{ id = "free", label = "Свободные" },
			{ id = "binds", label = "Бинды" },
			{ id = "map", label = "Карта" },
			{ id = "ranks", label = "Ранги" },
			{ id = "players", label = "Игроки" },
			{ id = "help", label = "Справка" },
		}
		if data and data.won and #data.case > 0 then
			table.insert(list, { id = "case", label = "Футляр" })
		end
		for _, button in tabButtons do
			button:Destroy()
		end
		table.clear(tabButtons)
		for index, entry in list do
			local button = Theme.button(tabsFrame, entry.label, UDim2.fromOffset(66, 30), nil, tab == entry.id and Theme.accent or Theme.panelLight)
			button.LayoutOrder = index
			button.TextSize = 12
			button.TextColor3 = tab == entry.id and Color3.fromRGB(10, 18, 26) or Theme.text
			button.Activated:Connect(function()
				tab = entry.id
				selected = nil
				bindMode = false
				render()
			end)
			tabButtons[entry.id] = button
		end
	end

	render = function()
		pruneBindings()
		local data = State.data
		if data then
			local owned = #data.slots
			stats.Text = ("Карт: %d/%d  ·  свободных слотов: %d/%d  ·  %s"):format(
				owned,
				Config.NumberedSlots,
				#data.free,
				Config.FreeSlots,
				Util.formatYen(data.yen)
			)
		else
			stats.Text = "Загрузка…"
		end
		bindButton.Text = bindMode and "✕ Отмена бинда" or "＋ Добавить бинд"
		bindButton.BackgroundColor3 = bindMode and Theme.warn or Theme.panelLight
		if awaitingKey and pendingBind then
			banner.Text = ("Нажмите клавишу для «%s». Esc — отмена."):format(cardName(pendingBind.id))
		elseif bindMode then
			banner.Text = "Выберите карту для бинда, затем нажмите клавишу."
		elseif mode == "gain" then
			banner.Text = "Выберите карту и нажмите «Получить» — она превратится в настоящую вещь."
		else
			banner.Text = ""
		end
		renderTabs()
		renderHand()
		renderGrid()
		renderDetail()
	end

	local function setOpen(open: boolean)
		if open == isOpen then
			return
		end
		isOpen = open
		if open then
			-- сначала из вспышки появляется книга, затем раскрывается окно
			pcall(BookModel.show)
			Remotes.BinderAction:FireServer({ action = "sync" })
			render()
			task.delay(BookModel.openSeconds * 0.8, function()
				if isOpen then
					root.Visible = true
				end
			end)
		else
			root.Visible = false
			pcall(BookModel.hide)
			confirm.Visible = false
			resetBindFlow()
			mode = "normal"
		end
	end

	closeButton.Activated:Connect(function()
		setOpen(false)
	end)

	bindButton.Activated:Connect(function()
		if bindMode then
			bindMode = false
			render()
			return
		end
		if not State.data then
			return
		end
		if not UserInputService.KeyboardEnabled then
			banner.Text = "Для бинда карт нужна клавиатура."
			return
		end
		bindMode = true
		selected = nil
		mode = "normal"
		if tab ~= "slots" and tab ~= "free" then
			tab = "slots"
		end
		render()
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not isOpen or not root.Visible then
			return
		end
		if awaitingKey then
			if input.UserInputType ~= Enum.UserInputType.Keyboard then
				return
			end
			local code = input.KeyCode
			if code == Enum.KeyCode.Escape then
				closeKeyPrompt()
				return
			end
			if code == Enum.KeyCode.Unknown then
				return
			end
			if RESERVED_KEYS[code] then
				keyHint.Text = ("Клавиша %s занята игрой. Нажмите другую."):format(keyName(code))
				return
			end
			local existing = bindings[code]
			if existing then
				keyHint.Text = ("%s уже занята картой «%s». Нажмите другую."):format(keyName(code), cardName(existing.id))
				return
			end
			local bind = pendingBind
			if not bind then
				closeKeyPrompt()
				return
			end
			bindings[code] = bind
			pendingBind = nil
			awaitingKey = false
			keyPrompt.Visible = false
			selected = { kind = bind.kind, id = bind.id, uid = bind.uid }
			mode = "normal"
			tab = "binds"
			render()
			return
		end
		if confirm.Visible then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape and bindMode then
			bindMode = false
			render()
			return
		end
		if bindMode or isBlocked() then
			return
		end
		local bind = bindings[input.KeyCode]
		if bind then
			useBind(bind, input.KeyCode)
		end
	end)

	-- только новый снимок книги перерисовывает окно: эффекты и стойки (приходят каждые полсекунды) не должны сбрасывать прокрутку
	State.dataChanged.Event:Connect(function()
		if isOpen then
			render()
		end
	end)

	-- таймеры карт в руке тикают без запросов к серверу
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if isOpen and accumulator >= 0.5 then
			accumulator = 0
			renderHand()
			if tab == "map" and mapMarker then
				local character = game:GetService("Players").LocalPlayer.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root then
					local position = (root :: BasePart).Position
					mapMarker.Position = mapPosition(position.X, position.Z)
				end
			end
		end
	end)

	-- на узких экранах окно уменьшается
	local function fit()
		local camera = workspace.CurrentCamera
		if camera then
			local size = camera.ViewportSize
			scale.Scale = math.clamp(math.min(size.X / 1000, size.Y / 640), 0.5, 1)
		end
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end

	title.Text = "📖 Книга"
	handLabel.Text = "В руке"

	return {
		toggle = function()
			setOpen(not isOpen)
		end,
		open = function(openMode: string?)
			resetBindFlow()
			mode = openMode or "normal"
			if mode == "gain" then
				tab = "free"
			end
			setOpen(true)
			render()
		end,
		close = function()
			setOpen(false)
		end,
		isOpen = function()
			return isOpen
		end,
		isCapturingKey = function()
			return awaitingKey
		end,
	}
end

return BookUI
