-- Мелкие клиентские эффекты: предметы в мире парят и вращаются, чтобы их было видно издалека.
local RunService = game:GetService("RunService")

local Effects = {}

function Effects.start()
	local baseHeight: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
	local itemsFolder: Instance? = nil

	task.spawn(function()
		local world = workspace:WaitForChild("World")
		itemsFolder = world:WaitForChild("Items")
	end)

	RunService.Heartbeat:Connect(function()
		local folder = itemsFolder
		local camera = workspace.CurrentCamera
		if not folder or not camera then
			return
		end
		local now = os.clock()
		local origin = camera.CFrame.Position
		for _, node in folder:GetChildren() do
			if node:IsA("BasePart") and node.Transparency < 1 then
				local position = node.Position
				if (position - origin).Magnitude < 160 then
					local base = baseHeight[node]
					if not base then
						base = position.Y
						baseHeight[node] = base
					end
					-- парение и вращение (локально на клиенте, сервер ничего не знает)
					node.CFrame = CFrame.new(position.X, base + math.sin(now * 2 + position.X) * 0.5, position.Z) * CFrame.Angles(0, now, 0)
				end
			end
		end
	end)
end

return Effects
