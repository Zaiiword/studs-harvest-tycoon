--!strict
-- Inventaire d'objets de chaque joueur (sabotage, récompenses du boss), sauvegardé par DataService.
-- Les quantités sont publiées en attributs « Item_<id> » pour la barre d'objets du client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Inventory = require(ReplicatedStorage.Shared.domain.Inventory)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)

local InventoryService = {}

local inventories: { [Player]: Inventory.Inventory } = {}

local function inventoryOf(player: Player): Inventory.Inventory
	local inventory = inventories[player]
	if not inventory then
		inventory = {}
		inventories[player] = inventory
	end
	return inventory
end

local function publish(player: Player, id: string)
	player:SetAttribute(PlayerAttributes.ITEM_PREFIX .. id, Inventory.count(inventoryOf(player), id))
end

function InventoryService.count(player: Player, id: string): number
	return Inventory.count(inventoryOf(player), id)
end

function InventoryService.add(player: Player, id: string, amount: number): number
	local added = Inventory.add(inventoryOf(player), id, amount)
	publish(player, id)
	return added
end

function InventoryService.take(player: Player, id: string): boolean
	local isTaken = Inventory.take(inventoryOf(player), id)
	publish(player, id)
	return isTaken
end

function InventoryService.snapshot(player: Player): Inventory.Inventory
	return table.clone(inventoryOf(player))
end

function InventoryService.restore(player: Player, items: Inventory.Inventory)
	inventories[player] = Inventory.sanitize(items)
	for id in inventories[player] do
		publish(player, id)
	end
end

-- Oublie l'inventaire d'un joueur qui part. Appelé par DataService après la capture du profil
-- (l'ordre des gestionnaires de PlayerRemoving n'est pas garanti).
function InventoryService.release(player: Player)
	inventories[player] = nil
end

return InventoryService
