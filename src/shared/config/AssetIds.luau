--!strict
-- Identifiants d'assets Roblox (textures, sons). Vides par défaut : à renseigner depuis le Creator Store
-- (docs/ANALYSE_CDC.md §6). Chaque fonctionnalité qui en dépend se dégrade proprement si l'ID est vide.
local Freeze = require("../util/Freeze")

return Freeze.deep({
	STUDS_COLOR_MAP = "", -- rbxassetid://... texture à tenons (CDC §2)
	STUDS_NORMAL_MAP = "",
	HARVEST_POP_SOUND = "", -- son « Pop » de brique plastique (CDC §2)
})
