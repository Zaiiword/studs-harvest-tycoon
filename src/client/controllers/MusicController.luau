--!strict
-- Musique de fond (A74) : une liste par ambiance (ferme au calme, boss Météorite), fondu au changement
-- d'ambiance, morceau suivant tiré sans répétition. Touche M ou bouton ♪ pour couper ou remettre la musique.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local AudioConfig = require(ReplicatedStorage.Shared.config.AudioConfig)
local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local Playlist = require(ReplicatedStorage.Shared.domain.Playlist)
local WorldAttributes = require(ReplicatedStorage.Shared.net.WorldAttributes)

local MusicController = {}

local FADE = TweenInfo.new(AudioConfig.FADE_SECONDS, Enum.EasingStyle.Sine)
local BUTTON = AudioConfig.TOGGLE_BUTTON

local random = Random.new()
local mood: Playlist.Mood = "calm"
local muted = false
local current: Sound? = nil
local lastIndex: { [string]: number } = {}
local token = 0 -- invalide les enchaînements prévus par un morceau remplacé entre-temps
local button: TextButton

local function roll(n: number): number
	return random:NextInteger(1, n)
end

local function fadeOut(sound: Sound)
	local tween = TweenService:Create(sound, FADE, { Volume = 0 })
	tween.Completed:Connect(function()
		sound:Destroy()
	end)
	tween:Play()
end

local function targetVolume(): number
	return if muted then 0 else AudioConfig.MUSIC_VOLUME
end

local playNext: () -> ()

-- Lance un morceau de l'ambiance en cours et enchaîne sur le suivant à la fin.
function playNext()
	token += 1
	local myToken = token
	local list = AudioConfig.MUSIC[mood]
	local index = Playlist.nextIndex(#list, lastIndex[mood], roll)
	lastIndex[mood] = index

	local sound = Instance.new("Sound")
	sound.Name = "Music"
	sound.SoundId = `rbxassetid://{list[index]}`
	sound.Volume = 0
	sound.Parent = SoundService
	sound.Ended:Connect(function()
		task.delay(AudioConfig.GAP_SECONDS, function()
			if myToken == token then
				playNext()
			end
		end)
	end)
	if current then
		fadeOut(current)
	end
	current = sound
	sound:Play()
	TweenService:Create(sound, FADE, { Volume = targetVolume() }):Play()
end

local function onBossChanged()
	local hp = ReplicatedStorage:GetAttribute(WorldAttributes.BOSS_HP)
	local nextMood = Playlist.mood(if typeof(hp) == "number" then hp else 0)
	if nextMood ~= mood then
		mood = nextMood
		playNext()
	end
end

local function setMuted(value: boolean)
	muted = value
	button.Text = if muted then "♪ ✕" else "♪"
	if current then
		TweenService:Create(current, TweenInfo.new(0.3), { Volume = targetVolume() }):Play()
	end
end

local function buildButton(): TextButton
	local gui = Instance.new("ScreenGui")
	gui.Name = "MusicToggle"
	gui.ResetOnSpawn = false
	local new = Instance.new("TextButton")
	new.Name = "Toggle"
	new.Size = UDim2.fromOffset(BUTTON.SIZE, BUTTON.SIZE)
	new.Position = UDim2.fromOffset(BUTTON.LEFT, BUTTON.TOP)
	new.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	new.BackgroundTransparency = 0.3
	new.TextColor3 = Color3.new(1, 1, 1)
	new.Font = (Enum.Font :: any)[UiConfig.FONT]
	new.TextScaled = true
	new.Text = "♪"
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, UiConfig.CORNER_RADIUS)
	corner.Parent = new
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = UiConfig.STROKE_THICKNESS
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = new
	local padding = Instance.new("UIPadding")
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
	padding.Parent = new
	new.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return new
end

function MusicController:Init()
	button = buildButton()
end

function MusicController:Start()
	button.Activated:Connect(function()
		setMuted(not muted)
	end)
	local key = (Enum.KeyCode :: any)[AudioConfig.TOGGLE_KEY]
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == key then
			setMuted(not muted)
		end
	end)
	ReplicatedStorage:GetAttributeChangedSignal(WorldAttributes.BOSS_HP):Connect(onBossChanged)
	mood = Playlist.mood(0)
	onBossChanged()
	if not current then
		playNext()
	end
end

return MusicController
