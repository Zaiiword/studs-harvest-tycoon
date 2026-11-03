--!strict
-- Placement du décor (CDC §2), sans API Roblox : murs de la tige, clôtures des bases, arbres, portiques
-- et variation déterministe des brins. Les builders serveur et client se contentent de poser les pièces.
local DecorConfig = require("../config/DecorConfig")
local FieldConfig = require("../config/FieldConfig")
local MapConfig = require("../config/MapConfig")
local RetentionConfig = require("../config/RetentionConfig")
local TycoonConfig = require("../config/TycoonConfig")
local MapGeometry = require("./MapGeometry")

export type Segment = { x1: number, z1: number, x2: number, z2: number }
export type Spot = { x: number, z: number }
export type Gate = { id: string, x: number, halfWidth: number }
export type Curb = { x: number, z: number, colorIndex: number }
export type StalkVariation = { heightScale: number, yaw: number, shade: number, lean: number }

local Decor = {}

local STEM = MapConfig.STEM
local WALL = DecorConfig.STEM_WALL
-- Le sol est en escalier : une cellule déborde au plus d'une demi-cellule de la ligne théorique.
local WALL_CLEARANCE = MapConfig.CELL_SIZE / 2 + WALL.THICKNESS / 2

-- Murs des deux côtés de la tige, qui suivent son rétrécissement, plus un mur au bout du champ.
function Decor.stemWalls(): { Segment }
	local segments: { Segment } = {}
	for _, side in { -1, 1 } do
		local x = STEM.minX
		while x < STEM.maxX do
			local nextX = math.min(x + WALL.SEGMENT_LENGTH, STEM.maxX)
			table.insert(segments, {
				x1 = x,
				z1 = side * (MapGeometry.stemHalfWidth(x) + WALL_CLEARANCE),
				x2 = nextX,
				z2 = side * (MapGeometry.stemHalfWidth(nextX) + WALL_CLEARANCE),
			})
			x = nextX
		end
	end
	local endZ = STEM.endHalfWidth + WALL_CLEARANCE
	local endX = STEM.maxX + WALL.THICKNESS / 2
	table.insert(segments, { x1 = endX, z1 = -endZ, x2 = endX, z2 = endZ })
	return segments
end

-- Clôture carrée autour d'une base, en coordonnées locales, ouverte côté champ (+X) sur GATE_WIDTH.
function Decor.baseFence(): { Segment }
	local fence = DecorConfig.FENCE
	local half = MapConfig.BASE_SIZE / 2 - fence.INSET
	local gate = fence.GATE_WIDTH / 2
	return {
		{ x1 = -half, z1 = -half, x2 = -half, z2 = half }, -- arrière
		{ x1 = -half, z1 = -half, x2 = half, z2 = -half }, -- côté gauche
		{ x1 = -half, z1 = half, x2 = half, z2 = half }, -- côté droit
		{ x1 = half, z1 = -half, x2 = half, z2 = -gate }, -- avant, de part et d'autre de l'ouverture
		{ x1 = half, z1 = gate, x2 = half, z2 = half },
	}
end

-- Les statues de classement (Sprint 7) occupent le devant des bases centrales : pas d'arbre dessus.
local function isNearStatue(x: number, z: number): boolean
	for _, statue in RetentionConfig.STATUES do
		if math.sqrt((statue.x - x) ^ 2 + (statue.z - z) ^ 2) < RetentionConfig.STATUE_CLEARANCE then
			return true
		end
	end
	return false
end

-- Arbres sur la barre du T : entre deux bases voisines et aux deux extrémités, devant et derrière.
function Decor.treeSpots(): { Spot }
	local bases = MapGeometry.baseCenters()
	local zs: { number } = { bases[1].z - MapConfig.BASE_PITCH / 2 }
	for i = 1, #bases - 1 do
		table.insert(zs, (bases[i].z + bases[i + 1].z) / 2)
	end
	table.insert(zs, bases[#bases].z + MapConfig.BASE_PITCH / 2)
	local spots: { Spot } = {}
	for _, x in DecorConfig.TREE.ROWS_X do
		for _, z in zs do
			if not isNearStatue(x, z) then
				table.insert(spots, { x = x, z = z })
			end
		end
	end
	return spots
end

-- Tronçons de bordure du boulevard (A54), en alternance de couleur, interrompus devant les ouvertures : les
-- portes des bases côté bases, les ponts côté fossé.
function Decor.roadCurbs(): { Curb }
	local road, curb = MapConfig.ROAD, DecorConfig.ROAD.CURB
	local curbs: { Curb } = {}
	local function addSide(x: number, openings: { number }, halfOpening: number)
		local index = 0
		local z = -road.halfLength
		while z + curb.length <= road.halfLength do
			local fromZ, toZ = z, z + curb.length
			local isBlocked = false
			for _, center in openings do
				isBlocked = isBlocked or (toZ > center - halfOpening and fromZ < center + halfOpening)
			end
			index += 1
			if not isBlocked then
				table.insert(curbs, { x = x, z = (fromZ + toZ) / 2, colorIndex = index % #curb.colors + 1 })
			end
			z = toZ
		end
	end
	local doors: { number } = {}
	for _, base in MapGeometry.baseCenters() do
		table.insert(doors, base.z)
	end
	addSide(road.minX + curb.width / 2, doors, DecorConfig.FENCE.GATE_WIDTH / 2)
	addSide(road.maxX - curb.width / 2, MapConfig.BRIDGE_Z, MapConfig.BRIDGE_WIDTH / 2)
	return curbs
end

-- Pointillés de la ligne centrale, tout le long du boulevard.
function Decor.roadDashes(): { number }
	local dash = DecorConfig.ROAD.DASH
	local dashes: { number } = {}
	local z = -MapConfig.ROAD.halfLength + dash.spacing / 2
	while z <= MapConfig.ROAD.halfLength - dash.length / 2 do
		table.insert(dashes, z)
		z += dash.spacing
	end
	return dashes
end

-- Drapeaux côté fossé, à distance des ponts, des statues et des arbres.
function Decor.roadFlags(): { Spot }
	local flag = DecorConfig.ROAD.FLAG
	local obstacles: { Spot } = {}
	for _, statue in RetentionConfig.STATUES do
		table.insert(obstacles, { x = statue.x, z = statue.z })
	end
	for _, bridgeZ in MapConfig.BRIDGE_Z do
		table.insert(obstacles, { x = flag.x, z = bridgeZ })
	end
	for _, tree in Decor.treeSpots() do
		table.insert(obstacles, tree)
	end
	local spots: { Spot } = {}
	local z = -MapConfig.ROAD.halfLength + flag.spacing / 2
	while z <= MapConfig.ROAD.halfLength do
		local isFree = true
		for _, obstacle in obstacles do
			isFree = isFree and math.sqrt((obstacle.x - flag.x) ^ 2 + (obstacle.z - z) ^ 2) >= flag.clearance
		end
		if isFree then
			table.insert(spots, { x = flag.x, z = z })
		end
		z += flag.spacing
	end
	return spots
end

-- Un portique au début de chaque bande de la tige.
function Decor.bandGates(): { Gate }
	local gates: { Gate } = {}
	for _, band in MapConfig.STEM_BANDS do
		local x = STEM.minX + band.startDistance
		table.insert(gates, { id = band.id, x = x, halfWidth = MapGeometry.stemHalfWidth(x) + WALL_CLEARANCE })
	end
	return gates
end

-- Hachage entier déterministe (Knuth) ramené dans [0, 1).
local function hash01(value: number, salt: number): number
	return ((value * 2654435761 + salt * 40503) % 4294967296) / 4294967296
end

-- Chaque brin a sa hauteur, son orientation et sa teinte, toujours les mêmes pour une cellule donnée (A35).
function Decor.stalkVariation(index: number): StalkVariation
	local variation = DecorConfig.STALK_VARIATION
	return {
		heightScale = 1 + (hash01(index, 1) * 2 - 1) * variation.HEIGHT,
		yaw = hash01(index, 2) * math.pi / 2, -- un quart de tour suffit pour une brique carrée
		shade = 1 + (hash01(index, 3) * 2 - 1) * variation.SHADE,
		lean = (hash01(index, 4) * 2 - 1) * FieldConfig.PLANT.MAX_LEAN,
	}
end

-- Vrai si la clôture laisse passer le joueur jusqu'à la grille de déchargement.
function Decor.gateClearsUnloadPad(): boolean
	local pad = TycoonConfig.LAYOUT.UNLOAD_PAD
	return DecorConfig.FENCE.GATE_WIDTH >= pad.size
		and math.abs(pad.z) + pad.size / 2 <= DecorConfig.FENCE.GATE_WIDTH / 2
end

return Decor
