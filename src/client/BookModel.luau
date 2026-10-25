-- «Книга» как в аниме: перед игроком из вспышки возникает переплёт, обложка раскрывается.
-- Модель собирается из частей и видна только самому игроку (клиентская).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local BookModel = {}

local OPEN_SECONDS = 0.5
local CLOSE_SECONDS = 0.3
local DISTANCE = 5 -- на сколько студов впереди игрока парит книга

local model: Folder? = nil
local parts: { [string]: Part } = {}
local progress = Instance.new("NumberValue") -- 0 закрыта и мала, 1 раскрыта
local connection: RBXScriptConnection? = nil
local tween: Tween? = nil
local emitter: ParticleEmitter? = nil

local function block(name: string, size: Vector3, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = model
	return part
end

local function build()
	model = Instance.new("Folder")
	model.Name = "GreedBook"
	model.Parent = workspace
	local leather = Color3.fromRGB(96, 52, 34)
	local gold = Color3.fromRGB(240, 200, 90)

	parts.back = block("Back", Vector3.new(3, 4, 0.16), leather, Enum.Material.Leather)
	parts.pages = block("Pages", Vector3.new(2.8, 3.8, 0.4), Color3.fromRGB(245, 236, 210), Enum.Material.SmoothPlastic)
	parts.spine = block("Spine", Vector3.new(0.22, 4, 0.72), leather:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Leather)
	parts.cover = block("Cover", Vector3.new(3, 4, 0.16), leather, Enum.Material.Leather)
	parts.gem = block("Gem", Vector3.new(0.7, 0.7, 0.12), Color3.fromRGB(120, 220, 255), Enum.Material.Neon)
	parts.gem.Shape = Enum.PartType.Ball
	parts.rim = block("Rim", Vector3.new(2.5, 3.5, 0.04), gold, Enum.Material.Metal)
	parts.rim.Transparency = 0.55

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizeStudsPerPixel = 0.02
	gui.Parent = parts.cover
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 0.3)
	label.Position = UDim2.fromScale(0, 0.12)
	label.BackgroundTransparency = 1
	label.Text = "GREED\nISLAND"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = gold
	label.Parent = gui

	-- искры при появлении
	local sparks = Instance.new("ParticleEmitter")
	sparks.Rate = 0
	sparks.Lifetime = NumberRange.new(0.5, 0.9)
	sparks.Speed = NumberRange.new(6, 12)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 230, 140), Color3.fromRGB(150, 220, 255))
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sparks.LightEmission = 1
	sparks.Parent = parts.back
	emitter = sparks
end

--- Положение частей для текущего прогресса относительно точки base (книга лицом к игроку).
local function layout(base: CFrame, value: number)
	local scale = 0.25 + 0.75 * value
	local angle = math.rad(165) * math.clamp((value - 0.15) / 0.85, 0, 1)
	local function place(part: Part, size: Vector3, offset: CFrame)
		part.Size = size * scale
		part.CFrame = base * CFrame.new(offset.Position * scale) * (offset - offset.Position)
	end
	place(parts.back, Vector3.new(3, 4, 0.16), CFrame.new(0, 0, 0.28))
	place(parts.pages, Vector3.new(2.8, 3.8, 0.4), CFrame.new(0.05, 0, 0))
	place(parts.spine, Vector3.new(0.22, 4, 0.72), CFrame.new(-1.5, 0, 0))
	-- обложка поворачивается вокруг корешка (левый край)
	local hinge = CFrame.new(-1.5 * scale, 0, -0.28 * scale) * CFrame.Angles(0, angle, 0)
	parts.cover.Size = Vector3.new(3, 4, 0.16) * scale
	parts.cover.CFrame = base * hinge * CFrame.new(1.5 * scale, 0, 0)
	local gem = parts.gem
	gem.Size = Vector3.new(0.7, 0.7, 0.12) * scale
	gem.CFrame = parts.cover.CFrame * CFrame.new(0, -0.9 * scale, -0.1 * scale)
	local rim = parts.rim
	rim.Size = Vector3.new(2.5, 3.5, 0.04) * scale
	rim.CFrame = parts.cover.CFrame * CFrame.new(0, 0, -0.1 * scale)
end

local function destroy()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if model then
		model:Destroy()
		model = nil
	end
	table.clear(parts)
end

local function follow()
	if connection then
		return
	end
	connection = RunService.RenderStepped:Connect(function()
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or not model then
			return
		end
		local flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		if flat.Magnitude < 0.01 then
			flat = Vector3.new(0, 0, -1)
		end
		flat = flat.Unit
		local bob = math.sin(os.clock() * 2) * 0.15
		local position = root.Position + flat * DISTANCE + Vector3.new(0, 1.2 + bob, 0)
		local base = CFrame.lookAt(position, root.Position + Vector3.new(0, 1.2 + bob, 0))
		layout(base, progress.Value)
	end)
end

local function animate(target: number, seconds: number, onDone: (() -> ())?)
	if tween then
		tween:Cancel()
	end
	tween = TweenService:Create(progress, TweenInfo.new(seconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = target })
	local current = tween :: Tween
	current.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and onDone then
			onDone()
		end
	end)
	current:Play()
end

--- Книга появляется и раскрывается. Длится OPEN_SECONDS.
function BookModel.show()
	if not model then
		progress.Value = 0
		build()
		follow()
		if emitter then
			emitter:Emit(24)
		end
	end
	animate(1, OPEN_SECONDS, nil)
end

--- Книга закрывается и исчезает.
function BookModel.hide()
	if not model then
		return
	end
	if emitter then
		emitter:Emit(10)
	end
	animate(0, CLOSE_SECONDS, destroy)
end

BookModel.openSeconds = OPEN_SECONDS

return BookModel
