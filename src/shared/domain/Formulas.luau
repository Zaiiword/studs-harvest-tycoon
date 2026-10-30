--!strict
-- Formules pures d'équilibrage (CDC §5 et §8). Aucune dépendance Roblox : testé sous Lune.

local EconomyConfig = require("../config/EconomyConfig")
local VehicleConfig = require("../config/VehicleConfig")

local Formulas = {}

export type IncomeInput = {
	rawPerSecond: number, -- Débit_Tapis × Valeur_Moyenne_Blé (décision A5)
	machineMultiplier: number,
	petBonuses: { number },
	rebirths: number,
	hasIncomeX2: boolean,
}

-- Décision A1 : sans pet le facteur vaut 1 (et non 0).
function Formulas.petFactor(petBonuses: { number }): number
	local factor = 1
	for _, bonus in petBonuses do
		factor += bonus - 1
	end
	return factor
end

function Formulas.incomePerSecond(input: IncomeInput): number
	if input.rawPerSecond <= 0 then
		return 0
	end
	local rebirthFactor = 1 + EconomyConfig.REBIRTH_INCOME_BONUS * input.rebirths
	local passFactor = if input.hasIncomeX2 then EconomyConfig.INCOME_X2_MULTIPLIER else 1
	return input.rawPerSecond
		* input.machineMultiplier
		* Formulas.petFactor(input.petBonuses)
		* rebirthFactor
		* passFactor
end

function Formulas.tycoonButtonPrice(basePrice: number, level: number): number
	return math.floor(basePrice * EconomyConfig.TYCOON_PRICE_GROWTH ^ level + 0.5)
end

function Formulas.rebirthCost(rebirths: number): number
	return EconomyConfig.REBIRTH_BASE_COST * EconomyConfig.REBIRTH_COST_GROWTH ^ rebirths
end

-- Décision A15 : Titan et Rebirth sont multiplicatifs ; le Rebirth n'est compté qu'ici.
function Formulas.effectiveMass(tierMass: number, rebirths: number, hasTitan: boolean): number
	local titan = if hasTitan then VehicleConfig.TITAN_MASS_MULTIPLIER else 1
	return tierMass * titan * (1 + VehicleConfig.REBIRTH_MASS_BONUS * rebirths)
end

-- CDC §5 : VitesseImpact × (MasseAttaquant ÷ MasseCible) × BonusPareChocs.
-- Le terme (1 + 0,15 × Rebirths) est déjà inclus dans effectiveMass.
function Formulas.knockbackForce(
	impactSpeed: number,
	attackerMass: number,
	targetMass: number,
	bumperBonus: number
): number
	assert(targetMass > 0, "targetMass doit être > 0")
	return math.max(0, impactSpeed) * (attackerMass / targetMass) * bumperBonus
end

return table.freeze(Formulas)
