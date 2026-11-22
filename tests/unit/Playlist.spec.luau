--!strict
local TestKit = require("../TestKit")
local AudioConfig = require("../../src/shared/config/AudioConfig")
local Playlist = require("../../src/shared/domain/Playlist")
local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function fixed(value: number): (number) -> number
	return function(_: number): number
		return value
	end
end

describe("Playlist", function()
	describe("mood", function()
		it("passe en ambiance boss tant que le boss a des PV", function()
			expect(Playlist.mood(0)).toBe("calm")
			expect(Playlist.mood(1)).toBe("boss")
			expect(Playlist.mood(50000)).toBe("boss")
		end)
	end)

	describe("nextIndex", function()
		it("tire librement sans morceau précédent", function()
			expect(Playlist.nextIndex(5, nil, fixed(3))).toBe(3)
		end)

		it("ne rejoue jamais le morceau précédent quand il y a le choix", function()
			for previous = 1, 5 do
				for roll = 1, 4 do
					expect(Playlist.nextIndex(5, previous, fixed(roll)) ~= previous).toBe(true)
				end
			end
		end)

		it("couvre tous les autres morceaux", function()
			local seen = {}
			for roll = 1, 4 do
				seen[Playlist.nextIndex(5, 2, fixed(roll))] = true
			end
			expect(seen[1] and seen[3] and seen[4] and seen[5] and true or false).toBe(true)
		end)

		it("rejoue le seul morceau d'une liste d'un élément", function()
			expect(Playlist.nextIndex(1, 1, fixed(1))).toBe(1)
		end)
	end)

	describe("AudioConfig", function()
		it("a des morceaux pour chaque ambiance", function()
			expect(#AudioConfig.MUSIC.calm > 1).toBe(true)
			expect(#AudioConfig.MUSIC.boss > 0).toBe(true)
		end)
	end)
end)
