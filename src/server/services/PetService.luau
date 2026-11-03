--!strict
-- Gacha de Pets (CDC §7.2, §8, Sprint 6) : distributeurs d'œufs sur chaque base (on marche sur le bouton pour
-- faire éclore), Œuf Légendaire ouvert depuis le menu, équipement (3 au plus), fusion Or / Arc-en-ciel.
-- Publie les Pets équipés (attribut lu par TycoonService et par les clients) et le facteur de puissance de coupe.
-- Le serveur tire au sort ; le client ne fait que demander et afficher.
-- Dépendances : Pets (pur), TycoonService (argent, gemmes), InventoryService (œufs gagnés), PlotService (base).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MonetizationConfig = require(ReplicatedStorage.Shared.config.MonetizationConfig)
local PetConfig = require(ReplicatedStorage.Shared.config.PetConfig)
local TycoonConfig = require(ReplicatedStorage.Shared.config.TycoonConfig)
local Formulas = require(ReplicatedStorage.Shared.domain.Formulas)
local MapGeometry = require(ReplicatedStorage.Shared.domain.MapGeometry)
local Pets = require(ReplicatedStorage.Shared.domain.Pets)
local PetRequests = require(ReplicatedStorage.Shared.net.PetRequests)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local Perks = require(ReplicatedStorage.Shared.net.Perks)
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
	visibleEggs: { [string]: boolean }, -- distributeurs déjà construits (A56)
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
		entry = { collection = Pets.newCollection(), lastHatchAt = -math.huge, visibleEggs = {} }
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

-- Un œuf : on vérifie la place AVANT de faire payer, puis le serveur tire le Pet.
local function hatchOne(player: Player, entry: Entry, egg: PetConfig.EggDef): boolean
	if Pets.total(entry.collection) >= PetConfig.MAX_PETS or not pay(player, egg) then
		return false
	end
	local key = Pets.roll(egg, nextRoll)
	Pets.add(entry.collection, key)
	publish(player)
	hatchResult:FireClient(player, egg.id, key)
	if Pets.rarityOf(key).isAnnounced then
		announce:FireAllClients(player.DisplayName, key) -- CDC §8 : annonce globale (DisplayName, déjà filtré)
	end
	return true
end

-- Gamepass Triple Éclosion (CDC §9) : 3 œufs d'un coup, chacun payé et tiré séparément.
local function hatch(player: Player, egg: PetConfig.EggDef)
	local entry = entryOf(player)
	local now = os.clock()
	if now - entry.lastHatchAt < PetConfig.HATCH_COOLDOWN then
		return
	end
	entry.lastHatchAt = now
	local count = if Perks.hasPass(player, "TripleHatch") then MonetizationConfig.TRIPLE_HATCH_COUNT else 1
	for _ = 1, count do
		if not hatchOne(player, entry, egg) then
			return
		end
	end
end

-- Construit les distributeurs débloqués (A56) ; ceux qui apparaissent en cours de partie tombent du ciel.
local function buildDispensers(player: Player)
	local entry = entryOf(player)
	local base = PlotService.basePlacement(player)
	local index = PlotService.baseIndexOf(player)
	local floor = index and MapService.basePart(index)
	if not base or not floor then
		return
	end
	local isFirstBuild = entry.dispensers == nil
	local folder = entry.dispensers or Instance.new("Folder")
	folder.Name = "EggDispensers"
	folder.Parent = floor
	entry.dispensers = folder
	if isFirstBuild then -- dans le dossier : le couvoir disparaît avec le joueur
		local centerX, centerZ = MapGeometry.baseToWorld(base, 0, 0)
		PetModels.hatchery(folder, CFrame.new(centerX, 0, centerZ))
	end
	local tier = player:GetAttribute(PlayerAttributes.TIER)
	local rebirths = player:GetAttribute(PlayerAttributes.REBIRTHS)
	for eggId, spot in PetConfig.DISPENSERS do
		local isVisible = Pets.isEggVisible(
			eggId,
			if typeof(tier) == "number" then tier else 1,
			if typeof(rebirths) == "number" then rebirths else 0
		)
		if isVisible and not entry.visibleEggs[eggId] then
			entry.visibleEggs[eggId] = true
			local padX, padZ = MapGeometry.baseToWorld(base, spot.x, spot.z)
			local eggX, eggZ = MapGeometry.baseToWorld(base, spot.x, spot.z + PetConfig.EGG_OFFSET_Z)
			local model = PetModels.dispenser(nil, Pets.egg(eggId) :: PetConfig.EggDef, {
				padCFrame = CFrame.new(padX, 0, padZ),
				eggCFrame = CFrame.new(eggX, 0, eggZ),
			})
			if not isFirstBuild then
				model:SetAttribute(TycoonConfig.BUILD_ANIM_ATTRIBUTE, Workspace:GetServerTimeNow())
			end
			model.Parent = folder
		end
	end
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
		if
			entryOf(player).visibleEggs[eggId]
			and MapGeometry.isOnSquare(localX, localZ, spot.x, spot.z, PetConfig.DISPENSER_SIZE)
		then
			return Pets.egg(eggId)
		end
	end
	return nil
end

-- Un distributeur ne fait éclore qu'à l'arrivée du joueur dessus, comme les boutons de l'usine ; avec
-- l'Auto-Hatch (Gamepass Triple Éclosion), il continue tant que le joueur y reste (au rythme de la recharge).
local function checkDispensers()
	for player, entry in entries do
		local egg = dispenserUnder(player)
		local eggId = egg and egg.id
		local isAuto = Perks.hasPass(player, "TripleHatch")
		if egg and (eggId ~= entry.currentPad or isAuto) then
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

-- Donne un Pet précis (Starter Pack, CDC §10). Renvoie faux si la collection est pleine.
function PetService.grantPet(player: Player, key: string): boolean
	local isAdded = Pets.add(entryOf(player).collection, key)
	publish(player)
	return isAdded
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
	for _, name in { PlayerAttributes.BASE_INDEX, PlayerAttributes.TIER, PlayerAttributes.REBIRTHS } do
		player:GetAttributeChangedSignal(name):Connect(function()
			buildDispensers(player)
		end)
	end
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
