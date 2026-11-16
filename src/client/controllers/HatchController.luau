--!strict
-- Éclosion d'un œuf (CDC §7.2, A69) : l'œuf en 3D apparaît au centre de l'écran et tremble de plus en plus fort,
-- un éclair blanc, puis le Pet tourne sur lui-même devant des rayons de la couleur de sa rareté. C'est le moment
-- le plus attendu d'un jeu de Pets : il se fête. Le Secret Mythique est annoncé à tout le serveur dans le chat
-- (CDC §8, message système).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local AssetIds = require(ReplicatedStorage.Shared.config.AssetIds)
local PetConfig = require(ReplicatedStorage.Shared.config.PetConfig)
local PetVisualConfig = require(ReplicatedStorage.Shared.config.PetVisualConfig)
local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local Pets = require(ReplicatedStorage.Shared.domain.Pets)
local Remotes = require(ReplicatedStorage.Shared.net.Remotes)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)
local EggModel = require(ReplicatedStorage.Shared.util.EggModel)
local PetViewport = require(script.Parent.Parent.ui.PetViewport)

local HatchController = {}

local HATCH = UiConfig.HATCH
local FONT = (Enum.Font :: any)[UiConfig.FONT] :: Enum.Font
local EGG_SIZE = Vector3.new(
	PetVisualConfig.DISPENSER.EGG_SIZE[1],
	PetVisualConfig.DISPENSER.EGG_SIZE[2],
	PetVisualConfig.DISPENSER.EGG_SIZE[3]
)

local localPlayer = Players.LocalPlayer
local screenGui: ScreenGui
local stage: Frame
local stageScale: UIScale
local rays: Frame
local eggView: ViewportFrame
local petHolder: Frame
local title: TextLabel
local subtitle: TextLabel
local flash: Frame
local sound: Sound? = nil
local token = 0
local eggBody: Model? = nil
local petView: PetViewport.View? = nil
local startedAt = 0
local isShaking = false

local function label(position: UDim2, size: UDim2): TextLabel
	local created = Instance.new("TextLabel")
	created.AnchorPoint = Vector2.new(0.5, 0.5)
	created.Position = position
	created.Size = size
	created.BackgroundTransparency = 1
	created.Font = FONT
	created.TextScaled = true
	created.TextColor3 = Color3.new(1, 1, 1)
	created.TextStrokeTransparency = 0
	created.Visible = false
	created.Parent = stage
	return created
end

local function buildRays()
	rays = Instance.new("Frame")
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.5)
	rays.Size = UDim2.fromScale(1, 1)
	rays.BackgroundTransparency = 1
	rays.Visible = false
	rays.Parent = stage
	for k = 1, HATCH.RAYS do
		local ray = Instance.new("Frame")
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.new(0, HATCH.RAY_WIDTH, HATCH.RAY_LENGTH, 0)
		ray.Rotation = (k - 1) * 180 / HATCH.RAYS
		ray.BorderSizePixel = 0
		ray.BackgroundColor3 = Color3.new(1, 1, 1)
		-- Transparent aux deux bouts : le rayon naît derrière le Pet et s'éteint au loin.
		local fade = Instance.new("UIGradient")
		fade.Rotation = 90
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
		fade.Parent = ray
		ray.Parent = rays
	end
end

local function buildEggView()
	eggView = Instance.new("ViewportFrame")
	eggView.AnchorPoint = Vector2.new(0.5, 0.5)
	eggView.Position = UDim2.fromScale(0.5, 0.5)
	eggView.Size = UDim2.fromScale(0.8, 0.8)
	eggView.BackgroundTransparency = 1
	eggView.Ambient = Color3.fromRGB(210, 210, 210)
	eggView.LightDirection = Vector3.new(-1, -1.2, 1)
	eggView.Visible = false
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 1.5, -EGG_SIZE.Y * 2.4), Vector3.zero)
	camera.Parent = eggView
	eggView.CurrentCamera = camera
	eggView.Parent = stage
end

local function clearModels()
	if eggBody then
		eggBody:Destroy()
		eggBody = nil
	end
	if petView then
		petView.frame:Destroy()
		petView = nil
	end
end

local function hide()
	isShaking = false
	clearModels()
	eggView.Visible, rays.Visible, title.Visible, subtitle.Visible = false, false, false, false
	stage.Visible = false
end

local function colorRays(color: Color3)
	for _, ray in rays:GetChildren() do
		if ray:IsA("Frame") then
			ray.BackgroundColor3 = color
		end
	end
end

local function playSound(pitch: number)
	if sound then
		sound.PlaybackSpeed = pitch
		sound:Play()
	end
end

local function pop(scaleFrom: number, seconds: number)
	stageScale.Scale = scaleFrom
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(stageScale, info, { Scale = 1 }):Play()
end

local function rarityRank(key: string): number
	local rarity = Pets.rarityOf(key)
	for index, candidate in PetConfig.RARITIES do
		if candidate.id == rarity.id then
			return index
		end
	end
	return 1
end

local function describe(key: string): (string, string)
	local species, variant = Pets.parse(key)
	local variantName = if variant and variant.name ~= "" then ` {variant.name}` else ""
	return `{Pets.rarityOf(key).name} !`, `{if species then species.name else "Pet"}{variantName}`
end

local function reveal(key: string)
	isShaking = false
	clearModels()
	eggView.Visible = false
	local color = Bricks.rgb(Pets.rarityOf(key).color)
	flash.BackgroundTransparency = 0.1
	TweenService:Create(flash, TweenInfo.new(HATCH.FLASH_SECONDS), { BackgroundTransparency = 1 }):Play()
	colorRays(color)
	rays.Visible = true
	local view = PetViewport.new(petHolder, key)
	if view then
		view.frame.Size = UDim2.fromScale(1, 1)
	end
	petView = view
	local rarityText, nameText = describe(key)
	title.Text = rarityText
	title.TextColor3 = color
	subtitle.Text = `{nameText} · bonus ×{Pets.bonusOf(key)}`
	title.Visible, subtitle.Visible = true, true
	pop(HATCH.REVEAL_POP, HATCH.POP_SECONDS)
	playSound(0.8 + 0.15 * rarityRank(key)) -- plus le Pet est rare, plus la note monte
end

local function play(eggId: string, key: string)
	token += 1
	local current = token
	hide()
	local eggDef = Pets.egg(eggId)
	local body = EggModel.build(eggId, if eggDef then eggDef.color else { 248, 248, 248 }, EGG_SIZE, CFrame.identity)
	body.Parent = eggView
	eggBody = body
	stage.Visible, eggView.Visible = true, true
	startedAt = os.clock()
	isShaking = true
	pop(HATCH.EGG_POP, HATCH.POP_SECONDS)
	playSound(0.7)
	task.delay(HATCH.SHAKE_SECONDS, function()
		if token ~= current then
			return
		end
		reveal(key)
		task.delay(HATCH.REVEAL_SECONDS, function()
			if token == current then
				hide()
			end
		end)
	end)
end

-- L'œuf se balance de plus en plus fort ; les rayons et le Pet tournent pendant la révélation.
local function onRenderStepped(deltaTime: number)
	if not stage.Visible then
		return
	end
	local body = eggBody
	if isShaking and body then
		local elapsed = os.clock() - startedAt
		local progress = math.clamp(elapsed / HATCH.SHAKE_SECONDS, 0, 1)
		local swing = math.sin(elapsed * HATCH.SHAKE_SPEED) * math.rad(HATCH.SHAKE_DEGREES) * (0.25 + progress)
		body:PivotTo(CFrame.new(0, math.abs(swing) * 0.6, 0) * CFrame.Angles(0, elapsed * 1.5, swing))
	end
	if rays.Visible then
		rays.Rotation = (rays.Rotation + deltaTime * HATCH.RAY_SPIN) % 360
	end
	local view = petView
	if view then
		PetViewport.turn(view, os.clock() * HATCH.PET_SPIN)
	end
end

local function announce(displayName: string, key: string)
	local rarityText, nameText = describe(key)
	local channels = TextChatService:FindFirstChild("TextChannels")
	local general = channels and channels:FindFirstChild("RBXGeneral")
	if general and general:IsA("TextChannel") then
		pcall(general.DisplaySystemMessage, general, `🌈 {displayName} a obtenu un {rarityText} {nameText}`)
	end
end

local function centered(parent: Instance, scale: number): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(scale, scale)
	frame.BackgroundTransparency = 1
	frame.Parent = parent
	return frame
end

function HatchController:Init()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Hatch"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = HATCH.DISPLAY_ORDER
	flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = screenGui
	stage = Instance.new("Frame")
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.Position = UDim2.fromScale(0.5, HATCH.STAGE_Y)
	stage.Size = UDim2.fromOffset(HATCH.STAGE_SIZE, HATCH.STAGE_SIZE)
	stage.BackgroundTransparency = 1
	stage.Visible = false
	stage.Parent = screenGui
	stageScale = Instance.new("UIScale")
	stageScale.Parent = stage
	buildRays()
	buildEggView()
	petHolder = centered(stage, 0.75)
	title = label(UDim2.fromScale(0.5, -0.02), UDim2.fromOffset(HATCH.REVEAL_WIDTH, HATCH.REVEAL_HEIGHT))
	subtitle = label(UDim2.fromScale(0.5, 1.02), UDim2.fromOffset(HATCH.REVEAL_WIDTH, HATCH.REVEAL_HEIGHT * 0.7))
end

function HatchController:Start()
	if AssetIds.REWARD_SOUND ~= "" then
		local created = Instance.new("Sound")
		created.Name = "HatchSound"
		created.SoundId = AssetIds.REWARD_SOUND
		created.Volume = 0.8
		created.Parent = SoundService
		sound = created
	end
	Remotes.event(Remotes.HATCH_RESULT).OnClientEvent:Connect(play)
	Remotes.event(Remotes.PET_ANNOUNCE).OnClientEvent:Connect(announce)
	RunService.RenderStepped:Connect(onRenderStepped)
	screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
end

return HatchController
