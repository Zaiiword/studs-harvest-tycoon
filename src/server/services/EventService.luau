--!strict
-- Événements dynamiques (CDC §6, Sprint 5) : météo tournante, hotspot mobile et boss Météorite.
-- L'état global est publié en attributs de ReplicatedStorage (WorldAttributes) pour le HUD et les effets.
-- Dépendances : FieldService (chance Arc-en-ciel), InventoryService (Œuf Légendaire), VehicleService (palier).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EventConfig = require(ReplicatedStorage.Shared.config.EventConfig)
local MapConfig = require(ReplicatedStorage.Shared.config.MapConfig)
local Hotspot = require(ReplicatedStorage.Shared.domain.Hotspot)
local MapGeometry = require(ReplicatedStorage.Shared.domain.MapGeometry)
local MeteorBoss = require(ReplicatedStorage.Shared.domain.MeteorBoss)
local Weather = require(ReplicatedStorage.Shared.domain.Weather)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local WorldAttributes = require(ReplicatedStorage.Shared.net.WorldAttributes)
local EventModels = require(script.Parent.Parent.builders.EventModels)
local FieldService = require(script.Parent.FieldService)
local InventoryService = require(script.Parent.InventoryService)
local VehicleService = require(script.Parent.VehicleService)

local EventService = {}

type ActiveBoss = { boss: MeteorBoss.Boss, model: EventModels.BossModel, leavesAt: number }

local METEOR = EventConfig.METEOR

local random = Random.new()
local folder: Folder
local weather: EventConfig.WeatherDef = EventConfig.CLEAR
local cycleStartedAt = 0
local hotspot: Hotspot.Spot? = nil
local hotspotMovesAt = 0
local hotspotModel: Model
local nextMeteorAt = 0
local activeBoss: ActiveBoss? = nil
local hitElapsed = 0

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function nextRoll(): number
	return random:NextNumber()
end

local function setWorld(name: string, value: any)
	ReplicatedStorage:SetAttribute(name, value)
end

local function applyWeather(def: EventConfig.WeatherDef, endsAt: number)
	weather = def
	FieldService.setRainbowBoost(def.rainbowBoost)
	setWorld(WorldAttributes.WEATHER, def.id)
	setWorld(WorldAttributes.WEATHER_ENDS_AT, endsAt)
	setWorld(WorldAttributes.VEHICLE_SPEED_MULTIPLIER, def.vehicleSpeedMultiplier)
end

-- A10 : 4 min de beau temps, puis 2 min d'un événement tiré au sort, en boucle.
local function updateWeather(time: number)
	local phase = Weather.phaseAt(time - cycleStartedAt)
	if phase.isEvent and weather.id == EventConfig.CLEAR.id then
		applyWeather(Weather.pick(nextRoll), time + phase.remaining)
	elseif not phase.isEvent and weather.id ~= EventConfig.CLEAR.id then
		applyWeather(EventConfig.CLEAR, time + phase.remaining)
	end
end

local function moveHotspot(time: number)
	hotspot = Hotspot.pick(nextRoll)
	hotspotMovesAt = time + EventConfig.HOTSPOT.MOVE_SECONDS
	local spot = hotspot :: Hotspot.Spot
	EventModels.placeHotspot(hotspotModel, spot.x, spot.z)
	setWorld(WorldAttributes.HOTSPOT_ENDS_AT, hotspotMovesAt)
end

local function arenaCenter(): (number, number)
	local core = MapGeometry.bandOf("Core")
	return MapConfig.STEM.minX + (core.startDistance + core.endDistance) / 2, 0
end

local function refreshBossLabel(active: ActiveBoss)
	local boss = active.boss
	active.model.hpLabel.Text = `☄️ Épi de Cristal  {math.ceil(boss.hp)} / {boss.maxHp} PV`
	setWorld(WorldAttributes.BOSS_HP, math.ceil(boss.hp))
end

-- Fait apparaître l'Épi Géant de Cristal au cœur de l'arène (CDC §6).
function EventService.summonMeteor()
	if activeBoss then
		return
	end
	local x, z = arenaCenter()
	local active: ActiveBoss = {
		boss = MeteorBoss.new(METEOR.MAX_HP),
		model = EventModels.meteor(folder, x, z),
		leavesAt = now() + METEOR.DURATION_SECONDS,
	}
	activeBoss = active
	setWorld(WorldAttributes.BOSS_MAX_HP, METEOR.MAX_HP)
	setWorld(WorldAttributes.BOSS_LEAVES_AT, active.leavesAt)
	refreshBossLabel(active)
end

-- Récompenses du Top 3 : Œuf Légendaire et revenus ×3 pendant 5 minutes (CDC §6).
local function rewardTop(boss: MeteorBoss.Boss)
	for _, userId in MeteorBoss.ranking(boss, METEOR.REWARD_TOP) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			InventoryService.add(player, METEOR.REWARD_ITEM, 1)
			player:SetAttribute(PlayerAttributes.BOOST_UNTIL, now() + METEOR.REWARD_SECONDS)
		end
	end
end

local function endBoss(isDefeated: boolean)
	local active = activeBoss
	if not active then
		return
	end
	if isDefeated then
		rewardTop(active.boss)
	end
	active.model.model:Destroy()
	activeBoss = nil
	nextMeteorAt = now() + METEOR.INTERVAL_SECONDS
	setWorld(WorldAttributes.BOSS_HP, 0)
	setWorld(WorldAttributes.METEOR_AT, nextMeteorAt)
end

-- Chaque engin (ou joueur à pied) assez proche fauche le boss avec la puissance de son outil.
local function hitBoss(active: ActiveBoss)
	local x, z = arenaCenter()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local tier = VehicleService.tierOf(player)
		local reach = METEOR.HIT_RADIUS + tier.hitboxStuds
		if root and (Vector3.new(root.Position.X - x, 0, root.Position.Z - z)).Magnitude <= reach then
			local multiplier = player:GetAttribute(PlayerAttributes.CUT_POWER_MULTIPLIER)
			local petFactor = if typeof(multiplier) == "number" and multiplier >= 1 then multiplier else 1
			MeteorBoss.hit(active.boss, player.UserId, MeteorBoss.damageFor(tier.cutPower * petFactor))
		end
	end
	refreshBossLabel(active)
	if MeteorBoss.isDefeated(active.boss) then
		endBoss(true)
	end
end

local function updateBoss(time: number, deltaTime: number)
	local active = activeBoss
	if not active then
		if time >= nextMeteorAt then
			EventService.summonMeteor()
		end
		return
	end
	if time >= active.leavesAt then
		endBoss(false) -- A40 : non abattu à temps, il repart sans récompense
		return
	end
	hitElapsed += deltaTime
	if hitElapsed >= METEOR.HIT_INTERVAL then
		hitElapsed = 0
		hitBoss(active)
	end
end

-- Multiplicateur de valeur d'un blé coupé en (x, z) : météo × hotspot (CDC §6, A11).
function EventService.valueMultiplierAt(x: number, z: number): number
	local hotspotBonus = if Hotspot.contains(hotspot, x, z) then EventConfig.HOTSPOT.VALUE_MULTIPLIER else 1
	return weather.valueMultiplier * hotspotBonus
end

-- Panneau de test : force un événement météo pour sa durée normale.
function EventService.forceWeather(id: string)
	local time = now()
	cycleStartedAt = time - EventConfig.WEATHER_CLEAR_SECONDS -- on se place au début de la phase événement
	applyWeather(Weather.byId(id), time + EventConfig.WEATHER_CYCLE_SECONDS - EventConfig.WEATHER_CLEAR_SECONDS)
end

function EventService:Init()
	folder = Instance.new("Folder")
	folder.Name = "Events"
	folder.Parent = Workspace
	hotspotModel = EventModels.hotspot(folder)
end

function EventService:Start()
	local time = now()
	cycleStartedAt = time
	applyWeather(EventConfig.CLEAR, time + EventConfig.WEATHER_CLEAR_SECONDS)
	moveHotspot(time)
	nextMeteorAt = time + METEOR.INTERVAL_SECONDS
	setWorld(WorldAttributes.METEOR_AT, nextMeteorAt)
	setWorld(WorldAttributes.BOSS_HP, 0)
	RunService.Heartbeat:Connect(function(deltaTime: number)
		local current = now()
		updateWeather(current)
		if current >= hotspotMovesAt then
			moveHotspot(current)
		end
		updateBoss(current, deltaTime)
	end)
end

return EventService
