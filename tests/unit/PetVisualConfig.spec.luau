--!strict
local TestKit = require("../TestKit")
local PetConfig = require("../../src/shared/config/PetConfig")
local PetVisualConfig = require("../../src/shared/config/PetVisualConfig")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("PetVisualConfig", function()
	it("donne un modèle à chaque espèce de Pet", function()
		for _, species in PetConfig.SPECIES do
			local pieces = PetVisualConfig.SPECIES[species.id]
			expect(pieces ~= nil and #pieces > 0).toBe(true)
		end
	end)
	it("a une pièce principale par modèle (elle prend la couleur Or / Arc-en-ciel)", function()
		for _, pieces in PetVisualConfig.SPECIES do
			local hasMain = false
			for _, piece in pieces do
				hasMain = hasMain or piece.isMain == true
			end
			expect(hasMain).toBe(true)
		end
	end)
	it("n'a que des pièces de taille positive", function()
		for _, pieces in PetVisualConfig.SPECIES do
			for _, piece in pieces do
				for _, dimension in piece.size do
					expect(dimension > 0).toBe(true)
				end
			end
		end
	end)
end)
