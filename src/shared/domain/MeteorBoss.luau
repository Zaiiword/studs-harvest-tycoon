--!strict
-- Boss Météorite (CDC §6, A40), sans API Roblox : points de vie, dégâts par joueur et classement final.
local EventConfig = require("../config/EventConfig")

export type Boss = {
	hp: number,
	maxHp: number,
	damageBy: { [number]: number }, -- UserId → dégâts infligés
}

local MeteorBoss = {}

function MeteorBoss.new(maxHp: number): Boss
	assert(maxHp > 0, "maxHp doit être > 0")
	return { hp = maxHp, maxHp = maxHp, damageBy = {} }
end

-- Dégâts d'un coup : puissance de coupe de l'outil × DAMAGE_PER_CUT_POWER.
function MeteorBoss.damageFor(cutPower: number): number
	return cutPower * EventConfig.METEOR.DAMAGE_PER_CUT_POWER
end

-- Applique des dégâts ; renvoie ceux réellement infligés (on ne compte pas au-delà des PV restants).
function MeteorBoss.hit(boss: Boss, playerId: number, amount: number): number
	if boss.hp <= 0 or amount <= 0 then
		return 0
	end
	local dealt = math.min(amount, boss.hp)
	boss.hp -= dealt
	boss.damageBy[playerId] = (boss.damageBy[playerId] or 0) + dealt
	return dealt
end

function MeteorBoss.isDefeated(boss: Boss): boolean
	return boss.hp <= 0
end

-- Les `count` meilleurs contributeurs, du plus gros dégât au plus petit (égalité : plus petit UserId d'abord).
function MeteorBoss.ranking(boss: Boss, count: number): { number }
	local ids: { number } = {}
	for id in boss.damageBy do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		local damageA, damageB = boss.damageBy[a], boss.damageBy[b]
		return if damageA == damageB then a < b else damageA > damageB
	end)
	return { table.unpack(ids, 1, math.min(count, #ids)) }
end

return MeteorBoss
