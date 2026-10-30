--!strict
-- Carte en T (décision A21, révisée à la demande du porteur de projet) : les 8 bases sont alignées sur la
-- barre du T (« Plaza »), un fossé franchi par 4 ponts étroits les sépare du champ, et le champ forme la tige
-- du T. Plus on s'éloigne des bases, plus le blé est rare et plus la tige se rétrécit : c'est l'« entonnoir »
-- du CDC §3 (rentabilité ↑, surface ↓, compétition ↑). L'arène du boss (« Core ») termine la tige.
-- Axe X : des bases vers le bout du champ. Axe Z : latéral. Unité : stud.
-- Tout le sol est posé sur un réseau de cellules de CELL_SIZE, le même que la grille du champ (CDC §4).
local Freeze = require("../util/Freeze")

export type Lattice = {
	minX: number,
	minZ: number,
	cols: number, -- cellules le long de X
	rows: number, -- cellules le long de Z
}

export type BandDef = {
	id: string,
	startDistance: number, -- distance depuis le début de la tige
	endDistance: number,
}

return Freeze.deep({
	CELL_SIZE = 8,

	-- Barre du T : bases et circulation. Fossé : bande vide franchie par les ponts. Tige : champ.
	PLAZA = { minX = -104, maxX = 0, halfWidth = 320 },
	MOAT = { minX = 0, maxX = 24 },
	STEM = { minX = 24, maxX = 904, startHalfWidth = 120, endHalfWidth = 64 },

	-- Bandes de la tige, de la plus proche des bases à la plus lointaine (CDC §3).
	STEM_BANDS = {
		{ id = "GreenWheat", startDistance = 0, endDistance = 360 },
		{ id = "GoldenCorn", startDistance = 360, endDistance = 640 },
		{ id = "DiamondWheat", startDistance = 640, endDistance = 820 },
		{ id = "Core", startDistance = 820, endDistance = 880 },
	} :: { BandDef },
	-- Zones sans sol : on les franchit par les ponts.
	VOID_ZONES = { Moat = true } :: { [string]: boolean },

	-- Réseau de toute la carte (sol) et réseau du champ (FieldGrid). Ils sont alignés : mêmes cellules.
	MAP_LATTICE = { minX = -104, minZ = -320, cols = 126, rows = 80 } :: Lattice,
	FIELD_LATTICE = { minX = 24, minZ = -120, cols = 110, rows = 30 } :: Lattice,

	-- Bases Tycoon : alignées sur la barre, tournées vers le champ (CDC §3, A22).
	BASE_COUNT = 8,
	BASE_SIZE = 60,
	BASE_PITCH = 80, -- distance entre deux centres de bases
	BASE_CENTER_X = -52,

	-- Ponts étroits qui franchissent le fossé (CDC §3, A23), répartis sur la largeur du début de la tige.
	BRIDGE_Z = { -90, -30, 30, 90 } :: { number },
	BRIDGE_WIDTH = 12,
	BRIDGE_OVERLAP = 10,

	-- Altitudes des faces supérieures et épaisseur des briques de sol.
	GROUND_THICKNESS = 2,
	FLOOR_TOP = 0,
	DECK_TOP = 0.4, -- ponts et bases, légèrement au-dessus du sol pour éviter le z-fighting
	WATER_TOP = -10, -- plan d'eau sous toute la carte : y tomber renvoie à sa base (A27)
	WATER_MARGIN = 200,
	SPAWN_HEIGHT = 1,
	RETURN_DROP_HEIGHT = 4, -- un joueur tombé à l'eau réapparaît 4 studs au-dessus de son spawn
	RETURN_COOLDOWN = 1, -- secondes entre deux renvois d'un même joueur

	-- Restes du modèle « Baseplate » de Studio qui recouvriraient la carte générée.
	TEMPLATE_LEFTOVERS = { "Baseplate", "SpawnLocation" } :: { string },

	-- Couleurs du sol : contrastées avec les brins de chaque bande (FieldConfig.WHEAT_ZONES).
	COLORS = {
		Plaza = { 248, 217, 109 },
		GreenWheat = { 164, 189, 71 },
		GoldenCorn = { 218, 133, 65 },
		DiamondWheat = { 98, 37, 209 },
		Core = { 196, 40, 28 },
		Bridge = { 196, 40, 28 },
		Base = { 13, 105, 172 },
		Water = { 4, 175, 236 },
	} :: { [string]: { number } },
})
