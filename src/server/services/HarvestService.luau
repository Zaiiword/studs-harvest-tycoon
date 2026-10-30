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
local Trove = require(ReplicatedStorage.Packages.Trove)
local FieldService = require(script.Parent.FieldService)
local PlotService = require(script.Parent.PlotService)
local TycoonService = require(script.Parent.TycoonService)
local EventService = require(script.Parent.EventService)

local HarvestService = {}

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
		local result = FieldService.damage(index, tier.cutPower, slot)
		if result then
			-- Pluie Dorée ×2 et hotspot ×3 (CDC §6, A11) s'appliquent à la valeur brute du blé coupé.
			Bag.add(state.bag, result.value * EventService.valueMultiplierAt(result.x, result.z))
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
			TycoonService.unload(player, state.bag)
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
