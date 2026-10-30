--!strict
local TestKit = require("../TestKit")
local FakeRng = require("../helpers/FakeRng")
local FieldConfig = require("../../src/shared/config/FieldConfig")
local FieldChunks = require("../../src/shared/domain/FieldChunks")
local FieldGrid = require("../../src/shared/domain/FieldGrid")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("FieldChunks", function()
	local grid = FieldGrid.new(FakeRng.constant(0.5))
	local map = FieldChunks.build(grid)

	it("range chaque brin dans exactement un chunk", function()
		local total = 0
		for _, chunk in map.ordered do
			total += #chunk.indices
		end
		expect(total).toBe(#grid:activeIndices())
	end)
	it("ne dépasse jamais 2 500 brins affichés (CDC §4, A32)", function()
		for _, x in { 30, 300, 600, 1000, 1250 } do
			local used = 0
			for _, chunk in FieldChunks.visible(map, x, 0, math.huge, FieldConfig.MAX_STALKS) do
				used += #chunk.indices
			end
			expect(used <= FieldConfig.MAX_STALKS).toBe(true)
		end
	end)
	it("affiche en priorité les chunks les plus proches", function()
		local visible = FieldChunks.visible(map, 600, 0, FieldConfig.RENDER_RADIUS, FieldConfig.MAX_STALKS)
		local first, last = visible[1], visible[#visible]
		local function distance(chunk: FieldChunks.Chunk): number
			return math.sqrt((chunk.x - 600) ^ 2 + chunk.z ^ 2)
		end
		expect(distance(first) <= distance(last)).toBe(true)
	end)
	it("remplit le rayon d'affichage autour du joueur", function()
		local visible = FieldChunks.visible(map, 600, 0, FieldConfig.RENDER_RADIUS, FieldConfig.MAX_STALKS)
		expect(#visible > 20).toBe(true)
	end)
	it("n'affiche rien loin du champ", function()
		expect(#FieldChunks.visible(map, -2000, 0, FieldConfig.RENDER_RADIUS, FieldConfig.MAX_STALKS)).toBe(0)
	end)
end)
