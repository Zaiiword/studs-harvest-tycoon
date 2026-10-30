--!strict
local TestKit = require("../TestKit")
local DecorConfig = require("../../src/shared/config/DecorConfig")
local FieldConfig = require("../../src/shared/config/FieldConfig")
local MapConfig = require("../../src/shared/config/MapConfig")
local Decor = require("../../src/shared/domain/Decor")
local MapGeometry = require("../../src/shared/domain/MapGeometry")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("Decor", function()
	describe("stemWalls", function()
		local walls = Decor.stemWalls()

		it("longe toute la tige des deux côtés, sans trou", function()
			local covered = 0
			for _, wall in walls do
				if wall.z1 > 0 and wall.x1 ~= wall.x2 then
					covered += wall.x2 - wall.x1
				end
			end
			expect(covered).toBe(MapConfig.STEM.maxX - MapConfig.STEM.minX)
		end)
		it("reste à l'extérieur du sol en escalier (pas de mur sur le blé)", function()
			for _, wall in walls do
				if wall.x1 ~= wall.x2 then
					local inner = math.abs(wall.z1) - DecorConfig.STEM_WALL.THICKNESS / 2
					expect(inner >= MapGeometry.stemHalfWidth(wall.x1) + MapConfig.CELL_SIZE / 2).toBe(true)
				end
			end
		end)
		it("ferme le bout du champ", function()
			local last = walls[#walls]
			expect(last.x1 > MapConfig.STEM.maxX - 1).toBe(true)
		end)
	end)

	describe("baseFence", function()
		it("laisse l'accès à la grille de déchargement", function()
			expect(Decor.gateClearsUnloadPad()).toBe(true)
		end)
		it("reste sur l'emprise de la base", function()
			for _, segment in Decor.baseFence() do
				for _, coordinate in { segment.x1, segment.z1, segment.x2, segment.z2 } do
					expect(math.abs(coordinate) <= MapConfig.BASE_SIZE / 2).toBe(true)
				end
			end
		end)
	end)

	describe("treeSpots", function()
		it("plante les arbres sur la barre, jamais sur une base", function()
			for _, spot in Decor.treeSpots() do
				expect(MapGeometry.zoneAt(spot.x, spot.z)).toBe("Plaza")
				for _, base in MapGeometry.baseCenters() do
					expect(MapGeometry.isInsideBase(base, spot.x, spot.z)).toBe(false)
				end
			end
		end)
	end)

	describe("bandGates", function()
		it("pose un portique au début de chaque bande", function()
			expect(#Decor.bandGates()).toBe(#MapConfig.STEM_BANDS)
		end)
	end)

	describe("stalkVariation", function()
		it("est déterministe", function()
			local a, b = Decor.stalkVariation(1234), Decor.stalkVariation(1234)
			expect(a.heightScale).toBe(b.heightScale)
			expect(a.yaw).toBe(b.yaw)
		end)
		it("reste dans les bornes configurées", function()
			local variation = DecorConfig.STALK_VARIATION
			for index = 1, 500 do
				local v = Decor.stalkVariation(index)
				expect(math.abs(v.heightScale - 1) <= variation.HEIGHT).toBe(true)
				expect(math.abs(v.shade - 1) <= variation.SHADE).toBe(true)
				expect(math.abs(v.lean) <= FieldConfig.PLANT.MAX_LEAN).toBe(true)
			end
		end)
		it("varie d'un brin à l'autre", function()
			expect(Decor.stalkVariation(1).heightScale ~= Decor.stalkVariation(2).heightScale).toBe(true)
		end)
	end)
end)
