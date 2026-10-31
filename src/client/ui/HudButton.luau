--!strict
-- Gros bouton du HUD façon jeux Roblox populaires (CDC §10) : dégradé, reflet, grosse icône, légende
-- contourée, pastille rouge « ! » quand quelque chose attend le joueur, et frétillement pour attirer l'œil.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)
local Style = require(script.Parent.Style)

local HudButton = {}

export type Spec = { icon: string, caption: string, top: { number }, bottom: { number }, fromBottom: number }
export type HudButton = { button: TextButton, alert: Frame, wiggles: boolean }

local HUD = UiConfig.HUD_BUTTON
local ALERT_SIZE = 26

local buttons: { HudButton } = {}
local clock = 0
local isAnimating = false

local function wiggleAngle(): number
	local wiggle = HUD.WIGGLE
	local phase = clock % wiggle.period
	if phase >= wiggle.seconds then
		return 0
	end
	return wiggle.degrees * math.sin(phase / wiggle.seconds * wiggle.shakes * math.pi)
end

local function animate(deltaTime: number)
	clock += deltaTime
	local angle = wiggleAngle()
	for _, hud in buttons do
		hud.button.Rotation = if hud.wiggles then angle else 0
	end
end

local function addAlert(button: TextButton): Frame
	local alert = Instance.new("Frame")
	alert.AnchorPoint = Vector2.new(0.5, 0.5)
	alert.Position = UDim2.new(1, -4, 0, 4)
	alert.Size = UDim2.fromOffset(ALERT_SIZE, ALERT_SIZE)
	alert.BackgroundColor3 = Bricks.rgb(HUD.ALERT_COLOR)
	alert.ZIndex = 5
	alert.Visible = false
	Style.corner(alert, UDim.new(0.5, 0))
	Style.stroke(alert, UiConfig.STROKE_COLOR, 2)
	local mark = Style.label(alert, "!", UDim2.fromScale(0.8, 0.8))
	mark.Position = UDim2.fromScale(0.1, 0.1)
	mark.ZIndex = 6
	alert.Parent = button
	return alert
end

function HudButton.new(parent: Instance, spec: Spec): HudButton
	local button = Style.button(parent, { top = spec.top, bottom = spec.bottom, edge = UiConfig.STROKE_COLOR })
	button.AnchorPoint = Vector2.new(0, 1)
	button.Position = UDim2.new(0, HUD.LEFT, 1, -spec.fromBottom)
	button.Size = UDim2.fromOffset(HUD.SIZE, HUD.SIZE)
	Style.shine(button)
	Style.label(button, spec.icon, UDim2.fromScale(0.8, 0.7)).Position = UDim2.fromScale(0.1, 0.02)
	local caption = Style.label(button, spec.caption, UDim2.fromScale(1.25, 0.32))
	caption.AnchorPoint = Vector2.new(0.5, 0.5)
	caption.Position = UDim2.fromScale(0.5, 0.92)
	local hud: HudButton = { button = button, alert = addAlert(button), wiggles = false }
	table.insert(buttons, hud)
	if not isAnimating then
		isAnimating = true
		RunService.RenderStepped:Connect(animate)
	end
	return hud
end

-- Pastille « ! » et frétillement quand une récompense attend (ou en permanence pour la boutique).
function HudButton.setAlert(hud: HudButton, isAlert: boolean)
	hud.alert.Visible = isAlert
	hud.wiggles = isAlert
end

return HudButton
