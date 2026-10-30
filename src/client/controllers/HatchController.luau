--!strict
-- Éclosion d'un œuf (CDC §7.2) : l'œuf tremble au centre de l'écran puis révèle le Pet, aux couleurs de sa
-- rareté. Le Secret Mythique est annoncé à tout le serveur dans le chat (CDC §8, message système).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local PetConfig = require(ReplicatedStorage.Shared.config.PetConfig)
local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local Pets = require(ReplicatedStorage.Shared.domain.Pets)
local Remotes = require(ReplicatedStorage.Shared.net.Remotes)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)

local HatchController = {}

local HATCH = UiConfig.HATCH
local FONT = (Enum.Font :: any)[UiConfig.FONT] :: Enum.Font

local localPlayer = Players.LocalPlayer
local screenGui: ScreenGui
local egg: TextLabel
local reveal: TextLabel
local token = 0

local function newLabel(size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.45)
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.TextScaled = true
	label.TextStrokeTransparency = 0
	label.Visible = false
	label.Parent = screenGui
	return label
end

local function describe(key: string): string
	local species, variant = Pets.parse(key)
	local rarity = Pets.rarityOf(key)
	local variantName = if variant and variant.name ~= "" then ` {variant.name}` else ""
	return `{rarity.name} ! {(species :: PetConfig.SpeciesDef).name}{variantName} · bonus ×{Pets.bonusOf(key)}`
end

local function play(eggId: string, key: string)
	token += 1
	local current = token
	local eggDef = Pets.egg(eggId)
	egg.Text = "🥚"
	egg.TextColor3 = if eggDef then Bricks.rgb(eggDef.color) else Color3.new(1, 1, 1)
	egg.Rotation = 0
	egg.Visible, reveal.Visible = true, false
	local shake = TweenService:Create(
		egg,
		TweenInfo.new(HATCH.SHAKE_SECONDS / 6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 5, true),
		{ Rotation = HATCH.SHAKE_DEGREES }
	)
	shake:Play()
	task.delay(HATCH.SHAKE_SECONDS, function()
		if token ~= current then
			return
		end
		egg.Visible = false
		reveal.Text = describe(key)
		reveal.TextColor3 = Bricks.rgb(Pets.rarityOf(key).color)
		reveal.Visible = true
		task.delay(HATCH.REVEAL_SECONDS, function()
			if token == current then
				reveal.Visible = false
			end
		end)
	end)
end

local function announce(displayName: string, key: string)
	local channels = TextChatService:FindFirstChild("TextChannels")
	local general = channels and channels:FindFirstChild("RBXGeneral")
	if general and general:IsA("TextChannel") then
		pcall(general.DisplaySystemMessage, general, `🌈 {displayName} a obtenu un {describe(key)}`)
	end
end

function HatchController:Init()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Hatch"
	screenGui.ResetOnSpawn = false
	egg = newLabel(UDim2.fromOffset(HATCH.EGG_SIZE, HATCH.EGG_SIZE))
	reveal = newLabel(UDim2.fromOffset(HATCH.REVEAL_WIDTH, HATCH.REVEAL_HEIGHT))
end

function HatchController:Start()
	Remotes.event(Remotes.HATCH_RESULT).OnClientEvent:Connect(play)
	Remotes.event(Remotes.PET_ANNOUNCE).OnClientEvent:Connect(announce)
	screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
end

return HatchController
