local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local CarService = {}

local playerCars: { [Player]: Model } = {}
local lastSpawn: { [Player]: number } = {}

local function carsFolder()
	return ServerStorage:FindFirstChild(Config.CarsFolderName)
end

local function listCars(): { string }
	local names = {}
	local folder = carsFolder()
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("Model") then
				table.insert(names, child.Name)
			end
		end
		table.sort(names)
	end
	return names
end

local function despawn(player: Player)
	local car = playerCars[player]
	if car then
		car:Destroy()
		playerCars[player] = nil
	end
end

local function spawnCar(player: Player, carName: any)
	if typeof(carName) ~= "string" then
		return
	end

	local now = os.clock()
	if lastSpawn[player] and now - lastSpawn[player] < Config.SpawnCooldownSeconds then
		return
	end

	local folder = carsFolder()
	local template = folder and folder:FindFirstChild(carName)
	if not (template and template:IsA("Model")) then
		return
	end

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (hum and root and hum.Health > 0) then
		return
	end
	lastSpawn[player] = now

	despawn(player)

	local car = template:Clone()
	car.Name = `{player.Name}_{carName}`

	-- Позиция перед игроком, на земле
	local look = root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	flatLook = if flatLook.Magnitude > 0.01 then flatLook.Unit else Vector3.new(0, 0, -1)
	local ahead = root.Position + flatLook * Config.SpawnDistance

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { char }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(ahead + Vector3.new(0, 50, 0), Vector3.new(0, -150, 0), params)
	local groundY = if hit then hit.Position.Y else root.Position.Y - 3

	local yaw = CFrame.lookAt(Vector3.zero, flatLook) * CFrame.Angles(0, math.rad(Config.CarYawOffsetDegrees), 0)
	local pivot = car:GetPivot()
	local bboxCF, bboxSize = car:GetBoundingBox()
	local pivotToCenterY = pivot.Y - bboxCF.Y
	local y = groundY + bboxSize.Y / 2 + pivotToCenterY + 0.5

	car:PivotTo(CFrame.new(ahead.X, y, ahead.Z) * yaw.Rotation)
	car.Parent = workspace
	playerCars[player] = car

	local seat = car:FindFirstChildWhichIsA("VehicleSeat", true)
	if seat then
		task.defer(function()
			if hum.Parent and seat.Parent then
				seat:Sit(hum)
			end
		end)
	else
		warn(`Car '{carName}' has no VehicleSeat`)
	end
end

function CarService.start()
	if not carsFolder() then
		warn(`ServerStorage.{Config.CarsFolderName} not found - put car Models there (see README)`)
	end

	Remotes.GetCars.OnServerInvoke = function()
		return listCars()
	end
	Remotes.SpawnCar.OnServerEvent:Connect(spawnCar)
	Remotes.DespawnCar.OnServerEvent:Connect(despawn)

	local function onPlayer(player: Player)
		player.CharacterRemoving:Connect(function()
			despawn(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end

	Players.PlayerRemoving:Connect(function(player)
		despawn(player)
		lastSpawn[player] = nil
	end)
end

return CarService
