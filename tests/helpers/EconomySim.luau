--!strict
-- Simulation d'économie (docs/ANALYSE_CDC.md §5 « Inflation de l'économie », docs/EQUILIBRAGE.md).
-- Un joueur appliqué, seul et sans Pet ni avantage Robux : il récolte la zone la plus rentable qu'il peut
-- couper, rentre décharger, et achète au mieux (Garage dès que possible, sinon machine, sinon tapis).
-- Modèle volontairement simple : il sert à repérer les dérives de prix, pas à prédire au seconde près.
local FieldConfig = require("../../src/shared/config/FieldConfig")
local MapConfig = require("../../src/shared/config/MapConfig")
local TycoonConfig = require("../../src/shared/config/TycoonConfig")
local VehicleConfig = require("../../src/shared/config/VehicleConfig")
local Formulas = require("../../src/shared/domain/Formulas")
local MapGeometry = require("../../src/shared/domain/MapGeometry")
local Tycoon = require("../../src/shared/domain/Tycoon")

export type Result = { tierReachedAt: { [number]: number }, completeAt: number?, rebirthReadyAt: number? }

local EconomySim = {}

local CELL = MapConfig.CELL_SIZE
local TICK = FieldConfig.HARVEST_INTERVAL

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
local function zoneIncome(tier: VehicleConfig.TierDef, zone: string): (number, number)
	local band = MapGeometry.bandOf(zone)
	local distance = MapConfig.STEM.minX + band.startDistance - MapConfig.BASE_CENTER_X
	local fillSeconds = tier.capacity / cutRate(tier, zone)
	local tripSeconds = fillSeconds + 2 * distance / tier.speed
	local value = tier.capacity * FieldConfig.WHEAT_ZONES[zone].value
	return value / tripSeconds, tripSeconds
end

local function bestZone(tier: VehicleConfig.TierDef): (number, number)
	local bestRate, bestTrip = 0, 1
	for zone in FieldConfig.WHEAT_ZONES do
		local rate, trip = zoneIncome(tier, zone)
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
	for _, machine in TycoonConfig.MACHINES do
		if Tycoon.buy(state, machine.id, tierId).isPurchased then
			return tierId
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
	local result: Result = { tierReachedAt = { [1] = 0 } }
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

return EconomySim
