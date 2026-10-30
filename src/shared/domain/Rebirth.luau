--!strict
-- Prestige (CDC §7.3, décisions A8, A9, A15, A37), sans API Roblox.
-- Condition : toutes les machines achetées ET argent ≥ 1e6 × 3^r. Effet : argent, machines, niveau du tapis et
-- véhicule remis à zéro ; +1 Rebirth (+50 % de revenus, +15 % de masse) et 10 × (r + 1) gemmes.
local EconomyConfig = require("../config/EconomyConfig")
local TycoonConfig = require("../config/TycoonConfig")
local Formulas = require("./Formulas")
local Tycoon = require("./Tycoon")

-- Ce que le Rebirth ne remet jamais à zéro.
export type Progress = {
	rebirths: number,
	gems: number,
}

local Rebirth = {}

Rebirth.STARTING_TIER = 1

function Rebirth.newProgress(): Progress
	return { rebirths = 0, gems = 0 }
end

function Rebirth.cost(progress: Progress): number
	return Formulas.rebirthCost(progress.rebirths)
end

-- A8 : « Tycoon complété » = toutes les machines achetées.
function Rebirth.isTycoonComplete(state: Tycoon.State): boolean
	for _, machine in TycoonConfig.MACHINES do
		if not state.machines[machine.id] then
			return false
		end
	end
	return true
end

function Rebirth.canRebirth(state: Tycoon.State, progress: Progress): boolean
	return Rebirth.isTycoonComplete(state) and state.money >= Rebirth.cost(progress)
end

-- A9 : 10 gemmes au premier Rebirth, 20 au deuxième, etc.
function Rebirth.gemsFor(progress: Progress): number
	return EconomyConfig.GEMS_PER_REBIRTH * (progress.rebirths + 1)
end

-- Applique le Rebirth si possible. Le silo est conservé (A37) : c'est du blé déjà récolté.
function Rebirth.apply(state: Tycoon.State, progress: Progress): boolean
	if not Rebirth.canRebirth(state, progress) then
		return false
	end
	progress.gems += Rebirth.gemsFor(progress)
	progress.rebirths += 1
	state.money = TycoonConfig.STARTING_MONEY
	state.conveyorLevel = 1
	state.machines = {}
	return true
end

-- Bonus de revenus à appliquer à l'usine (Pets et Gamepass s'y ajouteront aux Sprints 6 et 8).
function Rebirth.incomeBonus(progress: Progress): Tycoon.IncomeBonus
	return { petBonuses = {}, rebirths = progress.rebirths, hasIncomeX2 = false }
end

return Rebirth
