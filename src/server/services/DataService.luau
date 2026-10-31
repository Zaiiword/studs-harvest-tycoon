--!strict
-- Sauvegarde du profil joueur (CDC §11, Sprint 4) : chargement avec verrou de session, sauvegarde automatique
-- toutes les 60 s, sauvegarde + libération au départ du joueur et à la fermeture du serveur (BindToClose).
-- Toute la logique de verrou est dans ProfileStore (pur, testé) ; ce service ne fait que la brancher sur
-- DataStoreService et sur TycoonService. Sans accès aux API dans Studio, il bascule sur un stockage en mémoire.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataConfig = require(ReplicatedStorage.Shared.config.DataConfig)
local Profile = require(ReplicatedStorage.Shared.domain.Profile)
local ProfileStore = require(ReplicatedStorage.Shared.domain.ProfileStore)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local InventoryService = require(script.Parent.InventoryService)
local PetService = require(script.Parent.PetService)
local RetentionService = require(script.Parent.RetentionService)
local MonetizationService = require(script.Parent.MonetizationService)
local TycoonService = require(script.Parent.TycoonService)

local DataService = {}

local store: ProfileStore.ProfileStore
local loaded: { [Player]: boolean } = {}
local savesInFlight = 0

local function keyOf(player: Player): string
	return DataConfig.KEY_PREFIX .. player.UserId
end

local function dataStoreAdapter(): ProfileStore.Adapter?
	local ok, dataStore = pcall(DataStoreService.GetDataStore, DataStoreService, DataConfig.STORE_NAME)
	if not ok then
		return nil
	end
	return {
		update = function(key, transform)
			return (dataStore :: DataStore):UpdateAsync(key, transform)
		end,
	}
end

-- Stockage en mémoire pour Studio sans « Enable Studio Access to API Services » : rien ne survit à la session.
local function memoryAdapter(): ProfileStore.Adapter
	local records: { [string]: any } = {}
	return {
		update = function(key, transform)
			local result = transform(records[key])
			if result ~= nil then
				records[key] = result
			end
			return result
		end,
	}
end

local function chooseAdapter(): ProfileStore.Adapter
	local adapter = dataStoreAdapter()
	if adapter then
		local ok = pcall(adapter.update, "__probe", function()
			return nil
		end)
		if ok then
			return adapter
		end
	end
	warn(
		"[DataService] DataStore indisponible : sauvegarde EN MÉMOIRE uniquement (activer l'accès aux API dans Studio)"
	)
	return memoryAdapter()
end

local function loadPlayer(player: Player)
	local result = store:load(keyOf(player))
	if not player.Parent then
		return -- parti pendant le chargement : le verrou expirera seul (LOCK_TTL)
	end
	local data = result.data
	if not data then
		local isLocked = result.reason == ProfileStore.REASON_LOCKED
		player:Kick(if isLocked then DataConfig.KICK_LOCKED else DataConfig.KICK_ERROR)
		return
	end
	loaded[player] = true
	TycoonService.restore(player, data)
	InventoryService.restore(player, data.items)
	PetService.restore(player, data.pets)
	RetentionService.restore(player, data.retention)
	MonetizationService.restore(player, data.purchases)
	player:SetAttribute(PlayerAttributes.IS_DATA_LOADED, true)
end

local function capture(player: Player): Profile.Data?
	local factory = TycoonService.snapshot(player)
	if not factory then
		return nil
	end
	return Profile.fromGame({
		tycoon = factory.tycoon,
		tier = factory.tier,
		progress = factory.progress,
		items = InventoryService.snapshot(player),
		pets = PetService.snapshot(player),
		retention = RetentionService.snapshot(player),
		purchases = MonetizationService.snapshot(player),
	})
end

-- Sauvegarde le profil ; renvoie vrai si l'écriture a réussi (MonetizationService en a besoin pour les reçus).
local function save(player: Player, isRelease: boolean): boolean
	local data = capture(player)
	if not data or not loaded[player] or not store then
		return false
	end
	savesInFlight += 1
	local isSaved = store:save(keyOf(player), data, isRelease)
	if not isSaved then
		warn(`[DataService] sauvegarde refusée ou en échec pour {player.UserId} (verrou perdu ou DataStore en panne)`)
	end
	savesInFlight -= 1
	return isSaved
end

-- Capture le profil AVANT de libérer l'usine et l'inventaire, puis sauvegarde en libérant le verrou.
local function onPlayerRemoving(player: Player)
	local data = if loaded[player] then capture(player) else nil
	TycoonService.release(player)
	InventoryService.release(player)
	PetService.release(player)
	RetentionService.release(player)
	MonetizationService.release(player)
	local wasLoaded = loaded[player]
	loaded[player] = nil
	if data and wasLoaded then
		savesInFlight += 1
		store:save(keyOf(player), data, true)
		savesInFlight -= 1
	end
end

local function autosaveLoop()
	while true do
		task.wait(DataConfig.AUTOSAVE_INTERVAL)
		for player in loaded do
			task.spawn(save, player, false)
		end
	end
end

-- Le serveur ferme : on sauvegarde tout le monde en parallèle et on attend la fin des écritures.
local function onClose()
	for player in loaded do
		task.spawn(onPlayerRemoving, player)
	end
	while savesInFlight > 0 do
		task.wait()
	end
end

function DataService:Init()
	MonetizationService.setSaver(function(player: Player): boolean
		return save(player, false)
	end)
end

-- Start et non Init : tester l'accès au DataStore fait une requête, donc cède la main.
function DataService:Start()
	store = ProfileStore.new(chooseAdapter(), {
		sessionId = if game.JobId ~= "" then game.JobId else HttpService:GenerateGUID(false),
		now = os.time,
		wait = task.wait,
		lockTtl = DataConfig.LOCK_TTL,
		maxAttempts = DataConfig.MAX_ATTEMPTS,
		baseBackoff = DataConfig.BASE_BACKOFF,
	})
	Players.PlayerAdded:Connect(loadPlayer)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end
	task.spawn(autosaveLoop)
	game:BindToClose(onClose)
	if RunService:IsStudio() then
		print("[DataService] sauvegarde active (clé : " .. DataConfig.KEY_PREFIX .. "<UserId>)")
	end
end

return DataService
