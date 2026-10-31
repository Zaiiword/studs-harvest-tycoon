--!strict
-- Boucles de rétention (CDC §7.4, décisions A44 à A46) : cadeaux de temps de jeu, Roue de la Fortune
-- quotidienne, quêtes de destruction quotidiennes et statues de classement.
local Freeze = require("../util/Freeze")

export type Reward = {
	money: number?,
	gems: number?,
	item: string?, -- id d'objet de l'inventaire (sabotage ou Œuf Légendaire)
	count: number?,
}

export type Gift = { minutes: number, reward: Reward }

export type WheelSegment = { label: string, weight: number, reward: Reward, color: { number } }

export type QuestDef = {
	id: string,
	label: string,
	stat: string, -- statistique suivie (voir STATS)
	target: number,
	reward: Reward,
}

return Freeze.deep({
	-- CDC §7.4 : 9 cadeaux qui se débloquent entre 2 et 60 minutes de présence (par session, A44).
	GIFTS = {
		{ minutes = 2, reward = { money = 250 } },
		{ minutes = 5, reward = { money = 1_000 } },
		{ minutes = 10, reward = { gems = 3 } },
		{ minutes = 15, reward = { item = "Mud", count = 2 } },
		{ minutes = 20, reward = { money = 5_000 } },
		{ minutes = 30, reward = { gems = 10 } },
		{ minutes = 40, reward = { item = "Glove", count = 2 } },
		{ minutes = 50, reward = { money = 25_000 } },
		{ minutes = 60, reward = { item = "LegendaryEgg", count = 1 } },
	} :: { Gift },

	-- Roue de la Fortune : un tour gratuit toutes les 24 h (A45). Chances affichées sur la roue.
	WHEEL_COOLDOWN_SECONDS = 24 * 3600,
	WHEEL = {
		{ label = "500 $", weight = 30, reward = { money = 500 }, color = { 75, 151, 75 } },
		{ label = "2 000 $", weight = 22, reward = { money = 2_000 }, color = { 13, 105, 172 } },
		{ label = "5 💎", weight = 18, reward = { gems = 5 }, color = { 98, 37, 209 } },
		{ label = "2 🟫", weight = 10, reward = { item = "Mud", count = 2 }, color = { 105, 64, 40 } },
		{ label = "🥊", weight = 8, reward = { item = "Glove", count = 1 }, color = { 196, 40, 28 } },
		{ label = "10 000 $", weight = 7, reward = { money = 10_000 }, color = { 245, 205, 48 } },
		{ label = "20 💎", weight = 3, reward = { gems = 20 }, color = { 255, 89, 89 } },
		{
			label = "🥚 Légendaire",
			weight = 2,
			reward = { item = "LegendaryEgg", count = 1 },
			color = { 255, 176, 0 },
		},
	} :: { WheelSegment },

	-- Quêtes de destruction (CDC §7.4) : 3 quêtes par jour, tirées du catalogue selon la date (A46).
	QUESTS_PER_DAY = 3,
	QUESTS = {
		{ id = "Harvest", label = "Couper 300 blés", stat = "harvested", target = 300, reward = { money = 2_000 } },
		{ id = "Corn", label = "Couper 80 Maïs Dorés", stat = "corn", target = 80, reward = { gems = 5 } },
		{ id = "Diamond", label = "Couper 25 Blés Diamant", stat = "diamond", target = 25, reward = { gems = 10 } },
		{
			id = "Bumper",
			label = "Éjecter 3 rivaux",
			stat = "ejections",
			target = 3,
			reward = { item = "Glove", count = 1 },
		},
		{
			id = "Unload",
			label = "Décharger 8 fois au silo",
			stat = "unloads",
			target = 8,
			reward = { money = 3_000 },
		},
		{
			id = "Boss",
			label = "Infliger 2 000 dégâts au boss",
			stat = "bossDamage",
			target = 2_000,
			reward = { gems = 8 },
		},
	} :: { QuestDef },

	-- Statistiques suivies, sauvegardées, et utilisées par les statues (CDC §7.4).
	STATS = { "harvested", "corn", "diamond", "ejections", "unloads", "bossDamage", "earned" } :: { string },
	-- Devant les bases centrales, face aux ponts : tout le monde passe devant (coordonnées monde).
	STATUES = {
		{ id = "Money", label = "💰 Top $", stat = "earned", x = -10, z = 0 },
		{ id = "Harvest", label = "🌾 Top Récolte", stat = "harvested", x = -10, z = -40 },
		{ id = "Bumper", label = "💥 Roi du Pare-Chocs", stat = "ejections", x = -10, z = 40 },
	},
	STATUE_CLEARANCE = 15, -- aucun arbre à moins de 15 studs d'une statue
	LEADERBOARD_REFRESH_SECONDS = 120,
	LEADERBOARD_STORE_PREFIX = "Leaderboard_v1_",
})
