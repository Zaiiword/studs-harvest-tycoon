--!strict
-- Dimensions de la carte concentrique (CDC §3, décisions A21 à A24 de docs/ANALYSE_CDC.md). Unité : stud.
-- Le centre de la carte est l'origine (0, 0). Les zones sont listées de l'intérieur vers l'extérieur.
-- Tout le sol est posé sur un réseau de cellules carrées de CELL_SIZE, le même que la grille du champ (CDC §4) :
-- le bord des anneaux est donc « en escalier », comme un cercle construit en briques Lego.
local Freeze = require("../util/Freeze")

export type ZoneDef = {
	id: string,
	innerRadius: number,
	outerRadius: number,
}

return Freeze.deep({
	CELL_SIZE = 6,
	-- Nombre de cellules par côté du réseau de la carte (pair, pour rester aligné sur la grille du champ).
	MAP_GRID_SIZE = 86,

	ZONES = {
		{ id = "Core", innerRadius = 0, outerRadius = 24 },
		{ id = "DiamondWheat", innerRadius = 24, outerRadius = 60 },
		{ id = "GoldenCorn", innerRadius = 60, outerRadius = 100 },
		{ id = "GreenWheat", innerRadius = 100, outerRadius = 150 },
		{ id = "Moat", innerRadius = 150, outerRadius = 168 },
		{ id = "Crown", innerRadius = 168, outerRadius = 258 },
	} :: { ZoneDef },
	-- Zones sans sol : on les franchit par les ponts.
	VOID_ZONES = { Moat = true } :: { [string]: boolean },

	-- Bases Tycoon : réparties régulièrement sur la couronne extérieure (CDC §3).
	BASE_COUNT = 8,
	BASE_RADIUS = 213,
	BASE_START_ANGLE_DEG = 22.5,
	BASE_SIZE = 60,

	-- Ponts étroits qui franchissent le fossé entre la couronne et l'anneau Blé Vert (CDC §3).
	BRIDGE_COUNT = 4,
	BRIDGE_START_ANGLE_DEG = 0,
	BRIDGE_WIDTH = 12,
	BRIDGE_OVERLAP = 10,

	-- Altitudes des faces supérieures et épaisseur des briques de sol.
	GROUND_THICKNESS = 2,
	FLOOR_TOP = 0,
	DECK_TOP = 0.4, -- ponts et bases, légèrement au-dessus du sol pour éviter le z-fighting
	MOAT_FLOOR_TOP = -10,
	SPAWN_HEIGHT = 1,
	RETURN_DROP_HEIGHT = 4, -- un joueur tombé dans le fossé réapparaît 4 studs au-dessus de son spawn
	RETURN_COOLDOWN = 1, -- secondes entre deux renvois d'un même joueur

	COLORS = {
		Core = { 255, 196, 0 },
		DiamondWheat = { 90, 200, 250 },
		GoldenCorn = { 245, 205, 48 },
		GreenWheat = { 75, 151, 75 },
		Crown = { 160, 165, 169 },
		Bridge = { 196, 40, 28 },
		Base = { 13, 105, 172 },
		Moat = { 4, 175, 236 },
	} :: { [string]: { number } },
})
