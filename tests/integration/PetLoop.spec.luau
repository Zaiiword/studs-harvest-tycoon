--!strict
-- Intégration Sprint 6 : faire éclore, équiper, fusionner, et sentir l'effet des Pets sur l'usine (revenus)
-- et sur la récolte (puissance de coupe contre le Blé Diamant, A2).
local TestKit = require("../TestKit")
local FakeRng = require("../helpers/FakeRng")
local FieldConfig = require("../../src/shared/config/FieldConfig")
local PetConfig = require("../../src/shared/config/PetConfig")
local TycoonConfig = require("../../src/shared/config/TycoonConfig")
local VehicleConfig = require("../../src/shared/config/VehicleConfig")
local Formulas = require("../../src/shared/domain/Formulas")
local Pets = require("../../src/shared/domain/Pets")
local Rebirth = require("../../src/shared/domain/Rebirth")
local Tycoon = require("../../src/shared/domain/Tycoon")
local PetRequests = require("../../src/shared/net/PetRequests")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("Boucle des Pets", function()
	it("un Dragon Doré équipé multiplie les revenus de l'usine par 5 (CDC §8, A1)", function()
		local collection = Pets.newCollection()
		Pets.add(collection, Pets.roll(Pets.egg("LegendaryEgg") :: PetConfig.EggDef, FakeRng.constant(0)))
		Pets.equip(collection, "Dragon:Normal")
		local bonus = Rebirth.incomeBonus(Rebirth.newProgress())
		bonus.petBonuses = Pets.bonuses(collection)
		local state = Tycoon.new()
		Tycoon.deposit(state, 100)
		expect(Tycoon.tick(state, 1, bonus)).toBe(5 * TycoonConfig.CONVEYOR.BASE_RATE)
	end)

	it("trois Pets cumulent leurs bonus au-delà de 1 (1 + Σ(bonus − 1))", function()
		local collection = Pets.newCollection()
		for _, key in { "Chick:Normal", "Cow:Normal", "Tractor:Normal" } do
			Pets.add(collection, key)
			Pets.equip(collection, key)
		end
		expect(Formulas.petFactor(Pets.bonuses(collection))).toBeCloseTo(1 + 0.2 + 0.6 + 1.5)
	end)

	it("des Pets permettent à la Tondeuse d'abattre le Blé Diamant d'un coup (A2)", function()
		local mower = VehicleConfig.TIERS[3]
		local diamondHp = FieldConfig.WHEAT_ZONES.DiamondWheat.hp
		expect(mower.cutPower >= diamondHp).toBe(false)
		local collection = Pets.newCollection()
		for _ = 1, 3 do
			Pets.add(collection, "Dragon:Rainbow")
			Pets.equip(collection, "Dragon:Rainbow")
		end
		expect(mower.cutPower * Formulas.petFactor(Pets.bonuses(collection)) >= diamondHp).toBe(true)
	end)

	it("vingt-cinq Poussins deviennent un Poussin Arc-en-ciel en deux fusions", function()
		local collection = Pets.newCollection()
		for _ = 1, 25 do
			Pets.add(collection, "Chick:Normal")
		end
		for _ = 1, 5 do
			Pets.fuse(collection, "Chick:Normal")
		end
		expect(Pets.fuse(collection, "Chick:Gold")).toBe("Chick:Rainbow")
		expect(Pets.total(collection)).toBe(1)
	end)
end)

describe("Requêtes Pets", function()
	it("n'accepte que les actions et les clés connues", function()
		local action, key = PetRequests.parseAction("equip", "Cow:Gold")
		expect(action).toBe("equip")
		expect(key).toBe("Cow:Gold")
		expect(PetRequests.parseAction("sell", "Cow:Gold")).toBe(nil)
		expect(PetRequests.parseAction("equip", "Cow:Platinum")).toBe(nil)
		expect(PetRequests.parseAction("equip", 12)).toBe(nil)
	end)
	it("n'ouvre depuis le menu que les œufs gagnés (pas les œufs payants)", function()
		expect((PetRequests.parseItemEgg("LegendaryEgg") :: PetConfig.EggDef).id).toBe("LegendaryEgg")
		expect(PetRequests.parseItemEgg("BasicEgg")).toBe(nil)
		expect(PetRequests.parseItemEgg("Hack")).toBe(nil)
	end)
end)
