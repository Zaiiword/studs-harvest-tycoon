--!strict
-- Identifiants d'assets Roblox (textures, sons). A74 : les sons viennent des bibliothèques sous licence Roblox
-- (Pro Sound Effects, APM), libres d'usage dans toute expérience. Chaque fonctionnalité se dégrade proprement si
-- l'ID est vide. La musique est dans AudioConfig.
local Freeze = require("../util/Freeze")

return Freeze.deep({
	STUDS_COLOR_MAP = "", -- rbxassetid://... texture à tenons (CDC §2)
	STUDS_NORMAL_MAP = "",
	-- « Pop » de brique (CDC §2). A70 : un tic doux au lieu du tintement électronique, insupportable en rafale.
	HARVEST_POP_SOUND = "rbxasset://sounds/volume_slider.ogg",
	UI_CLICK_SOUND = "rbxasset://sounds/button.wav", -- clic des boutons « Studs Pop » (CDC §10), court
	ROBUX_ICON = "rbxasset://textures/ui/common/robux.png", -- icône Robux du client (repli sur « R$ » si absente)
	EJECT_SOUND = "rbxassetid://132937320140224", -- « bonk » de dessin animé : éjection (CDC §5)
	REWARD_SOUND = "rbxassetid://2415965014", -- tintement clair : récompense reçue (CDC §7.4)
	UNLOAD_SOUND = "rbxassetid://2415965014", -- sac vidé au silo (A68) : le tintement des récompenses, joué plus grave
})
