--!strict
-- Valeurs figées de l'usine (CDC §8, A7, A33) : un changement d'équilibrage doit être intentionnel.
local TestKit = require("../TestKit")
local Tycoon = require("../../src/shared/domain/Tycoon")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("Usine (golden)", function()
	it("prix des 5 premiers niveaux du tapis", function()
		local state = Tycoon.new()
		state.money = math.huge
		local prices = {}
		for _ = 1, 5 do
			table.insert(prices, Tycoon.offer(state, "Conveyor", 1).price)
			Tycoon.buy(state, "Conveyor", 1)
		end
		expect(table.concat(prices :: { any }, ",")).toBe("50,68,91,123,166")
	end)
	it("débit du tapis au niveau 10", function()
		local state = Tycoon.new()
		state.conveyorLevel = 10
		expect(Tycoon.conveyorRate(state)).toBeCloseTo(76.88671875)
	end)
	it("prix des machines", function()
		local state = Tycoon.new()
		expect(Tycoon.offer(state, "Mill", 1).price).toBe(250)
		expect(Tycoon.offer(state, "Oven", 1).price).toBe(2500)
		expect(Tycoon.offer(state, "Factory", 1).price).toBe(40000)
	end)
end)
