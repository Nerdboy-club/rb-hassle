local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DEFS = {
	-- server -> client
	State = "RemoteEvent", -- полный снимок книги: слоты, свободные, рука, йены, встреченные
	Notify = "RemoteEvent", -- { text, kind }
	Dialog = "RemoteEvent", -- { npcId, name, text, options = { {id, label} } } либо { close = true }
	ShopOpen = "RemoteEvent", -- { shopId, name, spells, yen, buy = {...}, sell = {...} }
	Quiz = "RemoteEvent", -- { kind, qid, text, options, seconds, round, total } либо { close = true }
	Hint = "RemoteEvent", -- { positions = {Vector3}, seconds }
	Status = "RemoteEvent", -- { effects = { {name, seconds} }, stance }
	Phase = "RemoteEvent", -- "lobby" | "game" | "win"
	-- client -> server
	BinderAction = "RemoteEvent", -- { action = "insert"|"release"|"gain", ... }
	DialogChoice = "RemoteEvent", -- { npcId, optionId }
	ShopAction = "RemoteEvent", -- { shopId, action = "buy"|"sell"|"info", cardId }
	QuizAnswer = "RemoteEvent", -- { qid, index }
	Attack = "RemoteEvent", -- Vector3 направление удара
	Stance = "RemoteEvent", -- "ten" | "zetsu" | "none"
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
