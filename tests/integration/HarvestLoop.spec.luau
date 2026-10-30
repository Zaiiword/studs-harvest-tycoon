--!strict
-- Intégration du domaine de récolte : un joueur traverse l'anneau Blé Vert, coupe, remplit son sac,
-- puis le champ repousse. Même enchaînement que HarvestService, sans Roblox et avec une horloge simulée.
local TestKit = require("../TestKit")
local FakeRng = require("../helpers/FakeRng")
local FieldConfig = require("../../src/shared/config/FieldConfig")
local VehicleConfig = require("../../src/shared/config/VehicleConfig")
local FieldGrid = require("../../src/shared/domain/FieldGrid")
local Bag = require("../../src/shared/domain/Bag")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- Couloir de marche au milieu de la tige : début du Blé Vert, et Blé Diamant.
local LANE_Z = 4
local GREEN_X = 30
local DIAMOND_X = 1000

type Run = { grid: FieldGrid.FieldGrid, bag: Bag.Bag, cutIndices: { number }, now: number }

-- Avance de `tier.speed` studs/s vers +x sur la ligne z, une requête de coupe toutes les 0,15 s.
local function walk(run: Run, tierId: number, fromX: number, z: number, seconds: number)
	local tier = VehicleConfig.TIERS[tierId]
	local x = fromX
	local ticks = math.floor(seconds / FieldConfig.HARVEST_INTERVAL)
	for _ = 1, ticks do
		run.now += FieldConfig.HARVEST_INTERVAL
		x += tier.speed * FieldConfig.HARVEST_INTERVAL
		run.grid:regrowDue(run.now)
		local hitbox = { x = x, z = z, dirX = 1, dirZ = 0, size = tier.hitboxStuds }
		for _, index in run.grid:queryHitbox(hitbox) do
			if Bag.isFull(run.bag) then
				return
			end
			local result = run.grid:damage(index, tier.cutPower, run.now)
			if result then
				Bag.add(run.bag, result.value)
				table.insert(run.cutIndices, index)
			end
		end
	end
end

local function newRun(tierId: number): Run
	local grid = FieldGrid.new(FakeRng.constant(0.5))
	return { grid = grid, bag = Bag.new(VehicleConfig.TIERS[tierId].capacity), cutIndices = {}, now = 0 }
end

describe("Boucle de récolte", function()
	it("les Mains Nues coupent du Blé Vert en marchant (Sprint 1)", function()
		local run = newRun(1)
		walk(run, 1, GREEN_X, LANE_Z, 2)
		expect(run.bag.count > 0).toBe(true)
		expect(run.bag.value).toBe(run.bag.count) -- Blé Vert : 1 $ par brin
	end)

	it("remplit le sac jusqu'à sa capacité puis s'arrête", function()
		local run = newRun(1)
		walk(run, 1, GREEN_X, LANE_Z, 20)
		expect(Bag.isFull(run.bag)).toBe(true)
		expect(run.bag.count).toBe(VehicleConfig.TIERS[1].capacity)
	end)

	-- Avec des cellules de 6 studs, Mains Nues (4) et Faux (7) couvrent le même nombre de rangées :
	-- l'écart entre ces deux paliers vient de la puissance et de la capacité (décision A24).
	it("un outil plus large coupe plus vite", function()
		local hands, tractor = newRun(1), newRun(4)
		walk(hands, 1, GREEN_X, LANE_Z, 1)
		walk(tractor, 4, GREEN_X, LANE_Z, 1)
		expect(tractor.bag.count > 2 * hands.bag.count).toBe(true)
	end)

	it("les brins coupés repoussent 8 s plus tard et redeviennent récoltables", function()
		local run = newRun(1)
		walk(run, 1, GREEN_X, LANE_Z, 1)
		local first = run.cutIndices[1]
		expect((run.grid:cell(first) :: FieldGrid.Cell).isGrown).toBe(false)
		run.grid:regrowDue(run.now + FieldConfig.REGROW_SECONDS)
		expect((run.grid:cell(first) :: FieldGrid.Cell).isGrown).toBe(true)
	end)

	it("les Mains Nues n'abattent pas le Blé Diamant en un passage (verrou souple, A3)", function()
		local run = newRun(1)
		walk(run, 1, DIAMOND_X, LANE_Z, 1)
		expect(run.bag.count).toBe(0)
	end)
end)
