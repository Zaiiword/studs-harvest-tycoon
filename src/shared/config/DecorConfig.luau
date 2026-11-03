--!strict
-- Décor « Classic Studs » (CDC §2) : murs, clôtures, arbres, portiques, rambardes, post-traitement.
-- Purement visuel : aucune de ces pièces n'influence le gameplay (hors collisions des murs et clôtures).
local Freeze = require("../util/Freeze")

return Freeze.deep({
	-- Murs de briques le long de la tige du champ (référence : couloir bordé de murs).
	STEM_WALL = {
		HEIGHT = 10,
		THICKNESS = 4,
		SEGMENT_LENGTH = 120,
		COLOR = { 218, 133, 65 },
		CAP_COLOR = { 75, 151, 75 },
	},

	-- Clôtures en bois autour des bases, ouvertes côté champ.
	FENCE = {
		POST_SIZE = 1.2,
		POST_HEIGHT = 5,
		POST_SPACING = 10,
		RAIL_HEIGHTS = { 1.8, 3.8 } :: { number },
		RAIL_THICKNESS = 0.6,
		INSET = 3, -- distance entre le bord de la base et la clôture
		GATE_WIDTH = 36, -- ouverture côté champ, devant la grille de déchargement
		COLOR = { 124, 92, 70 },
	},

	-- Arbres Lego entre les bases : tronc et feuillage en cubes empilés.
	TREE = {
		TRUNK_SIZE = { 2, 8, 2 },
		LEAF_LAYERS = { { size = 9, y = 9 }, { size = 7, y = 12 }, { size = 4, y = 14.5 } },
		LEAF_HEIGHT = 3,
		TRUNK_COLOR = { 105, 64, 40 },
		LEAF_COLOR = { 40, 127, 71 },
		ROWS_X = { -180, -10 } :: { number }, -- derrière les bases, et le long du boulevard côté fossé
	},

	-- Portique à chaque frontière de bande (et à l'entrée de l'arène) avec le nom de la zone.
	GATE = {
		PILLAR_SIZE = 6,
		HEIGHT = 26,
		BEAM_HEIGHT = 5,
		SIGN_TEXT_COLOR = { 255, 255, 255 },
		LABELS = {
			GreenWheat = "🌾 BLÉ VERT · ZONE SÛRE",
			GoldenCorn = "🌽 MAÏS DORÉ · 25 $",
			DiamondWheat = "💎 BLÉ DIAMANT · 250 $",
			Core = "☄️ ARÈNE DU BOSS",
		} :: { [string]: string },
		COLORS = {
			GreenWheat = { 75, 151, 75 },
			GoldenCorn = { 245, 205, 48 },
			DiamondWheat = { 98, 37, 209 },
			Core = { 196, 40, 28 },
		} :: { [string]: { number } },
	},

	-- Boulevard (A54) : asphalte, ligne centrale, bordures de course, néons, drapeaux et arches vers le champ.
	ROAD = {
		COLOR = { 58, 62, 74 },
		LINE_COLOR = { 255, 215, 60 },
		DASH = { spacing = 16, length = 8, width = 1 },
		CURB = { length = 16, width = 1.4, height = 0.35, colors = { { 230, 40, 40 }, { 248, 248, 248 } } },
		NEON = { inset = 2.4, width = 0.5, color = { 0, 170, 210 } },
		FLAG = {
			x = -16,
			spacing = 48,
			clearance = 16, -- distance minimale à un pont ou à une statue
			height = 14,
			colors = { { 255, 60, 90 }, { 255, 205, 48 }, { 60, 200, 255 }, { 120, 220, 80 } },
		},
		ARCH = {
			x = -15,
			height = 15,
			beamHeight = 4,
			color = { 27, 42, 53 },
			neon = { 215, 160, 35 },
			toField = "🌾 VERS LE CHAMP 🌾",
			toBases = "🏠 VERS LES BASES",
		},
	},

	BRIDGE_RAIL = { HEIGHT = 3, THICKNESS = 1, COLOR = { 248, 248, 248 } },

	BASE_SIGN = { WIDTH = 30, HEIGHT = 7, POLE_HEIGHT = 10, COLOR = { 27, 42, 53 } },

	-- Variation des brins (A35) : chaque brin est un peu différent, de façon déterministe.
	STALK_VARIATION = { HEIGHT = 0.25, SHADE = 0.12 },

	-- Post-traitement : couleurs saturées et léger éclat (CDC §2).
	POST = {
		SATURATION = 0.2,
		CONTRAST = 0.08,
		BLOOM_INTENSITY = 0.2,
		BLOOM_SIZE = 24,
		BLOOM_THRESHOLD = 2,
		SUN_RAYS_INTENSITY = 0.06,
	},

	-- Animations client de l'usine.
	MILL_SPIN_SPEED = 1.2, -- rad/s
	CONVEYOR_BRICK_SPEED = 6, -- studs/s
	CONVEYOR_BRICK_SPACING = 6,
})
