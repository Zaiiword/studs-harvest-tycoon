--!strict
-- Pop-up « GAGNÉ ! » (CDC §7.4, §10) : carte dorée qui surgit en rebondissant devant un halo de rayons qui
-- tournent, pluie de confettis, grosse icône du lot et son de récompense. Se ferme d'un clic ou toute seule.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local AssetIds = require(ReplicatedStorage.Shared.config.AssetIds)
local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)
local Style = require(script.Parent.Style)

local RewardPopup = {}

local POPUP = UiConfig.REWARD_POPUP
local SHOP = UiConfig.SHOP
local POP = TweenInfo.new(POPUP.POP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local HIDE = TweenInfo.new(POPUP.HIDE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local FALL = TweenInfo.new(POPUP.CONFETTI_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FULL_TURN = 360
local CONFETTI_LIFT = 0.6 -- les confettis partent surtout vers le haut, puis retombent
local ICON_BOB = { height = 6, speed = 4 }

local gui: ScreenGui? = nil
local sound: Sound? = nil
local token = 0

local function screen(): ScreenGui
	if gui then
		return gui
	end
	local created = Instance.new("ScreenGui")
	created.Name = "RewardPopup"
	created.ResetOnSpawn = false
	created.IgnoreGuiInset = true
	created.DisplayOrder = POPUP.DISPLAY_ORDER
	created.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	created.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	if AssetIds.REWARD_SOUND ~= "" then
		local reward = Instance.new("Sound")
		reward.SoundId = AssetIds.REWARD_SOUND
		reward.Parent = SoundService -- hors de la pop-up, qui est vidée à chaque affichage
		sound = reward
	end
	gui = created
	return created
end

-- Halo de rayons : chaque rayon est posé sur un bras de la taille du halo, qui tourne autour du centre.
local function buildRays(parent: Instance): Frame
	local halo = Instance.new("Frame")
	halo.AnchorPoint = Vector2.new(0.5, 0.5)
	halo.Position = UDim2.fromScale(0.5, 0.5)
	local diameter = POPUP.HEIGHT * POPUP.HALO_SCALE
	halo.Size = UDim2.fromOffset(diameter, diameter)
	halo.BackgroundTransparency = 1
	halo.Parent = parent
	for index = 1, POPUP.RAYS do
		local arm = Instance.new("Frame")
		arm.BackgroundTransparency = 1
		arm.Size = UDim2.fromScale(1, 1)
		arm.Rotation = (index - 1) * FULL_TURN / POPUP.RAYS
		arm.Parent = halo
		local ray = Instance.new("Frame")
		ray.AnchorPoint = Vector2.new(0.5, 0)
		ray.Position = UDim2.fromScale(0.5, 0)
		ray.Size = UDim2.fromScale(POPUP.RAY_WIDTH, 0.5)
		ray.BorderSizePixel = 0
		ray.BackgroundColor3 = Bricks.rgb(POPUP.RAY_COLOR)
		local fade = Instance.new("UIGradient")
		fade.Rotation = 90
		fade.Transparency = NumberSequence.new(1, POPUP.RAY_TRANSPARENCY) -- s'efface vers l'extérieur
		fade.Parent = ray
		ray.Parent = arm
	end
	return halo
end

local function burstConfetti(parent: Instance)
	for index = 1, POPUP.CONFETTI do
		local color = POPUP.CONFETTI_COLORS[(index % #POPUP.CONFETTI_COLORS) + 1]
		local bit = Instance.new("Frame")
		bit.AnchorPoint = Vector2.new(0.5, 0.5)
		bit.Position = UDim2.fromScale(0.5, 0.35)
		bit.Size = UDim2.fromOffset(POPUP.CONFETTI_SIZE, POPUP.CONFETTI_SIZE * 0.6)
		bit.BackgroundColor3 = Bricks.rgb(color)
		bit.BorderSizePixel = 0
		bit.ZIndex = 20
		bit.Parent = parent
		local angle = math.random() * 2 * math.pi
		local distance = POPUP.CONFETTI_SPREAD * (0.5 + math.random() / 2)
		local target = UDim2.new(
			0.5,
			math.cos(angle) * distance,
			0.35,
			-math.abs(math.sin(angle)) * distance * CONFETTI_LIFT + distance / 2
		)
		local fall = TweenService:Create(bit, FALL, {
			Position = target,
			Rotation = (math.random() - 0.5) * 2 * FULL_TURN,
			BackgroundTransparency = 1,
		})
		fall.Completed:Once(function()
			bit:Destroy()
		end)
		fall:Play()
	end
end

local function buildCard(parent: Instance, icon: string, text: string): (Frame, TextLabel, TextButton)
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(POPUP.WIDTH, POPUP.HEIGHT)
	card.ZIndex = 10
	Style.corner(card, UDim.new(0, UiConfig.WINDOW.CORNER))
	Style.gradient(card, POPUP.TOP, POPUP.BOTTOM)
	Style.stroke(card, UiConfig.WINDOW.STROKE_COLOR, UiConfig.WINDOW.STROKE)
	Style.shine(card)
	card.Parent = parent
	local title = Style.label(card, "🎉 GAGNÉ ! 🎉", UDim2.new(1, -20, 0.18, 0))
	title.Position = UDim2.new(0, 10, 0.04, 0)
	local iconLabel = Style.label(card, icon, UDim2.fromScale(1, 0.34))
	iconLabel.Position = UDim2.fromScale(0, 0.22)
	local reward = Style.label(card, text, UDim2.new(1, -24, 0.16, 0))
	reward.Position = UDim2.new(0, 12, 0.57, 0)
	local close = Style.button(card, { top = SHOP.BUY_TOP, bottom = SHOP.BUY_BOTTOM, edge = SHOP.BUY_STROKE })
	close.AnchorPoint = Vector2.new(0.5, 1)
	close.Position = UDim2.new(0.5, 0, 1, -14)
	close.Size = UDim2.new(0.6, 0, 0.17, 0)
	Style.shine(close)
	Style.label(close, "SUPER !", UDim2.new(1, -12, 1, -10)).Position = UDim2.fromOffset(6, 5)
	return card, iconLabel, close
end

-- Montre le lot gagné ; un nouvel appel remplace la pop-up en cours.
function RewardPopup.show(icon: string, text: string)
	token += 1
	local myToken = token
	local root = screen()
	root:ClearAllChildren()
	if sound then
		SoundService:PlayLocalSound(sound)
	end
	local stage = Instance.new("Frame")
	stage.BackgroundTransparency = 1
	stage.Size = UDim2.fromScale(1, 1)
	stage.Parent = root
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = stage
	local halo = buildRays(stage)
	local _, iconLabel, close = buildCard(stage, icon, text)
	burstConfetti(stage)
	TweenService:Create(scale, POP, { Scale = 1 }):Play()
	local clock = 0
	local spin = RunService.RenderStepped:Connect(function(deltaTime: number)
		clock += deltaTime
		halo.Rotation = (halo.Rotation + POPUP.RAY_SPEED * deltaTime) % FULL_TURN
		iconLabel.Position = UDim2.new(0, 0, 0.22, math.sin(clock * ICON_BOB.speed) * ICON_BOB.height)
	end)
	local function hide()
		if myToken ~= token or not stage.Parent then -- déjà remplacée par une autre pop-up
			return
		end
		local shrink = TweenService:Create(scale, HIDE, { Scale = 0 })
		shrink.Completed:Once(function()
			spin:Disconnect()
			stage:Destroy()
		end)
		shrink:Play()
	end
	stage.Destroying:Once(function()
		spin:Disconnect()
	end)
	close.Activated:Connect(hide)
	task.delay(POPUP.SHOW_SECONDS, hide)
end

return RewardPopup
