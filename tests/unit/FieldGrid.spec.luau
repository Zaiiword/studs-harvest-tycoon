--!strict
local TestKit = require("../TestKit")
local FakeRng = require("../helpers/FakeRng")
local FieldConfig = require("../../src/shared/config/FieldConfig")
local MapGeometry = require("../../src/shared/domain/MapGeometry")
local FieldGrid = require("../../src/shared/domain/FieldGrid")
local Rarity = require("../../src/shared/domain/Rarity")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local ALWAYS_NORMAL = FakeRng.constant(0.5)

local function firstCellOf(grid: FieldGrid.FieldGrid, zone: string): FieldGrid.Cell
	for _, index in grid:activeIndices() do
		local cell = grid:cell(index) :: FieldGrid.Cell
		if cell.zone == zone then
			return cell
		end
	end
	error(`aucune cellule {zone}`)
end

describe("FieldGrid", function()
	describe("new", function()
		local grid = FieldGrid.new(ALWAYS_NORMAL)

		it("ne dépasse pas 2 500 brins (CDC §4)", function()
			expect(#grid:activeIndices() <= FieldConfig.GRID_SIZE ^ 2).toBe(true)
		end)
		it("ne fait pousser du blé que dans les anneaux", function()
			for _, index in grid:activeIndices() do
				local cell = grid:cell(index) :: FieldGrid.Cell
				expect(FieldConfig.WHEAT_ZONES[MapGeometry.zoneAt(cell.x, cell.z) :: string] ~= nil).toBe(true)
			end
		end)
		it("laisse le dessous des ponts dégagé", function()
			for _, index in grid:activeIndices() do
				local cell = grid:cell(index) :: FieldGrid.Cell
				expect(MapGeometry.isUnderBridge(cell.x, cell.z, 0)).toBe(false)
			end
		end)
		it("donne à chaque brin les PV de son anneau (CDC §3)", function()
			expect(firstCellOf(grid, "GreenWheat").hp).toBe(1)
			expect(firstCellOf(grid, "GoldenCorn").hp).toBe(15)
			expect(firstCellOf(grid, "DiamondWheat").hp).toBe(100)
		end)
	end)

	describe("damage", function()
		it("coupe un Blé Vert en un coup et renvoie sa valeur", function()
			local grid = FieldGrid.new(ALWAYS_NORMAL)
			local cell = firstCellOf(grid, "GreenWheat")
			local result = grid:damage(cell.index, 1, 0) :: FieldGrid.CutResult
			expect(result.value).toBe(1)
			expect(cell.isGrown).toBe(false)
		end)
		it("cumule les dégâts sur un Maïs Doré (15 PV)", function()
			local grid = FieldGrid.new(ALWAYS_NORMAL)
			local cell = firstCellOf(grid, "GoldenCorn")
			expect(grid:damage(cell.index, 5, 0)).toBe(nil)
			expect(grid:damage(cell.index, 5, 0)).toBe(nil)
			expect((grid:damage(cell.index, 5, 0) :: FieldGrid.CutResult).value).toBe(25)
		end)
		it("ignore un brin déjà coupé", function()
			local grid = FieldGrid.new(ALWAYS_NORMAL)
			local cell = firstCellOf(grid, "GreenWheat")
			grid:damage(cell.index, 1, 0)
			expect(grid:damage(cell.index, 1, 0)).toBe(nil)
		end)
		it("multiplie la valeur d'un Blé Géant par 10 et ses PV par 3 (A4)", function()
			local grid = FieldGrid.new(FakeRng.constant(0.005))
			local cell = firstCellOf(grid, "GoldenCorn")
			expect(cell.rarity).toBe(Rarity.GIANT)
			expect(cell.hp).toBe(45)
			expect((grid:damage(cell.index, 45, 0) :: FieldGrid.CutResult).value).toBe(250)
		end)
		it("refuse une puissance nulle", function()
			local grid = FieldGrid.new(ALWAYS_NORMAL)
			expect(function()
				grid:damage(firstCellOf(grid, "GreenWheat").index, 0, 0)
			end).toThrow()
		end)
	end)

	describe("regrowDue", function()
		it("fait repousser un brin après 8 secondes, pas avant (CDC §4)", function()
			local grid = FieldGrid.new(ALWAYS_NORMAL)
			local cell = firstCellOf(grid, "GreenWheat")
			grid:damage(cell.index, 1, 100)
			expect(#grid:regrowDue(107.9)).toBe(0)
			local regrown = grid:regrowDue(108)
			expect(#regrown).toBe(1)
			expect(cell.isGrown).toBe(true)
		end)
		it("refait un tirage de rareté à la repousse", function()
			local nextRoll = 0.5
			local grid = FieldGrid.new(function()
				return nextRoll
			end)
			local cell = firstCellOf(grid, "GreenWheat")
			grid:damage(cell.index, 1, 0)
			nextRoll = 0.0001
			grid:regrowDue(FieldConfig.REGROW_SECONDS)
			expect(cell.rarity).toBe(Rarity.RAINBOW)
		end)
		it("reste correcte après compaction de la file", function()
			local grid = FieldGrid.new(ALWAYS_NORMAL)
			local cell = firstCellOf(grid, "GreenWheat")
			for round = 0, 600 do
				local now = round * FieldConfig.REGROW_SECONDS
				grid:regrowDue(now)
				expect(grid:damage(cell.index, 1, now) ~= nil).toBe(true)
			end
		end)
	end)

	describe("queryHitbox", function()
		local grid = FieldGrid.new(ALWAYS_NORMAL)
		local cell = firstCellOf(grid, "GreenWheat")

		it("trouve un brin juste devant les Mains Nues (4 studs)", function()
			local hits = grid:queryHitbox({ x = cell.x - 2, z = cell.z, dirX = 1, dirZ = 0, size = 4 })
			expect(table.find(hits, cell.index) ~= nil).toBe(true)
		end)
		it("ignore un brin situé derrière le joueur", function()
			local hits = grid:queryHitbox({ x = cell.x + 10, z = cell.z, dirX = 1, dirZ = 0, size = 4 })
			expect(table.find(hits, cell.index)).toBe(nil)
		end)
		it("touche plus de brins avec une plus grande hitbox", function()
			local small = grid:queryHitbox({ x = 0, z = -120, dirX = 1, dirZ = 0, size = 4 })
			local large = grid:queryHitbox({ x = 0, z = -120, dirX = 1, dirZ = 0, size = 38 })
			expect(#large > #small).toBe(true)
		end)
		it("trie les brins du plus proche au plus éloigné", function()
			local hits = grid:queryHitbox({ x = -20, z = -120, dirX = 1, dirZ = 0, size = 38 })
			local first = grid:cell(hits[1]) :: FieldGrid.Cell
			local last = grid:cell(hits[#hits]) :: FieldGrid.Cell
			expect(first.x <= last.x).toBe(true)
		end)
		it("renvoie une liste vide sans direction", function()
			expect(#grid:queryHitbox({ x = 0, z = -120, dirX = 0, dirZ = 0, size = 4 })).toBe(0)
		end)
	end)

	describe("miroir client", function()
		it("applique l'état reçu du serveur", function()
			local grid = FieldGrid.new(ALWAYS_NORMAL)
			local cell = firstCellOf(grid, "GoldenCorn")
			grid:setCut(cell.index)
			expect(grid:grownRarities()[cell.index]).toBe(nil)
			grid:setGrown(cell.index, Rarity.GIANT)
			expect(grid:grownRarities()[cell.index]).toBe(Rarity.GIANT)
			expect(cell.hp).toBe(45)
		end)
	end)
end)
