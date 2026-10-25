-- Модельки предметов в мире: собираются из простых частей по типу карты (ассеты не нужны).
-- Части привариваются к узлу-«ядру» (см. ItemService), поэтому парят и вращаются вместе с ним.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ranks = require(ReplicatedStorage:WaitForChild("Shared").Ranks)

local ItemModels = {}

local C3 = Color3.fromRGB

local function part(node: Part, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Size = size
	p.Shape = shape or Enum.PartType.Block
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CFrame = node.CFrame * offset
	p.Parent = node
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = node
	weld.Part1 = p
	weld.Parent = p
	p:SetAttribute("Model", true)
	return p
end

--- Вертикальный цилиндр (ось цилиндра в Roblox — X).
local function cyl(node: Part, height: number, diameter: number, offset: CFrame, color: Color3, material: Enum.Material?): Part
	return part(node, Vector3.new(height, diameter, diameter), offset * CFrame.Angles(0, 0, math.pi / 2), color, material, Enum.PartType.Cylinder)
end

local BUILDERS: { [string]: (Part, Color3) -> () } = {}

function BUILDERS.sword(node, tint)
	part(node, Vector3.new(0.35, 3.2, 0.12), CFrame.new(0, 0.4, 0), C3(205, 212, 225), Enum.Material.Metal)
	part(node, Vector3.new(1.5, 0.22, 0.3), CFrame.new(0, -1.1, 0), tint, Enum.Material.Metal)
	part(node, Vector3.new(0.28, 0.9, 0.28), CFrame.new(0, -1.7, 0), C3(90, 60, 40), Enum.Material.Wood)
end

function BUILDERS.potion(node, tint)
	part(node, Vector3.new(1.5, 1.6, 1.5), CFrame.new(0, -0.5, 0), tint, Enum.Material.Glass, Enum.PartType.Ball).Transparency = 0.25
	cyl(node, 0.9, 0.6, CFrame.new(0, 0.7, 0), C3(220, 225, 235), Enum.Material.Glass)
	cyl(node, 0.4, 0.7, CFrame.new(0, 1.3, 0), C3(130, 90, 55), Enum.Material.Wood)
end

function BUILDERS.food(node, tint)
	part(node, Vector3.new(1.8, 1.6, 1.8), CFrame.new(0, -0.2, 0), tint, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	part(node, Vector3.new(0.2, 0.6, 0.2), CFrame.new(0, 0.8, 0), C3(90, 60, 35), Enum.Material.Wood)
	part(node, Vector3.new(0.7, 0.12, 0.4), CFrame.new(0.4, 0.95, 0) * CFrame.Angles(0, 0, 0.4), C3(70, 170, 70), Enum.Material.Grass)
end

function BUILDERS.gift(node, tint)
	local ribbon = C3(250, 235, 120)
	part(node, Vector3.new(1.9, 1.5, 1.9), CFrame.new(0, -0.3, 0), tint, Enum.Material.SmoothPlastic)
	part(node, Vector3.new(0.35, 1.55, 1.95), CFrame.new(0, -0.3, 0), ribbon, Enum.Material.SmoothPlastic)
	part(node, Vector3.new(1.95, 1.55, 0.35), CFrame.new(0, -0.3, 0), ribbon, Enum.Material.SmoothPlastic)
	part(node, Vector3.new(0.9, 0.5, 0.5), CFrame.new(0, 0.7, 0), ribbon, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
end

function BUILDERS.currency(node, _tint)
	for index = 0, 2 do
		cyl(node, 0.35, 1.7, CFrame.new(0, -0.7 + index * 0.4, 0), C3(240, 205, 90), Enum.Material.Metal)
	end
end

function BUILDERS.ticket(node, tint)
	part(node, Vector3.new(2.6, 1.5, 0.15), CFrame.new(0, 0, 0), C3(240, 230, 200), Enum.Material.SmoothPlastic)
	part(node, Vector3.new(2.6, 0.3, 0.2), CFrame.new(0, 0.6, 0), tint, Enum.Material.SmoothPlastic)
end

function BUILDERS.magic(node, tint)
	part(node, Vector3.new(1.4, 1.4, 1.4), CFrame.new(0, 0, 0), tint, Enum.Material.Neon, Enum.PartType.Ball)
	cyl(node, 0.15, 2.8, CFrame.Angles(0.5, 0, 0.3), C3(235, 240, 255), Enum.Material.Neon)
end

function BUILDERS.monster(node, tint)
	local horn = C3(240, 240, 235)
	local eye = C3(20, 20, 25)
	part(node, Vector3.new(1.9, 1.7, 1.9), CFrame.new(0, -0.2, 0), tint, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	part(node, Vector3.new(0.5, 0.9, 0.5), CFrame.new(-0.6, 0.9, 0) * CFrame.Angles(0, 0, 0.3), horn, Enum.Material.SmoothPlastic)
	part(node, Vector3.new(0.5, 0.9, 0.5), CFrame.new(0.6, 0.9, 0) * CFrame.Angles(0, 0, -0.3), horn, Enum.Material.SmoothPlastic)
	part(node, Vector3.new(0.4, 0.4, 0.2), CFrame.new(-0.4, 0, -0.9), eye, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	part(node, Vector3.new(0.4, 0.4, 0.2), CFrame.new(0.4, 0, -0.9), eye, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
end

function BUILDERS.animal(node, tint)
	part(node, Vector3.new(1.8, 2, 1.6), CFrame.new(0, -0.2, 0), tint, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	part(node, Vector3.new(0.5, 0.5, 0.7), CFrame.new(0, 0.3, -0.9), C3(240, 180, 60), Enum.Material.SmoothPlastic)
	part(node, Vector3.new(2.6, 0.2, 1.1), CFrame.new(0, -0.1, 0.2), tint:Lerp(C3(0, 0, 0), 0.25), Enum.Material.SmoothPlastic)
end

function BUILDERS.person(node, tint)
	part(node, Vector3.new(1.3, 1.9, 1.3), CFrame.new(0, -0.5, 0), tint, Enum.Material.SmoothPlastic)
	part(node, Vector3.new(1.1, 1.1, 1.1), CFrame.new(0, 0.9, 0), C3(240, 205, 175), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
end

function BUILDERS.place(node, tint)
	part(node, Vector3.new(2.2, 1.4, 2.2), CFrame.new(0, -0.4, 0), tint, Enum.Material.Brick)
	part(node, Vector3.new(2.7, 0.4, 2.7), CFrame.new(0, 0.5, 0), C3(130, 70, 55), Enum.Material.Slate)
end

--- Кристалл по умолчанию: повёрнутый кубик и столбик из стекла.
function BUILDERS.item(node, tint)
	part(node, Vector3.new(1.4, 1.4, 1.4), CFrame.Angles(math.rad(45), math.rad(45), 0), tint, Enum.Material.Neon)
	part(node, Vector3.new(0.8, 2.6, 0.8), CFrame.Angles(0, math.rad(45), 0), tint:Lerp(C3(255, 255, 255), 0.4), Enum.Material.Glass)
end

-- по названию оружие получает свою форму
local SWORD_WORDS = { "Меч", "Клинок", "Нож", "Кинжал", "Сабля", "Топор" }

function ItemModels.attach(node: Part, card: { kind: string, rank: string, name: string })
	local tint = Ranks.color(card.rank)
	local builder = BUILDERS[card.kind] or BUILDERS.item
	for _, word in SWORD_WORDS do
		if string.find(card.name, word, 1, true) then
			builder = BUILDERS.sword
			break
		end
	end
	if not pcall(builder, node, tint) then
		pcall(BUILDERS.item, node, tint)
	end
end

--- Показать или спрятать модельку вместе с ядром.
function ItemModels.setVisible(node: Part, visible: boolean)
	for _, child in node:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("Model") then
			local base = child:GetAttribute("BaseTransparency")
			if base == nil then
				base = child.Transparency
				child:SetAttribute("BaseTransparency", base)
			end
			child.Transparency = visible and base or 1
		end
	end
end

return ItemModels
