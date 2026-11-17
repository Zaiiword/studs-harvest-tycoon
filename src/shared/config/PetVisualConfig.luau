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

export type EggLook = { spots: number, spotColor: { number }, beltColor: { number }?, glowColor: { number } }

local BLACK, WHITE = { 27, 42, 53 }, { 248, 248, 248 }
local PINK, DARK_PINK = { 255, 170, 190 }, { 240, 120, 155 }

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
		Pig = merge({
			{ size = { 1.8, 1.3, 2.2 }, offset = { 0, 0.95, 0.1 }, color = PINK, isMain = true },
			{ size = { 1.3, 1.2, 1.0 }, offset = { 0, 1.25, -1.15 }, color = PINK, isMain = true },
			{ size = { 0.7, 0.5, 0.25 }, offset = { 0, 1.05, -1.75 }, color = DARK_PINK },
			{ size = { 0.12, 0.15, 0.05 }, offset = { -0.15, 1.05, -1.9 }, color = { 120, 50, 70 } },
			{ size = { 0.12, 0.15, 0.05 }, offset = { 0.15, 1.05, -1.9 }, color = { 120, 50, 70 } },
			{ size = { 0.35, 0.35, 0.15 }, offset = { -0.4, 1.95, -1.0 }, color = DARK_PINK },
			{ size = { 0.35, 0.35, 0.15 }, offset = { 0.4, 1.95, -1.0 }, color = DARK_PINK },
			{ size = { 0.4, 0.4, 0.4 }, offset = { -0.55, 0.2, -0.6 }, color = PINK },
			{ size = { 0.4, 0.4, 0.4 }, offset = { 0.55, 0.2, -0.6 }, color = PINK },
			{ size = { 0.4, 0.4, 0.4 }, offset = { -0.55, 0.2, 0.75 }, color = PINK },
			{ size = { 0.4, 0.4, 0.4 }, offset = { 0.55, 0.2, 0.75 }, color = PINK },
			{ size = { 0.15, 0.15, 0.4 }, offset = { 0, 1.3, 1.35 }, color = DARK_PINK },
		}, eyes(1.45, -1.66, 0.3)),
		Bunny = merge({
			{ size = { 1.4, 1.3, 1.6 }, offset = { 0, 0.85, 0.2 }, color = WHITE, isMain = true },
			{ size = { 1.2, 1.1, 1.1 }, offset = { 0, 1.75, -0.55 }, color = WHITE, isMain = true },
			{ size = { 0.3, 1.2, 0.25 }, offset = { -0.3, 2.85, -0.5 }, color = WHITE, isMain = true },
			{ size = { 0.3, 1.2, 0.25 }, offset = { 0.3, 2.85, -0.5 }, color = WHITE, isMain = true },
			{ size = { 0.15, 0.8, 0.05 }, offset = { -0.3, 2.85, -0.64 }, color = DARK_PINK },
			{ size = { 0.15, 0.8, 0.05 }, offset = { 0.3, 2.85, -0.64 }, color = DARK_PINK },
			{ size = { 0.2, 0.15, 0.1 }, offset = { 0, 1.6, -1.15 }, color = DARK_PINK },
			{ size = { 0.6, 0.6, 0.6 }, offset = { 0, 1.0, 1.1 }, color = WHITE, shape = "Ball" },
			{ size = { 0.4, 0.25, 0.7 }, offset = { -0.4, 0.13, -0.5 }, color = WHITE },
			{ size = { 0.4, 0.25, 0.7 }, offset = { 0.4, 0.13, -0.5 }, color = WHITE },
		}, eyes(1.9, -1.11, 0.3)),
		Sheep = merge({
			{ size = { 2.0, 1.5, 2.4 }, offset = { 0, 1.25, 0.2 }, color = WHITE, isMain = true },
			{ size = { 1.4, 0.5, 1.8 }, offset = { 0, 2.1, 0.2 }, color = WHITE, isMain = true },
			{ size = { 0.9, 1.0, 0.9 }, offset = { 0, 1.5, -1.3 }, color = BLACK },
			{ size = { 1.0, 0.35, 0.6 }, offset = { 0, 2.1, -1.25 }, color = WHITE, isMain = true },
			{ size = { 0.5, 0.2, 0.3 }, offset = { -0.65, 1.7, -1.2 }, color = BLACK },
			{ size = { 0.5, 0.2, 0.3 }, offset = { 0.65, 1.7, -1.2 }, color = BLACK },
			{ size = { 0.35, 0.6, 0.35 }, offset = { -0.55, 0.3, -0.55 }, color = BLACK },
			{ size = { 0.35, 0.6, 0.35 }, offset = { 0.55, 0.3, -0.55 }, color = BLACK },
			{ size = { 0.35, 0.6, 0.35 }, offset = { -0.55, 0.3, 0.95 }, color = BLACK },
			{ size = { 0.35, 0.6, 0.35 }, offset = { 0.55, 0.3, 0.95 }, color = BLACK },
			{ size = { 0.25, 0.25, 0.1 }, offset = { -0.22, 1.65, -1.77 }, color = WHITE },
			{ size = { 0.25, 0.25, 0.1 }, offset = { 0.22, 1.65, -1.77 }, color = WHITE },
		}),
		Bee = {
			{ size = { 1.4, 1.4, 2.2 }, offset = { 0, 1.4, 0.1 }, color = { 245, 205, 48 }, isMain = true },
			{ size = { 1.45, 1.45, 0.35 }, offset = { 0, 1.4, 0.1 }, color = BLACK },
			{ size = { 1.45, 1.45, 0.35 }, offset = { 0, 1.4, 0.8 }, color = BLACK },
			{ size = { 1.1, 1.1, 0.8 }, offset = { 0, 1.6, -1.25 }, color = BLACK },
			{ size = { 0.2, 0.2, 0.5 }, offset = { 0, 1.3, 1.45 }, color = BLACK },
			{ size = { 0.15, 1.0, 1.2 }, offset = { -0.85, 2.3, 0.1 }, color = { 200, 240, 255 }, material = "Glass" },
			{ size = { 0.15, 1.0, 1.2 }, offset = { 0.85, 2.3, 0.1 }, color = { 200, 240, 255 }, material = "Glass" },
			{ size = { 0.12, 0.6, 0.12 }, offset = { -0.3, 2.35, -1.45 }, color = BLACK },
			{ size = { 0.12, 0.6, 0.12 }, offset = { 0.3, 2.35, -1.45 }, color = BLACK },
			{ size = { 0.35, 0.35, 0.1 }, offset = { -0.28, 1.75, -1.67 }, color = WHITE },
			{ size = { 0.35, 0.35, 0.1 }, offset = { 0.28, 1.75, -1.67 }, color = WHITE },
		},
		Unicorn = merge({
			{ size = { 1.5, 1.3, 2.4 }, offset = { 0, 1.45, 0.2 }, color = WHITE, isMain = true },
			{ size = { 0.4, 0.8, 0.4 }, offset = { -0.45, 0.4, -0.65 }, color = WHITE, isMain = true },
			{ size = { 0.4, 0.8, 0.4 }, offset = { 0.45, 0.4, -0.65 }, color = WHITE, isMain = true },
			{ size = { 0.4, 0.8, 0.4 }, offset = { -0.45, 0.4, 1.0 }, color = WHITE, isMain = true },
			{ size = { 0.4, 0.8, 0.4 }, offset = { 0.45, 0.4, 1.0 }, color = WHITE, isMain = true },
			{ size = { 0.8, 0.9, 0.8 }, offset = { 0, 2.2, -0.85 }, color = WHITE, isMain = true },
			{ size = { 0.9, 0.8, 1.3 }, offset = { 0, 2.7, -1.35 }, color = WHITE, isMain = true },
			{ size = { 0.22, 0.8, 0.22 }, offset = { 0, 3.45, -1.55 }, color = { 255, 196, 0 }, material = "Neon" },
			{ size = { 0.3, 0.45, 0.35 }, offset = { 0, 3.0, -0.75 }, color = { 255, 89, 89 } },
			{ size = { 0.3, 0.45, 0.35 }, offset = { 0, 2.6, -0.5 }, color = { 255, 176, 0 } },
			{ size = { 0.3, 0.45, 0.35 }, offset = { 0, 2.2, -0.3 }, color = { 13, 105, 172 } },
			{ size = { 0.3, 0.9, 0.3 }, offset = { 0, 1.4, 1.55 }, color = { 98, 37, 209 } },
		}, eyes(2.85, -2.01, 0.3)),
		Golem = {
			{ size = { 1.8, 1.8, 1.4 }, offset = { 0, 1.55, 0 }, color = { 128, 230, 255 }, isMain = true },
			{ size = { 1.1, 1.0, 1.0 }, offset = { 0, 2.95, -0.1 }, color = { 128, 230, 255 }, isMain = true },
			{ size = { 0.6, 1.4, 0.6 }, offset = { -1.25, 1.45, 0 }, color = { 100, 200, 235 }, isMain = true },
			{ size = { 0.6, 1.4, 0.6 }, offset = { 1.25, 1.45, 0 }, color = { 100, 200, 235 }, isMain = true },
			{ size = { 0.6, 0.65, 0.6 }, offset = { -0.5, 0.33, 0 }, color = { 100, 200, 235 } },
			{ size = { 0.6, 0.65, 0.6 }, offset = { 0.5, 0.33, 0 }, color = { 100, 200, 235 } },
			{ size = { 0.4, 0.8, 0.4 }, offset = { -0.6, 2.7, 0.4 }, color = { 98, 37, 209 }, material = "Neon" },
			{ size = { 0.35, 0.6, 0.35 }, offset = { 0.6, 2.6, 0.45 }, color = { 255, 89, 200 }, material = "Neon" },
			{ size = { 0.3, 0.7, 0.3 }, offset = { 0, 3.75, 0.15 }, color = { 128, 230, 255 }, material = "Neon" },
			{ size = { 0.6, 0.6, 0.1 }, offset = { 0, 1.6, -0.72 }, color = { 255, 176, 0 }, material = "Neon" },
			{ size = { 0.3, 0.2, 0.1 }, offset = { -0.25, 3.05, -0.62 }, color = WHITE, material = "Neon" },
			{ size = { 0.3, 0.2, 0.1 }, offset = { 0.25, 3.05, -0.62 }, color = WHITE, material = "Neon" },
		},
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
		STRAW_DARK_COLOR = { 214, 170, 66 },
		RIM_COLOR = { 15, 35, 90 },
		RIM_HEIGHT = 0.3, -- au-dessus des dalles du couvoir : deux faces au même niveau scintillent
		-- Nid (A69) : une couronne de brins de paille autour de l'œuf, qui flotte au-dessus d'un halo lumineux.
		NEST_TWIGS = 10,
		NEST_RADIUS = 3.1,
		EGG_HOVER = 0.9, -- hauteur de l'œuf au-dessus de la paille
		HALO_DIAMETER = 6.4,
		LIGHT_RANGE = 14,
		LIGHT_BRIGHTNESS = 1.1,
		SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds",
		SPARKLE_RATE = 7,
		BOB = { height = 0.35, period = 2.6, tilt = 5 },
	},
	-- Motifs des œufs (A69) : taches en relief, ceinture pour les œufs précieux, couleur du halo.
	EGG_REFLECTANCE = 0.06,
	EGG_LOOKS = {
		Default = { spots = 9, spotColor = { 200, 200, 210 }, glowColor = { 255, 255, 255 } },
		BasicEgg = { spots = 9, spotColor = { 150, 205, 255 }, glowColor = { 170, 220, 255 } },
		FarmEgg = { spots = 9, spotColor = { 75, 170, 80 }, glowColor = { 255, 225, 110 } },
		RebirthEgg = {
			spots = 11,
			spotColor = { 120, 230, 255 },
			beltColor = { 255, 215, 70 },
			glowColor = { 190, 120, 255 },
		},
		LegendaryEgg = {
			spots = 11,
			spotColor = { 255, 250, 220 },
			beltColor = { 220, 40, 40 },
			glowColor = { 255, 190, 60 },
		},
	} :: { [string]: EggLook },
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
		SIGN_TEXT = "COUVOIR",
		SIGN_SIZE = { 16, 3 },
		SIGN_POST_HEIGHT = 12,
		SIGN_COLOR = { 122, 82, 52 },
	},
})
