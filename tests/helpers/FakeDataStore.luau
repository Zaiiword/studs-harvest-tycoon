--!strict
-- Faux DataStore pour les tests (docs/CLEAN_CODE.md §1.2 « D ») : même sémantique qu'UpdateAsync, copie
-- profonde à chaque lecture/écriture (comme une sérialisation JSON) et pannes simulables.

local FakeDataStore = {}
FakeDataStore.__index = FakeDataStore

type FakeData = { records: { [string]: any }, failuresLeft: number, calls: number }
export type FakeDataStore = typeof(setmetatable({} :: FakeData, FakeDataStore))

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value do
		copy[key] = deepCopy(child)
	end
	return copy
end

function FakeDataStore.new(): FakeDataStore
	return setmetatable({ records = {}, failuresLeft = 0, calls = 0 }, FakeDataStore)
end

-- Les `count` prochains appels lèveront une erreur (quota dépassé, panne réseau…).
function FakeDataStore.failNext(self: FakeDataStore, count: number)
	self.failuresLeft = count
end

function FakeDataStore.update(self: FakeDataStore, key: string, transform: (any) -> any): any
	self.calls += 1
	if self.failuresLeft > 0 then
		self.failuresLeft -= 1
		error("DataStore indisponible (simulé)")
	end
	local result = transform(deepCopy(self.records[key]))
	if result ~= nil then
		self.records[key] = deepCopy(result)
	end
	return deepCopy(result)
end

-- Adaptateur attendu par ProfileStore.
function FakeDataStore.adapter(self: FakeDataStore): any
	return {
		update = function(key: string, transform: (any) -> any)
			return self:update(key, transform)
		end,
	}
end

return FakeDataStore
