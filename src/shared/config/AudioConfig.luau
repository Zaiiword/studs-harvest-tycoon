--!strict
-- Musique de fond (A74). Morceaux de la bibliothèque APM sous licence Roblox : utilisables librement dans toute
-- expérience. Deux ambiances : la ferme au calme, et le boss Météorite (plus rythmé) tant qu'il a des PV.
local Freeze = require("../util/Freeze")

return Freeze.deep({
	MUSIC_VOLUME = 0.22, -- assez bas pour laisser passer les sons de récolte
	FADE_SECONDS = 2.5, -- fondu entre deux ambiances
	GAP_SECONDS = 4, -- silence entre deux morceaux de la même ambiance
	TOGGLE_KEY = "M", -- nom d'Enum.KeyCode : couper ou remettre la musique
	TOGGLE_BUTTON = { SIZE = 44, LEFT = 12, TOP = 64 }, -- sous le bouton du menu Roblox

	MUSIC = {
		calm = {
			1836487915, -- Prairie Farm
			130182237855242, -- Pastures Green
			1844758917, -- Banjo And Fiddle
			1840347096, -- Country Friends
			1842289472, -- Fingerpickin'
		},
		boss = {
			1845230050, -- Crazy Banjo
			1842306201, -- Freight Train Trampin'
		},
	},
})
