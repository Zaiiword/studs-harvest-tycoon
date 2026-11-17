--!strict
-- Simulation d'économie (docs/ANALYSE_CDC.md §5 « Inflation de l'économie », docs/EQUILIBRAGE.md).
-- Un joueur appliqué, seul et sans Pet ni avantage Robux : il récolte la zone la plus rentable qu'il peut
-- couper, rentre décharger, et achète au mieux (Garage dès que possible, sinon machine, sinon tapis). Il bâtit aussi
-- sa ferme (A56) dès qu'un élément ne pèse plus grand-chose dans sa trésorerie, machines de l'étage comprises.
-- Modèle volontairement simple : il sert à repérer les dérives de prix, pas à prédire au seconde près.
local FieldConfig = require("../../src/shared/config/FieldConfig")
local MapConfig = require("../../src/shared/config/MapConfig")
local TycoonConfig = require("../../src/shared/config/TycoonConfig")
local VehicleConfig = require("../../src/shared/config/VehicleConfig")
local Formulas = require("../../src/shared/domain/Formulas")
local MapGeometry = require("../../src/shared/domain/MapGeometry")
local Tycoon = require("../../src/shared/domain/Tycoon")

export type Result = {
	tierReachedAt: { [number]: number },
	completeAt: number?,
	rebirthReadyAt: number?,
	builtAt: { [string]: number }, -- instant d'achat de chaque élément de la ferme et des machines de l'étage
}

-- Profil de joueur pour la simulation de carrière (A70). `bonus` : multiplicateur de revenus apporté par les Pets,
-- les cadeaux et les récompenses, selon le temps de jeu cumulé (les Pets survivent au Rebirth).
export type Profile = {
	travelLegs: number, -- 2 : aller-retour à chaque sac ; 1 : « Retour Base Instantané » à chaque fois
	bonus: (careerSeconds: number) -> number,
}
export type Run = {
	seconds: number, -- durée de cette partie, d'un Rebirth au suivant
	endedAt: number, -- temps de jeu cumulé au moment du Rebirth
	tierAt: { [number]: number },
	upperAt: number?, -- achat de la dernière machine de l'étage
}
export type Career = { runs: { Run } }

local EconomySim = {}

-- Joueur prudent : seul, sans Pet ni cadeau, qui rentre à pied.
EconomySim.CAREFUL = {
	travelLegs = 2,
	bonus = function(): number
		return 1
	end,
} :: Profile

-- Joueur réel, calé sur une partie observée (3 Rebirths en moins d'une heure avant A70) : il ouvre des œufs dès les
-- premières minutes, gagne un Pet Légendaire au boss, encaisse cadeaux, roue et quêtes (+40 %), et rentre avec le
-- « Retour Base Instantané ». Ses Pets passent de ×1 à ×13 en une heure et demie de jeu.
local REAL_PET_MINUTES, REAL_PET_CAP, REAL_REWARDS = 8, 13, 1.4
EconomySim.REAL = {
	travelLegs = 1,
	bonus = function(careerSeconds: number): number
		return math.min(REAL_PET_CAP, 1 + careerSeconds / 60 / REAL_PET_MINUTES) * REAL_REWARDS
	end,
} :: Profile

local CELL = MapConfig.CELL_SIZE
local TICK = FieldConfig.HARVEST_INTERVAL
local SILO_MARGIN = 2 -- silo visé : deux sacs pleins
local FARM_BUDGET = 0.15 -- part de la trésorerie qu'il consacre à l'élément suivant de la ferme

-- Blés coupés par seconde dans une zone : rangées couvertes × avancée, limité par les PV (coups par brin).
local function cutRate(tier: VehicleConfig.TierDef, zone: string): number
	local hp = FieldConfig.WHEAT_ZONES[zone].hp
	local rows = (tier.hitboxStuds + CELL) / CELL
	local hits = math.ceil(hp / tier.cutPower)
	if hits <= 1 then
		return rows * tier.speed / CELL
	end
	local depth = (tier.hitboxStuds + CELL) / CELL
	return rows * depth / (hits * TICK)
end

-- Valeur rapportée par seconde de jeu (récolte + allers-retours), pour une zone donnée.
local function zoneIncome(tier: VehicleConfig.TierDef, zone: string, travelLegs: number?): (number, number)
	local band = MapGeometry.bandOf(zone)
	local distance = MapConfig.STEM.minX + band.startDistance - MapConfig.BASE_CENTER_X
	local wheatValue = FieldConfig.WHEAT_ZONES[zone].value
	-- A55 : un blé prend autant de places qu'il vaut. Le sac porte donc une valeur, quelle que soit la zone.
	local wheats = math.floor(tier.capacity / wheatValue)
	if wheats < 1 then
		return 0, 1
	end
	local tripSeconds = wheats / cutRate(tier, zone) + (travelLegs or 2) * distance / tier.speed
	return wheats * wheatValue / tripSeconds, tripSeconds
end

local function bestZone(tier: VehicleConfig.TierDef, travelLegs: number?): (number, number)
	local bestRate, bestTrip = 0, 1
	for zone in FieldConfig.WHEAT_ZONES do
		local rate, trip = zoneIncome(tier, zone, travelLegs)
		if rate > bestRate then
			bestRate, bestTrip = rate, trip
		end
	end
	return bestRate, bestTrip
end

local function shop(state: Tycoon.State, tierId: number): number
	local garage = Tycoon.buy(state, TycoonConfig.GARAGE_NAME, tierId)
	if garage.newTier then
		return garage.newTier
	end
	-- A73 : un sac qui ne rentre plus dans le silo, c'est de la récolte perdue : on l'agrandit d'abord.
	if Tycoon.siloCapacity(state) < VehicleConfig.TIERS[tierId].capacity * SILO_MARGIN then
		if Tycoon.buy(state, TycoonConfig.SILO_UPGRADE.ID, tierId).isPurchased then
			return tierId
		end
	end
	for _, list in { TycoonConfig.MACHINES, TycoonConfig.UPPER_MACHINES } do
		for _, machine in list do
			if Tycoon.buy(state, machine.id, tierId).isPurchased then
				return tierId
			end
		end
	end
	for _, decor in TycoonConfig.DECORATIONS do
		if not state.decor[decor.id] then
			if decor.price <= state.money * FARM_BUDGET then
				Tycoon.buy(state, decor.id, tierId)
			end
			break
		end
	end
	-- Le tapis n'est amélioré que s'il ne suit plus la récolte (sinon c'est de l'argent gaspillé).
	local harvestPerSecond = bestZone(VehicleConfig.TIERS[tierId])
	if Tycoon.conveyorRate(state) < harvestPerSecond then
		Tycoon.buy(state, "Conveyor", tierId)
	end
	return tierId
end

-- Simule `maxSeconds` secondes de jeu, par pas d'un trajet complet.
function EconomySim.run(maxSeconds: number): Result
	local state = Tycoon.new()
	local tierId, time = 1, 0
	local result: Result = { tierReachedAt = { [1] = 0 }, builtAt = {} }
	while time < maxSeconds do
		local rate, trip = bestZone(VehicleConfig.TIERS[tierId])
		Tycoon.deposit(state, rate * trip)
		for _ = 1, math.ceil(trip) do
			Tycoon.tick(state, 1, Tycoon.NO_BONUS)
		end
		time += math.ceil(trip)
		local newTier = shop(state, tierId)
		if newTier ~= tierId then
			tierId = newTier
			result.tierReachedAt[tierId] = time
		end
		for id in state.decor do
			result.builtAt[id] = result.builtAt[id] or time
		end
		for id in state.machines do
			result.builtAt[id] = result.builtAt[id] or time
		end
		local isComplete = true
		for _, machine in TycoonConfig.MACHINES do
			isComplete = isComplete and state.machines[machine.id] == true
		end
		if isComplete and not result.completeAt then
			result.completeAt = time
		end
		if isComplete and not result.rebirthReadyAt and state.money >= Formulas.rebirthCost(0) then
			result.rebirthReadyAt = time
		end
	end
	return result
end

-- Joueur occasionnel : moitié moins de Pets, moitié moins vite, et il oublie une fois sur deux le Retour Base.
local CASUAL_PET_MINUTES, CASUAL_PET_CAP, CASUAL_REWARDS = 16, 6, 1.2
EconomySim.CASUAL = {
	travelLegs = 1.5,
	bonus = function(careerSeconds: number): number
		return math.min(CASUAL_PET_CAP, 1 + careerSeconds / 60 / CASUAL_PET_MINUTES) * CASUAL_REWARDS
	end,
} :: Profile

local SHOPPING_ROUNDS = 8 -- achats possibles à chaque retour à la base

local function isComplete(state: Tycoon.State, machines: { TycoonConfig.MachineDef }): boolean
	for _, machine in machines do
		if not state.machines[machine.id] then
			return false
		end
	end
	return true
end

-- Enchaîne `rebirths` Rebirths : à chaque partie le joueur repart du palier 1, garde ses Pets (profile.bonus) et
-- gagne le bonus de Rebirth. Il fait son Rebirth dès qu'il le peut. S'arrête à `maxSeconds` de jeu cumulé.
function EconomySim.career(profile: Profile, rebirths: number, maxSeconds: number): Career
	local career: Career = { runs = {} }
	local time = 0
	for done = 0, rebirths - 1 do
		local state = Tycoon.new()
		state.priceScale = Formulas.prestigePriceScale(done)
		local tierId, startedAt = 1, time
		local run: Run = { seconds = 0, endedAt = 0, tierAt = {} }
		local cost = Formulas.rebirthCost(done)
		while not (isComplete(state, TycoonConfig.MACHINES) and state.money >= cost) do
			if time >= maxSeconds then
				return career
			end
			local rate, trip = bestZone(VehicleConfig.TIERS[tierId], profile.travelLegs)
			Tycoon.deposit(state, rate * trip)
			local bonus: Tycoon.IncomeBonus = {
				petBonuses = { profile.bonus(time) },
				rebirths = done,
				hasIncomeX2 = false,
				boostMultiplier = 1,
			}
			for _ = 1, math.ceil(trip) do
				Tycoon.tick(state, 1, bonus)
			end
			time += math.ceil(trip)
			for _ = 1, SHOPPING_ROUNDS do
				local before = state.money
				local newTier = shop(state, tierId)
				if newTier ~= tierId then
					tierId = newTier
					run.tierAt[tierId] = time - startedAt
				end
				if state.money == before then
					break
				end
			end
			if not run.upperAt and isComplete(state, TycoonConfig.UPPER_MACHINES) then
				run.upperAt = time - startedAt
			end
		end
		run.seconds, run.endedAt = time - startedAt, time
		table.insert(career.runs, run)
	end
	return career
end

return EconomySim
