--!strict
local TestKit = require("../TestKit")
local MapConfig = require("../../src/shared/config/MapConfig")
local MapGeometry = require("../../src/shared/domain/MapGeometry")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local HALF_BASE = MapConfig.BASE_SIZE / 2
local PLAZA, MOAT, STEM = MapConfig.PLAZA, MapConfig.MOAT, MapConfig.STEM

describe("MapConfig", function()
	it("enchaîne barre, fossé et tige sans trou", function()
		expect(PLAZA.maxX).toBe(MOAT.minX)
		expect(MOAT.maxX).toBe(STEM.minX)
	end)
	it("enchaîne les bandes de la tige jusqu'à son bout", function()
		local bands = MapConfig.STEM_BANDS
		expect(bands[1].startDistance).toBe(0)
		for i = 2, #bands do
			expect(bands[i].startDistance).toBe(bands[i - 1].endDistance)
		end
		expect(bands[#bands].endDistance).toBe(STEM.maxX - STEM.minX)
	end)
	it("aligne le réseau du champ sur celui de la carte", function()
		local map, field = MapConfig.MAP_LATTICE, MapConfig.FIELD_LATTICE
		expect((field.minX - map.minX) % MapConfig.CELL_SIZE).toBe(0)
		expect((field.minZ - map.minZ) % MapConfig.CELL_SIZE).toBe(0)
		expect(map.minX + map.cols * MapConfig.CELL_SIZE).toBe(STEM.maxX)
		expect(field.minX + field.cols * MapConfig.CELL_SIZE).toBe(STEM.maxX)
		expect(field.minZ).toBe(-STEM.startHalfWidth)
	end)
	it("est gelée", function()
		expect(function()
			(MapConfig :: any).CELL_SIZE = 1
		end).toThrow()
	end)
end)

describe("MapGeometry", function()
	describe("cellCenter", function()
		it("place la première cellule à une demi-cellule du coin du réseau", function()
			local x, z = MapGeometry.cellCenter(MapConfig.FIELD_LATTICE, 1, 1)
			expect(x).toBe(STEM.minX + MapConfig.CELL_SIZE / 2)
			expect(z).toBe(-STEM.startHalfWidth + MapConfig.CELL_SIZE / 2)
		end)
	end)

	describe("stemHalfWidth", function()
		it("rétrécit la tige en s'éloignant des bases (entonnoir, CDC §3)", function()
			expect(MapGeometry.stemHalfWidth(STEM.minX)).toBe(STEM.startHalfWidth)
			expect(MapGeometry.stemHalfWidth(STEM.maxX)).toBe(STEM.endHalfWidth)
			expect(MapGeometry.stemHalfWidth(500) < MapGeometry.stemHalfWidth(100)).toBe(true)
		end)
	end)

	describe("zoneAt", function()
		it("range la barre, le fossé et les bandes de la tige dans l'ordre", function()
			expect(MapGeometry.zoneAt(-50, 300)).toBe("Plaza")
			expect(MapGeometry.zoneAt(10, 0)).toBe("Moat")
			expect(MapGeometry.zoneAt(100, 0)).toBe("GreenWheat")
			expect(MapGeometry.zoneAt(1500, 0)).toBe("GoldenCorn")
			expect(MapGeometry.zoneAt(2500, 0)).toBe("DiamondWheat")
			expect(MapGeometry.zoneAt(2900, 0)).toBe("Core")
		end)
		it("rend la tige plus étroite que la barre", function()
			expect(MapGeometry.zoneAt(100, 300)).toBe(nil)
			expect(MapGeometry.zoneAt(-50, 300)).toBe("Plaza")
		end)
		it("fait un champ assez long pour qu'on n'en voie pas le bout", function()
			expect(STEM.maxX - STEM.minX >= 3000).toBe(true)
		end)
		it("renvoie nil hors de la carte", function()
			expect(MapGeometry.zoneAt(-200, 0)).toBe(nil)
			expect(MapGeometry.zoneAt(STEM.maxX, 0)).toBe(nil)
		end)
	end)

	describe("baseCenters", function()
		local bases = MapGeometry.baseCenters()

		it("aligne 8 bases sur la barre du T (CDC §3)", function()
			expect(#bases).toBe(8)
			for _, base in bases do
				expect(MapGeometry.zoneAt(base.x, base.z)).toBe("Plaza")
			end
		end)
		it("garde chaque base entière sur la barre", function()
			for _, base in bases do
				expect(base.x - HALF_BASE >= PLAZA.minX and base.x + HALF_BASE <= PLAZA.maxX).toBe(true)
				expect(math.abs(base.z) + HALF_BASE <= PLAZA.halfWidth).toBe(true)
			end
		end)
		it("ne les fait pas se chevaucher", function()
			expect(MapConfig.BASE_PITCH > MapConfig.BASE_SIZE).toBe(true)
		end)
	end)

	describe("isInsideBase", function()
		local base = MapGeometry.baseCenters()[1]
		it("accepte le centre de la base", function()
			expect(MapGeometry.isInsideBase(base, base.x, base.z)).toBe(true)
		end)
		it("refuse un point hors de l'emprise", function()
			expect(MapGeometry.isInsideBase(base, base.x, base.z + MapConfig.BASE_SIZE)).toBe(false)
			expect(MapGeometry.isInsideBase(base, 100, 0)).toBe(false)
		end)
	end)

	describe("bridges", function()
		local bridges = MapGeometry.bridges()

		it("pose 4 ponts (CDC §3)", function()
			expect(#bridges).toBe(4)
		end)
		it("franchit le fossé en recouvrant les deux rives", function()
			for _, bridge in bridges do
				expect(bridge.x - bridge.length / 2 < MOAT.minX).toBe(true)
				expect(bridge.x + bridge.length / 2 > MOAT.maxX).toBe(true)
			end
		end)
		it("arrive sur le champ, pas à côté", function()
			for _, bridge in bridges do
				expect(MapGeometry.zoneAt(MOAT.maxX + 1, bridge.z)).toBe("GreenWheat")
			end
		end)
		it("reste étroit", function()
			for _, bridge in bridges do
				expect(bridge.width < HALF_BASE).toBe(true)
			end
		end)
	end)

	describe("isUnderBridge", function()
		it("détecte un point sur le tablier", function()
			local bridge = MapGeometry.bridges()[1]
			expect(MapGeometry.isUnderBridge(bridge.x, bridge.z, 0)).toBe(true)
		end)
		it("ignore le milieu du champ", function()
			expect(MapGeometry.isUnderBridge(400, 0, 0)).toBe(false)
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
				covered += math.round(run.sizeZ / MapConfig.CELL_SIZE)
			end
			local expected = 0
			local lattice = MapConfig.MAP_LATTICE
			for i = 1, lattice.cols do
				for j = 1, lattice.rows do
					local zone = MapGeometry.zoneAt(MapGeometry.cellCenter(lattice, i, j))
					if zone and not MapConfig.VOID_ZONES[zone] then
						expected += 1
					end
				end
			end
			expect(covered).toBe(expected)
		end)
		it("garde chaque brique dans une seule zone", function()
			for _, run in runs do
				local half = run.sizeZ / 2 - MapConfig.CELL_SIZE / 2
				expect(MapGeometry.zoneAt(run.x, run.z - half)).toBe(run.zone)
				expect(MapGeometry.zoneAt(run.x, run.z + half)).toBe(run.zone)
			end
		end)
	end)
end)
