--!strict
-- La grande ferme Lego (A56) : dimensions de la grange et palette. Le détail de chaque pièce est calculé par
-- FarmBlueprint. Coordonnées locales de la base : +X vers le champ, Z latéral, Y au-dessus du pont de la base.
local Freeze = require("../util/Freeze")

return Freeze.deep({
	BARN = {
		BACK_X = -54, -- face extérieure du mur du fond
		FRONT_X = 2, -- face extérieure de la façade
		HALF_Z = 32, -- face extérieure des murs latéraux
		WALL = 2, -- épaisseur des murs
		COURSE = 2.5, -- hauteur d'une rangée de briques
		BRICK = 10, -- longueur d'une brique (appareillage en quinconce)
		GROUND_COURSES = 8, -- rez-de-chaussée : 20 studs de haut
		UPPER_COURSES = 6, -- étage : avant-toit à 35 studs
		STONE_COURSES = 1, -- soubassement en pierre
		QUOINS = { 3, 5 }, -- chaînage d'angle blanc : longueur en alternance selon la rangée
		DOOR_HALF_WIDTH = 10,
		DOOR_COURSES = 6,
		WINDOW_FROM_COURSE = 3, -- au rez-de-chaussée ; à l'étage, juste au-dessus du plancher
		UPPER_WINDOW_FROM_COURSE = 1,
		WINDOW_COURSES = 3,
		WINDOW_WIDTH = 8,
		SIDE_WINDOWS_X = { -40, -24, -8 } :: { number },
		BACK_WINDOWS_Z = { -18, 0, 18 } :: { number },
		FRONT_WINDOWS_Z = { -24, 24 } :: { number },
		FRONT_WINDOW_WIDTH = 5, -- entre les battants ouverts et le chaînage d'angle
		HAY_DOOR_HALF_WIDTH = 7, -- porte du grenier, en haut de la façade
		BELT_HOLE = { fromX = -50, toX = -42, courses = 2 }, -- passage du tapis dans le mur sud
		LOFT_FRONT_X = -22, -- l'étage couvre l'arrière ; l'avant reste ouvert jusqu'au toit
		LOFT_THICKNESS = 1,
		STAIRS = { startX = -3, run = 1.5, steps = 21, minZ = 25, maxZ = 30 },
		ROOF = {
			OVERHANG = 2,
			LOWER_STEPS = 5, -- partie raide de la toiture à la Mansart
			LOWER_RISE = 2.5,
			LOWER_INSET = 2,
			UPPER_STEPS = 6, -- partie douce, jusqu'au faîtage
			UPPER_RISE = 1.25,
			UPPER_INSET = 4,
		},
	},
	-- Lumières de la ferme : elles s'additionnent sur les briques blanches, même en plein jour. Faibles et courtes,
	-- elles donnent une ambiance sans éblouir.
	LIGHT = { BRIGHTNESS = 0.3, MAX_RANGE = 14, MAX_NEON_LUMINANCE = 175 },
	-- Variation de teinte entre deux briques : c'est elle qui fait un mur « Lego » et non un aplat.
	SHADE = 0.05,
	PALETTE = {
		RED = { 178, 44, 38 },
		WHITE = { 236, 233, 225 },
		STONE = { 152, 152, 158 },
		STONE_DARK = { 108, 108, 116 },
		WOOD = { 122, 82, 52 },
		PLANK = { 158, 110, 68 },
		ROOF = { 68, 74, 90 },
		ROOF_LIGHT = { 86, 92, 110 },
		GOLD = { 255, 196, 0 },
		HAY = { 236, 196, 84 },
		STRAP = { 150, 110, 40 },
		LEAF = { 62, 140, 66 },
		LEAF_LIGHT = { 92, 170, 80 },
		SOIL = { 105, 64, 40 },
		GLASS = { 165, 225, 255 },
		WATER = { 80, 170, 255 },
		DARK = { 27, 42, 53 },
		WARM_LIGHT = { 225, 160, 80 }, -- néon : une couleur trop claire vire au blanc et éblouit
		NEON_PINK = { 255, 60, 160 },
		NEON_CYAN = { 0, 170, 210 },
		APPLE = { 220, 40, 40 },
		BELT = { 40, 45, 55 },
		SKIN = { 240, 205, 150 },
		SHIRT = { 60, 110, 190 },
		ORANGE = { 240, 130, 30 },
		PINK = { 245, 165, 170 },
		MUD = { 90, 62, 40 },
	} :: { [string]: { number } },
	FLOWER_COLORS = { { 255, 80, 80 }, { 255, 210, 40 }, { 190, 90, 255 }, { 255, 140, 200 } } :: { { number } },
})
