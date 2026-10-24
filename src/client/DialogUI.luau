-- Диалог с NPC: панель снизу, варианты ответа кнопками.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)

local DialogUI = {}

function DialogUI.create(gui: ScreenGui)
	local panel = Theme.frame(gui, UDim2.fromOffset(640, 230), UDim2.new(0.5, 0, 1, -24), Theme.panel)
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Visible = false
	panel.ZIndex = 8
	Theme.corner(panel, 14)
	Theme.stroke(panel, Theme.accent, 2)

	local scale = Instance.new("UIScale")
	scale.Parent = panel

	local nameLabel = Theme.label(panel, "", UDim2.new(1, -28, 0, 24), UDim2.fromOffset(16, 10), {
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = Theme.gold,
	})
	local textLabel = Theme.label(panel, "", UDim2.new(1, -32, 0, 100), UDim2.fromOffset(16, 40), {
		TextSize = 15,
	})
	local optionsFrame = Theme.frame(panel, UDim2.new(1, -32, 0, 70), UDim2.new(0, 16, 1, -80), Theme.panel)
	optionsFrame.BackgroundTransparency = 1
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Wraps = true
	layout.Padding = UDim.new(0, 8)
	layout.Parent = optionsFrame

	local currentNpc: string? = nil

	local function hide()
		panel.Visible = false
		currentNpc = nil
	end

	Remotes.Dialog.OnClientEvent:Connect(function(data)
		if data.close then
			hide()
			return
		end
		currentNpc = data.npcId
		panel.Visible = true
		nameLabel.Text = data.name
		textLabel.Text = data.text
		for _, child in optionsFrame:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		for index, option in data.options do
			local button = Theme.button(optionsFrame, option.label, UDim2.fromOffset(190, 32), nil, Theme.panelLight)
			button.LayoutOrder = index
			button.TextSize = 13
			button.Activated:Connect(function()
				Remotes.DialogChoice:FireServer({ npcId = data.npcId, optionId = option.id })
			end)
		end
	end)

	-- Esc закрывает диалог
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape and currentNpc then
			Remotes.DialogChoice:FireServer({ npcId = currentNpc, optionId = "bye" })
			hide()
		end
	end)

	local function fit()
		local camera = workspace.CurrentCamera
		if camera then
			scale.Scale = math.clamp(camera.ViewportSize.X / 700, 0.6, 1)
		end
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
end

return DialogUI
