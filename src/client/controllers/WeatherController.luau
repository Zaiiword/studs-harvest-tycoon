--!strict
-- Ambiance de la météo côté client (CDC §6) : teinte dorée pour la Pluie Dorée, brume dense pour la
-- Tempête de Vent, nuit et néons pour la Nuit Néon. Effets locaux uniquement : le serveur garde l'éclairage
-- de base (RenderService) et chaque client y ajoute sa couche.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local WorldAttributes = require(ReplicatedStorage.Shared.net.WorldAttributes)

local WeatherController = {}

type Look = { tint: Color3, clockTime: number?, brightness: number?, atmosphereDensity: number? }

local TRANSITION = TweenInfo.new(3, Enum.EasingStyle.Sine)
local LOOKS: { [string]: Look } = {
	Clear = { tint = Color3.new(1, 1, 1) },
	GoldenRain = { tint = Color3.fromRGB(255, 225, 160) },
	WindStorm = { tint = Color3.fromRGB(215, 225, 235), atmosphereDensity = 0.5 },
	NeonNight = { tint = Color3.fromRGB(190, 160, 255), clockTime = 0, brightness = 1.5 },
}

local correction: ColorCorrectionEffect
local base: { clockTime: number, brightness: number, density: number? } = { clockTime = 14, brightness = 3 }

local function apply(weatherId: string)
	local look = LOOKS[weatherId] or LOOKS.Clear
	TweenService:Create(correction, TRANSITION, { TintColor = look.tint }):Play()
	TweenService:Create(Lighting, TRANSITION, {
		ClockTime = look.clockTime or base.clockTime,
		Brightness = look.brightness or base.brightness,
	}):Play()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere and base.density then
		TweenService:Create(atmosphere, TRANSITION, { Density = look.atmosphereDensity or base.density }):Play()
	end
end

local function onWeatherChanged()
	local weather = ReplicatedStorage:GetAttribute(WorldAttributes.WEATHER)
	apply(if typeof(weather) == "string" then weather else "Clear")
end

function WeatherController:Start()
	base.clockTime, base.brightness = Lighting.ClockTime, Lighting.Brightness
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	base.density = atmosphere and atmosphere.Density
	correction = Instance.new("ColorCorrectionEffect")
	correction.Name = "WeatherTint"
	correction.Parent = Lighting
	ReplicatedStorage:GetAttributeChangedSignal(WorldAttributes.WEATHER):Connect(onWeatherChanged)
	onWeatherChanged()
end

return WeatherController
