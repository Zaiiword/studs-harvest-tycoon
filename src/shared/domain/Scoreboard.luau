--!strict
-- Classements (CDC §7.4, A58), sans API Roblox : niveau d'un joueur, tri des scores et texte affiché.
local VehicleConfig = require("../config/VehicleConfig")
local Format = require("../util/Format")

export type Entry = { userId: number, score: number }

local Scoreboard = {}

-- Niveau : les paliers grimpés, tous Rebirths compris. Il ne redescend donc jamais au Rebirth (T7 = 7, T1 après un
-- Rebirth = 8).
function Scoreboard.levelOf(tier: number, rebirths: number): number
	return rebirths * #VehicleConfig.TIERS + tier
end

-- Les `limit` meilleurs scores strictement positifs, du plus haut au plus bas. À égalité, l'ordre reste stable.
function Scoreboard.top(entries: { Entry }, limit: number): { Entry }
	local ranked: { Entry } = {}
	for _, entry in entries do
		if entry.score > 0 then
			table.insert(ranked, entry)
		end
	end
	table.sort(ranked, function(a, b)
		return if a.score ~= b.score then a.score > b.score else a.userId < b.userId
	end)
	while #ranked > limit do
		table.remove(ranked)
	end
	return ranked
end

function Scoreboard.scoreText(stat: string, score: number): string
	if stat == "level" then
		return `Niv. {score}`
	elseif stat == "earned" then
		return `{Format.money(score)} $`
	elseif stat == "robux" then
		return `{Format.money(score)} R$`
	end
	return Format.money(score)
end

-- Portrait d'un joueur : l'adresse ne demande aucun appel réseau côté serveur.
function Scoreboard.headshot(userId: number): string
	return `rbxthumb://type=AvatarHeadShot&id={userId}&w=420&h=420`
end

return Scoreboard
