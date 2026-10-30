--!strict
local TestKit = require("../TestKit")
local FakeRng = require("../helpers/FakeRng")
local PetConfig = require("../../src/shared/config/PetConfig")
local Formulas = require("../../src/shared/domain/Formulas")
local Pets = require("../../src/shared/domain/Pets")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function filled(key: string, count: number): Pets.Collection
	local collection = Pets.newCollection()
	for _ = 1, count do
		Pets.add(collection, key)
	end
	return collection
end

describe("Pets", function()
	describe("bonus", function()
		it("suit la table du CDC §8", function()
			expect(Pets.bonusOf("Chick:Normal")).toBe(1.2)
			expect(Pets.bonusOf("Dragon:Normal")).toBe(5)
			expect(Pets.bonusOf("Phoenix:Normal")).toBe(15)
		end)
		it("amplifie le bonus au-delà de 1 pour Or (×2) et Arc-en-ciel (×5) (A17)", function()
			expect(Pets.bonusOf("Chick:Gold")).toBeCloseTo(1.4)
			expect(Pets.bonusOf("Chick:Rainbow")).toBeCloseTo(2)
			expect(Pets.bonusOf("Dragon:Rainbow")).toBe(21)
		end)
		it("donne un facteur de 1 sans Pet équipé (A1)", function()
			expect(Formulas.petFactor(Pets.bonuses(Pets.newCollection()))).toBe(1)
		end)
	end)

	describe("roll", function()
		local basic = Pets.egg("BasicEgg") :: PetConfig.EggDef
		it("respecte les seuils de l'œuf de base (CDC §8)", function()
			expect(Pets.roll(basic, FakeRng.constant(0))).toBe("Chick:Normal")
			expect(Pets.roll(basic, FakeRng.constant(0.61))).toBe("Cow:Normal")
			expect(Pets.roll(basic, FakeRng.constant(0.9))).toBe("Tractor:Normal")
			expect(Pets.roll(basic, FakeRng.constant(0.96))).toBe("Dragon:Normal")
			expect(Pets.roll(basic, FakeRng.constant(0.9995))).toBe("Phoenix:Normal")
		end)
		it("ne donne jamais de Commun avec l'Œuf de Ferme", function()
			local farm = Pets.egg("FarmEgg") :: PetConfig.EggDef
			local rng = FakeRng.seeded(3)
			for _ = 1, 500 do
				expect(Pets.roll(farm, rng) ~= "Chick:Normal").toBe(true)
			end
		end)
		it("tire les fréquences annoncées sur un grand échantillon", function()
			local rng = FakeRng.seeded(11)
			local commons = 0
			for _ = 1, 20_000 do
				commons += if Pets.roll(basic, rng) == "Chick:Normal" then 1 else 0
			end
			expect(math.abs(commons / 20_000 - 0.6) < 0.02).toBe(true)
		end)
	end)

	describe("équipement", function()
		it("équipe 3 Pets au plus (A42)", function()
			local collection = filled("Chick:Normal", 5)
			for _ = 1, 3 do
				expect(Pets.equip(collection, "Chick:Normal")).toBe(true)
			end
			expect(Pets.equip(collection, "Chick:Normal")).toBe(false)
		end)
		it("n'équipe pas plus d'exemplaires qu'on en possède", function()
			local collection = filled("Cow:Normal", 1)
			expect(Pets.equip(collection, "Cow:Normal")).toBe(true)
			expect(Pets.equip(collection, "Cow:Normal")).toBe(false)
		end)
		it("plafonne la collection à MAX_PETS", function()
			local collection = filled("Chick:Normal", PetConfig.MAX_PETS)
			expect(Pets.add(collection, "Chick:Normal")).toBe(false)
		end)
	end)

	describe("fusion", function()
		it("fusionne 5 Pets identiques en un Pet Or, puis 5 Or en Arc-en-ciel (CDC §7.2)", function()
			local collection = filled("Dragon:Normal", 7)
			expect(Pets.fuse(collection, "Dragon:Normal")).toBe("Dragon:Gold")
			expect(collection.owned["Dragon:Normal"]).toBe(2)
			collection.owned["Dragon:Gold"] = 5
			expect(Pets.fuse(collection, "Dragon:Gold")).toBe("Dragon:Rainbow")
		end)
		it("refuse sans 5 exemplaires, et au sommet (Arc-en-ciel)", function()
			expect(Pets.fuse(filled("Chick:Normal", 4), "Chick:Normal")).toBe(nil)
			expect(Pets.fuse(filled("Chick:Rainbow", 5), "Chick:Rainbow")).toBe(nil)
		end)
		it("déséquipe les exemplaires consommés par la fusion", function()
			local collection = filled("Chick:Normal", 5)
			Pets.equip(collection, "Chick:Normal")
			Pets.fuse(collection, "Chick:Normal")
			expect(#collection.equipped).toBe(0)
		end)
	end)

	describe("sauvegarde et réseau", function()
		it("nettoie une collection corrompue", function()
			local collection = Pets.sanitize({
				owned = { ["Chick:Normal"] = 2.9, ["Unicorn:Normal"] = 3, ["Cow:Gold"] = -1 },
				equipped = { "Chick:Normal", "Chick:Normal", "Chick:Normal", "Hack" },
			})
			expect(collection.owned["Chick:Normal"]).toBe(2)
			expect(collection.owned["Unicorn:Normal"]).toBe(nil)
			expect(collection.owned["Cow:Gold"]).toBe(nil)
			expect(#collection.equipped).toBe(2)
		end)
		it("encode et relit la collection pour le menu client", function()
			local text = Pets.encodeOwned({ ["Dragon:Gold"] = 2, ["Cow:Normal"] = 5 })
			expect(text).toBe("Cow:Normal=5,Dragon:Gold=2")
			local owned = Pets.decodeOwned(text .. ",Hack:Normal=9")
			expect(owned["Dragon:Gold"]).toBe(2)
			expect(owned["Hack:Normal"]).toBe(nil)
		end)
		it("encode et relit les Pets équipés, en ignorant les clés inconnues", function()
			local text = Pets.encodeEquipped({ "Chick:Normal", "Dragon:Gold" })
			local keys = Pets.decodeEquipped(text .. ",Hack:Normal")
			expect(#keys).toBe(2)
			expect(keys[2]).toBe("Dragon:Gold")
		end)
	end)
end)
