--!strict
-- Matrice logique du champ (CDC §4) : état, PV et rareté de chaque brin, sans aucune API Roblox.
-- Table plate indexée (i - 1) × rows + j sur MapConfig.FIELD_LATTICE (docs/CLEAN_CODE.md §9). Le serveur fait autorité ;
-- le client en garde un miroir (setGrown / setCut) pour sa prédiction et le placement des visuels.
local FieldConfig = require("../config/FieldConfig")
local MapConfig = require("../config/MapConfig")
local MapGeometry = require("./MapGeometry")
local Rarity = require("./Rarity")

export type Cell = {
	index: number,
	x: number,
	z: number,
	zone: string,
	isGrown: boolean,
	hp: number,
	rarity: number,
}

export type CutResult = {
	index: number,
	zone: string,
	rarity: number,
	value: number,
}

-- Boîte de coupe placée devant l'outil : `size` studs de long et de large, orientée selon (dirX, dirZ).
export type Hitbox = {
	x: number,
	z: number,
	dirX: number,
	dirZ: number,
	size: number,
}

type RegrowEntry = { index: number, at: number }

local FieldGrid = {}
FieldGrid.__index = FieldGrid

type GridData = {
	_cells: { [number]: Cell },
	_activeIndices: { number },
	_regrowQueue: { RegrowEntry },
	_queueHead: number,
	_rng: Rarity.Rng,
}
export type FieldGrid = typeof(setmetatable({} :: GridData, FieldGrid))

local LATTICE = MapConfig.FIELD_LATTICE
local CELL_SIZE = MapConfig.CELL_SIZE
-- Une cellule est touchée si son carré (et pas seulement son centre) recoupe la boîte (décision A24).
local HITBOX_MARGIN = CELL_SIZE / 2
local QUEUE_COMPACT_THRESHOLD = 512

FieldGrid.CELL_COUNT = LATTICE.cols * LATTICE.rows

function FieldGrid.indexOf(i: number, j: number): number
	return (i - 1) * LATTICE.rows + j
end

local function freshHp(zone: string, rarity: number): number
	return FieldConfig.WHEAT_ZONES[zone].hp * Rarity.byId(rarity).hpMultiplier
end

local function newCell(i: number, j: number, rng: Rarity.Rng): Cell?
	local x, z = MapGeometry.cellCenter(LATTICE, i, j)
	local zone = MapGeometry.zoneAt(x, z)
	if not zone or not FieldConfig.WHEAT_ZONES[zone] or MapGeometry.isUnderBridge(x, z, HITBOX_MARGIN) then
		return nil
	end
	local rarity = Rarity.roll(rng)
	local index = FieldGrid.indexOf(i, j)
	return { index = index, x = x, z = z, zone = zone, isGrown = true, hp = freshHp(zone, rarity), rarity = rarity }
end

function FieldGrid.new(rng: Rarity.Rng): FieldGrid
	local self = setmetatable(
		{
			_cells = {},
			_activeIndices = {},
			_regrowQueue = {},
			_queueHead = 1,
			_rng = rng,
		} :: GridData,
		FieldGrid
	)
	for i = 1, LATTICE.cols do
		for j = 1, LATTICE.rows do
			local cell = newCell(i, j, rng)
			if cell then
				self._cells[cell.index] = cell
				table.insert(self._activeIndices, cell.index)
			end
		end
	end
	return self
end

function FieldGrid.cell(self: FieldGrid, index: number): Cell?
	return self._cells[index]
end

function FieldGrid.activeIndices(self: FieldGrid): { number }
	return table.clone(self._activeIndices)
end

-- Plage d'indices (1-based) des cellules dont le centre peut se trouver dans [center - reach, center + reach].
local function candidateRange(center: number, reach: number, min: number, count: number): (number, number)
	local low = math.max(1, math.floor((center - reach - min) / CELL_SIZE + 0.5))
	local high = math.min(count, math.ceil((center + reach - min) / CELL_SIZE + 0.5))
	return low, high
end

-- Brins debout dans la boîte de coupe, du plus proche au plus éloigné de l'outil.
function FieldGrid.queryHitbox(self: FieldGrid, hitbox: Hitbox): { number }
	local length = math.sqrt(hitbox.dirX * hitbox.dirX + hitbox.dirZ * hitbox.dirZ)
	if length < 1e-6 or hitbox.size <= 0 then
		return {}
	end
	local fx, fz = hitbox.dirX / length, hitbox.dirZ / length
	local reach = hitbox.size + HITBOX_MARGIN
	local halfWidth = hitbox.size / 2 + HITBOX_MARGIN
	local iLow, iHigh = candidateRange(hitbox.x, reach, LATTICE.minX, LATTICE.cols)
	local jLow, jHigh = candidateRange(hitbox.z, reach, LATTICE.minZ, LATTICE.rows)

	local hits: { { index: number, along: number } } = {}
	for i = iLow, iHigh do
		for j = jLow, jHigh do
			local cell = self._cells[FieldGrid.indexOf(i, j)]
			if cell and cell.isGrown then
				local dx, dz = cell.x - hitbox.x, cell.z - hitbox.z
				local along = dx * fx + dz * fz
				local lateral = -dx * fz + dz * fx
				if along >= -HITBOX_MARGIN and along <= reach and math.abs(lateral) <= halfWidth then
					table.insert(hits, { index = cell.index, along = along })
				end
			end
		end
	end
	table.sort(hits, function(a, b)
		return a.along < b.along
	end)
	local indices = table.create(#hits)
	for k, hit in hits do
		indices[k] = hit.index
	end
	return indices
end

-- Inflige `power` dégâts au brin. Renvoie le résultat de la coupe si le brin tombe, nil sinon.
function FieldGrid.damage(self: FieldGrid, index: number, power: number, now: number): CutResult?
	assert(power > 0, "power doit être > 0")
	local cell = self._cells[index]
	if not cell or not cell.isGrown then
		return nil
	end
	cell.hp -= power
	if cell.hp > 0 then
		return nil
	end
	cell.isGrown = false
	table.insert(self._regrowQueue, { index = index, at = now + FieldConfig.REGROW_SECONDS })
	local value = FieldConfig.WHEAT_ZONES[cell.zone].value * Rarity.byId(cell.rarity).valueMultiplier
	return { index = index, zone = cell.zone, rarity = cell.rarity, value = value }
end

local function compactQueue(self: FieldGrid)
	if self._queueHead < QUEUE_COMPACT_THRESHOLD then
		return
	end
	local remaining = #self._regrowQueue - self._queueHead + 1
	table.move(self._regrowQueue, self._queueHead, #self._regrowQueue, 1)
	for k = #self._regrowQueue, remaining + 1, -1 do
		self._regrowQueue[k] = nil
	end
	self._queueHead = 1
end

-- Fait repousser les brins dont le délai est écoulé ; chacun refait un tirage de rareté (CDC §4).
-- La file reste triée car le délai de repousse est constant.
function FieldGrid.regrowDue(self: FieldGrid, now: number, rainbowBoost: number?): { Cell }
	local regrown: { Cell } = {}
	local queue = self._regrowQueue
	while queue[self._queueHead] and queue[self._queueHead].at <= now do
		local cell = self._cells[queue[self._queueHead].index]
		self._queueHead += 1
		cell.rarity = Rarity.roll(self._rng, rainbowBoost)
		cell.hp = freshHp(cell.zone, cell.rarity)
		cell.isGrown = true
		table.insert(regrown, cell)
	end
	compactQueue(self)
	return regrown
end

-- Miroir client : applique l'état reçu du serveur sans toucher à la file de repousse.
function FieldGrid.setGrown(self: FieldGrid, index: number, rarity: number)
	local cell = self._cells[index]
	if cell then
		cell.isGrown, cell.rarity, cell.hp = true, rarity, freshHp(cell.zone, rarity)
	end
end

function FieldGrid.setCut(self: FieldGrid, index: number)
	local cell = self._cells[index]
	if cell then
		cell.isGrown = false
	end
end

-- Rareté de chaque brin debout, pour l'état initial envoyé à un client qui arrive.
function FieldGrid.grownRarities(self: FieldGrid): { [number]: number }
	local grown: { [number]: number } = {}
	for _, index in self._activeIndices do
		local cell = self._cells[index]
		if cell.isGrown then
			grown[index] = cell.rarity
		end
	end
	return grown
end

return FieldGrid
