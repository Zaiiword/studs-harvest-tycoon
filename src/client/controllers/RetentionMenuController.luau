--!strict
-- Menu des récompenses 🎁 (CDC §7.4, §10) dans le style de la boutique : onglets Connexion quotidienne (A61),
-- Cadeaux (9 cadeaux de temps de jeu), Quêtes du jour (barres de progression), Roue de la Fortune (chances
-- affichées, A45), Succès (A64) et Codes (A62). Il s'ouvre seul sur la connexion quand la récompense du jour attend.
-- Le client ne fait que demander ; la roue tourne jusqu'à la case tirée par le serveur.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local RetentionConfig = require(ReplicatedStorage.Shared.config.RetentionConfig)
local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local BrickIcon = require(ReplicatedStorage.Shared.util.BrickIcon)
local Retention = require(ReplicatedStorage.Shared.domain.Retention)
local RewardText = require(ReplicatedStorage.Shared.domain.RewardText)
local Rewards = require(ReplicatedStorage.Shared.domain.Rewards)
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
type QuestRow = { icon: Frame, title: TextLabel, fill: Frame, count: TextLabel, claim: TextButton, tile: Tile }

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
local DEFAULT_QUEST_ICON = "target"

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
local loginTiles: { Tile } = {}
local loginRewards: { TextLabel } = {}
local codeBox: TextBox
local codeFeedback: TextLabel
local tabs: Tabs.Tabs
local hasAutoOpened = false
local giftRewards: { TextLabel } = {} -- montants des cadeaux, qui suivent le revenu du joueur (A59)
local wheelLabels: { { TextLabel } } = {} -- textes de chaque case de la roue (sur la roue et dans les chances)
local questRows: { QuestRow } = {}
local achievementRows: { [string]: QuestRow } = {}
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
-- Une récompense en argent vaut quelques minutes de l'usine (A59, A73) : même calcul que le serveur.
local function rewardLabel(reward: RetentionConfig.Reward): string
	local income = attribute(PlayerAttributes.FACTORY_INCOME)
	local context = Rewards.contextOf(localPlayer, if typeof(income) == "number" then income else 0)
	return RewardText.label(Rewards.resolve(reward, context))
end

local function segmentLabel(segment: RetentionConfig.WheelSegment): string
	return if segment.reward.money then rewardLabel(segment.reward) else segment.label
end

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

-- Connexion quotidienne (A61) ----------------------------------------------------------------------------------

local function buildLoginDay(page: ScrollingFrame, index: number, reward: RetentionConfig.Reward)
	local card = candy(page, "wait")
	card.LayoutOrder = index
	local day = Style.label(card, `JOUR {index}`, UDim2.new(1, -12, 0.18, 0))
	day.Position = UDim2.new(0, 6, 0.03, 0)
	local icon = BrickIcon.new(card, RewardText.icon(reward), UDim2.fromScale(1, 0.3))
	icon.Position = UDim2.fromScale(0, 0.2)
	local amount = Style.label(card, rewardLabel(reward), UDim2.new(1, -12, 0.18, 0))
	amount.Position = UDim2.new(0, 6, 0.5, 0)
	loginRewards[index] = amount
	local pill = Instance.new("Frame")
	pill.AnchorPoint = Vector2.new(0.5, 1)
	pill.Position = UDim2.new(0.5, 0, 1, -8)
	pill.Size = UDim2.new(1, -16, 0.24, 0)
	pill.BackgroundColor3 = Bricks.rgb(WINDOW.STROKE_COLOR)
	pill.BackgroundTransparency = 0.35
	Style.corner(pill, CIRCLE)
	pill.Parent = card
	local status = Style.label(pill, "", UDim2.new(1, -10, 1, -6))
	status.Position = UDim2.fromOffset(5, 3)
	card.Activated:Connect(function()
		remotes.login:FireServer()
	end)
	loginTiles[index] = newTile(card, icon, status)
end

local function buildLogin(): ScrollingFrame
	local page = Grid.page({
		minWidth = GIFT_MIN_WIDTH,
		height = MENU.GIFT_HEIGHT,
		minColumns = MENU.LOGIN_COLUMNS,
		maxColumns = MENU.LOGIN_COLUMNS,
		padding = PAD,
	})
	for index, reward in RetentionConfig.LOGIN_REWARDS do
		buildLoginDay(page, index, reward)
	end
	return page
end

-- Codes (A62) --------------------------------------------------------------------------------------------------

local function buildCodes(): Frame
	local page = Instance.new("Frame")
	page.BackgroundTransparency = 1
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, PAD)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = page
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, PAD * 2)
	padding.Parent = page
	local title = Style.label(page, "Entre un code pour recevoir un cadeau !", UDim2.new(0.9, 0, 0, 40))
	title.LayoutOrder = 1
	codeBox = Instance.new("TextBox")
	codeBox.LayoutOrder = 2
	codeBox.Size = UDim2.new(0.7, 0, 0, MENU.CODE_HEIGHT)
	codeBox.BackgroundColor3 = Bricks.rgb(MENU.QUEST_TOP)
	codeBox.PlaceholderText = "CODE"
	codeBox.Text = ""
	codeBox.ClearTextOnFocus = false
	codeBox.Font = (Enum.Font :: any)[UiConfig.FONT]
	codeBox.TextScaled = true
	codeBox.TextColor3 = Bricks.rgb(WINDOW.STROKE_COLOR)
	Style.corner(codeBox, UDim.new(0, UiConfig.CORNER_RADIUS))
	Style.stroke(codeBox, WINDOW.STROKE_COLOR, 3)
	codeBox.Parent = page
	local submit = candy(page, "ready")
	submit.LayoutOrder = 3
	submit.Size = UDim2.new(0.45, 0, 0, SPIN_HEIGHT)
	Style.label(submit, "VALIDER", UDim2.new(1, -12, 1, -12)).Position = UDim2.fromOffset(6, 6)
	local function send()
		if codeBox.Text ~= "" then
			remotes.code:FireServer(codeBox.Text)
		end
	end
	submit.Activated:Connect(send)
	codeBox.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed then
			send()
		end
	end)
	codeFeedback = Style.label(page, "", UDim2.new(0.9, 0, 0, 34))
	codeFeedback.LayoutOrder = 4
	local hint = Style.label(page, "Des codes sont offerts à chaque mise à jour !", UDim2.new(0.9, 0, 0, 26))
	hint.LayoutOrder = 5
	hint.TextTransparency = 0.25
	return page
end

local function onCodeResult(isOk: boolean, message: string)
	codeFeedback.Text = message
	codeFeedback.TextColor3 = Bricks.rgb(if isOk then MENU.CODE_OK else MENU.CODE_ERROR)
	if isOk then
		codeBox.Text = ""
	end
end

-- Cadeaux ----------------------------------------------------------------------------------------------------

local function buildGift(page: ScrollingFrame, index: number, gift: RetentionConfig.Gift)
	local card = candy(page, "wait")
	card.LayoutOrder = index
	local icon = BrickIcon.new(card, RewardText.icon(gift.reward), UDim2.fromScale(1, 0.38))
	icon.Position = UDim2.fromScale(0, 0.04)
	local reward = Style.label(card, rewardLabel(gift.reward), UDim2.new(1, -12, 0.22, 0))
	reward.Position = UDim2.new(0, 6, 0.42, 0)
	giftRewards[index] = reward
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
	local icon = BrickIcon.new(row, DEFAULT_QUEST_ICON, UDim2.new(0, MENU.QUEST_HEIGHT - PAD, 1, -PAD))
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
		local questId = claim:GetAttribute("QuestId")
		if questId then
			remotes.quest:FireServer(questId)
		end
	end)
	table.insert(questRows, questRow)
end

local function listPage(): ScrollingFrame
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
	return page
end

local function buildQuests(): ScrollingFrame
	local page = listPage()
	for order = 1, RetentionConfig.QUESTS_PER_DAY do
		buildQuestRow(page, order)
	end
	return page
end

-- Succès (A64) : une ligne par famille, qui montre le prochain palier à atteindre.
local function buildAchievements(): ScrollingFrame
	local page = listPage()
	for order, def in RetentionConfig.ACHIEVEMENTS do
		buildQuestRow(page, order)
		local row = table.remove(questRows) :: QuestRow -- même ligne que les quêtes, rangée à part
		BrickIcon.set(row.icon, def.icon)
		row.claim.Activated:Connect(function()
			remotes.achievement:FireServer(def.id)
		end)
		achievementRows[def.id] = row
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
		local text = Style.label(chip, segmentLabel(segment), UDim2.new(1, -6, 1, -4))
		text.Position = UDim2.fromOffset(3, 2)
		wheelLabels[index] = { text }
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
	BrickIcon.new(hub, "star", UDim2.fromScale(0.8, 0.8)).Position = UDim2.fromScale(0.1, 0.1)
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
		local name = Style.label(row, segmentLabel(segment), UDim2.new(0.68, -8, 1, -6))
		table.insert(wheelLabels[index], name)
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
		RewardPopup.show(RewardText.icon(reward), rewardLabel(reward))
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

local function refreshLogin(now: number): boolean
	local state = Retention.newState()
	local lastDay, streak = attribute(PlayerAttributes.LOGIN_LAST_DAY), attribute(PlayerAttributes.LOGIN_STREAK)
	state.login.lastDay = if typeof(lastDay) == "number" then lastDay else -1
	state.login.streak = if typeof(streak) == "number" then streak else 0
	local status = Retention.loginStatus(state, Retention.dayOf(now))
	for index, reward in RetentionConfig.LOGIN_REWARDS do
		loginRewards[index].Text = rewardLabel(reward)
		local tile = loginTiles[index]
		local isToday = index == status.index
		if index > status.index then
			setState(tile, "wait", if index == status.index + 1 then "DEMAIN" else `J+{index - status.index}`)
		elseif isToday and status.isClaimable then
			setState(tile, "ready", "RÉCLAMER !")
		else
			setState(tile, "done", "✔ REÇU") -- jours précédents de la série, ou aujourd'hui déjà réclamé
		end
	end
	return status.isClaimable
end

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
		giftRewards[index].Text = rewardLabel(gift.reward)
		if claimed[index] then
			setState(tile, "done", "✔ REÇU")
		elseif Retention.isGiftClaimable(index, session, claimed) then
			setState(tile, "ready", "RÉCLAMER !")
			hasReady = true
		else
			setState(tile, "wait", `dans {Format.duration(gift.minutes * 60 - session)}`)
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
		BrickIcon.set(row.icon, MENU.QUEST_ICONS[quest.id] or DEFAULT_QUEST_ICON)
		row.title.Text = quest.label
		row.fill.Size = UDim2.fromScale(done / quest.target, 1)
		row.count.Text = `{done} / {quest.target}`
		local isClaimed = string.find("," .. claimed .. ",", "," .. quest.id .. ",", 1, true) ~= nil
		local reward = rewardLabel(quest.reward)
		if isClaimed then
			setState(row.tile, "done", "✔ REÇU")
		elseif done >= quest.target then
			setState(row.tile, "ready", `RÉCLAMER\n{reward}`)
			hasReady = true
		else
			setState(row.tile, "wait", reward)
		end
		row.claim:SetAttribute("QuestId", quest.id)
	end
	return hasReady
end

local function parseCounts(name: string): { [string]: number }
	local counts: { [string]: number } = {}
	for id, value in string.gmatch(tostring(attribute(name) or ""), "(%w+)=(%d+)") do
		counts[id] = tonumber(value) :: number
	end
	return counts
end

local function refreshAchievements(): boolean
	local state = Retention.newState()
	state.stats = parseCounts(PlayerAttributes.STATS)
	state.achievements = parseCounts(PlayerAttributes.ACHIEVEMENTS)
	local hasReady = false
	for _, def in RetentionConfig.ACHIEVEMENTS do
		local row = achievementRows[def.id]
		local status = Retention.achievementStatus(state, def)
		local done = math.min(status.progress, status.target)
		local label = string.gsub(def.label, "{n}", Format.money(status.target))
		row.title.Text = `{label}  ({status.tier}/{#def.targets})`
		row.fill.Size = UDim2.fromScale(done / status.target, 1)
		row.count.Text = `{Format.money(done)} / {Format.money(status.target)}`
		if status.isMaxed then
			setState(row.tile, "done", "✔ TERMINÉ")
		elseif status.isClaimable then
			setState(row.tile, "ready", `RÉCLAMER\n{status.gems} gemmes`)
			hasReady = true
		else
			setState(row.tile, "wait", `{status.gems} gemmes`)
		end
	end
	return hasReady
end

local function refreshWheel(now: number): boolean
	for index, segment in RetentionConfig.WHEEL do
		for _, label in wheelLabels[index] do
			label.Text = segmentLabel(segment)
		end
	end
	local readyAt = attribute(PlayerAttributes.WHEEL_READY_AT)
	local wait = if typeof(readyAt) == "number" then readyAt - now else 0
	if wait > 0 then
		setState(spinTile, "done", `dans {Format.duration(wait)}`)
	else
		setState(spinTile, "ready", "TOURNER !")
	end
	return wait <= 0
end

local function refresh()
	local now = Workspace:GetServerTimeNow()
	local loginReady = refreshLogin(now)
	local giftReady = refreshGifts(now)
	local questReady = refreshQuests(now)
	local wheelReady = refreshWheel(now)
	local achievementReady = refreshAchievements()
	HudButton.setAlert(hud, loginReady or giftReady or questReady or wheelReady or achievementReady)
	-- La récompense du jour attend : le menu s'ouvre seul, une fois par session, une fois le profil chargé. Jamais à
	-- la toute première visite (A68) : un nouveau joueur doit d'abord jouer, la pastille « ! » suffit.
	local lastLoginDay = attribute(PlayerAttributes.LOGIN_LAST_DAY)
	local isReturning = typeof(lastLoginDay) == "number" and lastLoginDay >= 0
	if loginReady and isReturning and not hasAutoOpened and attribute(PlayerAttributes.IS_DATA_LOADED) == true then
		hasAutoOpened = true
		task.delay(MENU.LOGIN_AUTO_OPEN_DELAY, function()
			tabs:select(1)
			window:open()
		end)
	end
end

-- Les récompenses prêtes « respirent » pour attirer l'œil.
local function animate(deltaTime: number)
	clock += deltaTime
	if not window.isOpen then
		return
	end
	local scale = 1 + math.sin(clock * MENU.READY_PULSE.speed) * MENU.READY_PULSE.scale
	for _, list in { giftTiles, loginTiles } do
		for _, tile in list do
			tile.pulse.Scale = if tile.state == "ready" then scale else 1
		end
	end
	for _, rows in { questRows, achievementRows } :: { { [any]: QuestRow } } do
		for _, row in rows do
			row.tile.pulse.Scale = if row.tile.state == "ready" then scale else 1
		end
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
	window = Window.new(screenGui, "Rewards", "RÉCOMPENSES")
	window.onOpen = refresh
	tabs = Tabs.new(window.body)
	tabs:add("JOUR", buildLogin())
	tabs:add("CADEAUX", buildGifts())
	tabs:add("QUÊTES", buildQuests())
	tabs:add("SUCCÈS", buildAchievements())
	tabs:add("ROUE", buildWheel())
	tabs:add("CODES", buildCodes())
	tabs:select(2)
	hud = HudButton.new(screenGui, {
		icon = "gift",
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
	remotes.login = Remotes.event(Remotes.CLAIM_LOGIN)
	remotes.achievement = Remotes.event(Remotes.CLAIM_ACHIEVEMENT)
	remotes.code = Remotes.event(Remotes.REDEEM_CODE)
	Remotes.event(Remotes.CODE_RESULT).OnClientEvent:Connect(onCodeResult)
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
