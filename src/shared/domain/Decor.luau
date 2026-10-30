--!strict
-- Placement du décor (CDC §2), sans API Roblox : murs de la tige, clôtures des bases, arbres, portiques
-- et variation déterministe des brins. Les builders serveur et client se contentent de poser les pièces.
local DecorConfig = require("../config/DecorConfig")
local MapConfig = require("../config/MapConfig")
local TycoonConfig = require("../config/TycoonConfig")
local MapGeometry = require("./MapGeometry")

export type Segment = { x1: number, z1: number, x2: number, z2: number }
export type Spot = { x: number, z: number }
export type Gate = { id: string, x: number, halfWidth: number }
export type StalkVariation = { heightScale: number, yaw: number, shade: number }

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
			table.insert(spots, { x = x, z = z })
		end
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
	}
end

-- Vrai si la clôture laisse passer le joueur jusqu'à la grille de déchargement.
function Decor.gateClearsUnloadPad(): boolean
	local pad = TycoonConfig.LAYOUT.UNLOAD_PAD
	return DecorConfig.FENCE.GATE_WIDTH >= pad.size
		and math.abs(pad.z) + pad.size / 2 <= DecorConfig.FENCE.GATE_WIDTH / 2
end

return Decor
