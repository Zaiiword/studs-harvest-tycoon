--!strict
-- Persistance avec verrouillage de session (CDC §11, docs/CLEAN_CODE.md §4), sans API Roblox :
-- le DataStore, l'horloge et l'attente sont injectés (FakeDataStore dans les tests, DataStoreService en jeu).
--
-- Enregistrement : { data = Profile.Data, lock = { id = sessionId, at = horodatage } | nil }.
-- * Charger = poser son verrou via UpdateAsync, sauf si un autre serveur en tient un encore valide.
-- * Sauvegarder = n'écrire que si l'on détient toujours le verrou (sinon un autre serveur a repris la main :
--   écrire écraserait des données plus récentes → duplication possible).
-- * Libérer = sauvegarder en retirant le verrou (départ du joueur, fermeture du serveur).
-- Chaque appel est réessayé avec un délai qui double (backoff exponentiel).
local Profile = require("./Profile")

export type Lock = { id: string, at: number }
export type Record = { data: any, lock: Lock? }

-- `update` a la sémantique de GlobalDataStore:UpdateAsync : la transformation reçoit l'ancienne valeur et
-- renvoie la nouvelle, ou nil pour annuler l'écriture. Elle peut lever une erreur (quota, panne).
export type Adapter = {
	update: (key: string, transform: (old: Record?) -> Record?) -> Record?,
}

export type Options = {
	sessionId: string,
	now: () -> number,
	wait: (seconds: number) -> (),
	lockTtl: number, -- un verrou plus vieux que ça est considéré comme abandonné (serveur planté)
	maxAttempts: number,
	baseBackoff: number,
}

export type LoadResult = { data: Profile.Data?, reason: string? }

local ProfileStore = {}
ProfileStore.__index = ProfileStore

type StoreData = { _adapter: Adapter, _options: Options }
export type ProfileStore = typeof(setmetatable({} :: StoreData, ProfileStore))

ProfileStore.REASON_LOCKED = "locked" -- un autre serveur détient encore le profil
ProfileStore.REASON_ERROR = "error" -- le DataStore a échoué à chaque tentative

function ProfileStore.new(adapter: Adapter, options: Options): ProfileStore
	return setmetatable({ _adapter = adapter, _options = options }, ProfileStore)
end

local function isHeldByOther(record: Record?, sessionId: string, now: number, ttl: number): boolean
	local lock = record and record.lock
	return lock ~= nil and lock.id ~= sessionId and now - lock.at < ttl
end

function ProfileStore.load(self: ProfileStore, key: string): LoadResult
	local options = self._options
	local reason = ProfileStore.REASON_ERROR
	for attempt = 1, options.maxAttempts do
		local isBlocked = false
		local ok, result = pcall(self._adapter.update, key, function(old: Record?): Record?
			local now = options.now()
			if isHeldByOther(old, options.sessionId, now, options.lockTtl) then
				isBlocked = true
				return nil
			end
			return { data = Profile.sanitize(old and old.data), lock = { id = options.sessionId, at = now } }
		end)
		if ok and result and not isBlocked then
			return { data = Profile.sanitize(result.data) }
		end
		reason = if isBlocked then ProfileStore.REASON_LOCKED else ProfileStore.REASON_ERROR
		if attempt < options.maxAttempts then
			options.wait(options.baseBackoff * 2 ^ (attempt - 1))
		end
	end
	return { reason = reason }
end

-- Écrit `data` si l'on détient toujours le verrou. `isRelease` retire le verrou après l'écriture.
-- Renvoie false si le verrou est perdu ou si le DataStore a échoué à chaque tentative.
function ProfileStore.save(self: ProfileStore, key: string, data: Profile.Data, isRelease: boolean): boolean
	local options = self._options
	for attempt = 1, options.maxAttempts do
		local isLockLost = false
		local ok = pcall(self._adapter.update, key, function(old: Record?): Record?
			local lock = old and old.lock
			if not lock or lock.id ~= options.sessionId then
				isLockLost = true
				return nil
			end
			local newLock = if isRelease then nil else { id = options.sessionId, at = options.now() }
			return { data = Profile.sanitize(data), lock = newLock }
		end)
		if isLockLost then
			return false
		end
		if ok then
			return true
		end
		if attempt < options.maxAttempts then
			options.wait(options.baseBackoff * 2 ^ (attempt - 1))
		end
	end
	return false
end

return ProfileStore
