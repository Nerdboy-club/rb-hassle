-- Анимация удара «Нен»: замах правой рукой, поворот к цели и светящаяся дуга перед персонажем.
-- Рука двигается через C0 плеча (Motor6D) — ассеты анимаций не нужны; видно только самому игроку.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local AttackFx = {}

local SWING_SECONDS = 0.28
local MIN_GAP = 0.4
local lastPlay = 0

local function slash(root: BasePart, forward: Vector3)
	local flat = Vector3.new(forward.X, 0, forward.Z)
	if flat.Magnitude < 0.01 then
		flat = root.CFrame.LookVector
	end
	local base = CFrame.lookAt(root.Position + Vector3.new(0, 0.8, 0), root.Position + Vector3.new(0, 0.8, 0) + flat)
	local arc = Instance.new("Part")
	arc.Name = "AttackArc"
	arc.Anchored = true
	arc.CanCollide = false
	arc.CanQuery = false
	arc.CanTouch = false
	arc.Material = Enum.Material.Neon
	arc.Color = Color3.fromRGB(150, 220, 255)
	arc.Size = Vector3.new(0.25, 0.25, 6)
	arc.Transparency = 0.1
	arc.CFrame = base * CFrame.Angles(0, math.rad(-70), 0) * CFrame.new(0, 0, -4)
	arc.Parent = workspace
	local spin = Instance.new("CFrameValue")
	spin.Value = base * CFrame.Angles(0, math.rad(-70), 0) * CFrame.new(0, 0, -4)
	local tween = TweenService:Create(spin, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Value = base * CFrame.Angles(0, math.rad(70), 0) * CFrame.new(0, 0, -4),
	})
	spin.Changed:Connect(function(value)
		arc.CFrame = value
	end)
	tween:Play()
	TweenService:Create(arc, TweenInfo.new(0.25), { Transparency = 1 }):Play()
	task.delay(0.3, function()
		spin:Destroy()
		arc:Destroy()
	end)
end

local function findShoulder(character: Model): Motor6D?
	local upper = character:FindFirstChild("RightUpperArm") -- R15
	local motor = upper and upper:FindFirstChild("RightShoulder")
	if motor and motor:IsA("Motor6D") then
		return motor
	end
	return nil -- R6: только дуга
end

--- direction — куда бьёт игрок (мировой вектор).
function AttackFx.play(direction: Vector3)
	local now = os.clock()
	if now - lastPlay < MIN_GAP then
		return
	end
	lastPlay = now
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not root then
		return
	end

	-- повернуться лицом к цели (только по горизонтали)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude > 0.05 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
	end
	slash(root, flat)

	local shoulder = findShoulder(character)
	if not shoulder then
		return
	end
	local rest = shoulder.C0
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - started) / SWING_SECONDS
		if t >= 1 or not shoulder.Parent then
			shoulder.C0 = rest
			connection:Disconnect()
			return
		end
		-- быстрый замах вперёд-вверх и возврат
		local angle = math.sin(t * math.pi) * math.rad(150)
		shoulder.C0 = rest * CFrame.Angles(angle, 0, 0)
	end)
end

return AttackFx
