-- Удар «Нен»: клик по цели. Сервер сам пускает луч от игрока и проверяет дальность и перезарядку.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local PlayerData = require(script.Parent.PlayerData)
local Status = require(script.Parent.Status)
local MonsterService = require(script.Parent.MonsterService)

local CombatService = {}

local lastAttack: { [Player]: number } = {}

local function handle(player: Player, direction: any)
	if typeof(direction) ~= "Vector3" or direction.Magnitude < 0.1 or direction.Magnitude ~= direction.Magnitude then
		return
	end
	local profile = PlayerData.get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not profile or not profile.inGame or not root or not humanoid or humanoid.Health <= 0 then
		return
	end

	local now = os.clock()
	if now - (lastAttack[player] or 0) < Status.attackCooldown(player) then
		return
	end
	lastAttack[player] = now

	local range = Status.attackRange(player)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character :: Instance }
	local origin = (root :: BasePart).Position + Vector3.new(0, 1.5, 0)
	local result = workspace:Raycast(origin, direction.Unit * range, params)
	if result and MonsterService.isMonsterPart(result.Instance) then
		MonsterService.hit(player, result.Instance :: BasePart, Config.BaseDamage)
	end
end

function CombatService.start()
	Remotes.Attack.OnServerEvent:Connect(handle)
	Players.PlayerRemoving:Connect(function(player)
		lastAttack[player] = nil
	end)
end

return CombatService
