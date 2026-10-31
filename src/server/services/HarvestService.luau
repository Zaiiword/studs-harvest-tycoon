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
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
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
	trove: any,
	backpack: Part?,
	weld: Weld?,
	shownStep: number,
}

local BACKPACK = FieldConfig.BACKPACK
local ATTR = PlayerAttributes

local states: { [Player]: PlayerState } = {}
local elapsed = 0

local function tierOf(player: Player): VehicleConfig.TierDef
	local id = player:GetAttribute(ATTR.TIER)
	return VehicleConfig.TIERS[if typeof(id) == "number" then id else 1] or VehicleConfig.TIERS[1]
end

-- Puissance de coupe : celle de l'outil × facteur des Pets équipés (A2, publié par PetService).
function HarvestService.cutPowerOf(player: Player, tier: VehicleConfig.TierDef): number
	local multiplier = player:GetAttribute(ATTR.CUT_POWER_MULTIPLIER)
	return tier.cutPower * (if typeof(multiplier) == "number" and multiplier >= 1 then multiplier else 1)
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
		if Bag.isFull(state.bag) then
			return
		end
		local result = FieldService.damage(index, HarvestService.cutPowerOf(player, tier), slot)
		if result then
			-- Pluie Dorée ×2 et hotspot ×3 (CDC §6, A11) s'appliquent à la valeur brute du blé coupé.
			Bag.add(state.bag, result.value * EventService.valueMultiplierAt(result.x, result.z))
			HarvestService.Harvested:Fire(player, result)
		end
	end
end

local function refresh(player: Player, state: PlayerState, humanoid: Humanoid, tier: VehicleConfig.TierDef)
	setIfChanged(player, ATTR.BAG_COUNT, state.bag.count)
	setIfChanged(player, ATTR.BAG_CAPACITY, state.bag.capacity)
	resizeBackpack(state)
	if not tier.isVehicle then -- la vitesse des véhicules sera gérée par VehicleService (Sprint 2)
		local penalty = if Bag.isFull(state.bag) then VehicleConfig.FULL_SPEED_PENALTY else 0
		humanoid.WalkSpeed = tier.speed * (1 - penalty)
	end
end

local function harvestTick(player: Player, state: PlayerState)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local tier = tierOf(player)
	Bag.setCapacity(state.bag, tier.capacity)
	if TycoonService.isOnUnloadPad(player, root.Position) then
		if state.bag.count > 0 then
			HarvestService.Unloaded:Fire(player, TycoonService.unload(player, state.bag))
		end
	elseif not Bag.isFull(state.bag) then
		cutInFront(player, state, root, tier)
	end
	refresh(player, state, humanoid, tier)
end

local function onPlayerAdded(player: Player)
	local state: PlayerState = {
		bag = Bag.new(tierOf(player).capacity),
		trove = Trove.new(),
		shownStep = -1,
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
	if not state or Bag.fillRatio(state.bag) < FieldConfig.RETURN_HOME.MIN_FILL then
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
