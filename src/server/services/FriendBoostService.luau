--!strict
-- Bonus social (A63) : compte les amis de chaque joueur présents sur le serveur et publie le multiplicateur de
-- revenus (amis + Roblox Premium) dans un attribut que TycoonService lit. IsFriendsWith interroge le web :
-- chaque vérification tourne à part, sous pcall, et un échec compte simplement « pas ami ».
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Social = require(ReplicatedStorage.Shared.domain.Social)
local PlayerAttributes = require(ReplicatedStorage.Shared.net.PlayerAttributes)

local FriendBoostService = {}

local friends: { [Player]: { [Player]: boolean } } = {}

local function publish(player: Player)
	local set = friends[player]
	if not set or not player.Parent then
		return
	end
	local count = 0
	for _ in set do
		count += 1
	end
	local isPremium = player.MembershipType == Enum.MembershipType.Premium
	player:SetAttribute(PlayerAttributes.FRIENDS_ONLINE, count)
	player:SetAttribute(PlayerAttributes.SOCIAL_BOOST, Social.multiplier(count, isPremium))
end

local function link(a: Player, b: Player)
	local ok, isFriend = pcall(a.IsFriendsWith, a, b.UserId)
	if not ok or not isFriend or not friends[a] or not friends[b] then
		return
	end
	friends[a][b], friends[b][a] = true, true
	publish(a)
	publish(b)
end

local function onPlayerAdded(player: Player)
	friends[player] = {}
	publish(player)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			task.spawn(link, player, other)
		end
	end
end

local function onPlayerRemoving(player: Player)
	for other in friends[player] or {} do
		if friends[other] then
			friends[other][player] = nil
			publish(other)
		end
	end
	friends[player] = nil
end

function FriendBoostService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	Players.PlayerMembershipChanged:Connect(publish)
	for _, player in Players:GetPlayers() do
		if not friends[player] then
			onPlayerAdded(player)
		end
	end
end

return FriendBoostService
