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
	-- Bandeau des événements sous la trésorerie (météo, boss, multiplicateur) — CDC §6.
	EVENT_BANNER = {
		WIDTH = 520,
		HEIGHT = 30,
		TOP = 84,
		SPACING = 6,
		BOSS_BAR_COLOR = { 128, 230, 255 },
		WEATHER_COLOR = { 245, 205, 48 },
		BOOST_COLOR = { 75, 151, 75 },
	},
	-- Barre d'objets de sabotage à droite de l'écran ; touches 1 à 4.
	ITEM_BAR = {
		BUTTON_SIZE = 64,
		BUY_HEIGHT = 22,
		PADDING = 8,
		RIGHT_MARGIN = 12,
		COLOR = { 27, 42, 53 },
		BUY_COLOR = { 98, 37, 209 },
		TOAST_SECONDS = 2.5,
		KEYS = { "One", "Two", "Three", "Four" } :: { string },
	},
	-- Menu des Pets (CDC §7.2) : bouton 🐾 en bas à gauche.
	PET_MENU = {
		WIDTH = 620,
		HEIGHT = 420,
		ROW_HEIGHT = 40,
		NAME_WIDTH = 330,
		BUTTON_WIDTH = 120,
		TOGGLE_SIZE = 64,
		TOGGLE_MARGIN = 16,
		BUTTON_COLOR = { 98, 37, 209 },
		ROW_COLOR = { 27, 42, 53 },
	},
	-- Éclosion : l'œuf tremble, puis le Pet est révélé.
	HATCH = {
		EGG_SIZE = 160,
		REVEAL_WIDTH = 640,
		REVEAL_HEIGHT = 60,
		SHAKE_SECONDS = 1.2,
		SHAKE_DEGREES = 18,
		REVEAL_SECONDS = 3,
	},
	-- Menu de rétention 🎁 (CDC §7.4) : cadeaux de temps de jeu, quêtes du jour, Roue de la Fortune.
	RETENTION_MENU = {
		WIDTH = 640,
		HEIGHT = 440,
		ROW_HEIGHT = 36,
		GIFT_SIZE = 96,
		WHEEL_SIZE = 220,
		SPIN_SECONDS = 4,
		SPIN_TURNS = 5,
		READY_COLOR = { 75, 151, 75 },
		LOCKED_COLOR = { 99, 95, 98 },
	},
	-- Game feel (CDC §2) : textes flottants, tremblement de caméra, rebond des boutons.
	JUICE = {
		FLOAT_POOL = 24,
		FLOAT_RISE = 4,
		FLOAT_SECONDS = 0.8,
		SHAKE_PER_CUT = 0.08, -- « trauma » ajouté par coupe, pondéré par la taille de l'outil
		SHAKE_ON_EJECT = 0.9,
		SHAKE_DECAY = 2.5, -- par seconde
		SHAKE_MAX_ANGLE = 0.03, -- radians
		BIGGEST_HITBOX = 38, -- hitbox du Tier 7 : tremblement maximal par coupe
		BOUNCE_SCALE = 0.88,
		BOUNCE_SECONDS = 0.25,
		TOAST_SECONDS = 2.5,
		CRITICAL_COLOR = { 255, 176, 0 },
		RAINBOW_COLOR = { 255, 89, 89 },
	},
	-- Boutique Robux et offres contextuelles (CDC §9, §10).
	SHOP = {
		WIDTH = 600,
		HEIGHT = 440,
		ROW_HEIGHT = 64,
		BUTTON_WIDTH = 120,
		ROW_COLOR = { 27, 42, 53 },
		DETAIL_COLOR = { 200, 200, 200 },
		BUY_COLOR = { 0, 162, 255 },
		REVENGE_COLOR = { 196, 40, 28 },
	},
	-- Panneau de test (Studio uniquement).
	DEV_PANEL = {
		BUTTON_WIDTH = 96,
		BUTTON_HEIGHT = 32,
		PADDING = 6,
		LEFT_MARGIN = 12,
		COLOR = { 98, 37, 209 },
	},
})
