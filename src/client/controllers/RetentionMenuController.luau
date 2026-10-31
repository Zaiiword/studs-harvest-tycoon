--!strict
-- Menu des récompenses 🎁 (CDC §7.4, §10) dans le style de la boutique : onglets Cadeaux (9 cadeaux de temps
-- de jeu), Quêtes du jour (barres de progression) et Roue de la Fortune (chances affichées, A45).
-- Le client ne fait que demander ; la roue tourne jusqu'à la case tirée par le serveur.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local RetentionConfig = require(ReplicatedStorage.Shared.config.RetentionConfig)
local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local Retention = require(ReplicatedStorage.Shared.domain.Retention)
local RewardText = require(ReplicatedStorage.Shared.domain.RewardText)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local Remotes = require(ReplicatedStorage.Shared.net.Remotes)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)
local Format = require(ReplicatedStorage.Shared.util.Format)
local Grid = require(script.Parent.Parent.ui.Grid)
local HudButton = require(script.Parent.Parent.ui.HudButton)
local Style = require(script.Parent.Parent.ui.Style)
local Tabs = require(script.Parent.Parent.ui.Tabs)
local RewardPopup = require(script.Parent.Parent.ui.RewardPopup)
local Window = require(script.Parent.Parent.ui.Window)

local RetentionMenuController = {}

type State = "ready" | "wait" | "done"
type Tile = { gradient: UIGradient, status: TextLabel, pulse: UIScale, state: State }
type QuestRow = { icon: TextLabel, title: TextLabel, fill: Frame, count: TextLabel, claim: TextButton, tile: Tile }

local MENU = UiConfig.RETENTION_MENU
local WINDOW = UiConfig.WINDOW
local POPUP = UiConfig.REWARD_POPUP
local HUD = UiConfig.HUD_BUTTON
local PAD = MENU.PADDING
local REFRESH_INTERVAL = 0.5
local GIFT_MIN_WIDTH = 120
local CIRCLE = UDim.new(0.5, 0)
local SPIN_HEIGHT = 64
local ODDS_ROW_HEIGHT = 30
local DIVIDER_WIDTH = 3
local CHIP_SIZE = UDim2.fromScale(0.34, 0.12)
local HUB_SIZE = 0.2
local POINTER_SIZE = 0.16
local DEFAULT_QUEST_ICON = "🎯"

local COLORS: { [State]: { top: { number }, bottom: { number } } } = {
	ready = { top = MENU.READY_TOP, bottom = MENU.READY_BOTTOM },
	wait = { top = MENU.WAIT_TOP, bottom = MENU.WAIT_BOTTOM },
	done = { top = MENU.DONE_TOP, bottom = MENU.DONE_BOTTOM },
}

local localPlayer = Players.LocalPlayer
local screenGui: ScreenGui
local window: Window.Window
local hud: HudButton.HudButton
local giftTiles: { Tile } = {}
local questRows: { QuestRow } = {}
local rotor: Frame
local pointer: TextLabel
local lastSegment = 0 -- case sous le pointeur, pour le faire claquer à chaque passage
local spinTile: Tile
local remotes: { [string]: RemoteEvent } = {}
local elapsed = 0
local clock = 0

local function attribute(name: string): any
	return localPlayer:GetAttribute(name)
end

-- (Le rebond des boutons occupe leur UIScale : la respiration se fait sur un enfant.)
-- Change l'état d'une tuile (couleurs, texte) ; les tuiles prêtes « respirent » (voir animate).
local function setState(tile: Tile, state: State, text: string)
	tile.state = state
	tile.status.Text = text
	local colors = COLORS[state]
	tile.gradient.Color = ColorSequence.new(Bricks.rgb(colors.top), Bricks.rgb(colors.bottom))
end

local function newTile(button: TextButton, pulseTarget: GuiObject, status: TextLabel): Tile
	local pulse = Instance.new("UIScale")
	pulse.Parent = pulseTarget
	return {
		gradient = button:FindFirstChildOfClass("UIGradient") :: UIGradient,
		status = status,
		pulse = pulse,
		state = "wait",
	}
end

local function candy(parent: Instance, state: State): TextButton
	local colors = COLORS[state]
	local button = Style.button(parent, { top = colors.top, bottom = colors.bottom, edge = WINDOW.STROKE_COLOR })
	Style.shine(button)
	return button
end

-- Cadeaux ----------------------------------------------------------------------------------------------------

local function buildGift(page: ScrollingFrame, index: number, gift: RetentionConfig.Gift)
	local card = candy(page, "wait")
	card.LayoutOrder = index
	local icon = Style.label(card, RewardText.icon(gift.reward), UDim2.fromScale(1, 0.38))
	icon.Position = UDim2.fromScale(0, 0.04)
	local reward = Style.label(card, RewardText.label(gift.reward), UDim2.new(1, -12, 0.22, 0))
	reward.Position = UDim2.new(0, 6, 0.42, 0)
	local pill = Instance.new("Frame")
	pill.AnchorPoint = Vector2.new(0.5, 1)
	pill.Position = UDim2.new(0.5, 0, 1, -8)
	pill.Size = UDim2.new(1, -16, 0.26, 0)
	pill.BackgroundColor3 = Bricks.rgb(WINDOW.STROKE_COLOR)
	pill.BackgroundTransparency = 0.35
	Style.corner(pill, CIRCLE)
	pill.Parent = card
	local status = Style.label(pill, "", UDim2.new(1, -10, 1, -6))
	status.Position = UDim2.fromOffset(5, 3)
	card.Activated:Connect(function()
		remotes.gift:FireServer(index)
	end)
	giftTiles[index] = newTile(card, icon, status)
end

local function buildGifts(): ScrollingFrame
	local page = Grid.page({
		minWidth = GIFT_MIN_WIDTH,
		height = MENU.GIFT_HEIGHT,
		minColumns = MENU.GIFT_COLUMNS,
		maxColumns = MENU.GIFT_COLUMNS,
		padding = PAD,
	})
	for index, gift in RetentionConfig.GIFTS do
		buildGift(page, index, gift)
	end
	return page
end

-- Quêtes -----------------------------------------------------------------------------------------------------

local function buildProgressBar(row: Frame): (Frame, TextLabel)
	local bar = Instance.new("Frame")
	bar.Position = UDim2.new(0, MENU.QUEST_HEIGHT, 0.55, 0)
	bar.Size = UDim2.new(0.62, -MENU.QUEST_HEIGHT, 0.3, 0)
	bar.BackgroundColor3 = Bricks.rgb(MENU.BAR_BACK)
	Style.corner(bar, CIRCLE)
	Style.stroke(bar, WINDOW.STROKE_COLOR, 2)
	bar.Parent = row
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	Style.corner(fill, CIRCLE)
	Style.gradient(fill, MENU.BAR_TOP, MENU.BAR_BOTTOM)
	fill.Parent = bar
	local count = Style.label(bar, "", UDim2.new(1, 0, 1, -4))
	count.Position = UDim2.fromOffset(0, 2)
	count.ZIndex = 2
	return fill, count
end

local function buildQuestRow(page: ScrollingFrame, order: number)
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, MENU.QUEST_HEIGHT)
	Style.corner(row, UDim.new(0, UiConfig.CORNER_RADIUS + 4))
	Style.gradient(row, MENU.QUEST_TOP, MENU.QUEST_BOTTOM)
	Style.stroke(row, WINDOW.STROKE_COLOR, UiConfig.STROKE_THICKNESS)
	row.Parent = page
	local icon = Style.label(row, DEFAULT_QUEST_ICON, UDim2.new(0, MENU.QUEST_HEIGHT - PAD, 1, -PAD))
	icon.Position = UDim2.fromOffset(PAD / 2, PAD / 2)
	local title = Style.label(row, "", UDim2.new(0.62, -MENU.QUEST_HEIGHT, 0.4, 0))
	title.Position = UDim2.new(0, MENU.QUEST_HEIGHT, 0.1, 0)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local fill, count = buildProgressBar(row)
	local claim = candy(row, "wait")
	claim.AnchorPoint = Vector2.new(1, 0.5)
	claim.Position = UDim2.new(1, -PAD, 0.5, 0)
	claim.Size = UDim2.new(0.36, -PAD, 1, -2 * PAD)
	local status = Style.label(claim, "", UDim2.new(1, -12, 1, -10))
	status.Position = UDim2.fromOffset(6, 5)
	local questRow: QuestRow =
		{ icon = icon, title = title, fill = fill, count = count, claim = claim, tile = newTile(claim, status, status) }
	claim.Activated:Connect(function()
		remotes.quest:FireServer(claim:GetAttribute("QuestId"))
	end)
	table.insert(questRows, questRow)
end

local function buildQuests(): ScrollingFrame
	local page = Instance.new("ScrollingFrame")
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.CanvasSize = UDim2.new()
	page.ScrollBarThickness = 8
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0, PAD), UDim.new(0, PAD)
	padding.PaddingTop = UDim.new(0, 4)
	padding.Parent = page
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, PAD)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = page
	for order = 1, RetentionConfig.QUESTS_PER_DAY do
		buildQuestRow(page, order)
	end
	return page
end

-- Roue -------------------------------------------------------------------------------------------------------

local function circle(parent: Instance, scale: number): Frame
	local disc = Instance.new("Frame")
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromScale(0.5, 0.5)
	disc.Size = UDim2.fromScale(scale, scale)
	Style.corner(disc, CIRCLE)
	disc.Parent = parent
	return disc
end

-- Cases de la roue : séparateurs depuis le centre et pastille colorée au milieu de chaque case.
local function buildSegments(face: Frame)
	rotor = Instance.new("Frame")
	rotor.BackgroundTransparency = 1
	rotor.Size = UDim2.fromScale(1, 1)
	rotor.Parent = face
	local count = #RetentionConfig.WHEEL
	local step = 360 / count
	for index, segment in RetentionConfig.WHEEL do
		-- Roblox fait tourner un cadre autour de SON centre (pas de son AnchorPoint) : le séparateur est donc
		-- posé sur un bras transparent de la taille de la roue, et c'est le bras qui tourne autour du centre.
		local arm = Instance.new("Frame")
		arm.BackgroundTransparency = 1
		arm.Size = UDim2.fromScale(1, 1)
		arm.Rotation = (index - 1) * step
		arm.Parent = rotor
		local divider = Instance.new("Frame")
		divider.AnchorPoint = Vector2.new(0.5, 0)
		divider.Position = UDim2.fromScale(0.5, 0)
		divider.Size = UDim2.new(0, DIVIDER_WIDTH, 0.5, 0)
		divider.BackgroundColor3 = Bricks.rgb(WINDOW.STROKE_COLOR)
		divider.BorderSizePixel = 0
		divider.Parent = arm
		local angle = math.rad((index - 0.5) * step)
		local chip = Instance.new("Frame")
		chip.AnchorPoint = Vector2.new(0.5, 0.5)
		chip.Position = UDim2.fromScale(
			0.5 + MENU.WHEEL_LABEL_RADIUS * math.sin(angle),
			0.5 - MENU.WHEEL_LABEL_RADIUS * math.cos(angle)
		)
		chip.Size = CHIP_SIZE
		chip.Rotation = math.deg(angle) - 90 -- lisible depuis le centre, comme sur une vraie roue
		chip.BackgroundColor3 = Bricks.rgb(segment.color)
		Style.corner(chip, CIRCLE)
		Style.stroke(chip, WINDOW.STROKE_COLOR, 2)
		Style.label(chip, segment.label, UDim2.new(1, -6, 1, -4)).Position = UDim2.fromOffset(3, 2)
		chip.Parent = rotor
	end
end

local function buildWheelDisc(page: Frame)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromOffset(PAD, PAD * 2)
	holder.Size = UDim2.new(0.55, -PAD, 1, -PAD * 3)
	holder.Parent = page
	local rim = circle(holder, 1)
	local square = Instance.new("UIAspectRatioConstraint")
	square.Parent = rim
	Style.gradient(rim, MENU.WHEEL_RIM_TOP, MENU.WHEEL_RIM_BOTTOM)
	Style.stroke(rim, WINDOW.STROKE_COLOR, UiConfig.STROKE_THICKNESS + 1)
	local face = circle(rim, 1 - 2 * MENU.WHEEL_RIM)
	face.BackgroundColor3 = Bricks.rgb(MENU.WHEEL_FACE)
	Style.stroke(face, WINDOW.STROKE_COLOR, 2)
	buildSegments(face)
	local hub = circle(face, HUB_SIZE)
	Style.gradient(hub, MENU.WHEEL_RIM_TOP, MENU.WHEEL_RIM_BOTTOM)
	Style.stroke(hub, WINDOW.STROKE_COLOR, 2)
	Style.label(hub, "⭐", UDim2.fromScale(0.7, 0.7)).Position = UDim2.fromScale(0.15, 0.15)
	pointer = Style.label(rim, "▼", UDim2.fromScale(POINTER_SIZE, POINTER_SIZE))
	pointer.AnchorPoint = Vector2.new(0.5, 0.6)
	pointer.Position = UDim2.fromScale(0.5, 0)
	pointer.TextColor3 = Bricks.rgb(MENU.POINTER_COLOR)
	pointer.ZIndex = 5
end

local function buildOdds(page: Frame)
	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.new(0.55, PAD, 0, PAD)
	list.Size = UDim2.new(0.45, -2 * PAD, 1, -(SPIN_HEIGHT + 3 * PAD))
	list.Parent = page
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	Style.label(list, "CHANCES", UDim2.new(1, 0, 0, ODDS_ROW_HEIGHT))
	local odds = RewardText.wheelOdds()
	for index, segment in RetentionConfig.WHEEL do
		local row = Instance.new("Frame")
		row.LayoutOrder = index
		row.Size = UDim2.new(1, 0, 0, ODDS_ROW_HEIGHT)
		row.BackgroundColor3 = Bricks.rgb(segment.color)
		Style.corner(row, CIRCLE)
		Style.stroke(row, WINDOW.STROKE_COLOR, 2)
		local name = Style.label(row, segment.label, UDim2.new(0.68, -8, 1, -6))
		name.Position = UDim2.fromOffset(10, 3)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local chance = Style.label(row, `{odds[index]} %`, UDim2.new(0.32, -10, 1, -6))
		chance.Position = UDim2.new(0.68, 0, 0, 3)
		chance.TextXAlignment = Enum.TextXAlignment.Right
		row.Parent = list
	end
end

local function buildWheel(): Frame
	local page = Instance.new("Frame")
	page.BackgroundTransparency = 1
	buildWheelDisc(page)
	buildOdds(page)
	local spin = candy(page, "ready")
	spin.AnchorPoint = Vector2.new(0, 1)
	spin.Position = UDim2.new(0.55, PAD, 1, -PAD)
	spin.Size = UDim2.new(0.45, -2 * PAD, 0, SPIN_HEIGHT)
	local status = Style.label(spin, "", UDim2.new(1, -12, 1, -12))
	status.Position = UDim2.fromOffset(6, 6)
	spin.Activated:Connect(function()
		remotes.spin:FireServer()
	end)
	spinTile = newTile(spin, status, status)
	return page
end

-- Fait tourner la roue pour que la case tirée par le serveur s'arrête sous le pointeur.
local function spinTo(index: number)
	local count = #RetentionConfig.WHEEL
	local target = 360 * MENU.SPIN_TURNS - (index - 0.5) * 360 / count
	rotor.Rotation = 0
	local info = TweenInfo.new(MENU.SPIN_SECONDS, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	local spin = TweenService:Create(rotor, info, { Rotation = target })
	spin.Completed:Once(function()
		local reward = RetentionConfig.WHEEL[index].reward
		RewardPopup.show(RewardText.icon(reward), RewardText.label(reward))
	end)
	spin:Play()
end

-- Le pointeur claque à chaque case qui passe dessous, comme une vraie roue de fête foraine.
local function flickPointer()
	local step = 360 / #RetentionConfig.WHEEL
	local segment = math.floor(rotor.Rotation / step)
	if segment == lastSegment then
		return
	end
	lastSegment = segment
	pointer.Rotation = -POPUP.POINTER_FLICK_DEGREES
	local info = TweenInfo.new(POPUP.POINTER_FLICK_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(pointer, info, { Rotation = 0 }):Play()
end

-- Rafraîchissement ---------------------------------------------------------------------------------------------

local function refreshGifts(now: number): boolean
	local started = attribute(PlayerAttributes.SESSION_STARTED_AT)
	local session = if typeof(started) == "number" then now - started else 0
	local claimed: { [number]: boolean } = {}
	for index in string.gmatch(tostring(attribute(PlayerAttributes.GIFTS_CLAIMED) or ""), "%d+") do
		claimed[tonumber(index) :: number] = true
	end
	local hasReady = false
	for index, gift in RetentionConfig.GIFTS do
		local tile = giftTiles[index]
		if claimed[index] then
			setState(tile, "done", "✔ REÇU")
		elseif Retention.isGiftClaimable(index, session, claimed) then
			setState(tile, "ready", "RÉCLAMER !")
			hasReady = true
		else
			setState(tile, "wait", `⏱ {Format.duration(gift.minutes * 60 - session)}`)
		end
	end
	return hasReady
end

local function refreshQuests(now: number): boolean
	local progress: { [string]: number } = {}
	for id, value in string.gmatch(tostring(attribute(PlayerAttributes.QUEST_PROGRESS) or ""), "(%w+)=(%d+)") do
		progress[id] = tonumber(value) :: number
	end
	local claimed = tostring(attribute(PlayerAttributes.QUESTS_CLAIMED) or "")
	local hasReady = false
	for k, quest in Retention.questsForDay(Retention.dayOf(now)) do
		local row = questRows[k]
		local done = math.min(progress[quest.id] or 0, quest.target)
		row.icon.Text = MENU.QUEST_ICONS[quest.id] or DEFAULT_QUEST_ICON
		row.title.Text = quest.label
		row.fill.Size = UDim2.fromScale(done / quest.target, 1)
		row.count.Text = `{done} / {quest.target}`
		local isClaimed = string.find("," .. claimed .. ",", "," .. quest.id .. ",", 1, true) ~= nil
		local reward = RewardText.label(quest.reward)
		if isClaimed then
			setState(row.tile, "done", "✔ REÇU")
		elseif done >= quest.target then
			setState(row.tile, "ready", `RÉCLAMER\n{reward}`)
			hasReady = true
		else
			setState(row.tile, "wait", `🎁 {reward}`)
		end
		row.claim:SetAttribute("QuestId", quest.id)
	end
	return hasReady
end

local function refreshWheel(now: number): boolean
	local readyAt = attribute(PlayerAttributes.WHEEL_READY_AT)
	local wait = if typeof(readyAt) == "number" then readyAt - now else 0
	if wait > 0 then
		setState(spinTile, "done", `⏱ {Format.duration(wait)}`)
	else
		setState(spinTile, "ready", "🎡 TOURNER !")
	end
	return wait <= 0
end

local function refresh()
	local now = Workspace:GetServerTimeNow()
	local giftReady = refreshGifts(now)
	local questReady = refreshQuests(now)
	local wheelReady = refreshWheel(now)
	HudButton.setAlert(hud, giftReady or questReady or wheelReady)
end

-- Les récompenses prêtes « respirent » pour attirer l'œil.
local function animate(deltaTime: number)
	clock += deltaTime
	if not window.isOpen then
		return
	end
	local scale = 1 + math.sin(clock * MENU.READY_PULSE.speed) * MENU.READY_PULSE.scale
	for _, tile in giftTiles do
		tile.pulse.Scale = if tile.state == "ready" then scale else 1
	end
	for _, row in questRows do
		row.tile.pulse.Scale = if row.tile.state == "ready" then scale else 1
	end
	spinTile.pulse.Scale = if spinTile.state == "ready" then scale else 1
	flickPointer()
end

function RetentionMenuController:Init()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "RetentionMenu"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true -- le fond assombri couvre tout l'écran
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	window = Window.new(screenGui, "Rewards", "🎁 RÉCOMPENSES")
	window.onOpen = refresh
	local tabs = Tabs.new(window.body)
	tabs:add("🎁 CADEAUX", buildGifts())
	tabs:add("📜 QUÊTES", buildQuests())
	tabs:add("🎡 ROUE", buildWheel())
	tabs:select(1)
	hud = HudButton.new(screenGui, {
		icon = "🎁",
		caption = "CADEAUX",
		top = HUD.GIFTS_TOP,
		bottom = HUD.GIFTS_BOTTOM_COLOR,
		fromBottom = HUD.GIFTS_BOTTOM,
	})
	hud.button.Activated:Connect(function()
		window:toggle()
	end)
end

function RetentionMenuController:Start()
	remotes.gift = Remotes.event(Remotes.CLAIM_GIFT)
	remotes.spin = Remotes.event(Remotes.SPIN_WHEEL)
	remotes.quest = Remotes.event(Remotes.CLAIM_QUEST)
	Remotes.event(Remotes.WHEEL_RESULT).OnClientEvent:Connect(spinTo)
	RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed >= REFRESH_INTERVAL then
			elapsed = 0
			refresh() -- même fermé : la pastille « ! » du bouton doit apparaître dès qu'un cadeau est prêt
		end
	end)
	RunService.RenderStepped:Connect(animate)
	screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
end

return RetentionMenuController
