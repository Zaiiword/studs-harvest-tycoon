--!strict
-- Intégration Sprint 3 : récolter, décharger au silo, laisser tourner l'usine, acheter une machine.
-- Même enchaînement que HarvestService + TycoonService, sans Roblox et avec une horloge simulée.
local TestKit = require("../TestKit")
local FakeRng = require("../helpers/FakeRng")
local TycoonConfig = require("../../src/shared/config/TycoonConfig")
local VehicleConfig = require("../../src/shared/config/VehicleConfig")
local Bag = require("../../src/shared/domain/Bag")
local FieldGrid = require("../../src/shared/domain/FieldGrid")
local Tycoon = require("../../src/shared/domain/Tycoon")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local NO_BONUS = Tycoon.NO_BONUS

-- Remplit un sac des Mains Nues en coupant le Blé Vert le long d'une ligne.
local function fillBag(grid: FieldGrid.FieldGrid, bag: Bag.Bag)
	local tier = VehicleConfig.TIERS[1]
	local x = 30
	while not Bag.isFull(bag) do
		x += 2
		for _, index in grid:queryHitbox({ x = x, z = 4, dirX = 1, dirZ = 0, size = tier.hitboxStuds }) do
			local result = grid:damage(index, tier.cutPower, 0)
			if result and not Bag.isFull(bag) then
				Bag.add(bag, result.value)
			end
		end
	end
end

local function runFactory(state: Tycoon.State, seconds: number)
	for _ = 1, seconds do
		Tycoon.tick(state, TycoonConfig.INCOME_INTERVAL, NO_BONUS)
	end
end

describe("Boucle économique", function()
	it("un sac plein déchargé au silo devient de l'argent", function()
		local grid, bag, state =
			FieldGrid.new(FakeRng.constant(0.5)), Bag.new(VehicleConfig.TIERS[1].capacity), Tycoon.new()
		fillBag(grid, bag)
		local _, value = Bag.withdraw(bag, TycoonConfig.SILO_CAPACITY - state.silo)
		Tycoon.deposit(state, value)
		expect(state.silo).toBe(VehicleConfig.TIERS[1].capacity) -- Blé Vert : 1 $ brut par brin
		runFactory(state, 60)
		expect(state.silo).toBe(0)
		expect(state.money).toBe(VehicleConfig.TIERS[1].capacity)
	end)

	it("le Moulin rapporte ×1,5 sur la récolte suivante", function()
		local state = Tycoon.new()
		state.money = TycoonConfig.MACHINES[1].price
		expect(Tycoon.buy(state, "Mill", 1).isPurchased).toBe(true)
		Tycoon.deposit(state, 100)
		runFactory(state, 100)
		expect(state.money).toBeCloseTo(150)
	end)

	it("deux sacs de Mains Nues suffisent pour améliorer le tapis (premiers achats rapides, CDC §8)", function()
		local state = Tycoon.new()
		Tycoon.deposit(state, 2 * VehicleConfig.TIERS[1].capacity)
		runFactory(state, 60)
		expect(Tycoon.buy(state, "Conveyor", 1).isPurchased).toBe(true)
	end)
end)
