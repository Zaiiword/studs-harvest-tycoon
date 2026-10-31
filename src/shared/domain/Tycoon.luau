--!strict
-- Économie Tycoon d'un joueur (CDC §7.1, §8), sans API Roblox : silo, tapis, machines, achats et revenu.
-- Le silo stocke une valeur brute en $ (A5) ; le tapis en consomme `conveyorRate` par seconde ; le revenu
-- applique ensuite les multiplicateurs (Formulas.incomePerSecond). Silo vide → l'usine s'arrête.
local TycoonConfig = require("../config/TycoonConfig")
local VehicleConfig = require("../config/VehicleConfig")
local Formulas = require("./Formulas")

export type State = {
	money: number,
	silo: number,
	conveyorLevel: number,
	machines: { [string]: boolean },
	siloLevel: number, -- agrandissements du silo achetés (A53)
	decor: { [string]: boolean }, -- décorations achetées (A53)
	guided: { [string]: boolean }, -- boutons déjà achetés une fois (et déchargement fait) : plus de flèches (A53)
}

-- Bonus extérieurs à l'usine (Pets au Sprint 6, Rebirths au Sprint 4, Gamepass au Sprint 8).
export type IncomeBonus = {
	petBonuses: { number },
	rebirths: number,
	hasIncomeX2: boolean,
	boostMultiplier: number?, -- multiplicateur temporaire (récompense du boss Météorite ×3, CDC §6)
}

export type Offer = {
	id: string,
	label: string,
	price: number?, -- nil : plus rien à acheter sur ce bouton
}

export type PurchaseResult = {
	isPurchased: boolean,
	newTier: number?, -- renseigné par le Garage
}

local Tycoon = {}

local CONVEYOR = TycoonConfig.CONVEYOR
local SILO_UPGRADE = TycoonConfig.SILO_UPGRADE
local machinesById: { [string]: TycoonConfig.MachineDef } = {}
for _, machine in TycoonConfig.MACHINES do
	machinesById[machine.id] = machine
end
local decorById: { [string]: TycoonConfig.DecorDef } = {}
for _, decor in TycoonConfig.DECORATIONS do
	decorById[decor.id] = decor
end

Tycoon.NO_BONUS = table.freeze({ petBonuses = {}, rebirths = 0, hasIncomeX2 = false }) :: IncomeBonus

function Tycoon.new(): State
	return {
		money = TycoonConfig.STARTING_MONEY,
		silo = 0,
		conveyorLevel = 1,
		machines = {},
		siloLevel = 0,
		decor = {},
		guided = {},
	}
end

function Tycoon.conveyorRate(state: State): number
	return CONVEYOR.BASE_RATE * CONVEYOR.RATE_GROWTH ^ (state.conveyorLevel - 1)
end

-- Produit des multiplicateurs des machines possédées (A6) ; 1 sans machine.
function Tycoon.machineMultiplier(state: State): number
	local multiplier = 1
	for id, isOwned in state.machines do
		if isOwned then
			multiplier *= machinesById[id].multiplier
		end
	end
	return multiplier
end

-- Capacité du silo à un niveau d'agrandissement donné (A53) : ×2 par niveau.
function Tycoon.siloCapacityAt(level: number): number
	return TycoonConfig.SILO_CAPACITY * SILO_UPGRADE.CAPACITY_GROWTH ^ level
end

function Tycoon.siloCapacity(state: State): number
	return Tycoon.siloCapacityAt(state.siloLevel)
end

-- Capacité maximale atteignable : borne de la sauvegarde.
Tycoon.MAX_SILO_CAPACITY = Tycoon.siloCapacityAt(#SILO_UPGRADE.PRICES)

-- Verse une valeur brute dans le silo, dans la limite de sa capacité. Renvoie la part acceptée.
function Tycoon.deposit(state: State, value: number): number
	local accepted = math.clamp(value, 0, Tycoon.siloCapacity(state) - state.silo)
	state.silo += accepted
	return accepted
end

-- Revenu par seconde affiché : celui de l'usine à plein débit, 0 si le silo est vide.
local function income(state: State, rawPerSecond: number, bonus: IncomeBonus): number
	return Formulas.incomePerSecond({
		rawPerSecond = rawPerSecond,
		machineMultiplier = Tycoon.machineMultiplier(state),
		petBonuses = bonus.petBonuses,
		rebirths = bonus.rebirths,
		hasIncomeX2 = bonus.hasIncomeX2,
	}) * (bonus.boostMultiplier or 1)
end

function Tycoon.incomePerSecond(state: State, bonus: IncomeBonus): number
	return income(state, if state.silo > 0 then Tycoon.conveyorRate(state) else 0, bonus)
end

-- Fait tourner l'usine pendant `dt` secondes : le tapis vide le silo et le revenu est encaissé.
function Tycoon.tick(state: State, dt: number, bonus: IncomeBonus): number
	local consumed = math.min(state.silo, Tycoon.conveyorRate(state) * dt)
	if consumed <= 0 or dt <= 0 then
		return 0
	end
	state.silo -= consumed
	local earned = income(state, consumed / dt, bonus) * dt
	state.money += earned
	return earned
end

-- Secondes avant que le silo soit vide au débit actuel (CDC §10 « autonomie restante du silo »).
function Tycoon.autonomySeconds(state: State): number
	return state.silo / Tycoon.conveyorRate(state)
end

local function conveyorOffer(state: State): Offer
	local isMaxed = state.conveyorLevel >= CONVEYOR.MAX_LEVEL
	local price = Formulas.tycoonButtonPrice(CONVEYOR.BASE_PRICE, state.conveyorLevel - 1)
	return {
		id = "Conveyor",
		label = `{CONVEYOR.NAME} niv. {state.conveyorLevel + 1}`,
		price = (not isMaxed) and price or nil,
	}
end

local function siloOffer(state: State): Offer
	local price = SILO_UPGRADE.PRICES[state.siloLevel + 1]
	local label = if price then `{SILO_UPGRADE.NAME} niv. {state.siloLevel + 1}` else `{SILO_UPGRADE.NAME} max`
	return { id = SILO_UPGRADE.ID, label = label, price = price }
end

local function garageOffer(tier: number): Offer
	local nextTier = VehicleConfig.TIERS[tier + 1]
	if not nextTier then
		return { id = TycoonConfig.GARAGE_NAME, label = "Palier maximal", price = nil }
	end
	return { id = TycoonConfig.GARAGE_NAME, label = nextTier.name, price = nextTier.price }
end

-- Ce que propose chaque bouton au sol de la base, compte tenu de l'état et du palier actuel.
function Tycoon.offer(state: State, buttonId: string, tier: number): Offer
	if buttonId == "Conveyor" then
		return conveyorOffer(state)
	end
	if buttonId == TycoonConfig.GARAGE_NAME then
		return garageOffer(tier)
	end
	if buttonId == SILO_UPGRADE.ID then
		return siloOffer(state)
	end
	local decor = decorById[buttonId]
	if decor then
		return { id = decor.id, label = decor.name, price = if state.decor[decor.id] then nil else decor.price }
	end
	local machine = machinesById[buttonId]
	assert(machine, `bouton inconnu : {buttonId}`)
	return { id = machine.id, label = machine.name, price = if state.machines[machine.id] then nil else machine.price }
end

-- Achète ce que propose le bouton si le joueur en a les moyens. Le Garage renvoie le nouveau palier.
function Tycoon.buy(state: State, buttonId: string, tier: number): PurchaseResult
	local offer = Tycoon.offer(state, buttonId, tier)
	local price = offer.price
	if not price or state.money < price then
		return { isPurchased = false }
	end
	state.money -= price
	state.guided[buttonId] = true
	if buttonId == "Conveyor" then
		state.conveyorLevel += 1
	elseif buttonId == TycoonConfig.GARAGE_NAME then
		return { isPurchased = true, newTier = tier + 1 }
	elseif buttonId == SILO_UPGRADE.ID then
		state.siloLevel += 1
	elseif decorById[buttonId] then
		state.decor[buttonId] = true
	else
		state.machines[buttonId] = true
	end
	return { isPurchased = true }
end

return Tycoon
