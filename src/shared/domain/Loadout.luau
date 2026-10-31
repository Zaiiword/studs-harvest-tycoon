--!strict
-- Palier effectif d'un joueur (CDC §5, §9 ; A12, A16), sans API Roblox : le palier acheté au Garage, modifié
-- par les avantages Robux. Utilisé à l'identique par le serveur (autorité) et le client (prédiction, conduite).
local MonetizationConfig = require("../config/MonetizationConfig")
local VehicleConfig = require("../config/VehicleConfig")

export type Perks = {
	hasMagnet: boolean, -- Aimant à Briques & Vitesse : hitbox +35 %, vitesse +20 %
	hasInfiniteTrailer: boolean, -- Remorque Infinie : capacité illimitée (A16)
	hasTurboTractor: boolean, -- Mini-Tracteur Turbo du Starter Pack (A12)
}

local Loadout = {}

Loadout.NO_PERKS = table.freeze({ hasMagnet = false, hasInfiniteTrailer = false, hasTurboTractor = false }) :: Perks

-- Copie modifiable du palier `tierId` (1 par défaut si inconnu).
local function copyOf(tierId: number): VehicleConfig.TierDef
	return table.clone(VehicleConfig.TIERS[tierId] or VehicleConfig.TIERS[1]) :: VehicleConfig.TierDef
end

function Loadout.effectiveTier(tierId: number, perks: Perks): VehicleConfig.TierDef
	local starter = MonetizationConfig.STARTER
	local tier = copyOf(tierId)
	-- A12 : le Mini-Tracteur Turbo donne les statistiques du Tier 4 (+10 % de vitesse) tant que le palier
	-- acheté est plus faible ; il ne remplace pas la progression, qui reste celle du Garage.
	if perks.hasTurboTractor and tier.id < starter.TURBO_TIER then
		tier = copyOf(starter.TURBO_TIER)
		tier.speed *= starter.TURBO_SPEED_MULTIPLIER
	end
	if perks.hasMagnet then
		tier.hitboxStuds *= MonetizationConfig.MAGNET_HITBOX_MULTIPLIER
		tier.speed *= MonetizationConfig.MAGNET_SPEED_MULTIPLIER
	end
	if perks.hasInfiniteTrailer then
		tier.capacity = math.huge
	end
	return tier
end

return Loadout
