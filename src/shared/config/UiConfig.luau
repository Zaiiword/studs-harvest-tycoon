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
		NO_BOUNCE_ATTRIBUTE = "NoBounce", -- bouton qui ne rebondit pas (fond cliquable d'une fenêtre)
		CRITICAL_COLOR = { 255, 176, 0 },
		RAINBOW_COLOR = { 255, 89, 89 },
	},
	-- Boutique Robux et offres contextuelles (CDC §9, §10).
	SHOP = {
		ROW_COLOR = { 27, 42, 53 },
		BUY_COLOR = { 0, 162, 255 },
		REVENGE_COLOR = { 196, 40, 28 },
		-- Grille de cartes : autant de colonnes que la largeur le permet, entre MIN et MAX.
		CARD_MIN_WIDTH = 190,
		CARD_HEIGHT = 250,
		MIN_COLUMNS = 2,
		MAX_COLUMNS = 4,
		CARD_PADDING = 12,
		ICON_BOB = { height = 4, speed = 2.5 }, -- l'icône de chaque carte flotte doucement
		BUY_TOP = { 120, 230, 60 }, -- bouton d'achat vert (dégradé)
		BUY_BOTTOM = { 40, 165, 30 },
		BUY_STROKE = { 20, 90, 15 },
		OWNED_TOP = { 160, 160, 170 },
		OWNED_BOTTOM = { 110, 110, 120 },
		BADGE_COLOR = { 255, 60, 90 },
		TAB_ON_TOP = { 255, 225, 80 },
		TAB_ON_BOTTOM = { 255, 160, 20 },
		TAB_OFF_TOP = { 70, 120, 220 },
		TAB_OFF_BOTTOM = { 40, 80, 170 },
		TOGGLE_TOP = { 255, 225, 80 }, -- bouton 🛒 du HUD
		TOGGLE_BOTTOM = { 255, 140, 20 },
		TOGGLE_WIGGLE = { degrees = 8, period = 4 }, -- petit frétillement pour attirer l'œil
		-- Habillage de chaque offre : icône, dégradé de la carte, bandeau facultatif.
		CARDS = {
			InfiniteTrailer = { icon = "🚛", top = { 90, 200, 255 }, bottom = { 30, 110, 220 }, badge = "MEILLEUR" },
			IncomeX2 = { icon = "💰", top = { 255, 220, 70 }, bottom = { 240, 140, 20 }, badge = "POPULAIRE" },
			Titan = { icon = "🛡️", top = { 255, 120, 90 }, bottom = { 200, 40, 50 } },
			Magnet = { icon = "🧲", top = { 200, 120, 255 }, bottom = { 120, 50, 210 } },
			TripleHatch = { icon = "🥚", top = { 120, 235, 160 }, bottom = { 30, 160, 90 } },
			Bazooka = { icon = "💥", top = { 255, 150, 80 }, bottom = { 220, 70, 30 } },
			Meteor = { icon = "☄️", top = { 255, 210, 90 }, bottom = { 190, 110, 20 }, badge = "ÉPIQUE" },
		} :: { [string]: { icon: string, top: { number }, bottom: { number }, badge: string? } },
	},
	-- Fenêtres de menu « premium » (boutique…) : dégradé, gros contour, croix rouge, ouverture qui rebondit.
	WINDOW = {
		SCALE = { 0.9, 0.86 }, -- part de l'écran occupée, bornée par MAX_SIZE
		MAX_SIZE = { 820, 560 },
		HEADER_HEIGHT = 64,
		TAB_HEIGHT = 46,
		CORNER = 20,
		STROKE = 5,
		TOP = { 80, 160, 255 },
		BOTTOM = { 35, 95, 215 },
		STROKE_COLOR = { 15, 35, 90 },
		INNER = { 225, 238, 255 }, -- fond clair de la zone de contenu
		INNER_TRANSPARENCY = 0.15,
		TITLE_TOP = { 255, 245, 140 },
		TITLE_BOTTOM = { 255, 175, 30 },
		CLOSE_SIZE = 54,
		CLOSE_TOP = { 255, 95, 95 },
		CLOSE_BOTTOM = { 205, 25, 35 },
		CLOSE_STROKE = { 100, 0, 10 },
		BACKDROP_TRANSPARENCY = 0.45,
		OPEN_SECONDS = 0.35,
		CLOSE_SECONDS = 0.15,
		OPEN_FROM_SCALE = 0.6,
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
