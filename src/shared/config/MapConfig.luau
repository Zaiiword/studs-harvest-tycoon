--!strict
-- Dimensions de la carte concentrique (CDC §3, décisions A21 à A23 de docs/ANALYSE_CDC.md). Unité : stud.
-- Le centre de la carte est l'origine (0, 0). Les zones sont listées de l'intérieur vers l'extérieur.

export type ZoneDef = {
	id: string,
	innerRadius: number,
	outerRadius: number,
}

local ZONES: { ZoneDef } = {
	{ id = "Core", innerRadius = 0, outerRadius = 60 },
	{ id = "DiamondWheat", innerRadius = 60, outerRadius = 140 },
	{ id = "GoldenCorn", innerRadius = 140, outerRadius = 230 },
	{ id = "GreenWheat", innerRadius = 230, outerRadius = 330 },
	{ id = "Moat", innerRadius = 330, outerRadius = 350 },
	{ id = "Crown", innerRadius = 350, outerRadius = 450 },
}

local MapConfig = {
	ZONES = ZONES,

	-- Bases Tycoon : réparties régulièrement sur la couronne extérieure.
	BASE_COUNT = 8,
	BASE_RADIUS = 400,
	BASE_START_ANGLE_DEG = 22.5,
	BASE_SIZE = 60,

	-- Ponts étroits qui franchissent le fossé entre la couronne et l'anneau Blé Vert.
	BRIDGE_COUNT = 4,
	BRIDGE_START_ANGLE_DEG = 0,
	BRIDGE_WIDTH = 12,
	BRIDGE_OVERLAP = 10,

	-- Rendu : altitude de la face supérieure de chaque couche, épaisseur du sol, nombre de segments de la couronne.
	GROUND_THICKNESS = 2,
	CROWN_SEGMENTS = 64,
	LAYER_ELEVATION = {
		Core = 0.8,
		DiamondWheat = 0.6,
		GoldenCorn = 0.4,
		GreenWheat = 0.2,
		Crown = 0,
	} :: { [string]: number },
	MOAT_FLOOR_ELEVATION = -8,
	STUDS_MATERIAL_VARIANT = "LegoStuds",
	ZONE_COLORS = {
		Core = { 255, 196, 0 },
		DiamondWheat = { 90, 200, 250 },
		GoldenCorn = { 245, 205, 48 },
		GreenWheat = { 75, 151, 75 },
		Crown = { 160, 165, 169 },
		BridgeAndBase = { 196, 40, 28 },
		Moat = { 13, 105, 172 },
	} :: { [string]: { number } },
}

return MapConfig
