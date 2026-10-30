--!strict
-- Validation des requêtes Pets du client (docs/CLEAN_CODE.md §4) : action en liste blanche, clé de Pet
-- connue, œuf « gagné » uniquement (les œufs payants s'ouvrent sur les distributeurs de la base).
local PetConfig = require("../config/PetConfig")
local Pets = require("../domain/Pets")

export type Action = "equip" | "unequip" | "fuse"

local PetRequests = {}

local ACTIONS: { [string]: boolean } = { equip = true, unequip = true, fuse = true }

function PetRequests.parseAction(action: any, key: any): (Action?, string?)
	if typeof(action) ~= "string" or not ACTIONS[action] or not Pets.isKnown(key) then
		return nil, nil
	end
	return action :: Action, key :: string
end

function PetRequests.parseItemEgg(eggId: any): PetConfig.EggDef?
	local egg = Pets.egg(eggId)
	return if egg and egg.currency == "item" then egg else nil
end

return PetRequests
