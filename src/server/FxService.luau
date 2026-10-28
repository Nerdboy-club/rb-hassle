-- Визуальные эффекты магии: сервер лишь говорит клиентам, что показать (рисует client/SpellFx.luau).
-- Эффекты видят все игроки рядом, на игровую логику они не влияют.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local FxService = {}

--- Вспышка телепортации в точке (уход или появление).
function FxService.flash(kind: string, position: Vector3)
	Remotes.Fx:FireAllClients({ kind = kind, position = position })
end

--- Телепорт игрока: вспышка в старой точке, затем игрок оказывается в новой.
--- move() должен сам переставить персонажа.
function FxService.teleport(player: Player, move: () -> ())
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local from = root and root.Position
	move()
	local after = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if from then
		Remotes.Fx:FireAllClients({ kind = "teleportOut", position = from })
	end
	if after then
		Remotes.Fx:FireAllClients({ kind = "teleportIn", position = after.Position, userId = player.UserId })
	end
end

--- Эффект применённого заклинания вокруг игрока. effect — тип из Spells.luau, seconds — длительность (если есть).
function FxService.cast(player: Player, effect: string, seconds: number?)
	Remotes.Fx:FireAllClients({ kind = "cast", userId = player.UserId, effect = effect, seconds = seconds })
end

--- Предмет подобран: только подобравший видит, как он превращается в карту и летит в книгу.
function FxService.pickup(player: Player, position: Vector3, cardId: number)
	Remotes.Fx:FireClient(player, { kind = "pickup", position = position, cardId = cardId })
end

return FxService
