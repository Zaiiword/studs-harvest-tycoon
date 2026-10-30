--!strict
-- Rendu « Classic Studs » (CDC §2) : éclairage ensoleillé et texture Lego.
local Freeze = require("../util/Freeze")

return Freeze.deep({
	LIGHTING = {
		BRIGHTNESS = 3, -- CDC §2
		COLOR_SHIFT_TOP = { 255, 214, 120 }, -- « ColorShift_Top doré »
		CLOCK_TIME = 14,
		OUTDOOR_AMBIENT = { 150, 150, 150 },
	},
	-- Brume légère : le bout du champ se perd à l'horizon et masque l'apparition des chunks (A32).
	ATMOSPHERE = {
		DENSITY = 0.32,
		HAZE = 1.5,
		COLOR = { 199, 220, 240 },
	},
	-- Nom du MaterialVariant appliqué à toutes les briques du monde. Il n'est créé que si une texture est
	-- fournie dans AssetIds ; sinon les surfaces Studs/Inlet natives de Roblox assurent le rendu (décision A25).
	STUDS_MATERIAL_VARIANT = "LegoStuds",
	STUDS_TEXTURE_SIZE = 2, -- 1 tenon = 1 stud × 1 stud
})
