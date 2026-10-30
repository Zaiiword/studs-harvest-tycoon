--!strict
-- Gacha de Pets (CDC §7.2, §8, Sprint 6) : distributeurs d'œufs sur chaque base (on marche sur le bouton pour
-- faire éclore), Œuf Légendaire ouvert depuis le menu, équipement (3 au plus), fusion Or / Arc-en-ciel.
-- Publie les Pets équipés (attribut lu par TycoonService et par les clients) et le facteur de puissance de coupe.
-- Le serveur tire au sort ; le client ne fait que demander et afficher.
-- Dépendances : Pets (pur), TycoonService (argent, gemmes), InventoryService (œufs gagnés), PlotService (base).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PetConfig = require(ReplicatedStorage.Shared.config.PetConfig)
local Formulas = require(ReplicatedStorage.Shared.domain.Formulas)
local MapGeometry = require(ReplicatedStorage.Shared.domain.MapGeometry)
local Pets = require(ReplicatedStorage.Shared.domain.Pets)
local PetRequests = require(ReplicatedStorage.Shared.net.PetRequests)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local Remotes = require(ReplicatedStorage.Shared.net.Remotes)
local RateLimiter = require(ReplicatedStorage.Shared.util.RateLimiter)
local PetModels = require(script.Parent.Parent.builders.PetModels)
local InventoryService = require(script.Parent.InventoryService)
local MapService = require(script.Parent.MapService)
local PlotService = require(script.Parent.PlotService)
local TycoonService = require(script.Parent.TycoonService)

local PetService = {}

type Entry = {
	collection: Pets.Collection,
	dispensers: Folder?,
	currentPad: string?,
	lastHatchAt: number,
}

local CHECK_INTERVAL = 0.25

local random = Random.new()
local entries: { [Player]: Entry } = {}
local requestLimiter = RateLimiter.new(6, 3)
local hatchResult: RemoteEvent
local announce: RemoteEvent
local checkElapsed = 0

local function entryOf(player: Player): Entry
	local entry = entries[player]
	if not entry then
		entry = { collection = Pets.newCollection(), lastHatchAt = -math.huge }
		entries[player] = entry
	end
	return entry :: Entry
end

local function publish(player: Player)
	local collection = entryOf(player).collection
	player:SetAttribute(PlayerAttributes.EQUIPPED_PETS, Pets.encodeEquipped(collection.equipped))
	player:SetAttribute(PlayerAttributes.OWNED_PETS, Pets.encodeOwned(collection.owned))
	-- A2 : la puissance de coupe profite du même facteur que les revenus (1 + Σ(bonus − 1)).
	player:SetAttribute(PlayerAttributes.CUT_POWER_MULTIPLIER, Formulas.petFactor(Pets.bonuses(collection)))
end

local function nextRoll(): number
	return random:NextNumber()
end

local function pay(player: Player, egg: PetConfig.EggDef): boolean
	if egg.currency == "money" then
		return TycoonService.spendMoney(player, egg.price)
	elseif egg.currency == "gems" then
		return TycoonService.spendGems(player, egg.price)
	end
	return InventoryService.take(player, egg.id)
end

-- Fait éclore un œuf : on vérifie la place AVANT de faire payer, puis le serveur tire le Pet.
local function hatch(player: Player, egg: PetConfig.EggDef)
	local entry = entryOf(player)
	local now = os.clock()
	if now - entry.lastHatchAt < PetConfig.HATCH_COOLDOWN or Pets.total(entry.collection) >= PetConfig.MAX_PETS then
		return
	end
	if not pay(player, egg) then
		return
	end
	entry.lastHatchAt = now
	local key = Pets.roll(egg, nextRoll)
	Pets.add(entry.collection, key)
	publish(player)
	hatchResult:FireClient(player, egg.id, key)
	if Pets.rarityOf(key).isAnnounced then
		announce:FireAllClients(player.DisplayName, key) -- CDC §8 : annonce globale (DisplayName, déjà filtré)
	end
end

local function buildDispensers(player: Player)
	local entry = entryOf(player)
	local base = PlotService.basePlacement(player)
	local index = PlotService.baseIndexOf(player)
	local floor = index and MapService.basePart(index)
	if entry.dispensers or not base or not floor then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "EggDispensers"
	folder.Parent = floor
	for eggId, spot in PetConfig.DISPENSERS do
		local padX, padZ = MapGeometry.baseToWorld(base, spot.x, spot.z)
		local eggX, eggZ = MapGeometry.baseToWorld(base, spot.x + PetConfig.EGG_OFFSET_X, spot.z)
		PetModels.dispenser(folder, Pets.egg(eggId) :: PetConfig.EggDef, {
			padCFrame = CFrame.new(padX, 0, padZ),
			eggCFrame = CFrame.new(eggX, 0, eggZ),
		})
	end
	entry.dispensers = folder
end

local function dispenserUnder(player: Player): PetConfig.EggDef?
	local base = PlotService.basePlacement(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not base or not root then
		return nil
	end
	local localX, localZ = MapGeometry.worldToBase(base, root.Position.X, root.Position.Z)
	for eggId, spot in PetConfig.DISPENSERS do
		if MapGeometry.isOnSquare(localX, localZ, spot.x, spot.z, PetConfig.DISPENSER_SIZE) then
			return Pets.egg(eggId)
		end
	end
	return nil
end

-- Un distributeur ne fait éclore qu'à l'arrivée du joueur dessus, comme les boutons de l'usine.
local function checkDispensers()
	for player, entry in entries do
		local egg = dispenserUnder(player)
		local eggId = egg and egg.id
		if egg and eggId ~= entry.currentPad then
			hatch(player, egg)
		end
		entry.currentPad = eggId
	end
end

local function onAction(player: Player, rawAction: any, rawKey: any)
	local action, key = PetRequests.parseAction(rawAction, rawKey)
	if not action or not key or not requestLimiter:allow(player, os.clock()) then
		return
	end
	local collection = entryOf(player).collection
	if action == "equip" then
		Pets.equip(collection, key)
	elseif action == "unequip" then
		Pets.unequip(collection, key)
	else
		Pets.fuse(collection, key)
	end
	publish(player)
end

local function onOpenEgg(player: Player, rawEggId: any)
	local egg = PetRequests.parseItemEgg(rawEggId)
	if egg and requestLimiter:allow(player, os.clock()) then
		hatch(player, egg)
	end
end

function PetService.snapshot(player: Player): Pets.Collection
	local collection = entryOf(player).collection
	return { owned = table.clone(collection.owned), equipped = table.clone(collection.equipped) }
end

function PetService.restore(player: Player, collection: Pets.Collection)
	entryOf(player).collection = Pets.sanitize(collection)
	publish(player)
end

-- Oublie le joueur qui part (appelé par DataService après la capture du profil).
function PetService.release(player: Player)
	local entry = entries[player]
	if entry and entry.dispensers then
		entry.dispensers:Destroy()
	end
	entries[player] = nil
	requestLimiter:forget(player)
end

local function watch(player: Player)
	player:GetAttributeChangedSignal(PlayerAttributes.BASE_INDEX):Connect(function()
		buildDispensers(player)
	end)
	buildDispensers(player)
	publish(player)
end

function PetService:Init()
	hatchResult = Remotes.event(Remotes.HATCH_RESULT)
	announce = Remotes.event(Remotes.PET_ANNOUNCE)
	Remotes.event(Remotes.PET_ACTION).OnServerEvent:Connect(onAction)
	Remotes.event(Remotes.OPEN_EGG).OnServerEvent:Connect(onOpenEgg)
end

function PetService:Start()
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	RunService.Heartbeat:Connect(function(deltaTime: number)
		checkElapsed += deltaTime
		if checkElapsed >= CHECK_INTERVAL then
			checkElapsed = 0
			checkDispensers()
		end
	end)
end

return PetService
