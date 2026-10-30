--!strict
-- Inventaire d'objets (sabotage, récompenses), sans API Roblox. Sauvegardé dans le profil (Profile v2).
local SabotageConfig = require("../config/SabotageConfig")

export type Inventory = { [string]: number }

local Inventory = {}

local known: { [string]: boolean } = table.clone(SabotageConfig.TROPHIES) :: any
for _, item in SabotageConfig.ITEMS do
	known[item.id] = true
end

function Inventory.isKnown(id: string): boolean
	return known[id] == true
end

function Inventory.count(inventory: Inventory, id: string): number
	return inventory[id] or 0
end

-- Ajoute `amount` exemplaires, sans dépasser MAX_STACK. Renvoie le nombre réellement ajouté.
function Inventory.add(inventory: Inventory, id: string, amount: number): number
	assert(known[id], `objet inconnu : {id}`)
	local current = Inventory.count(inventory, id)
	local added = math.clamp(math.floor(amount), 0, SabotageConfig.MAX_STACK - current)
	inventory[id] = current + added
	return added
end

-- Consomme un exemplaire. Renvoie false s'il n'y en a plus.
function Inventory.take(inventory: Inventory, id: string): boolean
	local current = Inventory.count(inventory, id)
	if current <= 0 then
		return false
	end
	inventory[id] = current - 1
	return true
end

-- Nettoie un inventaire lu depuis le DataStore : objets connus, quantités entières dans [0, MAX_STACK].
function Inventory.sanitize(raw: any): Inventory
	local inventory: Inventory = {}
	if typeof(raw) ~= "table" then
		return inventory
	end
	for id, value in raw do
		if typeof(id) == "string" and known[id] and typeof(value) == "number" and value == value then
			local amount = math.clamp(math.floor(value), 0, SabotageConfig.MAX_STACK)
			if amount > 0 then
				inventory[id] = amount
			end
		end
	end
	return inventory
end

return Inventory
