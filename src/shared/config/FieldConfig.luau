--!strict
-- Champ de blé, récolte et rareté — CDC §3 (bandes de blé), §4 (grille, repousse, RNG) et §11 (batching).
local Freeze = require("../util/Freeze")

export type WheatZoneDef = {
	hp: number,
	value: number,
	color: { number }, -- couleur de l'épi
	stemColor: { number },
}

export type RarityDef = {
	id: number,
	chance: number,
	valueMultiplier: number,
	hpMultiplier: number,
	sizeMultiplier: number,
}

return Freeze.deep({
	-- CDC §4 : au plus 2 500 brins *affichés simultanément* (budget de 60 FPS sur mobile, décision A32).
	-- Le serveur gère toute la grille (MapConfig.FIELD_LATTICE) ; chaque client n'affiche que les chunks
	-- proches de sa caméra, avec un pool fixe de MAX_STALKS pièces recyclées.
	MAX_STALKS = 2500,
	CHUNK_CELLS = 8, -- un chunk = 8 × 8 cellules (64 × 64 studs)
	RENDER_RADIUS = 220, -- studs autour du point suivi par la caméra
	STREAM_INTERVAL = 0.25, -- secondes entre deux mises à jour des chunks affichés

	-- CDC §3. Clés = id des bandes de MapConfig.
	WHEAT_ZONES = {
		GreenWheat = { hp = 1, value = 1, color = { 196, 220, 90 }, stemColor = { 75, 151, 75 } },
		GoldenCorn = { hp = 15, value = 25, color = { 245, 205, 48 }, stemColor = { 120, 160, 60 } },
		DiamondWheat = { hp = 100, value = 250, color = { 128, 230, 255 }, stemColor = { 90, 140, 200 } },
	} :: { [string]: WheatZoneDef },

	-- CDC §4 + décision A4 (le Géant a 3× plus de PV, l'Arc-en-ciel non).
	RARITIES = {
		Normal = { id = 0, chance = 0, valueMultiplier = 1, hpMultiplier = 1, sizeMultiplier = 1 },
		Giant = { id = 1, chance = 1 / 100, valueMultiplier = 10, hpMultiplier = 3, sizeMultiplier = 3 },
		Rainbow = { id = 2, chance = 1 / 1000, valueMultiplier = 100, hpMultiplier = 1, sizeMultiplier = 1 },
	} :: { [string]: RarityDef },

	REGROW_SECONDS = 8, -- CDC §4
	HARVEST_INTERVAL = 0.15, -- CDC §4 : interrogation de la grille toutes les 0,15 s
	BROADCAST_INTERVAL = 0.2, -- CDC §11 : envois groupés toutes les 0,2 s (décision A18)

	-- Sac / remorque (CDC §4) : l'empilement visible grandit par paliers de 10 %.
	BAG_FILL_STEP = 0.1,
	BACKPACK = {
		WIDTH = 2,
		DEPTH = 1.2,
		BASE_HEIGHT = 0.4, -- sac vide
		HEIGHT_PER_STEP = 0.35, -- +0,35 stud par palier de 10 % (CDC §2 « volume physique qui déborde »)
		BOTTOM_Y = -0.6, -- bas du sac par rapport au centre du HumanoidRootPart
		BACK_OFFSET = 1.1, -- distance derrière le dos
		COLOR = { 245, 205, 48 },
	},

	-- Prédiction client (décision A26) : une coupe prédite non confirmée par le serveur réapparaît.
	PREDICTION_TIMEOUT = 1,

	-- Rendu client des brins (CDC §2, §4).
	-- Un brin = une tige fine + un épi (2 pièces, A36). Hauteur totale : STEM + EAR (≈ 6 studs).
	PLANT = {
		STEM = { 0.5, 3.6, 0.5 },
		EAR = { 1.3, 2.6, 1.3 },
		MAX_LEAN = 0.18, -- inclinaison maximale (radians) : le champ n'est pas une grille au garde-à-vous
	},
	RAINBOW_BEAM_HEIGHT = 160, -- CDC §4 : faisceau visible de toute la carte
	RAINBOW_BEAM_WIDTH = 0.8,
	RAINBOW_BEAM_TRANSPARENCY = 0.4,
	RAINBOW_HUE_SPEED = 0.5, -- tours de roue chromatique par seconde
	BRICKS_PER_CUT_MIN = 3, -- CDC §2 : « 3 à 5 petites briques jaunes »
	BRICKS_PER_CUT_MAX = 5,
	BRICK_SIZE = 0.6,
	BRICK_COLOR = { 245, 205, 48 }, -- CDC §2 : « petites briques jaunes »
	BRICK_FLIGHT_SECONDS = 0.45,
	BRICK_ARC_HEIGHT = 6,
	BRICK_POOL_SIZE = 150,
	POP_PITCH_STEP = 0.03, -- CDC §2 : la tonalité monte à chaque coupe consécutive
	POP_PITCH_MAX = 1.6,
	POP_COMBO_RESET_SECONDS = 1.5,
})
