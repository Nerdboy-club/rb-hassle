local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer

local function new(className, props, parent)
	local inst = Instance.new(className)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local gui = new("ScreenGui", {
	Name = "DriveHud",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
}, player:WaitForChild("PlayerGui"))

------------------------------------------------------------------------
-- Car menu (bottom-left)
------------------------------------------------------------------------

local menu = new("Frame", {
	Size = UDim2.fromOffset(180, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Position = UDim2.new(0, 16, 1, -16),
	AnchorPoint = Vector2.new(0, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.4,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 8) }, menu)
new("UIPadding", {
	PaddingTop = UDim.new(0, 8),
	PaddingBottom = UDim.new(0, 8),
	PaddingLeft = UDim.new(0, 8),
	PaddingRight = UDim.new(0, 8),
}, menu)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, menu)

local function button(text, order, onClick)
	local b = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Color3.fromRGB(40, 40, 46),
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamMedium,
		TextSize = 16,
		Text = text,
		LayoutOrder = order,
	}, menu)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
	b.Activated:Connect(onClick)
	return b
end

new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 20),
	BackgroundTransparency = 1,
	TextColor3 = Color3.fromRGB(200, 200, 205),
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	Text = "SPAWN CAR",
	LayoutOrder = 0,
}, menu)

task.spawn(function()
	local cars = Remotes.GetCars:InvokeServer()
	if #cars == 0 then
		new("TextLabel", {
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundTransparency = 1,
			TextColor3 = Color3.fromRGB(255, 120, 120),
			Font = Enum.Font.Gotham,
			TextSize = 14,
			TextWrapped = true,
			Text = "No cars in ServerStorage.Cars",
			LayoutOrder = 1,
		}, menu)
	end
	for i, name in cars do
		button(name, i, function()
			Remotes.SpawnCar:FireServer(name)
		end)
	end
	button("Remove car", 1000, function()
		Remotes.DespawnCar:FireServer()
	end)
end)

------------------------------------------------------------------------
-- Speedometer (bottom-right, only while seated in a vehicle)
------------------------------------------------------------------------

local speedo = new("TextLabel", {
	Size = UDim2.fromOffset(220, 70),
	Position = UDim2.new(1, -16, 1, -16),
	AnchorPoint = Vector2.new(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.4,
	TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.GothamBold,
	TextSize = 36,
	Text = "0 km/h",
	Visible = false,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 8) }, speedo)

RunService.RenderStepped:Connect(function()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if seat and seat:IsA("VehicleSeat") then
		local kmh = seat.AssemblyLinearVelocity.Magnitude * Config.StudToMeters * 3.6
		speedo.Text = string.format("%d km/h", math.floor(kmh + 0.5))
		speedo.Visible = true
	else
		speedo.Visible = false
	end
end)

------------------------------------------------------------------------
-- Shashki score (top-center)
------------------------------------------------------------------------

local scoreFrame = new("Frame", {
	Size = UDim2.fromOffset(260, 90),
	Position = UDim2.new(0.5, 0, 0, 16),
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.4,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 8) }, scoreFrame)

local scoreLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 0.55, 0),
	BackgroundTransparency = 1,
	TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.GothamBold,
	TextSize = 34,
	Text = "0",
}, scoreFrame)

local comboLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 0.35, 0),
	Position = UDim2.fromScale(0, 0.6),
	BackgroundTransparency = 1,
	TextColor3 = Color3.fromRGB(255, 200, 60),
	Font = Enum.Font.GothamBold,
	TextSize = 20,
	Text = "",
}, scoreFrame)

local popup = new("TextLabel", {
	Size = UDim2.fromOffset(300, 40),
	Position = UDim2.new(0.5, 0, 0, 120),
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundTransparency = 1,
	TextColor3 = Color3.fromRGB(120, 255, 160),
	Font = Enum.Font.GothamBlack,
	TextSize = 26,
	TextStrokeTransparency = 0.3,
	Text = "",
}, gui)

local popupId = 0
Remotes.ShashkiScore.OnClientEvent:Connect(function(data)
	scoreLabel.Text = tostring(data.score)
	comboLabel.Text = if data.mult > 1 then `COMBO x{data.mult}` else ""
	if data.popup then
		popupId += 1
		local id = popupId
		popup.Text = data.popup
		popup.TextColor3 = if data.crash then Color3.fromRGB(255, 90, 90) else Color3.fromRGB(120, 255, 160)
		task.delay(1.2, function()
			if popupId == id then
				popup.Text = ""
			end
		end)
	end
end)
