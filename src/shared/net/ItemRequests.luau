--!strict
-- Validation des requêtes d'objets envoyées par le client (docs/CLEAN_CODE.md §4) : le serveur n'accepte
-- qu'un identifiant d'objet connu, de type chaîne. Rien d'autre ne transite (ni cible, ni position).
local SabotageConfig = require("../config/SabotageConfig")

local ItemRequests = {}

local items: { [string]: SabotageConfig.ItemDef } = {}
for _, item in SabotageConfig.ITEMS do
	items[item.id] = item
end

function ItemRequests.parse(value: any): SabotageConfig.ItemDef?
	if typeof(value) ~= "string" or #value > 32 then
		return nil
	end
	return items[value]
end

return ItemRequests
