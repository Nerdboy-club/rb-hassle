-- Общие цвета и конструкторы интерфейса. Весь UI собирается кодом, без ассетов.
local Theme = {}

Theme.bg = Color3.fromRGB(20, 22, 32)
Theme.panel = Color3.fromRGB(30, 33, 46)
Theme.panelLight = Color3.fromRGB(42, 46, 64)
Theme.text = Color3.fromRGB(235, 238, 248)
Theme.muted = Color3.fromRGB(150, 156, 178)
Theme.accent = Color3.fromRGB(120, 200, 255)
Theme.good = Color3.fromRGB(110, 220, 140)
Theme.warn = Color3.fromRGB(255, 190, 90)
Theme.bad = Color3.fromRGB(255, 100, 110)
Theme.gold = Color3.fromRGB(255, 215, 110)

function Theme.corner(instance: Instance, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = instance
end

function Theme.stroke(instance: Instance, color: Color3, thickness: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = instance
	return stroke
end

function Theme.padding(instance: Instance, pixels: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, pixels)
	padding.PaddingBottom = UDim.new(0, pixels)
	padding.PaddingLeft = UDim.new(0, pixels)
	padding.PaddingRight = UDim.new(0, pixels)
	padding.Parent = instance
end

function Theme.frame(parent: Instance, size: UDim2, position: UDim2?, color: Color3?): Frame
	local frame = Instance.new("Frame")
	frame.Size = size
	frame.Position = position or UDim2.new()
	frame.BackgroundColor3 = color or Theme.panel
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

function Theme.label(parent: Instance, text: string, size: UDim2, position: UDim2?, props: { [string]: any }?): TextLabel
	local label = Instance.new("TextLabel")
	label.Text = text
	label.Size = size
	label.Position = position or UDim2.new()
	label.BackgroundTransparency = 1
	label.TextColor3 = Theme.text
	label.Font = Enum.Font.Gotham
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextWrapped = true
	label.RichText = false
	if props then
		for name, value in props do
			(label :: any)[name] = value
		end
	end
	label.Parent = parent
	return label
end

function Theme.button(parent: Instance, text: string, size: UDim2, position: UDim2?, color: Color3?): TextButton
	local button = Instance.new("TextButton")
	button.Text = text
	button.Size = size
	button.Position = position or UDim2.new()
	button.BackgroundColor3 = color or Theme.panelLight
	button.TextColor3 = Theme.text
	button.Font = Enum.Font.GothamMedium
	button.TextSize = 14
	button.AutoButtonColor = true
	button.BorderSizePixel = 0
	button.Parent = parent
	Theme.corner(button, 8)
	return button
end

return Theme
