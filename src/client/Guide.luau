-- Путеводитель новичка: стрелка в HUD и маркер в мире показывают, куда идти по текущей цели.
-- Позиции считаются на клиенте из общих данных (Zones, Npcs) — серверу ничего слать не нужно.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Npcs = require(Shared.Npcs)
local Zones = require(Shared.Zones)

local Theme = require(script.Parent.Theme)

local Guide = {}

local terrain = workspace.Terrain
local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { terrain }

local function groundAt(x: number, z: number): Vector3
	local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), terrainOnly)
	return Vector3.new(x, hit and hit.Position.Y or 0, z)
end

--- Место NPC по его id из Npcs.luau (nil, если такого нет).
function Guide.npcPosition(npcId: string): Vector3?
	local npc = Npcs[npcId]
	local zone = npc and Zones[npc.zone]
	if not npc or not zone then
		return nil
	end
	if npc.zone == "Coast" then
		return groundAt(npc.dx, npc.dz)
	end
	return groundAt(zone.x + npc.dx, zone.z + npc.dz)
end

--- Центр зоны.
function Guide.zonePosition(zoneKey: string): Vector3?
	local zone = Zones[zoneKey]
	return zone and groundAt(zone.x, zone.z) or nil
end

--- Ближайший монстр к игроку (папка workspace.Monsters, часть Root).
function Guide.nearestMonster(from: Vector3): Vector3?
	local folder = workspace:FindFirstChild("Monsters")
	if not folder then
		return nil
	end
	local best: Vector3? = nil
	local bestDistance = math.huge
	for _, model in folder:GetChildren() do
		local part = model:FindFirstChild("Root")
		if part and part:IsA("BasePart") then
			local distance = (part.Position - from).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				best = part.Position
			end
		end
	end
	return best
end

function Guide.create(screen: Instance)
	local arrowFrame = Theme.frame(screen, UDim2.fromOffset(150, 44), UDim2.new(0.5, 0, 0, 6), Theme.bg)
	arrowFrame.AnchorPoint = Vector2.new(0.5, 0)
	arrowFrame.BackgroundTransparency = 0.25
	arrowFrame.Visible = false
	Theme.corner(arrowFrame, 10)
	Theme.stroke(arrowFrame, Theme.gold, 1)
	local arrow = Theme.label(arrowFrame, "▲", UDim2.fromOffset(36, 36), UDim2.fromOffset(6, 4), {
		TextSize = 28,
		TextColor3 = Theme.gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
	local info = Theme.label(arrowFrame, "", UDim2.new(1, -50, 1, -6), UDim2.fromOffset(46, 3), {
		TextSize = 13,
		TextYAlignment = Enum.TextYAlignment.Center,
	})

	-- маркер в мире: виден сквозь стены и с большого расстояния
	local anchor = Instance.new("Part")
	anchor.Name = "GuideMarker"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(150, 44)
	billboard.StudsOffset = Vector3.new(0, 7, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 1500
	billboard.Parent = anchor
	local marker = Theme.label(billboard, "", UDim2.fromScale(1, 1), nil, {
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = Theme.gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextStrokeTransparency = 0.4,
	})

	local getter: (() -> Vector3?)? = nil
	local title = ""
	local active = false

	local function lookTarget(): Vector3?
		return getter and getter() or nil
	end

	local function update(withMarker: boolean)
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local camera = workspace.CurrentCamera
		local target = active and lookTarget() or nil
		if not target or not root or not camera then
			arrowFrame.Visible = false
			anchor.Parent = nil
			return
		end
		local from = (root :: BasePart).Position
		local flat = Vector3.new(target.X - from.X, 0, target.Z - from.Z)
		local meters = math.floor(flat.Magnitude)
		arrowFrame.Visible = meters > 12
		anchor.Parent = meters > 12 and workspace or nil
		if meters <= 12 then
			return
		end
		local look = camera.CFrame.LookVector
		local forward = Vector3.new(look.X, 0, look.Z)
		if forward.Magnitude > 0.01 then
			forward = forward.Unit
			local direction = flat.Unit
			-- угол от направления взгляда к цели: вправо — положительный
			local angle = math.atan2(direction.X * forward.Z - direction.Z * forward.X, direction:Dot(forward))
			arrow.Rotation = -math.deg(angle)
		end
		local text = ("%s\n%d м"):format(title, meters)
		info.Text = text
		if withMarker then
			anchor.Position = target
			marker.Text = "◆ " .. text:gsub("\n", " · ")
		end
	end

	local accumulator = 0
	RunService.RenderStepped:Connect(function(dt)
		if not active then
			return
		end
		accumulator += dt
		update(accumulator >= 0.25)
		if accumulator >= 0.25 then
			accumulator = 0
		end
	end)

	return {
		--- Нет цели — стрелка прячется.
		set = function(newGetter: (() -> Vector3?)?, newTitle: string?)
			getter = newGetter
			title = newTitle or ""
			active = newGetter ~= nil
			if not active then
				arrowFrame.Visible = false
				anchor.Parent = nil
			end
		end,
	}
end

return Guide
