local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local S = Config.Shashki
local STEP = 0.1

local ShashkiService = {}

type State = {
	score: number,
	combo: number,
	lastHitAt: number,
	prevSpeed: number,
	prevCheckAt: number,
	cooldowns: { [any]: number },
}

local states: { [Player]: State } = {}

local function newState(): State
	return { score = 0, combo = 0, lastHitAt = 0, prevSpeed = 0, prevCheckAt = 0, cooldowns = {} }
end

local function multiplier(combo: number): number
	return math.clamp(1 + combo, 1, S.MaxMultiplier)
end

local function push(player: Player, state: State, popup: string?, crash: boolean?)
	Remotes.ShashkiScore:FireClient(player, {
		score = state.score,
		mult = multiplier(state.combo),
		popup = popup,
		crash = crash,
	})
end

local function tick(player: Player, state: State, trafficCars, now: number)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if not (seat and seat:IsA("VehicleSeat")) then
		state.prevSpeed = 0
		return
	end

	local speed = seat.AssemblyLinearVelocity.Magnitude -- studs/s
	local kmh = speed * Config.StudToMeters * 3.6

	-- Авария: резкая потеря скорости
	if state.prevSpeed > 0 and now - state.prevCheckAt <= 0.4 then
		local prevKmh = state.prevSpeed * Config.StudToMeters * 3.6
		if prevKmh >= S.MinSpeedKmh and speed < state.prevSpeed * (1 - S.CrashSpeedDrop) and state.combo > 0 then
			state.combo = 0
			push(player, state, "CRASH", true)
		end
	end
	state.prevSpeed = speed
	state.prevCheckAt = now

	-- Combo сгорает по таймауту
	if state.combo > 0 and now - state.lastHitAt > S.ComboWindow then
		state.combo = 0
		push(player, state, nil)
	end

	if kmh < S.MinSpeedKmh then
		return
	end

	local pos = seat.Position
	for _, car in trafficCars do
		if car.pos then
			local dist = (car.pos - pos).Magnitude
			if dist <= S.NearMissDistance then
				local last = state.cooldowns[car]
				if not last or now - last >= S.PerCarCooldown then
					state.cooldowns[car] = now
					state.combo += 1
					state.lastHitAt = now
					local mult = multiplier(state.combo)
					local speedBonus = math.floor(kmh / 100)
					local points = (S.BasePoints + speedBonus * 10) * mult
					state.score += points
					push(player, state, `NEAR MISS +{points}`)
				end
			end
		end
	end
end

function ShashkiService.start(trafficService)
	local function onPlayer(player: Player)
		states[player] = newState()
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(STEP)
			local now = os.clock()
			local cars = trafficService.getCars()
			for player, state in states do
				tick(player, state, cars, now)
			end
		end
	end)
end

return ShashkiService
