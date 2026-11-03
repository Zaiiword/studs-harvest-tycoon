--!strict
-- Habillage permanent de la base (A53) : tapis roulant (rails, rouleaux) et grille de déchargement (cadre, barreaux).
-- `toWorld` convertit un point local en repère monde. La ferme elle-même se construit achat par achat (A56).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TycoonConfig = require(ReplicatedStorage.Shared.config.TycoonConfig)
local Build = require(script.Parent.Build)

local TycoonGrounds = {}

export type ToWorld = (x: number, z: number) -> CFrame -- point local → repère monde au niveau du pont
type Rect = { minX: number, maxX: number, minZ: number, maxZ: number }

local LAYOUT = TycoonConfig.LAYOUT
local BORDER = LAYOUT.BORDER
local DARK = BORDER.color
local CHROME = { 210, 210, 215 }
local ROLLER = { 70, 75, 85 }
local RAIL_HEIGHT = 1.6
local RAIL_WIDTH = 0.5
local ROLLER_SPACING = 3
local GRATE_BARS = 6
local GRATE_BAR_WIDTH = 0.6

-- Bordure sombre posée sur le pourtour intérieur d'un rectangle.
local function border(parent: Instance, toWorld: ToWorld, zone: Rect)
	local w, h = BORDER.width, BORDER.height
	local sizeX, sizeZ = zone.maxX - zone.minX, zone.maxZ - zone.minZ
	local centerX, centerZ = (zone.minX + zone.maxX) / 2, (zone.minZ + zone.maxZ) / 2
	local edges = {
		{ x = centerX, z = zone.minZ + w / 2, size = Vector3.new(sizeX, h, w) },
		{ x = centerX, z = zone.maxZ - w / 2, size = Vector3.new(sizeX, h, w) },
		{ x = zone.minX + w / 2, z = centerZ, size = Vector3.new(w, h, sizeZ - 2 * w) },
		{ x = zone.maxX - w / 2, z = centerZ, size = Vector3.new(w, h, sizeZ - 2 * w) },
	}
	for _, edge in edges do
		Build.block(parent, {
			name = "Border",
			cframe = toWorld(edge.x, edge.z) * CFrame.new(0, h / 2, 0),
			size = edge.size,
			color = DARK,
		})
	end
end

-- Rails chromés de chaque côté du tapis et rouleaux sombres en travers.
function TycoonGrounds.dressConveyor(parent: Instance, toWorld: ToWorld)
	local conveyor = LAYOUT.CONVEYOR
	local length = conveyor.toZ - conveyor.fromZ
	local centerZ = (conveyor.fromZ + conveyor.toZ) / 2
	for _, side in { -1, 1 } do
		Build.block(parent, {
			name = "Rail",
			cframe = toWorld(conveyor.x + side * (conveyor.width / 2 + RAIL_WIDTH / 2), centerZ)
				* CFrame.new(0, RAIL_HEIGHT / 2, 0),
			size = Vector3.new(RAIL_WIDTH, RAIL_HEIGHT, length),
			color = CHROME,
		}).Material =
			Enum.Material.Metal
	end
	for z = conveyor.fromZ + ROLLER_SPACING / 2, conveyor.toZ, ROLLER_SPACING do
		Build.block(parent, {
			name = "Roller",
			cframe = toWorld(conveyor.x, z) * CFrame.new(0, conveyor.height + 0.04, 0),
			size = Vector3.new(conveyor.width - 0.4, 0.08, 0.4),
			color = ROLLER,
		}).CanCollide =
			false
	end
end

-- Cadre sombre et barreaux de grille sur la zone de déchargement.
function TycoonGrounds.dressUnloadPad(parent: Instance, toWorld: ToWorld)
	local pad = LAYOUT.UNLOAD_PAD
	local half = pad.size / 2
	local top = LAYOUT.PAD_THICKNESS
	border(parent, toWorld, {
		minX = pad.x - half - BORDER.width,
		maxX = pad.x + half + BORDER.width,
		minZ = pad.z - half - BORDER.width,
		maxZ = pad.z + half + BORDER.width,
	})
	local step = pad.size / (GRATE_BARS + 1)
	for index = 1, GRATE_BARS do
		Build.block(parent, {
			name = "Grate",
			cframe = toWorld(pad.x - half + index * step, pad.z) * CFrame.new(0, top + 0.04, 0),
			size = Vector3.new(GRATE_BAR_WIDTH, 0.08, pad.size - 2),
			color = DARK,
		}).CanCollide =
			false
	end
end

return TycoonGrounds
