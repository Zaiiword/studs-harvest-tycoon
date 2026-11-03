--!strict
-- Plan de la grande ferme Lego (A56), sans API Roblox : chaque élément du plan de construction est une liste de
-- briques (taille, position, couleur). TycoonDecor n'a plus qu'à les poser. Coordonnées locales de la base :
-- +X vers le champ, Z latéral, Y au-dessus du pont. Les murs sont de vraies rangées de briques en quinconce,
-- le toit un escalier de plaques à tenons : c'est ce qui donne le style « Lego ».
local FarmConfig = require("../config/FarmConfig")
local TycoonConfig = require("../config/TycoonConfig")

export type Sign = { face: string, text: string } -- `{owner}` est remplacé par le nom du joueur
export type Piece = {
	name: string,
	size: { number },
	at: { number }, -- centre de la pièce
	color: { number },
	tilt: { number }?, -- radians (x, y, z)
	shape: string?, -- « Cylinder » (axe X), « Ball » ; bloc par défaut
	material: string?,
	transparency: number?,
	reflectance: number?,
	isSolid: boolean?, -- collision et requêtes physiques ; décor traversable sinon
	isSmooth: boolean?, -- sans tenons (vitres, eau)
	light: number?, -- portée d'un PointLight
	signs: { Sign }?,
	group: string?, -- sous-modèle (ailes qui tournent, voir TycoonAnimController)
	isHub: boolean?, -- pièce principale du sous-modèle
	hasSpray: boolean?, -- jet d'eau
}
export type Opening = { from: number, to: number, bottom: number, top: number }
export type WallSpec = {
	axis: "x" | "z", -- axe le long duquel court le mur
	fixed: number, -- coordonnée du centre du mur sur l'autre axe
	from: number,
	to: number,
	baseY: number,
	courses: number,
	openings: { Opening }?,
	hasQuoins: boolean?, -- chaînage d'angle blanc
	stoneCourses: number?, -- rangées de soubassement en pierre
	brick: number?,
}

local FarmBlueprint = {}

local BARN, PALETTE = FarmConfig.BARN, FarmConfig.PALETTE
local COURSE = BARN.COURSE
local THICK = BARN.WALL
local FACADE_X = BARN.FRONT_X - THICK / 2
local BACK_X = BARN.BACK_X + THICK / 2
local SIDE_Z = BARN.HALF_Z - THICK / 2
local INNER_BACK, INNER_FRONT = BARN.BACK_X + THICK, BARN.FRONT_X - THICK
local INNER_Z = BARN.HALF_Z - THICK
local GROUND_TOP = BARN.GROUND_COURSES * COURSE
local EAVES = GROUND_TOP + BARN.UPPER_COURSES * COURSE
local LOFT_TOP = TycoonConfig.LAYOUT.LOFT_TOP
local MIN_BRICK = 1.2 -- pas de brique plus courte : on la soude à sa voisine
local HALF_TURN = math.pi / 2

local current: { Piece } = {} -- liste de l'élément en cours de construction

-- Hachage déterministe : une même brique a toujours la même teinte.
local function shade(rgb: { number }, seed: number): { number }
	local noise = ((seed * 2654435761) % 4294967296) / 4294967296
	local factor = 1 + (noise * 2 - 1) * FarmConfig.SHADE
	return { math.min(255, rgb[1] * factor), math.min(255, rgb[2] * factor), math.min(255, rgb[3] * factor) }
end

local function add(color: { number }, size: { number }, at: { number }, extra: { [string]: any }?): Piece
	local piece: any = { name = "Brick", color = color, size = size, at = at }
	for key, value in extra or {} do
		piece[key] = value
	end
	table.insert(current, piece)
	return piece
end

-- Cylindre debout : le cylindre Roblox est couché sur X, on le redresse.
local function pillar(color: { number }, dims: { number }, at: { number }, extra: { [string]: any }?): Piece
	local piece: any = add(color, { dims[1], dims[2], dims[2] }, at, extra)
	piece.shape = "Cylinder"
	piece.tilt = { 0, 0, HALF_TURN }
	return piece
end

local function neon(color: { number }, size: { number }, at: { number }, light: number?): Piece
	return add(color, size, at, { material = "Neon", light = light, isSmooth = true })
end

-- Pose un tronçon de mur : le mur court sur `axis`, son épaisseur est sur l'autre axe.
local function wallBrick(spec: WallSpec, span: { number }, y: { number }, color: { number })
	local center, length = (span[1] + span[2]) / 2, span[2] - span[1]
	local height = y[2] - y[1]
	local middle = (y[1] + y[2]) / 2
	if spec.axis == "x" then
		add(color, { length, height, THICK }, { center, middle, spec.fixed }, { isSolid = true })
	else
		add(color, { THICK, height, length }, { spec.fixed, middle, center }, { isSolid = true })
	end
end

-- Parties pleines d'une rangée, une fois retirées les ouvertures qui la croisent.
local function solidSpans(spec: WallSpec, bottom: number, top: number): { { number } }
	local cuts: { Opening } = {}
	for _, opening in spec.openings or {} do
		if opening.bottom < top - 1e-6 and opening.top > bottom + 1e-6 then
			table.insert(cuts, opening)
		end
	end
	table.sort(cuts, function(a, b)
		return a.from < b.from
	end)
	local spans: { { number } } = {}
	local cursor = spec.from
	for _, cut in cuts do
		if cut.from > cursor then
			table.insert(spans, { cursor, cut.from })
		end
		cursor = math.max(cursor, cut.to)
	end
	if cursor < spec.to then
		table.insert(spans, { cursor, spec.to })
	end
	return spans
end

-- Découpe une partie pleine en briques, sur une grille décalée d'une demi-brique à chaque rangée (quinconce).
local function cutBricks(spec: WallSpec, span: { number }, course: number): { { number } }
	local length = spec.brick or BARN.BRICK
	local offset = if course % 2 == 0 then 0 else length / 2
	local bricks: { { number } } = {}
	local start = span[1]
	local boundary = spec.from + offset + (math.floor((start - spec.from - offset) / length) + 1) * length
	while start < span[2] - 1e-6 do
		while boundary - start < MIN_BRICK do
			boundary += length
		end
		local stop = if span[2] - boundary < MIN_BRICK then span[2] else boundary
		stop = math.min(stop, span[2])
		table.insert(bricks, { start, stop })
		start = stop
		boundary += length
	end
	return bricks
end

-- Mur en rangées de briques : soubassement en pierre, chaînage blanc aux angles, teinte qui varie à chaque brique.
local function wall(spec: WallSpec)
	for course = 0, spec.courses - 1 do
		local bottom = spec.baseY + course * COURSE
		local top = bottom + COURSE
		local isStone = course < (spec.stoneCourses or 0)
		local quoin = BARN.QUOINS[course % 2 + 1]
		for _, span in solidSpans(spec, bottom, top) do
			local spans = { span }
			-- Le chaînage d'angle est une brique à part, plus courte, alternée d'une rangée à l'autre.
			if spec.hasQuoins and not isStone then
				spans = {}
				local first, last = span[1], span[2]
				if first <= spec.from + 1e-6 then
					local stop = math.min(first + quoin, last)
					wallBrick(spec, { first, stop }, { bottom, top }, PALETTE.WHITE)
					first = stop
				end
				if last >= spec.to - 1e-6 then
					local start = math.max(last - quoin, first)
					if start < last then
						wallBrick(spec, { start, last }, { bottom, top }, PALETTE.WHITE)
					end
					last = start
				end
				if last > first then
					spans = { { first, last } }
				end
			end
			for _, solid in spans do
				for index, brick in cutBricks(spec, solid, course) do
					local base = if isStone then PALETTE.STONE else PALETTE.RED
					wallBrick(spec, brick, { bottom, top }, shade(base, course * 37 + index + math.floor(brick[1])))
				end
			end
		end
	end
end

-- Encadrement blanc, carreau et croisillon d'une fenêtre percée dans un mur.
local function windowFrame(spec: WallSpec, center: number, bottom: number, wide: number?)
	local width = wide or BARN.WINDOW_WIDTH
	local height = BARN.WINDOW_COURSES * COURSE
	local depth = THICK + 0.4
	local function bar(along: number, size: { number }, y: number)
		if spec.axis == "x" then
			add(PALETTE.WHITE, { size[1], size[2], depth }, { along, y, spec.fixed })
		else
			add(PALETTE.WHITE, { depth, size[2], size[1] }, { spec.fixed, y, along })
		end
	end
	local middle = bottom + height / 2
	if spec.axis == "x" then
		add(
			PALETTE.GLASS,
			{ width, height, 0.3 },
			{ center, middle, spec.fixed },
			{ material = "Glass", transparency = 0.45, isSmooth = true, isSolid = true }
		)
	else
		add(
			PALETTE.GLASS,
			{ 0.3, height, width },
			{ spec.fixed, middle, center },
			{ material = "Glass", transparency = 0.45, isSmooth = true, isSolid = true }
		)
	end
	bar(center, { width + 1, 0.6 }, bottom)
	bar(center, { width + 1, 0.6 }, bottom + height)
	bar(center - width / 2, { 0.6, height }, middle)
	bar(center + width / 2, { 0.6, height }, middle)
	bar(center, { 0.4, height }, middle)
	bar(center, { width, 0.4 }, middle)
end

-- Bas des fenêtres d'un niveau : plus haut au rez-de-chaussée, juste au-dessus du plancher à l'étage.
local function windowBottom(baseY: number): number
	return baseY + (if baseY == 0 then BARN.WINDOW_FROM_COURSE else BARN.UPPER_WINDOW_FROM_COURSE) * COURSE
end

-- Ouvertures de fenêtres d'un mur, centrées sur `centers`.
local function windowOpenings(centers: { number }, baseY: number, wide: number?): { Opening }
	local openings: { Opening } = {}
	local width = wide or BARN.WINDOW_WIDTH
	local bottom = windowBottom(baseY)
	local top = bottom + BARN.WINDOW_COURSES * COURSE
	for _, center in centers do
		table.insert(openings, {
			from = center - width / 2,
			to = center + width / 2,
			bottom = bottom,
			top = top,
		})
	end
	return openings
end

local function sideWall(z: number, baseY: number, courses: number, extra: { Opening }?): WallSpec
	local openings = windowOpenings(BARN.SIDE_WINDOWS_X, baseY)
	for _, opening in extra or {} do
		table.insert(openings, opening)
	end
	return {
		axis = "x",
		fixed = z,
		from = INNER_BACK,
		to = INNER_FRONT,
		baseY = baseY,
		courses = courses,
		openings = openings,
		hasQuoins = true,
		stoneCourses = if baseY == 0 then BARN.STONE_COURSES else 0,
	}
end

local function backWall(baseY: number, courses: number): WallSpec
	return {
		axis = "z",
		fixed = BACK_X,
		from = -BARN.HALF_Z,
		to = BARN.HALF_Z,
		baseY = baseY,
		courses = courses,
		openings = windowOpenings(BARN.BACK_WINDOWS_Z, baseY),
		hasQuoins = true,
		stoneCourses = if baseY == 0 then BARN.STONE_COURSES else 0,
	}
end

local function frontWall(baseY: number, courses: number, openings: { Opening }): WallSpec
	return {
		axis = "z",
		fixed = FACADE_X,
		from = -BARN.HALF_Z,
		to = BARN.HALF_Z,
		baseY = baseY,
		courses = courses,
		openings = openings,
		hasQuoins = true,
		stoneCourses = if baseY == 0 then BARN.STONE_COURSES else 0,
	}
end

local function doorHeight(): number
	return BARN.DOOR_COURSES * COURSE
end

-- Éléments du plan ------------------------------------------------------------------------------------------------

local function path()
	local rows, bricks = 8, 6 -- aussi large que la porte, entre les lampadaires
	local length, width = 4, 2.5
	for row = 0, rows - 1 do
		local stagger = if row % 2 == 0 then 0 else width / 2
		for k = 0, bricks - 1 do
			local z = -width * bricks / 2 + (k + 0.5) * width + stagger - width / 4
			add(
				shade(PALETTE.STONE, row * 11 + k),
				{ length - 0.15, 0.2, width - 0.15 },
				{ 3 + (row + 0.5) * length, 0.1, z }
			)
		end
	end
end

local function barnFloor()
	local boards, width = 15, 4
	local length = INNER_FRONT - INNER_BACK
	for k = 0, boards - 1 do
		local z = -INNER_Z + (k + 0.5) * width
		add(
			shade(PALETTE.PLANK, k * 7),
			{ length, 0.3, width - 0.1 },
			{ (INNER_BACK + INNER_FRONT) / 2, 0.15, z },
			{ isSolid = true }
		)
	end
end

local function wallBack()
	wall(backWall(0, BARN.GROUND_COURSES))
end

local function wallSouth()
	local hole = BARN.BELT_HOLE
	wall(sideWall(-SIDE_Z, 0, BARN.GROUND_COURSES, {
		{ from = hole.fromX, to = hole.toX, bottom = 0, top = hole.courses * COURSE },
	}))
end

local function wallNorth()
	wall(sideWall(SIDE_Z, 0, BARN.GROUND_COURSES))
end

local function facade()
	local half = BARN.DOOR_HALF_WIDTH
	local openings = windowOpenings(BARN.FRONT_WINDOWS_Z, 0, BARN.FRONT_WINDOW_WIDTH)
	table.insert(openings, { from = -half, to = half, bottom = 0, top = doorHeight() })
	wall(frontWall(0, BARN.GROUND_COURSES, openings))
	local height = doorHeight()
	local x = BARN.FRONT_X + 0.2
	for _, side in { -1, 1 } do
		add(PALETTE.WHITE, { 1, height + 1, 1.2 }, { x, (height + 1) / 2, side * (half + 0.6) })
	end
	add(PALETTE.WHITE, { 1, 1.2, half * 2 + 2.4 }, { x, height + 0.6, 0 })
	local board = add(PALETTE.WOOD, { 0.6, 3, 20 }, { BARN.FRONT_X + 0.3, height + 3, 0 }, { name = "Sign" })
	board.signs = { { face = "Right", text = "🌾 FERME DE {owner}" } }
end

-- Battants ouverts contre la façade : panneau rouge, cadre blanc et croix de Saint-André.
local function doors()
	local half = BARN.DOOR_HALF_WIDTH
	local height = doorHeight()
	local leaf = half
	local x = BARN.FRONT_X + 0.7
	local diagonal = math.sqrt(height * height + leaf * leaf) - 0.5
	local lean = math.atan2(leaf, height)
	for _, side in { -1, 1 } do
		local z = side * (half + 1.2 + leaf / 2)
		add(shade(PALETTE.RED, 3), { 0.5, height, leaf }, { x, height / 2, z })
		for _, y in { 0.4, height - 0.4 } do
			add(PALETTE.WHITE, { 0.7, 0.8, leaf }, { x, y, z })
		end
		for _, edge in { -1, 1 } do
			add(PALETTE.WHITE, { 0.7, height, 0.8 }, { x, height / 2, z + edge * (leaf / 2 - 0.4) })
			add(PALETTE.WHITE, { 0.65, diagonal, 0.7 }, { x, height / 2, z }, { tilt = { edge * lean, 0, 0 } })
		end
	end
end

local function windows()
	local function each(spec: WallSpec, centers: { number }, wide: number?)
		for _, center in centers do
			windowFrame(spec, center, windowBottom(0), wide)
		end
	end
	each(sideWall(-SIDE_Z, 0, 1), BARN.SIDE_WINDOWS_X)
	each(sideWall(SIDE_Z, 0, 1), BARN.SIDE_WINDOWS_X)
	each(backWall(0, 1), BARN.BACK_WINDOWS_Z)
	each(frontWall(0, 1, {}), BARN.FRONT_WINDOWS_Z, BARN.FRONT_WINDOW_WIDTH)
	-- Jardinières sous les fenêtres de la façade.
	for _, z in BARN.FRONT_WINDOWS_Z do
		local y = windowBottom(0) - 0.7
		add(PALETTE.WOOD, { 1.2, 1, BARN.FRONT_WINDOW_WIDTH }, { BARN.FRONT_X + 0.6, y, z })
		for k = -1, 1 do
			local color = FarmConfig.FLOWER_COLORS[k + 2]
			add(color, { 0.9, 0.9, 0.9 }, { BARN.FRONT_X + 0.6, y + 0.9, z + k * 1.7 }, { shape = "Ball" })
		end
	end
end

local function lantern(at: { number }, range: number)
	add(PALETTE.DARK, { 1.3, 0.3, 1.3 }, { at[1], at[2] + 0.95, at[3] })
	neon(PALETTE.WARM_LIGHT, { 0.9, 1.5, 0.9 }, at, range)
	add(PALETTE.DARK, { 1.3, 0.3, 1.3 }, { at[1], at[2] - 0.95, at[3] })
end

local function lanterns()
	for _, side in { -1, 1 } do
		add(PALETTE.DARK, { 1.4, 0.3, 0.3 }, { BARN.FRONT_X + 0.7, 18.6, side * 15 })
		lantern({ BARN.FRONT_X + 1.2, 17.3, side * 15 }, 22)
		for _, x in { -14, -4 } do
			add(PALETTE.DARK, { 0.2, 2.2, 0.2 }, { x, GROUND_TOP - 1.1, side * 14 })
			lantern({ x, GROUND_TOP - 3.2, side * 14 }, 26)
		end
	end
end

local function flowerBed(x: number, z: number)
	add(PALETTE.STONE, { 4, 0.8, 8 }, { x, 0.4, z })
	add(PALETTE.SOIL, { 3.2, 0.2, 7.2 }, { x, 0.85, z })
	for k = 0, 3 do
		for _, offset in { -0.8, 0.8 } do
			local flowerZ = z - 2.7 + k * 1.8
			add(PALETTE.LEAF, { 0.2, 1, 0.2 }, { x + offset, 1.4, flowerZ })
			local color = FarmConfig.FLOWER_COLORS[(k + (if offset > 0 then 2 else 0)) % #FarmConfig.FLOWER_COLORS + 1]
			add(color, { 0.8, 0.8, 0.8 }, { x + offset, 2.1, flowerZ }, { shape = "Ball" })
		end
	end
end

local function flowers()
	for _, side in { -1, 1 } do
		flowerBed(5, side * 28)
		flowerBed(22, side * 10)
	end
end

local function lamps()
	local height = 9
	for _, x in { 8, 18, 30 } do
		for _, side in { -1, 1 } do
			local z = side * 8
			add(PALETTE.DARK, { 0.6, height, 0.6 }, { x, height / 2, z })
			add(PALETTE.DARK, { 1.6, 0.4, 1.6 }, { x, 0.2, z })
			add(PALETTE.DARK, { 0.4, 0.4, 1.6 }, { x, height, z - side * 0.6 })
			neon(PALETTE.WARM_LIGHT, { 1, 1.2, 1 }, { x, height - 0.7, z - side * 1.2 }, 18)
		end
	end
end

local function bale(at: { number }, isAlongZ: boolean)
	local size = if isAlongZ then { 3, 2.4, 5 } else { 5, 2.4, 3 }
	add(shade(PALETTE.HAY, math.floor(at[1] + at[3] * 3 + at[2] * 7)), size, at)
	for _, offset in { -1.1, 1.1 } do
		local strapSize = if isAlongZ then { 3.1, 2.5, 0.3 } else { 0.3, 2.5, 3.1 }
		local x = if isAlongZ then at[1] else at[1] + offset
		local z = if isAlongZ then at[3] + offset else at[3]
		add(PALETTE.STRAP, strapSize, { x, at[2], z })
	end
end

local function hay()
	local baseX, baseZ = -4, -42
	for k = -1, 1 do
		bale({ baseX + k * 5.2, 1.2, baseZ }, false)
	end
	for _, k in { -0.5, 0.5 } do
		bale({ baseX + k * 5.2, 3.6, baseZ }, false)
	end
	bale({ baseX, 6, baseZ }, false)
	bale({ 54, 1.2, -26 }, true)
	bale({ 54, 3.6, -26 }, true)
end

local function appleTree(x: number, z: number)
	add(PALETTE.WOOD, { 1.6, 7, 1.6 }, { x, 3.5, z })
	for index, layer in { { 7, 8 }, { 5.5, 10.2 }, { 3.5, 12.2 } } do
		local color = if index % 2 == 0 then PALETTE.LEAF_LIGHT else PALETTE.LEAF
		add(color, { layer[1], 2.2, layer[1] }, { x, layer[2], z })
	end
	for _, spot in { { 3.6, 0.8 }, { -3.6, -1 }, { 1, 3.6 }, { -1.2, -3.6 }, { 2.7, -1.8 } } do
		add(PALETTE.APPLE, { 0.9, 0.9, 0.9 }, { x + spot[1], 7.8, z + spot[2] }, { shape = "Ball" })
	end
end

local function trees()
	appleTree(10, 48)
	appleTree(24, 52)
	appleTree(40, 50)
end

local function well()
	local x, z = 30, 28
	pillar(PALETTE.STONE, { 2.6, 6 }, { x, 1.3, z })
	pillar(PALETTE.WATER, { 0.15, 4.6 }, { x, 2.68, z }, { isSmooth = true })
	for _, side in { -1, 1 } do
		add(PALETTE.WOOD, { 0.6, 7, 0.6 }, { x, 3.5, z + side * 2.8 })
	end
	for index, width in { 7, 5, 3, 1.4 } do
		add(PALETTE.RED, { 4, 0.6, width }, { x, 6.6 + index * 0.6, z })
	end
	add(PALETTE.DARK, { 0.3, 0.3, 5.6 }, { x, 5.6, z })
	add(PALETTE.DARK, { 0.1, 2, 0.1 }, { x, 4.6, z })
	pillar(PALETTE.WOOD, { 1, 1 }, { x, 3.4, z })
end

local function fountain()
	local x, z = 46, 28
	pillar(PALETTE.STONE, { 1.5, 12 }, { x, 0.75, z })
	-- L'eau flotte au-dessus du bassin sans toucher sa face : deux faces au même niveau scintillent.
	pillar(PALETTE.WATER, { 0.12, 10.4 }, { x, 1.62, z }, { isSmooth = true, transparency = 0.15, reflectance = 0.2 })
	pillar(PALETTE.STONE, { 4, 1.6 }, { x, 3, z })
	pillar(PALETTE.STONE, { 0.8, 5 }, { x, 5.2, z })
	local spout = neon(PALETTE.WATER, { 0.8, 0.8, 0.8 }, { x, 6, z }, 14)
	spout.hasSpray = true
end

local function cart()
	local x, z = 44, -26
	add(PALETTE.WOOD, { 4.4, 0.5, 8 }, { x, 2.6, z })
	for _, side in { -1, 1 } do
		add(shade(PALETTE.WOOD, side + 2), { 0.4, 1.6, 8 }, { x + side * 2, 3.6, z })
		add(shade(PALETTE.WOOD, side + 5), { 4.4, 1.6, 0.4 }, { x, 3.6, z + side * 3.8 })
		for _, along in { -2.2, 2.2 } do
			add(PALETTE.DARK, { 0.5, 3.2, 3.2 }, { x + side * 2.5, 1.6, z + along }, { shape = "Cylinder" })
			add(PALETTE.GOLD, { 0.6, 1, 1 }, { x + side * 2.5, 1.6, z + along }, { shape = "Cylinder" })
		end
		add(PALETTE.WOOD, { 0.3, 0.3, 3 }, { x + side * 1.2, 2.4, z + 5.4 })
	end
	add(PALETTE.HAY, { 3.6, 1.6, 7.2 }, { x, 4.8, z })
	add(PALETTE.HAY, { 2.4, 1, 5 }, { x, 6, z })
end

local function scarecrow()
	local x, z = 46, 42
	add(PALETTE.WOOD, { 0.6, 8, 0.6 }, { x, 4, z })
	add(PALETTE.WOOD, { 0.5, 0.5, 6 }, { x, 6.2, z })
	add(PALETTE.SHIRT, { 1.6, 3, 2.6 }, { x, 5.6, z })
	add(PALETTE.RED, { 1.65, 0.6, 2.65 }, { x, 4.4, z })
	add(PALETTE.HAY, { 1.8, 1.8, 1.8 }, { x, 8, z })
	add(PALETTE.STRAP, { 3, 0.25, 3 }, { x, 9, z })
	add(PALETTE.STRAP, { 1.6, 1, 1.6 }, { x, 9.6, z })
	for _, side in { -1, 1 } do
		add(PALETTE.HAY, { 0.8, 0.8, 0.8 }, { x, 6.2, z + side * 3.2 })
	end
end

local function mailbox()
	local x, z = 52, 16
	add(PALETTE.WOOD, { 0.6, 4, 0.6 }, { x, 2, z })
	local box = add(PALETTE.RED, { 2.4, 1.6, 1.4 }, { x, 4.6, z }, { name = "Box" })
	box.signs = { { face = "Back", text = "{owner}" } }
	add(PALETTE.WHITE, { 2.5, 0.3, 1.5 }, { x, 5.5, z })
	add(PALETTE.GOLD, { 0.2, 1, 0.5 }, { x + 1.3, 5, z + 0.8 })
end

local function bench()
	local x, z = 38, 18
	add(PALETTE.PLANK, { 1.6, 0.3, 4.4 }, { x, 1.6, z })
	add(PALETTE.PLANK, { 0.3, 1.4, 4.4 }, { x - 0.75, 2.5, z })
	for _, side in { -1, 1 } do
		add(PALETTE.DARK, { 1.4, 1.5, 0.3 }, { x, 0.75, z + side * 1.8 })
		add(PALETTE.DARK, { 0.3, 1.4, 0.3 }, { x - 0.75, 2.2, z + side * 1.8 })
	end
end

local function garden()
	local x, z = 34, -30
	for row = -1, 1 do
		local rowZ = z + row * 4
		add(shade(PALETTE.SOIL, row + 3), { 11, 0.8, 2.6 }, { x, 0.4, rowZ })
		for k = -2, 2 do
			local plantX = x + k * 2.1
			if row == 0 then
				add(PALETTE.ORANGE, { 0.6, 0.5, 0.6 }, { plantX, 1, rowZ })
				add(PALETTE.LEAF_LIGHT, { 0.4, 0.9, 0.4 }, { plantX, 1.6, rowZ })
			else
				add(if k % 2 == 0 then PALETTE.LEAF else PALETTE.LEAF_LIGHT, { 1.3, 1, 1.3 }, { plantX, 1.3, rowZ })
			end
		end
	end
	for _, side in { -1, 1 } do
		add(PALETTE.WOOD, { 12, 1, 0.4 }, { x, 0.5, z + side * 6 })
		add(PALETTE.WOOD, { 0.4, 1, 12 }, { x + side * 6, 0.5, z })
	end
end

local function pumpkins()
	local x, z = 54, -15
	add(PALETTE.SOIL, { 5.6, 0.4, 5.6 }, { x, 0.2, z })
	for _, spot in { { -1.5, -1.5, 1.6 }, { 1.4, -1.2, 1.2 }, { 0, 0.6, 2 }, { -1.6, 1.8, 1.1 }, { 1.7, 1.8, 1.4 } } do
		add(
			PALETTE.ORANGE,
			{ spot[3], spot[3] * 0.85, spot[3] },
			{ x + spot[1], 0.4 + spot[3] * 0.42, z + spot[2] },
			{ shape = "Ball" }
		)
		add(PALETTE.LEAF, { 0.25, 0.4, 0.25 }, { x + spot[1], 0.5 + spot[3] * 0.9, z + spot[2] })
	end
end

local function pen()
	local x, z = -30, -46
	local halfX, halfZ = 5, 6
	add(PALETTE.MUD, { halfX * 2, 0.3, halfZ * 2 }, { x, 0.15, z })
	for _, sideZ in { -1, 1 } do
		for _, y in { 1, 2.2 } do
			add(PALETTE.WOOD, { halfX * 2, 0.4, 0.4 }, { x, y, z + sideZ * halfZ })
		end
		for _, sideX in { -1, 1 } do
			add(PALETTE.WOOD, { 0.7, 3, 0.7 }, { x + sideX * halfX, 1.5, z + sideZ * halfZ })
		end
	end
	for _, sideX in { -1, 1 } do
		for _, y in { 1, 2.2 } do
			add(PALETTE.WOOD, { 0.4, 0.4, halfZ * 2 }, { x + sideX * halfX, y, z })
		end
	end
	add(PALETTE.WOOD, { 1.4, 0.8, 4 }, { x - 3, 0.7, z })
	for _, spot in { { 1, -2.5 }, { 1.5, 2.2 } } do
		local pigX, pigZ = x + spot[1], z + spot[2]
		add(PALETTE.PINK, { 2.6, 1.4, 1.6 }, { pigX, 1.2, pigZ })
		add(PALETTE.PINK, { 1.2, 1.2, 1.2 }, { pigX - 1.6, 1.5, pigZ })
		add(shade(PALETTE.PINK, 9), { 0.3, 0.5, 0.7 }, { pigX - 2.3, 1.3, pigZ })
		for _, side in { -1, 1 } do
			add(PALETTE.PINK, { 0.4, 0.6, 0.4 }, { pigX - 0.8, 0.3, pigZ + side * 0.5 })
			add(PALETTE.PINK, { 0.4, 0.6, 0.4 }, { pigX + 0.8, 0.3, pigZ + side * 0.5 })
			add(PALETTE.PINK, { 0.3, 0.4, 0.3 }, { pigX - 1.6, 2.2, pigZ + side * 0.4 })
		end
	end
end

local function beehives()
	local x, z = 7.5, 37
	add(PALETTE.STONE, { 5, 0.4, 5 }, { x, 0.2, z })
	for _, side in { -1, 1 } do
		local hiveZ = z + side * 1.3
		add(PALETTE.WHITE, { 2.2, 1, 2 }, { x, 1, hiveZ })
		add(PALETTE.HAY, { 2.2, 1, 2 }, { x, 2, hiveZ })
		add(PALETTE.WHITE, { 2.2, 1, 2 }, { x, 3, hiveZ })
		add(PALETTE.RED, { 2.6, 0.4, 2.3 }, { x, 3.7, hiveZ })
		add(PALETTE.DARK, { 0.1, 0.3, 0.8 }, { x + 1.15, 0.8, hiveZ })
	end
end

local function stairs()
	local spec = BARN.STAIRS
	local width = spec.maxZ - spec.minZ
	local z = (spec.minZ + spec.maxZ) / 2
	for step = 1, spec.steps do
		local x = spec.startX - (step - 0.5) * spec.run
		add(shade(PALETTE.WOOD, step * 5), { spec.run, step, width }, { x, step / 2, z }, { isSolid = true })
	end
	-- Rampe blanche, le long du côté ouvert.
	local rise, run = spec.steps, spec.steps * spec.run
	local slope = math.atan2(rise, run)
	local length = math.sqrt(rise * rise + run * run)
	local middleX = spec.startX - run / 2
	add(PALETTE.WHITE, { length, 0.4, 0.4 }, { middleX, rise / 2 + 3, spec.minZ - 0.2 }, { tilt = { 0, 0, -slope } })
	for step = 1, spec.steps, 4 do
		local x = spec.startX - (step - 0.5) * spec.run
		add(PALETTE.WHITE, { 0.4, 3, 0.4 }, { x, step + 1.5, spec.minZ - 0.2 })
	end
end

local function loft()
	local front = BARN.LOFT_FRONT_X
	local stairTop = BARN.STAIRS.startX - BARN.STAIRS.steps * BARN.STAIRS.run -- haut de l'escalier
	local stairZ = BARN.STAIRS.minZ
	local top, thickness = LOFT_TOP, BARN.LOFT_THICKNESS
	local boardWidth = 5
	local z = -INNER_Z
	local index = 0
	while z < INNER_Z - 1e-6 do
		index += 1
		-- Vers le haut de l'escalier, le plancher s'arrête pour laisser monter.
		local toX = if z + boardWidth > stairZ then stairTop else front
		local length = toX - INNER_BACK
		add(shade(PALETTE.PLANK, index * 13), { length, thickness, boardWidth - 0.1 }, {
			INNER_BACK + length / 2,
			top - thickness / 2,
			z + boardWidth / 2,
		}, { isSolid = true })
		z += boardWidth
	end
	-- Poteaux et poutre maîtresse.
	add(PALETTE.WOOD, { 2, 1.2, INNER_Z * 2 }, { front - 1, top - thickness - 0.6, 0 }, { isSolid = true })
	for _, postZ in { -26, -8, 10, 23 } do
		add(PALETTE.WOOD, { 2, top - thickness, 2 }, { front - 2, (top - thickness) / 2, postZ }, { isSolid = true })
	end
	-- Garde-corps blanc au bord de l'étage et le long de la trémie d'escalier.
	local railHeight = 3
	local rails = {
		{ size = { 0.5, 0.5, INNER_Z + stairZ }, x = front - 0.3, z = (stairZ - INNER_Z) / 2 },
		{ size = { front - stairTop, 0.5, 0.5 }, x = (front + stairTop) / 2, z = stairZ - 0.3 },
	}
	for _, rail in rails do
		add(PALETTE.WHITE, rail.size, { rail.x, top + railHeight, rail.z }, { isSolid = true })
	end
	local postZ = -INNER_Z
	while postZ <= stairZ do
		add(PALETTE.WHITE, { 0.5, railHeight, 0.5 }, { front - 0.3, top + railHeight / 2, postZ }, { isSolid = true })
		postZ += 6
	end
	-- Tapis de la chaîne de l'étage, animé comme celui du rez-de-chaussée (nom « Conveyor »).
	add(PALETTE.BELT, { 5, 1, 48 }, { -48, top + 0.5, -2 }, { name = "Conveyor", isSolid = true })
	for _, side in { -1, 1 } do
		add({ 210, 210, 215 }, { 0.5, 1.6, 48 }, { -48 + side * 2.75, top + 0.8, -2 }, { material = "Metal" })
	end
end

local function hayDoor(half: number, bottom: number, top: number)
	local x = BARN.FRONT_X + 0.2
	for _, side in { -1, 1 } do
		add(PALETTE.WHITE, { 1, top - bottom + 1, 1 }, { x, (top + bottom) / 2, side * (half + 0.5) })
		add(
			shade(PALETTE.RED, 8),
			{ 0.5, top - bottom, half },
			{ x + 0.5, (top + bottom) / 2, side * (half + 1 + half / 2) }
		)
		add(PALETTE.WHITE, { 0.6, 0.6, half }, { x + 0.5, (top + bottom) / 2, side * (half + 1 + half / 2) })
	end
	add(PALETTE.WHITE, { 1, 1, half * 2 + 2 }, { x, top + 0.5, 0 })
	add(PALETTE.WHITE, { 1, 1, half * 2 + 2 }, { x, bottom - 0.5, 0 })
end

local function upperWalls()
	local base = GROUND_TOP
	wall(sideWall(-SIDE_Z, base, BARN.UPPER_COURSES))
	wall(sideWall(SIDE_Z, base, BARN.UPPER_COURSES))
	wall(backWall(base, BARN.UPPER_COURSES))
	local half = BARN.HAY_DOOR_HALF_WIDTH
	local hayBottom = base + COURSE
	local hayTop = hayBottom + 4 * COURSE
	wall(frontWall(base, BARN.UPPER_COURSES, { { from = -half, to = half, bottom = hayBottom, top = hayTop } }))
	hayDoor(half, hayBottom, hayTop)
	for _, z in { -SIDE_Z, SIDE_Z } do
		for _, x in BARN.SIDE_WINDOWS_X do
			windowFrame(sideWall(z, base, 1), x, windowBottom(base))
		end
	end
	for _, z in BARN.BACK_WINDOWS_Z do
		windowFrame(backWall(base, 1), z, windowBottom(base))
	end
	-- Bandeau blanc sous l'avant-toit.
	local length = BARN.FRONT_X - BARN.BACK_X
	local middleX = (BARN.FRONT_X + BARN.BACK_X) / 2
	for _, side in { -1, 1 } do
		add(PALETTE.WHITE, { length, 0.6, 0.6 }, { middleX, EAVES - 0.3, side * (BARN.HALF_Z + 0.1) })
	end
end

-- Profil du toit à la Mansart : pour chaque gradin, sa hauteur et sa distance au faîtage.
local function roofSteps(): { { y: number, height: number, outer: number, inner: number } }
	local roof = BARN.ROOF
	local steps = {}
	local y, outer = EAVES, BARN.HALF_Z + roof.OVERHANG
	for _ = 1, roof.LOWER_STEPS do
		table.insert(steps, { y = y, height = roof.LOWER_RISE, outer = outer, inner = outer - roof.LOWER_INSET })
		y += roof.LOWER_RISE
		outer -= roof.LOWER_INSET
	end
	for _ = 1, roof.UPPER_STEPS do
		table.insert(steps, { y = y, height = roof.UPPER_RISE, outer = outer, inner = outer - roof.UPPER_INSET })
		y += roof.UPPER_RISE
		outer -= roof.UPPER_INSET
	end
	return steps
end

function FarmBlueprint.ridgeHeight(): number
	local last = roofSteps()
	local step = last[#last]
	return step.y + step.height
end

local function gable(x: number)
	local overhang = BARN.ROOF.OVERHANG
	for index, step in roofSteps() do
		local half = math.max(step.outer - overhang, 0)
		if half > 0.5 then
			add(
				shade(PALETTE.RED, index * 9 + math.floor(x)),
				{ THICK, step.height, half * 2 },
				{ x, step.y + step.height / 2, 0 }
			)
		end
	end
end

local function roof()
	local overhang = BARN.ROOF.OVERHANG
	local fromX, toX = BARN.BACK_X - overhang, BARN.FRONT_X + overhang
	local length = toX - fromX
	local middleX = (fromX + toX) / 2
	for index, step in roofSteps() do
		local width = step.outer - math.max(step.inner, 0) + 0.5
		local center = step.outer - width / 2
		local base = if index % 2 == 0 then PALETTE.ROOF_LIGHT else PALETTE.ROOF
		for _, side in { -1, 1 } do
			add(base, { length, step.height, width }, { middleX, step.y + step.height / 2, side * center })
		end
	end
	local ridge = FarmBlueprint.ridgeHeight()
	add(PALETTE.WHITE, { length + 0.4, 0.8, 3 }, { middleX, ridge + 0.4, 0 })
	for _, side in { -1, 1 } do
		add(PALETTE.WHITE, { length, 0.5, 0.8 }, { middleX, EAVES - 0.1, side * (BARN.HALF_Z + overhang) })
	end
	gable(FACADE_X)
	gable(BACK_X)
	-- Œil-de-bœuf en haut de la façade.
	add(PALETTE.WHITE, { THICK + 0.6, 7, 7 }, { FACADE_X, EAVES + 7, 0 }, { shape = "Cylinder" })
	add(
		PALETTE.GLASS,
		{ THICK + 0.8, 5, 5 },
		{ FACADE_X, EAVES + 7, 0 },
		{ shape = "Cylinder", material = "Glass", transparency = 0.3, isSmooth = true }
	)
end

local function cupola()
	local x = (BARN.BACK_X + BARN.FRONT_X) / 2
	local ridge = FarmBlueprint.ridgeHeight() + 0.8
	add(PALETTE.WHITE, { 8, 1, 8 }, { x, ridge + 0.5, 0 })
	add(PALETTE.RED, { 6, 4, 6 }, { x, ridge + 3, 0 })
	for _, side in { -1, 1 } do
		neon(PALETTE.WARM_LIGHT, { 6.1, 2, 2 }, { x, ridge + 3, side * 1.5 })
		neon(PALETTE.WARM_LIGHT, { 2, 2, 6.1 }, { x + side * 1.5, ridge + 3, 0 })
	end
	for index, width in { 7.5, 6, 4.4, 2.8, 1.4 } do
		add(
			if index % 2 == 0 then PALETTE.ROOF_LIGHT else PALETTE.ROOF,
			{ width, 0.8, width },
			{ x, ridge + 4.6 + index * 0.8, 0 }
		)
	end
	local top = ridge + 9.6
	add(PALETTE.GOLD, { 1.2, 1.2, 1.2 }, { x, top, 0 }, { shape = "Ball", material = "Metal", reflectance = 0.3 })
	add(PALETTE.DARK, { 0.25, 4, 0.25 }, { x, top + 2, 0 })
	add(PALETTE.DARK, { 0.2, 0.2, 5 }, { x, top + 3, 0 })
	add(PALETTE.GOLD, { 0.2, 1.4, 1.6 }, { x, top + 3.4, 1.8 }, { material = "Metal" })
	add(PALETTE.GOLD, { 0.2, 0.9, 0.9 }, { x, top + 3.8, -2.2 }, { material = "Metal" })
end

local function flag()
	local x, z, height = 52, 42, 22
	add(PALETTE.WHITE, { 0.7, height, 0.7 }, { x, height / 2, z }, { material = "Metal" })
	add(PALETTE.STONE, { 3, 1, 3 }, { x, 0.5, z })
	add(PALETTE.GOLD, { 1.4, 1.4, 1.4 }, { x, height + 0.5, z }, { shape = "Ball", reflectance = 0.35 })
	local cloth = add(PALETTE.RED, { 0.2, 5, 8.6 }, { x, height - 3, z - 4.5 }, { name = "Cloth" })
	cloth.signs = {
		{ face = "Right", text = "FERME DE\n{owner}" },
		{ face = "Left", text = "FERME DE\n{owner}" },
	}
end

local function coop()
	local x, z = -2, 47
	add(PALETTE.STONE, { 10, 0.6, 8 }, { x, 0.3, z })
	add(PALETTE.WHITE, { 8, 4, 6 }, { x, 2.6, z })
	for index, width in { 7, 5, 3, 1.2 } do
		add(
			if index % 2 == 0 then shade(PALETTE.RED, 5) else PALETTE.RED,
			{ 8.8, 0.7, width },
			{ x, 4.4 + index * 0.7, z }
		)
	end
	add(PALETTE.DARK, { 0.2, 2, 1.6 }, { x + 4.05, 1.6, z })
	add(PALETTE.WOOD, { 3, 0.2, 1.4 }, { x + 5, 0.8, z }, { tilt = { 0, 0, -0.45 } })
	for _, spot in { { 6, 3 }, { 7.5, -2.5 }, { 3.5, 5.2 } } do
		local chickenX, chickenZ = x + spot[1], z + spot[2]
		add(PALETTE.WHITE, { 1.2, 0.9, 0.9 }, { chickenX, 0.75, chickenZ })
		add(PALETTE.WHITE, { 0.6, 0.6, 0.6 }, { chickenX + 0.6, 1.3, chickenZ })
		add(PALETTE.APPLE, { 0.25, 0.3, 0.2 }, { chickenX + 0.6, 1.75, chickenZ })
		add(PALETTE.GOLD, { 0.3, 0.15, 0.2 }, { chickenX + 1, 1.3, chickenZ })
	end
end

local function greenhouse()
	local x, z = -20, 46
	local halfX, halfZ, height = 8, 6, 6
	add(PALETTE.STONE, { halfX * 2, 1, halfZ * 2 }, { x, 0.5, z })
	local glass = { material = "Glass", transparency = 0.55, isSmooth = true }
	for _, side in { -1, 1 } do
		add(PALETTE.GLASS, { halfX * 2, height, 0.2 }, { x, 1 + height / 2, z + side * halfZ }, glass)
		add(PALETTE.GLASS, { 0.2, height, halfZ * 2 }, { x + side * halfX, 1 + height / 2, z }, glass)
		add(PALETTE.WHITE, { halfX * 2 + 0.4, 0.4, 0.4 }, { x, 1 + height, z + side * halfZ })
		add(PALETTE.WHITE, { 0.4, 0.4, halfZ * 2 + 0.4 }, { x + side * halfX, 1 + height, z })
		for _, along in { -halfX, -halfX / 3, halfX / 3, halfX } do
			add(PALETTE.WHITE, { 0.4, height, 0.4 }, { x + along, 1 + height / 2, z + side * halfZ })
		end
	end
	for index, inset in { 1.5, 3.2, 4.8 } do
		for _, side in { -1, 1 } do
			local y = 1 + height + index * 0.9
			add(PALETTE.GLASS, { halfX * 2, 0.5, 2 }, { x, y, z + side * (halfZ - inset) }, glass)
			add(PALETTE.WHITE, { halfX * 2 + 0.2, 0.25, 0.3 }, { x, y + 0.3, z + side * (halfZ - inset + 1) })
		end
	end
	add(PALETTE.WHITE, { halfX * 2 + 0.4, 0.5, 1 }, { x, 1 + height + 3.2, z })
	for k = -2, 2 do
		for _, side in { -1, 1 } do
			local plantX, plantZ = x + k * 2.8, z + side * 2.8
			add(PALETTE.SOIL, { 2.2, 0.8, 2.2 }, { plantX, 1.4, plantZ })
			add(if k % 2 == 0 then PALETTE.LEAF else PALETTE.LEAF_LIGHT, { 1.5, 1.5, 1.5 }, { plantX, 2.5, plantZ })
		end
	end
end

local function statue()
	local x, z = 30, 40
	add(PALETTE.STONE, { 6, 3, 6 }, { x, 1.5, z })
	add(PALETTE.DARK, { 5, 0.4, 5 }, { x, 3.2, z })
	local gold = { material = "Metal", reflectance = 0.35 }
	local parts = {
		{ { 1.2, 4, 1.2 }, { 0, 5.4, -0.6 } },
		{ { 1.2, 4, 1.2 }, { 0, 5.4, 0.6 } },
		{ { 1.4, 2.6, 2.6 }, { 0, 8.6, 0 } },
		{ { 1.2, 2.6, 1.2 }, { 0, 8.6, -1.9 } },
		{ { 1.2, 2.6, 1.2 }, { 0.6, 10.2, 1.9 } },
		{ { 1.8, 1.8, 1.8 }, { 0, 10.8, 0 } },
		{ { 3.2, 0.25, 3.2 }, { 0, 11.8, 0 } },
		{ { 1.9, 1, 1.9 }, { 0, 12.4, 0 } },
		{ { 0.3, 7, 0.3 }, { 1.3, 11, 1.9 } },
	}
	for _, part in parts do
		add(PALETTE.GOLD, part[1], { x + part[2][1], part[2][2], z + part[2][3] }, gold)
	end
end

local function arch()
	local x, height, half = 58.5, 16, 20 -- encadre la porte de la clôture
	for _, side in { -1, 1 } do
		add(PALETTE.DARK, { 2, height, 2 }, { x, height / 2, side * half })
		neon(PALETTE.NEON_CYAN, { 0.2, height - 1, 0.6 }, { x + 1.05, height / 2, side * half }, 12)
	end
	local beam = add(
		PALETTE.DARK,
		{ half * 2 + 2, 3, 2 },
		{ x, height + 1.5, 0 },
		{ name = "Beam", tilt = { 0, HALF_TURN, 0 } }
	)
	beam.signs = {
		{ face = "Front", text = "🌾 FERME DE {owner} 🌾" },
		{ face = "Back", text = "🌾 FERME DE {owner} 🌾" },
	}
	neon(PALETTE.NEON_PINK, { 2.2, 0.3, half * 2 + 2 }, { x, height, 0 }, 14)
end

local function windmill()
	local x, z = -44, 46
	local y = 0
	for index, level in { { 8, 10 }, { 6.5, 10 }, { 5, 10 } } do
		local color = if index % 2 == 0 then PALETTE.RED else PALETTE.WHITE
		add(color, { level[1], level[2], level[1] }, { x, y + level[2] / 2, z })
		y += level[2]
	end
	add(PALETTE.RED, { 6, 3, 6 }, { x, y + 1.5, z })
	local hubX, hubY = x + 3.5, y - 1
	add(PALETTE.DARK, { 1.2, 2.4, 2.4 }, { hubX, hubY, z }, { name = "Hub", group = "MillBlades", isHub = true })
	add(PALETTE.WHITE, { 0.4, 24, 2.2 }, { hubX + 0.6, hubY, z }, { name = "BladeA", group = "MillBlades" })
	add(PALETTE.WHITE, { 0.4, 2.2, 24 }, { hubX + 0.6, hubY, z }, { name = "BladeB", group = "MillBlades" })
end

local BUILDERS: { [string]: () -> () } = {
	Path = path,
	BarnFloor = barnFloor,
	WallBack = wallBack,
	WallSouth = wallSouth,
	WallNorth = wallNorth,
	Facade = facade,
	Doors = doors,
	Windows = windows,
	Lanterns = lanterns,
	Flowers = flowers,
	Lamps = lamps,
	Hay = hay,
	Trees = trees,
	Well = well,
	Fountain = fountain,
	Cart = cart,
	Scarecrow = scarecrow,
	Mailbox = mailbox,
	Bench = bench,
	Garden = garden,
	Pumpkins = pumpkins,
	Pen = pen,
	Beehives = beehives,
	Stairs = stairs,
	Loft = loft,
	UpperWalls = upperWalls,
	Roof = roof,
	Cupola = cupola,
	Flag = flag,
	Coop = coop,
	Greenhouse = greenhouse,
	Statue = statue,
	Arch = arch,
	Windmill = windmill,
}

-- Liste des briques d'un élément du plan.
function FarmBlueprint.pieces(id: string): { Piece }
	local builder = BUILDERS[id]
	assert(builder, `élément inconnu : {id}`)
	current = {}
	builder()
	local pieces = current
	current = {}
	return pieces
end

-- Murs en quinconce, exposés aux tests.
function FarmBlueprint.wallPieces(spec: WallSpec): { Piece }
	current = {}
	wall(spec)
	local pieces = current
	current = {}
	return pieces
end

return FarmBlueprint
