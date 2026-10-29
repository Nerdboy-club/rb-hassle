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

function BUILDERS.crown(node, tint)
	local gold = C3(242, 196, 70)
	cyl(node, 0.45, 1.9, CFrame.new(0, -0.75, 0), gold, Enum.Material.Metal)
	for index = 0, 4 do
		local angle = index * math.pi * 2 / 5
		local x = math.cos(angle) * 0.75
		local z = math.sin(angle) * 0.75
		part(node, Vector3.new(0.3, 0.95, 0.3), CFrame.new(x, 0.02, z) * CFrame.Angles(0, -angle, 0), gold, Enum.Material.Metal)
		part(node, Vector3.new(0.18, 0.18, 0.18), CFrame.new(x, 0.58, z), tint, Enum.Material.Neon, Enum.PartType.Ball)
	end
	part(node, Vector3.new(0.42, 0.38, 0.2), CFrame.new(0, -0.72, -0.98), tint, Enum.Material.Neon)
end

function BUILDERS.heart(node, tint)
	part(node, Vector3.new(0.9, 0.9, 0.9), CFrame.new(-0.35, 0.25, 0), tint, Enum.Material.Neon, Enum.PartType.Ball)
	part(node, Vector3.new(0.9, 0.9, 0.9), CFrame.new(0.35, 0.25, 0), tint, Enum.Material.Neon, Enum.PartType.Ball)
	part(node, Vector3.new(1.15, 1.25, 0.9), CFrame.new(0, -0.55, 0) * CFrame.Angles(0, 0, math.rad(45)), tint, Enum.Material.Neon)
end

function BUILDERS.gem(node, tint)
	part(node, Vector3.new(1.35, 1.35, 1.35), CFrame.Angles(0, math.rad(45), math.rad(45)), tint, Enum.Material.Neon)
	part(node, Vector3.new(0.85, 1.85, 0.85), CFrame.Angles(0, math.rad(45), 0), tint:Lerp(C3(255, 255, 255), 0.4), Enum.Material.Glass)
end

function BUILDERS.crystal(node, tint)
	part(node, Vector3.new(1.15, 1.75, 1.15), CFrame.Angles(math.rad(12), math.rad(45), math.rad(10)), tint, Enum.Material.Neon)
	part(node, Vector3.new(0.55, 1.15, 0.55), CFrame.new(0.55, -0.2, 0.15) * CFrame.Angles(math.rad(-10), math.rad(45), math.rad(15)), tint:Lerp(C3(255, 255, 255), 0.35), Enum.Material.Glass)
	part(node, Vector3.new(0.35, 0.8, 0.35), CFrame.new(-0.55, -0.45, -0.1) * CFrame.Angles(math.rad(20), 0, math.rad(-15)), tint, Enum.Material.Neon)
end

function BUILDERS.compass(node, tint)
	local gold = C3(232, 190, 80)
	cyl(node, 0.32, 1.95, CFrame.new(0, -0.15, 0), gold, Enum.Material.Metal)
	cyl(node, 0.12, 1.55, CFrame.new(0, 0.05, 0), C3(238, 232, 205), Enum.Material.SmoothPlastic)
	part(node, Vector3.new(0.12, 0.14, 1.2), CFrame.new(0, 0.16, 0), tint, Enum.Material.Neon)
	part(node, Vector3.new(0.26, 0.16, 0.26), CFrame.new(0, 0.2, 0), gold, Enum.Material.Metal, Enum.PartType.Ball)
end

function BUILDERS.tear(node, tint)
	part(node, Vector3.new(1.0, 1.0, 1.0), CFrame.new(0, -0.25, 0), tint, Enum.Material.Glass, Enum.PartType.Ball).Transparency = 0.15
	part(node, Vector3.new(0.7, 0.7, 0.7), CFrame.new(0, 0.45, 0) * CFrame.Angles(0, 0, math.rad(45)), tint, Enum.Material.Neon)
	part(node, Vector3.new(0.18, 0.5, 0.18), CFrame.new(0, 0.9, 0), tint:Lerp(C3(255, 255, 255), 0.4), Enum.Material.Neon)
end

function BUILDERS.owl(node, tint)
	local feather = tint:Lerp(C3(120, 85, 55), 0.35)
	local cream = C3(235, 220, 190)
	local dark = C3(25, 25, 30)
	part(node, Vector3.new(1.5, 1.9, 1.4), CFrame.new(0, -0.2, 0), feather, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	part(node, Vector3.new(1.15, 1.15, 1.15), CFrame.new(0, 0.9, 0), feather, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	part(node, Vector3.new(0.42, 0.42, 0.2), CFrame.new(-0.3, 0.95, -0.55), cream, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	part(node, Vector3.new(0.42, 0.42, 0.2), CFrame.new(0.3, 0.95, -0.55), cream, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	part(node, Vector3.new(0.18, 0.18, 0.12), CFrame.new(-0.3, 0.95, -0.7), dark, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	part(node, Vector3.new(0.18, 0.18, 0.12), CFrame.new(0.3, 0.95, -0.7), dark, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	part(node, Vector3.new(0.3, 0.22, 0.38), CFrame.new(0, 0.72, -0.68), C3(230, 160, 50), Enum.Material.SmoothPlastic)
	part(node, Vector3.new(0.35, 1.2, 1.0), CFrame.new(-0.9, -0.15, 0) * CFrame.Angles(0, 0, math.rad(12)), feather:Lerp(C3(0, 0, 0), 0.15), Enum.Material.SmoothPlastic)
	part(node, Vector3.new(0.35, 1.2, 1.0), CFrame.new(0.9, -0.15, 0) * CFrame.Angles(0, 0, math.rad(-12)), feather:Lerp(C3(0, 0, 0), 0.15), Enum.Material.SmoothPlastic)
end

function BUILDERS.shell(node, tint)
	local shell = tint:Lerp(C3(255, 210, 200), 0.55)
	for index = -2, 2 do
		part(node, Vector3.new(0.55, 1.5, 0.18), CFrame.new(index * 0.24, 0, 0) * CFrame.Angles(0, 0, index * 0.22), shell, Enum.Material.SmoothPlastic)
	end
	part(node, Vector3.new(0.35, 0.35, 0.35), CFrame.new(0, -0.6, 0.2), C3(245, 220, 190), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
end

function BUILDERS.pearl(node, tint)
	local shell = tint:Lerp(C3(255, 200, 210), 0.6)
	for index = -2, 2 do
		part(node, Vector3.new(0.5, 1.2, 0.16), CFrame.new(index * 0.22, -0.3, 0) * CFrame.Angles(0, 0, index * 0.18), shell, Enum.Material.SmoothPlastic)
	end
	part(node, Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, 0.15, -0.05), C3(245, 245, 235), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
end

function BUILDERS.horn(node, _tint)
	local cream = C3(240, 225, 190)
	cyl(node, 0.35, 1.0, CFrame.new(0, -0.9, 0), C3(210, 180, 110), Enum.Material.Metal)
	cyl(node, 0.85, 0.75, CFrame.new(0.05, -0.45, 0) * CFrame.Angles(0, 0, math.rad(15)), cream, Enum.Material.SmoothPlastic)
	cyl(node, 0.8, 0.55, CFrame.new(0.3, 0.1, 0) * CFrame.Angles(0, 0, math.rad(38)), cream, Enum.Material.SmoothPlastic)
	cyl(node, 0.75, 0.36, CFrame.new(0.65, 0.55, 0) * CFrame.Angles(0, 0, math.rad(62)), cream, Enum.Material.SmoothPlastic)
	cyl(node, 0.5, 0.2, CFrame.new(0.95, 0.82, 0) * CFrame.Angles(0, 0, math.rad(78)), cream, Enum.Material.SmoothPlastic)
end

function BUILDERS.chest(node, _tint)
	local wood = C3(120, 72, 40)
	local gold = C3(225, 180, 70)
	part(node, Vector3.new(2.1, 1.2, 1.4), CFrame.new(0, -0.35, 0), wood, Enum.Material.Wood)
	part(node, Vector3.new(2.2, 0.45, 1.5), CFrame.new(0, 0.5, 0) * CFrame.Angles(math.rad(-12), 0, 0), wood, Enum.Material.Wood)
	part(node, Vector3.new(0.18, 1.25, 1.48), CFrame.new(-0.65, -0.35, 0), gold, Enum.Material.Metal)
	part(node, Vector3.new(0.18, 1.25, 1.48), CFrame.new(0.65, -0.35, 0), gold, Enum.Material.Metal)
	part(node, Vector3.new(2.16, 0.18, 1.46), CFrame.new(0, -0.7, 0), gold, Enum.Material.Metal)
	part(node, Vector3.new(0.45, 0.45, 0.18), CFrame.new(0, 0.05, -0.78), gold, Enum.Material.Metal)
end

function BUILDERS.chip(node, tint)
	local gold = C3(238, 198, 82)
	cyl(node, 0.28, 1.9, CFrame.new(0, -0.2, 0), gold, Enum.Material.Metal)
	cyl(node, 0.3, 1.45, CFrame.new(0, 0.02, 0), C3(178, 128, 44), Enum.Material.Metal)
	part(node, Vector3.new(0.9, 0.14, 0.18), CFrame.new(0, 0.19, 0), tint, Enum.Material.Neon)
	part(node, Vector3.new(0.18, 0.14, 0.9), CFrame.new(0, 0.19, 0), tint, Enum.Material.Neon)
end

function BUILDERS.dice(node, tint)
	local white = C3(240, 235, 220)
	local dark = C3(30, 30, 35)
	part(node, Vector3.new(1.4, 1.4, 1.4), CFrame.Angles(0.2, 0.4, 0.1), white, Enum.Material.SmoothPlastic)
	for _, offset in {
		Vector3.new(-0.35, 0.35, -0.72),
		Vector3.new(0.35, 0.35, -0.72),
		Vector3.new(0, 0, -0.72),
		Vector3.new(-0.35, -0.35, -0.72),
		Vector3.new(0.35, -0.35, -0.72),
		Vector3.new(0, 0.72, 0),
	} do
		part(node, Vector3.new(0.18, 0.18, 0.18), CFrame.new(offset), dark, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
	part(node, Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 0.4, 0.72), tint, Enum.Material.Neon, Enum.PartType.Ball)
end

function BUILDERS.cards(node, tint)
	for index = 0, 2 do
		part(node, Vector3.new(1.3, 1.8, 0.08), CFrame.new(index * 0.16 - 0.16, 0, index * 0.12) * CFrame.Angles(0, math.rad(index * 12 - 12), 0), C3(245, 240, 225), Enum.Material.SmoothPlastic)
	end
	part(node, Vector3.new(0.8, 0.9, 0.09), CFrame.new(-0.16, 0, -0.05), tint, Enum.Material.SmoothPlastic)
end

function BUILDERS.shield(node, tint)
	part(node, Vector3.new(0.22, 2.2, 2.2), CFrame.Angles(0, math.pi / 2, 0), C3(105, 75, 45), Enum.Material.Metal, Enum.PartType.Cylinder)
	part(node, Vector3.new(0.26, 1.75, 1.75), CFrame.new(0, 0, -0.03) * CFrame.Angles(0, math.pi / 2, 0), tint, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	part(node, Vector3.new(0.5, 0.5, 0.25), CFrame.new(0, 0, -0.18), C3(225, 180, 70), Enum.Material.Metal, Enum.PartType.Ball)
end

function BUILDERS.key(node, _tint)
	local gold = C3(200, 160, 80)
	part(node, Vector3.new(1.9, 0.2, 0.2), CFrame.new(0, 0, 0.2) * CFrame.Angles(0, math.pi / 2, 0), gold, Enum.Material.Metal, Enum.PartType.Cylinder)
	part(node, Vector3.new(0.18, 0.85, 0.18), CFrame.new(0, 0.35, -0.95), gold, Enum.Material.Metal)
	part(node, Vector3.new(0.18, 0.85, 0.18), CFrame.new(0, -0.35, -0.95), gold, Enum.Material.Metal)
	part(node, Vector3.new(0.18, 0.85, 0.18), CFrame.new(-0.42, 0, -0.95), gold, Enum.Material.Metal)
	part(node, Vector3.new(0.18, 0.85, 0.18), CFrame.new(0.42, 0, -0.95), gold, Enum.Material.Metal)
	part(node, Vector3.new(0.45, 0.18, 0.18), CFrame.new(0.3, -0.28, 1.0), gold, Enum.Material.Metal)
	part(node, Vector3.new(0.3, 0.18, 0.18), CFrame.new(0.22, -0.28, 1.25), gold, Enum.Material.Metal)
end

function BUILDERS.hourglass(node, _tint)
	local wood = C3(110, 65, 35)
	local glass = C3(210, 235, 240)
	local sand = C3(235, 195, 90)
	cyl(node, 0.18, 1.55, CFrame.new(0, -0.95, 0), wood, Enum.Material.Wood)
	cyl(node, 0.18, 1.55, CFrame.new(0, 0.95, 0), wood, Enum.Material.Wood)
	for index = 0, 2 do
		local diameter = 1.35 - index * 0.33
		cyl(node, 0.3, diameter, CFrame.new(0, 0.72 - index * 0.28, 0), glass, Enum.Material.Glass).Transparency = 0.35
		cyl(node, 0.3, diameter, CFrame.new(0, -0.72 + index * 0.28, 0), glass, Enum.Material.Glass).Transparency = 0.35
	end
	part(node, Vector3.new(0.12, 0.6, 0.12), CFrame.new(0, 0, 0), sand, Enum.Material.Neon)
	part(node, Vector3.new(0.65, 0.25, 0.65), CFrame.new(0, -0.75, 0), sand, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
end

function BUILDERS.letter(node, _tint)
	part(node, Vector3.new(1.9, 1.2, 0.12), CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(-8), 0, 0), C3(245, 238, 215), Enum.Material.SmoothPlastic)
	part(node, Vector3.new(1.0, 1.0, 0.14), CFrame.new(0, 0, -0.02) * CFrame.Angles(0, 0, math.rad(45)), C3(232, 220, 190), Enum.Material.SmoothPlastic)
	part(node, Vector3.new(0.38, 0.38, 0.18), CFrame.new(0, -0.05, -0.1), C3(190, 45, 55), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
end

function BUILDERS.lantern(node, _tint)
	local metal = C3(75, 70, 65)
	local glass = C3(255, 225, 140)
	cyl(node, 0.2, 1.1, CFrame.new(0, -0.95, 0), metal, Enum.Material.Metal)
	cyl(node, 0.2, 1.1, CFrame.new(0, 0.95, 0), metal, Enum.Material.Metal)
	for index = 0, 3 do
		local angle = index * math.pi / 2
		local x = math.cos(angle) * 0.42
		local z = math.sin(angle) * 0.42
		part(node, Vector3.new(0.12, 1.8, 0.12), CFrame.new(x, 0, z), metal, Enum.Material.Metal)
	end
	part(node, Vector3.new(0.8, 1.35, 0.8), CFrame.new(0, 0, 0), glass, Enum.Material.Neon).Transparency = 0.15
	part(node, Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 1.15, 0), metal, Enum.Material.Metal, Enum.PartType.Ball)
	part(node, Vector3.new(0.18, 0.55, 0.18), CFrame.new(-0.2, 1.35, 0) * CFrame.Angles(0, 0, 0.45), metal, Enum.Material.Metal)
	part(node, Vector3.new(0.18, 0.55, 0.18), CFrame.new(0.2, 1.35, 0) * CFrame.Angles(0, 0, -0.45), metal, Enum.Material.Metal)
	part(node, Vector3.new(0.8, 0.14, 0.14), CFrame.new(0, 1.55, 0), metal, Enum.Material.Metal)
end

function BUILDERS.seal(node, tint)
	local gold = C3(225, 180, 70)
	cyl(node, 0.35, 1.35, CFrame.new(0, -0.55, 0), gold, Enum.Material.Metal)
	cyl(node, 0.65, 0.55, CFrame.new(0, 0.15, 0), gold, Enum.Material.Metal)
	part(node, Vector3.new(0.45, 0.45, 0.18), CFrame.new(0, 0.52, 0), tint, Enum.Material.Neon)
end

function BUILDERS.pickaxe(node, _tint)
	local wood = C3(120, 75, 40)
	local metal = C3(120, 125, 135)
	part(node, Vector3.new(2.7, 0.22, 0.22), CFrame.new(0, -0.1, 0) * CFrame.Angles(0, 0, math.rad(55)), wood, Enum.Material.Wood, Enum.PartType.Cylinder)
	part(node, Vector3.new(1.35, 0.3, 0.3), CFrame.new(0.72, 0.8, 0) * CFrame.Angles(0, 0, math.rad(28)), metal, Enum.Material.Metal, Enum.PartType.Cylinder)
	part(node, Vector3.new(1.35, 0.3, 0.3), CFrame.new(-0.1, 0.95, 0) * CFrame.Angles(0, 0, math.rad(-58)), metal, Enum.Material.Metal, Enum.PartType.Cylinder)
end

function BUILDERS.bow(node, _tint)
	local wood = C3(125, 80, 40)
	part(node, Vector3.new(0.2, 1.15, 0.2), CFrame.new(-0.5, 0.55, 0) * CFrame.Angles(0, 0, math.rad(-18)), wood, Enum.Material.Wood)
	part(node, Vector3.new(0.2, 1.2, 0.2), CFrame.new(-0.65, 0, 0), wood, Enum.Material.Wood)
	part(node, Vector3.new(0.2, 1.15, 0.2), CFrame.new(-0.5, -0.55, 0) * CFrame.Angles(0, 0, math.rad(18)), wood, Enum.Material.Wood)
	part(node, Vector3.new(0.07, 2.05, 0.07), CFrame.new(-0.15, 0, 0), C3(235, 230, 210), Enum.Material.SmoothPlastic)
end

function BUILDERS.net(node, _tint)
	local metal = C3(120, 125, 135)
	part(node, Vector3.new(2.0, 0.18, 0.18), CFrame.new(-0.6, -0.3, 0) * CFrame.Angles(0, 0, math.rad(35)), C3(120, 75, 40), Enum.Material.Wood, Enum.PartType.Cylinder)
	part(node, Vector3.new(0.15, 1.3, 0.15), CFrame.new(0.65, 0.65, 0), metal, Enum.Material.Metal)
	part(node, Vector3.new(0.15, 1.3, 0.15), CFrame.new(0.65, -0.1, 0), metal, Enum.Material.Metal)
	part(node, Vector3.new(1.3, 0.15, 0.15), CFrame.new(1.25, 0, 0), metal, Enum.Material.Metal)
	part(node, Vector3.new(1.3, 0.15, 0.15), CFrame.new(1.25, 1.25, 0), metal, Enum.Material.Metal)
	part(node, Vector3.new(1.1, 1.1, 0.06), CFrame.new(1.25, 0.62, 0), C3(220, 230, 235), Enum.Material.Glass).Transparency = 0.4
end

function BUILDERS.sack(node, tint)
	part(node, Vector3.new(1.5, 1.8, 1.4), CFrame.new(0, -0.2, 0), C3(185, 145, 95), Enum.Material.Fabric, Enum.PartType.Ball)
	cyl(node, 0.5, 0.55, CFrame.new(0, 0.95, 0), C3(150, 110, 70), Enum.Material.Fabric)
	part(node, Vector3.new(0.5, 0.35, 0.5), CFrame.new(0, 0.75, 0), C3(215, 180, 120), Enum.Material.Fabric)
	part(node, Vector3.new(0.4, 0.3, 0.1), CFrame.new(0, -0.15, -0.72), tint, Enum.Material.SmoothPlastic)
end

function BUILDERS.map(node, _tint)
	part(node, Vector3.new(2.2, 0.12, 1.5), CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(-8), 0), C3(240, 225, 185), Enum.Material.SmoothPlastic)
	part(node, Vector3.new(0.9, 0.16, 0.12), CFrame.new(0.45, 0.12, 0.25) * CFrame.Angles(0, math.rad(35), 0), C3(190, 50, 45), Enum.Material.SmoothPlastic)
	part(node, Vector3.new(0.9, 0.16, 0.12), CFrame.new(0.45, 0.12, 0.25) * CFrame.Angles(0, math.rad(-35), 0), C3(190, 50, 45), Enum.Material.SmoothPlastic)
	cyl(node, 0.35, 1.5, CFrame.new(-1.05, 0, 0), C3(210, 190, 145), Enum.Material.SmoothPlastic)
	cyl(node, 0.35, 1.5, CFrame.new(1.05, 0, 0), C3(210, 190, 145), Enum.Material.SmoothPlastic)
end

function BUILDERS.binoculars(node, _tint)
	local body = C3(55, 60, 65)
	for _, x in { -0.45, 0.45 } do
		cyl(node, 0.95, 0.55, CFrame.new(x, 0, 0), body, Enum.Material.Metal)
		part(node, Vector3.new(0.1, 0.38, 0.38), CFrame.new(x, 0, -0.48) * CFrame.Angles(0, math.pi / 2, 0), C3(150, 200, 220), Enum.Material.Glass, Enum.PartType.Cylinder)
	end
	part(node, Vector3.new(0.55, 0.18, 0.18), CFrame.new(0, 0, 0), body, Enum.Material.Metal)
end

function BUILDERS.amulet(node, tint)
	part(node, Vector3.new(0.18, 1.0, 1.0), CFrame.new(0, -0.2, 0) * CFrame.Angles(0, math.pi / 2, 0), C3(120, 80, 45), Enum.Material.Wood, Enum.PartType.Cylinder)
	part(node, Vector3.new(0.28, 0.5, 0.5), CFrame.new(0, -0.2, -0.12), tint, Enum.Material.Neon, Enum.PartType.Ball)
	part(node, Vector3.new(0.1, 0.9, 0.1), CFrame.new(-0.3, 0.45, 0) * CFrame.Angles(0, 0, -0.35), C3(80, 55, 35), Enum.Material.Fabric)
	part(node, Vector3.new(0.1, 0.9, 0.1), CFrame.new(0.3, 0.45, 0) * CFrame.Angles(0, 0, 0.35), C3(80, 55, 35), Enum.Material.Fabric)
end

function BUILDERS.bell(node, _tint)
	local gold = C3(225, 180, 70)
	cyl(node, 0.55, 1.0, CFrame.new(0, -0.15, 0), gold, Enum.Material.Metal)
	cyl(node, 0.55, 0.55, CFrame.new(0, 0.35, 0), gold, Enum.Material.Metal)
	part(node, Vector3.new(0.22, 0.22, 0.22), CFrame.new(0, 0.75, 0), gold, Enum.Material.Metal, Enum.PartType.Ball)
	part(node, Vector3.new(0.2, 0.35, 0.2), CFrame.new(0, -0.55, 0), C3(120, 90, 40), Enum.Material.Metal)
end

function BUILDERS.staff(node, tint)
	local wood = C3(120, 75, 40)
	cyl(node, 2.2, 0.18, CFrame.new(0, -0.2, 0), wood, Enum.Material.Wood)
	part(node, Vector3.new(0.55, 0.2, 0.2), CFrame.new(0.2, 0.85, 0) * CFrame.Angles(0, 0, 0.45), wood, Enum.Material.Wood)
	part(node, Vector3.new(0.55, 0.2, 0.2), CFrame.new(0.55, 1.1, 0) * CFrame.Angles(0, 0, 1.1), wood, Enum.Material.Wood)
	part(node, Vector3.new(0.42, 0.42, 0.42), CFrame.new(0.72, 1.28, 0), tint, Enum.Material.Neon, Enum.PartType.Ball)
end

function BUILDERS.scroll(node, tint)
	part(node, Vector3.new(1.8, 0.5, 0.5), CFrame.new(0, 0, 0), C3(235, 220, 185), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	cyl(node, 0.35, 0.16, CFrame.new(-0.92, 0.2, 0), C3(120, 75, 40), Enum.Material.Wood)
	cyl(node, 0.35, 0.16, CFrame.new(0.92, 0.2, 0), C3(120, 75, 40), Enum.Material.Wood)
	part(node, Vector3.new(0.18, 0.5, 0.6), CFrame.new(0, 0.32, 0), tint, Enum.Material.Fabric)
end

function BUILDERS.book(node, tint)
	part(node, Vector3.new(1.8, 0.25, 1.4), CFrame.new(0, -0.2, 0), tint:Lerp(C3(0, 0, 0), 0.35), Enum.Material.SmoothPlastic)
	part(node, Vector3.new(1.6, 0.2, 1.25), CFrame.new(0.05, -0.02, 0), C3(240, 230, 200), Enum.Material.SmoothPlastic)
	part(node, Vector3.new(0.2, 0.45, 1.4), CFrame.new(-0.9, -0.08, 0), tint:Lerp(C3(0, 0, 0), 0.5), Enum.Material.SmoothPlastic)
	part(node, Vector3.new(0.12, 0.1, 0.8), CFrame.new(0.55, -0.15, 0.5), C3(210, 70, 60), Enum.Material.SmoothPlastic)
end

function BUILDERS.mirror(node, _tint)
	local gold = C3(225, 180, 70)
	part(node, Vector3.new(0.22, 1.9, 1.9), CFrame.Angles(0, math.pi / 2, 0), gold, Enum.Material.Metal, Enum.PartType.Cylinder)
	part(node, Vector3.new(0.24, 1.55, 1.55), CFrame.new(0, 0, -0.05) * CFrame.Angles(0, math.pi / 2, 0), C3(190, 225, 235), Enum.Material.Glass, Enum.PartType.Cylinder).Transparency = 0.15
	cyl(node, 0.7, 0.18, CFrame.new(0, -1.15, 0), gold, Enum.Material.Metal)
end

function BUILDERS.flag(node, _tint)
	local white = C3(240, 235, 225)
	cyl(node, 2.3, 0.16, CFrame.new(-0.65, 0, 0), C3(105, 70, 40), Enum.Material.Wood)
	part(node, Vector3.new(1.4, 0.9, 0.08), CFrame.new(0.05, 0.45, 0), C3(35, 35, 40), Enum.Material.Fabric)
	part(node, Vector3.new(0.28, 0.28, 0.1), CFrame.new(0.05, 0.5, -0.06), white, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	part(node, Vector3.new(0.55, 0.1, 0.1), CFrame.new(0.05, 0.4, -0.08) * CFrame.Angles(0, 0, 0.5), white, Enum.Material.SmoothPlastic)
	part(node, Vector3.new(0.55, 0.1, 0.1), CFrame.new(0.05, 0.4, -0.08) * CFrame.Angles(0, 0, -0.5), white, Enum.Material.SmoothPlastic)
end

function BUILDERS.bouquet(node, _tint)
	local stem = C3(70, 140, 60)
	local petals = { C3(220, 60, 70), C3(240, 150, 180), C3(245, 210, 100) }
	for index = -1, 1 do
		cyl(node, 0.9, 0.1, CFrame.new(index * 0.22, -0.35, 0), stem, Enum.Material.Grass)
		part(node, Vector3.new(0.55, 0.5, 0.55), CFrame.new(index * 0.3, 0.25, 0), petals[index + 2], Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		part(node, Vector3.new(0.2, 0.2, 0.2), CFrame.new(index * 0.3, 0.25, -0.2), C3(245, 220, 100), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
	part(node, Vector3.new(0.7, 0.9, 0.7), CFrame.new(0, -0.55, 0), C3(210, 200, 180), Enum.Material.Fabric)
end

function BUILDERS.honey(node, _tint)
	cyl(node, 1.2, 1.3, CFrame.new(0, -0.2, 0), C3(220, 150, 45), Enum.Material.Glass).Transparency = 0.15
	cyl(node, 0.18, 1.0, CFrame.new(0, 0.55, 0), C3(120, 75, 40), Enum.Material.Wood)
	cyl(node, 0.25, 0.85, CFrame.new(0, 0.75, 0), C3(240, 215, 150), Enum.Material.SmoothPlastic)
	part(node, Vector3.new(0.18, 0.75, 0.18), CFrame.new(0.25, 0.85, 0) * CFrame.Angles(0, 0, 0.35), C3(180, 130, 60), Enum.Material.Wood)
end

function BUILDERS.toolbox(node, _tint)
	local red = C3(170, 55, 45)
	local metal = C3(150, 155, 160)
	part(node, Vector3.new(2.0, 1.0, 1.2), CFrame.new(0, -0.3, 0), red, Enum.Material.Metal)
	part(node, Vector3.new(2.05, 0.2, 1.25), CFrame.new(0, 0.25, 0), red:Lerp(C3(255, 255, 255), 0.15), Enum.Material.Metal)
	part(node, Vector3.new(1.0, 0.12, 0.12), CFrame.new(0, 0.75, 0), metal, Enum.Material.Metal)
	part(node, Vector3.new(0.12, 0.5, 0.12), CFrame.new(-0.45, 0.5, 0), metal, Enum.Material.Metal)
	part(node, Vector3.new(0.12, 0.5, 0.12), CFrame.new(0.45, 0.5, 0), metal, Enum.Material.Metal)
	part(node, Vector3.new(0.25, 0.3, 0.15), CFrame.new(0, 0.15, -0.65), C3(225, 180, 70), Enum.Material.Metal)
end

function BUILDERS.mushrooms(node, _tint)
	local stem = C3(235, 225, 200)
	local cap = C3(190, 70, 60)
	for index = -1, 1 do
		local x = index * 0.45
		cyl(node, 0.55, 0.14, CFrame.new(x, -0.45, 0), stem, Enum.Material.SmoothPlastic)
		part(node, Vector3.new(0.6, 0.35, 0.6), CFrame.new(x, -0.1, 0), cap, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
	part(node, Vector3.new(0.2, 0.16, 0.2), CFrame.new(-0.1, 0.05, 0), C3(245, 235, 220), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	part(node, Vector3.new(0.16, 0.12, 0.16), CFrame.new(0.55, 0.02, 0.15), C3(245, 235, 220), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
end

function BUILDERS.fish(node, _tint)
	local body = C3(130, 175, 200)
	part(node, Vector3.new(1.8, 1.0, 0.8), CFrame.new(0, 0, 0), body, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	part(node, Vector3.new(0.6, 1.0, 0.18), CFrame.new(-1.0, 0, 0) * CFrame.Angles(0, 0, math.rad(25)), body:Lerp(C3(0, 0, 0), 0.2), Enum.Material.SmoothPlastic)
	part(node, Vector3.new(0.6, 1.0, 0.18), CFrame.new(-1.0, 0, 0) * CFrame.Angles(0, 0, math.rad(-25)), body:Lerp(C3(0, 0, 0), 0.2), Enum.Material.SmoothPlastic)
	part(node, Vector3.new(0.5, 0.35, 0.1), CFrame.new(0, 0.45, 0), body:Lerp(C3(255, 255, 255), 0.2), Enum.Material.SmoothPlastic)
	part(node, Vector3.new(0.2, 0.2, 0.14), CFrame.new(0.55, 0.15, -0.38), C3(25, 25, 30), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
end

function BUILDERS.feather(node, _tint)
	local cream = C3(245, 240, 225)
	part(node, Vector3.new(1.8, 0.08, 0.08), CFrame.new(0, -0.1, 0) * CFrame.Angles(0, 0, math.rad(20)), C3(225, 215, 195), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	part(node, Vector3.new(0.5, 1.0, 0.06), CFrame.new(-0.25, 0.4, 0) * CFrame.Angles(0, 0, 0.4), cream, Enum.Material.SmoothPlastic)
	part(node, Vector3.new(0.5, 1.0, 0.06), CFrame.new(0.2, 0.5, 0) * CFrame.Angles(0, 0, -0.35), cream, Enum.Material.SmoothPlastic)
end

function BUILDERS.herb(node, _tint)
	for index = -1, 1 do
		part(node, Vector3.new(0.22, 1.4, 0.12), CFrame.new(index * 0.25, -0.1, 0) * CFrame.Angles(0, 0, index * 0.25), C3(70, 160, 70), Enum.Material.Grass)
	end
	part(node, Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 0.65, 0), C3(240, 220, 120), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
end

function BUILDERS.bracelet(node, tint)
	local shell = tint:Lerp(C3(255, 220, 200), 0.55)
	for index = 0, 5 do
		local angle = index * math.pi / 3
		part(node, Vector3.new(0.3, 0.3, 0.3), CFrame.new(math.cos(angle) * 0.75, 0, math.sin(angle) * 0.75), shell, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
	part(node, Vector3.new(0.45, 0.45, 0.45), CFrame.new(0.75, 0, 0), C3(250, 235, 220), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
end

function BUILDERS.wreath(node, _tint)
	for index = 0, 7 do
		local angle = index * math.pi / 4
		part(node, Vector3.new(0.5, 0.35, 0.3), CFrame.new(math.cos(angle) * 0.8, 0, math.sin(angle) * 0.8) * CFrame.Angles(0, -angle, 0), C3(70, 150, 60), Enum.Material.Grass)
	end
	for index = 0, 2 do
		local angle = index * math.pi * 2 / 3
		part(node, Vector3.new(0.35, 0.35, 0.35), CFrame.new(math.cos(angle) * 0.8, 0.15, math.sin(angle) * 0.8), C3(230, 120, 150), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
end

function BUILDERS.horseshoe(node, _tint)
	local gold = C3(220, 180, 80)
	part(node, Vector3.new(0.35, 1.5, 0.35), CFrame.new(-0.55, 0.1, 0), gold, Enum.Material.Metal)
	part(node, Vector3.new(0.35, 1.5, 0.35), CFrame.new(0.55, 0.1, 0), gold, Enum.Material.Metal)
	part(node, Vector3.new(1.45, 0.35, 0.35), CFrame.new(0, -0.65, 0), gold, Enum.Material.Metal)
	part(node, Vector3.new(0.55, 0.35, 0.35), CFrame.new(-0.35, 0.75, 0) * CFrame.Angles(0, 0, 0.5), gold, Enum.Material.Metal)
	part(node, Vector3.new(0.55, 0.35, 0.35), CFrame.new(0.35, 0.75, 0) * CFrame.Angles(0, 0, -0.5), gold, Enum.Material.Metal)
end

function BUILDERS.apple(node, _tint)
	part(node, Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, -0.15, 0), C3(190, 45, 45), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	cyl(node, 0.5, 0.12, CFrame.new(0, 0.7, 0), C3(100, 65, 35), Enum.Material.Wood)
	part(node, Vector3.new(0.5, 0.1, 0.25), CFrame.new(0.3, 0.8, 0) * CFrame.Angles(0, 0, -0.5), C3(70, 150, 60), Enum.Material.Grass)
end

function BUILDERS.vine(node, _tint)
	local green = C3(55, 150, 70)
	part(node, Vector3.new(0.22, 1.9, 0.22), CFrame.new(-0.2, 0, 0) * CFrame.Angles(0, 0, math.rad(18)), green, Enum.Material.Grass)
	part(node, Vector3.new(0.22, 1.6, 0.22), CFrame.new(0.3, -0.15, 0) * CFrame.Angles(0, 0, math.rad(-28)), green, Enum.Material.Grass)
	part(node, Vector3.new(0.6, 0.12, 0.45), CFrame.new(-0.55, 0.4, 0) * CFrame.Angles(0, 0, 0.4), green:Lerp(C3(255, 255, 255), 0.2), Enum.Material.Grass)
	part(node, Vector3.new(0.6, 0.12, 0.45), CFrame.new(0.65, -0.4, 0) * CFrame.Angles(0, 0, -0.4), green:Lerp(C3(255, 255, 255), 0.2), Enum.Material.Grass)
end

function BUILDERS.stone(node, _tint)
	part(node, Vector3.new(1.5, 1.1, 1.3), CFrame.new(0, -0.2, 0) * CFrame.Angles(0.2, 0.4, 0.1), C3(115, 115, 120), Enum.Material.Slate)
	part(node, Vector3.new(0.8, 0.7, 0.8), CFrame.new(0.55, -0.35, 0.35) * CFrame.Angles(0.4, 0.2, 0.3), C3(95, 95, 100), Enum.Material.Slate)
	part(node, Vector3.new(0.5, 0.45, 0.5), CFrame.new(-0.5, -0.45, -0.3), C3(135, 135, 140), Enum.Material.Slate)
end

function BUILDERS.coal(node, _tint)
	part(node, Vector3.new(1.3, 1.0, 1.1), CFrame.Angles(0.2, 0.5, 0.1), C3(40, 40, 45), Enum.Material.Slate)
	part(node, Vector3.new(0.7, 0.6, 0.7), CFrame.new(0.5, -0.35, 0.3) * CFrame.Angles(0.4, 0.2, 0.3), C3(25, 25, 30), Enum.Material.Slate)
	part(node, Vector3.new(0.4, 0.4, 0.4), CFrame.new(-0.5, -0.4, -0.3), C3(55, 55, 60), Enum.Material.Slate)
end

function BUILDERS.spool(node, tint)
	cyl(node, 1.0, 0.55, CFrame.new(0, 0, 0), C3(190, 160, 110), Enum.Material.Wood)
	cyl(node, 0.55, 0.8, CFrame.new(0, 0, 0), tint, Enum.Material.Fabric)
end

function BUILDERS.bowl(node, _tint)
	cyl(node, 0.35, 1.8, CFrame.new(0, -0.25, 0), C3(145, 95, 50), Enum.Material.Wood)
	cyl(node, 0.12, 1.4, CFrame.new(0, -0.1, 0), C3(110, 70, 35), Enum.Material.Wood)
end

function BUILDERS.basket(node, _tint)
	local tan = C3(170, 125, 70)
	part(node, Vector3.new(1.6, 0.2, 1.2), CFrame.new(0, -0.7, 0), tan, Enum.Material.Wood)
	part(node, Vector3.new(0.18, 1.0, 1.2), CFrame.new(-0.7, 0, 0), tan, Enum.Material.Wood)
	part(node, Vector3.new(0.18, 1.0, 1.2), CFrame.new(0.7, 0, 0), tan, Enum.Material.Wood)
	part(node, Vector3.new(1.4, 1.0, 0.18), CFrame.new(0, 0, -0.55), tan, Enum.Material.Wood)
	part(node, Vector3.new(1.4, 1.0, 0.18), CFrame.new(0, 0, 0.55), tan, Enum.Material.Wood)
	part(node, Vector3.new(0.15, 0.7, 0.15), CFrame.new(-0.5, 0.55, 0), tan, Enum.Material.Wood)
	part(node, Vector3.new(0.15, 0.7, 0.15), CFrame.new(0.5, 0.55, 0), tan, Enum.Material.Wood)
	part(node, Vector3.new(1.0, 0.15, 0.15), CFrame.new(0, 0.85, 0), tan, Enum.Material.Wood)
end

function BUILDERS.pot(node, _tint)
	local clay = C3(170, 95, 60)
	cyl(node, 1.2, 1.4, CFrame.new(0, -0.2, 0), clay, Enum.Material.Brick)
	cyl(node, 0.35, 0.9, CFrame.new(0, 0.55, 0), C3(190, 110, 70), Enum.Material.Brick)
	part(node, Vector3.new(0.35, 0.2, 0.6), CFrame.new(-0.75, 0.1, 0), clay, Enum.Material.Brick)
	part(node, Vector3.new(0.35, 0.2, 0.6), CFrame.new(0.75, 0.1, 0), clay, Enum.Material.Brick)
end

function BUILDERS.candle(node, _tint)
	cyl(node, 1.3, 0.6, CFrame.new(0, -0.15, 0), C3(240, 235, 215), Enum.Material.SmoothPlastic)
	cyl(node, 0.15, 0.8, CFrame.new(0, -0.8, 0), C3(120, 100, 80), Enum.Material.Metal)
	part(node, Vector3.new(0.3, 0.5, 0.3), CFrame.new(0, 0.75, 0) * CFrame.Angles(0, 0, 0.2), C3(255, 180, 60), Enum.Material.Neon, Enum.PartType.Ball)
end

function BUILDERS.chalk(node, _tint)
	part(node, Vector3.new(0.75, 0.16, 0.16), CFrame.new(-0.25, -0.1, 0) * CFrame.Angles(0, 0, 0.3), C3(245, 245, 235), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	part(node, Vector3.new(0.7, 0.16, 0.16), CFrame.new(0.3, 0.15, 0.1) * CFrame.Angles(0, 0, -0.25), C3(235, 235, 225), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
end

function BUILDERS.notebook(node, _tint)
	part(node, Vector3.new(1.5, 0.15, 1.9), CFrame.new(0, -0.1, 0), C3(80, 110, 160), Enum.Material.SmoothPlastic)
	part(node, Vector3.new(1.4, 0.12, 1.75), CFrame.new(0.05, 0, 0), C3(240, 230, 200), Enum.Material.SmoothPlastic)
	for index = -1, 1 do
		cyl(node, 0.18, 0.1, CFrame.new(-0.78, index * 0.45, 0), C3(180, 180, 190), Enum.Material.Metal)
	end
	part(node, Vector3.new(0.12, 1.5, 0.12), CFrame.new(0.5, 0.2, 0.2) * CFrame.Angles(0.5, 0, 0.2), C3(235, 200, 70), Enum.Material.Wood)
end

function BUILDERS.button(node, tint)
	cyl(node, 0.18, 1.0, CFrame.new(0, 0, 0), tint, Enum.Material.SmoothPlastic)
	for _, offset in {
		Vector3.new(-0.22, 0.12, -0.22),
		Vector3.new(0.22, 0.12, -0.22),
		Vector3.new(-0.22, 0.12, 0.22),
		Vector3.new(0.22, 0.12, 0.22),
	} do
		part(node, Vector3.new(0.12, 0.1, 0.12), CFrame.new(offset), C3(35, 35, 40), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
end

function BUILDERS.stick(node, _tint)
	cyl(node, 2.2, 0.18, CFrame.new(0, 0, 0), C3(115, 75, 40), Enum.Material.Wood)
end

function BUILDERS.straw(node, _tint)
	cyl(node, 2.2, 0.08, CFrame.new(0, 0, 0), C3(225, 195, 100), Enum.Material.Grass)
end

function BUILDERS.rag(node, _tint)
	local cloth = C3(120, 125, 130)
	part(node, Vector3.new(1.4, 0.1, 1.2), CFrame.new(0, -0.1, 0), cloth, Enum.Material.Fabric)
	part(node, Vector3.new(0.8, 0.1, 0.7), CFrame.new(0.3, 0, 0.2) * CFrame.Angles(0, 0.3, 0.1), cloth:Lerp(C3(255, 255, 255), 0.1), Enum.Material.Fabric)
	part(node, Vector3.new(0.7, 0.1, 0.8), CFrame.new(-0.3, -0.2, -0.2) * CFrame.Angles(0, -0.2, 0.15), cloth:Lerp(C3(0, 0, 0), 0.1), Enum.Material.Fabric)
end

function BUILDERS.leaf(node, _tint)
	part(node, Vector3.new(0.9, 0.08, 1.4), CFrame.Angles(0.2, 0, 0.4), C3(70, 150, 60), Enum.Material.Grass)
	cyl(node, 0.6, 0.08, CFrame.new(0, -0.1, 0.6) * CFrame.Angles(1.2, 0, 0), C3(110, 75, 40), Enum.Material.Wood)
end

function BUILDERS.sandbag(node, _tint)
	part(node, Vector3.new(1.4, 1.6, 1.3), CFrame.new(0, -0.2, 0), C3(215, 190, 140), Enum.Material.Fabric, Enum.PartType.Ball)
	cyl(node, 0.4, 0.45, CFrame.new(0, 0.8, 0), C3(160, 135, 95), Enum.Material.Fabric)
	part(node, Vector3.new(0.45, 0.12, 0.45), CFrame.new(0, 0.95, 0), C3(190, 165, 115), Enum.Material.Fabric)
end

function BUILDERS.cork(node, _tint)
	cyl(node, 0.9, 0.55, CFrame.new(0, 0, 0), C3(165, 115, 70), Enum.Material.Wood)
end

function BUILDERS.vial(node, tint)
	cyl(node, 1.0, 0.75, CFrame.new(0, -0.2, 0), C3(210, 235, 240), Enum.Material.Glass).Transparency = 0.2
	cyl(node, 0.45, 0.45, CFrame.new(0, 0.45, 0), C3(210, 235, 240), Enum.Material.Glass).Transparency = 0.2
	cyl(node, 0.18, 0.35, CFrame.new(0, 0.7, 0), C3(130, 90, 55), Enum.Material.Wood)
	cyl(node, 0.55, 0.62, CFrame.new(0, -0.35, 0), tint, Enum.Material.Neon).Transparency = 0.1
end

function BUILDERS.flask(node, tint)
	part(node, Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, -0.2, 0), C3(210, 235, 240), Enum.Material.Glass, Enum.PartType.Ball).Transparency = 0.2
	cyl(node, 0.5, 0.4, CFrame.new(0, 0.5, 0), C3(210, 235, 240), Enum.Material.Glass).Transparency = 0.2
	cyl(node, 0.18, 0.35, CFrame.new(0, 0.75, 0), C3(130, 90, 55), Enum.Material.Wood)
	part(node, Vector3.new(0.75, 0.55, 0.75), CFrame.new(0, -0.35, 0), tint, Enum.Material.Neon, Enum.PartType.Ball)
end

function BUILDERS.torch(node, _tint)
	cyl(node, 1.8, 0.2, CFrame.new(0, -0.3, 0), C3(110, 70, 40), Enum.Material.Wood)
	cyl(node, 0.22, 0.3, CFrame.new(0, 0.65, 0), C3(90, 85, 80), Enum.Material.Metal)
	part(node, Vector3.new(0.45, 0.7, 0.45), CFrame.new(0, 1.05, 0), C3(255, 140, 40), Enum.Material.Neon, Enum.PartType.Ball)
	part(node, Vector3.new(0.22, 0.4, 0.22), CFrame.new(0, 1.45, 0), C3(255, 220, 90), Enum.Material.Neon, Enum.PartType.Ball)
end

function BUILDERS.rope(node, _tint)
	local rope = C3(185, 150, 95)
	for index = 0, 5 do
		local angle = index * math.pi / 3
		part(node, Vector3.new(0.7, 0.2, 0.2), CFrame.new(math.cos(angle) * 0.7, 0, math.sin(angle) * 0.7) * CFrame.Angles(0, -angle, 0), rope, Enum.Material.Fabric, Enum.PartType.Cylinder)
	end
end

function BUILDERS.card(node, tint)
	part(node, Vector3.new(1.2, 1.7, 0.08), CFrame.new(0, 0, 0), C3(245, 240, 225), Enum.Material.SmoothPlastic)
	part(node, Vector3.new(1.0, 1.5, 0.1), CFrame.new(0, 0, 0.03), tint, Enum.Material.SmoothPlastic)
	part(node, Vector3.new(0.3, 0.3, 0.11), CFrame.new(0, 0, -0.02), C3(245, 240, 225), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
end

function BUILDERS.shard(node, _tint)
	local glass = C3(180, 225, 235)
	part(node, Vector3.new(0.9, 1.4, 0.12), CFrame.Angles(0.2, 0.4, 0.3), glass, Enum.Material.Glass).Transparency = 0.2
	part(node, Vector3.new(0.5, 0.9, 0.1), CFrame.new(0.5, -0.2, 0.1) * CFrame.Angles(0.3, 0.2, 0.4), glass, Enum.Material.Glass).Transparency = 0.2
	part(node, Vector3.new(0.4, 0.7, 0.1), CFrame.new(-0.4, -0.3, -0.1) * CFrame.Angles(0.1, 0.5, 0.2), glass, Enum.Material.Glass).Transparency = 0.2
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

local NAME_BUILDERS: { [string]: (Part, Color3) -> () } = {
	["Корона Лимейро"] = BUILDERS.crown,
	["Меч Истины"] = BUILDERS.sword,
	["Орлиное сердце"] = BUILDERS.heart,
	["Королевский рубин"] = BUILDERS.gem,
	["Золотой компас"] = BUILDERS.compass,
	["Слеза русалки"] = BUILDERS.tear,
	["Сова NPC"] = BUILDERS.owl,
	["Жемчужина Суфраби"] = BUILDERS.pearl,
	["Рог единорога"] = BUILDERS.horn,
	["Пиратский сундук"] = BUILDERS.chest,
	["Золотая фишка"] = BUILDERS.chip,
	["Рубиновые кости"] = BUILDERS.dice,
	["Колода шулера"] = BUILDERS.cards,
	["Кристалл Рубикуты"] = BUILDERS.crystal,
	["Лунный камень"] = BUILDERS.crystal,
	["Изумрудная лоза"] = BUILDERS.vine,
	["Бронзовый щит"] = BUILDERS.shield,
	["Ракушка-эхо"] = BUILDERS.shell,
	["Ключ от башни"] = BUILDERS.key,
	["Песочные часы"] = BUILDERS.hourglass,
	["Любовное письмо"] = BUILDERS.letter,
	["Фонарь маяка"] = BUILDERS.lantern,
	["Королевская печать"] = BUILDERS.seal,
	["Железная кирка"] = BUILDERS.pickaxe,
	["Лук охотника"] = BUILDERS.bow,
	["Рыбацкая сеть"] = BUILDERS.net,
	["Мешок специй"] = BUILDERS.sack,
	["Старая карта"] = BUILDERS.map,
	["Карта сокровищ"] = BUILDERS.map,
	["Бинокль"] = BUILDERS.binoculars,
	["Талисман Бунзена"] = BUILDERS.amulet,
	["Колокольчик"] = BUILDERS.bell,
	["Дубовая трость"] = BUILDERS.staff,
	["Свиток Масадоры"] = BUILDERS.scroll,
	["Зеркальце"] = BUILDERS.mirror,
	["Пиратский флаг"] = BUILDERS.flag,
	["Серебряная монета"] = BUILDERS.currency,
	["Медная монета"] = BUILDERS.currency,
	["10 000 йен"] = BUILDERS.currency,
	["Букет роз"] = BUILDERS.bouquet,
	["Мёд диких пчёл"] = BUILDERS.honey,
	["Ящик инструментов"] = BUILDERS.toolbox,
	["Грибы Бунзена"] = BUILDERS.mushrooms,
	["Сушёная рыба"] = BUILDERS.fish,
	["Рыба Галгайда"] = BUILDERS.fish,
	["Перо совы"] = BUILDERS.feather,
	["Перо чайки"] = BUILDERS.feather,
	["Ракушечный браслет"] = BUILDERS.bracelet,
	["Цветочный венок"] = BUILDERS.wreath,
	["Подкова"] = BUILDERS.horseshoe,
	["Яблоко Шисо"] = BUILDERS.apple,
	["Камень-пробник"] = BUILDERS.stone,
	["Булыжник"] = BUILDERS.stone,
	["Камешек"] = BUILDERS.stone,
	["Моток ниток"] = BUILDERS.spool,
	["Деревянная миска"] = BUILDERS.bowl,
	["Плетёная корзина"] = BUILDERS.basket,
	["Лечебная трава"] = BUILDERS.herb,
	["Глиняный горшок"] = BUILDERS.pot,
	["Кусок мела"] = BUILDERS.chalk,
	["Пуговица"] = BUILDERS.button,
	["Палка"] = BUILDERS.stick,
	["Ракушка"] = BUILDERS.shell,
	["Стекляшка"] = BUILDERS.shard,
	["Тряпка"] = BUILDERS.rag,
	["Сухой лист"] = BUILDERS.leaf,
	["Песок в мешочке"] = BUILDERS.sandbag,
	["Пик"] = BUILDERS.card,
	["Трейс"] = BUILDERS.card,
	["Соломинка"] = BUILDERS.straw,
	["Угольок"] = BUILDERS.coal,
	["Пробка"] = BUILDERS.cork,
	["Пустая склянка"] = BUILDERS.vial,
	["Фляга"] = BUILDERS.flask,
	["Факел"] = BUILDERS.torch,
	["Крепкая верёвка"] = BUILDERS.rope,
	["Книга заклинаний"] = BUILDERS.book,
}

-- по названию оружие получает свою форму
local SWORD_WORDS = { "Меч", "Клинок", "Нож", "Кинжал", "Сабля", "Шпага", "Топор" }

function ItemModels.attach(node: Part, card: { kind: string, rank: string, name: string })
	local tint = Ranks.color(card.rank)
	local builder = NAME_BUILDERS[card.name]
	if not builder then
		builder = BUILDERS[card.kind] or BUILDERS.item
		for _, word in SWORD_WORDS do
			if string.find(card.name, word, 1, true) then
				builder = BUILDERS.sword
				break
			end
		end
	end
	if not pcall(builder, node, tint) then
		pcall(BUILDERS.item, node, tint)
	end
end

--- Показать или спрятать модельку.
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
