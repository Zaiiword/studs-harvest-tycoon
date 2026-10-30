--!strict
-- Sac à dos / remorque (CDC §4) : compte les blés coupés et leur valeur brute en $ (décision A5).
-- Une capacité infinie (Remorque Infinie, décision A16) n'est jamais « PLEINE ».
local FieldConfig = require("../config/FieldConfig")

export type Bag = {
	count: number,
	value: number,
	capacity: number,
}

local Bag = {}

local MAX_STEP = math.round(1 / FieldConfig.BAG_FILL_STEP)

function Bag.new(capacity: number): Bag
	assert(capacity > 0, "capacity doit être > 0")
	return { count = 0, value = 0, capacity = capacity }
end

function Bag.isFull(bag: Bag): boolean
	return bag.count >= bag.capacity
end

-- Ajoute un blé. Renvoie false (sans rien modifier) si le sac est déjà plein.
function Bag.add(bag: Bag, value: number): boolean
	if Bag.isFull(bag) then
		return false
	end
	bag.count += 1
	bag.value += value
	return true
end

function Bag.fillRatio(bag: Bag): number
	if bag.capacity == math.huge then
		return 0
	end
	return math.min(1, bag.count / bag.capacity)
end

-- Palier visuel de remplissage, de 0 à 10 (CDC §4 : « paliers de 10 % »).
function Bag.fillStep(bag: Bag): number
	return math.clamp(math.floor(Bag.fillRatio(bag) * MAX_STEP + 1e-9), 0, MAX_STEP)
end

-- Vide le sac (déchargement au silo) et renvoie ce qu'il contenait.
function Bag.empty(bag: Bag): (number, number)
	local count, value = bag.count, bag.value
	bag.count, bag.value = 0, 0
	return count, value
end

-- Retire au plus `maxValue` $ du sac (silo presque plein) : on retire la même proportion de blés.
-- Renvoie ce qui a été retiré.
function Bag.withdraw(bag: Bag, maxValue: number): (number, number)
	if bag.value <= maxValue then
		return Bag.empty(bag)
	end
	if maxValue <= 0 or bag.value <= 0 then
		return 0, 0
	end
	local count = math.floor(bag.count * maxValue / bag.value)
	bag.count -= count
	bag.value -= maxValue
	return count, maxValue
end

-- Changement de palier : le contenu est conservé, même s'il dépasse la nouvelle capacité.
function Bag.setCapacity(bag: Bag, capacity: number)
	assert(capacity > 0, "capacity doit être > 0")
	bag.capacity = capacity
end

return Bag
