--!strict
-- Lecture des avantages Robux d'un joueur depuis ses attributs répliqués (posés par MonetizationService).
-- Même lecture côté serveur et côté client : les deux calculent le même palier effectif (Loadout).
local Loadout = require("../domain/Loadout")
local VehicleConfig = require("../config/VehicleConfig")
local PlayerAttributes = require("./PlayerAttributes")

local Perks = {}

function Perks.hasPass(player: Player, key: string): boolean
	return player:GetAttribute(PlayerAttributes.PASS_PREFIX .. key) == true
end

function Perks.of(player: Player): Loadout.Perks
	return {
		hasMagnet = Perks.hasPass(player, "Magnet"),
		hasInfiniteTrailer = Perks.hasPass(player, "InfiniteTrailer"),
		hasTurboTractor = player:GetAttribute(PlayerAttributes.HAS_TURBO_TRACTOR) == true,
	}
end

-- Palier effectif du joueur : palier acheté (attribut Tier) modifié par ses avantages.
function Perks.tierOf(player: Player): VehicleConfig.TierDef
	local id = player:GetAttribute(PlayerAttributes.TIER)
	return Loadout.effectiveTier(if typeof(id) == "number" then id else 1, Perks.of(player))
end

return Perks
