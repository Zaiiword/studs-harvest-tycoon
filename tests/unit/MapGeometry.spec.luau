--!strict
local TestKit = require("../TestKit")
local MapConfig = require("../../src/shared/config/MapConfig")
local MapGeometry = require("../../src/shared/domain/MapGeometry")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function distance(ax: number, az: number, bx: number, bz: number): number
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

local HALF_DIAGONAL = MapConfig.BASE_SIZE * math.sqrt(2) / 2

describe("MapConfig", function()
	it("enchaîne les zones sans trou ni chevauchement", function()
		expect(MapConfig.ZONES[1].innerRadius).toBe(0)
		for i = 2, #MapConfig.ZONES do
			expect(MapConfig.ZONES[i].innerRadius).toBe(MapConfig.ZONES[i - 1].outerRadius)
		end
	end)
	it("couvre toute la carte avec son réseau de cellules", function()
		local crown = MapGeometry.zone("Crown")
		expect(MapConfig.MAP_GRID_SIZE * MapConfig.CELL_SIZE / 2 >= crown.outerRadius).toBe(true)
		expect(MapConfig.MAP_GRID_SIZE % 2).toBe(0)
	end)
	it("est gelée", function()
		expect(function()
			(MapConfig :: any).CELL_SIZE = 1
		end).toThrow()
	end)
end)

describe("MapGeometry", function()
	describe("cellCenter", function()
		it("centre le réseau sur l'origine", function()
			local x, z = MapGeometry.cellCenter(50, 25, 26)
			expect(x).toBe(-MapConfig.CELL_SIZE / 2)
			expect(z).toBe(MapConfig.CELL_SIZE / 2)
		end)
		it("aligne deux réseaux pairs de même pas", function()
			local xSmall = MapGeometry.cellCenter(50, 1, 1)
			local xLarge = MapGeometry.cellCenter(86, 19, 1)
			expect(xSmall).toBe(xLarge)
		end)
	end)

	describe("baseCenters", function()
		local bases = MapGeometry.baseCenters()

		it("place 8 bases (CDC §3)", function()
			expect(#bases).toBe(8)
		end)
		it("les répartit à égale distance les unes des autres", function()
			local expected = distance(bases[1].x, bases[1].z, bases[2].x, bases[2].z)
			for i = 1, #bases do
				local nextBase = bases[i % #bases + 1]
				expect(distance(bases[i].x, bases[i].z, nextBase.x, nextBase.z)).toBeCloseTo(expected)
			end
		end)
		it("ne les fait pas se chevaucher", function()
			expect(distance(bases[1].x, bases[1].z, bases[2].x, bases[2].z) > 2 * HALF_DIAGONAL).toBe(true)
		end)
		it("les garde entièrement dans la couronne", function()
			local crown = MapGeometry.zone("Crown")
			expect(MapConfig.BASE_RADIUS - HALF_DIAGONAL >= crown.innerRadius).toBe(true)
			expect(MapConfig.BASE_RADIUS + HALF_DIAGONAL <= crown.outerRadius).toBe(true)
		end)
	end)

	describe("isInsideBase", function()
		local base = MapGeometry.baseCenters()[1]
		it("accepte le centre de la base", function()
			expect(MapGeometry.isInsideBase(base, base.x, base.z)).toBe(true)
		end)
		it("refuse un point hors de l'emprise", function()
			local far = MapConfig.BASE_SIZE
			expect(MapGeometry.isInsideBase(base, base.x + far, base.z + far)).toBe(false)
			expect(MapGeometry.isInsideBase(base, 0, 0)).toBe(false)
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
				local middle = distance(bridge.x, bridge.z, 0, 0)
				expect(middle - bridge.length / 2 < moat.innerRadius).toBe(true)
				expect(middle + bridge.length / 2 > moat.outerRadius).toBe(true)
			end
		end)
		it("reste étroit", function()
			for _, bridge in bridges do
				expect(bridge.width < MapConfig.BASE_SIZE / 2).toBe(true)
			end
		end)
		it("ne traverse aucune base", function()
			for _, bridge in bridges do
				for _, base in MapGeometry.baseCenters() do
					local lateral = math.abs(-math.sin(bridge.angle) * base.x + math.cos(bridge.angle) * base.z)
					expect(lateral > HALF_DIAGONAL + bridge.width / 2).toBe(true)
				end
			end
		end)
	end)

	describe("isUnderBridge", function()
		it("détecte un point sur le tablier", function()
			local bridge = MapGeometry.bridges()[1]
			expect(MapGeometry.isUnderBridge(bridge.x, bridge.z, 0)).toBe(true)
		end)
		it("ignore le centre de la carte", function()
			expect(MapGeometry.isUnderBridge(0, 0, 0)).toBe(false)
		end)
	end)

	describe("zoneAt", function()
		it("identifie chaque zone par son rayon", function()
			expect(MapGeometry.zoneAt(0, 0)).toBe("Core")
			expect(MapGeometry.zoneAt(40, 0)).toBe("DiamondWheat")
			expect(MapGeometry.zoneAt(0, 80)).toBe("GoldenCorn")
			expect(MapGeometry.zoneAt(-120, 0)).toBe("GreenWheat")
			expect(MapGeometry.zoneAt(160, 0)).toBe("Moat")
			expect(MapGeometry.zoneAt(0, -213)).toBe("Crown")
		end)
		it("traite les rayons comme semi-ouverts", function()
			expect(MapGeometry.zoneAt(24, 0)).toBe("DiamondWheat")
			expect(MapGeometry.zoneAt(258, 0)).toBe(nil)
		end)
	end)

	describe("floorRuns", function()
		local runs = MapGeometry.floorRuns()

		it("ne pose aucun sol dans le fossé", function()
			for _, run in runs do
				expect(MapConfig.VOID_ZONES[run.zone] == nil).toBe(true)
			end
		end)
		it("couvre chaque cellule de sol exactement une fois", function()
			local covered = 0
			for _, run in runs do
				covered += math.round(run.sizeX / MapConfig.CELL_SIZE)
			end
			local expected = 0
			local size = MapConfig.MAP_GRID_SIZE
			for i = 1, size do
				for j = 1, size do
					local zone = MapGeometry.zoneAt(MapGeometry.cellCenter(size, i, j))
					if zone and not MapConfig.VOID_ZONES[zone] then
						expected += 1
					end
				end
			end
			expect(covered).toBe(expected)
		end)
		it("garde chaque rangée dans une seule zone", function()
			for _, run in runs do
				local half = run.sizeX / 2 - MapConfig.CELL_SIZE / 2
				expect(MapGeometry.zoneAt(run.x - half, run.z)).toBe(run.zone)
				expect(MapGeometry.zoneAt(run.x + half, run.z)).toBe(run.zone)
			end
		end)
	end)
end)
