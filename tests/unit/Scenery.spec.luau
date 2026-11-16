--!strict
local TestKit = require("../TestKit")
local DecorConfig = require("../../src/shared/config/DecorConfig")
local MapConfig = require("../../src/shared/config/MapConfig")
local PetConfig = require("../../src/shared/config/PetConfig")
local PetVisualConfig = require("../../src/shared/config/PetVisualConfig")
local SceneryConfig = require("../../src/shared/config/SceneryConfig")
local MapGeometry = require("../../src/shared/domain/MapGeometry")
local Scenery = require("../../src/shared/domain/Scenery")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local SQUARE_REACH = math.sqrt(2)

describe("Scenery", function()
	describe("rng", function()
		it("donne la même suite pour la même graine", function()
			local a, b = Scenery.rng(42), Scenery.rng(42)
			for _ = 1, 20 do
				expect(a()).toBe(b())
			end
		end)
		it("reste dans [0, 1[", function()
			local rng = Scenery.rng(SceneryConfig.SEED)
			for _ = 1, 500 do
				local value = rng()
				expect(value >= 0 and value < 1).toBe(true)
			end
		end)
	end)

	describe("isClear", function()
		it("refuse le champ, la barre et le fossé", function()
			expect(Scenery.isClear(400, 0, 0)).toBe(false)
			expect(Scenery.isClear(-100, 0, 0)).toBe(false)
			expect(Scenery.isClear(12, 0, 0)).toBe(false)
		end)
		it("accepte la mer, les berges et l'arrière du champ", function()
			expect(Scenery.isClear(-400, 0, 50)).toBe(true)
			expect(Scenery.isClear(400, 400, 50)).toBe(true)
			expect(Scenery.isClear(MapConfig.STEM.maxX + 200, 0, 50)).toBe(true)
		end)
	end)

	describe("berges", function()
		it("longent les murs du champ par l'extérieur", function()
			for _, side in { -1, 1 } do
				local frame = Scenery.bankFrame(side)
				for _, u in { 0, frame.length / 2, frame.length } do
					local x, z = Scenery.bankPoint(frame, u, 0)
					local wallOuter = MapGeometry.stemHalfWidth(x)
						+ MapConfig.CELL_SIZE / 2
						+ DecorConfig.STEM_WALL.THICKNESS
					expect(math.abs(z) > wallOuter).toBe(true)
					expect(z * side > 0).toBe(true)
				end
			end
		end)
		it("s'éloignent du champ quand v grandit", function()
			local frame = Scenery.bankFrame(1)
			local _, nearZ = Scenery.bankPoint(frame, 300, 10)
			local _, farZ = Scenery.bankPoint(frame, 300, 200)
			expect(farZ > nearZ).toBe(true)
		end)
	end)

	describe("hills", function()
		local hills = Scenery.hills()

		it("pose des collines et des montagnes des deux côtés", function()
			local counts = { hill = 0, mountain = 0 }
			for _, hill in hills do
				counts[hill.kind] += 1
			end
			expect(counts.hill > 10).toBe(true)
			expect(counts.mountain > 6).toBe(true)
		end)
		it("ne touche jamais une zone où l'on joue", function()
			for _, hill in hills do
				expect(Scenery.isClear(hill.x, hill.z, hill.radius * SQUARE_REACH)).toBe(true)
			end
		end)
		it("est le même à chaque appel", function()
			local again = Scenery.hills()
			expect(#again).toBe(#hills)
			for index, hill in hills do
				expect(again[index].x).toBe(hill.x)
				expect(again[index].radius).toBe(hill.radius)
			end
		end)
		it("donne des moulins à certaines collines seulement", function()
			local windmills = 0
			for _, hill in hills do
				if hill.feature == "windmill" then
					windmills += 1
					expect(hill.kind).toBe("hill")
				end
			end
			expect(windmills >= 4).toBe(true)
		end)
	end)

	describe("bankTrees", function()
		local trees = Scenery.bankTrees()

		it("plante une forêt hors du champ", function()
			expect(#trees > 60).toBe(true)
			for _, tree in trees do
				expect(Scenery.isClear(tree.x, tree.z, 6)).toBe(true)
			end
		end)
		it("ne plante aucun arbre sous une colline", function()
			for _, tree in trees do
				for _, hill in Scenery.hills() do
					local distance = math.sqrt((tree.x - hill.x) ^ 2 + (tree.z - hill.z) ^ 2)
					expect(distance >= hill.radius * SQUARE_REACH).toBe(true)
				end
			end
		end)
		it("ne tire que des essences connues", function()
			local known: { [string]: boolean } = {}
			for _, kind in SceneryConfig.TREE.KINDS do
				known[kind.id] = true
			end
			for _, tree in trees do
				expect(known[tree.kind] == true).toBe(true)
			end
		end)
	end)

	describe("rivière", function()
		it("garde nénuphars et canards dans le fossé, jamais sous un pont", function()
			local river = SceneryConfig.RIVER
			for _, spots in { Scenery.lilies(), Scenery.ducks() } do
				for _, spot in spots do
					expect(MapGeometry.zoneAt(spot.x, spot.z)).toBe("Moat")
					expect(MapGeometry.isUnderBridge(spot.x, spot.z, river.BRIDGE_MARGIN)).toBe(false)
				end
			end
		end)
		it("pose le nombre prévu de chaque", function()
			expect(#Scenery.lilies()).toBe(SceneryConfig.RIVER.LILY_COUNT)
			expect(#Scenery.ducks()).toBe(SceneryConfig.RIVER.DUCK_COUNT)
		end)
	end)

	describe("gardens", function()
		local props = Scenery.gardens()

		it("reste sur la barre, hors des bases et du boulevard", function()
			expect(#props > 50).toBe(true)
			for _, prop in props do
				expect(MapGeometry.zoneAt(prop.x, prop.z)).toBe("Plaza")
				expect(MapGeometry.isOnRoad(prop.x, prop.z)).toBe(false)
				for _, base in MapGeometry.baseCenters() do
					expect(MapGeometry.isInsideBase(base, prop.x, prop.z)).toBe(false)
				end
			end
		end)
	end)

	describe("lampPosts", function()
		it("éclaire chaque allée sans jamais gêner une porte de base", function()
			local posts = Scenery.lampPosts()
			expect(#posts).toBe(MapConfig.BASE_COUNT + 1)
			for _, post in posts do
				expect(MapGeometry.isOnRoad(post.x, post.z)).toBe(false)
				for _, base in MapGeometry.baseCenters() do
					expect(math.abs(post.z - base.z) > DecorConfig.FENCE.GATE_WIDTH / 2).toBe(true)
				end
			end
		end)
	end)

	describe("ciel et mer", function()
		it("pose le nombre prévu de nuages, au-dessus de tout le décor", function()
			local clouds = Scenery.clouds()
			expect(#clouds).toBe(SceneryConfig.CLOUD.COUNT)
			for _, cloud in clouds do
				expect(cloud.y >= SceneryConfig.CLOUD.MIN_Y).toBe(true)
			end
		end)
		it("garde îles, phare et voiliers en mer", function()
			for _, island in SceneryConfig.ISLAND.SPOTS do
				expect(Scenery.isClear(island.x, island.z, island.radius * SQUARE_REACH)).toBe(true)
			end
			local lighthouse = SceneryConfig.LIGHTHOUSE
			expect(Scenery.isClear(lighthouse.x, lighthouse.z, lighthouse.ROCK_RADIUS * SQUARE_REACH)).toBe(true)
			for _, boat in SceneryConfig.BOAT.SPOTS do
				expect(Scenery.isClear(boat.x, boat.z, 12)).toBe(true)
			end
		end)
		it("garde les parasols sur la plage", function()
			for _, prop in Scenery.beachProps() do
				expect(prop.x < MapConfig.PLAZA.minX).toBe(true)
				expect(prop.x > MapConfig.PLAZA.minX - SceneryConfig.BEACH.STEPS[1].depth).toBe(true)
			end
		end)
	end)

	describe("œufs", function()
		it("donne un motif à chaque œuf", function()
			for _, egg in PetConfig.EGGS do
				local look = PetVisualConfig.EGG_LOOKS[egg.id]
				expect(look ~= nil and look.spots > 0).toBe(true)
			end
		end)
	end)
end)
