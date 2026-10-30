--!strict
-- Jauge du sac en bas au centre et valeur du silo (CDC §4, §10, charte « Studs Pop »).
-- Version minimale du Sprint 1 : le bouton « Retour Base Instantané » et le HUD complet arrivent au Sprint 7.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)

local BagHudController = {}

local BAR = UiConfig.BAG_BAR
local SILO = UiConfig.SILO_LABEL
local FONT = (Enum.Font :: any)[UiConfig.FONT] :: Enum.Font

local localPlayer = Players.LocalPlayer
local fill: Frame
local label: TextLabel
local siloLabel: TextLabel
local isAlerting = false
local screenGui: ScreenGui

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

local function buildSiloLabel(gui: ScreenGui)
	local frame = Instance.new("Frame")
	frame.Name = "Silo"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, SILO.TOP_MARGIN)
	frame.Size = UDim2.fromOffset(SILO.WIDTH, SILO.HEIGHT)
	frame.BackgroundColor3 = Bricks.rgb(BAR.BACKGROUND)
	decorate(frame)
	frame.Parent = gui
	siloLabel = newLabel(frame)
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
	siloLabel.Text = `Silo : {numberAttribute(PlayerAttributes.SILO_VALUE)} $`
	if not isAlerting then
		fill.BackgroundColor3 = Bricks.rgb(BAR.FILL)
	end
end

local function pulse()
	if not isAlerting then
		return
	end
	local alpha = (math.sin(os.clock() * BAR.PULSE_SPEED) + 1) / 2
	fill.BackgroundColor3 = Bricks.rgb(BAR.FILL):Lerp(Bricks.rgb(BAR.ALERT), alpha)
end

function BagHudController:Init()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "HarvestHud"
	screenGui.ResetOnSpawn = false
	buildBar(screenGui)
	buildSiloLabel(screenGui)
end

function BagHudController:Start()
	screenGui.Parent = localPlayer:WaitForChild("PlayerGui") -- attente autorisée dans Start, pas dans Init
	for _, name in { PlayerAttributes.BAG_COUNT, PlayerAttributes.BAG_CAPACITY, PlayerAttributes.SILO_VALUE } do
		localPlayer:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()
	RunService.RenderStepped:Connect(pulse)
end

return BagHudController
