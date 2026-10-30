--!strict
-- Mise en forme des nombres pour le HUD (CDC §10 : « +14,5 K $/s »), à la française.

local Format = {}

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi" }
local THOUSAND = 1000

-- 999 → « 999 » ; 14 500 → « 14,5 K » ; 2 000 000 → « 2 M ».
function Format.money(value: number): string
	local sign = if value < 0 then "-" else ""
	local magnitude = math.abs(value)
	if magnitude < THOUSAND then
		return sign .. tostring(math.floor(magnitude))
	end
	local exponent = math.min(#SUFFIXES, math.floor(math.log(magnitude, THOUSAND) + 1e-9))
	local scaled = math.floor(magnitude / THOUSAND ^ exponent * 10) / 10
	local text = if scaled % 1 == 0 then string.format("%d", scaled) else string.format("%.1f", scaled)
	return `{sign}{(string.gsub(text, "%.", ","))} {SUFFIXES[exponent]}`
end

-- 125 → « 2:05 » ; 3 725 → « 1:02:05 ».
function Format.duration(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local hours, minutes, secs = total // 3600, (total % 3600) // 60, total % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%d:%02d", minutes, secs)
end

return Format
