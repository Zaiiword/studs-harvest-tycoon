--!strict
local TestKit = require("../TestKit")
local MapConfig = require("../../src/shared/config/MapConfig")
local MapGeometry = require("../../src/shared/domain/MapGeometry")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function distance(ax: number, az: number, bx: number, bz: number): number
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

describe("MapConfig", function()
	it("enchaîne les zones sans trou ni chevauchement", function()
		expect(MapConfig.ZONES[1].innerRadius).toBe(0)
		for i = 2, #MapConfig.ZONES do
			expect(MapConfig.ZONES[i].innerRadius).toBe(MapConfig.ZONES[i - 1].outerRadius)
		end
	end)
end)

describe("MapGeometry", function()
	describe("baseCenters", function()
		local bases = MapGeometry.baseCenters()

		it("place 8 bases (CDC §3)", function()
			expect(#bases).toBe(8)
		end)
		it("les place toutes à BASE_RADIUS du centre", function()
			for _, base in bases do
				expect(distance(base.x, base.z, 0, 0)).toBeCloseTo(MapConfig.BASE_RADIUS)
			end
		end)
		it("les répartit à égale distance les unes des autres", function()
			local expected = distance(bases[1].x, bases[1].z, bases[2].x, bases[2].z)
			for i = 1, #bases do
				local nextBase = bases[i % #bases + 1]
				expect(distance(bases[i].x, bases[i].z, nextBase.x, nextBase.z)).toBeCloseTo(expected)
			end
		end)
		it("ne les fait pas se chevaucher", function()
			local minGap = distance(bases[1].x, bases[1].z, bases[2].x, bases[2].z)
			expect(minGap > MapConfig.BASE_SIZE * math.sqrt(2)).toBe(true)
		end)
		it("les garde entièrement dans la couronne", function()
			local crown = MapGeometry.zone("Crown")
			local halfDiagonal = MapConfig.BASE_SIZE * math.sqrt(2) / 2
			expect(MapConfig.BASE_RADIUS - halfDiagonal >= crown.innerRadius).toBe(true)
			expect(MapConfig.BASE_RADIUS + halfDiagonal <= crown.outerRadius).toBe(true)
			for _, base in bases do
				expect(MapGeometry.zoneAt(base.x, base.z)).toBe("Crown")
			end
		end)
	end)

	describe("bridges", function()
		local bridges = MapGeometry.bridges()
		local moat = MapGeometry.zone("Moat")

		it("pose 4 ponts (CDC §3)", function()
			expect(#bridges).toBe(4)
		end)
		it("franchit le fossé en recouvrant les deux rives", function()
			for _, bridge in bridges do
				local nearEdge = distance(bridge.x, bridge.z, 0, 0) - bridge.length / 2
				local farEdge = distance(bridge.x, bridge.z, 0, 0) + bridge.length / 2
				expect(nearEdge < moat.innerRadius).toBe(true)
				expect(farEdge > moat.outerRadius).toBe(true)
			end
		end)
		it("reste étroit", function()
			for _, bridge in bridges do
				expect(bridge.width).toBe(MapConfig.BRIDGE_WIDTH)
				expect(bridge.width < MapConfig.BASE_SIZE / 2).toBe(true)
			end
		end)
		it("ne traverse aucune base", function()
			local halfDiagonal = MapConfig.BASE_SIZE * math.sqrt(2) / 2
			for _, bridge in bridges do
				for _, base in MapGeometry.baseCenters() do
					-- Distance de la base à l'axe du pont (droite passant par l'origine à l'angle du pont).
					local lateral = math.abs(-math.sin(bridge.angle) * base.x + math.cos(bridge.angle) * base.z)
					expect(lateral > halfDiagonal + bridge.width / 2).toBe(true)
				end
			end
		end)
	end)

	describe("annulusSegments", function()
		it("produit le nombre de segments demandé, centrés au rayon moyen", function()
			local segments = MapGeometry.annulusSegments(350, 450, 64)
			expect(#segments).toBe(64)
			for _, segment in segments do
				expect(distance(segment.x, segment.z, 0, 0)).toBeCloseTo(400)
				expect(segment.depth).toBe(100)
			end
		end)
		it("refuse un anneau dégénéré", function()
			expect(function()
				MapGeometry.annulusSegments(10, 10, 8)
			end).toThrow()
		end)
	end)

	describe("zoneAt", function()
		it("identifie chaque zone par son rayon", function()
			expect(MapGeometry.zoneAt(0, 0)).toBe("Core")
			expect(MapGeometry.zoneAt(100, 0)).toBe("DiamondWheat")
			expect(MapGeometry.zoneAt(0, 180)).toBe("GoldenCorn")
			expect(MapGeometry.zoneAt(-280, 0)).toBe("GreenWheat")
			expect(MapGeometry.zoneAt(340, 0)).toBe("Moat")
			expect(MapGeometry.zoneAt(0, -400)).toBe("Crown")
		end)
		it("traite les rayons comme semi-ouverts", function()
			expect(MapGeometry.zoneAt(60, 0)).toBe("DiamondWheat")
			expect(MapGeometry.zoneAt(450, 0)).toBe(nil)
		end)
	end)
end)
