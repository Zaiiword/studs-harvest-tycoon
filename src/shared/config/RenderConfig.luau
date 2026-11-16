--!strict
-- Rendu « Classic Studs » (CDC §2) : éclairage ensoleillé et texture Lego.
local Freeze = require("../util/Freeze")

return Freeze.deep({
	LIGHTING = {
		BRIGHTNESS = 3, -- CDC §2
		COLOR_SHIFT_TOP = { 255, 214, 120 }, -- « ColorShift_Top doré »
		CLOCK_TIME = 15.2, -- soleil d'après-midi (A69) : ombres plus longues, relief plus lisible
		GEOGRAPHIC_LATITUDE = 32,
		OUTDOOR_AMBIENT = { 128, 138, 162 }, -- ombres légèrement bleutées : le soleil doré ressort
		AMBIENT = { 60, 60, 70 },
		SHADOW_SOFTNESS = 0.25,
		ENVIRONMENT_DIFFUSE = 0.6,
		ENVIRONMENT_SPECULAR = 0.5,
	},
	-- Brume légère : le bout du champ se perd à l'horizon et masque l'apparition des chunks (A32).
	ATMOSPHERE = {
		DENSITY = 0.32,
		HAZE = 1.5,
		COLOR = { 199, 220, 240 },
		DECAY = { 255, 226, 190 }, -- horizon doré du côté du soleil (A69)
		GLARE = 0.25,
	},
	SKY = { SUN_SIZE = 14, MOON_SIZE = 9, STARS = 3000 },
	-- Nom du MaterialVariant appliqué à toutes les briques du monde. Il n'est créé que si une texture est
	-- fournie dans AssetIds ; sinon les surfaces Studs/Inlet natives de Roblox assurent le rendu (décision A25).
	STUDS_MATERIAL_VARIANT = "LegoStuds",
	STUDS_TEXTURE_SIZE = 2, -- 1 tenon = 1 stud × 1 stud
})
