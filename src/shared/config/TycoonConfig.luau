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
		} :: { [string]: Spot },
		SILO = { x = -42, z = -42, radius = 9, minHeight = 8, maxHeight = 80 },
		CONVEYOR = { x = -42, fromZ = -30, toZ = 50, width = 6, height = 1 },
		MACHINE_SIZE = 10,
		MACHINES = {
			Mill = { x = -26, z = -10 },
			Oven = { x = -26, z = 14 },
			Factory = { x = -26, z = 38 },
		} :: { [string]: Spot },
	},
	-- Étiquettes flottantes au-dessus des boutons et des machines.
	LABEL = { WIDTH = 220, HEIGHT = 60, HEIGHT_ABOVE = 5, MAX_DISTANCE = 150 },
	COLORS = {
		PAD_AFFORDABLE = { 75, 151, 75 },
		PAD_TOO_EXPENSIVE = { 196, 40, 28 },
		PAD_SOLD_OUT = { 99, 95, 98 },
		PAD_REBIRTH = { 98, 37, 209 },
		UNLOAD_PAD = { 245, 205, 48 },
		SILO = { 248, 248, 248 },
		CONVEYOR = { 27, 42, 53 },
	} :: { [string]: { number } },
})
