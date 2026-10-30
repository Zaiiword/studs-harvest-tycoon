--!strict
-- Formes des plantes du champ (CDC §2 « Classic Studs », décision A39). Chaque plante est une liste de pièces
-- décrites dans le repère du pied de la plante (Y vers le haut), à l'échelle 1 (le Géant est ×3).
-- Deux niveaux de détail : « detailed » près de la caméra, « simple » plus loin (tige + épi).
local Freeze = require("../util/Freeze")

export type Role = "stem" | "leaf" | "ear" | "awn"

export type Piece = {
	role: Role,
	size: { number }, -- x, y, z
	offset: { number }, -- centre de la pièce
	tilt: { number }?, -- rotation en radians (x, y, z)
}

export type ShapeSet = { detailed: { Piece }, simple: { Piece } }

local function piece(role: Role, size: { number }, offset: { number }, tilt: { number }?): Piece
	return { role = role, size = size, offset = offset, tilt = tilt }
end

-- Blé : tige fine, deux feuilles, épi de grains en quinconce et deux barbes au sommet.
local WHEAT: ShapeSet = {
	detailed = {
		piece("stem", { 0.3, 3.6, 0.3 }, { 0, 1.8, 0 }),
		piece("leaf", { 0.12, 1.6, 0.7 }, { 0.35, 1.3, 0 }, { 0, 0, -0.55 }),
		piece("leaf", { 0.12, 1.4, 0.6 }, { -0.3, 2.1, 0 }, { 0, 0, 0.55 }),
		piece("ear", { 0.6, 0.6, 0.6 }, { 0.15, 3.9, 0 }),
		piece("ear", { 0.6, 0.6, 0.6 }, { -0.15, 4.45, 0 }),
		piece("ear", { 0.6, 0.6, 0.6 }, { 0.15, 5.0, 0 }),
		piece("ear", { 0.55, 0.55, 0.55 }, { -0.12, 5.5, 0 }),
		piece("awn", { 0.08, 1.2, 0.08 }, { 0.22, 6.3, 0 }, { 0, 0, -0.25 }),
		piece("awn", { 0.08, 1.2, 0.08 }, { -0.22, 6.3, 0 }, { 0, 0, 0.25 }),
	},
	simple = {
		piece("stem", { 0.4, 3.6, 0.4 }, { 0, 1.8, 0 }),
		piece("ear", { 1, 2.4, 1 }, { 0, 4.8, 0 }),
	},
}

-- Maïs : tige épaisse, larges feuilles, épi jaune dans son enveloppe verte, panicule au sommet.
local CORN: ShapeSet = {
	detailed = {
		piece("stem", { 0.5, 5, 0.5 }, { 0, 2.5, 0 }),
		piece("leaf", { 0.12, 2.6, 1.1 }, { 0.6, 1.8, 0 }, { 0, 0, -0.7 }),
		piece("leaf", { 0.12, 2.4, 1.0 }, { -0.55, 2.8, 0 }, { 0, 0, 0.7 }),
		piece("ear", { 0.8, 1.8, 0.8 }, { 0.45, 3.3, 0 }, { 0, 0, -0.3 }),
		piece("leaf", { 0.95, 0.9, 0.95 }, { 0.3, 2.5, 0 }, { 0, 0, -0.3 }),
		piece("awn", { 0.1, 1.1, 0.1 }, { 0, 5.5, 0 }),
		piece("awn", { 0.1, 0.9, 0.1 }, { 0.25, 5.3, 0 }, { 0, 0, -0.5 }),
		piece("awn", { 0.1, 0.9, 0.1 }, { -0.25, 5.3, 0 }, { 0, 0, 0.5 }),
	},
	simple = {
		piece("stem", { 0.5, 5, 0.5 }, { 0, 2.5, 0 }),
		piece("ear", { 1, 2, 1 }, { 0.4, 3.4, 0 }),
	},
}

-- Blé Diamant : tige courte et gerbe de cristaux taillés.
local CRYSTAL: ShapeSet = {
	detailed = {
		piece("stem", { 0.3, 2.6, 0.3 }, { 0, 1.3, 0 }),
		piece("leaf", { 0.12, 1.2, 0.6 }, { 0.3, 0.8, 0 }, { 0, 0, -0.6 }),
		piece("leaf", { 0.12, 1.2, 0.6 }, { -0.3, 0.8, 0 }, { 0, 0, 0.6 }),
		piece("ear", { 0.9, 2.4, 0.9 }, { 0, 3.6, 0 }, { 0, math.pi / 4, 0 }),
		piece("ear", { 0.55, 1.5, 0.55 }, { 0.55, 3.1, 0 }, { 0, math.pi / 4, -0.45 }),
		piece("ear", { 0.55, 1.5, 0.55 }, { -0.55, 3.1, 0 }, { 0, math.pi / 4, 0.45 }),
		piece("awn", { 0.4, 0.9, 0.4 }, { 0, 5.1, 0 }, { 0, math.pi / 4, 0 }),
	},
	simple = {
		piece("stem", { 0.4, 2.6, 0.4 }, { 0, 1.3, 0 }),
		piece("ear", { 1.1, 2.6, 1.1 }, { 0, 3.9, 0 }, { 0, math.pi / 4, 0 }),
	},
}

return Freeze.deep({
	-- Niveau de détail (A39) : le budget total reste 2 500 plantes affichées (CDC §4).
	DETAIL_RADIUS = 80, -- studs autour du point suivi par la caméra
	DETAIL_BUDGET = 300, -- plantes détaillées au plus
	DETAILED_PIECES = 9, -- pièces par plante détaillée (max des formes)
	SIMPLE_PIECES = 2,
	EAR_HEIGHT = 4.5, -- hauteur d'où partent les briques volantes

	SHAPES = {
		GreenWheat = WHEAT,
		GoldenCorn = CORN,
		DiamondWheat = CRYSTAL,
	} :: { [string]: ShapeSet },

	-- Couleurs par rôle et par bande.
	COLORS = {
		GreenWheat = {
			stem = { 120, 160, 60 },
			leaf = { 75, 151, 75 },
			ear = { 226, 196, 90 },
			awn = { 245, 220, 140 },
		},
		GoldenCorn = { stem = { 90, 150, 60 }, leaf = { 60, 130, 50 }, ear = { 245, 205, 48 }, awn = { 200, 160, 90 } },
		DiamondWheat = {
			stem = { 90, 140, 200 },
			leaf = { 70, 110, 170 },
			ear = { 128, 230, 255 },
			awn = { 220, 250, 255 },
		},
	} :: { [string]: { [string]: { number } } },
	-- Le Blé Diamant brille un peu (matériau), le reste est en plastique Lego.
	EAR_MATERIAL = { DiamondWheat = "Glass" } :: { [string]: string },
})
