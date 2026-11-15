--!strict
local TestKit = require("../TestKit")
local Social = require("../../src/shared/domain/Social")
local Tycoon = require("../../src/shared/domain/Tycoon")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("Bonus social (A63)", function()
	it("vaut 1 seul et sans Premium", function()
		expect(Social.multiplier(0, false)).toBe(1)
	end)
	it("ajoute 10 % par ami, dans la limite de 4", function()
		expect(Social.multiplier(2, false)).toBeCloseTo(1.2)
		expect(Social.multiplier(9, false)).toBeCloseTo(1.4)
	end)
	it("ajoute 10 % pour Premium", function()
		expect(Social.multiplier(0, true)).toBeCloseTo(1.1)
		expect(Social.multiplier(4, true)).toBeCloseTo(1.5)
	end)
	it("s'affiche en pourcentage", function()
		expect(Social.percent(Social.multiplier(2, true))).toBe("+30 %")
	end)
	it("multiplie le revenu de l'usine", function()
		local state = Tycoon.new()
		state.silo = 100
		local base = Tycoon.incomePerSecond(state, Tycoon.NO_BONUS)
		local social = Tycoon.incomePerSecond(
			state,
			{ petBonuses = {}, rebirths = 0, hasIncomeX2 = false, socialMultiplier = 1.2 }
		)
		expect(social).toBeCloseTo(base * 1.2)
	end)
end)
