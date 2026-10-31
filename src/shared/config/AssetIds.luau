--!strict
-- Identifiants d'assets Roblox (textures, sons). Les sons pointent par défaut vers des fichiers intégrés au
-- client Roblox (rbxasset://sounds/…) ; à remplacer par des sons du Creator Store pour un rendu final
-- (docs/ANALYSE_CDC.md §6). Chaque fonctionnalité se dégrade proprement si l'ID est vide.
local Freeze = require("../util/Freeze")

return Freeze.deep({
	STUDS_COLOR_MAP = "", -- rbxassetid://... texture à tenons (CDC §2)
	STUDS_NORMAL_MAP = "",
	HARVEST_POP_SOUND = "rbxasset://sounds/electronicpingshort.wav", -- « Pop » de brique (CDC §2)
	UI_CLICK_SOUND = "rbxasset://sounds/button.wav", -- clic des boutons « Studs Pop » (CDC §10)
	EJECT_SOUND = "rbxasset://sounds/swoosh.wav", -- éjection (CDC §5)
	REWARD_SOUND = "rbxasset://sounds/electronicpingshort.wav", -- récompense reçue (CDC §7.4)
})
