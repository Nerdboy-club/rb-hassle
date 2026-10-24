local cache = {}
local fired = {}
local function bindable()
	local handlers = {}
	return { Fire = function(self, ...) for _, h in handlers do h(...) end end,
		Event = { Connect = function(_, f) table.insert(handlers, f) end } }
end
local fakeRemote = setmetatable({}, { __index = function(_, k) return { FireClient = function(_, _, payload) fired[k] = payload end } end })
local DB = {}
local dbFail = false
local dataStore = {
	GetAsync = function(_, key) if dbFail then error("db down") end local v = DB[key]; return v and table.clone(v) or nil end,
	SetAsync = function(_, key, value) DB[key] = value end,
}
local function load(name)
	if name == "Remotes" then return fakeRemote end
	if cache[name] then return cache[name] end
	local fn = assert(loadstring(SOURCES[name], name))
	local services = {
		DataStoreService = { GetDataStore = function() return dataStore end },
		ReplicatedStorage = { WaitForChild = function() return setmetatable({}, { __index = function(_, k) return k end }) end },
		RunService = { Heartbeat = { Connect = function() end } },
		Players = { GetPlayers = function() return {} end },
	}
	local e = setmetatable({
		script = { Parent = setmetatable({}, { __index = function(_, k) return k end }) },
		require = function(n) return load(n) end,
		game = { GetService = function(_, n) return services[n] end },
		Instance = { new = function() return bindable() end },
		Color3 = { fromRGB = function() return {} end },
		Vector3 = { new = function() return {} end },
		warn = print, os = os, task = { wait = function() end, defer = function() end },
	}, { __index = _G })
	setfenv(fn, e)
	cache[name] = fn()
	return cache[name]
end
local function check(cond, msg) if not cond then error("FAIL: " .. msg) end print("ok  " .. msg) end
