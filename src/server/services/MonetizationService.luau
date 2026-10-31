--!strict
-- Monétisation Robux (CDC §9, §10, Sprint 8) : Gamepasses, DevProducts, « Se venger » et Starter Pack.
-- ProcessReceipt est idempotent (docs/ANALYSE_CDC.md §4) : un reçu déjà accordé n'est jamais accordé deux
-- fois, et PurchaseGranted n'est renvoyé qu'APRÈS une sauvegarde réussie (sinon Roblox rappellera plus tard).
-- Les effets des passes sont lus par les autres services via les attributs « Pass_<clé> » (net/Perks).
-- Dépendances : Inventory/Pet/Tycoon/Event/BumperService (effets). DataService injecte la sauvegarde.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MonetizationConfig = require(ReplicatedStorage.Shared.config.MonetizationConfig)
local Purchases = require(ReplicatedStorage.Shared.domain.Purchases)
local Sabotage = require(ReplicatedStorage.Shared.domain.Sabotage)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local Remotes = require(ReplicatedStorage.Shared.net.Remotes)
local BumperService = require(script.Parent.BumperService)
local EventService = require(script.Parent.EventService)
local InventoryService = require(script.Parent.InventoryService)
local PetService = require(script.Parent.PetService)
local TycoonService = require(script.Parent.TycoonService)

local MonetizationService = {}

type Entry = { purchases: Purchases.Purchases, joinedAt: number, hasFilledBag: boolean }
type Aggressor = { userId: number, at: number }
type Grant = (player: Player) -> ()

local STARTER = MonetizationConfig.STARTER
local OFFER_CHECK_INTERVAL = 5

local entries: { [Player]: Entry } = {}
local aggressors: { [Player]: Aggressor } = {}
local productsById: { [number]: MonetizationConfig.ProductDef } = {}
local passesById: { [number]: MonetizationConfig.PassDef } = {}
-- Remplacée par DataService (setSaver) ; tant qu'elle ne l'est pas, aucun achat n'est confirmé.
local saveNow: (Player) -> boolean = function(_player: Player): boolean
	return false
end
local notify: RemoteEvent
local offerElapsed = 0

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function entryOf(player: Player): Entry
	local entry = entries[player]
	if not entry then
		entry = { purchases = Purchases.new(), joinedAt = os.clock(), hasFilledBag = false }
		entries[player] = entry
	end
	return entry :: Entry
end

local function publish(player: Player)
	local purchases = entryOf(player).purchases
	player:SetAttribute(PlayerAttributes.HAS_TURBO_TRACTOR, purchases.hasTurboTractor)
	local isOpen = Purchases.isStarterOfferOpen(purchases, now())
	local closesAt = purchases.starterOfferedAt + STARTER.OFFER_DURATION_SECONDS
	player:SetAttribute(PlayerAttributes.STARTER_OFFER_UNTIL, if isOpen then closesAt else 0)
end

-- « Se venger » (A14, A49) : éjecte le dernier agresseur s'il est encore là et non protégé ; sinon le joueur
-- reçoit 1 tir de Bazooka en compensation (un achat Robux ne se rembourse pas).
local function revenge(player: Player)
	local aggressor = aggressors[player]
	local isRecent = aggressor ~= nil and os.clock() - aggressor.at <= MonetizationConfig.REVENGE_MEMORY_SECONDS
	local contestants = BumperService.contestants()
	local user, target = nil, nil
	for _, contestant in contestants do
		if contestant.player == player then
			user = contestant
		elseif isRecent and contestant.body.id == (aggressor :: Aggressor).userId then
			target = contestant
		end
	end
	if user and target then
		local horizontal, vertical = Sabotage.launchForDistance(MonetizationConfig.REVENGE_EJECT_DISTANCE)
		local dx, dz = target.body.x - user.body.x, target.body.z - user.body.z
		local length = math.max(1e-6, math.sqrt(dx * dx + dz * dz))
		local ejection: BumperService.Ejection = {
			dirX = dx / length,
			dirZ = dz / length,
			horizontal = horizontal,
			vertical = vertical,
			attacker = player,
		}
		if BumperService.eject(target, ejection) then
			notify:FireClient(player, "💥 Vengeance accomplie !")
			return
		end
	end
	InventoryService.add(player, "Bazooka", 1)
	notify:FireClient(player, "Cible introuvable ou protégée : +1 tir de Bazooka 🚀")
end

local function starterPack(player: Player)
	local purchases = entryOf(player).purchases
	purchases.hasStarterPack = true
	purchases.hasTurboTractor = true
	TycoonService.grant(player, STARTER.MONEY)
	PetService.grantPet(player, STARTER.PET)
	publish(player)
	notify:FireClient(player, "🎉 Starter Pack : Mini-Tracteur Turbo, Pet Épique et 10 000 $ !")
end

local GRANTS: { [string]: Grant } = {
	Bazooka = function(player)
		InventoryService.add(player, "Bazooka", 3)
	end,
	Meteor = function(player)
		local isNow = EventService.summonMeteor(player.DisplayName)
		notify:FireClient(
			player,
			if isNow
				then "☄️ Météorite invoquée !"
				else "☄️ Ta Météorite tombera juste après le boss actuel."
		)
	end,
	Revenge = revenge,
	StarterPack = starterPack,
}

-- Accorde un produit (achat réel ou simulation Studio). Le Starter Pack ne s'achète qu'une fois par compte.
function MonetizationService.grantProduct(player: Player, key: string)
	if key == "StarterPack" and entryOf(player).purchases.hasStarterPack then
		InventoryService.add(player, "Bazooka", 3) -- ne devrait pas arriver (offre fermée) : on compense
		return
	end
	local grant = GRANTS[key]
	if grant then
		grant(player)
	end
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local product = productsById[receipt.ProductId]
	local entry = player and entries[player]
	if not player or not product or not entry or not player:GetAttribute(PlayerAttributes.IS_DATA_LOADED) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receiptId = tostring(receipt.PurchaseId)
	if not Purchases.hasReceipt(entry.purchases, receiptId) then
		MonetizationService.grantProduct(player, product.key)
		Purchases.recordReceipt(entry.purchases, receiptId)
	end
	-- Accordé (maintenant ou lors d'un appel précédent) : on ne confirme qu'une fois la sauvegarde réussie.
	if saveNow(player) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

local function setPass(player: Player, key: string, isOwned: boolean)
	player:SetAttribute(PlayerAttributes.PASS_PREFIX .. key, isOwned)
end

local function loadPasses(player: Player)
	for _, pass in MonetizationConfig.GAMEPASSES do
		if pass.id > 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
			setPass(player, pass.key, ok and owns == true)
		end
	end
end

-- Simulation dans Studio (panneau de test) : bascule un Gamepass sans achat réel.
function MonetizationService.togglePass(player: Player, key: string)
	setPass(player, key, player:GetAttribute(PlayerAttributes.PASS_PREFIX .. key) ~= true)
end

-- Starter Pack : proposé une fois par compte, après 4 min ou au premier sac plein (A50).
local function checkStarterOffers()
	for player, entry in entries do
		local played = os.clock() - entry.joinedAt
		if
			player:GetAttribute(PlayerAttributes.IS_DATA_LOADED)
			and Purchases.shouldOfferStarter(entry.purchases, played, entry.hasFilledBag)
		then
			entry.purchases.starterOfferedAt = now()
		end
		publish(player)
	end
end

local function watch(player: Player)
	entryOf(player)
	task.spawn(loadPasses, player)
	player:GetAttributeChangedSignal(PlayerAttributes.BAG_COUNT):Connect(function()
		local count, capacity =
			player:GetAttribute(PlayerAttributes.BAG_COUNT), player:GetAttribute(PlayerAttributes.BAG_CAPACITY)
		if
			typeof(count) == "number"
			and typeof(capacity) == "number"
			and capacity ~= math.huge
			and count >= capacity
		then
			entryOf(player).hasFilledBag = true
		end
	end)
end

-- « Se venger » : on retient le dernier agresseur, et la victime voit le bouton pendant 6 s (CDC §10).
local function onEjected(attacker: Player, target: Player)
	aggressors[target] = { userId = attacker.UserId, at = os.clock() }
	target:SetAttribute(PlayerAttributes.REVENGE_TARGET, attacker.DisplayName)
	target:SetAttribute(PlayerAttributes.REVENGE_UNTIL, now() + MonetizationConfig.REVENGE_BUTTON_SECONDS)
end

function MonetizationService.snapshot(player: Player): Purchases.Purchases
	return Purchases.sanitize(entryOf(player).purchases)
end

function MonetizationService.restore(player: Player, purchases: Purchases.Purchases)
	entryOf(player).purchases = Purchases.sanitize(purchases)
	publish(player)
end

function MonetizationService.release(player: Player)
	entries[player] = nil
	aggressors[player] = nil
end

-- DataService fournit sa sauvegarde immédiate (évite une dépendance circulaire entre les deux services).
function MonetizationService.setSaver(saver: (Player) -> boolean)
	saveNow = saver
end

function MonetizationService:Init()
	notify = Remotes.event(Remotes.NOTIFY)
	for _, product in MonetizationConfig.PRODUCTS do
		productsById[product.id] = if product.id > 0 then product else nil
	end
	for _, pass in MonetizationConfig.GAMEPASSES do
		passesById[pass.id] = if pass.id > 0 then pass else nil
	end
	MarketplaceService.ProcessReceipt = processReceipt
end

function MonetizationService:Start()
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, wasPurchased: boolean)
			local pass = passesById[passId]
			if pass and wasPurchased then
				setPass(player, pass.key, true)
			end
		end
	)
	BumperService.Ejected:Connect(onEjected)
	RunService.Heartbeat:Connect(function(deltaTime: number)
		offerElapsed += deltaTime
		if offerElapsed >= OFFER_CHECK_INTERVAL then
			offerElapsed = 0
			checkStarterOffers()
		end
	end)
end

return MonetizationService
