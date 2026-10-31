--!strict
-- Menu de rétention 🎁 (CDC §7.4, §10) : 9 cadeaux de temps de jeu, 3 quêtes du jour, Roue de la Fortune
-- (chances affichées, A45). Le client ne fait que demander ; la roue tourne jusqu'à la case tirée par le serveur.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local RetentionConfig = require(ReplicatedStorage.Shared.config.RetentionConfig)
local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local Retention = require(ReplicatedStorage.Shared.domain.Retention)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)
local Remotes = require(ReplicatedStorage.Shared.net.Remotes)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)
local Format = require(ReplicatedStorage.Shared.util.Format)

local RetentionMenuController = {}

local MENU = UiConfig.RETENTION_MENU
local FONT = (Enum.Font :: any)[UiConfig.FONT] :: Enum.Font
local REFRESH_INTERVAL = 0.5

local localPlayer = Players.LocalPlayer
local screenGui: ScreenGui
local panel: Frame
local giftButtons: { TextButton } = {}
local questRows: { { label: TextLabel, button: TextButton } } = {}
local wheel: Frame
local spinButton: TextButton
local remotes: { [string]: RemoteEvent } = {}
local elapsed = 0

local function rounded(gui: GuiObject, radius: UDim?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or UDim.new(0, UiConfig.CORNER_RADIUS)
	corner.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = UiConfig.STROKE_THICKNESS
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = gui
end

local function newButton(parent: Instance, size: UDim2, position: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Size, button.Position = size, position
	button.BackgroundColor3 = Bricks.rgb(MENU.LOCKED_COLOR)
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = FONT
	button.TextScaled = true
	rounded(button)
	button.Parent = parent
	return button
end

local function newText(parent: Instance, size: UDim2, position: UDim2, text: string): TextLabel
	local label = Instance.new("TextLabel")
	label.Size, label.Position = size, position
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = parent
	return label
end

local function rewardText(reward: RetentionConfig.Reward): string
	if reward.money then
		return `{Format.money(reward.money)} $`
	elseif reward.gems then
		return `{reward.gems} 💎`
	end
	return `{reward.count or 1} × {reward.item}`
end

local function buildGifts()
	local size = MENU.GIFT_SIZE
	for index in RetentionConfig.GIFTS do
		local column, row = (index - 1) % 3, (index - 1) // 3
		local position = UDim2.fromOffset(12 + column * (size + 6), 48 + row * (size * 0.6 + 6))
		local button = newButton(panel, UDim2.fromOffset(size, size * 0.6), position)
		button.Activated:Connect(function()
			remotes.gift:FireServer(index)
		end)
		giftButtons[index] = button
	end
end

local function buildQuests()
	local top = 48 + 3 * (MENU.GIFT_SIZE * 0.6 + 6) + 12
	for k = 1, RetentionConfig.QUESTS_PER_DAY do
		local y = top + (k - 1) * (MENU.ROW_HEIGHT + 6)
		local label = newText(panel, UDim2.fromOffset(250, MENU.ROW_HEIGHT), UDim2.fromOffset(12, y), "")
		label.TextXAlignment = Enum.TextXAlignment.Left
		local button = newButton(panel, UDim2.fromOffset(60, MENU.ROW_HEIGHT), UDim2.fromOffset(266, y))
		table.insert(questRows, { label = label, button = button })
	end
end

local function buildWheel()
	local size = MENU.WHEEL_SIZE
	local x = MENU.WIDTH - size - 24
	newText(panel, UDim2.fromOffset(size, 24), UDim2.fromOffset(x, 40), "▼")
	wheel = Instance.new("Frame")
	wheel.Size, wheel.Position = UDim2.fromOffset(size, size), UDim2.fromOffset(x, 64)
	wheel.BackgroundColor3 = Bricks.rgb(UiConfig.BAG_BAR.BACKGROUND)
	rounded(wheel, UDim.new(0.5, 0))
	wheel.Parent = panel
	local count = #RetentionConfig.WHEEL
	for index, segment in RetentionConfig.WHEEL do
		local angle = math.rad((index - 0.5) * 360 / count)
		local label = newText(wheel, UDim2.fromOffset(70, 22), UDim2.new(0.5, 0, 0.5, 0), segment.label)
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.new(0.5 + 0.36 * math.sin(angle), 0, 0.5 - 0.36 * math.cos(angle), 0)
		label.Rotation = math.deg(angle)
		label.TextColor3 = Bricks.rgb(segment.color)
	end
	spinButton = newButton(panel, UDim2.fromOffset(size, 36), UDim2.fromOffset(x, 64 + size + 8))
	spinButton.Activated:Connect(function()
		remotes.spin:FireServer()
	end)
	local total = 0
	for _, segment in RetentionConfig.WHEEL do
		total += segment.weight
	end
	local odds = {}
	for _, segment in RetentionConfig.WHEEL do
		table.insert(odds, `{segment.label} {math.floor(segment.weight / total * 1000 + 0.5) / 10} %`)
	end
	local oddsLabel =
		newText(panel, UDim2.fromOffset(size, 70), UDim2.fromOffset(x, 64 + size + 50), table.concat(odds, " · "))
	oddsLabel.TextWrapped = true
end

-- Fait tourner la roue pour que la case tirée par le serveur s'arrête sous le pointeur.
local function spinTo(index: number)
	local count = #RetentionConfig.WHEEL
	local target = 360 * MENU.SPIN_TURNS - (index - 0.5) * 360 / count
	wheel.Rotation = 0
	local info = TweenInfo.new(MENU.SPIN_SECONDS, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	TweenService:Create(wheel, info, { Rotation = target }):Play()
end

local function attribute(name: string): any
	return localPlayer:GetAttribute(name)
end

local function setState(button: TextButton, text: string, isReady: boolean)
	button.Text = text
	button.BackgroundColor3 = Bricks.rgb(if isReady then MENU.READY_COLOR else MENU.LOCKED_COLOR)
end

local function refreshGifts(now: number)
	local started = attribute(PlayerAttributes.SESSION_STARTED_AT)
	local session = if typeof(started) == "number" then now - started else 0
	local claimed: { [number]: boolean } = {}
	for index in string.gmatch(tostring(attribute(PlayerAttributes.GIFTS_CLAIMED) or ""), "%d+") do
		claimed[tonumber(index) :: number] = true
	end
	for index, gift in RetentionConfig.GIFTS do
		local reward = rewardText(gift.reward)
		if claimed[index] then
			setState(giftButtons[index], `✔ {reward}`, false)
		elseif Retention.isGiftClaimable(index, session, claimed) then
			setState(giftButtons[index], `Réclamer\n{reward}`, true)
		else
			setState(giftButtons[index], `{Format.duration(gift.minutes * 60 - session)}\n{reward}`, false)
		end
	end
end

local function refreshQuests(now: number)
	local progress: { [string]: number } = {}
	for id, value in string.gmatch(tostring(attribute(PlayerAttributes.QUEST_PROGRESS) or ""), "(%w+)=(%d+)") do
		progress[id] = tonumber(value) :: number
	end
	local claimed = tostring(attribute(PlayerAttributes.QUESTS_CLAIMED) or "")
	for k, quest in Retention.questsForDay(Retention.dayOf(now)) do
		local row = questRows[k]
		local done = math.min(progress[quest.id] or 0, quest.target)
		row.label.Text = `{quest.label} ({done}/{quest.target}) → {rewardText(quest.reward)}`
		local isClaimed = string.find("," .. claimed .. ",", "," .. quest.id .. ",", 1, true) ~= nil
		setState(row.button, if isClaimed then "✔" else "OK", not isClaimed and done >= quest.target)
		row.button:SetAttribute("QuestId", quest.id)
	end
end

local function refreshWheel(now: number)
	local readyAt = attribute(PlayerAttributes.WHEEL_READY_AT)
	local wait = if typeof(readyAt) == "number" then readyAt - now else 0
	setState(spinButton, if wait > 0 then `Prochain tour : {Format.duration(wait)}` else "🎡 Tourner !", wait <= 0)
end

local function refresh()
	local now = Workspace:GetServerTimeNow()
	refreshGifts(now)
	refreshQuests(now)
	refreshWheel(now)
end

local function buildToggle()
	local toggle = newButton(screenGui, UDim2.fromOffset(64, 64), UDim2.new(0, 16, 1, -160))
	toggle.Text = "🎁"
	toggle.BackgroundColor3 = Bricks.rgb(MENU.READY_COLOR)
	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			refresh()
		end
	end)
end

function RetentionMenuController:Init()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "RetentionMenu"
	screenGui.ResetOnSpawn = false
	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(MENU.WIDTH, MENU.HEIGHT)
	panel.BackgroundColor3 = Bricks.rgb(UiConfig.BAG_BAR.BACKGROUND)
	panel.Visible = false
	rounded(panel)
	panel.Parent = screenGui
	newText(
		panel,
		UDim2.new(1, -24, 0, 32),
		UDim2.fromOffset(12, 6),
		"🎁 Cadeaux · 📜 Quêtes du jour · 🎡 Roue"
	)
	buildGifts()
	buildQuests()
	buildWheel()
	buildToggle()
end

function RetentionMenuController:Start()
	remotes.gift = Remotes.event(Remotes.CLAIM_GIFT)
	remotes.spin = Remotes.event(Remotes.SPIN_WHEEL)
	remotes.quest = Remotes.event(Remotes.CLAIM_QUEST)
	for _, row in questRows do
		row.button.Activated:Connect(function()
			remotes.quest:FireServer(row.button:GetAttribute("QuestId"))
		end)
	end
	Remotes.event(Remotes.WHEEL_RESULT).OnClientEvent:Connect(spinTo)
	RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if panel.Visible and elapsed >= REFRESH_INTERVAL then
			elapsed = 0
			refresh()
		end
	end)
	screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
end

return RetentionMenuController
