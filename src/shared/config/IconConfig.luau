--!strict
-- Icônes du jeu (A72) : de petites sculptures en briques, montrées en 3D dans l'interface (BrickIcon) à la place
-- des emojis. Le jeu est en briques, ses icônes aussi : elles ne ressemblent à celles d'aucun autre jeu.
-- Chaque icône est une liste de pièces dans son repère (origine au sol, haut = +Y, face tournée vers -Z), dans un
-- cube d'environ 4 studs de côté. `rot` : rotation en degrés (X, Y, Z). L'axe d'un cylindre Roblox est son axe X.
local Freeze = require("../util/Freeze")

export type Piece = {
	size: { number },
	offset: { number },
	color: { number },
	rot: { number }?,
	shape: string?, -- « Ball », « Cylinder », « Wedge » ; bloc par défaut
	material: string?, -- « Neon », « Glass » ; plastique lisse par défaut
	studs: boolean?, -- tenons sur le dessus
}

local GOLD, DARK_GOLD = { 245, 205, 48 }, { 214, 160, 30 }
local RED, DARK_RED = { 220, 40, 40 }, { 160, 25, 30 }
local BLUE, CYAN = { 40, 110, 200 }, { 90, 200, 255 }
local GREEN, DARK_GREEN = { 75, 170, 80 }, { 40, 127, 71 }
local BROWN, DARK_BROWN = { 150, 105, 70 }, { 105, 70, 45 }
local WHITE, GREY, DARK = { 248, 248, 248 }, { 150, 152, 160 }, { 27, 42, 53 }
local PURPLE, PINK, ORANGE = { 150, 90, 220 }, { 255, 150, 200 }, { 240, 140, 40 }
local CREAM, TAN = { 250, 238, 205 }, { 214, 178, 124 }
local UP, FACING = { 0, 0, 90 }, { 0, 90, 0 } -- cylindre debout ; disque tourné vers la caméra

local function merge(...: { Piece }): { Piece }
	local all: { Piece } = {}
	for _, list in { ... } do
		for _, piece in list do
			table.insert(all, piece)
		end
	end
	return all
end

-- Trois épis sur leur tige, en éventail. Sert au blé, au maïs doré et au blé diamant.
local function stalks(ear: { number }, stem: { number }): { Piece }
	local pieces: { Piece } = {}
	for index, lean in { -14, 0, 14 } do
		local x = (index - 2) * 1.1
		table.insert(
			pieces,
			{ size = { 0.3, 2.2, 0.3 }, offset = { x * 0.6, 1.1, 0 }, color = stem, rot = { 0, 0, -lean } }
		)
		for level = 0, 2 do
			table.insert(pieces, {
				size = { 0.8 - level * 0.12, 0.6, 0.8 - level * 0.12 },
				offset = { x * (0.75 + level * 0.12), 2.3 + level * 0.6, 0 },
				color = ear,
				rot = { 0, 0, -lean },
			})
		end
	end
	return pieces
end

-- Étoile à huit branches tournée vers la caméra : deux carrés décalés d'un huitième de tour.
local function burst(outer: { number }, inner: { number }, y: number): { Piece }
	return {
		{ size = { 3, 3, 0.7 }, offset = { 0, y, 0 }, color = outer },
		{ size = { 3, 3, 0.7 }, offset = { 0, y, 0 }, color = outer, rot = { 0, 0, 45 } },
		{ size = { 1.7, 1.7, 0.9 }, offset = { 0, y, 0 }, color = inner, rot = { 0, 0, 22 } },
	}
end

-- Moissonneuse vue de profil (paliers 5 à 7) : caisse, cabine, barre de coupe à l'avant.
local function combine(body: { number }, accent: { number }, glow: { number }?): { Piece }
	local pieces: { Piece } = {
		{ size = { 2.6, 1.5, 1.7 }, offset = { 0.3, 1.5, 0 }, color = body, studs = true },
		{ size = { 1.2, 1.1, 1.5 }, offset = { -0.4, 2.8, 0 }, color = CYAN, material = "Glass" },
		{ size = { 1.3, 0.25, 1.6 }, offset = { -0.4, 3.45, 0 }, color = body },
		{ size = { 0.7, 0.9, 3.4 }, offset = { -1.7, 0.75, 0 }, color = accent },
		{ size = { 0.3, 1.5, 0.3 }, offset = { 1.3, 2.9, 0.4 }, color = DARK, rot = { 0, 0, -25 } },
		{ size = { 0.55, 1.7, 1.7 }, offset = { 0.9, 0.85, 0.95 }, color = DARK, shape = "Cylinder", rot = FACING },
		{ size = { 0.55, 1.7, 1.7 }, offset = { 0.9, 0.85, -0.95 }, color = DARK, shape = "Cylinder", rot = FACING },
		{ size = { 0.45, 1, 1 }, offset = { -0.7, 0.5, 0.95 }, color = DARK, shape = "Cylinder", rot = FACING },
		{ size = { 0.45, 1, 1 }, offset = { -0.7, 0.5, -0.95 }, color = DARK, shape = "Cylinder", rot = FACING },
	}
	if glow then
		table.insert(pieces, { size = { 2.7, 0.2, 1.8 }, offset = { 0.3, 0.85, 0 }, color = glow, material = "Neon" })
		table.insert(pieces, { size = { 0.2, 0.3, 3.5 }, offset = { -2.05, 0.9, 0 }, color = glow, material = "Neon" })
	end
	return pieces
end

local ICONS: { [string]: { Piece } } = {
	-- Monnaies et progression
	coin = {
		{ size = { 0.7, 3, 3 }, offset = { -0.3, 0.35, 0 }, color = DARK_GOLD, shape = "Cylinder", rot = UP },
		{ size = { 0.7, 3, 3 }, offset = { -0.1, 1.05, 0.1 }, color = GOLD, shape = "Cylinder", rot = UP },
		{ size = { 0.7, 3, 3 }, offset = { -0.35, 1.75, -0.05 }, color = DARK_GOLD, shape = "Cylinder", rot = UP },
		{ size = { 0.7, 3, 3 }, offset = { -0.2, 2.45, 0.05 }, color = GOLD, shape = "Cylinder", rot = UP },
		{ size = { 0.6, 2.4, 2.4 }, offset = { 1.9, 1.2, -1 }, color = GOLD, shape = "Cylinder", rot = { 0, 70, 0 } },
	},
	gem = {
		{ size = { 1.7, 0.5, 1.7 }, offset = { 0, 3.55, 0 }, color = { 190, 240, 255 } },
		{ size = { 2.9, 0.8, 2.9 }, offset = { 0, 2.9, 0 }, color = CYAN },
		{ size = { 2.2, 0.75, 2.2 }, offset = { 0, 2.12, 0 }, color = { 60, 170, 240 } },
		{ size = { 1.5, 0.75, 1.5 }, offset = { 0, 1.37, 0 }, color = BLUE },
		{ size = { 0.8, 0.75, 0.8 }, offset = { 0, 0.62, 0 }, color = { 30, 80, 170 } },
		{ size = { 0.7, 0.2, 0.7 }, offset = { -0.5, 3.85, -0.5 }, color = WHITE },
	},
	star = merge(burst(GOLD, { 255, 240, 150 }, 2), {
		{ size = { 0.8, 0.8, 1 }, offset = { 0, 2, 0 }, color = WHITE, rot = { 0, 0, 45 } },
	}),
	target = {
		{ size = { 0.4, 3.6, 3.6 }, offset = { 0, 2, 0 }, color = WHITE, shape = "Cylinder", rot = FACING },
		{ size = { 0.5, 2.7, 2.7 }, offset = { 0, 2, 0 }, color = RED, shape = "Cylinder", rot = FACING },
		{ size = { 0.6, 1.8, 1.8 }, offset = { 0, 2, 0 }, color = WHITE, shape = "Cylinder", rot = FACING },
		{ size = { 0.7, 0.9, 0.9 }, offset = { 0, 2, 0 }, color = RED, shape = "Cylinder", rot = FACING },
	},
	friends = {
		{ size = { 1.5, 1.3, 1 }, offset = { -0.9, 0.65, 0 }, color = BLUE },
		{ size = { 1.2, 1.2, 1.2 }, offset = { -0.9, 1.9, 0 }, color = GOLD },
		{ size = { 0.2, 0.2, 0.1 }, offset = { -1.15, 2, -0.62 }, color = DARK },
		{ size = { 0.2, 0.2, 0.1 }, offset = { -0.65, 2, -0.62 }, color = DARK },
		{ size = { 1.5, 1.6, 1 }, offset = { 0.9, 0.8, 0.4 }, color = RED },
		{ size = { 1.2, 1.2, 1.2 }, offset = { 0.9, 2.2, 0.4 }, color = GOLD },
		{ size = { 0.2, 0.2, 0.1 }, offset = { 0.65, 2.3, -0.22 }, color = DARK },
		{ size = { 0.2, 0.2, 0.1 }, offset = { 1.15, 2.3, -0.22 }, color = DARK },
	},
	trophy = {
		{ size = { 2, 0.5, 2 }, offset = { 0, 0.25, 0 }, color = DARK },
		{ size = { 0.7, 0.9, 0.7 }, offset = { 0, 0.95, 0 }, color = DARK_GOLD },
		{ size = { 2.2, 1.9, 2.2 }, offset = { 0, 2.35, 0 }, color = GOLD, studs = true },
		{ size = { 0.5, 1, 0.5 }, offset = { -1.4, 2.6, 0 }, color = DARK_GOLD },
		{ size = { 0.5, 1, 0.5 }, offset = { 1.4, 2.6, 0 }, color = DARK_GOLD },
		{ size = { 0.9, 0.9, 0.15 }, offset = { 0, 2.4, -1.12 }, color = WHITE, rot = { 0, 0, 45 } },
	},

	-- Boutons du HUD
	shop = {
		{ size = { 3.6, 1.4, 1.6 }, offset = { 0, 0.7, 0 }, color = BROWN },
		{ size = { 3.8, 0.25, 1.9 }, offset = { 0, 1.5, 0 }, color = DARK_BROWN },
		{ size = { 0.3, 1.9, 0.3 }, offset = { -1.6, 2.5, 0.6 }, color = DARK_BROWN },
		{ size = { 0.3, 1.9, 0.3 }, offset = { 1.6, 2.5, 0.6 }, color = DARK_BROWN },
		{ size = { 1, 0.5, 2.2 }, offset = { -1.5, 3.5, 0 }, color = RED, rot = { -18, 0, 0 } },
		{ size = { 1, 0.5, 2.2 }, offset = { -0.5, 3.5, 0 }, color = WHITE, rot = { -18, 0, 0 } },
		{ size = { 1, 0.5, 2.2 }, offset = { 0.5, 3.5, 0 }, color = RED, rot = { -18, 0, 0 } },
		{ size = { 1, 0.5, 2.2 }, offset = { 1.5, 3.5, 0 }, color = WHITE, rot = { -18, 0, 0 } },
		{ size = { 0.4, 0.9, 0.9 }, offset = { -0.8, 2.05, -0.2 }, color = GOLD, shape = "Cylinder", rot = FACING },
		{ size = { 0.8, 0.8, 0.8 }, offset = { 0.6, 2, -0.1 }, color = CYAN, rot = { 0, 30, 0 } },
	},
	gift = {
		{ size = { 3, 2.3, 3 }, offset = { 0, 1.15, 0 }, color = RED },
		{ size = { 3.3, 0.7, 3.3 }, offset = { 0, 2.65, 0 }, color = DARK_RED },
		{ size = { 0.7, 3.05, 3.4 }, offset = { 0, 1.5, 0 }, color = GOLD },
		{ size = { 3.4, 3.05, 0.7 }, offset = { 0, 1.5, 0 }, color = GOLD },
		{ size = { 1.1, 0.8, 0.7 }, offset = { -0.6, 3.4, 0 }, color = GOLD, rot = { 0, 0, 25 } },
		{ size = { 1.1, 0.8, 0.7 }, offset = { 0.6, 3.4, 0 }, color = GOLD, rot = { 0, 0, -25 } },
	},
	paw = {
		{ size = { 0.6, 2.4, 2.4 }, offset = { 0, 1.3, 0 }, color = WHITE, shape = "Cylinder", rot = FACING },
		{ size = { 0.6, 1.05, 1.05 }, offset = { -1.5, 2.55, 0 }, color = WHITE, shape = "Cylinder", rot = FACING },
		{ size = { 0.6, 1.1, 1.1 }, offset = { -0.55, 3.35, 0 }, color = WHITE, shape = "Cylinder", rot = FACING },
		{ size = { 0.6, 1.1, 1.1 }, offset = { 0.55, 3.35, 0 }, color = WHITE, shape = "Cylinder", rot = FACING },
		{ size = { 0.6, 1.05, 1.05 }, offset = { 1.5, 2.55, 0 }, color = WHITE, shape = "Cylinder", rot = FACING },
		{ size = { 0.7, 1.5, 1.5 }, offset = { 0, 1.2, 0 }, color = PINK, shape = "Cylinder", rot = FACING },
		{ size = { 0.7, 0.55, 0.55 }, offset = { -1.5, 2.55, 0 }, color = PINK, shape = "Cylinder", rot = FACING },
		{ size = { 0.7, 0.6, 0.6 }, offset = { -0.55, 3.35, 0 }, color = PINK, shape = "Cylinder", rot = FACING },
		{ size = { 0.7, 0.6, 0.6 }, offset = { 0.55, 3.35, 0 }, color = PINK, shape = "Cylinder", rot = FACING },
		{ size = { 0.7, 0.55, 0.55 }, offset = { 1.5, 2.55, 0 }, color = PINK, shape = "Cylinder", rot = FACING },
	},
	guide = {
		{ size = { 0.5, 3.6, 0.5 }, offset = { -0.6, 1.8, 0 }, color = BROWN },
		{ size = { 2.6, 1.1, 0.5 }, offset = { 0.2, 2.9, -0.3 }, color = CYAN },
		{ size = { 1.05, 1.05, 0.5 }, offset = { 1.5, 2.9, -0.3 }, color = CYAN, rot = { 0, 0, 45 } },
		{ size = { 1.4, 0.4, 1.4 }, offset = { -0.6, 0.2, 0 }, color = DARK_GREEN },
	},
	guideOff = {
		{ size = { 0.5, 3.6, 0.5 }, offset = { -0.6, 1.8, 0 }, color = BROWN },
		{ size = { 2.6, 1.1, 0.5 }, offset = { 0.2, 2.9, -0.3 }, color = GREY },
		{ size = { 1.05, 1.05, 0.5 }, offset = { 1.5, 2.9, -0.3 }, color = GREY, rot = { 0, 0, 45 } },
		{ size = { 3.6, 0.5, 0.3 }, offset = { 0.3, 2.9, -0.7 }, color = RED, rot = { 0, 0, 40 } },
		{ size = { 3.6, 0.5, 0.3 }, offset = { 0.3, 2.9, -0.7 }, color = RED, rot = { 0, 0, -40 } },
	},

	-- Récolte
	wheat = stalks(GOLD, GREEN),
	corn = stalks({ 255, 170, 40 }, DARK_GREEN),
	diamondWheat = stalks(CYAN, { 120, 110, 200 }),
	lock = {
		{ size = { 2.6, 2.1, 1.1 }, offset = { 0, 1.05, 0 }, color = GOLD },
		{ size = { 0.5, 1.4, 0.5 }, offset = { -0.8, 2.7, 0 }, color = GREY },
		{ size = { 0.5, 1.4, 0.5 }, offset = { 0.8, 2.7, 0 }, color = GREY },
		{ size = { 2.1, 0.5, 0.5 }, offset = { 0, 3.5, 0 }, color = GREY },
		{ size = { 0.6, 0.6, 0.2 }, offset = { 0, 1.25, -0.6 }, color = DARK, shape = "Cylinder", rot = FACING },
		{ size = { 0.3, 0.7, 0.15 }, offset = { 0, 0.8, -0.6 }, color = DARK },
	},
	home = {
		{ size = { 3, 1.9, 2.6 }, offset = { 0, 0.95, 0 }, color = CREAM },
		{ size = { 3.6, 0.6, 3 }, offset = { 0, 2.2, 0 }, color = RED },
		{ size = { 2.6, 0.6, 3 }, offset = { 0, 2.8, 0 }, color = RED },
		{ size = { 1.5, 0.6, 3 }, offset = { 0, 3.4, 0 }, color = DARK_RED },
		{ size = { 0.8, 1.3, 0.15 }, offset = { -0.6, 0.65, -1.32 }, color = BROWN },
		{ size = { 0.8, 0.7, 0.15 }, offset = { 0.8, 1.1, -1.32 }, color = CYAN },
	},
	unload = {
		{ size = { 3.4, 0.9, 2.4 }, offset = { 0, 0.45, 0 }, color = BROWN },
		{ size = { 2.8, 0.3, 1.8 }, offset = { 0, 0.95, 0 }, color = DARK },
		{ size = { 1, 1.5, 0.8 }, offset = { 0, 3.2, 0 }, color = GREEN },
		{ size = { 1.7, 1.7, 0.8 }, offset = { 0, 2.2, 0 }, color = GREEN, rot = { 0, 0, 45 } },
	},

	-- Objets de sabotage
	mud = {
		{ size = { 0.5, 3.6, 3.2 }, offset = { 0, 0.25, 0 }, color = DARK_BROWN, shape = "Cylinder", rot = UP },
		{ size = { 0.5, 2.2, 2.4 }, offset = { 0.5, 0.6, 0.2 }, color = BROWN, shape = "Cylinder", rot = UP },
		{ size = { 0.7, 0.7, 0.7 }, offset = { -1, 1.5, -0.4 }, color = BROWN, shape = "Ball" },
		{ size = { 0.5, 0.5, 0.5 }, offset = { 0.9, 2.1, 0 }, color = DARK_BROWN, shape = "Ball" },
		{ size = { 0.4, 0.4, 0.4 }, offset = { -0.2, 2.6, 0.3 }, color = BROWN, shape = "Ball" },
	},
	glove = {
		{ size = { 2.7, 2.7, 2.7 }, offset = { 0.1, 2.7, 0 }, color = RED, shape = "Ball" },
		{ size = { 1.4, 1.4, 1.4 }, offset = { -1.25, 2.2, -0.5 }, color = DARK_RED, shape = "Ball" },
		{ size = { 1.2, 1.9, 1.9 }, offset = { 0.1, 0.9, 0 }, color = WHITE, shape = "Cylinder", rot = UP },
		{ size = { 0.35, 2, 2 }, offset = { 0.1, 1.5, 0 }, color = DARK_RED, shape = "Cylinder", rot = UP },
		{ size = { 0.9, 0.3, 0.3 }, offset = { 0.5, 3.3, -1.1 }, color = { 255, 150, 150 }, rot = { 0, 0, 20 } },
	},
	dynamite = {
		{ size = { 2.8, 0.95, 0.95 }, offset = { -0.95, 1.4, 0 }, color = RED, shape = "Cylinder", rot = UP },
		{ size = { 2.8, 0.95, 0.95 }, offset = { 0, 1.4, -0.3 }, color = RED, shape = "Cylinder", rot = UP },
		{ size = { 2.8, 0.95, 0.95 }, offset = { 0.95, 1.4, 0 }, color = RED, shape = "Cylinder", rot = UP },
		{ size = { 3.1, 0.6, 1.5 }, offset = { 0, 1.4, -0.1 }, color = DARK },
		{ size = { 0.18, 1, 0.18 }, offset = { 0.2, 3.2, -0.3 }, color = TAN, rot = { 0, 0, -20 } },
		{
			size = { 0.55, 0.55, 0.55 },
			offset = { 0.45, 3.8, -0.3 },
			color = ORANGE,
			material = "Neon",
			rot = { 30, 20, 45 },
		},
	},
	rocket = {
		{ size = { 2.4, 1.3, 1.3 }, offset = { 0, 2.1, 0 }, color = WHITE, shape = "Cylinder", rot = { 0, 0, 55 } },
		{ size = { 1.1, 1.1, 1.1 }, offset = { 0.83, 3.28, 0 }, color = RED, rot = { 0, 0, 10 } },
		{ size = { 0.5, 0.6, 0.6 }, offset = { 0.25, 2.45, -0.62 }, color = CYAN, shape = "Cylinder", rot = FACING },
		{ size = { 0.4, 1.2, 1.9 }, offset = { -0.7, 1.1, 0 }, color = RED, rot = { 0, 0, 55 } },
		{ size = { 0.9, 0.9, 0.9 }, offset = { -1.05, 0.6, 0 }, color = ORANGE, material = "Neon", rot = { 0, 0, 10 } },
		{
			size = { 0.55, 0.55, 0.55 },
			offset = { -1.55, -0.1, 0 },
			color = GOLD,
			material = "Neon",
			rot = { 0, 0, 10 },
		},
	},
	boom = merge(burst(ORANGE, GOLD, 2), {
		{ size = { 0.9, 0.9, 1.1 }, offset = { 0, 2, 0 }, color = WHITE, rot = { 0, 0, 45 } },
	}),

	-- Usine
	conveyor = {
		{ size = { 3.8, 0.5, 1.8 }, offset = { 0, 0.9, 0 }, color = DARK },
		{ size = { 1.8, 0.7, 0.7 }, offset = { -1.4, 0.45, 0 }, color = GREY, shape = "Cylinder", rot = FACING },
		{ size = { 1.8, 0.7, 0.7 }, offset = { 0, 0.45, 0 }, color = GREY, shape = "Cylinder", rot = FACING },
		{ size = { 1.8, 0.7, 0.7 }, offset = { 1.4, 0.45, 0 }, color = GREY, shape = "Cylinder", rot = FACING },
		{ size = { 0.9, 0.9, 0.9 }, offset = { -1, 1.6, 0 }, color = GOLD, studs = true },
		{ size = { 0.9, 0.9, 0.9 }, offset = { 0.6, 1.6, 0.1 }, color = GOLD, studs = true },
	},
	silo = {
		{ size = { 2.8, 2.3, 2.3 }, offset = { 0, 1.4, 0 }, color = WHITE, shape = "Cylinder", rot = UP },
		{ size = { 2.3, 2.3, 2.3 }, offset = { 0, 2.8, 0 }, color = RED, shape = "Ball" },
		{ size = { 0.25, 2.6, 0.15 }, offset = { -0.5, 1.4, -1.15 }, color = DARK },
		{ size = { 0.25, 2.6, 0.15 }, offset = { 0, 1.4, -1.2 }, color = DARK },
		{ size = { 0.5, 0.3, 2.5 }, offset = { 0, 0.3, 0 }, color = GREY, shape = "Cylinder", rot = UP },
	},
	mill = {
		{ size = { 2, 1.6, 2 }, offset = { 0, 0.8, 0 }, color = WHITE },
		{ size = { 1.6, 1.4, 1.6 }, offset = { 0, 2.3, 0 }, color = CREAM },
		{ size = { 2, 0.6, 2 }, offset = { 0, 3.3, 0 }, color = RED },
		{ size = { 0.5, 3.8, 0.2 }, offset = { 0, 2.4, -1.1 }, color = BROWN, rot = { 0, 0, 45 } },
		{ size = { 0.5, 3.8, 0.2 }, offset = { 0, 2.4, -1.1 }, color = BROWN, rot = { 0, 0, -45 } },
		{ size = { 0.5, 0.5, 0.4 }, offset = { 0, 2.4, -1.2 }, color = DARK },
	},
	oven = {
		{ size = { 3, 2.3, 2.2 }, offset = { 0, 1.15, 0 }, color = { 190, 110, 70 } },
		{ size = { 3.3, 0.5, 2.5 }, offset = { 0, 2.55, 0 }, color = DARK_BROWN },
		{ size = { 1.8, 1.2, 0.2 }, offset = { 0, 1, -1.05 }, color = DARK },
		{ size = { 1.4, 0.6, 0.25 }, offset = { 0, 0.7, -1.08 }, color = ORANGE, material = "Neon" },
		{ size = { 0.7, 1.3, 0.7 }, offset = { 0.9, 3.4, 0.5 }, color = DARK_BROWN },
		{ size = { 1.6, 0.7, 0.9 }, offset = { -0.5, 3.15, -0.2 }, color = TAN },
	},
	factory = {
		{ size = { 3.6, 1.8, 2.2 }, offset = { 0, 0.9, 0 }, color = GOLD },
		{ size = { 1.2, 0.7, 2.2 }, offset = { -1.2, 2.15, 0 }, color = DARK_GOLD, rot = { 0, 0, 20 } },
		{ size = { 1.2, 0.7, 2.2 }, offset = { 0, 2.15, 0 }, color = DARK_GOLD, rot = { 0, 0, 20 } },
		{ size = { 0.8, 2.6, 0.8 }, offset = { 1.3, 3.1, 0.3 }, color = DARK },
		{ size = { 0.9, 0.35, 0.9 }, offset = { 1.3, 4.2, 0.3 }, color = RED },
		{ size = { 0.6, 0.6, 0.15 }, offset = { -1, 1, -1.12 }, color = CYAN },
		{ size = { 0.6, 0.6, 0.15 }, offset = { 0, 1, -1.12 }, color = CYAN },
		{ size = { 0.6, 0.6, 0.15 }, offset = { 1, 1, -1.12 }, color = CYAN },
	},
	dryer = {
		{ size = { 2.8, 2.8, 2.2 }, offset = { 0, 1.4, 0 }, color = { 90, 150, 200 } },
		{ size = { 0.3, 2, 2 }, offset = { 0, 1.5, -1.1 }, color = GREY, shape = "Cylinder", rot = FACING },
		{ size = { 0.4, 1.7, 0.4 }, offset = { 0, 1.5, -1.25 }, color = WHITE, rot = { 0, 0, 30 } },
		{ size = { 0.4, 1.7, 0.4 }, offset = { 0, 1.5, -1.25 }, color = WHITE, rot = { 0, 0, -60 } },
		{ size = { 3, 0.4, 2.4 }, offset = { 0, 3, 0 }, color = DARK },
	},
	press = {
		{ size = { 3.2, 0.8, 2.2 }, offset = { 0, 0.4, 0 }, color = DARK },
		{ size = { 0.5, 2.6, 0.5 }, offset = { -1.2, 2.1, 0 }, color = GREY },
		{ size = { 0.5, 2.6, 0.5 }, offset = { 1.2, 2.1, 0 }, color = GREY },
		{ size = { 3.2, 0.7, 1.4 }, offset = { 0, 3.6, 0 }, color = { 200, 90, 60 } },
		{ size = { 1.6, 0.9, 1.4 }, offset = { 0, 2.6, 0 }, color = { 200, 90, 60 } },
		{ size = { 1.8, 0.4, 1.5 }, offset = { 0, 1.95, 0 }, color = GREY },
		{ size = { 1.2, 0.35, 1 }, offset = { 0, 1, 0 }, color = GOLD },
	},
	box = {
		{ size = { 3, 2.3, 3 }, offset = { 0, 1.15, 0 }, color = TAN },
		{ size = { 0.7, 2.35, 3.05 }, offset = { 0, 1.15, 0 }, color = CREAM },
		{ size = { 1.5, 0.25, 3 }, offset = { -1.2, 2.7, 0 }, color = TAN, rot = { 0, 0, 35 } },
		{ size = { 1.5, 0.25, 3 }, offset = { 1.2, 2.7, 0 }, color = TAN, rot = { 0, 0, -35 } },
		{ size = { 1, 0.9, 1 }, offset = { 0, 2.6, 0 }, color = GOLD, studs = true },
	},
	build = {
		{ size = { 1.9, 0.9, 1.1 }, offset = { -1, 0.45, 0 }, color = RED, studs = true },
		{ size = { 1.9, 0.9, 1.1 }, offset = { 1, 0.45, 0 }, color = DARK_RED, studs = true },
		{ size = { 1.9, 0.9, 1.1 }, offset = { 0, 1.35, 0 }, color = RED, studs = true },
		{ size = { 0.9, 0.9, 1.1 }, offset = { -1.5, 1.35, 0 }, color = DARK_RED, studs = true },
		{ size = { 1.9, 0.9, 1.1 }, offset = { -1, 2.25, 0 }, color = DARK_RED, studs = true },
		{ size = { 1.9, 0.9, 1.1 }, offset = { 0.9, 3.4, -0.2 }, color = GOLD, rot = { 0, 15, -18 }, studs = true },
	},

	-- Ferme
	tree = {
		{ size = { 0.8, 1.8, 0.8 }, offset = { 0, 0.9, 0 }, color = DARK_BROWN },
		{ size = { 2.6, 2.2, 2.6 }, offset = { 0, 2.7, 0 }, color = GREEN },
		{ size = { 3.4, 1.2, 1.8 }, offset = { 0, 2.6, 0 }, color = DARK_GREEN },
		{ size = { 1.6, 0.8, 1.6 }, offset = { 0, 4.1, 0 }, color = DARK_GREEN },
		{ size = { 0.5, 0.5, 0.5 }, offset = { -0.9, 2.3, -1.3 }, color = RED },
		{ size = { 0.5, 0.5, 0.5 }, offset = { 0.8, 3.2, -1.3 }, color = RED },
	},
	flower = {
		{ size = { 0.35, 2.2, 0.35 }, offset = { 0, 1.1, 0 }, color = GREEN },
		{ size = { 1, 0.3, 0.5 }, offset = { 0.5, 1, 0 }, color = DARK_GREEN, rot = { 0, 0, 30 } },
		{ size = { 1, 1, 0.5 }, offset = { 0, 3.6, 0 }, color = PINK },
		{ size = { 1, 1, 0.5 }, offset = { -0.9, 2.9, 0 }, color = PINK },
		{ size = { 1, 1, 0.5 }, offset = { 0.9, 2.9, 0 }, color = PINK },
		{ size = { 1, 1, 0.5 }, offset = { 0, 2.2, 0 }, color = PINK },
		{ size = { 0.9, 0.9, 0.7 }, offset = { 0, 2.9, 0 }, color = GOLD },
	},
	lamp = {
		{ size = { 1.4, 0.4, 1.4 }, offset = { 0, 0.2, 0 }, color = DARK },
		{ size = { 0.4, 2.6, 0.4 }, offset = { 0, 1.7, 0 }, color = DARK },
		{ size = { 1.3, 1.3, 1.3 }, offset = { 0, 3.5, 0 }, color = { 255, 225, 130 }, material = "Neon" },
		{ size = { 1.6, 0.3, 1.6 }, offset = { 0, 4.3, 0 }, color = DARK },
	},
	hay = {
		{ size = { 3, 2.4, 2.4 }, offset = { 0, 1.2, 0 }, color = GOLD, shape = "Cylinder" },
		{ size = { 0.4, 2.5, 2.5 }, offset = { -0.7, 1.2, 0 }, color = DARK_GOLD, shape = "Cylinder" },
		{ size = { 0.4, 2.5, 2.5 }, offset = { 0.7, 1.2, 0 }, color = DARK_GOLD, shape = "Cylinder" },
	},
	pumpkin = {
		{ size = { 2.6, 2.6, 2.6 }, offset = { 0, 1.3, 0 }, color = ORANGE, shape = "Ball" },
		{ size = { 3, 2.1, 2.1 }, offset = { 0, 1.3, 0 }, color = { 225, 120, 30 }, shape = "Ball" },
		{ size = { 0.45, 0.8, 0.45 }, offset = { 0.1, 2.8, 0 }, color = DARK_GREEN, rot = { 0, 0, -15 } },
	},
	flag = {
		{ size = { 0.3, 4, 0.3 }, offset = { -1.2, 2, 0 }, color = GREY },
		{ size = { 2.4, 1.5, 0.2 }, offset = { 0.1, 3.2, 0 }, color = RED },
		{ size = { 1.2, 0.75, 0.25 }, offset = { -0.5, 3.57, 0 }, color = GOLD },
		{ size = { 1.2, 0.4, 1.2 }, offset = { -1.2, 0.2, 0 }, color = DARK },
	},
	well = {
		{ size = { 1.3, 2.8, 2.8 }, offset = { 0, 0.65, 0 }, color = GREY, shape = "Cylinder", rot = UP },
		{ size = { 0.3, 2.2, 2.2 }, offset = { 0, 1.25, 0 }, color = CYAN, shape = "Cylinder", rot = UP },
		{ size = { 0.3, 2.4, 0.3 }, offset = { -1.2, 2.2, 0 }, color = BROWN },
		{ size = { 0.3, 2.4, 0.3 }, offset = { 1.2, 2.2, 0 }, color = BROWN },
		{ size = { 3.2, 0.5, 2 }, offset = { 0, 3.6, 0 }, color = RED },
	},
	pig = {
		{ size = { 2.6, 2.2, 2.2 }, offset = { 0, 1.6, 0 }, color = PINK },
		{ size = { 1.2, 0.8, 0.4 }, offset = { 0, 1.3, -1.25 }, color = { 240, 120, 155 } },
		{ size = { 0.2, 0.25, 0.1 }, offset = { -0.25, 1.3, -1.48 }, color = DARK },
		{ size = { 0.2, 0.25, 0.1 }, offset = { 0.25, 1.3, -1.48 }, color = DARK },
		{ size = { 0.3, 0.3, 0.1 }, offset = { -0.7, 2.1, -1.12 }, color = DARK },
		{ size = { 0.3, 0.3, 0.1 }, offset = { 0.7, 2.1, -1.12 }, color = DARK },
		{ size = { 0.7, 0.6, 0.3 }, offset = { -0.9, 2.9, -0.5 }, color = { 240, 120, 155 } },
		{ size = { 0.7, 0.6, 0.3 }, offset = { 0.9, 2.9, -0.5 }, color = { 240, 120, 155 } },
	},

	-- Outils et engins (Garage)
	hand = {
		{ size = { 2, 2, 0.9 }, offset = { 0, 1.3, 0 }, color = GOLD },
		{ size = { 0.45, 1.3, 0.9 }, offset = { -0.78, 2.9, 0 }, color = GOLD },
		{ size = { 0.45, 1.6, 0.9 }, offset = { -0.26, 3.05, 0 }, color = GOLD },
		{ size = { 0.45, 1.5, 0.9 }, offset = { 0.26, 3, 0 }, color = GOLD },
		{ size = { 0.45, 1.2, 0.9 }, offset = { 0.78, 2.85, 0 }, color = GOLD },
		{ size = { 0.5, 1.2, 0.9 }, offset = { -1.35, 1.6, 0 }, color = GOLD, rot = { 0, 0, 35 } },
		{ size = { 1.6, 0.6, 1 }, offset = { 0, 0.3, 0 }, color = WHITE },
	},
	scythe = {
		{ size = { 0.5, 4.6, 0.5 }, offset = { 0.5, 2.2, 0 }, color = BROWN, rot = { 0, 0, -18 } },
		{ size = { 2.6, 0.9, 0.35 }, offset = { -0.9, 4, 0 }, color = GREY, rot = { 0, 0, 10 } },
		{ size = { 1.5, 0.7, 0.35 }, offset = { -2.5, 3.4, 0 }, color = GREY, rot = { 0, 0, 38 } },
		{ size = { 0.9, 0.45, 0.35 }, offset = { -3.3, 2.6, 0 }, color = WHITE, rot = { 0, 0, 60 } },
		{ size = { 1, 0.35, 0.6 }, offset = { 0.95, 2, 0 }, color = DARK_BROWN, rot = { 0, 0, -18 } },
	},
	mower = {
		{ size = { 2.6, 0.9, 2 }, offset = { -0.2, 0.9, 0 }, color = RED, studs = true },
		{ size = { 1.1, 0.8, 1.1 }, offset = { -0.4, 1.75, 0 }, color = DARK },
		{ size = { 0.3, 2.6, 0.3 }, offset = { 1.5, 2.1, 0.7 }, color = GREY, rot = { 0, 0, -30 } },
		{ size = { 0.3, 2.6, 0.3 }, offset = { 1.5, 2.1, -0.7 }, color = GREY, rot = { 0, 0, -30 } },
		{ size = { 0.3, 0.3, 1.8 }, offset = { 2.15, 3.2, 0 }, color = DARK },
		{ size = { 0.4, 0.9, 0.9 }, offset = { -1.1, 0.45, 1.05 }, color = DARK, shape = "Cylinder", rot = FACING },
		{ size = { 0.4, 0.9, 0.9 }, offset = { -1.1, 0.45, -1.05 }, color = DARK, shape = "Cylinder", rot = FACING },
		{ size = { 0.4, 0.9, 0.9 }, offset = { 0.8, 0.45, 1.05 }, color = DARK, shape = "Cylinder", rot = FACING },
		{ size = { 0.4, 0.9, 0.9 }, offset = { 0.8, 0.45, -1.05 }, color = DARK, shape = "Cylinder", rot = FACING },
	},
	tractor = {
		{ size = { 2.2, 1, 1.5 }, offset = { -0.6, 1.3, 0 }, color = GREEN, studs = true },
		{ size = { 1.4, 1.3, 1.5 }, offset = { 0.9, 2.3, 0 }, color = CYAN, material = "Glass" },
		{ size = { 1.6, 0.25, 1.7 }, offset = { 0.9, 3.05, 0 }, color = GOLD },
		{ size = { 1.5, 0.9, 1.5 }, offset = { 0.9, 1.3, 0 }, color = GREEN },
		{ size = { 0.25, 1, 0.25 }, offset = { -1.2, 2.3, 0.35 }, color = DARK },
		{ size = { 0.55, 2, 2 }, offset = { 0.95, 1, 1 }, color = DARK, shape = "Cylinder", rot = FACING },
		{ size = { 0.55, 2, 2 }, offset = { 0.95, 1, -1 }, color = DARK, shape = "Cylinder", rot = FACING },
		{ size = { 0.6, 0.9, 0.9 }, offset = { 0.95, 1, 1.02 }, color = GOLD, shape = "Cylinder", rot = FACING },
		{ size = { 0.6, 0.9, 0.9 }, offset = { 0.95, 1, -1.02 }, color = GOLD, shape = "Cylinder", rot = FACING },
		{ size = { 0.45, 1.1, 1.1 }, offset = { -1.25, 0.55, 0.9 }, color = DARK, shape = "Cylinder", rot = FACING },
		{ size = { 0.45, 1.1, 1.1 }, offset = { -1.25, 0.55, -0.9 }, color = DARK, shape = "Cylinder", rot = FACING },
	},
	combineRed = combine(RED, GOLD, nil),
	combineGold = combine(GOLD, DARK, nil),
	combineCyber = combine(DARK, PURPLE, { 0, 230, 255 }),

	-- Boutique
	trailer = {
		{ size = { 3.4, 0.4, 2 }, offset = { 0, 1, 0 }, color = DARK },
		{ size = { 3.4, 1.3, 0.3 }, offset = { 0, 1.8, -1 }, color = BLUE },
		{ size = { 3.4, 1.3, 0.3 }, offset = { 0, 1.8, 1 }, color = BLUE },
		{ size = { 0.3, 1.3, 2 }, offset = { 1.6, 1.8, 0 }, color = BLUE },
		{ size = { 0.3, 1.3, 2 }, offset = { -1.6, 1.8, 0 }, color = BLUE },
		{ size = { 2.8, 1.2, 1.5 }, offset = { 0, 2.1, 0 }, color = GOLD, studs = true },
		{ size = { 1.6, 0.9, 1.2 }, offset = { -0.2, 3.1, 0 }, color = GOLD, studs = true },
		{ size = { 0.45, 1.3, 1.3 }, offset = { 0.5, 0.65, 1.1 }, color = DARK, shape = "Cylinder", rot = FACING },
		{ size = { 0.45, 1.3, 1.3 }, offset = { 0.5, 0.65, -1.1 }, color = DARK, shape = "Cylinder", rot = FACING },
		{ size = { 1.2, 0.25, 0.25 }, offset = { -2.2, 1, 0 }, color = GREY },
	},
	shield = {
		{ size = { 2.8, 2.2, 0.7 }, offset = { 0, 2.9, 0 }, color = RED },
		{ size = { 2, 2, 0.7 }, offset = { 0, 1.8, 0 }, color = RED, rot = { 0, 0, 45 } },
		{ size = { 0.6, 2.9, 0.85 }, offset = { 0, 2.4, 0 }, color = GOLD },
		{ size = { 2.2, 0.6, 0.85 }, offset = { 0, 3, 0 }, color = GOLD },
		{ size = { 3.1, 0.4, 0.8 }, offset = { 0, 4.1, 0 }, color = DARK_RED },
	},
	magnet = {
		{ size = { 3, 1, 1.1 }, offset = { 0, 0.5, 0 }, color = RED },
		{ size = { 1, 1.7, 1.1 }, offset = { -1, 1.85, 0 }, color = RED },
		{ size = { 1, 1.7, 1.1 }, offset = { 1, 1.85, 0 }, color = RED },
		{ size = { 1.05, 0.8, 1.15 }, offset = { -1, 3.1, 0 }, color = WHITE },
		{ size = { 1.05, 0.8, 1.15 }, offset = { 1, 3.1, 0 }, color = WHITE },
		{ size = { 0.6, 0.6, 0.6 }, offset = { -0.9, 4.3, -0.1 }, color = GOLD, rot = { 0, 20, 25 } },
		{ size = { 0.5, 0.5, 0.5 }, offset = { 0.2, 4.1, 0 }, color = GOLD, rot = { 0, 10, -15 } },
		{ size = { 0.6, 0.6, 0.6 }, offset = { 1.1, 4.5, 0.1 }, color = GOLD, rot = { 15, 0, 40 } },
	},
	meteor = {
		{ size = { 2.5, 2.5, 2.5 }, offset = { -0.9, 1.3, 0 }, color = { 96, 78, 92 }, shape = "Ball" },
		{
			size = { 0.25, 0.7, 0.7 },
			offset = { -1.3, 1.6, -1.12 },
			color = { 60, 48, 60 },
			shape = "Cylinder",
			rot = FACING,
		},
		{
			size = { 0.25, 0.45, 0.45 },
			offset = { -0.5, 0.9, -1.2 },
			color = { 60, 48, 60 },
			shape = "Cylinder",
			rot = FACING,
		},
		{ size = { 2.6, 1.5, 1.2 }, offset = { 0.5, 2.6, 0.2 }, color = ORANGE, rot = { 0, 0, 42 }, material = "Neon" },
		{ size = { 2, 0.9, 1 }, offset = { 1.5, 3.6, 0.3 }, color = GOLD, rot = { 0, 0, 42 }, material = "Neon" },
		{
			size = { 1.2, 0.5, 0.8 },
			offset = { 2.3, 4.4, 0.4 },
			color = { 255, 240, 170 },
			rot = { 0, 0, 42 },
			material = "Neon",
		},
	},
	backpack = {
		{ size = { 2.6, 2.8, 1.5 }, offset = { 0, 1.5, 0 }, color = GOLD },
		{ size = { 2.7, 1, 1.6 }, offset = { 0, 2.6, 0 }, color = DARK_GOLD },
		{ size = { 1.5, 1, 0.3 }, offset = { 0, 1.1, -0.85 }, color = DARK_GOLD },
		{ size = { 0.4, 0.4, 0.2 }, offset = { 0, 2.3, -0.85 }, color = DARK },
		{ size = { 0.4, 2.4, 0.3 }, offset = { -0.9, 1.6, 0.85 }, color = BROWN },
		{ size = { 0.4, 2.4, 0.3 }, offset = { 0.9, 1.6, 0.85 }, color = BROWN },
		{ size = { 1, 0.5, 0.4 }, offset = { 0, 3.3, 0 }, color = BROWN },
	},
	chart = {
		{ size = { 0.9, 1.1, 0.9 }, offset = { -1.2, 0.55, 0 }, color = GREEN },
		{ size = { 0.9, 2, 0.9 }, offset = { 0, 1, 0 }, color = GREEN },
		{ size = { 0.9, 3, 0.9 }, offset = { 1.2, 1.5, 0 }, color = DARK_GREEN },
		{ size = { 3.8, 0.3, 1.2 }, offset = { 0, 0.15, 0 }, color = DARK },
		{ size = { 0.5, 1.2, 1.2 }, offset = { 1.2, 3.7, 0 }, color = GOLD, shape = "Cylinder", rot = FACING },
	},

	-- Récompenses
	calendar = {
		{ size = { 3, 2.6, 0.5 }, offset = { 0, 1.6, 0 }, color = WHITE },
		{ size = { 3, 0.9, 0.55 }, offset = { 0, 3.3, 0 }, color = RED },
		{ size = { 0.3, 0.7, 0.3 }, offset = { -0.9, 3.9, 0 }, color = GREY },
		{ size = { 0.3, 0.7, 0.3 }, offset = { 0.9, 3.9, 0 }, color = GREY },
		{ size = { 0.55, 0.55, 0.15 }, offset = { -0.9, 2.2, -0.3 }, color = GREY },
		{ size = { 0.55, 0.55, 0.15 }, offset = { 0, 2.2, -0.3 }, color = GREY },
		{ size = { 0.55, 0.55, 0.15 }, offset = { 0.9, 2.2, -0.3 }, color = GREY },
		{ size = { 0.55, 0.55, 0.15 }, offset = { -0.9, 1.2, -0.3 }, color = GREY },
		{ size = { 0.7, 0.7, 0.2 }, offset = { 0, 1.2, -0.3 }, color = GOLD },
		{ size = { 0.55, 0.55, 0.15 }, offset = { 0.9, 1.2, -0.3 }, color = GREY },
	},
	ticket = {
		{ size = { 3.6, 1.9, 0.35 }, offset = { 0, 2, 0 }, color = GOLD, rot = { 0, 0, 14 } },
		{ size = { 0.2, 1.9, 0.4 }, offset = { -0.75, 1.8, 0 }, color = DARK_GOLD, rot = { 0, 0, 14 } },
		{ size = { 1.5, 0.35, 0.4 }, offset = { 0.55, 2.4, -0.02 }, color = DARK, rot = { 0, 0, 14 } },
		{ size = { 1.1, 0.3, 0.4 }, offset = { 0.5, 1.85, -0.02 }, color = DARK, rot = { 0, 0, 14 } },
		{ size = { 0.6, 0.6, 0.4 }, offset = { -1.35, 1.65, -0.02 }, color = RED, rot = { 0, 0, 59 } },
	},
	scroll = {
		{ size = { 2.4, 3, 0.25 }, offset = { 0, 2, 0 }, color = CREAM },
		{ size = { 2.9, 0.6, 0.6 }, offset = { 0, 3.6, 0 }, color = TAN, shape = "Cylinder" },
		{ size = { 2.9, 0.6, 0.6 }, offset = { 0, 0.4, 0 }, color = TAN, shape = "Cylinder" },
		{ size = { 1.6, 0.25, 0.1 }, offset = { 0, 2.8, -0.16 }, color = DARK_BROWN },
		{ size = { 1.6, 0.25, 0.1 }, offset = { 0, 2.2, -0.16 }, color = DARK_BROWN },
		{ size = { 1.1, 0.25, 0.1 }, offset = { -0.25, 1.6, -0.16 }, color = DARK_BROWN },
		{ size = { 0.5, 0.5, 0.15 }, offset = { 0.7, 1.1, -0.16 }, color = RED, shape = "Cylinder", rot = FACING },
	},
	wheel = {
		{ size = { 0.5, 3.6, 3.6 }, offset = { 0, 2.3, 0 }, color = WHITE, shape = "Cylinder", rot = FACING },
		{ size = { 1.25, 1.25, 0.6 }, offset = { -0.75, 3.05, 0 }, color = RED },
		{ size = { 1.25, 1.25, 0.6 }, offset = { 0.75, 3.05, 0 }, color = GOLD },
		{ size = { 1.25, 1.25, 0.6 }, offset = { -0.75, 1.55, 0 }, color = BLUE },
		{ size = { 1.25, 1.25, 0.6 }, offset = { 0.75, 1.55, 0 }, color = GREEN },
		{ size = { 0.7, 0.8, 0.8 }, offset = { 0, 2.3, 0 }, color = DARK, shape = "Cylinder", rot = FACING },
		{ size = { 0.6, 0.6, 0.7 }, offset = { 0, 4.3, 0 }, color = RED, rot = { 0, 0, 45 } },
		{ size = { 1.8, 0.4, 1.2 }, offset = { 0, 0.2, 0.2 }, color = DARK },
	},
	weather = {
		{
			size = { 0.5, 2.2, 2.2 },
			offset = { 0.9, 3, 0.4 },
			color = GOLD,
			shape = "Cylinder",
			rot = FACING,
			material = "Neon",
		},
		{ size = { 3, 1.1, 1.2 }, offset = { -0.2, 1.6, 0 }, color = WHITE },
		{ size = { 1.6, 1, 1.2 }, offset = { -0.6, 2.5, 0 }, color = WHITE },
		{ size = { 1.2, 0.8, 1.2 }, offset = { 0.6, 2.3, -0.1 }, color = { 230, 238, 248 } },
		{ size = { 0.25, 0.7, 0.25 }, offset = { -0.9, 0.5, 0 }, color = CYAN, rot = { 0, 0, -15 } },
		{ size = { 0.25, 0.7, 0.25 }, offset = { 0, 0.4, 0 }, color = CYAN, rot = { 0, 0, -15 } },
		{ size = { 0.25, 0.7, 0.25 }, offset = { 0.9, 0.5, 0 }, color = CYAN, rot = { 0, 0, -15 } },
	},
}

-- Boutons au sol de la base : chacun montre l'icône de ce qu'il construit.
local BUTTONS: { [string]: string } = {
	Conveyor = "conveyor",
	SiloUpgrade = "silo",
	Mill = "mill",
	Oven = "oven",
	Factory = "factory",
	Garage = "tractor",
	Rebirth = "star",
	Dryer = "dryer",
	Press = "press",
	Packer = "box",
	Facade = "home",
	Doors = "home",
	Windows = "home",
	Roof = "home",
	Cupola = "home",
	Greenhouse = "home",
	Lanterns = "lamp",
	Lamps = "lamp",
	Flowers = "flower",
	Garden = "flower",
	Hay = "hay",
	Cart = "hay",
	Trees = "tree",
	Well = "well",
	Fountain = "well",
	Pumpkins = "pumpkin",
	Pen = "pig",
	Coop = "pig",
	Beehives = "pig",
	Flag = "flag",
	Statue = "trophy",
	Windmill = "mill",
}

return Freeze.deep({
	ICONS = ICONS,
	BUTTONS = BUTTONS,
	DEFAULT_BUTTON = "build", -- murs, planchers, mobilier : la brique qu'on pose
	EGG_PREFIX = "egg:", -- « egg:BasicEgg » : l'œuf en 3D de EggModel
	-- Icône de chaque palier d'outil ou d'engin (Garage, pop-up « Nouvel outil »).
	TIERS = { "hand", "scythe", "mower", "tractor", "combineRed", "combineGold", "combineCyber" } :: { string },
	-- Cadrage dans le ViewportFrame.
	CAMERA = { fov = 30, distance = 2.35, side = 0.5, height = 0.42 },
	AMBIENT = { 175, 178, 190 },
	LIGHT = { 255, 250, 240 },
	LIGHT_DIRECTION = { 0.5, -1, 0.9 },
})
