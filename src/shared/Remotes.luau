local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DEFS = {
	SpawnCar = "RemoteEvent", -- client -> server (carName: string)
	DespawnCar = "RemoteEvent", -- client -> server
	GetCars = "RemoteFunction", -- client -> server, returns { string }
	ShashkiScore = "RemoteEvent", -- server -> client { score, combo, mult, popup? }
}

local isServer = RunService:IsServer()
local folder
if isServer then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local Remotes = {}
for name, className in DEFS do
	if isServer then
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
		Remotes[name] = remote
	else
		Remotes[name] = folder:WaitForChild(name)
	end
end

return Remotes
