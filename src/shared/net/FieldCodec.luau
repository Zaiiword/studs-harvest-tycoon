--!strict
-- Encodage binaire des événements du champ (CDC §4 « signal compressé », §11 batching, docs/CLEAN_CODE.md §9).
-- Un lot d'événements tient en 4 octets par événement ; l'état initial en 1 octet par cellule.
local MapConfig = require("../config/MapConfig")

export type FieldEvent = {
	kind: number,
	index: number,
	data: number, -- coupe : n° de base du récolteur (0 = aucun) ; repousse : rareté
}

local FieldCodec = {}

FieldCodec.EVENT_CUT = 0
FieldCodec.EVENT_REGROW = 1

local EVENT_BYTES = 4
local CELL_COUNT = MapConfig.FIELD_LATTICE.cols * MapConfig.FIELD_LATTICE.rows -- ≤ 65 535 (index en u16)
local NOT_GROWN = 0

local function isValidIndex(index: number): boolean
	return index >= 1 and index <= CELL_COUNT
end

function FieldCodec.encodeEvents(events: { FieldEvent }): buffer
	local out = buffer.create(#events * EVENT_BYTES)
	for k, event in events do
		local offset = (k - 1) * EVENT_BYTES
		buffer.writeu8(out, offset, event.kind)
		buffer.writeu16(out, offset + 1, event.index)
		buffer.writeu8(out, offset + 3, event.data)
	end
	return out
end

-- Les événements mal formés (type ou index hors bornes) sont ignorés plutôt que de faire planter le client.
function FieldCodec.decodeEvents(input: buffer): { FieldEvent }
	local events: { FieldEvent } = {}
	local count = buffer.len(input) // EVENT_BYTES
	for k = 0, count - 1 do
		local offset = k * EVENT_BYTES
		local kind = buffer.readu8(input, offset)
		local index = buffer.readu16(input, offset + 1)
		if (kind == FieldCodec.EVENT_CUT or kind == FieldCodec.EVENT_REGROW) and isValidIndex(index) then
			table.insert(events, { kind = kind, index = index, data = buffer.readu8(input, offset + 3) })
		end
	end
	return events
end

-- 1 octet par cellule : 0 = pas de brin debout, sinon rareté + 1.
function FieldCodec.encodeSnapshot(grown: { [number]: number }): buffer
	local out = buffer.create(CELL_COUNT)
	for index, rarity in grown do
		if isValidIndex(index) then
			buffer.writeu8(out, index - 1, rarity + 1)
		end
	end
	return out
end

function FieldCodec.decodeSnapshot(input: buffer): { [number]: number }
	local grown: { [number]: number } = {}
	for index = 1, math.min(CELL_COUNT, buffer.len(input)) do
		local byte = buffer.readu8(input, index - 1)
		if byte ~= NOT_GROWN then
			grown[index] = byte - 1
		end
	end
	return grown
end

return FieldCodec
