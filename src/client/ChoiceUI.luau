-- Выбор цели заклинания («Полёт»: куда лететь). Карта тратится только после выбора; закрытие окна — отмена.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)

local ChoiceUI = {}

function ChoiceUI.create(gui: ScreenGui)
	local panel = Theme.frame(gui, UDim2.fromOffset(460, 360), UDim2.fromScale(0.5, 0.5), Theme.panel)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Visible = false
	panel.ZIndex = 14
	Theme.corner(panel, 14)
	Theme.stroke(panel, Theme.accent, 2)
	local scale = Instance.new("UIScale")
	scale.Parent = panel

	local title = Theme.label(panel, "", UDim2.new(1, -24, 0, 28), UDim2.fromOffset(14, 12), {
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = Theme.gold,
	})
	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -28, 1, -112)
	list.Position = UDim2.fromOffset(14, 48)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -6, 0, 38)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list

	local cancel = Theme.button(panel, "Отмена", UDim2.fromOffset(140, 34), UDim2.new(0.5, -70, 1, -48), Theme.bad)

	local currentSpell: number? = nil

	local function close(send: boolean)
		panel.Visible = false
		if send and currentSpell then
			Remotes.SpellChoose:FireServer({ spellId = currentSpell }) -- без option: отмена
		end
		currentSpell = nil
	end

	cancel.Activated:Connect(function()
		close(true)
	end)

	Remotes.SpellChoice.OnClientEvent:Connect(function(data)
		currentSpell = data.spellId
		title.Text = data.title
		for _, child in list:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		for index, option in data.options do
			local button = Theme.button(list, option.label, UDim2.fromOffset(100, 38), nil, Theme.panelLight)
			button.LayoutOrder = index
			button.TextSize = 13
			button.TextWrapped = true
			button.Activated:Connect(function()
				local spellId = currentSpell
				panel.Visible = false
				currentSpell = nil
				if spellId then
					Remotes.SpellChoose:FireServer({ spellId = spellId, option = option.id })
				end
			end)
		end
		panel.Visible = true
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape and panel.Visible then
			close(true)
		end
	end)

	local function fit()
		local camera = workspace.CurrentCamera
		if camera then
			scale.Scale = math.clamp(math.min(camera.ViewportSize.X / 500, camera.ViewportSize.Y / 400), 0.5, 1)
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

return ChoiceUI
