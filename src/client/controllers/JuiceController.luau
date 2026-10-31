--!strict
-- Game feel (CDC §2) : textes flottants colorés à chaque coupe du joueur local (+25 🌾, CRITIQUE ×10 !),
-- tremblement de caméra proportionnel à la taille de l'outil, secousse et son à l'éjection, son de
-- récompense. Purement visuel et local.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AssetIds = require(ReplicatedStorage.Shared.config.AssetIds)
local FieldConfig = require(ReplicatedStorage.Shared.config.FieldConfig)
local MapConfig = require(ReplicatedStorage.Shared.config.MapConfig)
local PlantConfig = require(ReplicatedStorage.Shared.config.PlantConfig)
local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local VehicleConfig = require(ReplicatedStorage.Shared.config.VehicleConfig)
local Rarity = require(ReplicatedStorage.Shared.domain.Rarity)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local Remotes = require(ReplicatedStorage.Shared.net.Remotes)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)
local FieldController = require(script.Parent.FieldController)

local JuiceController = {}

type Floater = { anchor: Part, label: TextLabel }

local JUICE = UiConfig.JUICE
local PARKED = CFrame.new(0, -1000, 0)

local localPlayer = Players.LocalPlayer
local floaters: { Floater } = {}
local nextFloater = 1
local trauma = 0
local lastDizzyUntil = 0
local sounds: { [string]: Sound } = {}

local function newFloater(parent: Instance): Floater
	local anchor = Bricks.decor("Floater", Vector3.one * 0.2, { 255, 255, 255 })
	anchor.Transparency = 1
	anchor.CFrame = PARKED
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 40)
	gui.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = (Enum.Font :: any)[UiConfig.FONT]
	label.TextScaled = true
	label.TextStrokeTransparency = 0
	label.Parent = gui
	gui.Parent = anchor
	anchor.Parent = parent
	return { anchor = anchor, label = label }
end

-- Affiche un texte qui monte et s'efface au-dessus de (x, z). Pool circulaire : jamais d'Instance.new en jeu.
local function float(x: number, z: number, text: string, color: { number })
	local floater = floaters[nextFloater]
	nextFloater = nextFloater % #floaters + 1
	local start = CFrame.new(x, MapConfig.FLOOR_TOP + PlantConfig.EAR_HEIGHT + 1, z)
	floater.anchor.CFrame = start
	floater.label.Text = text
	floater.label.TextColor3 = Bricks.rgb(color)
	floater.label.TextTransparency, floater.label.TextStrokeTransparency = 0, 0
	local info = TweenInfo.new(JUICE.FLOAT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(floater.anchor, info, { CFrame = start + Vector3.new(0, JUICE.FLOAT_RISE, 0) }):Play()
	TweenService:Create(floater.label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
end

local function play(name: string)
	local sound = sounds[name]
	if sound then
		SoundService:PlayLocalSound(sound)
	end
end

local function cutText(index: number): (string, { number })
	local cell = FieldController.grid():cell(index)
	if not cell then
		return "+🌾", { 255, 255, 255 }
	end
	local rarity = Rarity.byId(cell.rarity)
	local value = FieldConfig.WHEAT_ZONES[cell.zone].value * rarity.valueMultiplier
	if cell.rarity == Rarity.RAINBOW then
		return `ARC-EN-CIEL ×{rarity.valueMultiplier} !!`, JUICE.RAINBOW_COLOR
	elseif cell.rarity == Rarity.GIANT then
		return `CRITIQUE ×{rarity.valueMultiplier} !`, JUICE.CRITICAL_COLOR
	end
	return `+{value} 🌾`, { 255, 255, 255 }
end

local function onCellCut(index: number, slot: number, x: number, z: number)
	if slot ~= localPlayer:GetAttribute(PlayerAttributes.BASE_INDEX) then
		return
	end
	local text, color = cutText(index)
	float(x, z, text, color)
	local tierId = localPlayer:GetAttribute(PlayerAttributes.TIER)
	local tier = VehicleConfig.TIERS[if typeof(tierId) == "number" then tierId else 1] or VehicleConfig.TIERS[1]
	trauma = math.min(1, trauma + JUICE.SHAKE_PER_CUT * tier.hitboxStuds / JUICE.BIGGEST_HITBOX)
end

-- Éjection du joueur local : forte secousse et « swoosh ».
local function onDizzyChanged()
	local dizzyUntil = localPlayer:GetAttribute(PlayerAttributes.DIZZY_UNTIL)
	if typeof(dizzyUntil) == "number" and dizzyUntil > lastDizzyUntil then
		lastDizzyUntil = dizzyUntil
		trauma = math.min(1, trauma + JUICE.SHAKE_ON_EJECT)
		play("eject")
	end
end

-- Tremblement « trauma² » : fort au début, il s'amortit vite (appliqué après la caméra par défaut).
local function shakeCamera(deltaTime: number)
	if trauma <= 0 then
		return
	end
	local camera = Workspace.CurrentCamera
	local strength = trauma * trauma * JUICE.SHAKE_MAX_ANGLE
	local t = os.clock() * 40
	camera.CFrame *= CFrame.Angles(
		math.noise(t, 1) * strength,
		math.noise(t, 2) * strength,
		math.noise(t, 3) * strength
	)
	trauma = math.max(0, trauma - JUICE.SHAKE_DECAY * deltaTime)
end

local function loadSound(name: string, id: string)
	if id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Parent = SoundService
	sounds[name] = sound
end

function JuiceController:Init()
	local folder = Instance.new("Folder")
	folder.Name = "Floaters"
	for _ = 1, JUICE.FLOAT_POOL do
		table.insert(floaters, newFloater(folder))
	end
	folder.Parent = Workspace
	loadSound("eject", AssetIds.EJECT_SOUND)
	loadSound("reward", AssetIds.REWARD_SOUND)
end

function JuiceController:Start()
	FieldController.CellCut:Connect(onCellCut)
	localPlayer:GetAttributeChangedSignal(PlayerAttributes.DIZZY_UNTIL):Connect(onDizzyChanged)
	Remotes.event(Remotes.NOTIFY).OnClientEvent:Connect(function()
		play("reward")
	end)
	RunService:BindToRenderStep("JuiceShake", Enum.RenderPriority.Camera.Value + 1, shakeCamera)
end

return JuiceController
