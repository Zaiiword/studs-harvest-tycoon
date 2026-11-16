--!strict
-- Récolte autoritaire (CDC §4, Sprint 1) : toutes les 0,15 s, la boîte de coupe placée devant chaque joueur
-- interroge la grille côté serveur, sans aucune requête client (décision A26). Remplit le sac, applique
-- la pénalité « PLEIN » (-10 % de vitesse) et vide le sac sur la grille de déchargement de sa base.
-- Dépendances : FieldService (brins), PlotService (bases), TycoonService (silo).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FieldConfig = require(ReplicatedStorage.Shared.config.FieldConfig)
local VehicleConfig = require(ReplicatedStorage.Shared.config.VehicleConfig)
local Bag = require(ReplicatedStorage.Shared.domain.Bag)
local MapGeometry = require(ReplicatedStorage.Shared.domain.MapGeometry)
local Movement = require(ReplicatedStorage.Shared.domain.Movement)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local Perks = require(ReplicatedStorage.Shared.net.Perks)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Spill = require(ReplicatedStorage.Shared.domain.Spill)
local FieldService = require(script.Parent.FieldService)
local PlotService = require(script.Parent.PlotService)
local Remotes = require(ReplicatedStorage.Shared.net.Remotes)
local Workspace = game:GetService("Workspace")
local TycoonService = require(script.Parent.TycoonService)
local EventService = require(script.Parent.EventService)

local HarvestService = {}

-- Signaux écoutés par la rétention (quêtes, statistiques) : la récolte ne dépend pas d'elle.
HarvestService.Harvested = Signal.new() -- (player, FieldGrid.CutResult)
HarvestService.Unloaded = Signal.new() -- (player, valeur déposée)

type PlayerState = {
	bag: Bag.Bag,
	blockedPlaces: number, -- places du dernier blé qui ne tenait pas dans le sac (A55)
	trove: any,
	backpack: Part?,
	weld: Weld?,
	shownStep: number,
	hasWarnedSiloFull: boolean, -- « silo plein » n'est dit qu'une fois par passage sur la grille (A68)
}

local BACKPACK = FieldConfig.BACKPACK
local ATTR = PlayerAttributes

local states: { [Player]: PlayerState } = {}
local elapsed = 0
local unloadedRemote: RemoteEvent
local notifyRemote: RemoteEvent

-- Palier effectif : Garage + avantages Robux (Aimant, Remorque Infinie, Mini-Tracteur Turbo).
local function tierOf(player: Player): VehicleConfig.TierDef
	return Perks.tierOf(player)
end

-- Multiplicateur publié en attribut (Pets, améliorations) : 1 s'il est absent ou invalide.
local function multiplierOf(player: Player, name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" and value >= 1 then value else 1
end

-- Puissance de coupe : celle de l'outil × facteur des Pets équipés (A2, publié par PetService) × Lames Affûtées (A65).
function HarvestService.cutPowerOf(player: Player, tier: VehicleConfig.TierDef): number
	return tier.cutPower * multiplierOf(player, ATTR.CUT_POWER_MULTIPLIER) * multiplierOf(player, ATTR.CUT_UPGRADE)
end

-- Capacité du sac : celle du palier × Sac XXL (A65).
local function capacityOf(player: Player, tier: VehicleConfig.TierDef): number
	return math.floor(tier.capacity * multiplierOf(player, ATTR.BAG_UPGRADE))
end

-- Butin des chocs (A71) : retire du sac la part lâchée par un joueur éjecté. Renvoie (places, valeur).
function HarvestService.spill(player: Player): (number, number)
	local state = states[player]
	if not state then
		return 0, 0
	end
	return Spill.take(state.bag)
end

-- Ramasse un tas de butin dans le sac du joueur, dans la limite des places libres. Renvoie les places prises.
function HarvestService.collect(player: Player, pile: Spill.Pile): number
	local state = states[player]
	return if state then Spill.pickUp(state.bag, pile) else 0
end

local function setIfChanged(player: Player, name: string, value: any)
	if player:GetAttribute(name) ~= value then
		player:SetAttribute(name, value)
	end
end

local function resizeBackpack(state: PlayerState)
	local step = Bag.fillStep(state.bag)
	local part, weld = state.backpack, state.weld
	if not part or not weld or step == state.shownStep then
		return
	end
	state.shownStep = step
	local height = BACKPACK.BASE_HEIGHT + step * BACKPACK.HEIGHT_PER_STEP
	part.Size = Vector3.new(BACKPACK.WIDTH, height, BACKPACK.DEPTH)
	weld.C0 = CFrame.new(0, BACKPACK.BOTTOM_Y + height / 2, BACKPACK.BACK_OFFSET)
end

-- Sac visible sur le dos : sa hauteur montre la richesse du joueur à distance (CDC §2).
local function attachBackpack(state: PlayerState, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not root then
		return
	end
	local part = Instance.new("Part")
	part.Name = "HarvestBackpack"
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	Bricks.style(part, BACKPACK.COLOR)
	local weld = Instance.new("Weld")
	weld.Part0, weld.Part1 = root, part
	weld.Parent = part
	part.Parent = character
	state.backpack, state.weld, state.shownStep = part, weld, -1
	resizeBackpack(state)
end

local function cutInFront(player: Player, state: PlayerState, root: BasePart, tier: VehicleConfig.TierDef)
	local look = root.CFrame.LookVector
	local position = root.Position
	local slot = PlotService.baseIndexOf(player) or 0
	local hitbox = { x = position.X, z = position.Z, dirX = look.X, dirZ = look.Z, size = tier.hitboxStuds }
	for _, index in FieldService.query(hitbox) do
		local cell = FieldService.cell(index)
		local places = if cell then Bag.placesOf(cell.zone) else 1
		local result = nil
		if Bag.canFit(state.bag, places) then
			result = FieldService.damage(index, HarvestService.cutPowerOf(player, tier), slot)
		else
			state.blockedPlaces = places -- ce blé ne tient pas : le HUD explique pourquoi on ne coupe plus (A55)
		end
		if result then
			-- Pluie Dorée ×2 et hotspot ×3 (CDC §6, A11) s'appliquent à la valeur brute du blé coupé.
			Bag.add(state.bag, result.value * EventService.valueMultiplierAt(result.x, result.z), places)
			HarvestService.Harvested:Fire(player, result)
		end
	end
end

local function refresh(player: Player, state: PlayerState, humanoid: Humanoid, tier: VehicleConfig.TierDef)
	setIfChanged(player, ATTR.BAG_COUNT, state.bag.count)
	setIfChanged(player, ATTR.BAG_CAPACITY, state.bag.capacity)
	setIfChanged(player, ATTR.BAG_BLOCKED, state.blockedPlaces)
	resizeBackpack(state)
	-- À pied (sans effet en engin : PlatformStand). Sur le boulevard et les ponts, on court ×3 (A54).
	local root = humanoid.RootPart
	local isOnRoad = root ~= nil and MapGeometry.isOnRoad(root.Position.X, root.Position.Z)
	setIfChanged(player, ATTR.ON_ROAD, isOnRoad)
	humanoid.WalkSpeed = Movement.walkSpeed(tier, Bag.isFull(state.bag), isOnRoad)
end

local function harvestTick(player: Player, state: PlayerState)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local tier = tierOf(player)
	Bag.setCapacity(state.bag, capacityOf(player, tier))
	state.blockedPlaces = 0
	if TycoonService.isOnUnloadPad(player, root.Position) then
		if state.bag.count > 0 then
			local accepted = TycoonService.unload(player, state.bag)
			HarvestService.Unloaded:Fire(player, accepted)
			if accepted > 0 then
				unloadedRemote:FireClient(player, accepted)
			elseif not state.hasWarnedSiloFull then
				state.hasWarnedSiloFull = true
				notifyRemote:FireClient(player, "Silo plein ! Agrandis-le, ou monte le tapis pour le vider plus vite.")
			end
		end
	else
		state.hasWarnedSiloFull = false
		if not Bag.isFull(state.bag) then
			cutInFront(player, state, root, tier)
		end
	end
	refresh(player, state, humanoid, tier)
end

local function onPlayerAdded(player: Player)
	local state: PlayerState = {
		bag = Bag.new(tierOf(player).capacity),
		blockedPlaces = 0,
		trove = Trove.new(),
		shownStep = -1,
		hasWarnedSiloFull = false,
	}
	states[player] = state
	state.trove:Connect(player.CharacterAdded, function(character: Model)
		attachBackpack(state, character)
	end)
	if player.Character then
		task.spawn(attachBackpack, state, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	local state = states[player]
	if state then
		state.trove:Destroy()
		states[player] = nil
	end
end

local function onHeartbeat(deltaTime: number)
	elapsed += deltaTime
	if elapsed < FieldConfig.HARVEST_INTERVAL then
		return
	end
	elapsed -= FieldConfig.HARVEST_INTERVAL
	for player, state in states do
		harvestTick(player, state)
	end
end

-- « Retour Base Instantané » (A19) : le serveur vérifie lui-même le remplissage du sac et la recharge.
local function onTeleportHome(player: Player)
	local state = states[player]
	local readyAt = player:GetAttribute(ATTR.HOME_READY_AT)
	local now = Workspace:GetServerTimeNow()
	local isStuck = state ~= nil and state.blockedPlaces > 0 and state.bag.count > 0 -- plus de place pour ce blé
	if not state or (Bag.fillRatio(state.bag) < FieldConfig.RETURN_HOME.MIN_FILL and not isStuck) then
		return
	end
	if typeof(readyAt) == "number" and now < readyAt then
		return
	end
	player:SetAttribute(ATTR.HOME_READY_AT, now + FieldConfig.RETURN_HOME.COOLDOWN_SECONDS)
	PlotService.returnToBase(player)
end

function HarvestService:Init()
	Remotes.event(Remotes.TELEPORT_HOME).OnServerEvent:Connect(onTeleportHome)
	unloadedRemote = Remotes.event(Remotes.UNLOADED)
	notifyRemote = Remotes.event(Remotes.NOTIFY)
end

function HarvestService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		if not states[player] then
			onPlayerAdded(player)
		end
	end
	RunService.Heartbeat:Connect(onHeartbeat)
end

return HarvestService
