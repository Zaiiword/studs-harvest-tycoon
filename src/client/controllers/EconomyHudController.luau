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

	alert = newLabel(screenGui)
	alert.AnchorPoint = Vector2.new(0.5, 0)
	alert.Position = UDim2.new(0.5, 0, 0, PANEL.TOP_MARGIN + PANEL.HEIGHT + PANEL.TOP_MARGIN / 2)
	alert.Size = UDim2.fromOffset(PANEL.WIDTH, PANEL.ALERT_HEIGHT)
	alert.TextColor3 = Bricks.rgb(PANEL.ALERT_COLOR)
	alert.TextStrokeTransparency = 0
	alert.Text = "Silo vide : l'usine est à l'arrêt, retourne récolter !"
end

local function numberAttribute(name: string): number
	local value = localPlayer:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
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
		}
	do
		localPlayer:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()
end

return EconomyHudController
