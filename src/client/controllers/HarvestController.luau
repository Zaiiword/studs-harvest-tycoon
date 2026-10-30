--!strict
-- Game feel de la récolte (CDC §2, §4) : prédit les coupes du joueur local pour un retour immédiat,
-- fait voler 3 à 5 briques jaunes en arc jusqu'au récolteur et joue le « Pop » dont la tonalité monte.
-- Les briques viennent d'un pool et sont déplacées en un seul BulkMoveTo par image (docs/CLEAN_CODE.md §5).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local AssetIds = require(ReplicatedStorage.Shared.config.AssetIds)
local FieldConfig = require(ReplicatedStorage.Shared.config.FieldConfig)
local MapConfig = require(ReplicatedStorage.Shared.config.MapConfig)
local PlantConfig = require(ReplicatedStorage.Shared.config.PlantConfig)
local VehicleConfig = require(ReplicatedStorage.Shared.config.VehicleConfig)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)
local FieldController = require(script.Parent.FieldController)

local HarvestController = {}

type Flight = {
	part: Part,
	from: Vector3,
	target: BasePart,
	startedAt: number,
}

local PARKED = CFrame.new(0, -1000, 0) -- hors de vue, sous la carte
local SPAWN_JITTER = MapConfig.CELL_SIZE / 3 -- les briques partent de tout le brin, pas d'un seul point

local localPlayer = Players.LocalPlayer
local random = Random.new()
local freeBricks: { Part } = {}
local flights: { Flight } = {}
local popSound: Sound? = nil
local popPitch = 1
local lastPopAt = -math.huge
local predictElapsed = 0

local function rootOf(player: Player?): BasePart?
	local character = player and player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function playerInSlot(slot: number): Player?
	for _, player in Players:GetPlayers() do
		if player:GetAttribute(PlayerAttributes.BASE_INDEX) == slot then
			return player
		end
	end
	return nil
end

local function launchBricks(x: number, z: number, target: BasePart)
	local now = os.clock()
	for _ = 1, random:NextInteger(FieldConfig.BRICKS_PER_CUT_MIN, FieldConfig.BRICKS_PER_CUT_MAX) do
		local part = table.remove(freeBricks)
		if not part then
			return -- pool épuisé : on sacrifie l'effet plutôt que d'instancier en boucle chaude
		end
		local jitterX = random:NextNumber(-SPAWN_JITTER, SPAWN_JITTER)
		local jitterZ = random:NextNumber(-SPAWN_JITTER, SPAWN_JITTER)
		local from = Vector3.new(x + jitterX, MapConfig.FLOOR_TOP + PlantConfig.EAR_HEIGHT, z + jitterZ)
		table.insert(flights, { part = part, from = from, target = target, startedAt = now })
	end
end

-- Courbe de Bézier quadratique dont le point de contrôle est surélevé : l'« arc magnétique » du CDC §2.
local function arcPoint(from: Vector3, to: Vector3, t: number): Vector3
	local control = (from + to) / 2 + Vector3.new(0, FieldConfig.BRICK_ARC_HEIGHT, 0)
	return from:Lerp(control, t):Lerp(control:Lerp(to, t), t)
end

local function animateFlights(now: number)
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	for k = #flights, 1, -1 do
		local flight = flights[k]
		local t = (now - flight.startedAt) / FieldConfig.BRICK_FLIGHT_SECONDS
		local isDone = t >= 1 or not flight.target.Parent
		table.insert(parts, flight.part)
		table.insert(cframes, if isDone then PARKED else CFrame.new(arcPoint(flight.from, flight.target.Position, t)))
		if isDone then
			table.insert(freeBricks, flight.part)
			table.remove(flights, k)
		end
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

local function playPop()
	if not popSound then
		return
	end
	local now = os.clock()
	local isCombo = now - lastPopAt < FieldConfig.POP_COMBO_RESET_SECONDS
	popPitch = if isCombo then math.min(FieldConfig.POP_PITCH_MAX, popPitch + FieldConfig.POP_PITCH_STEP) else 1
	lastPopAt = now
	popSound.PlaybackSpeed = popPitch
	SoundService:PlayLocalSound(popSound)
end

local function onCellCut(_index: number, slot: number, x: number, z: number, wasPredicted: boolean)
	if wasPredicted then
		return -- les briques sont déjà parties au moment de la prédiction
	end
	local harvester = playerInSlot(slot)
	local target = rootOf(harvester)
	if target then
		launchBricks(x, z, target)
		if harvester == localPlayer then
			playPop()
		end
	end
end

local function numberAttribute(name: string, default: number): number
	local value = localPlayer:GetAttribute(name)
	return if typeof(value) == "number" then value else default
end

-- Prédiction : seuls les brins que l'outil abat d'un coup sont masqués d'avance (décision A26).
local function predictCuts()
	local root = rootOf(localPlayer)
	local capacity = numberAttribute(PlayerAttributes.BAG_CAPACITY, 0)
	local room = capacity - numberAttribute(PlayerAttributes.BAG_COUNT, 0) - FieldController.predictedCount()
	if not root or room <= 0 then
		return
	end
	local tier = VehicleConfig.TIERS[numberAttribute(PlayerAttributes.TIER, 1)] or VehicleConfig.TIERS[1]
	local look, grid = root.CFrame.LookVector, FieldController.grid()
	local hitbox = { x = root.Position.X, z = root.Position.Z, dirX = look.X, dirZ = look.Z, size = tier.hitboxStuds }
	for _, index in grid:queryHitbox(hitbox) do
		local cell = grid:cell(index)
		if room <= 0 then
			return
		end
		local cutPower = tier.cutPower * numberAttribute(PlayerAttributes.CUT_POWER_MULTIPLIER, 1) -- Pets (A2)
		if cell and cell.hp <= cutPower and FieldController.predictCut(index) then
			room -= 1
			launchBricks(cell.x, cell.z, root)
			playPop()
		end
	end
end

local function onHeartbeat(deltaTime: number)
	animateFlights(os.clock())
	predictElapsed += deltaTime
	if predictElapsed >= FieldConfig.HARVEST_INTERVAL then
		predictElapsed = 0
		predictCuts()
	end
end

function HarvestController:Init()
	local folder = Instance.new("Folder")
	folder.Name = "FlyingBricks"
	local size = Vector3.one * FieldConfig.BRICK_SIZE
	for k = 1, FieldConfig.BRICK_POOL_SIZE do
		local part = Bricks.decor(`Brick{k}`, size, FieldConfig.BRICK_COLOR)
		part.CFrame = PARKED
		part.Parent = folder
		table.insert(freeBricks, part)
	end
	folder.Parent = Workspace
	if AssetIds.HARVEST_POP_SOUND ~= "" then
		local sound = Instance.new("Sound")
		sound.SoundId = AssetIds.HARVEST_POP_SOUND
		sound.Parent = SoundService
		popSound = sound
	end
end

function HarvestController:Start()
	FieldController.CellCut:Connect(onCellCut)
	RunService.Heartbeat:Connect(onHeartbeat)
end

return HarvestController
