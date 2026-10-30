--!strict
-- Objets de sabotage (CDC §6 « Fling Items », §9 Bazooka ; décisions A13, A41).
-- Tous respectent la bulle d'immunité de 15 s et les zones sécurisées (A29) : on ne peut pas enchaîner
-- les éjections sur un même joueur (conformité Roblox, docs/ANALYSE_CDC.md §4).
local Freeze = require("../util/Freeze")

export type ItemDef = {
	id: string,
	name: string,
	icon: string,
	gemPrice: number?, -- nil : non vendu en gemmes (Robux au Sprint 8)
	chargesPerPurchase: number,
}

return Freeze.deep({
	ITEMS = {
		{ id = "Mud", name = "Flaque de Boue", icon = "🟫", gemPrice = 5, chargesPerPurchase = 1 },
		{ id = "Glove", name = "Gant de Boxe", icon = "🥊", gemPrice = 8, chargesPerPurchase = 1 },
		{ id = "Dynamite", name = "Onde de Choc", icon = "🧨", gemPrice = 12, chargesPerPurchase = 1 },
		{ id = "Bazooka", name = "Bazooka Éjecteur", icon = "🚀", gemPrice = nil, chargesPerPurchase = 3 },
	} :: { ItemDef },
	-- Objets qu'on garde sans les utiliser (récompenses), sauvegardés avec l'inventaire.
	TROPHIES = { LegendaryEgg = true } :: { [string]: boolean },

	MUD = {
		RADIUS = 7,
		LIFETIME_SECONDS = 45,
		SPIN_SECONDS = 3, -- CDC §6 : « tourner sur eux-mêmes pendant 3 secondes »
		CHECK_INTERVAL = 0.2,
		COLOR = { 105, 64, 40 },
		MAX_PER_PLAYER = 2,
	},
	GLOVE = { RANGE = 10, EJECT_DISTANCE = 80 }, -- A13 : portée de contact, éjection à 80 studs
	BAZOOKA = { RANGE = 60, CONE_DEGREES = 25, EJECT_DISTANCE = 120 }, -- A13 : 60 studs, ligne de vue
	DYNAMITE = { RAINBOW_RANGE = 30, RADIUS = 25, EJECT_DISTANCE = 60 }, -- autour d'un Blé Arc-en-ciel

	EJECT_VERTICAL_SPEED = 45, -- studs/s ; la vitesse horizontale en découle pour parcourir la distance voulue
	USE_COOLDOWN = 1, -- secondes entre deux objets d'un même joueur
	MAX_STACK = 99,
})
