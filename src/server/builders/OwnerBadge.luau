--!strict
-- Tête du propriétaire, en grand au-dessus de sa grange (A58) : on repère sa base et celle des autres de loin.
-- Le panneau se mesure en studs : il reste à l'échelle de la grange, quelle que soit la distance.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FarmConfig = require(ReplicatedStorage.Shared.config.FarmConfig)
local UiConfig = require(ReplicatedStorage.Shared.config.UiConfig)
local Scoreboard = require(ReplicatedStorage.Shared.domain.Scoreboard)
local Bricks = require(ReplicatedStorage.Shared.util.Bricks)

local OwnerBadge = {}

local BADGE = FarmConfig.OWNER_BADGE
local NAME_SHARE = 0.2 -- part de la hauteur occupée par le nom

-- `origin` : centre de la base, au niveau du pont.
function OwnerBadge.build(parent: Instance, origin: CFrame, player: Player)
	local anchor = Instance.new("Part")
	anchor.Name = "OwnerBadge"
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = origin * CFrame.new(BADGE.X, BADGE.HEIGHT, 0)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(BADGE.SIZE, BADGE.SIZE / (1 - NAME_SHARE))
	gui.LightInfluence = 0
	local head = Instance.new("ImageLabel")
	head.Size = UDim2.fromScale(1, 1 - NAME_SHARE)
	head.BackgroundColor3 = Bricks.rgb(BADGE.BACKGROUND)
	head.Image = Scoreboard.headshot(player.UserId)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = head
	local ring = Instance.new("UIStroke")
	ring.Thickness = BADGE.RING
	ring.Color = Bricks.rgb(BADGE.RING_COLOR)
	ring.Parent = head
	head.Parent = gui
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromScale(0, 1 - NAME_SHARE)
	name.Size = UDim2.fromScale(1, NAME_SHARE)
	name.Font = (Enum.Font :: any)[UiConfig.FONT]
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.Text = player.DisplayName
	local outline = Instance.new("UIStroke")
	outline.Thickness = BADGE.RING / 2
	outline.Parent = name
	name.Parent = gui
	gui.Parent = anchor
	anchor.Parent = parent
end

return OwnerBadge
