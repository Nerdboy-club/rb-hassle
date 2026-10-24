-- Клиентское состояние: последний снимок книги от сервера и сигнал об изменении.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

export type Snapshot = {
	slots: { number },
	free: { { uid: number, id: number } },
	hand: { { uid: number, id: number, left: number } },
	yen: number,
	met: { string },
	won: boolean,
	case: { number },
	inGame: boolean,
	cured: number,
	flags: { string },
}

local State = {}

State.data = nil :: Snapshot?
State.receivedAt = 0
State.phase = "lobby"
State.stance = "none"
State.effects = {} :: { { name: string, seconds: number } }
State.statusAt = 0
State.changed = Instance.new("BindableEvent")

function State.owns(id: number): boolean
	local data = State.data
	if not data then
		return false
	end
	if table.find(data.slots, id) then
		return true
	end
	for _, entry in data.free do
		if entry.id == id then
			return true
		end
	end
	return false
end

function State.hasFlag(name: string): boolean
	return State.data ~= nil and table.find(State.data.flags or {}, name) ~= nil
end

function State.ownsSlot(id: number): boolean
	return State.data ~= nil and table.find(State.data.slots, id) ~= nil
end

--- Сколько секунд осталось у карты в руке прямо сейчас.
function State.handLeft(entry: { left: number }): number
	return math.max(0, entry.left - (os.clock() - State.receivedAt))
end

Remotes.State.OnClientEvent:Connect(function(snapshot)
	State.data = snapshot
	State.receivedAt = os.clock()
	State.changed:Fire()
end)

Remotes.Phase.OnClientEvent:Connect(function(phase)
	State.phase = phase
	State.changed:Fire()
end)

Remotes.Status.OnClientEvent:Connect(function(status)
	State.stance = status.stance or "none"
	State.effects = status.effects or {}
	State.statusAt = os.clock()
	State.changed:Fire()
end)

return State
