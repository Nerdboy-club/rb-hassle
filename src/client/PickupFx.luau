-- Плавный подбор: предмет вспыхивает картой, карта летит по дуге и уходит в книгу.
-- Всё рисуется на клиенте из простых деталей и UI, сервер только сообщает точку и id карты.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Cards)
local Ranks = require(Shared.Ranks)
local Remotes = require(Shared.Remotes)

local BookModel = require(script.Parent.BookModel)
local CardView = require(script.Parent.CardView)

local PickupFx = {}

local MAX_DISTANCE = 220
local CARD_SIZE = Vector3.new(2.4, 3.3, 0.08)
local APPEAR_SECONDS = 0.26
local FLY_SECONDS = 0.7

local function makePart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, transparency: number?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = transparency or 0
	part.Parent = parent
	return part
end

local function bezier(a: Vector3, b: Vector3, c: Vector3, t: number): Vector3
	local u = 1 - t
	return a * (u * u) + b * (2 * u * t) + c * (t * t)
end

local function burst(position: Vector3, color: Color3)
	local anchor = makePart(workspace, "PickupBurst", Vector3.one, CFrame.new(position), color, Enum.Material.Neon, 1)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.35, 0.7)
	emitter.Speed = NumberRange.new(5, 12)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Color = ColorSequence.new(color, Color3.fromRGB(255, 255, 255))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) })
	emitter.LightEmission = 1
	emitter.Drag = 2
	emitter.Parent = anchor
	emitter:Emit(28)
	Debris:AddItem(anchor, 1.2)
end

--- Карта из деталей: лицевая сторона — настоящая карта из CardView, сзади — рубашка.
local function createCard(position: Vector3, card: Cards.Card, rankColor: Color3): Part
	local part = makePart(workspace, "PickupCard", CARD_SIZE * 0.12, CFrame.new(position), rankColor, Enum.Material.SmoothPlastic, 0)
	part.CFrame = CFrame.new(position) * CFrame.Angles(0, math.random() * math.pi * 2, 0)

	local gui = Instance.new("SurfaceGui")
	gui.Name = "CardFace"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 100
	gui.LightInfluence = 0
	gui.ClipsDescendants = true
	gui.Parent = part
	local ok, err = pcall(CardView.big, gui, card.id, true, UDim2.fromOffset(240, 330))
	if not ok then
		warn("[PickupFx] card gui: " .. tostring(err))
	end

	local light = Instance.new("PointLight")
	light.Color = rankColor
	light.Range = 9
	light.Brightness = 1.4
	light.Parent = part

	local top = Instance.new("Attachment")
	top.Position = Vector3.new(-1.1, 0, 0)
	top.Parent = part
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(1.1, 0, 0)
	bottom.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(rankColor, Color3.fromRGB(255, 255, 255))
	trail.Lifetime = 0.35
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.65),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Parent = part

	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Rate = 16
	sparkle.Lifetime = NumberRange.new(0.25, 0.5)
	sparkle.Speed = NumberRange.new(0.3, 1.2)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Color = ColorSequence.new(rankColor)
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	sparkle.LightEmission = 1
	sparkle.Parent = part

	return part
end

--- Призрачная книга в точке, где она появится, если настоящая сейчас закрыта.
local function ghostBook(base: CFrame, color: Color3): (Folder, { { part: Part, target: number } }, PointLight)
	local folder = Instance.new("Folder")
	folder.Name = "PickupBookGhost"
	folder.Parent = workspace
	local leather = Color3.fromRGB(96, 52, 34)
	local gold = Color3.fromRGB(240, 200, 90)
	local pieces: { { part: Part, target: number } } = {}

	local function add(name: string, size: Vector3, offset: CFrame, partColor: Color3, material: Enum.Material, target: number)
		local part = makePart(folder, name, size, base * offset, partColor, material, 1)
		table.insert(pieces, { part = part, target = target })
		return part
	end

	add("Back", Vector3.new(3, 4, 0.16), CFrame.new(0, 0, 0.28), leather, Enum.Material.Leather, 0.22)
	add("Pages", Vector3.new(2.8, 3.8, 0.4), CFrame.new(0.05, 0, 0), Color3.fromRGB(245, 236, 210), Enum.Material.SmoothPlastic, 0.08)
	add("Spine", Vector3.new(0.22, 4, 0.72), CFrame.new(-1.5, 0, 0), leather, Enum.Material.Leather, 0.22)
	add("Cover", Vector3.new(3, 4, 0.16), CFrame.new(0, 0, -0.28), leather, Enum.Material.Leather, 0.22)
	add("Rim", Vector3.new(2.5, 3.5, 0.04), CFrame.new(0, 0, -0.38), gold, Enum.Material.Metal, 0.35)
	local glowPart = add("Glow", Vector3.new(3.4, 4.4, 0.05), CFrame.new(0, 0, -0.44), color, Enum.Material.Neon, 0.65)

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 14
	light.Brightness = 2
	light.Parent = glowPart

	for _, entry in pieces do
		TweenService:Create(entry.part, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = entry.target,
		}):Play()
	end
	return folder, pieces, light
end

local function play(position: Vector3, cardId: number)
	local card = Cards.get(cardId)
	if not card then
		return
	end
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - position).Magnitude > MAX_DISTANCE then
		return
	end

	local rankColor = Ranks.color(card.rank)
	local startPosition = position + Vector3.new(0, 0.35, 0)
	local cardPart = createCard(startPosition, card, rankColor)
	local anchor = BookModel.getAnchor()
	local ghost, ghostParts, ghostLight = nil, nil, nil
	if not BookModel.isOpen() and anchor then
		ghost, ghostParts, ghostLight = ghostBook(anchor, rankColor)
	end
	local target = BookModel.getTargetPosition() or (anchor and anchor.Position) or (startPosition + Vector3.new(0, 4, 0))
	local control = (startPosition + target) * 0.5
		+ Vector3.new(0, 4 + (target - startPosition).Magnitude * 0.06, 0)
		+ Vector3.new(math.random(-10, 10) * 0.1, 0, math.random(-10, 10) * 0.1)

	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local elapsed = now - started
		local currentCamera = workspace.CurrentCamera
		local face = currentCamera and currentCamera.CFrame.Position or target

		if elapsed < APPEAR_SECONDS then
			local alpha = elapsed / APPEAR_SECONDS
			local eased = 1 - (1 - alpha) ^ 3
			cardPart.Size = CARD_SIZE * (0.12 + 0.88 * eased)
			local spin = (1 - alpha) * math.pi * 2
			cardPart.CFrame = CFrame.lookAt(startPosition, face) * CFrame.Angles(0, spin, 0)
			return
		end

		local alpha = math.clamp((elapsed - APPEAR_SECONDS) / FLY_SECONDS, 0, 1)
		local eased = 1 - (1 - alpha) ^ 3
		local positionNow = bezier(startPosition, control, target, eased)
		cardPart.Size = CARD_SIZE * (1 - 0.72 * eased * eased)
		local direction = face - positionNow
		local cframe = direction.Magnitude > 0.1 and CFrame.lookAt(positionNow, face) or CFrame.new(positionNow)
		cardPart.CFrame = cframe * CFrame.Angles(0, math.sin(alpha * math.pi) * 0.25, math.sin(alpha * math.pi * 2) * 0.12)

		if alpha >= 1 then
			connection:Disconnect()
			burst(target, rankColor)
			cardPart:Destroy()
			if ghost and ghostParts then
				for _, entry in ghostParts do
					TweenService:Create(entry.part, TweenInfo.new(0.28), { Transparency = 1 }):Play()
				end
				if ghostLight then
					TweenService:Create(ghostLight, TweenInfo.new(0.28), { Brightness = 0 }):Play()
				end
				Debris:AddItem(ghost, 0.5)
			end
		end
	end)
end

function PickupFx.start()
	Remotes.Fx.OnClientEvent:Connect(function(data)
		if type(data) ~= "table" or data.kind ~= "pickup" then
			return
		end
		local cardId = tonumber(data.cardId)
		if not cardId or typeof(data.position) ~= "Vector3" then
			return
		end
		local ok, err = pcall(play, data.position, cardId)
		if not ok then
			warn("[PickupFx] " .. tostring(err))
		end
	end)
end

return PickupFx
