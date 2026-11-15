--!strict
-- Objectif affiché sous la trésorerie (A59), sans API Roblox : le prochain grand achat vers lequel épargner.
-- Les flèches de guidage montrent ce qu'on peut payer tout de suite ; la barre d'objectif montre ce qu'on vise.
-- Candidats : le palier suivant au Garage, la prochaine machine (rez-de-chaussée puis étage) et le Rebirth une fois
-- l'usine complète. Le moins cher l'emporte : il y a toujours une victoire proche en vue.
local TycoonConfig = require("../config/TycoonConfig")
local Rebirth = require("./Rebirth")
local Tycoon = require("./Tycoon")

export type Goal = { id: string, label: string, price: number }

local Goal = {}

local ICONS = TycoonConfig.PAD_STYLE.ICONS

local function candidate(state: Tycoon.State, buttonId: string, tier: number): Goal?
	local offer = Tycoon.offer(state, buttonId, tier)
	if not offer.price then
		return nil
	end
	return { id = buttonId, label = `{ICONS[buttonId] or "⭐"} {offer.label}`, price = offer.price }
end

-- Prochaine machine à acheter dans une chaîne (la première qui n'est pas encore possédée et déjà débloquée).
local function nextMachine(state: Tycoon.State, list: { TycoonConfig.MachineDef }, tier: number): Goal?
	for _, machine in list do
		if not state.machines[machine.id] then
			return candidate(state, machine.id, tier)
		end
	end
	return nil
end

function Goal.next(state: Tycoon.State, tier: number, progress: Rebirth.Progress): Goal?
	local options: { Goal? } = {
		candidate(state, TycoonConfig.GARAGE_NAME, tier),
		nextMachine(state, TycoonConfig.MACHINES, tier),
		nextMachine(state, TycoonConfig.UPPER_MACHINES, tier),
	}
	if Rebirth.isTycoonComplete(state) then
		local label = `{ICONS[TycoonConfig.REBIRTH_NAME]} Rebirth n°{progress.rebirths + 1}`
		table.insert(options, { id = TycoonConfig.REBIRTH_NAME, label = label, price = Rebirth.cost(progress) })
	end
	local best: Goal? = nil
	for index = 1, 4 do
		local option = options[index]
		if option and (best == nil or option.price < best.price) then
			best = option
		end
	end
	return best
end

return Goal
