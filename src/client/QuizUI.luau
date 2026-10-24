-- Викторина: вопрос, четыре варианта, полоса времени.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)

local QuizUI = {}

function QuizUI.create(gui: ScreenGui)
	local root = Theme.frame(gui, UDim2.fromOffset(620, 330), UDim2.new(0.5, 0, 0, 80), Theme.panel)
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Visible = false
	root.ZIndex = 14
	Theme.corner(root, 14)
	Theme.stroke(root, Theme.gold, 2)

	local scale = Instance.new("UIScale")
	scale.Parent = root

	local header = Theme.label(root, "", UDim2.new(1, -28, 0, 22), UDim2.fromOffset(14, 10), {
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.gold,
		TextSize = 15,
	})
	local question = Theme.label(root, "", UDim2.new(1, -28, 0, 70), UDim2.fromOffset(14, 36), {
		TextSize = 18,
		Font = Enum.Font.GothamMedium,
	})
	local bar = Theme.frame(root, UDim2.new(1, -28, 0, 8), UDim2.fromOffset(14, 108), Theme.panelLight)
	Theme.corner(bar, 4)
	local fill = Theme.frame(bar, UDim2.fromScale(1, 1), nil, Theme.gold)
	Theme.corner(fill, 4)

	local buttons: { TextButton } = {}
	for index = 1, 4 do
		local button = Theme.button(
			root,
			"",
			UDim2.new(1, -28, 0, 44),
			UDim2.fromOffset(14, 124 + (index - 1) * 50),
			Theme.panelLight
		)
		button.TextSize = 15
		buttons[index] = button
	end

	local currentQid = 0
	local answered = false
	local activeTween: Tween? = nil

	local function hide()
		root.Visible = false
		if activeTween then
			activeTween:Cancel()
		end
	end

	for index, button in buttons do
		button.Activated:Connect(function()
			if answered then
				return
			end
			answered = true
			Remotes.QuizAnswer:FireServer({ qid = currentQid, index = index })
			for other, otherButton in buttons do
				otherButton.BackgroundColor3 = other == index and Theme.accent or Theme.panel
			end
		end)
	end

	Remotes.Quiz.OnClientEvent:Connect(function(data)
		if data.close then
			hide()
			return
		end
		currentQid = data.qid
		answered = false
		root.Visible = true
		local who = data.kind == "final" and "Финальная викторина Лимейро" or "Конкурс Антокибы"
		header.Text = ("%s · вопрос %d из %d"):format(who, data.round, data.total)
		question.Text = data.text
		for index, button in buttons do
			button.Text = data.options[index] or ""
			button.BackgroundColor3 = Theme.panelLight
		end
		fill.Size = UDim2.fromScale(1, 1)
		if activeTween then
			activeTween:Cancel()
		end
		activeTween = TweenService:Create(fill, TweenInfo.new(data.seconds, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) })
		activeTween:Play()
	end)

	local function fit()
		local camera = workspace.CurrentCamera
		if camera then
			scale.Scale = math.clamp(camera.ViewportSize.X / 680, 0.6, 1)
		end
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
end

return QuizUI
