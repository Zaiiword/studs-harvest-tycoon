--!strict
-- Pets cubiques (CDC §7.2, §8 ; décisions A1, A2, A9, A17, A42, A43).
local Freeze = require("../util/Freeze")

export type RarityDef = {
	id: string,
	name: string,
	bonus: number, -- CDC §8
	color: { number },
	isAnnounced: boolean, -- annonce dans le chat du serveur (Secret Mythique)
}

export type SpeciesDef = {
	id: string,
	name: string,
	rarity: string,
}

export type EggDef = {
	id: string,
	name: string,
	currency: "money" | "gems" | "item", -- « item » : œuf gagné (inventaire), ouvert depuis le menu
	price: number,
	odds: { [string]: number }, -- rareté → poids (en %)
	color: { number },
}

export type VariantDef = { id: string, name: string, multiplier: number }

return Freeze.deep({
	-- Ordre du plus commun au plus rare.
	RARITIES = {
		{ id = "Common", name = "Commun", bonus = 1.2, color = { 163, 162, 165 }, isAnnounced = false },
		{ id = "Rare", name = "Rare", bonus = 1.6, color = { 13, 105, 172 }, isAnnounced = false },
		{ id = "Epic", name = "Épique", bonus = 2.5, color = { 98, 37, 209 }, isAnnounced = false },
		{ id = "Legendary", name = "Légendaire", bonus = 5, color = { 245, 205, 48 }, isAnnounced = false },
		{ id = "Mythic", name = "Secret Mythique", bonus = 15, color = { 255, 89, 89 }, isAnnounced = true },
	} :: { RarityDef },

	-- Un pet par rareté (CDC §7.2 ; le cinquième, pour le Secret Mythique, est la décision A43).
	SPECIES = {
		{ id = "Chick", name = "Poussin Carré", rarity = "Common" },
		{ id = "Cow", name = "Vache Cubique", rarity = "Rare" },
		{ id = "Tractor", name = "Tracteur Vivant", rarity = "Epic" },
		{ id = "Dragon", name = "Dragon Doré", rarity = "Legendary" },
		{ id = "Phoenix", name = "Phénix Arc-en-ciel", rarity = "Mythic" },
	} :: { SpeciesDef },

	-- A9 + A42 : l'œuf de base suit exactement la table du CDC §8 ; les œufs plus chers retirent les raretés basses.
	EGGS = {
		{
			id = "BasicEgg",
			name = "Œuf Basique",
			currency = "money",
			price = 500,
			odds = { Common = 60, Rare = 25, Epic = 10, Legendary = 4.9, Mythic = 0.1 },
			color = { 248, 248, 248 },
		},
		{
			id = "FarmEgg",
			name = "Œuf de Ferme",
			currency = "money",
			price = 25_000,
			odds = { Rare = 70, Epic = 22, Legendary = 7.5, Mythic = 0.5 },
			color = { 245, 205, 48 },
		},
		{
			id = "RebirthEgg",
			name = "Œuf de Rebirth",
			currency = "gems",
			price = 50,
			odds = { Epic = 75, Legendary = 23.5, Mythic = 1.5 },
			color = { 98, 37, 209 },
		},
		{
			id = "LegendaryEgg",
			name = "Œuf Légendaire",
			currency = "item",
			price = 1,
			odds = { Legendary = 97, Mythic = 3 },
			color = { 255, 176, 0 },
		},
	} :: { EggDef },

	-- A17 : la fusion multiplie le bonus au-delà de 1 : 1 + (bonus − 1) × k.
	VARIANTS = {
		{ id = "Normal", name = "", multiplier = 1 },
		{ id = "Gold", name = "Or", multiplier = 2 },
		{ id = "Rainbow", name = "Arc-en-ciel", multiplier = 5 },
	} :: { VariantDef },
	FUSION_COUNT = 5, -- CDC §7.2 : cinq Pets identiques fusionnent

	MAX_EQUIPPED = 3, -- A42
	MAX_PETS = 100,

	-- Distributeurs d'œufs sur la base (coordonnées locales du bouton, comme TycoonConfig.LAYOUT) ;
	-- l'œuf géant est posé EGG_OFFSET_X plus loin, côté champ.
	EGG_OFFSET_X = 9,
	DISPENSERS = {
		BasicEgg = { x = 20, z = -45 },
		FarmEgg = { x = 20, z = -15 },
		RebirthEgg = { x = 20, z = 15 },
	} :: { [string]: { x: number, z: number } },
	DISPENSER_SIZE = 10,
	HATCH_COOLDOWN = 1.2, -- secondes entre deux éclosions d'un même joueur

	-- Suivi côté client (CDC §7.2 « suivent le joueur en sautillant »).
	FOLLOW = {
		DISTANCE = 6,
		SPREAD = 4,
		HOP_HEIGHT = 1.2,
		HOP_SPEED = 8,
		SMOOTHING = 8,
		SIZE = 2,
	},
})
