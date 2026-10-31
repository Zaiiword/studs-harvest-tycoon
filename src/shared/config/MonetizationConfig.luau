--!strict
-- Monétisation Robux (CDC §9, §10 ; décisions A12, A14, A16, A48 à A50).
-- Les identifiants (id = 0) sont à créer sur le Creator Hub puis à renseigner ici (docs/PUBLICATION.md).
-- Tant qu'un identifiant vaut 0, l'achat n'est pas proposé en jeu ; dans Studio, le panneau de test le simule.
local Freeze = require("../util/Freeze")

export type PassDef = { key: string, id: number, name: string, price: number, description: string }
export type ProductDef = { key: string, id: number, name: string, price: number, description: string }

return Freeze.deep({
	GAMEPASSES = {
		{
			key = "InfiniteTrailer",
			id = 0,
			name = "Remorque Infinie",
			price = 499,
			description = "Plus de limite de stockage : reste au centre pendant tout un événement.",
		},
		{
			key = "IncomeX2",
			id = 0,
			name = "Revenus ×2",
			price = 299,
			description = "Double tous les $/s de ton usine.",
		},
		{
			key = "Titan",
			id = 0,
			name = "Pare-Chocs Lourd Titan",
			price = 199,
			description = "Masse PvP ×2,5 et pare-buffle doré.",
		},
		{
			key = "Magnet",
			id = 0,
			name = "Aimant à Briques & Vitesse",
			price = 149,
			description = "Rayon de coupe +35 % et vitesse +20 %.",
		},
		{
			key = "TripleHatch",
			id = 0,
			name = "Triple Éclosion & Auto-Hatch",
			price = 399,
			description = "Ouvre 3 œufs à la fois, en continu tant que tu restes sur le distributeur.",
		},
	} :: { PassDef },

	PRODUCTS = {
		{
			key = "Bazooka",
			id = 0,
			name = "Bazooka Éjecteur (3 tirs)",
			price = 39,
			description = "3 tirs de Bazooka.",
		},
		{
			key = "Meteor",
			id = 0,
			name = "Invoquer Météorite Dorée",
			price = 99,
			description = "Fait tomber le boss tout de suite, avec ton nom en géant.",
		},
		{
			key = "Revenge",
			id = 0,
			name = "Se venger !",
			price = 39,
			description = "Éjecte le dernier joueur qui t'a bousculé.",
		},
		{
			key = "StarterPack",
			id = 0,
			name = "Starter Pack",
			price = 99,
			description = "Mini-Tracteur Turbo + 1 Pet Épique + 10 000 $.",
		},
	} :: { ProductDef },

	-- Effets des Gamepasses (CDC §9).
	MAGNET_HITBOX_MULTIPLIER = 1.35,
	MAGNET_SPEED_MULTIPLIER = 1.2,
	TRIPLE_HATCH_COUNT = 3,

	-- A14 : « Se venger » cible le dernier agresseur. Le bouton reste 6 s ; le serveur garde l'agresseur
	-- 60 s pour couvrir le temps de l'achat. Si la cible est partie ou protégée, le joueur reçoit 1 tir de
	-- Bazooka à la place (A49 : on ne peut pas rembourser des Robux, on compense).
	REVENGE_BUTTON_SECONDS = 6,
	REVENGE_MEMORY_SECONDS = 60,
	REVENGE_EJECT_DISTANCE = 120,

	-- Starter Pack (CDC §10, A12, A50) : offert une seule fois par compte, après 4 min de jeu ou au premier
	-- sac plein (le premier des deux), pendant 15 minutes.
	STARTER = {
		OFFER_AFTER_SECONDS = 240,
		OFFER_DURATION_SECONDS = 900,
		MONEY = 10_000,
		PET = "Tractor:Normal", -- Pet Épique
		TURBO_TIER = 4, -- Mini-Tracteur Turbo : statistiques du Tier 4…
		TURBO_SPEED_MULTIPLIER = 1.1, -- … et +10 % de vitesse (A12)
	},

	RECEIPT_HISTORY = 200, -- reçus déjà traités gardés dans le profil (idempotence)
})
