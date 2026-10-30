--!strict
-- Construit la carte concentrique dans Workspace (CDC §3, Sprint 0) à partir de MapGeometry/MapConfig :
-- aucune pièce n'est posée à la main. Dépendances : MapGeometry, MapConfig, Bricks.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapConfig = require(ReplicatedStorage.Shared.config.MapConfig)
local MapGeometry = require(ReplicatedStorage.Shared.domain.MapGeometry)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)

local MapService = {}

MapService.MAP_NAME = "Map"
MapService.BASES_FOLDER = "Bases"
MapService.SPAWN_NAME = "Spawn"
MapService.WATER_NAME = "Water"

type SlabSpec = {
	name: string,
	x: number,
	z: number,
	angle: number, -- yaw radial (voir MapGeometry)
	top: number,
	sizeX: number,
	sizeZ: number,
	color: string,
}

local function newFolder(name: string, parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

-- Brique de sol ancrée et franchissable, dont la face supérieure est à `spec.top`.
local function slab(spec: SlabSpec, parent: Instance): Part
	local thickness = MapConfig.GROUND_THICKNESS
	local part = Instance.new("Part")
	part.Name = spec.name
	part.Anchored = true
	part.Size = Vector3.new(spec.sizeX, thickness, spec.sizeZ)
	part.CFrame = CFrame.new(spec.x, spec.top - thickness / 2, spec.z) * CFrame.Angles(0, -spec.angle, 0)
	Bricks.style(part, MapConfig.COLORS[spec.color])
	part.Parent = parent
	return part
end

local function buildFloor(map: Folder)
	local floor = newFolder("Floor", map)
	for k, run in MapGeometry.floorRuns() do
		slab({
			name = `{run.zone}{k}`,
			x = run.x,
			z = run.z,
			angle = 0,
			top = MapConfig.FLOOR_TOP,
			sizeX = run.sizeX,
			sizeZ = run.sizeZ,
			color = run.zone,
		}, floor)
	end
end

-- Plan d'eau sous toute la carte (fossé compris) : trop profond pour en ressortir, il renvoie le joueur
-- sur sa base (HazardService) au lieu de le laisser tomber dans le vide.
-- Découpé en dalles : une pièce Roblox ne dépasse pas 2 048 studs par côté.
local function buildWater(map: Folder)
	local folder = newFolder(MapService.WATER_NAME, map)
	local lattice, margin, tile = MapConfig.MAP_LATTICE, MapConfig.WATER_MARGIN, MapConfig.WATER_TILE_SIZE
	local minX, minZ = lattice.minX - margin, lattice.minZ - margin
	local totalX = lattice.cols * MapConfig.CELL_SIZE + 2 * margin
	local totalZ = lattice.rows * MapConfig.CELL_SIZE + 2 * margin
	for offsetX = 0, totalX - 1, tile do
		for offsetZ = 0, totalZ - 1, tile do
			local sizeX, sizeZ = math.min(tile, totalX - offsetX), math.min(tile, totalZ - offsetZ)
			slab({
				name = "WaterTile",
				x = minX + offsetX + sizeX / 2,
				z = minZ + offsetZ + sizeZ / 2,
				angle = 0,
				top = MapConfig.WATER_TOP,
				sizeX = sizeX,
				sizeZ = sizeZ,
				color = "Water",
			}, folder)
		end
	end
end

-- Le modèle « Baseplate » de Studio pose un sol gris au niveau 0 qui recouvre la carte générée.
local function removeTemplateLeftovers()
	for _, name in MapConfig.TEMPLATE_LEFTOVERS do
		local leftover = Workspace:FindFirstChild(name)
		if leftover and leftover:IsA("BasePart") then
			leftover:Destroy()
		end
	end
end

local function buildBridges(map: Folder)
	local folder = newFolder("Bridges", map)
	for _, bridge in MapGeometry.bridges() do
		slab({
			name = `Bridge{bridge.index}`,
			x = bridge.x,
			z = bridge.z,
			angle = bridge.angle,
			top = MapConfig.DECK_TOP,
			sizeX = bridge.length,
			sizeZ = bridge.width,
			color = "Bridge",
		}, folder)
	end
end

local function addSpawn(floor: Part)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = MapService.SPAWN_NAME
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(6, MapConfig.SPAWN_HEIGHT, 6)
	-- Posé sur la base : décalage = demi-épaisseur de la base + demi-hauteur du spawn.
	spawn.CFrame = floor.CFrame + Vector3.new(0, (MapConfig.GROUND_THICKNESS + MapConfig.SPAWN_HEIGHT) / 2, 0)
	Bricks.style(spawn, MapConfig.COLORS.Core)
	spawn.Parent = floor
end

local function buildBases(map: Folder)
	local folder = newFolder(MapService.BASES_FOLDER, map)
	for _, base in MapGeometry.baseCenters() do
		local floor = slab({
			name = `Base{base.index}`,
			x = base.x,
			z = base.z,
			angle = base.angle,
			top = MapConfig.DECK_TOP,
			sizeX = MapConfig.BASE_SIZE,
			sizeZ = MapConfig.BASE_SIZE,
			color = "Base",
		}, folder)
		floor:SetAttribute("BaseIndex", base.index)
		addSpawn(floor)
	end
end

function MapService:Init()
	local existing = Workspace:FindFirstChild(MapService.MAP_NAME)
	if existing then
		existing:Destroy()
	end
	removeTemplateLeftovers()
	local map = Instance.new("Folder")
	map.Name = MapService.MAP_NAME

	buildFloor(map)
	buildWater(map)
	buildBridges(map)
	buildBases(map)

	map.Parent = Workspace
end

-- Brique de sol d'une base (pour PlotService). Disponible après Init.
function MapService.basePart(index: number): BasePart?
	local map = Workspace:FindFirstChild(MapService.MAP_NAME)
	local bases = map and map:FindFirstChild(MapService.BASES_FOLDER)
	return bases and bases:FindFirstChild(`Base{index}`) :: BasePart?
end

-- Dalles du plan d'eau (pour HazardService). Disponibles après Init.
function MapService.waterTiles(): { BasePart }
	local map = Workspace:FindFirstChild(MapService.MAP_NAME)
	local folder = map and map:FindFirstChild(MapService.WATER_NAME)
	local tiles: { BasePart } = {}
	for _, child in if folder then folder:GetChildren() else {} do
		if child:IsA("BasePart") then
			table.insert(tiles, child)
		end
	end
	return tiles
end

return MapService
