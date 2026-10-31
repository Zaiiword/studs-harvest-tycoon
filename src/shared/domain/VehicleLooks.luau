--!strict
-- Apparence d'un engin (A52), sans API Roblox : quel modèle, quelles couleurs, quelles pièces générées.
-- Le client (VehicleVisualController) n'a plus qu'à transformer ces données en briques.
local MonetizationConfig = require("../config/MonetizationConfig")
local VehicleConfig = require("../config/VehicleConfig")
local VehicleVisualConfig = require("../config/VehicleVisualConfig")
local Loadout = require("./Loadout")

export type Look = {
	tierId: number, -- palier effectif (avantages Robux compris) : c'est l'engin qui roule
	hasTurbo: boolean, -- Mini-Tracteur Turbo affiché (A12) : livrée course et flammes
	hasTitan: boolean, -- Gamepass Pare-Chocs Lourd Titan : pare-buffle doré (CDC §9)
}

local VehicleLooks = {}

function VehicleLooks.lookOf(purchasedTier: number, perks: Loadout.Perks, hasTitan: boolean): Look
	return {
		tierId = Loadout.effectiveTier(purchasedTier, perks).id,
		hasTurbo = perks.hasTurboTractor and purchasedTier < MonetizationConfig.STARTER.TURBO_TIER,
		hasTitan = hasTitan,
	}
end

function VehicleLooks.hasModel(look: Look): boolean
	return VehicleVisualConfig.MODELS[look.tierId] ~= nil
end

-- Couleur RGB d'une peinture : variante néon du palier, puis palette du palier (ou Turbo), puis couleurs communes.
function VehicleLooks.paint(look: Look, paint: string): { number }
	local override = VehicleVisualConfig.NEON_OVERRIDES[look.tierId]
	local palette = if look.hasTurbo
		then VehicleVisualConfig.TURBO_PALETTE
		else VehicleVisualConfig.PALETTES[look.tierId]
	local rgb = (override and override[paint])
		or (palette and palette[paint])
		or VehicleVisualConfig.SHARED_PAINT[paint]
	assert(rgb, `peinture inconnue « {paint} » pour le palier {look.tierId}`)
	return rgb
end

-- Avant de l'engin (z le plus petit atteint par une pièce) : le pare-buffle et la paille s'y placent.
function VehicleLooks.frontZ(tierId: number): number
	local front = 0
	for _, piece in VehicleVisualConfig.MODELS[tierId].pieces do
		front = math.min(front, piece.at[3] - piece.size[3] / 2)
	end
	return front
end

-- Pare-buffle Titan, dimensionné d'après la carrosserie physique et posé devant la pièce la plus avancée.
local function titanGuard(tierId: number): VehicleVisualConfig.Piece
	local body = VehicleConfig.BODIES[tierId]
	local guard = VehicleVisualConfig.TITAN_GUARD
	return {
		paint = "titan",
		size = { body.width + guard.margin, body.height * guard.heightRatio, guard.depth },
		at = { 0, 0, VehicleLooks.frontZ(tierId) - guard.gap - guard.depth / 2 },
	}
end

function VehicleLooks.piecesFor(look: Look): { VehicleVisualConfig.Piece }
	local pieces = table.clone(VehicleVisualConfig.MODELS[look.tierId].pieces)
	if look.hasTitan then
		table.insert(pieces, titanGuard(look.tierId))
	end
	return pieces
end

-- Barre de paille projetée en fauchant : à l'avant, au ras du sol, aussi large que la coupe du palier.
function VehicleLooks.chaffBar(look: Look): ({ number }, number)
	local height = VehicleConfig.BODIES[look.tierId].height
	local at = { 0, -height / 2 + VehicleVisualConfig.CHAFF.size, VehicleLooks.frontZ(look.tierId) }
	return at, VehicleConfig.TIERS[look.tierId].hitboxStuds
end

return VehicleLooks
