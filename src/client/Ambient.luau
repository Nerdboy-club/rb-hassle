-- Лёгкая «жизнь» мира на клиенте: ближние лодки качаются на воде, кроны деревьев чуть колышутся.
-- Двигаем не больше нескольких десятков частей рядом с камерой, остальные стоят — нагрузки почти нет.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Ambient = {}

type Tracked = { part: BasePart, base: CFrame, phase: number }

local CONFIG = {
	Bob = { limit = 12, radius = 220 },
	Sway = { limit = 40, radius = 110 },
}

function Ambient.start()
	local tracked: { [string]: { Tracked } } = { Bob = {}, Sway = {} }
	local active: { [string]: { Tracked } } = { Bob = {}, Sway = {} }

	for tag in CONFIG do
		local function add(instance: Instance)
			if instance:IsA("BasePart") then
				local phase = instance:GetAttribute("BobPhase") or (instance.Position.X * 0.37 + instance.Position.Z * 0.21)
				table.insert(tracked[tag], { part = instance, base = instance.CFrame, phase = phase })
			end
		end
		for _, instance in CollectionService:GetTagged(tag) do
			add(instance)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(add)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
			for index, entry in tracked[tag] do
				if entry.part == instance then
					table.remove(tracked[tag], index)
					break
				end
			end
		end)
	end

	local function pickNearest()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local origin = camera.CFrame.Position
		for tag, config in CONFIG do
			local candidates = {}
			for _, entry in tracked[tag] do
				local distance = (entry.base.Position - origin).Magnitude
				if distance <= config.radius then
					table.insert(candidates, { entry = entry, distance = distance })
				end
			end
			table.sort(candidates, function(a, b)
				return a.distance < b.distance
			end)
			local picked = {}
			for index = 1, math.min(config.limit, #candidates) do
				table.insert(picked, candidates[index].entry)
			end
			-- те, что выпали из выборки, возвращаем на место
			for _, entry in active[tag] do
				if not table.find(picked, entry) and entry.part.Parent then
					entry.part.CFrame = entry.base
				end
			end
			active[tag] = picked
		end
	end

	local pickClock, moveClock = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		pickClock += dt
		moveClock += dt
		if pickClock >= 0.5 then
			pickClock = 0
			pickNearest()
		end
		if moveClock < 1 / 20 then
			return
		end
		moveClock = 0
		local now = os.clock()
		for _, entry in active.Bob do
			local t = now * 1.4 + entry.phase
			entry.part.CFrame = entry.base * CFrame.new(0, math.sin(t) * 0.18, 0) * CFrame.Angles(math.sin(t * 0.8) * 0.03, 0, math.cos(t * 1.1) * 0.05)
		end
		for _, entry in active.Sway do
			local t = now * 1.1 + entry.phase
			entry.part.CFrame = entry.base + Vector3.new(math.sin(t) * 0.3, 0, math.cos(t * 0.8) * 0.3)
		end
	end)
end

return Ambient
