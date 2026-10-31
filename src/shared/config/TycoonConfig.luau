--!strict
-- Usine Tycoon (CDC §7.1, §8 ; décisions A5 à A8, A16, A33). Montants en $, débits en $ bruts par seconde.
-- Positions en coordonnées locales de la base : +X vers le champ, Z latéral, origine au centre de la base.
local Freeze = require("../util/Freeze")

export type MachineDef = {
	id: string,
	name: string,
	price: number,
	multiplier: number,
	color: { number },
}

export type Spot = { x: number, z: number }
export type Zone = { name: string, minX: number, maxX: number, minZ: number, maxZ: number, color: { number } }

-- Décoration (A53) : purement esthétique, achetée une fois, conservée au Rebirth. `spots` : où la construire.
export type DecorDef = { id: string, name: string, price: number, spots: { Spot }, footprint: { number } }

return Freeze.deep({
	STARTING_MONEY = 0,
	SILO_CAPACITY = 250_000, -- A16 : le silo garde un plafond, même avec la Remorque Infinie

	-- Tapis roulant : le niveau 1 est offert, chaque niveau multiplie le débit (A33).
	CONVEYOR = {
		NAME = "Tapis Roulant",
		BASE_RATE = 2, -- $ bruts consommés par seconde au niveau 1
		RATE_GROWTH = 1.15, -- A51 : réglé par la simulation d'économie (docs/EQUILIBRAGE.md)
		BASE_PRICE = 50, -- A7 ; prix du niveau n+1 = 50 × 1,35^(n-1) (CDC §8)
		MAX_LEVEL = 40,
	},
	-- Machines achetées une fois ; leurs multiplicateurs se multiplient (A6, CDC §7 : ×1,5 / ×3 / ×8).
	-- Prix du Four et de l'Usine relevés par l'équilibrage (A51) : l'Usine ×8 à 40 000 $ bouclait le jeu en 1 h.
	MACHINES = {
		{ id = "Mill", name = "Moulin à Farine", price = 250, multiplier = 1.5, color = { 255, 255, 255 } },
		{ id = "Oven", name = "Four à Pain", price = 20_000, multiplier = 3, color = { 218, 133, 65 } },
		{
			id = "Factory",
			name = "Usine de Céréales Dorées",
			price = 400_000,
			multiplier = 8,
			color = { 245, 205, 48 },
		},
	} :: { MachineDef },
	-- Silo agrandissable (A53) : chaque niveau double sa capacité. Le niveau est conservé au Rebirth (comme le
	-- contenu du silo, A37). Plus de capacité = plus d'autonomie de l'usine entre deux récoltes.
	SILO_UPGRADE = {
		ID = "SiloUpgrade",
		NAME = "Silo Géant",
		PRICES = { 5_000, 60_000, 600_000, 6_000_000 },
		CAPACITY_GROWTH = 2,
	},
	-- Décorations (A53) : de quoi construire une base qui impressionne, du lampadaire à l'éolienne géante.
	-- Ordre = ordre des boutons ; `footprint` = emprise au sol (x, z) pour vérifier qu'elles ne se chevauchent pas.
	DECORATIONS = {
		{
			id = "Lamps",
			name = "Lampadaires",
			price = 750,
			spots = { -- de part et d'autre de l'allée centrale
				{ x = 6, z = -50 },
				{ x = 14, z = -50 },
				{ x = 6, z = -10 },
				{ x = 14, z = -10 },
				{ x = 6, z = 30 },
				{ x = 14, z = 30 },
			},
			footprint = { 2, 2 },
		},
		{
			id = "Flowers",
			name = "Parterres Fleuris",
			price = 2_500,
			spots = { { x = -54, z = -20 }, { x = -54, z = 0 }, { x = -54, z = 20 }, { x = -54, z = 40 } },
			footprint = { 4, 8 },
		},
		{ id = "Fountain", name = "Fontaine", price = 15_000, spots = { { x = 45, z = -44 } }, footprint = { 12, 12 } },
		{ id = "Flag", name = "Drapeau Géant", price = 60_000, spots = { { x = 52, z = 42 } }, footprint = { 2, 10 } },
		{
			id = "Statue",
			name = "Statue Dorée",
			price = 300_000,
			spots = { { x = 36, z = 28 } },
			footprint = { 6, 6 },
		},
		{ id = "Arch", name = "Arche Néon", price = 1_500_000, spots = { { x = 59, z = 0 } }, footprint = { 2, 30 } },
		{
			id = "Windmill",
			name = "Éolienne Géante",
			price = 6_000_000,
			spots = { { x = 48, z = -24 } },
			footprint = { 8, 8 },
		},
	} :: { DecorDef },
	GARAGE_NAME = "Garage", -- bouton d'achat du palier suivant (CDC §5)
	REBIRTH_NAME = "Rebirth",

	INCOME_INTERVAL = 1, -- CDC §8 : revenu calculé côté serveur chaque seconde
	PAD_CHECK_INTERVAL = 0.25,
	PURCHASE_COOLDOWN = 0.75, -- secondes entre deux achats d'un même joueur (rester sur un bouton n'achète pas en boucle)

	LAYOUT = {
		UNLOAD_PAD = { x = 46, z = 0, size = 22 }, -- « grille de déchargement » (CDC §7.1), côté champ
		SPAWN = { x = 26, z = -30 } :: Spot,
		PAD_SIZE = 10,
		PAD_THICKNESS = 0.4,
		PADS = {
			Conveyor = { x = 0, z = -40 },
			Mill = { x = 0, z = -20 },
			Oven = { x = 0, z = 0 },
			Factory = { x = 0, z = 20 },
			Garage = { x = 0, z = 40 },
			Rebirth = { x = 20, z = 40 }, -- CDC §7.3 : bouton Rebirth (A8)
			SiloUpgrade = { x = -20, z = -46 },
			-- Rangée des décorations, le long du bord de la base.
			Lamps = { x = -28, z = 53 },
			Flowers = { x = -16, z = 53 },
			Fountain = { x = -4, z = 53 },
			Flag = { x = 8, z = 53 },
			Statue = { x = 20, z = 53 },
			Arch = { x = 32, z = 53 },
			Windmill = { x = 44, z = 53 },
		} :: { [string]: Spot },
		SILO = { x = -42, z = -42, radius = 9, minHeight = 8, maxHeight = 80, levelHeight = 15 },
		CONVEYOR = { x = -42, fromZ = -30, toZ = 44, width = 6, height = 1 },
		MACHINE_SIZE = 10,
		MACHINES = {
			Mill = { x = -26, z = -10 },
			Oven = { x = -26, z = 14 },
			Factory = { x = -26, z = 38 },
		} :: { [string]: Spot },
		-- Zones au sol (A53) : dalles colorées bordées, pour une base lisible. Rectangles en coordonnées locales.
		ZONES = {
			{ name = "Factory", minX = -59, maxX = -15, minZ = -58, maxZ = 46, color = { 110, 115, 125 } },
			{ name = "Shop", minX = -8, maxX = 6, minZ = -56, maxZ = 46, color = { 205, 210, 218 } },
			{ name = "EggsSouth", minX = 14, maxX = 34, minZ = -58, maxZ = -4, color = { 255, 175, 215 } },
			{ name = "EggsNorth", minX = 14, maxX = 34, minZ = 4, maxZ = 22, color = { 255, 175, 215 } },
			{ name = "Garden", minX = -46, maxX = 52, minZ = 47, maxZ = 59, color = { 90, 170, 80 } },
		} :: { Zone },
		-- Allées pavées, un peu plus hautes que les zones (pas de faces au même niveau qui scintillent).
		AVENUES = {
			{ name = "Main", minX = 6, maxX = 14, minZ = -58, maxZ = 47, color = { 240, 238, 230 } },
			{ name = "ToUnload", minX = 14, maxX = 35, minZ = -4, maxZ = 4, color = { 240, 238, 230 } },
		} :: { Zone },
		ZONE_THICKNESS = 0.08,
		AVENUE_THICKNESS = 0.12,
		BORDER = { width = 0.6, height = 0.3, color = { 27, 42, 53 } },
		-- Panneaux de zone sur poteau ; `footprint` vérifié par le test du plan de la base.
		SIGNS = {
			{ text = "🏭 USINE", x = -30, z = -56 },
			{ text = "⭐ ACHATS", x = 0, z = -53 },
			{ text = "🥚 ŒUFS", x = 24, z = -55 },
			{ text = "🌷 DÉCO", x = -40, z = 53 },
		} :: { { text: string, x: number, z: number } },
		SIGN = { width = 7, height = 2.6, postHeight = 3.4, footprint = { 7, 1 } },
	},
	-- Boutons au sol façon grands tycoons (A53) : socle sombre, plaque colorée, anneau néon, panneau de prix.
	-- Un bouton épuisé (machine achetée, décoration construite…) disparaît, comme dans les tycoons classiques.
	PAD_STYLE = {
		RIM_MARGIN = 1.6, -- le socle dépasse de la plaque
		RIM_HEIGHT = 0.5,
		RING_WIDTH = 0.5,
		LABEL_SIZE = { 11, 4.4 }, -- panneau en studs : il rapetisse avec la distance
		LABEL_HEIGHT_ABOVE = 5.5,
		ICONS = {
			Conveyor = "⚙️",
			SiloUpgrade = "🛢️",
			Mill = "🌾",
			Oven = "🍞",
			Factory = "🏭",
			Garage = "🚜",
			Rebirth = "♻️",
			Lamps = "💡",
			Flowers = "🌷",
			Fountain = "⛲",
			Flag = "🚩",
			Statue = "🗿",
			Arch = "🌈",
			Windmill = "🌬️",
		} :: { [string]: string },
		-- Dégradé du panneau et couleur de l'anneau selon l'état du bouton.
		STATES = {
			affordable = { top = { 120, 230, 60 }, bottom = { 40, 165, 30 }, ring = { 120, 255, 120 } },
			expensive = { top = { 255, 110, 100 }, bottom = { 200, 30, 40 }, ring = { 255, 70, 70 } },
			rebirth = { top = { 210, 130, 255 }, bottom = { 120, 50, 210 }, ring = { 200, 120, 255 } },
			locked = { top = { 175, 175, 185 }, bottom = { 110, 110, 120 }, ring = { 140, 140, 150 } },
			info = { top = { 110, 175, 255 }, bottom = { 40, 95, 215 }, ring = { 110, 175, 255 } },
			unload = { top = { 255, 230, 90 }, bottom = { 255, 150, 20 }, ring = { 255, 220, 60 } },
			egg = { top = { 255, 140, 200 }, bottom = { 170, 60, 210 }, ring = { 255, 140, 200 } },
		} :: { [string]: { top: { number }, bottom: { number }, ring: { number } } },
	},
	BUILD_ANIM_ATTRIBUTE = "BuiltAt", -- heure serveur de construction : le client anime l'arrivée des briques
	PAD_TAG = "TycoonPad", -- boutons repérés par les flèches de guidage (attributs ButtonId, OwnerId, Price, State)
	UNLOAD_TAG = "UnloadPad",
	GUIDE_UNLOAD_KEY = "Unload", -- premier déchargement fait : les flèches n'y ramènent plus (A53)

	-- Étiquettes flottantes au-dessus des boutons et des machines.
	LABEL = { MAX_DISTANCE = 110 }, -- au-delà, les panneaux disparaissent (moins de fouillis vu de loin)
	COLORS = {
		UNLOAD_PAD = { 245, 205, 48 },
		SILO = { 248, 248, 248 },
		CONVEYOR = { 27, 42, 53 },
	} :: { [string]: { number } },
})
