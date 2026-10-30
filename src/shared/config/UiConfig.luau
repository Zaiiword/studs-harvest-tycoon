--!strict
-- Charte graphique « Studs Pop » (CDC §10) et jauge du sac. Le HUD complet arrive au Sprint 7.
local Freeze = require("../util/Freeze")

return Freeze.deep({
	CORNER_RADIUS = 12, -- UICorner = 12 px
	STROKE_THICKNESS = 3, -- UIStroke = 3 px, noir
	STROKE_COLOR = { 0, 0, 0 },
	FONT = "FredokaOne", -- nom d'Enum.Font (la config reste de la donnée pure, testable sous Lune)

	BAG_BAR = {
		WIDTH = 340,
		HEIGHT = 36,
		BOTTOM_MARGIN = 24,
		BACKGROUND = { 40, 40, 40 },
		FILL = { 245, 205, 48 },
		ALERT = { 220, 40, 40 },
		TEXT = { 255, 255, 255 },
		ALERT_RATIO = 0.9, -- CDC §10 : la barre pulse en rouge dès 90 %
		PULSE_SPEED = 6, -- radians par seconde
	},
	-- CDC §10 « Indicateur de revenu passif » : trésorerie, cadence de l'usine et autonomie du silo.
	ECONOMY_PANEL = {
		WIDTH = 600,
		HEIGHT = 40,
		TOP_MARGIN = 12,
		ALERT_HEIGHT = 28,
		ALERT_COLOR = { 220, 40, 40 },
	},
	-- Panneau de test (Studio uniquement).
	DEV_PANEL = {
		BUTTON_WIDTH = 64,
		BUTTON_HEIGHT = 32,
		PADDING = 6,
		LEFT_MARGIN = 12,
		COLOR = { 98, 37, 209 },
	},
})
