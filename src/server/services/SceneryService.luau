--!strict
-- Paysage autour de la carte (A69) : berges, plateau du volcan, plage, collines, forêts, îles, phare, voiliers,
-- montgolfières, nuages, vie de la rivière, jardins et lampadaires. Placement calculé par Scenery (pur, testé),
-- pièces posées par SceneryModels. Construit dans Start : la carte de MapService existe déjà.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapConfig = require(ReplicatedStorage.Shared.config.MapConfig)
local SceneryConfig = require(ReplicatedStorage.Shared.config.SceneryConfig)
local Scenery = require(ReplicatedStorage.Shared.domain.Scenery)
local Build = require(script.Parent.Parent.builders.Build)
local SceneryModels = require(script.Parent.Parent.builders.SceneryModels)
local MapService = require(script.Parent.MapService)

local SceneryService = {}

local PLAZA, STEM = MapConfig.PLAZA, MapConfig.STEM
local SEABED = MapConfig.WATER_TOP - 2 -- les socles descendent sous la surface de l'eau

local function folder(name: string, parent: Instance): Folder
	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = parent
	return created
end

-- Bloc de terrain dont la face supérieure est à `top` et qui descend jusqu'au fond de l'eau.
local function ground(
	parent: Instance,
	name: string,
	cframe: CFrame,
	sizeX: number,
	sizeZ: number,
	top: number,
	color: { number }
): Part
	local height = top - SEABED
	return Build.block(parent, {
		name = name,
		cframe = cframe * CFrame.new(0, top - height / 2, 0),
		size = Vector3.new(sizeX, height, sizeZ),
		color = color,
	})
end

-- Deux plateaux parallèles aux murs du champ : de la terre, coiffée d'une couche d'herbe.
local function buildBanks(parent: Instance)
	local bank = SceneryConfig.BANK
	for _, side in { -1, 1 } do
		local frame = Scenery.bankFrame(side)
		local x, z = Scenery.bankPoint(frame, frame.length / 2, bank.WIDTH / 2)
		local center = Vector3.new(x, 0, z)
		local along = CFrame.lookAt(center, center + Vector3.new(frame.dirX, 0, frame.dirZ))
		local earthTop = bank.TOP - bank.GRASS_THICKNESS
		ground(parent, "BankEarth", along, bank.WIDTH, frame.length, earthTop, bank.EARTH_COLOR)
		Build.block(parent, {
			name = "BankGrass",
			cframe = along * CFrame.new(0, bank.TOP - bank.GRASS_THICKNESS / 2, 0),
			size = Vector3.new(bank.WIDTH, bank.GRASS_THICKNESS, frame.length),
			color = bank.GRASS_COLOR,
		})
	end
end

local function plateauX(): number
	return STEM.maxX + MapConfig.CELL_SIZE + SceneryConfig.BANK.GAP
end

local function buildPlateau(parent: Instance)
	local plateau = SceneryConfig.END_PLATEAU
	local center = CFrame.new(plateauX() + plateau.DEPTH / 2, 0, 0)
	ground(parent, "Plateau", center, plateau.DEPTH, plateau.HALF_WIDTH * 2, plateau.TOP, plateau.COLOR)
	SceneryModels.volcano(parent, plateauX() + SceneryConfig.VOLCANO.DISTANCE, plateau.TOP)
end

-- Marches de sable derrière les bases, sur toute la longueur de la barre.
local function buildBeach(parent: Instance)
	local beach = SceneryConfig.BEACH
	local edge = PLAZA.minX
	for _, step in beach.STEPS do
		local center = CFrame.new(edge - step.depth / 2, 0, 0)
		ground(parent, "Beach", center, step.depth, PLAZA.halfWidth * 2, step.top, beach.COLOR)
		edge -= step.depth
	end
	local props = folder("BeachProps", parent)
	for _, prop in Scenery.beachProps() do
		SceneryModels.gardenProp(props, prop, beach.STEPS[1].top)
	end
end

local function buildHills(parent: Instance)
	local hills = folder("Hills", parent)
	for _, hill in Scenery.hills() do
		SceneryModels.hill(hills, hill)
	end
	local trees = folder("Trees", parent)
	for _, tree in Scenery.bankTrees() do
		local base = CFrame.new(tree.x, SceneryConfig.BANK.TOP, tree.z) * CFrame.Angles(0, math.rad(tree.yaw), 0)
		SceneryModels.tree(trees, tree.kind, base, tree.scale, tree.shade)
	end
end

local function buildSea(parent: Instance)
	local sea = folder("Sea", parent)
	for _, spot in SceneryConfig.ISLAND.SPOTS do
		SceneryModels.island(sea, spot)
	end
	SceneryModels.lighthouse(sea)
	for index, spot in SceneryConfig.BOAT.SPOTS do
		SceneryModels.boat(sea, spot, index)
	end
end

local function buildSky(parent: Instance)
	local sky = folder("Sky", parent)
	for index, spot in SceneryConfig.BALLOON.SPOTS do
		SceneryModels.balloon(sky, spot, index)
	end
	for _, cloud in Scenery.clouds() do
		SceneryModels.cloud(sky, cloud)
	end
end

local function buildRiver(parent: Instance)
	local river = folder("River", parent)
	for _, spot in Scenery.lilies() do
		SceneryModels.lily(river, spot)
	end
	for _, spot in Scenery.ducks() do
		SceneryModels.duck(river, spot)
	end
end

local function buildGardens(parent: Instance)
	local gardens = folder("Gardens", parent)
	for _, prop in Scenery.gardens() do
		SceneryModels.gardenProp(gardens, prop, MapConfig.FLOOR_TOP)
	end
	for _, spot in Scenery.lampPosts() do
		SceneryModels.lamp(gardens, spot.x, spot.z, MapConfig.FLOOR_TOP)
	end
end

function SceneryService:Start()
	local map = Workspace:FindFirstChild(MapService.MAP_NAME)
	if not map then
		return
	end
	local scenery = folder(SceneryConfig.FOLDER_NAME, map)
	buildBanks(scenery)
	buildPlateau(scenery)
	buildBeach(scenery)
	buildHills(scenery)
	buildSea(scenery)
	buildSky(scenery)
	buildRiver(scenery)
	buildGardens(scenery)
end

return SceneryService
