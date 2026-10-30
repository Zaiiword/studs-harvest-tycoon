--!strict
local TestKit = require("../TestKit")
local FieldConfig = require("../../src/shared/config/FieldConfig")
local PlantConfig = require("../../src/shared/config/PlantConfig")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("PlantConfig", function()
	it("donne une forme détaillée et une forme simple à chaque bande de blé", function()
		for zone in FieldConfig.WHEAT_ZONES do
			local shapes = PlantConfig.SHAPES[zone]
			expect(shapes ~= nil).toBe(true)
			expect(#shapes.detailed <= PlantConfig.DETAILED_PIECES).toBe(true)
			expect(#shapes.simple <= PlantConfig.SIMPLE_PIECES).toBe(true)
		end
	end)
	it("a une couleur pour chaque rôle de pièce utilisé", function()
		for zone, shapes in PlantConfig.SHAPES do
			for _, shape in { shapes.detailed, shapes.simple } do
				for _, piece in shape do
					expect(PlantConfig.COLORS[zone][piece.role] ~= nil).toBe(true)
				end
			end
		end
	end)
	it("n'a que des pièces de taille positive, posées au-dessus du sol", function()
		for _, shapes in PlantConfig.SHAPES do
			for _, shape in { shapes.detailed, shapes.simple } do
				for _, piece in shape do
					for _, dimension in piece.size do
						expect(dimension > 0).toBe(true)
					end
					expect(piece.offset[2] > 0).toBe(true)
				end
			end
		end
	end)
	it("a un épi dans chaque forme (c'est lui qui change de couleur en Arc-en-ciel)", function()
		for _, shapes in PlantConfig.SHAPES do
			for _, shape in { shapes.detailed, shapes.simple } do
				local hasEar = false
				for _, piece in shape do
					hasEar = hasEar or piece.role == "ear"
				end
				expect(hasEar).toBe(true)
			end
		end
	end)
end)
