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
		PADDING = 10,
		-- Inventaire : grille de cartes avec le Pet en 3D (ViewportFrame) à gauche, fiche détaillée à droite.
		CARD_MIN_WIDTH = 104,
		CARD_HEIGHT = 128,
		MIN_COLUMNS = 3,
		MAX_COLUMNS = 6,
		DETAIL_WIDTH = 0.36, -- part de la largeur occupée par la fiche
		HEADER_HEIGHT = 34, -- bandeau « Équipés 2 / 3 · Bonus ×3,4 »
		SPIN_SPEED = 1.2, -- rad/s : le Pet de la fiche tourne sur lui-même
		CAMERA = { fov = 40, distance = 1.9, height = 0.35, side = 0.55 }, -- cadrage des Pets 3D
		SELECTED_STROKE = { 255, 255, 255 },
		EQUIPPED_COLOR = { 60, 200, 80 },
		FUSE_TOP = { 210, 130, 255 },
		FUSE_BOTTOM = { 120, 50, 210 },
		FUSE_STROKE = { 60, 15, 110 },
		DARKEN = 0.55, -- bas du dégradé d'une carte : couleur de rareté assombrie
		RAINBOW = { { 255, 80, 80 }, { 255, 200, 60 }, { 90, 220, 90 }, { 60, 170, 255 }, { 190, 90, 255 } },
		GOLD_STROKE = { 255, 200, 40 },
		-- Onglet Œufs : une carte par œuf avec ses chances (A42).
		EGG_CARD_MIN_WIDTH = 200,
		EGG_CARD_HEIGHT = 300,
		EGG_ODDS_ROW = 24,
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
		GIFT_COLUMNS = 3,
		GIFT_HEIGHT = 128,
		QUEST_HEIGHT = 92,
		PADDING = 12,
		SPIN_SECONDS = 4,
		SPIN_TURNS = 5,
		-- Cartes de cadeau selon leur état : à réclamer (or), en attente (bleu), déjà reçu (gris).
		READY_TOP = { 255, 230, 90 },
		READY_BOTTOM = { 255, 150, 20 },
		WAIT_TOP = { 110, 175, 255 },
		WAIT_BOTTOM = { 50, 105, 215 },
		DONE_TOP = { 175, 175, 185 },
		DONE_BOTTOM = { 120, 120, 130 },
		QUEST_TOP = { 255, 255, 255 }, -- fond clair des lignes de quête
		QUEST_BOTTOM = { 215, 228, 250 },
		BAR_BACK = { 40, 50, 80 },
		BAR_TOP = { 140, 240, 80 },
		BAR_BOTTOM = { 50, 170, 40 },
		READY_PULSE = { scale = 0.06, speed = 6 }, -- les récompenses prêtes « respirent »
		WHEEL_RIM_TOP = { 255, 230, 110 }, -- jante dorée de la roue
		WHEEL_RIM_BOTTOM = { 220, 140, 20 },
		WHEEL_FACE = { 255, 250, 235 },
		WHEEL_RIM = 0.08, -- épaisseur de la jante, en part du diamètre
		WHEEL_LABEL_RADIUS = 0.3, -- position des cases, en part du diamètre
		POINTER_COLOR = { 230, 30, 40 },
		QUEST_ICONS = {
			Harvest = "🌾",
			Corn = "🌽",
			Diamond = "💠",
			Bumper = "💥",
			Unload = "🚜",
			Boss = "☄️",
		} :: {
			[string]: string,
		},
	},
	-- Pop-up « GAGNÉ ! » (roue, CDC §7.4) : rayons qui tournent, confettis, grosse icône qui rebondit.
	REWARD_POPUP = {
		WIDTH = 340,
		HEIGHT = 300,
		RAYS = 12,
		RAY_WIDTH = 0.09, -- en part de la taille du halo
		RAY_SPEED = 40, -- degrés par seconde
		RAY_COLOR = { 255, 235, 120 },
		RAY_TRANSPARENCY = 0.35,
		HALO_SCALE = 1.9, -- halo de rayons, en part de la hauteur de la carte
		TOP = { 255, 235, 110 },
		BOTTOM = { 255, 150, 20 },
		CONFETTI = 28,
		CONFETTI_SIZE = 12,
		CONFETTI_SECONDS = 1.4,
		CONFETTI_SPREAD = 260, -- pixels
		CONFETTI_COLORS = { { 255, 60, 90 }, { 60, 200, 255 }, { 120, 230, 60 }, { 255, 210, 40 }, { 170, 90, 255 } },
		POP_SECONDS = 0.45,
		HIDE_SECONDS = 0.18,
		SHOW_SECONDS = 4, -- se ferme seule après ce délai
		DISPLAY_ORDER = 20, -- au-dessus des menus
		POINTER_FLICK_DEGREES = 25, -- le pointeur de la roue claque à chaque case
		POINTER_FLICK_SECONDS = 0.12,
	},
	-- Gros boutons ronds du HUD, empilés à gauche : 🛒 boutique, 🎁 récompenses, 🐾 Pets (CDC §10).
	HUD_BUTTON = {
		SIZE = 72,
		LEFT = 16,
		SHOP_BOTTOM = 184, -- distance au bas de l'écran
		GIFTS_BOTTOM = 100,
		PETS_BOTTOM = 16,
		WIGGLE = { degrees = 8, period = 4, seconds = 0.6, shakes = 5 }, -- frétillement pour attirer l'œil
		ALERT_COLOR = { 255, 40, 60 }, -- pastille « ! » quand une récompense attend
		SHOP_TOP = { 255, 225, 80 },
		SHOP_BOTTOM_COLOR = { 255, 140, 20 },
		GIFTS_TOP = { 120, 235, 120 },
		GIFTS_BOTTOM_COLOR = { 40, 165, 60 },
		PETS_TOP = { 210, 130, 255 },
		PETS_BOTTOM_COLOR = { 120, 50, 210 },
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
		TAB_GAP = 12,
		TAB_ON_TOP = { 255, 225, 80 },
		TAB_ON_BOTTOM = { 255, 160, 20 },
		TAB_OFF_TOP = { 70, 120, 220 },
		TAB_OFF_BOTTOM = { 40, 80, 170 },
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
