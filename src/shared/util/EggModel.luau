--!strict
-- Œuf en 3D (A69) : une coquille ovale, des taches en relief, une ceinture pour les œufs précieux et un reflet.
-- Le même modèle sert au couvoir (serveur) et à l'animation d'éclosion à l'écran (client).
local PetVisualConfig = require("../config/PetVisualConfig")
local Bricks = require("./Bricks")

local EggModel = {}

EggModel.SHELL_NAME = "Shell"

local LOOKS = PetVisualConfig.EGG_LOOKS
local GOLDEN_ANGLE = math.pi * (3 - math.sqrt(5))

local function ovoid(name: string, size: Vector3, color: { number }): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
	part.Size = size
	part.Color = Bricks.rgb(color)
	part.Material = Enum.Material.SmoothPlastic
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere -- la sphère épouse la taille de la pièce
	mesh.Parent = part
	return part
end

-- Point de la coquille dans la direction (x, y, z), et normale à cet endroit.
local function onShell(radii: Vector3, direction: Vector3): (Vector3, Vector3)
	local position = direction * radii
	local normal = (direction / radii).Unit
	return position, normal
end

-- Œuf centré sur `center`, de taille `size`. `eggId` choisit les couleurs des taches et de la ceinture.
function EggModel.build(eggId: string, shellColor: { number }, size: Vector3, center: CFrame): Model
	local look = LOOKS[eggId] or LOOKS.Default
	local model = Instance.new("Model")
	model.Name = "EggBody"
	local shell = ovoid(EggModel.SHELL_NAME, size, shellColor)
	shell.Reflectance = PetVisualConfig.EGG_REFLECTANCE
	shell.CFrame = center
	shell.Parent = model
	model.PrimaryPart = shell
	local radii = size / 2
	local unit = math.min(size.X, size.Z)
	-- Taches réparties en spirale : régulières sans paraître alignées.
	for k = 1, look.spots do
		local height = 1 - 2 * (k - 0.5) / look.spots
		local ring = math.sqrt(1 - height * height)
		local angle = k * GOLDEN_ANGLE
		local position, normal =
			onShell(radii, Vector3.new(math.cos(angle) * ring, height * 0.8, math.sin(angle) * ring).Unit)
		local spotSize = unit * (0.2 + 0.09 * (k % 3))
		local spot = ovoid("Spot", Vector3.new(spotSize, spotSize, unit * 0.06), look.spotColor)
		spot.CFrame = center * CFrame.lookAt(position * 0.985, position + normal)
		spot.Parent = model
	end
	if look.beltColor then
		local belt = ovoid("Belt", Vector3.new(size.X * 1.04, size.Y * 0.13, size.Z * 1.04), look.beltColor)
		belt.CFrame = center * CFrame.new(0, -size.Y * 0.06, 0)
		belt.Parent = model
	end
	for _, side in { -1, 1 } do
		local position, normal = onShell(radii, Vector3.new(side * 0.45, 0.62, side * -0.64).Unit)
		local shine = ovoid("Shine", Vector3.new(unit * 0.2, unit * 0.32, unit * 0.05), { 255, 255, 255 })
		shine.Transparency = 0.25
		shine.CFrame = center * CFrame.lookAt(position, position + normal) * CFrame.Angles(0, 0, math.rad(25))
		shine.Parent = model
	end
	return model
end

function EggModel.glowColor(eggId: string): { number }
	return (LOOKS[eggId] or LOOKS.Default).glowColor
end

return EggModel
