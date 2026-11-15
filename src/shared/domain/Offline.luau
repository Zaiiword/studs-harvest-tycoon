--!strict
-- Gains hors ligne (A60), sans API Roblox : pendant l'absence du joueur, le tapis continue de vider le silo au
-- même débit qu'en jeu. Le gain est donc borné par ce que le joueur a récolté avant de partir (« remplis ton silo
-- avant d'aller dormir »), et par TycoonConfig.OFFLINE.MAX_SECONDS.
local TycoonConfig = require("../config/TycoonConfig")
local Tycoon = require("./Tycoon")

export type Result = { seconds: number, earned: number }

local Offline = {}

local OFFLINE = TycoonConfig.OFFLINE

-- Secondes d'absence prises en compte : 0 sans date de départ connue (nouveau profil) ou si l'horloge recule.
function Offline.awaySeconds(lastSeenAt: number, now: number): number
	if lastSeenAt <= 0 or now <= lastSeenAt then
		return 0
	end
	return math.min(now - lastSeenAt, OFFLINE.MAX_SECONDS)
end

-- Fait tourner l'usine pendant l'absence. Renvoie la durée retenue et l'argent gagné (0 si trop court).
function Offline.collect(state: Tycoon.State, lastSeenAt: number, now: number, bonus: Tycoon.IncomeBonus): Result
	local seconds = Offline.awaySeconds(lastSeenAt, now)
	if seconds < OFFLINE.MIN_SECONDS then
		return { seconds = 0, earned = 0 }
	end
	return { seconds = seconds, earned = Tycoon.tick(state, seconds, bonus) }
end

return Offline
