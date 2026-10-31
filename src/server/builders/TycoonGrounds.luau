--!strict
-- Aménagement de la base (A53) : dalles colorées par zone avec bordure, allées pavées, panneaux de zone,
-- habillage du tapis roulant (rails, rouleaux) et de la grille de déchargement (cadre, barreaux).
-- Tout est posé à plat sur le pont de la base ; `toWorld` convertit un point local en repère monde.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TycoonConfig = require(ReplicatedStorage.Shared.config.TycoonConfig)
local Build = require(script.Parent.Build)

local TycoonGrounds = {}

export type ToWorld = (x: number, z: number) -> CFrame -- point local → repère monde au niveau du pont

local LAYOUT = TycoonConfig.LAYOUT
local BORDER = LAYOUT.BORDER
local SIGN = LAYOUT.SIGN
local DARK = BORDER.color
local CHROME = { 210, 210, 215 }
local ROLLER = { 70, 75, 85 }
local WHITE = { 248, 248, 248 }
local RAIL_HEIGHT = 1.6
local RAIL_WIDTH = 0.5
local ROLLER_SPACING = 3
local GRATE_BARS = 6
local GRATE_BAR_WIDTH = 0.6

local function slab(parent: Instance, toWorld: ToWorld, zone: TycoonConfig.Zone, thickness: number): Part
	local sizeX, sizeZ = zone.maxX - zone.minX, zone.maxZ - zone.minZ
	local origin = toWorld((zone.minX + zone.maxX) / 2, (zone.minZ + zone.maxZ) / 2)
	return Build.block(parent, {
		name = zone.name,
		cframe = origin * CFrame.new(0, thickness / 2, 0),
		size = Vector3.new(sizeX, thickness, sizeZ),
		color = zone.color,
	})
end

-- Bordure sombre posée sur le pourtour intérieur d'une zone.
local function border(parent: Instance, toWorld: ToWorld, zone: TycoonConfig.Zone)
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

local function zoneSign(parent: Instance, toWorld: ToWorld, spec: { text: string, x: number, z: number })
	local origin = toWorld(spec.x, spec.z)
	for _, side in { -1, 1 } do
		Build.block(parent, {
			name = "SignPost",
			cframe = origin * CFrame.new(side * (SIGN.width / 2 - 0.5), SIGN.postHeight / 2, 0),
			size = Vector3.new(0.5, SIGN.postHeight, 0.5),
			color = DARK,
		})
	end
	local board = Build.block(parent, {
		name = "SignBoard",
		cframe = origin * CFrame.new(0, SIGN.postHeight + SIGN.height / 2, 0),
		size = Vector3.new(SIGN.width, SIGN.height, 0.4),
		color = DARK,
	})
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		Build.sign(board, face, spec.text, WHITE)
	end
end

-- Dalles, bordures, allées et panneaux de toute la base.
function TycoonGrounds.build(parent: Instance, toWorld: ToWorld)
	for _, zone in LAYOUT.ZONES do
		slab(parent, toWorld, zone, LAYOUT.ZONE_THICKNESS)
		border(parent, toWorld, zone)
	end
	for _, avenue in LAYOUT.AVENUES do
		slab(parent, toWorld, avenue, LAYOUT.AVENUE_THICKNESS)
	end
	for _, spec in LAYOUT.SIGNS do
		zoneSign(parent, toWorld, spec)
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
		name = "UnloadFrame",
		minX = pad.x - half - BORDER.width,
		maxX = pad.x + half + BORDER.width,
		minZ = pad.z - half - BORDER.width,
		maxZ = pad.z + half + BORDER.width,
		color = DARK,
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
