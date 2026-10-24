-- Окно лавки: слева «Купить», справа «Продать», сверху баланс.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Cards)
local Ranks = require(Shared.Ranks)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)

local Theme = require(script.Parent.Theme)

local ShopUI = {}

function ShopUI.create(gui: ScreenGui)
	local root = Theme.frame(gui, UDim2.fromOffset(780, 540), UDim2.fromScale(0.5, 0.5), Theme.bg)
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Visible = false
	root.ZIndex = 12
	Theme.corner(root, 16)
	Theme.stroke(root, Theme.gold, 2)

	local scale = Instance.new("UIScale")
	scale.Parent = root

	local title = Theme.label(root, "", UDim2.fromOffset(420, 30), UDim2.fromOffset(18, 12), {
		Font = Enum.Font.GothamBold,
		TextSize = 22,
	})
	local yenLabel = Theme.label(root, "", UDim2.fromOffset(240, 24), UDim2.new(1, -310, 0, 16), {
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Enum.Font.GothamMedium,
		TextSize = 16,
		TextColor3 = Theme.gold,
	})
	local closeButton = Theme.button(root, "✕", UDim2.fromOffset(36, 32), UDim2.new(1, -50, 0, 12))

	local infoButton = Theme.button(root, "", UDim2.fromOffset(260, 30), UDim2.fromOffset(18, 52), Theme.panelLight)
	infoButton.Visible = false

	local function column(titleText: string, x: number, width: number)
		Theme.label(root, titleText, UDim2.fromOffset(width, 22), UDim2.fromOffset(x, 92), {
			Font = Enum.Font.GothamMedium,
			TextColor3 = Theme.muted,
		})
		local scroll = Instance.new("ScrollingFrame")
		scroll.Size = UDim2.fromOffset(width, 400)
		scroll.Position = UDim2.fromOffset(x, 118)
		scroll.BackgroundColor3 = Theme.panel
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 6
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.CanvasSize = UDim2.new()
		scroll.Parent = root
		Theme.corner(scroll, 10)
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 6)
		layout.Parent = scroll
		Theme.padding(scroll, 6)
		return scroll
	end

	local buyColumn = column("Купить", 18, 460)
	local sellColumn = column("Продать", 492, 270)

	local currentShop: string? = nil

	local function clear(container: Instance)
		for _, child in container:GetChildren() do
			if child:IsA("Frame") or child:IsA("TextLabel") then
				child:Destroy()
			end
		end
	end

	local function row(parent: Instance, card: Cards.Card, subtitle: string, buttonText: string, enabled: boolean, onClick: () -> ())
		local frame = Theme.frame(parent, UDim2.new(1, -12, 0, 54), nil, Theme.panelLight)
		Theme.corner(frame, 8)
		local rankColor = Ranks.color(card.rank)
		Theme.stroke(frame, rankColor, 1)
		Theme.label(frame, (Cards.ICONS[card.kind] or "🎴") .. " " .. card.name, UDim2.new(1, -130, 0, 22), UDim2.fromOffset(8, 5), {
			Font = Enum.Font.GothamMedium,
			TextSize = 14,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		Theme.label(frame, subtitle, UDim2.new(1, -130, 0, 22), UDim2.fromOffset(8, 28), {
			TextSize = 12,
			TextColor3 = Theme.muted,
		})
		local button = Theme.button(frame, buttonText, UDim2.fromOffset(110, 34), UDim2.new(1, -118, 0.5, -17), enabled and Theme.good or Theme.panel)
		button.TextColor3 = enabled and Color3.fromRGB(10, 20, 14) or Theme.muted
		button.Active = enabled
		button.AutoButtonColor = enabled
		button.TextSize = 13
		button.Activated:Connect(function()
			if enabled then
				onClick()
			end
		end)
	end

	local function render(data: any)
		currentShop = data.shopId
		title.Text = data.name
		yenLabel.Text = Util.formatYen(data.yen)
		clear(buyColumn)
		clear(sellColumn)

		for _, item in data.buy do
			local card = Cards.get(item.id)
			if card then
				local sub = ("ранг %s · %s"):format(card.rank, Util.formatYen(item.price))
				local enabled = data.yen >= item.price and not item.locked
				local label = "Купить"
				if item.stock ~= nil then
					sub ..= (" · в наличии: %d"):format(item.stock)
					if item.stock <= 0 then
						enabled = false
						label = "Нет"
					end
				end
				if item.locked then
					sub = item.lockText or "недоступно"
					label = "🔒"
				end
				row(buyColumn, card, sub, label, enabled, function()
					Remotes.ShopAction:FireServer({ shopId = data.shopId, action = "buy", cardId = item.id })
				end)
			end
		end
		if #data.buy == 0 then
			Theme.label(buyColumn, "Лавка пуста.", UDim2.new(1, -12, 0, 24), nil, { TextColor3 = Theme.muted })
		end

		if data.spells then
			Theme.label(sellColumn, "Магазин спелл-карт ничего не выкупает. Запас заклинаний пополняется, когда карты используют.", UDim2.new(1, -12, 0, 100), nil, {
				TextColor3 = Theme.muted,
				TextSize = 13,
			})
		else
			for _, item in data.sell do
				local card = Cards.get(item.id)
				if card then
					row(sellColumn, card, "+" .. Util.formatYen(item.price), "Продать", true, function()
						Remotes.ShopAction:FireServer({ shopId = data.shopId, action = "sell", uid = item.uid })
					end)
				end
			end
			if #data.sell == 0 then
				Theme.label(sellColumn, "В свободных слотах нечего продавать.", UDim2.new(1, -12, 0, 40), nil, {
					TextColor3 = Theme.muted,
					TextSize = 13,
				})
			end
		end

		infoButton.Visible = data.info == true
		infoButton.Text = ("🕵 Купить информацию — %s"):format(Util.formatYen(data.infoPrice))
	end

	infoButton.Activated:Connect(function()
		if currentShop then
			Remotes.ShopAction:FireServer({ shopId = currentShop, action = "info" })
		end
	end)

	local function close()
		if currentShop then
			Remotes.ShopAction:FireServer({ shopId = currentShop, action = "close" })
		end
		currentShop = nil
		root.Visible = false
	end
	closeButton.Activated:Connect(close)

	Remotes.ShopOpen.OnClientEvent:Connect(function(data)
		if data.close then
			-- сервер закрыл лавку (игрок отошёл)
			currentShop = nil
			root.Visible = false
			return
		end
		root.Visible = true
		render(data)
	end)

	local function fit()
		local camera = workspace.CurrentCamera
		if camera then
			local size = camera.ViewportSize
			scale.Scale = math.clamp(math.min(size.X / 840, size.Y / 600), 0.5, 1)
		end
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end

	return {
		close = close,
		isOpen = function()
			return root.Visible
		end,
	}
end

return ShopUI
