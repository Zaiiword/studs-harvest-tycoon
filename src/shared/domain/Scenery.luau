--!strict
-- Placement du paysage (A69), sans API Roblox : berges, collines, montagnes, arbres, nuages, vie de la rivière,
-- jardins. Tout est tiré d'un générateur déterministe (même paysage sur tous les serveurs) et reste hors des zones
-- où l'on joue. Les builders serveur se contentent de poser les pièces.
local DecorConfig = require("../config/DecorConfig")
local MapConfig = require("../config/MapConfig")
local SceneryConfig = require("../config/SceneryConfig")
local Decor = require("./Decor")
local MapGeometry = require("./MapGeometry")

export type Rng = () -> number
export type BankFrame = {
	side: number,
	startX: number,
	startZ: number,
	dirX: number,
	dirZ: number,
	normalX: number,
	normalZ: number,
	length: number,
}
export type Hill = {
	kind: string, -- « hill », « mountain »
	x: number,
	z: number,
	radius: number,
	tiers: number,
	yaw: number, -- degrés
	feature: string?, -- « windmill », « trees »
	side: number,
}
export type Tree = { kind: string, x: number, z: number, scale: number, yaw: number, shade: number }
export type Cloud = { x: number, y: number, z: number, scale: number }
export type Floater = { x: number, z: number, yaw: number, variant: number }
export type Prop = { kind: string, x: number, z: number, yaw: number, variant: number, scale: number }

local Scenery = {}

local PLAZA, MOAT, STEM = MapConfig.PLAZA, MapConfig.MOAT, MapConfig.STEM
local WALL = DecorConfig.STEM_WALL
-- Face extérieure des murs du champ, mesurée depuis la demi-largeur théorique de la tige (voir Decor.stemWalls).
local WALL_OUTER = MapConfig.CELL_SIZE / 2 + WALL.THICKNESS
local SQUARE_REACH = math.sqrt(2) -- une plaque carrée tournée déborde de √2 fois son demi-côté
local PARK_MILLER, PARK_MODULUS = 16807, 2147483647

-- Générateur de Park-Miller : entiers exacts en double précision, donc identique sur toutes les machines.
function Scenery.rng(seed: number): Rng
	local state = seed % PARK_MODULUS
	if state <= 0 then
		state += PARK_MODULUS - 1
	end
	return function(): number
		state = (state * PARK_MILLER) % PARK_MODULUS
		return (state - 1) / (PARK_MODULUS - 1)
	end
end

local function between(rng: Rng, low: number, high: number): number
	return low + (high - low) * rng()
end

local function pick(rng: Rng, count: number): number
	return math.clamp(math.floor(rng() * count) + 1, 1, count)
end

-- Repère d'une berge : son bord intérieur longe le mur du champ, `normal` pointe vers l'extérieur.
function Scenery.bankFrame(side: number): BankFrame
	local inset = WALL_OUTER + SceneryConfig.BANK.GAP
	local startX, startZ = STEM.minX, side * (STEM.startHalfWidth + inset)
	local endX, endZ = STEM.maxX, side * (STEM.endHalfWidth + inset)
	local dx, dz = endX - startX, endZ - startZ
	local length = math.sqrt(dx * dx + dz * dz)
	local dirX, dirZ = dx / length, dz / length
	return {
		side = side,
		startX = startX,
		startZ = startZ,
		dirX = dirX,
		dirZ = dirZ,
		normalX = -side * dirZ,
		normalZ = side * dirX,
		length = length,
	}
end

-- Point de la berge à `u` studs le long du mur et `v` studs vers l'extérieur.
function Scenery.bankPoint(frame: BankFrame, u: number, v: number): (number, number)
	return frame.startX + frame.dirX * u + frame.normalX * v, frame.startZ + frame.dirZ * u + frame.normalZ * v
end

-- Vrai si le disque (x, z, margin) ne touche aucune zone où l'on joue : barre, fossé, champ et ses murs.
function Scenery.isClear(x: number, z: number, margin: number): boolean
	if x + margin < PLAZA.minX or math.abs(z) - margin > PLAZA.halfWidth then
		return true
	end
	if x - margin > STEM.maxX + WALL_OUTER then
		return true
	end
	if x - margin >= MOAT.maxX then
		-- À côté de la tige : elle est la plus large là où x est le plus petit.
		return math.abs(z) - margin > MapGeometry.stemHalfWidth(x - margin) + WALL_OUTER
	end
	return false
end

local function tiersFor(rng: Rng, low: number, high: number): number
	return low + pick(rng, high - low + 1) - 1
end

local function bankRow(
	rng: Rng,
	frame: BankFrame,
	range: SceneryConfig.Range,
	visit: (u: number, v: number, scale: number) -> ()
)
	local u = range.spacing / 2
	while u < frame.length do
		local jitter = between(rng, -range.spacing / 3, range.spacing / 3)
		local v = between(rng, range.minV, range.maxV)
		visit(math.clamp(u + jitter, 0, frame.length), v, between(rng, range.minScale, range.maxScale))
		u += range.spacing
	end
end

-- Collines proches (certaines portent un moulin) et montagnes lointaines, sur les deux berges.
function Scenery.hills(): { Hill }
	local rng = Scenery.rng(SceneryConfig.SEED)
	local hills: { Hill } = {}
	local hillConfig, mountainConfig = SceneryConfig.HILL, SceneryConfig.MOUNTAIN
	for _, side in { -1, 1 } do
		local frame = Scenery.bankFrame(side)
		local count = 0
		bankRow(rng, frame, hillConfig.NEAR, function(u, v, radius)
			local x, z = Scenery.bankPoint(frame, u, v)
			count += 1
			local reach = (v - SceneryConfig.BANK.GAP) / SQUARE_REACH -- ne touche jamais le mur
			table.insert(hills, {
				kind = "hill",
				x = x,
				z = z,
				radius = math.min(radius, reach),
				tiers = tiersFor(rng, hillConfig.MIN_TIERS, hillConfig.MAX_TIERS),
				yaw = between(rng, 0, 90),
				feature = if count % hillConfig.WINDMILL_EVERY == 0 then "windmill" else "trees",
				side = side,
			})
		end)
		bankRow(rng, frame, mountainConfig.FAR, function(u, v, radius)
			local x, z = Scenery.bankPoint(frame, u, v)
			table.insert(hills, {
				kind = "mountain",
				x = x,
				z = z,
				radius = radius,
				tiers = tiersFor(rng, mountainConfig.MIN_TIERS, mountainConfig.MAX_TIERS),
				yaw = between(rng, 0, 90),
				feature = nil,
				side = side,
			})
		end)
	end
	return hills
end

local function treeKind(rng: Rng): string
	local kinds = SceneryConfig.TREE.KINDS
	local total = 0
	for _, kind in kinds do
		total += kind.weight
	end
	local roll = rng() * total
	for _, kind in kinds do
		roll -= kind.weight
		if roll <= 0 then
			return kind.id
		end
	end
	return kinds[1].id
end

local function isOnHill(hills: { Hill }, x: number, z: number): boolean
	for _, hill in hills do
		local reach = hill.radius * SQUARE_REACH
		if (hill.x - x) ^ 2 + (hill.z - z) ^ 2 < reach * reach then
			return true
		end
	end
	return false
end

-- Arbres des berges : une lisière juste derrière les murs et une forêt plus loin. Aucun sous une colline.
function Scenery.bankTrees(): { Tree }
	local rng = Scenery.rng(SceneryConfig.SEED + 1)
	local hills = Scenery.hills()
	local trees: { Tree } = {}
	for _, side in { -1, 1 } do
		local frame = Scenery.bankFrame(side)
		for _, range in { SceneryConfig.TREE.BANK, SceneryConfig.TREE.FOREST } do
			bankRow(rng, frame, range, function(u, v, scale)
				local x, z = Scenery.bankPoint(frame, u, v)
				local tree =
					{ kind = treeKind(rng), x = x, z = z, scale = scale, yaw = between(rng, 0, 90), shade = rng() }
				if not isOnHill(hills, x, z) then
					table.insert(trees, tree)
				end
			end)
		end
	end
	return trees
end

function Scenery.clouds(): { Cloud }
	local rng = Scenery.rng(SceneryConfig.SEED + 2)
	local config = SceneryConfig.CLOUD
	local clouds: { Cloud } = {}
	for _ = 1, config.COUNT do
		table.insert(clouds, {
			x = between(rng, config.MIN_X, config.MAX_X),
			y = between(rng, config.MIN_Y, config.MAX_Y),
			z = between(rng, config.MIN_Z, config.MAX_Z),
			scale = between(rng, config.MIN_SCALE, config.MAX_SCALE),
		})
	end
	return clouds
end

local function riverSpots(rng: Rng, count: number): { Floater }
	local river = SceneryConfig.RIVER
	local spots: { Floater } = {}
	local attempts = 0
	while #spots < count and attempts < count * 20 do
		attempts += 1
		local x = between(rng, MOAT.minX + river.MARGIN, MOAT.maxX - river.MARGIN)
		local z = between(rng, -PLAZA.halfWidth + river.MARGIN, PLAZA.halfWidth - river.MARGIN)
		local variant = pick(rng, #river.FLOWER_COLORS + 1) -- la dernière valeur : sans fleur
		if not MapGeometry.isUnderBridge(x, z, river.BRIDGE_MARGIN) then
			table.insert(spots, { x = x, z = z, yaw = between(rng, 0, 360), variant = variant })
		end
	end
	return spots
end

-- Nénuphars du fossé, jamais sous un pont.
function Scenery.lilies(): { Floater }
	return riverSpots(Scenery.rng(SceneryConfig.SEED + 3), SceneryConfig.RIVER.LILY_COUNT)
end

function Scenery.ducks(): { Floater }
	return riverSpots(Scenery.rng(SceneryConfig.SEED + 4), SceneryConfig.RIVER.DUCK_COUNT)
end

-- Milieux des allées entre deux bases voisines, plus les deux bouts de la barre.
function Scenery.alleys(): { number }
	local bases = MapGeometry.baseCenters()
	local zs: { number } = { bases[1].z - MapConfig.BASE_PITCH / 2 }
	for i = 1, #bases - 1 do
		table.insert(zs, (bases[i].z + bases[i + 1].z) / 2)
	end
	table.insert(zs, bases[#bases].z + MapConfig.BASE_PITCH / 2)
	return zs
end

-- Jardins : une ligne de décor dans chaque allée, et une rangée basse derrière les bases.
function Scenery.gardens(): { Prop }
	local rng = Scenery.rng(SceneryConfig.SEED + 5)
	local garden = SceneryConfig.GARDEN
	local props: { Prop } = {}
	local function add(kind: string, x: number, z: number)
		table.insert(props, {
			kind = if kind == "tree" then treeKind(rng) else kind,
			x = x,
			z = z,
			yaw = between(rng, 0, 360),
			variant = pick(rng, 12),
			scale = between(rng, 0.9, 1.3),
		})
	end
	local alleys = Scenery.alleys()
	for index, alleyZ in alleys do
		local step = 0
		for x = garden.MIN_X, garden.MAX_X, garden.SPACING do
			step += 1
			local kind = garden.KINDS[(index * 3 + step) % #garden.KINDS + 1]
			add(kind, x + between(rng, -2, 2), alleyZ + between(rng, -garden.HALF_WIDTH, garden.HALF_WIDTH))
		end
	end
	local step = 0
	for z = -PLAZA.halfWidth + garden.BACK_SPACING, PLAZA.halfWidth - garden.BACK_SPACING, garden.BACK_SPACING do
		step += 1
		local isNearTree = false
		for _, alleyZ in alleys do
			isNearTree = isNearTree or math.abs(alleyZ - z) < garden.TREE_CLEARANCE
		end
		if not isNearTree then
			local kind = if step % 3 == 0 then "bush" elseif step % 3 == 1 then "flowers" else "rock"
			add(kind, garden.BACK_X + between(rng, -2, 2), z)
		end
	end
	return props
end

-- Un lampadaire au bord du boulevard devant chaque allée : jamais devant une porte de base.
function Scenery.lampPosts(): { Decor.Spot }
	local spots: { Decor.Spot } = {}
	for _, alleyZ in Scenery.alleys() do
		table.insert(spots, { x = SceneryConfig.LAMP.X, z = alleyZ })
	end
	return spots
end

-- Parasols le long de la plage, sur la première marche de sable.
function Scenery.beachProps(): { Prop }
	local rng = Scenery.rng(SceneryConfig.SEED + 6)
	local beach, config = SceneryConfig.BEACH, SceneryConfig.BEACH_PROPS
	local props: { Prop } = {}
	local x = PLAZA.minX - beach.STEPS[1].depth / 2
	for z = -PLAZA.halfWidth + config.SPACING / 2, PLAZA.halfWidth, config.SPACING do
		table.insert(props, {
			kind = "parasol",
			x = x + between(rng, -3, 3),
			z = z + between(rng, -14, 14),
			yaw = between(rng, 0, 360),
			variant = pick(rng, 12),
			scale = 1,
		})
	end
	return props
end

return Scenery
