-- Действия игрока с книгой: вложить карту из руки, вернуть в исходное состояние, «Приращение».
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Binder = require(script.Parent.Binder)
local Hand = require(script.Parent.Hand)
local PlayerData = require(script.Parent.PlayerData)

local BinderActions = {}

local function isInt(value: any): boolean
	return type(value) == "number" and value == math.floor(value)
end

local function handle(player: Player, data: any)
	if type(data) ~= "table" then
		return
	end
	if data.action == "sync" then
		PlayerData.push(player)
		return
	end
	local profile = PlayerData.get(player)
	-- карты работают только внутри игры
	if not profile or not profile.inGame then
		return
	end
	if data.action == "insert" and isInt(data.uid) then
		Hand.insert(player, data.uid)
	elseif data.action == "release" then
		Binder.release(player, { slot = isInt(data.slot) and data.slot or nil, uid = isInt(data.uid) and data.uid or nil })
	elseif data.action == "gain" then
		Binder.gain(player, { slot = isInt(data.slot) and data.slot or nil, uid = isInt(data.uid) and data.uid or nil })
	end
end

function BinderActions.start()
	Remotes.BinderAction.OnServerEvent:Connect(handle)
end

return BinderActions
