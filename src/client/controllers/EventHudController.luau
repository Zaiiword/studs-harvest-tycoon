--!strict
-- Bandeaux d'événements sous la trésorerie (CDC §6, §10) : météo en cours, compte à rebours ou barre de PV
-- du boss Météorite, multiplicateur ×3 gagné contre le boss. Lit les attributs publiés par EventService.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EventConfig = require(ReplicatedStorage.Shared.config.EventConfig)
local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local Weather = require(ReplicatedStorage.Shared.domain.Weather)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local WorldAttributes = require(ReplicatedStorage.Shared.net.WorldAttributes)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)
local Format = require(ReplicatedStorage.Shared.util.Format)

local EventHudController = {}

type Banner = { frame: Frame, fill: Frame, label: TextLabel }

local BANNER = UiConfig.EVENT_BANNER
local BAR = UiConfig.BAG_BAR
local REFRESH_INTERVAL = 0.25

local localPlayer = Players.LocalPlayer
local screenGui: ScreenGui
local weatherBanner: Banner
local bossBanner: Banner
local boostBanner: Banner
local elapsed = 0

local function newBanner(row: number, fillColor: { number }): Banner
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, BANNER.TOP + (row - 1) * (BANNER.HEIGHT + BANNER.SPACING))
	frame.Size = UDim2.fromOffset(BANNER.WIDTH, BANNER.HEIGHT)
	frame.BackgroundColor3 = Bricks.rgb(BAR.BACKGROUND)
	frame.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, UiConfig.CORNER_RADIUS)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = UiConfig.STROKE_THICKNESS
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Bricks.rgb(fillColor)
	fill.BackgroundTransparency = 0.3
	local fillCorner = corner:Clone()
	fillCorner.Parent = fill
	fill.Parent = frame
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = (Enum.Font :: any)[UiConfig.FONT]
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.ZIndex = 2
	label.Parent = frame
	frame.Parent = screenGui
	return { frame = frame, fill = fill, label = label }
end

local function world(name: string): any
	return ReplicatedStorage:GetAttribute(name)
end

local function numberOf(value: any): number
	return if typeof(value) == "number" then value else 0
end

local function refreshWeather(now: number)
	local def =
		Weather.byId(if typeof(world(WorldAttributes.WEATHER)) == "string" then world(WorldAttributes.WEATHER) else "")
	local isEvent = def.id ~= EventConfig.CLEAR.id
	weatherBanner.frame.Visible = isEvent
	if isEvent then
		local remaining = numberOf(world(WorldAttributes.WEATHER_ENDS_AT)) - now
		weatherBanner.label.Text = `🌦️ {def.name} · {def.description} · {Format.duration(remaining)}`
	end
end

-- Compte à rebours avant l'impact, puis barre de PV pendant le combat.
local function refreshBoss(now: number)
	local hp, maxHp = numberOf(world(WorldAttributes.BOSS_HP)), numberOf(world(WorldAttributes.BOSS_MAX_HP))
	local untilImpact = numberOf(world(WorldAttributes.METEOR_AT)) - now
	if hp > 0 and maxHp > 0 then
		bossBanner.frame.Visible = true
		bossBanner.fill.Size = UDim2.fromScale(hp / maxHp, 1)
		local leaves = numberOf(world(WorldAttributes.BOSS_LEAVES_AT)) - now
		bossBanner.label.Text =
			`☄️ Épi de Cristal : {Format.money(hp)} PV · Top 3 récompensé · {Format.duration(leaves)}`
	elseif untilImpact > 0 and untilImpact <= EventConfig.METEOR.ANNOUNCE_SECONDS then
		bossBanner.frame.Visible = true
		bossBanner.fill.Size = UDim2.fromScale(1, 1)
		bossBanner.label.Text = `☄️ Météorite dans {math.ceil(untilImpact)} s : fonce au bout du champ !`
	else
		bossBanner.frame.Visible = false
	end
end

local function refreshBoost(now: number)
	local remaining = numberOf(localPlayer:GetAttribute(PlayerAttributes.BOOST_UNTIL)) - now
	boostBanner.frame.Visible = remaining > 0
	if remaining > 0 then
		local multiplier = EventConfig.METEOR.REWARD_INCOME_MULTIPLIER
		boostBanner.label.Text = `🏆 Revenus ×{multiplier} · {Format.duration(remaining)}`
	end
end

function EventHudController:Init()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "EventHud"
	screenGui.ResetOnSpawn = false
	weatherBanner = newBanner(1, BANNER.WEATHER_COLOR)
	bossBanner = newBanner(2, BANNER.BOSS_BAR_COLOR)
	boostBanner = newBanner(3, BANNER.BOOST_COLOR)
end

function EventHudController:Start()
	screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
	RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed < REFRESH_INTERVAL then
			return
		end
		elapsed = 0
		local now = Workspace:GetServerTimeNow()
		refreshWeather(now)
		refreshBoss(now)
		refreshBoost(now)
	end)
end

return EventHudController
