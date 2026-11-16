--!strict
-- Paysage autour de la carte (A69) : berges herbeuses le long du champ, collines et montagnes en briques, arbres,
-- îles, bateaux, montgolfières, nuages, vie de la rivière et jardins entre les bases. Purement visuel : rien ici
-- ne touche au gameplay, et tout est placé hors des zones où l'on joue (vérifié par les tests de Scenery).
local Freeze = require("../util/Freeze")

export type TreeKind = { id: string, weight: number }
export type Range = { spacing: number, minV: number, maxV: number, minScale: number, maxScale: number }
export type Bob = { height: number, period: number, tilt: number }

return Freeze.deep({
	SEED = 20261116, -- le paysage est le même sur tous les serveurs

	-- Socle de terre sous le sol : la carte est une île aux falaises brunes, pas une plaque posée sur l'eau.
	FOUNDATION = { DEPTH = 12, COLOR = { 124, 92, 70 } },
	-- Bandes de tonte : une bande de sol sur deux est un peu plus sombre, comme une pelouse fraîchement tondue.
	STRIPE = { WIDTH = 16, SHADE = 0.93 },

	-- Berges : deux grands plateaux herbeux, parallèles aux murs du champ, qui portent collines et forêts.
	BANK = {
		TOP = 4, -- sous le haut des murs (10) : on voit la berge par-dessus sans qu'elle déborde
		WIDTH = 420,
		GAP = 3, -- distance entre la face extérieure du mur et la berge
		GRASS_THICKNESS = 1.2,
		GRASS_COLOR = { 96, 168, 76 },
		EARTH_COLOR = { 124, 92, 70 },
	},
	-- Plateau au bout du champ, derrière l'arène du boss : il porte le volcan du Météore.
	END_PLATEAU = { TOP = 8, DEPTH = 460, HALF_WIDTH = 540, COLOR = { 86, 78, 92 } },

	-- Plage derrière les bases : des marches de sable qui descendent vers la mer.
	BEACH = {
		STEPS = { { depth = 22, top = -3 }, { depth = 22, top = -6.5 } },
		COLOR = { 250, 228, 150 },
	},

	-- Collines en gradins (plaques empilées de plus en plus petites).
	HILL = {
		TIER_HEIGHT = 5,
		COLORS = { { 96, 168, 76 }, { 82, 152, 66 }, { 110, 180, 84 } },
		NEAR = { spacing = 105, minV = 60, maxV = 130, minScale = 26, maxScale = 46 } :: Range,
		MIN_TIERS = 2,
		MAX_TIERS = 5,
		WINDMILL_EVERY = 3, -- une colline proche sur trois porte un moulin
	},
	MOUNTAIN = {
		TIER_HEIGHT = 10,
		ROCK_COLORS = { { 120, 124, 138 }, { 104, 108, 124 } },
		GRASS_COLORS = { { 76, 140, 70 }, { 66, 128, 64 } },
		SNOW_COLOR = { 244, 248, 252 },
		GRASS_TIERS = 3, -- pied herbeux
		SNOW_FROM = 0.72, -- part de la hauteur à partir de laquelle la roche est enneigée
		FAR = { spacing = 165, minV = 215, maxV = 330, minScale = 80, maxScale = 125 } :: Range,
		MIN_TIERS = 8,
		MAX_TIERS = 13,
	},
	VOLCANO = {
		DISTANCE = 250, -- derrière le mur du fond
		RADIUS = 190,
		TIERS = 13,
		TIER_HEIGHT = 13,
		ROCK_COLORS = { { 72, 60, 70 }, { 58, 48, 60 } },
		LAVA_COLOR = { 255, 96, 40 },
		FLANKS = { { z = -330, radius = 120, tiers = 10 }, { z = 330, radius = 120, tiers = 10 } },
	},

	-- Arbres : essences tirées au sort, avec quelques cerisiers en fleurs et arbres d'automne pour la couleur.
	TREE = {
		TRUNK_COLOR = { 105, 64, 40 },
		LEAF_COLORS = { { 40, 127, 71 }, { 58, 150, 70 }, { 34, 110, 62 } },
		BLOSSOM_COLORS = { { 255, 170, 205 }, { 255, 200, 222 } },
		AUTUMN_COLORS = { { 240, 150, 50 }, { 226, 110, 44 } },
		APPLE_COLOR = { 220, 40, 40 },
		PALM_LEAF_COLOR = { 70, 170, 80 },
		PALM_TRUNK_COLOR = { 160, 120, 76 },
		KINDS = {
			{ id = "pine", weight = 4 },
			{ id = "round", weight = 4 },
			{ id = "apple", weight = 2 },
			{ id = "blossom", weight = 2 },
			{ id = "autumn", weight = 1 },
		} :: { TreeKind },
		BANK = { spacing = 24, minV = 10, maxV = 52, minScale = 1.0, maxScale = 1.8 } :: Range,
		FOREST = { spacing = 34, minV = 140, maxV = 210, minScale = 1.4, maxScale = 2.4 } :: Range,
	},

	WINDMILL = {
		TOWER_COLOR = { 244, 238, 224 },
		ROOF_COLOR = { 196, 40, 28 },
		BLADE_COLOR = { 124, 92, 70 },
		SAIL_COLOR = { 248, 248, 248 },
		HEIGHT = 30,
		WIDTH = 11,
		BLADE_LENGTH = 22,
	},

	-- Îles derrière les bases et au large : un socle de sable, de l'herbe, des palmiers.
	ISLAND = {
		SAND_COLOR = { 250, 228, 150 },
		SPOTS = {
			{ x = -420, z = -380, radius = 70, tiers = 4, palms = 4 },
			{ x = -520, z = -40, radius = 95, tiers = 7, palms = 5 },
			{ x = -400, z = 330, radius = 60, tiers = 3, palms = 4 },
			{ x = -330, z = 760, radius = 80, tiers = 5, palms = 4 },
			{ x = -330, z = -780, radius = 75, tiers = 5, palms = 4 },
		},
		TIER_HEIGHT = 6,
	},
	LIGHTHOUSE = {
		x = -330,
		z = 150,
		ROCK_RADIUS = 26,
		ROCK_COLOR = { 120, 124, 138 },
		STRIPES = 6,
		STRIPE_HEIGHT = 7,
		WIDTH = 12,
		COLORS = { { 220, 40, 40 }, { 248, 248, 248 } },
		LAMP_COLOR = { 255, 230, 140 },
	},

	-- Voiliers qui tanguent sur la mer.
	BOAT = {
		SPOTS = {
			{ x = -270, z = -220, yaw = 20 },
			{ x = -300, z = 40, yaw = -70 },
			{ x = -260, z = 290, yaw = 140 },
			{ x = -380, z = 520, yaw = 60 },
			{ x = -250, z = -560, yaw = -30 },
			{ x = -120, z = 700, yaw = 100 },
			{ x = -120, z = -700, yaw = 10 },
		},
		HULL_COLORS = { { 220, 40, 40 }, { 40, 110, 200 }, { 245, 205, 48 }, { 124, 92, 70 } },
		SAIL_COLOR = { 248, 248, 248 },
		BOB = { height = 0.6, period = 3.2, tilt = 4 } :: Bob,
	},

	-- Montgolfières au-dessus des berges et de la mer.
	BALLOON = {
		SPOTS = {
			{ x = 180, y = 120, z = -420 },
			{ x = 520, y = 150, z = 380 },
			{ x = 900, y = 135, z = -330 },
			{ x = -260, y = 110, z = 250 },
			{ x = -240, y = 140, z = -420 },
			{ x = 1120, y = 160, z = 300 },
		},
		PALETTES = {
			{ { 220, 40, 40 }, { 248, 248, 248 } },
			{ { 245, 205, 48 }, { 40, 110, 200 } },
			{ { 255, 120, 180 }, { 248, 248, 248 } },
			{ { 70, 190, 110 }, { 245, 205, 48 } },
			{ { 150, 90, 220 }, { 255, 160, 60 } },
		},
		TIERS = { 12, 22, 28, 28, 22, 12 }, -- largeur de chaque étage de l'enveloppe
		TIER_HEIGHT = 6,
		BASKET_COLOR = { 124, 92, 70 },
		BOB = { height = 4, period = 9, tilt = 0 } :: Bob,
	},

	-- Nuages en briques blanches, qui dérivent lentement (animés côté client).
	CLOUD = {
		COUNT = 22,
		MIN_X = -700,
		MAX_X = 1700,
		MIN_Z = -950,
		MAX_Z = 950,
		MIN_Y = 190,
		MAX_Y = 300,
		MIN_SCALE = 0.8,
		MAX_SCALE = 1.9,
		COLOR = { 255, 255, 255 },
		DRIFT_SPEED = 5, -- studs/s, le long de Z
		-- Blocs d'un nuage à l'échelle 1 : { décalage x, y, z, taille x, y, z }.
		BLOCKS = {
			{ 0, 0, 0, 44, 12, 70 },
			{ 4, 9, -8, 30, 10, 40 },
			{ -6, 6, 18, 26, 9, 30 },
			{ 2, -5, 6, 36, 6, 90 },
		},
	},

	-- Vie de la rivière (le fossé) : nénuphars et canards.
	RIVER = {
		LILY_COUNT = 34,
		DUCK_COUNT = 12,
		MARGIN = 5, -- distance aux rives
		BRIDGE_MARGIN = 6,
		LILY_COLOR = { 60, 150, 70 },
		FLOWER_COLORS = { { 255, 170, 205 }, { 255, 255, 255 }, { 255, 215, 90 } },
		DUCK_COLOR = { 250, 215, 60 },
		BEAK_COLOR = { 240, 130, 40 },
		BOB = { height = 0.25, period = 2.2, tilt = 5 } :: Bob,
	},

	-- Jardins entre les bases et derrière elles : arbres, buissons, fleurs, rochers, champignons, bottes de foin.
	GARDEN = {
		MIN_X = -162, -- entre deux bases, du fond jusqu'avant le boulevard
		MAX_X = -64,
		SPACING = 11,
		HALF_WIDTH = 8, -- de part et d'autre du milieu de l'allée (les clôtures sont à 15,5)
		BACK_X = -184, -- rangée derrière les bases
		BACK_SPACING = 14,
		TREE_CLEARANCE = 9, -- les arbres existants de la barre gardent leur place
		BUSH_COLORS = { { 62, 140, 66 }, { 80, 160, 74 } },
		FLOWER_COLORS = { { 255, 90, 110 }, { 255, 215, 60 }, { 250, 250, 250 }, { 190, 120, 255 }, { 255, 150, 60 } },
		STEM_COLOR = { 70, 150, 70 },
		ROCK_COLORS = { { 150, 152, 160 }, { 128, 130, 140 } },
		HAY_COLOR = { 236, 196, 84 },
		MUSHROOM_CAP = { 220, 40, 40 },
		MUSHROOM_STEM = { 248, 244, 232 },
		KINDS = { "tree", "flowers", "bush", "flowers", "rock", "tree", "mushroom", "hay", "flowers", "bush" },
	},

	-- Lampadaires au bord du boulevard, entre deux portes de bases.
	LAMP = {
		X = -54,
		HEIGHT = 13,
		POLE_COLOR = { 27, 42, 53 },
		LIGHT_COLOR = { 255, 220, 130 },
		RANGE = 30,
		BRIGHTNESS = 1.2,
	},

	-- Parasols et serviettes sur la première marche de sable.
	BEACH_PROPS = {
		SPACING = 72,
		PARASOL_COLORS = { { 220, 40, 40 }, { 40, 110, 200 }, { 245, 205, 48 }, { 255, 120, 180 } },
		TOWEL_COLORS = { { 60, 200, 255 }, { 255, 150, 60 }, { 150, 90, 220 } },
	},

	-- Noms et attributs lus par le client pour animer le paysage (SceneryFxController).
	FOLDER_NAME = "Scenery",
	DRIFT_TAG = "SceneryDrift",
	BOB_TAG = "SceneryBob",
	BOB_HEIGHT = "BobHeight",
	BOB_PERIOD = "BobPeriod",
	BOB_TILT = "BobTilt",
	BOB_ROAM = "BobRoam", -- rayon de la ronde autour du point de repos (0 : sur place)
})
