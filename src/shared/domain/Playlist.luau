--!strict
-- Choix de la musique (A74), sans API Roblox : l'ambiance selon l'état du serveur et le morceau suivant.

local Playlist = {}

export type Mood = "calm" | "boss"

-- Le boss impose son ambiance tant qu'il lui reste des PV.
function Playlist.mood(bossHp: number): Mood
	return if bossHp > 0 then "boss" else "calm"
end

-- Index du morceau suivant, tiré au hasard sans rejouer le précédent (quand il y a le choix).
-- `roll(n)` renvoie un entier entre 1 et n.
function Playlist.nextIndex(count: number, previous: number?, roll: (number) -> number): number
	assert(count > 0, "liste de morceaux vide")
	if count == 1 or previous == nil or previous < 1 or previous > count then
		return roll(count)
	end
	local index = roll(count - 1)
	return if index >= previous then index + 1 else index
end

return Playlist
