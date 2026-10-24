-- Простая модель человечка для NPC: собирается из частей, ничего из Toolbox не нужно.
local RigBuilder = {}

local function block(name: string, size: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

--- Модель стоит на земле (y пола — floorY), лицом к -Z (или повёрнута CFrame-ом позже).
function RigBuilder.build(displayName: string, shirt: Color3, skin: Color3?, scale: number?): Model
	local factor = scale or 1
	local skinColor = skin or Color3.fromRGB(240, 200, 160)
	local legColor = Color3.fromRGB(50, 55, 70)
	local model = Instance.new("Model")
	model.Name = displayName

	local rootPart = block("HumanoidRootPart", Vector3.new(2, 2, 1) * factor, shirt, model)
	rootPart.Transparency = 1
	rootPart.CanCollide = false
	model.PrimaryPart = rootPart

	-- смещения от центра корня: ноги -2.. и ниже, торс 0, голова +1.5
	local parts: { { part: Part, offset: Vector3 } } = {
		{ part = block("Torso", Vector3.new(2, 2, 1) * factor, shirt, model), offset = Vector3.new(0, 0, 0) },
		{ part = block("Head", Vector3.new(1.4, 1.4, 1.4) * factor, skinColor, model), offset = Vector3.new(0, 1.7, 0) * factor },
		{ part = block("LeftArm", Vector3.new(1, 2, 1) * factor, skinColor, model), offset = Vector3.new(-1.5, 0, 0) * factor },
		{ part = block("RightArm", Vector3.new(1, 2, 1) * factor, skinColor, model), offset = Vector3.new(1.5, 0, 0) * factor },
		{ part = block("LeftLeg", Vector3.new(1, 2, 1) * factor, legColor, model), offset = Vector3.new(-0.5, -2, 0) * factor },
		{ part = block("RightLeg", Vector3.new(1, 2, 1) * factor, legColor, model), offset = Vector3.new(0.5, -2, 0) * factor },
	}

	local face = Instance.new("Decal")
	face.Name = "face"
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = parts[2].part

	model:SetAttribute("RigOffsets", "")
	for _, entry in parts do
		entry.part:SetAttribute("OffsetX", entry.offset.X)
		entry.part:SetAttribute("OffsetY", entry.offset.Y)
		entry.part:SetAttribute("OffsetZ", entry.offset.Z)
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayName = displayName
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.NameDisplayDistance = 40
	humanoid.Parent = model

	return model
end

--- Поставить модель так, чтобы подошвы стояли на groundY, лицом в точку lookAt.
function RigBuilder.place(model: Model, position: Vector3, groundY: number, lookAt: Vector3?, scale: number?)
	local factor = scale or 1
	local center = Vector3.new(position.X, groundY + 3 * factor, position.Z)
	local facing = lookAt and Vector3.new(lookAt.X, center.Y, lookAt.Z) or (center + Vector3.new(0, 0, -1))
	local base = CFrame.lookAt(center, facing)
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			local offset = Vector3.new(
				part:GetAttribute("OffsetX") or 0,
				part:GetAttribute("OffsetY") or 0,
				part:GetAttribute("OffsetZ") or 0
			)
			part.CFrame = base * CFrame.new(offset)
		end
	end
end

return RigBuilder
