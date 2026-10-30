--!strict
-- Découpage du champ en chunks pour l'affichage client (décision A32), sans API Roblox.
-- Le client affiche les chunks les plus proches de sa caméra jusqu'à épuiser son budget de brins.
local FieldConfig = require("../config/FieldConfig")
local MapConfig = require("../config/MapConfig")
local FieldGrid = require("./FieldGrid")

export type Chunk = {
	key: number,
	x: number, -- centre monde
	z: number,
	indices: { number }, -- cellules actives (brins) du chunk
}

export type ChunkMap = {
	chunks: { [number]: Chunk },
	ordered: { Chunk },
}

local FieldChunks = {}

local LATTICE = MapConfig.FIELD_LATTICE
local SIZE = FieldConfig.CHUNK_CELLS
local CHUNK_ROWS = math.ceil(LATTICE.rows / SIZE)

local function chunkKey(i: number, j: number): number
	local ci, cj = (i - 1) // SIZE, (j - 1) // SIZE
	return ci * CHUNK_ROWS + cj + 1
end

-- Regroupe les cellules actives d'une grille par chunk. Les chunks sans brin sont omis.
function FieldChunks.build(grid: FieldGrid.FieldGrid): ChunkMap
	local chunks: { [number]: Chunk } = {}
	local ordered: { Chunk } = {}
	local span = SIZE * MapConfig.CELL_SIZE
	for _, index in grid:activeIndices() do
		local i, j = (index - 1) // LATTICE.rows + 1, (index - 1) % LATTICE.rows + 1
		local key = chunkKey(i, j)
		local chunk = chunks[key]
		if not chunk then
			local ci, cj = (i - 1) // SIZE, (j - 1) // SIZE
			chunk = {
				key = key,
				x = LATTICE.minX + (ci + 0.5) * span,
				z = LATTICE.minZ + (cj + 0.5) * span,
				indices = {},
			}
			chunks[key] = chunk
			table.insert(ordered, chunk)
		end
		table.insert(chunk.indices, index)
	end
	return { chunks = chunks, ordered = ordered }
end

export type RenderBudget = {
	detailRadius: number,
	detailBudget: number, -- plantes détaillées au plus
	farRadius: number,
	totalBudget: number, -- plantes affichées au plus (détaillées comprises)
}

export type RenderPlan = { detailed: { Chunk }, simple: { Chunk } }

-- Répartit les chunks proches en deux niveaux de détail (A39) : détaillés tant que le chunk est dans le
-- rayon de détail et que le budget le permet, simples ensuite, jusqu'au budget total (CDC §4).
function FieldChunks.plan(map: ChunkMap, x: number, z: number, budget: RenderBudget): RenderPlan
	local plan: RenderPlan = { detailed = {}, simple = {} }
	local detailedUsed = 0
	for _, chunk in FieldChunks.visible(map, x, z, budget.farRadius, budget.totalBudget) do
		local cost = #chunk.indices
		local distance = math.sqrt((chunk.x - x) ^ 2 + (chunk.z - z) ^ 2)
		if distance <= budget.detailRadius and detailedUsed + cost <= budget.detailBudget then
			detailedUsed += cost
			table.insert(plan.detailed, chunk)
		else
			table.insert(plan.simple, chunk)
		end
	end
	return plan
end

-- Chunks à afficher autour de (x, z), du plus proche au plus lointain, sans dépasser `budget` brins.
function FieldChunks.visible(map: ChunkMap, x: number, z: number, radius: number, budget: number): { Chunk }
	local candidates: { { chunk: Chunk, distance: number } } = {}
	for _, chunk in map.ordered do
		local distance = math.sqrt((chunk.x - x) ^ 2 + (chunk.z - z) ^ 2)
		if distance <= radius then
			table.insert(candidates, { chunk = chunk, distance = distance })
		end
	end
	table.sort(candidates, function(a, b)
		return a.distance < b.distance
	end)
	local visible: { Chunk } = {}
	local used = 0
	for _, candidate in candidates do
		local cost = #candidate.chunk.indices
		if used + cost > budget then
			break
		end
		used += cost
		table.insert(visible, candidate.chunk)
	end
	return visible
end

return FieldChunks
