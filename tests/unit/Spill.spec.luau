--!strict
local TestKit = require("../TestKit")
local BumperConfig = require("../../src/shared/config/BumperConfig")
local Bag = require("../../src/shared/domain/Bag")
local Spill = require("../../src/shared/domain/Spill")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local SPILL = BumperConfig.SPILL

local function filled(capacity: number, places: number, value: number): Bag.Bag
	local bag = Bag.new(capacity)
	bag.count, bag.value = places, value
	return bag
end

local function fixed(value: number): () -> number
	return function(): number
		return value
	end
end

describe("Spill", function()
	describe("take", function()
		it("retire la part prévue du sac, places et valeur dans la même proportion", function()
			local bag = filled(600, 400, 800)
			local places, value = Spill.take(bag)
			expect(places).toBe(math.floor(400 * SPILL.SHARE))
			expect(value).toBe(800 * places / 400)
			expect(bag.count).toBe(400 - places)
			expect(bag.value).toBe(800 - value)
		end)
		it("ne dépouille pas un sac presque vide", function()
			local bag = filled(25, SPILL.MIN_PLACES - 1, 9)
			local places, value = Spill.take(bag)
			expect(places).toBe(0)
			expect(value).toBe(0)
			expect(bag.count).toBe(SPILL.MIN_PLACES - 1)
		end)
		it("laisse toujours la plus grande part à la victime", function()
			local bag = filled(2000, 2000, 2000)
			Spill.take(bag)
			expect(bag.count >= 1000).toBe(true)
		end)
	end)

	describe("scatter", function()
		it("répartit tout le butin, sans perdre ni créer de place", function()
			local piles = Spill.scatter(123, 246, 100, 50, 1, 0, fixed(0.5))
			expect(#piles).toBe(SPILL.PILES)
			local places, value = 0, 0
			for _, pile in piles do
				places += pile.places
				value += pile.value
				expect(pile.places > 0).toBe(true)
			end
			expect(places).toBe(123)
			expect(math.abs(value - 246) < 1e-6).toBe(true)
		end)
		it("ne fait pas plus de tas que de places", function()
			expect(#Spill.scatter(3, 3, 0, 0, 1, 0, fixed(0.5))).toBe(3)
			expect(#Spill.scatter(0, 0, 0, 0, 1, 0, fixed(0.5))).toBe(0)
		end)
		it("projette les tas dans le sens de l'éjection, à bonne distance", function()
			for _, roll in { 0, 0.5, 0.999 } do
				for _, pile in Spill.scatter(50, 50, 100, 50, 1, 0, fixed(roll)) do
					local dx, dz = pile.x - 100, pile.z - 50
					local distance = math.sqrt(dx * dx + dz * dz)
					expect(distance >= SPILL.MIN_DISTANCE - 1e-6 and distance <= SPILL.MAX_DISTANCE + 1e-6).toBe(true)
					expect(dx > 0).toBe(true) -- jamais vers l'attaquant
				end
			end
		end)
	end)

	describe("pickUp", function()
		it("prend tout le tas quand il tient dans le sac", function()
			local bag = filled(100, 10, 10)
			local pile = { x = 0, z = 0, places = 30, value = 90 }
			expect(Spill.pickUp(bag, pile)).toBe(30)
			expect(bag.count).toBe(40)
			expect(bag.value).toBe(100)
			expect(pile.places).toBe(0)
		end)
		it("ne prend que ce qui tient et laisse le reste au sol", function()
			local bag = filled(50, 40, 40)
			local pile = { x = 0, z = 0, places = 30, value = 90 }
			expect(Spill.pickUp(bag, pile)).toBe(10)
			expect(bag.count).toBe(50)
			expect(bag.value).toBe(70)
			expect(pile.places).toBe(20)
			expect(pile.value).toBe(60)
		end)
		it("ne prend rien dans un sac plein", function()
			local bag = filled(50, 50, 50)
			local pile = { x = 0, z = 0, places = 30, value = 90 }
			expect(Spill.pickUp(bag, pile)).toBe(0)
			expect(pile.places).toBe(30)
		end)
		it("ramasse tout avec une remorque infinie", function()
			local bag = filled(math.huge, 5, 5)
			local pile = { x = 0, z = 0, places = 30, value = 90 }
			expect(Spill.pickUp(bag, pile)).toBe(30)
		end)
	end)

	it("ne crée ni ne détruit de blé d'un bout à l'autre", function()
		local victim, thief = filled(600, 500, 1000), filled(600, 0, 0)
		local places, value = Spill.take(victim)
		for _, pile in Spill.scatter(places, value, 0, 0, 1, 0, fixed(0.3)) do
			Spill.pickUp(thief, pile)
		end
		expect(victim.count + thief.count).toBe(500)
		expect(math.abs(victim.value + thief.value - 1000) < 1e-6).toBe(true)
	end)
end)
