--!strict
-- Usine Tycoon (CDC §7.1, §8 ; décisions A5 à A8, A16, A33, A53, A56). Montants en $, débits en $ bruts par seconde.
-- Positions en coordonnées locales de la base : +X vers le champ, Z latéral, origine au centre de la base.
local Freeze = require("../util/Freeze")

export type MachineDef = {
	id: string,
	name: string,
	price: number,
	multiplier: number,
	color: { number },
	size: number?, -- côté du modèle (LAYOUT.MACHINE_SIZE par défaut)
	chute: number?, -- longueur de la goulotte qui relie le tapis à la machine
}

export type Spot = { x: number, z: number, level: number? } -- level 1 : à l'étage de la grange

-- Élément du plan de construction de la ferme (A56) : conservé au Rebirth, révélé quand le précédent est acheté.
-- Ses briques sont décrites par FarmBlueprint. `fadesInside` : s'efface quand on est dans la grange (toit).
export type DecorDef = { id: string, name: string, price: number, fadesInside: boolean? }

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
	-- Machines achetées une fois, dans l'ordre ; leurs multiplicateurs se multiplient (A6, CDC §7 : ×1,5 / ×3 / ×8).
	-- Prix du Four et de l'Usine relevés par l'équilibrage (A51) : l'Usine ×8 à 40 000 $ bouclait le jeu en 1 h.
	MACHINES = {
		{ id = "Mill", name = "Moulin à Farine", price = 250, multiplier = 1.5, color = { 255, 255, 255 }, chute = 5 },
		{ id = "Oven", name = "Four à Pain", price = 20_000, multiplier = 3, color = { 218, 133, 65 }, chute = 5 },
		{
			id = "Factory",
			name = "Usine de Céréales Dorées",
			price = 400_000,
			multiplier = 8,
			color = { 245, 205, 48 },
			chute = 5,
		},
	} :: { MachineDef },
	-- Chaîne de l'étage (A56) : débloquée par le toit et l'Usine, remise à zéro au Rebirth comme les autres machines,
	-- mais pas exigée pour le Rebirth.
	UPPER_MACHINES = {
		{
			id = "Dryer",
			name = "Séchoir à Grains",
			price = 1_500_000,
			multiplier = 1.5,
			color = { 90, 150, 200 },
			size = 8,
			chute = 1.5,
		},
		{
			id = "Press",
			name = "Presse à Flocons",
			price = 6_000_000,
			multiplier = 2,
			color = { 200, 90, 60 },
			size = 8,
			chute = 1.5,
		},
		{
			id = "Packer",
			name = "Emballeuse Dorée",
			price = 20_000_000,
			multiplier = 3,
			color = { 245, 205, 48 },
			size = 8,
			chute = 1.5,
		},
	} :: { MachineDef },
	UPPER_REQUIRES = { machine = "Factory", decor = "Roof" }, -- ce qui ouvre la chaîne de l'étage
	-- Silo agrandissable (A53) : chaque niveau double sa capacité. Le niveau est conservé au Rebirth (comme le
	-- contenu du silo, A37). Plus de capacité = plus d'autonomie de l'usine entre deux récoltes.
	SILO_UPGRADE = {
		ID = "SiloUpgrade",
		NAME = "Silo Géant",
		PRICES = { 5_000, 60_000, 600_000, 6_000_000 },
		CAPACITY_GROWTH = 2,
		REQUIRES = "Mill", -- n'apparaît qu'après le premier achat important
	},
	-- Plan de construction de la ferme (A56) : un seul bouton à la fois, dans cet ordre. On pose le terrain, on bâtit
	-- la grange mur par mur, on aménage la cour, puis l'escalier et le toit ouvrent l'étage ; le reste est du prestige.
	DECORATIONS = {
		{ id = "Path", name = "Chemin Pavé", price = 100 },
		{ id = "BarnFloor", name = "Plancher de la Grange", price = 250 },
		{ id = "WallBack", name = "Mur du Fond", price = 500 },
		{ id = "WallSouth", name = "Mur Sud", price = 800 },
		{ id = "WallNorth", name = "Mur Nord", price = 1_200 },
		{ id = "Facade", name = "Façade de la Grange", price = 2_000 },
		{ id = "Doors", name = "Grandes Portes", price = 3_000 },
		{ id = "Windows", name = "Fenêtres", price = 5_000 },
		{ id = "Lanterns", name = "Lanternes", price = 8_000 },
		{ id = "Mailbox", name = "Boîte aux Lettres", price = 10_000 },
		{ id = "Flowers", name = "Parterres Fleuris", price = 14_000 },
		{ id = "Lamps", name = "Lampadaires", price = 18_000 },
		{ id = "Bench", name = "Banc", price = 22_000 },
		{ id = "Hay", name = "Bottes de Foin", price = 27_000 },
		{ id = "Trees", name = "Pommiers", price = 35_000 },
		{ id = "Garden", name = "Potager", price = 45_000 },
		{ id = "Well", name = "Puits", price = 55_000 },
		{ id = "Pumpkins", name = "Carré de Citrouilles", price = 70_000 },
		{ id = "Fountain", name = "Fontaine", price = 85_000 },
		{ id = "Cart", name = "Charrette", price = 105_000 },
		{ id = "Scarecrow", name = "Épouvantail", price = 130_000 },
		{ id = "Pen", name = "Enclos à Cochons", price = 150_000 },
		{ id = "Stairs", name = "Escalier", price = 175_000 },
		{ id = "Loft", name = "Plancher de l'Étage", price = 250_000 },
		{ id = "UpperWalls", name = "Murs de l'Étage", price = 400_000 },
		{ id = "Roof", name = "Toit de la Grange", price = 700_000, fadesInside = true },
		{ id = "Cupola", name = "Clocheton et Girouette", price = 1_000_000, fadesInside = true },
		{ id = "Flag", name = "Drapeau Géant", price = 1_500_000 },
		{ id = "Coop", name = "Poulailler", price = 2_000_000 },
		{ id = "Beehives", name = "Ruches", price = 2_500_000 },
		{ id = "Greenhouse", name = "Serre", price = 3_000_000 },
		{ id = "Statue", name = "Statue Dorée", price = 4_500_000 },
		{ id = "Arch", name = "Arche Néon", price = 6_500_000 },
		{ id = "Windmill", name = "Éolienne Géante", price = 10_000_000 },
	} :: { DecorDef },
	GARAGE_NAME = "Garage", -- bouton d'achat du palier suivant (CDC §5)
	REBIRTH_NAME = "Rebirth",

	INCOME_INTERVAL = 1, -- CDC §8 : revenu calculé côté serveur chaque seconde
	PAD_CHECK_INTERVAL = 0.25,
	PURCHASE_COOLDOWN = 0.75, -- secondes entre deux achats d'un même joueur (rester sur un bouton n'achète pas en boucle)

	LAYOUT = {
		UNLOAD_PAD = { x = 46, z = 0, size = 22 }, -- « grille de déchargement » (CDC §7.1), côté champ
		SPAWN = { x = 28, z = -16 } :: Spot,
		PAD_SIZE = 10,
		PAD_THICKNESS = 0.4,
		LOFT_TOP = 21, -- hauteur du plancher de l'étage au-dessus du pont
		-- Boutons au sol. Le plan de construction n'en montre qu'un à la fois : ils se relaient sur le chemin
		-- devant la grange, ou à l'intérieur pour ce qui se construit dedans.
		PADS = {
			Conveyor = { x = 10, z = -16 },
			Garage = { x = 10, z = 16 },
			Rebirth = { x = 16, z = 34 }, -- CDC §7.3 : bouton Rebirth (A8)
			SiloUpgrade = { x = -18, z = -46 },
			Mill = { x = -16, z = -20 },
			Oven = { x = -16, z = -2 },
			Factory = { x = -16, z = 16 },
			Dryer = { x = -29, z = -20, level = 1 },
			Press = { x = -29, z = -2, level = 1 },
			Packer = { x = -29, z = 14, level = 1 },
			Path = { x = 24, z = 0 },
			BarnFloor = { x = -6, z = 0 },
			WallBack = { x = -6, z = -14 },
			WallSouth = { x = -6, z = 14 },
			WallNorth = { x = -6, z = 0 },
			Facade = { x = 14, z = 0 },
			Doors = { x = 24, z = 0 },
			Windows = { x = 14, z = 0 },
			Lanterns = { x = 24, z = 0 },
			Mailbox = { x = 14, z = 0 },
			Flowers = { x = 24, z = 0 },
			Lamps = { x = 14, z = 0 },
			Bench = { x = 24, z = 0 },
			Hay = { x = 14, z = 0 },
			Trees = { x = 24, z = 0 },
			Garden = { x = 14, z = 0 },
			Well = { x = 24, z = 0 },
			Pumpkins = { x = 14, z = 0 },
			Fountain = { x = 24, z = 0 },
			Cart = { x = 14, z = 0 },
			Scarecrow = { x = 24, z = 0 },
			Pen = { x = 14, z = 0 },
			Stairs = { x = -6, z = 14 },
			Loft = { x = -6, z = -14 },
			UpperWalls = { x = -6, z = 0 },
			Roof = { x = 14, z = 0 },
			Cupola = { x = 24, z = 0 },
			Flag = { x = 14, z = 0 },
			Coop = { x = 24, z = 0 },
			Beehives = { x = 14, z = 0 },
			Greenhouse = { x = 24, z = 0 },
			Statue = { x = 14, z = 0 },
			Arch = { x = 24, z = 0 },
			Windmill = { x = 14, z = 0 },
		} :: { [string]: Spot },
		SILO = { x = -46, z = -46, radius = 9, minHeight = 8, maxHeight = 80, levelHeight = 15 },
		CONVEYOR = { x = -46, fromZ = -37, toZ = 26, width = 6, height = 1 },
		MACHINE_SIZE = 10,
		-- Panneau d'une machine : devant elle (ailes comprises) et sous le plancher de l'étage. Au-dessus, il serait
		-- caché par la machine elle-même ou par le plancher.
		MACHINE_LABEL = { FRONT = 2.5, HEIGHT = 11 },
		MACHINES = {
			Mill = { x = -33, z = -20 },
			Oven = { x = -33, z = -2 },
			Factory = { x = -33, z = 16 },
			Dryer = { x = -40, z = -20, level = 1 },
			Press = { x = -40, z = -2, level = 1 },
			Packer = { x = -40, z = 14, level = 1 },
		} :: { [string]: Spot },
		BORDER = { width = 0.6, height = 0.3, color = { 27, 42, 53 } }, -- cadre de la grille de déchargement
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
			Dryer = "♨️",
			Press = "⚙️",
			Packer = "📦",
			Path = "🧱",
			BarnFloor = "🟫",
			WallBack = "🧱",
			WallSouth = "🧱",
			WallNorth = "🧱",
			Facade = "🏠",
			Doors = "🚪",
			Windows = "🖼️",
			Lanterns = "🏮",
			Flowers = "🌷",
			Lamps = "💡",
			Hay = "🌾",
			Trees = "🍎",
			Well = "💧",
			Fountain = "⛲",
			Cart = "🛒",
			Scarecrow = "👒",
			Mailbox = "📬",
			Bench = "💺",
			Garden = "🥕",
			Pumpkins = "🎃",
			Pen = "🐷",
			Beehives = "🐝",
			Stairs = "⬆️",
			Loft = "🟫",
			UpperWalls = "🧱",
			Roof = "🏚️",
			Cupola = "🐓",
			Flag = "🚩",
			Coop = "🐔",
			Greenhouse = "🌱",
			Statue = "🗿",
			Arch = "🌈",
			Windmill = "🌬️",
		} :: { [string]: string },
		-- Dégradé du panneau et couleur de l'anneau selon l'état du bouton.
		STATES = {
			affordable = { top = { 120, 230, 60 }, bottom = { 40, 165, 30 }, ring = { 70, 190, 70 } },
			expensive = { top = { 255, 110, 100 }, bottom = { 200, 30, 40 }, ring = { 195, 50, 50 } },
			rebirth = { top = { 210, 130, 255 }, bottom = { 120, 50, 210 }, ring = { 140, 85, 195 } },
			info = { top = { 110, 175, 255 }, bottom = { 40, 95, 215 }, ring = { 80, 130, 200 } },
			unload = { top = { 255, 230, 90 }, bottom = { 255, 150, 20 }, ring = { 210, 170, 50 } },
			egg = { top = { 255, 140, 200 }, bottom = { 170, 60, 210 }, ring = { 200, 100, 155 } },
		} :: { [string]: { top: { number }, bottom: { number }, ring: { number } } },
	},
	BUILD_ANIM_ATTRIBUTE = "BuiltAt", -- heure serveur de construction : le client anime l'arrivée des briques
	FADE_ATTRIBUTE = "FadesInside", -- s'efface pour le joueur qui est dans la grange (toit, clocheton)
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
