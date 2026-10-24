local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local T = Config.Traffic

local TrafficService = {}

local COLORS = {
	Color3.fromRGB(196, 40, 28),
	Color3.fromRGB(13, 105, 172),
	Color3.fromRGB(245, 205, 48),
	Color3.fromRGB(226, 226, 226),
	Color3.fromRGB(40, 40, 44),
	Color3.fromRGB(75, 151, 75),
	Color3.fromRGB(160, 95, 53),
}

------------------------------------------------------------------------
-- Lanes
------------------------------------------------------------------------

-- Сглаживание углов (Chaikin) - машины едут по плавным дугам
local function chaikin(points, loop, iterations)
	for _ = 1, iterations do
		local n = #points
		local out = {}
		if not loop then
			table.insert(out, points[1])
		end
		for i = 1, if loop then n else n - 1 do
			local a = points[i]
			local b = points[i % n + 1]
			table.insert(out, a:Lerp(b, 0.25))
			table.insert(out, a:Lerp(b, 0.75))
		end
		if not loop then
			table.insert(out, points[n])
		end
		points = out
	end
	return points
end

local function loadLanes()
	local lanes = {}
	local root = workspace:FindFirstChild(T.PathsFolderName)
	if not root then
		warn(`Workspace.{T.PathsFolderName} not found - traffic disabled (see README)`)
		return lanes
	end

	for _, folder in root:GetChildren() do
		local waypoints = {}
		for _, part in folder:GetChildren() do
			if part:IsA("BasePart") and tonumber(part.Name) then
				table.insert(waypoints, part)
			end
		end
		table.sort(waypoints, function(a, b)
			return tonumber(a.Name) < tonumber(b.Name)
		end)

		if #waypoints >= 2 then
			local points = {}
			for _, part in waypoints do
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.Transparency = 1
				table.insert(points, part.Position)
			end

			local loop = folder:GetAttribute("Loop") ~= false
			points = chaikin(points, loop, 2)

			local cum = { 0 }
			for i = 2, #points do
				cum[i] = cum[i - 1] + (points[i] - points[i - 1]).Magnitude
			end
			local length = cum[#points]
			if loop then
				length += (points[1] - points[#points]).Magnitude
			end

			table.insert(lanes, {
				points = points,
				cum = cum,
				length = length,
				loop = loop,
				limit = folder:GetAttribute("SpeedLimit") or T.DefaultSpeedLimit,
			})
		else
			warn(`Lane '{folder.Name}' needs at least 2 waypoints named 1..N`)
		end
	end
	return lanes
end

-- Точка на полосе на расстоянии s от начала: позиция и индекс следующего вейпоинта
local function pointAt(lane, s)
	local points, cum = lane.points, lane.cum
	local n = #points
	for i = n, 1, -1 do
		if cum[i] <= s then
			local j = i % n + 1
			if i == n and not lane.loop then
				return points[n], n
			end
			local segLen = (points[j] - points[i]).Magnitude
			local alpha = if segLen > 0 then (s - cum[i]) / segLen else 0
			return points[i]:Lerp(points[j], math.clamp(alpha, 0, 1)), j
		end
	end
	return points[1], 2
end

------------------------------------------------------------------------
-- Car models
------------------------------------------------------------------------

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function buildProcedural()
	local model = Instance.new("Model")
	local color = COLORS[math.random(#COLORS)]
	-- Передок = -Z (LookVector)
	local body = part({ Name = "Body", Size = Vector3.new(4, 1.2, 9), Color = color }, model)
	part({
		Name = "Cabin",
		Size = Vector3.new(3.4, 1.1, 4),
		Color = Color3.fromRGB(30, 34, 40),
		CFrame = body.CFrame * CFrame.new(0, 1.15, 0.5),
	}, model)
	for _, sx in { -2.1, 2.1 } do
		for _, sz in { -3, 3 } do
			part({
				Name = "Wheel",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.8, 2, 2),
				Color = Color3.fromRGB(20, 20, 20),
				CFrame = body.CFrame * CFrame.new(sx, -0.6, sz),
			}, model)
		end
	end
	model.PrimaryPart = body
	return model
end

local function prepareTemplate(model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanTouch = false
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		elseif d:IsA("VehicleSeat") or d:IsA("Seat") then
			d.Disabled = true
		end
	end
end

local function createModel()
	local folder = ServerStorage:FindFirstChild(T.TemplatesFolderName)
	local templates = {}
	if folder then
		for _, c in folder:GetChildren() do
			if c:IsA("Model") then
				table.insert(templates, c)
			end
		end
	end

	if #templates > 0 then
		local model = templates[math.random(#templates)]:Clone()
		prepareTemplate(model)
		return model, CFrame.Angles(0, math.rad(T.TemplateYawOffsetDegrees), 0)
	end
	return buildProcedural(), CFrame.identity
end

------------------------------------------------------------------------
-- Cars
------------------------------------------------------------------------

local lanes = {}
local cars = {}
local trafficFolder

local function playerPositions()
	local list = {}
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root then
			table.insert(list, root.Position)
		end
	end
	return list
end

local function applyPose(car)
	local base = car.pos + Vector3.new(0, car.groundOffset, 0)
	car.model:PivotTo(CFrame.lookAt(base, base + car.dir) * car.yaw)
end

-- Ставит машину на случайную свободную точку случайной полосы
local function placeCar(car)
	local players = playerPositions()
	local totalLength = 0
	for _, lane in lanes do
		totalLength += lane.length
	end

	for _ = 1, 30 do
		local pick = math.random() * totalLength
		local lane = lanes[#lanes]
		for _, l in lanes do
			if pick <= l.length then
				lane = l
				break
			end
			pick -= l.length
		end

		local s = math.random() * lane.length
		local pos, target = pointAt(lane, s)

		local ok = true
		for _, other in cars do
			if other ~= car and other.pos and (other.pos - pos).Magnitude < T.MinSpawnGap then
				ok = false
				break
			end
		end
		if ok then
			for _, pp in players do
				if (pp - pos).Magnitude < T.MinPlayerSpawnDistance then
					ok = false
					break
				end
			end
		end

		if ok then
			car.lane = lane
			car.pos = pos
			car.target = target
			car.dir = (lane.points[target] - pos).Unit
			car.speed = 0
			car.stuck = 0
			car.limit = lane.limit * (0.85 + math.random() * 0.15)
			applyPose(car)
			return true
		end
	end
	return false
end

local function advance(car, dt)
	local lane = car.lane
	local n = #lane.points
	local remaining = car.speed * dt
	while remaining > 0 do
		local targetPos = lane.points[car.target]
		local vec = targetPos - car.pos
		local d = vec.Magnitude
		if d <= remaining then
			car.pos = targetPos
			remaining -= d
			if car.target == n then
				if lane.loop then
					car.target = 1
				else
					return false -- доехала до конца открытой полосы
				end
			else
				car.target += 1
			end
		else
			car.pos += vec.Unit * remaining
			remaining = 0
		end
	end
	return true
end

local function step(car, dt)
	-- Препятствие впереди -> тормозим
	local lookAhead = 10 + car.speed * 0.8
	local origin = car.pos + Vector3.new(0, 2.5, 0) + car.dir * car.frontOffset
	local hit = workspace:Raycast(origin, car.dir * lookAhead, car.rayParams)

	local targetSpeed = car.limit
	if hit then
		local free = hit.Distance - 4
		targetSpeed = if free <= 0 then 0 else car.limit * math.clamp(free / (lookAhead - 4), 0, 1)
	end

	if targetSpeed < car.speed then
		car.speed = math.max(targetSpeed, car.speed - T.Brake * dt)
	else
		car.speed = math.min(targetSpeed, car.speed + T.Accel * dt)
	end

	if car.speed < 0.5 then
		car.stuck += dt
	else
		car.stuck = 0
	end
	if car.stuck > T.StuckSeconds then
		placeCar(car)
		return
	end

	if not advance(car, dt) then
		placeCar(car)
		return
	end

	local toTarget = car.lane.points[car.target] - car.pos
	if toTarget.Magnitude > 0.01 then
		car.dir = car.dir:Lerp(toTarget.Unit, math.min(1, dt * 8)).Unit
	end
	applyPose(car)
end

function TrafficService.getCars()
	return cars
end

function TrafficService.start()
	if not T.Enabled then
		return
	end
	lanes = loadLanes()
	if #lanes == 0 then
		return
	end

	trafficFolder = Instance.new("Folder")
	trafficFolder.Name = "Traffic"
	trafficFolder.Parent = workspace

	for i = 1, T.Count do
		local model, yaw = createModel()
		model.Name = `TrafficCar{i}`
		model.Parent = trafficFolder

		local bboxCF, bboxSize = model:GetBoundingBox()
		local bottomY = bboxCF.Y - bboxSize.Y / 2

		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = { model }
		rayParams.RespectCanCollide = true

		local car = {
			model = model,
			yaw = yaw,
			groundOffset = model:GetPivot().Y - bottomY + 0.1,
			frontOffset = math.max(bboxSize.X, bboxSize.Z) / 2 + 1,
			rayParams = rayParams,
		}
		if placeCar(car) then
			table.insert(cars, car)
		else
			model:Destroy()
		end
	end

	RunService.Heartbeat:Connect(function(dt)
		if #Players:GetPlayers() == 0 then
			return
		end
		for _, car in cars do
			step(car, dt)
		end
	end)
end

return TrafficService
