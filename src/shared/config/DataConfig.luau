--!strict
-- Persistance (CDC §11, docs/ANALYSE_CDC.md §5 « Duplication d'objets »).
local Freeze = require("../util/Freeze")

return Freeze.deep({
	STORE_NAME = "PlayerProfiles_v1", -- changer de nom = repartir de zéro ; préférer une migration (Profile.VERSION)
	KEY_PREFIX = "player_",
	AUTOSAVE_INTERVAL = 60, -- secondes (le verrou est rafraîchi à chaque sauvegarde)
	LOCK_TTL = 300, -- un verrou non rafraîchi depuis 5 min est abandonné (serveur planté)
	MAX_ATTEMPTS = 5,
	BASE_BACKOFF = 1, -- 1, 2, 4, 8 s entre les tentatives
	KICK_LOCKED = "Ta partie est encore ouverte sur un autre serveur. Réessaie dans quelques minutes.",
	KICK_ERROR = "Impossible de charger ta sauvegarde pour le moment. Réessaie dans quelques minutes.",
})
