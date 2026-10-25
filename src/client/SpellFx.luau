-- Аниме-эффекты магии: вспышка и световой столб телепорта, магический круг под ногами при заклинаниях,
-- шлейф скорости, щит-сфера, исцеляющие искры. Всё из встроенных деталей и частиц, без ассетов.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local SpellFx = {}

local MAX_DISTANCE = 300 -- дальше от камеры эффекты не рисуем

local COLORS = {
	teleport = Color3.fromRGB(150, 210, 255),
	heal = Color3.fromRGB(120, 255, 160),
	buff = Color3.fromRGB(255, 215, 110),
	shield = Color3.fromRGB(110, 230, 255),
	attack = Color3.fromRGB(255, 110, 110),
	control = Color3.fromRGB(170, 190, 255),
	stealth = Color3.fromRGB(180, 130, 255),
	reveal = Color3.fromRGB(255, 240, 150),
	default = Color3.fromRGB(200, 170, 255),
}

-- тип заклинания (effect из Spells.luau) -> цвет и вид эффекта
local KIND_OF = {
	heal = "heal",
	groupHeal = "heal",
	revive = "heal",
	hpboost = "heal",
	haste = "haste",
	quick = "haste",
	jump = "haste",
	rage = "attack",
	reach = "attack",
	shield = "shield",
	block = "shield",
	reflect = "shield",
	stealth = "stealth",
	silent = "stealth",
	reveal = "reveal",
	scout = "reveal",
	freeze = "control",
	blind = "control",
	calm = "control",
	lure = "control",
	slow = "control",
	fortune = "buff",
	magnet = "buff",
	recall = "buff",
	cancel = "buff",
}

local function nearCamera(position: Vector3): boolean
	local camera = workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - position).Magnitude <= MAX_DISTANCE
end

local function part(size: Vector3, cframe: CFrame, color: Color3, shape: Enum.PartType?, transparency: number?): Part
	local created = Instance.new("Part")
	created.Anchored = true
	created.CanCollide = false
	created.CanQuery = false
	created.CanTouch = false
	created.CastShadow = false
	created.Material = Enum.Material.Neon
	created.Color = color
	created.Size = size
	created.CFrame = cframe
	created.Shape = shape or Enum.PartType.Block
	created.Transparency = transparency or 0
	created.Parent = workspace
	return created
end

local function fade(target: Instance, info: TweenInfo, goal: { [string]: any }, lifetime: number)
	TweenService:Create(target, info, goal):Play()
	Debris:AddItem(target, lifetime)
end

--- Искры из точки.
local function sparks(position: Vector3, color: Color3, count: number, speed: number)
	local anchor = part(Vector3.one, CFrame.new(position), color, nil, 1)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.6, 1.1)
	emitter.Speed = NumberRange.new(speed * 0.5, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Color = ColorSequence.new(color, Color3.fromRGB(255, 255, 255))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
	emitter.LightEmission = 1
	emitter.Drag = 2
	emitter.Parent = anchor
	emitter:Emit(count)
	Debris:AddItem(anchor, 1.6)
end

--- Расходящееся кольцо по земле.
local function ring(position: Vector3, color: Color3, startSize: number, endSize: number, seconds: number)
	local disc = part(
		Vector3.new(0.25, startSize, startSize),
		CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2),
		color,
		Enum.PartType.Cylinder,
		0.15
	)
	fade(disc, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.25, endSize, endSize),
		Transparency = 1,
	}, seconds + 0.1)
end

--- Световой столб, стягивающийся в линию.
local function pillar(position: Vector3, color: Color3, height: number, seconds: number)
	local beam = part(
		Vector3.new(height, 7, 7),
		CFrame.new(position + Vector3.new(0, height / 2 - 3, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		color,
		Enum.PartType.Cylinder,
		0.2
	)
	fade(beam, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = Vector3.new(height, 0.2, 0.2),
		Transparency = 1,
	}, seconds + 0.1)
end

--- Телепорт: вспышка, кольцо и столб света (уход — столб растёт вверх, появление — падает).
local function teleportFlash(position: Vector3, arriving: boolean)
	local color = COLORS.teleport
	ring(position - Vector3.new(0, 2.8, 0), color, 4, arriving and 18 or 26, 0.6)
	ring(position - Vector3.new(0, 2.6, 0), Color3.fromRGB(255, 255, 255), 2, arriving and 10 or 14, 0.45)
	pillar(position, color, arriving and 55 or 80, 0.55)
	sparks(position, color, arriving and 40 or 55, arriving and 22 or 32)
end

--- Магический круг под ногами с вращающимися «рунами».
local function magicCircle(root: BasePart, color: Color3, seconds: number)
	local ground = root.Position - Vector3.new(0, 2.9, 0)
	local base = CFrame.new(ground) * CFrame.Angles(0, 0, math.pi / 2)
	local disc = part(Vector3.new(0.12, 11, 11), base, color, Enum.PartType.Cylinder, 0.7)
	local outer = part(Vector3.new(0.18, 12, 12), base, color, Enum.PartType.Cylinder, 0.35)
	local inner = part(Vector3.new(0.2, 9.4, 9.4), base, Color3.fromRGB(10, 10, 20), Enum.PartType.Cylinder, 1)
	inner.Material = Enum.Material.SmoothPlastic
	local runes = {}
	for index = 1, 6 do
		runes[index] = part(Vector3.new(0.6, 0.15, 1.8), CFrame.new(ground), color, nil, 0.1)
	end
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - started) / seconds
		if t >= 1 then
			connection:Disconnect()
			for _, runePart in runes do
				runePart:Destroy()
			end
			disc:Destroy()
			outer:Destroy()
			inner:Destroy()
			return
		end
		local alpha = t < 0.15 and t / 0.15 or (t > 0.7 and (1 - t) / 0.3 or 1)
		disc.Transparency = 1 - 0.3 * alpha
		outer.Transparency = 1 - 0.65 * alpha
		for index, runePart in runes do
			local angle = index / 6 * math.pi * 2 + (os.clock() - started) * 2.5
			local rise = t * 2.5
			runePart.CFrame = CFrame.new(ground + Vector3.new(math.cos(angle) * 5.2, rise, math.sin(angle) * 5.2))
				* CFrame.Angles(0, -angle, 0)
			runePart.Transparency = 1 - 0.9 * alpha
		end
	end)
end

--- Постоянное свечение вокруг персонажа на время действия (шлейф скорости, сфера щита, искры исцеления).
local function aura(character: Model, kind: string, color: Color3, seconds: number)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	if kind == "haste" then
		local top = Instance.new("Attachment")
		top.Position = Vector3.new(0, 1.6, 0)
		top.Parent = root
		local bottom = Instance.new("Attachment")
		bottom.Position = Vector3.new(0, -1.8, 0)
		bottom.Parent = root
		local trail = Instance.new("Trail")
		trail.Attachment0 = top
		trail.Attachment1 = bottom
		trail.Lifetime = 0.45
		trail.LightEmission = 1
		trail.Color = ColorSequence.new(color, Color3.fromRGB(255, 255, 255))
		trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) })
		trail.Parent = root
		local streaks = Instance.new("ParticleEmitter")
		streaks.Rate = 25
		streaks.Lifetime = NumberRange.new(0.3, 0.5)
		streaks.Speed = NumberRange.new(0.5, 2)
		streaks.Color = ColorSequence.new(color)
		streaks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		streaks.LightEmission = 1
		streaks.Parent = root
		Debris:AddItem(trail, seconds)
		Debris:AddItem(streaks, seconds)
		Debris:AddItem(top, seconds + 1)
		Debris:AddItem(bottom, seconds + 1)
	elseif kind == "shield" then
		local sphere = part(Vector3.new(9, 9, 9), root.CFrame, color, Enum.PartType.Ball, 0.7)
		sphere.Material = Enum.Material.ForceField
		sphere.Anchored = false
		sphere.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = sphere
		weld.Parent = sphere
		sphere.Parent = character
		task.delay(math.max(seconds - 0.6, 0.2), function()
			if sphere.Parent then
				TweenService:Create(sphere, TweenInfo.new(0.6), { Transparency = 1 }):Play()
			end
		end)
		Debris:AddItem(sphere, seconds)
	elseif kind == "heal" then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Rate = 40
		emitter.Lifetime = NumberRange.new(0.8, 1.3)
		emitter.Speed = NumberRange.new(3, 6)
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.SpreadAngle = Vector2.new(25, 25)
		emitter.Color = ColorSequence.new(color, Color3.fromRGB(255, 255, 255))
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
		emitter.LightEmission = 1
		emitter.Parent = root
		Debris:AddItem(emitter, math.min(seconds, 2.5))
		task.delay(1.2, function()
			emitter.Enabled = false
		end)
	elseif kind == "stealth" then
		local mist = Instance.new("ParticleEmitter")
		mist.Rate = 18
		mist.Lifetime = NumberRange.new(0.8, 1.4)
		mist.Speed = NumberRange.new(0.5, 2)
		mist.SpreadAngle = Vector2.new(180, 180)
		mist.Color = ColorSequence.new(color)
		mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
		mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 3) })
		mist.LightEmission = 0.6
		mist.Parent = root
		Debris:AddItem(mist, math.min(seconds, 6))
	end
end

--- Заклинание применено: круг у ног, искры и (для длящихся эффектов) аура.
local function castEffect(character: Model, effect: string, seconds: number?)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not nearCamera(root.Position) then
		return
	end
	local kind = KIND_OF[effect] or "default"
	local colorKey = kind == "haste" and "buff" or kind
	local color = COLORS[colorKey] or COLORS.default
	magicCircle(root, color, 1.3)
	ring(root.Position - Vector3.new(0, 2.7, 0), color, 5, 20, 0.7)
	sparks(root.Position, color, 28, 16)
	if kind == "attack" then
		pillar(root.Position, color, 30, 0.5)
	elseif kind == "reveal" then
		ring(root.Position - Vector3.new(0, 2.5, 0), color, 6, 70, 1.2)
	elseif kind == "control" then
		ring(root.Position - Vector3.new(0, 2.5, 0), color, 6, 55, 0.9)
	end
	local duration = seconds or 6
	if kind == "haste" or kind == "shield" or kind == "heal" or kind == "stealth" then
		aura(character, kind, color, duration)
	end
end

function SpellFx.start()
	Remotes.Fx.OnClientEvent:Connect(function(data)
		if type(data) ~= "table" or type(data.kind) ~= "string" then
			return
		end
		local ok, err = pcall(function()
			if data.kind == "teleportOut" and typeof(data.position) == "Vector3" and nearCamera(data.position) then
				teleportFlash(data.position, false)
			elseif data.kind == "teleportIn" and typeof(data.position) == "Vector3" and nearCamera(data.position) then
				teleportFlash(data.position, true)
			elseif data.kind == "cast" and type(data.effect) == "string" then
				local player = Players:GetPlayerByUserId(data.userId)
				local character = player and player.Character
				if character then
					castEffect(character, data.effect, tonumber(data.seconds))
				end
			end
		end)
		if not ok then
			warn("[SpellFx] " .. tostring(err))
		end
	end)
end

return SpellFx
