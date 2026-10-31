--!strict
-- Jauge du sac en bas au centre (CDC §4, §10, charte « Studs Pop ») : pulse en rouge dès 90 % et propose
-- alors le bouton « Retour Base Instantané » (A19), vérifié par le serveur.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)
local Remotes = require(ReplicatedStorage.Shared.net.Remotes)
local Workspace = game:GetService("Workspace")

local BagHudController = {}

local BAR = UiConfig.BAG_BAR
local FONT = (Enum.Font :: any)[UiConfig.FONT] :: Enum.Font

local localPlayer = Players.LocalPlayer
local fill: Frame
local label: TextLabel
local isAlerting = false
local screenGui: ScreenGui
local homeButton: TextButton

local function decorate(frame: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, UiConfig.CORNER_RADIUS)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = UiConfig.STROKE_THICKNESS
	stroke.Color = Bricks.rgb(UiConfig.STROKE_COLOR)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
end

local function newLabel(parent: Instance): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = FONT
	text.TextScaled = true
	text.TextColor3 = Bricks.rgb(BAR.TEXT)
	text.ZIndex = 2
	text.Parent = parent
	return text
end

local function buildBar(gui: ScreenGui)
	local bar = Instance.new("Frame")
	bar.Name = "BagBar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -BAR.BOTTOM_MARGIN)
	bar.Size = UDim2.fromOffset(BAR.WIDTH, BAR.HEIGHT)
	bar.BackgroundColor3 = Bricks.rgb(BAR.BACKGROUND)
	decorate(bar)
	bar.Parent = gui
	fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Bricks.rgb(BAR.FILL)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, UiConfig.CORNER_RADIUS)
	corner.Parent = fill
	fill.Parent = bar
	label = newLabel(bar)
end

local function numberAttribute(name: string): number
	local value = localPlayer:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function refresh()
	local count = numberAttribute(PlayerAttributes.BAG_COUNT)
	local capacity = numberAttribute(PlayerAttributes.BAG_CAPACITY)
	local ratio = if capacity > 0 and capacity ~= math.huge then math.min(1, count / capacity) else 0
	fill.Size = UDim2.fromScale(ratio, 1)
	isAlerting = ratio >= BAR.ALERT_RATIO
	label.Text = if ratio >= 1 then "PLEIN !" else `{count} / {capacity} 🌾`
	if not isAlerting then
		fill.BackgroundColor3 = Bricks.rgb(BAR.FILL)
	end
end

-- Le bouton « Retour Base Instantané » n'apparaît qu'à 90 % et hors recharge (CDC §10, A19).
local function refreshHomeButton()
	local isReady = Workspace:GetServerTimeNow() >= numberAttribute(PlayerAttributes.HOME_READY_AT)
	homeButton.Visible = isAlerting and isReady
end

local function pulse()
	refreshHomeButton()
	if not isAlerting then
		return
	end
	local alpha = (math.sin(os.clock() * BAR.PULSE_SPEED) + 1) / 2
	fill.BackgroundColor3 = Bricks.rgb(BAR.FILL):Lerp(Bricks.rgb(BAR.ALERT), alpha)
end

local function buildHomeButton(gui: ScreenGui)
	homeButton = Instance.new("TextButton")
	homeButton.Name = "ReturnHome"
	homeButton.AnchorPoint = Vector2.new(0.5, 1)
	homeButton.Position = UDim2.new(0.5, 0, 1, -(BAR.BOTTOM_MARGIN + BAR.HEIGHT + 12))
	homeButton.Size = UDim2.fromOffset(BAR.WIDTH, BAR.HEIGHT * 1.4)
	homeButton.BackgroundColor3 = Bricks.rgb(BAR.ALERT)
	homeButton.TextColor3 = Bricks.rgb(BAR.TEXT)
	homeButton.Font = FONT
	homeButton.TextScaled = true
	homeButton.Text = "🏠 Retour Base Instantané"
	homeButton.Visible = false
	decorate(homeButton)
	homeButton.Activated:Connect(function()
		Remotes.event(Remotes.TELEPORT_HOME):FireServer()
	end)
	homeButton.Parent = gui
end

function BagHudController:Init()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "HarvestHud"
	screenGui.ResetOnSpawn = false
	buildBar(screenGui)
	buildHomeButton(screenGui)
end

function BagHudController:Start()
	screenGui.Parent = localPlayer:WaitForChild("PlayerGui") -- attente autorisée dans Start, pas dans Init
	for _, name in { PlayerAttributes.BAG_COUNT, PlayerAttributes.BAG_CAPACITY } do
		localPlayer:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()
	RunService.RenderStepped:Connect(pulse)
end

return BagHudController
