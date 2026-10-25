-- Экранные кнопки для телефона: удар, Тен, Зетсу, Книга, Получить.
-- Стоят справа над родной кнопкой прыжка Roblox (слева — её джойстик, там ничего нет).
local UserInputService = game:GetService("UserInputService")

local State = require(script.Parent.State)
local Theme = require(script.Parent.Theme)

local TouchControls = {}

--- Телефон или планшет без клавиатуры.
function TouchControls.isTouchDevice(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function TouchControls.create(screen: ScreenGui, actions: { [string]: () -> () }, isBlocked: () -> boolean)
	local root = Instance.new("Frame")
	root.Name = "TouchControls"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.Parent = screen

	local function round(button: GuiButton)
		Theme.corner(button, 100)
		Theme.stroke(button, Theme.accent, 2)
	end

	-- большая кнопка удара: зажатие бьёт непрерывно
	local attack = Theme.button(root, "УДАР", UDim2.fromOffset(84, 84), UDim2.new(1, -118, 1, -30), Color3.fromRGB(120, 40, 50))
	attack.AnchorPoint = Vector2.new(1, 1)
	attack.TextSize = 15
	attack.Font = Enum.Font.GothamBlack
	attack.AutoButtonColor = true
	round(attack)

	local held = false
	local function swing()
		if actions.attack then
			actions.attack()
		end
	end
	attack.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			if held then
				return
			end
			held = true
			task.spawn(function()
				while held and root.Visible do
					swing()
					task.wait(0.45)
				end
			end)
		end
	end)
	attack.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			held = false
		end
	end)

	-- ряд малых кнопок над кнопкой прыжка
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(1, 1)
	row.Size = UDim2.fromOffset(4 * 54, 48)
	row.Position = UDim2.new(1, -12, 1, -136)
	row.Parent = root
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.Padding = UDim.new(0, 6)
	layout.Parent = row

	local stanceButtons: { [string]: TextButton } = {}
	local function small(text: string, order: number, callback: () -> ()): TextButton
		local button = Theme.button(row, text, UDim2.fromOffset(48, 48), nil, Theme.panelLight)
		button.TextSize = 11
		button.LayoutOrder = order
		button.Activated:Connect(callback)
		round(button)
		return button
	end
	small("Книга", 1, actions.book)
	small("Прир.", 2, actions.gain)
	stanceButtons.ten = small("Тен", 3, actions.ten)
	stanceButtons.zetsu = small("Зетсу", 4, actions.zetsu)

	local function refresh()
		root.Visible = State.phase ~= "lobby" and not isBlocked()
		if not root.Visible then
			held = false
		end
		for name, button in stanceButtons do
			local active = State.stance == name
			button.BackgroundColor3 = active and Theme.accent or Theme.panelLight
			button.TextColor3 = active and Color3.fromRGB(10, 18, 26) or Theme.text
		end
	end
	State.changed.Event:Connect(refresh)
	task.spawn(function()
		while root.Parent do
			refresh()
			task.wait(0.25)
		end
	end)
	refresh()
	return root
end

return TouchControls
