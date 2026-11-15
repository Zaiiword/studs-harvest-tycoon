--!strict
-- Indicateur de revenu passif en haut de l'écran (CDC §10) : trésorerie, cadence de l'usine et autonomie
-- du silo ; alerte quand le silo est vide et que l'usine s'arrête (CDC §8). Lit les attributs du joueur.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)
local Format = require(ReplicatedStorage.Shared.util.Format)

local EconomyHudController = {}

local PANEL = UiConfig.ECONOMY_PANEL
local BAR = UiConfig.BAG_BAR

local localPlayer = Players.LocalPlayer
local screenGui: ScreenGui
local summary: TextLabel
local alert: TextLabel
local goalFill: Frame
local goalText: TextLabel

local GOAL = PANEL.GOAL

local function newLabel(parent: Instance): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = (Enum.Font :: any)[UiConfig.FONT]
	text.TextScaled = true
	text.TextColor3 = Bricks.rgb(BAR.TEXT)
	text.Parent = parent
	return text
end

-- Barre d'objectif (A59) : le prochain grand achat, rempli à mesure qu'on épargne.
local function buildGoal(top: number)
	local bar = Instance.new("Frame")
	bar.Name = "Goal"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, top)
	bar.Size = UDim2.fromOffset(GOAL.WIDTH, GOAL.HEIGHT)
	bar.BackgroundColor3 = Bricks.rgb(BAR.BACKGROUND)
	bar.ClipsDescendants = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = bar
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Bricks.rgb(UiConfig.STROKE_COLOR)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = bar
	goalFill = Instance.new("Frame")
	goalFill.BorderSizePixel = 0
	goalFill.Size = UDim2.fromScale(0, 1)
	goalFill.BackgroundColor3 = Bricks.rgb(GOAL.FILL)
	goalFill.Parent = bar
	local fillCorner = corner:Clone()
	fillCorner.Parent = goalFill
	goalText = newLabel(bar)
	goalText.Size = UDim2.new(1, -16, 1, -4)
	goalText.Position = UDim2.fromOffset(8, 2)
	goalText.TextStrokeTransparency = 0
	bar.Parent = screenGui
end

local function buildPanel()
	local frame = Instance.new("Frame")
	frame.Name = "Economy"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, PANEL.TOP_MARGIN)
	frame.Size = UDim2.fromOffset(PANEL.WIDTH, PANEL.HEIGHT)
	frame.BackgroundColor3 = Bricks.rgb(BAR.BACKGROUND)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, UiConfig.CORNER_RADIUS)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = UiConfig.STROKE_THICKNESS
	stroke.Color = Bricks.rgb(UiConfig.STROKE_COLOR)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	frame.Parent = screenGui
	summary = newLabel(frame)

	local goalTop = PANEL.TOP_MARGIN + PANEL.HEIGHT + GOAL.GAP
	alert = newLabel(screenGui)
	alert.AnchorPoint = Vector2.new(0.5, 0)
	alert.Position = UDim2.new(0.5, 0, 0, goalTop + GOAL.HEIGHT + GOAL.GAP)
	alert.Size = UDim2.fromOffset(PANEL.WIDTH, PANEL.ALERT_HEIGHT)
	alert.TextColor3 = Bricks.rgb(PANEL.ALERT_COLOR)
	alert.TextStrokeTransparency = 0
	alert.Text = "Silo vide : l'usine est à l'arrêt, retourne récolter !"
	buildGoal(goalTop)
end

local function numberAttribute(name: string): number
	local value = localPlayer:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function refreshGoal()
	local label = localPlayer:GetAttribute(PlayerAttributes.GOAL_LABEL)
	local price = numberAttribute(PlayerAttributes.GOAL_PRICE)
	local bar = goalFill.Parent :: Frame
	bar.Visible = typeof(label) == "string" and label ~= "" and price > 0
	if not bar.Visible then
		return
	end
	local money = numberAttribute(PlayerAttributes.MONEY)
	local ratio = math.clamp(money / price, 0, 1)
	goalFill.Size = UDim2.fromScale(ratio, 1)
	goalFill.BackgroundColor3 = Bricks.rgb(if ratio >= 1 then GOAL.READY else GOAL.FILL)
	goalText.Text = if ratio >= 1
		then `🎯 {label} : achète-le !`
		else `🎯 {label} · {Format.money(money)} / {Format.money(price)} $`
end

local function refresh()
	local silo = numberAttribute(PlayerAttributes.SILO_VALUE)
	local rate = numberAttribute(PlayerAttributes.CONVEYOR_RATE)
	local autonomy = if rate > 0 then Format.duration(silo / rate) else "—"
	local money = Format.money(numberAttribute(PlayerAttributes.MONEY))
	local income = Format.money(numberAttribute(PlayerAttributes.INCOME_PER_SECOND))
	local prestige =
		`♻️ {numberAttribute(PlayerAttributes.REBIRTHS)}  💎 {numberAttribute(PlayerAttributes.GEMS)}`
	summary.Text = `💰 {money} $  ·  +{income} $/s  ·  Silo {autonomy}  ·  {prestige}`
	refreshGoal()
	-- L'alerte n'a de sens qu'une fois l'usine lancée (quelque chose a déjà été déposé ou gagné).
	alert.Visible = silo <= 0 and numberAttribute(PlayerAttributes.MONEY) > 0
end

function EconomyHudController:Init()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "EconomyHud"
	screenGui.ResetOnSpawn = false
	buildPanel()
end

function EconomyHudController:Start()
	screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
	for _, name in
		{
			PlayerAttributes.MONEY,
			PlayerAttributes.INCOME_PER_SECOND,
			PlayerAttributes.SILO_VALUE,
			PlayerAttributes.CONVEYOR_RATE,
			PlayerAttributes.REBIRTHS,
			PlayerAttributes.GEMS,
			PlayerAttributes.GOAL_LABEL,
			PlayerAttributes.GOAL_PRICE,
		}
	do
		localPlayer:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()
end

return EconomyHudController
