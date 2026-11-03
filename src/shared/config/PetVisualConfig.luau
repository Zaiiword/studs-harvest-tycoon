--!strict
-- Apparence des Pets cubiques en briques (CDC §2, §7.2) et des distributeurs d'œufs. Chaque Pet est une liste
-- de pièces dans son propre repère (avant = -Z, haut = +Y, origine au sol), à la taille 1.
local Freeze = require("../util/Freeze")

export type Piece = {
	size: { number },
	offset: { number },
	color: { number },
	isMain: boolean?, -- prend la couleur de la variante (Or, Arc-en-ciel)
	shape: string?, -- « Ball », « Cylinder » ; bloc par défaut
	material: string?,
}

local BLACK, WHITE = { 27, 42, 53 }, { 248, 248, 248 }

local function eyes(y: number, z: number, spread: number): { Piece }
	return {
		{ size = { 0.3, 0.3, 0.1 }, offset = { -spread, y, z }, color = BLACK },
		{ size = { 0.3, 0.3, 0.1 }, offset = { spread, y, z }, color = BLACK },
	}
end

local function merge(...: { Piece }): { Piece }
	local all: { Piece } = {}
	for _, list in { ... } do
		for _, piece in list do
			table.insert(all, piece)
		end
	end
	return all
end

return Freeze.deep({
	SPECIES = {
		Chick = merge({
			{ size = { 1.6, 1.6, 1.6 }, offset = { 0, 0.8, 0 }, color = { 245, 205, 48 }, isMain = true },
			{ size = { 0.5, 0.3, 0.4 }, offset = { 0, 0.9, -0.95 }, color = { 218, 133, 65 } },
			{ size = { 0.4, 0.4, 0.4 }, offset = { 0, 1.8, 0 }, color = { 196, 40, 28 } },
			{ size = { 0.2, 0.7, 0.9 }, offset = { -0.9, 0.8, 0.1 }, color = { 226, 196, 90 } },
			{ size = { 0.2, 0.7, 0.9 }, offset = { 0.9, 0.8, 0.1 }, color = { 226, 196, 90 } },
		}, eyes(1.15, -0.81, 0.35)),
		Cow = merge({
			{ size = { 1.8, 1.4, 2.4 }, offset = { 0, 1.1, 0.2 }, color = WHITE, isMain = true },
			{ size = { 1.2, 1.1, 1.0 }, offset = { 0, 1.5, -1.3 }, color = WHITE, isMain = true },
			{ size = { 0.8, 0.5, 0.2 }, offset = { 0, 1.2, -1.85 }, color = { 255, 152, 220 } },
			{ size = { 0.7, 0.5, 0.9 }, offset = { 0.55, 1.5, 0.4 }, color = BLACK },
			{ size = { 0.6, 0.4, 0.6 }, offset = { -0.6, 1.0, -0.2 }, color = BLACK },
			{ size = { 0.2, 0.5, 0.2 }, offset = { -0.45, 2.2, -1.3 }, color = { 226, 196, 90 } },
			{ size = { 0.2, 0.5, 0.2 }, offset = { 0.45, 2.2, -1.3 }, color = { 226, 196, 90 } },
			{ size = { 0.4, 0.4, 0.4 }, offset = { -0.6, 0.2, -0.7 }, color = WHITE },
			{ size = { 0.4, 0.4, 0.4 }, offset = { 0.6, 0.2, 1.0 }, color = WHITE },
		}, eyes(1.75, -1.81, 0.3)),
		Tractor = merge({
			{ size = { 1.8, 1.0, 2.6 }, offset = { 0, 1.0, 0 }, color = { 75, 151, 75 }, isMain = true },
			{ size = { 1.3, 1.0, 1.0 }, offset = { 0, 2.0, 0.6 }, color = { 128, 230, 255 }, material = "Glass" },
			{ size = { 0.5, 1.4, 1.4 }, offset = { -1.1, 0.7, 0.8 }, color = BLACK, shape = "Cylinder" },
			{ size = { 0.5, 1.4, 1.4 }, offset = { 1.1, 0.7, 0.8 }, color = BLACK, shape = "Cylinder" },
			{ size = { 0.4, 0.9, 0.9 }, offset = { -1.05, 0.45, -0.9 }, color = BLACK, shape = "Cylinder" },
			{ size = { 0.4, 0.9, 0.9 }, offset = { 1.05, 0.45, -0.9 }, color = BLACK, shape = "Cylinder" },
			{ size = { 0.5, 0.5, 0.1 }, offset = { -0.45, 1.2, -1.32 }, color = WHITE },
			{ size = { 0.5, 0.5, 0.1 }, offset = { 0.45, 1.2, -1.32 }, color = WHITE },
		}, eyes(1.2, -1.38, 0.45)),
		Dragon = merge({
			{ size = { 1.6, 1.4, 2.4 }, offset = { 0, 1.2, 0 }, color = { 245, 205, 48 }, isMain = true },
			{ size = { 1.2, 1.0, 1.2 }, offset = { 0, 2.0, -1.3 }, color = { 245, 205, 48 }, isMain = true },
			{ size = { 0.2, 0.6, 0.2 }, offset = { -0.4, 2.7, -1.2 }, color = WHITE },
			{ size = { 0.2, 0.6, 0.2 }, offset = { 0.4, 2.7, -1.2 }, color = WHITE },
			{ size = { 2.0, 0.15, 1.2 }, offset = { -1.6, 1.8, 0.2 }, color = { 218, 133, 65 } },
			{ size = { 2.0, 0.15, 1.2 }, offset = { 1.6, 1.8, 0.2 }, color = { 218, 133, 65 } },
			{ size = { 0.5, 0.5, 1.4 }, offset = { 0, 1.0, 1.8 }, color = { 245, 205, 48 }, isMain = true },
		}, eyes(2.15, -1.91, 0.3)),
		Phoenix = merge({
			{ size = { 1.4, 1.4, 1.8 }, offset = { 0, 1.4, 0 }, color = { 255, 89, 89 }, isMain = true },
			{ size = { 2.4, 0.15, 1.2 }, offset = { -1.9, 1.9, 0.2 }, color = { 255, 176, 0 }, material = "Neon" },
			{ size = { 2.4, 0.15, 1.2 }, offset = { 1.9, 1.9, 0.2 }, color = { 255, 176, 0 }, material = "Neon" },
			{ size = { 0.4, 0.9, 0.4 }, offset = { 0, 2.5, -0.3 }, color = { 245, 205, 48 }, material = "Neon" },
			{ size = { 0.4, 0.3, 0.5 }, offset = { 0, 1.5, -1.1 }, color = { 245, 205, 48 } },
			{ size = { 0.8, 0.2, 1.6 }, offset = { 0, 1.2, 1.6 }, color = { 255, 176, 0 }, material = "Neon" },
		}, eyes(1.75, -0.91, 0.3)),
	} :: { [string]: { Piece } },

	VARIANT_COLORS = {
		Gold = { 255, 196, 0 },
	} :: { [string]: { number } },
	GOLD_REFLECTANCE = 0.35,
	RAINBOW_HUE_SPEED = 0.4,

	-- Distributeur d'œufs : socle, œuf géant, étiquette avec prix et chances (A42).
	DISPENSER = {
		BASE_SIZE = { 8, 1.5, 8 }, -- caisse en bois garnie de paille
		EGG_SIZE = { 5, 6.5, 5 },
		BASE_COLOR = { 122, 82, 52 },
		STRAW_COLOR = { 236, 196, 84 },
		RIM_COLOR = { 15, 35, 90 },
		RIM_HEIGHT = 0.3, -- au-dessus des dalles du couvoir : deux faces au même niveau scintillent
	},
	-- Couvoir : terrasse dallée le long de la clôture sud, haie à l'arrière et enseigne (A57). Coordonnées locales.
	HATCHERY = {
		MIN_X = 8,
		MAX_X = 48,
		MIN_Z = -54.5,
		MAX_Z = -33,
		ROW_DEPTH = 5, -- rangées de dalles
		TILE_HEIGHT = 0.2,
		COLORS = { { 255, 205, 225 }, { 250, 238, 222 } },
		BORDER_COLOR = { 236, 233, 225 },
		HEDGE_COLOR = { 62, 140, 66 },
		HEDGE_HEIGHT = 3,
		SIGN_TEXT = "🥚 COUVOIR 🥚",
		SIGN_SIZE = { 16, 3 },
		SIGN_POST_HEIGHT = 12,
		SIGN_COLOR = { 122, 82, 52 },
	},
})
