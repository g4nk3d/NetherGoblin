--[[ NetherGoblin - Core/Init.lua
	The namespace and the plumbing every other file uses.

	  NG:Module(name)                 a module table, created once (NG.<name>)
	  NG:On(event, fn) / NG:Off(...)  game events; several handlers per event
	  NG:Register(msg, fn [, owner])  internal messages (the same bus plugins listen on)
	  NG:Fire(msg, ...)               every listener runs protected; a plugin listener's failure
	                                  counts against that plugin, never against the core
	  NG:After(s, fn)                 a timer; NG:Debounce(key, s, fn) runs once, s after the
	                                  last call with that key
	  NG:AfterCombat(key, fn)         now, or once combat ends (one waiting entry per key)
	  NG:Safe(context, fn, ...)       a protected call at a boundary (plugin, network, data)
	  NG:Log(level, fmt, ...)         the diagnostics log (never chat unless debugging)
	  NG.Num / NG.Str / NG.Open       a number / string / table, or nil (secret values and wrong
	                                  types refused)

	Only API/Plugin.lua adds a global (NetherGoblin). Everything else lives in here. ]]

local ADDON, ns = ...
local NG = { name = ADDON, modules = {} }
ns.NG = NG

NG.VERSION = "1.4.0"
NG.MEDIA = "Interface\\AddOns\\NetherGoblin\\Media\\"
NG.FONT_BODY = NG.MEDIA .. "Fonts\\Philosopher-Bold.ttf"
NG.FONT_TITLE = NG.MEDIA .. "Fonts\\Cinzel-Bold.ttf"
NG.SCHEMA = 1        -- account saved data layout
NG.CHAR_SCHEMA = 1   -- per-character saved data layout
NG.PROTOCOL = 1      -- the price-check addon messages
NG.API_VERSION = 1   -- plugin API

local type, pairs, ipairs, select, tostring, tonumber = type, pairs, ipairs, select, tostring, tonumber
local format, pcall = string.format, pcall
local tremove = table.remove
local wipe = _G.wipe or function(t) for k in pairs(t) do t[k] = nil end return t end
NG.wipe = wipe

function NG:Module(name)
	local m = self.modules[name]
	if not m then
		m = { name = name }
		self.modules[name] = m
		self[name] = m
	end
	return m
end

---------------------------------------------------------------------------------------------
-- Values the game may hand back as "secret" (Midnight API lineage) or of the wrong type
---------------------------------------------------------------------------------------------
-- looked up on every call: the client defines it, and tests may replace it
local function issecret(v)
	local f = _G.issecretvalue
	if f then return f(v) and true or false end
	return false
end
NG.IsSecret = issecret

function NG.Num(v)
	if v == nil or issecret(v) then return nil end
	v = tonumber(v)
	if v == nil or v ~= v or v == math.huge or v == -math.huge then return nil end
	return v
end

function NG.Str(v)
	if v == nil or issecret(v) or type(v) ~= "string" or v == "" then return nil end
	return v
end

-- A table that may be looked into. In a dungeon the game can hand back tooltip data (the whole
-- table, its lines, a line) as a secret table; indexing one faults.
function NG.Open(t)
	if type(t) ~= "table" or issecret(t) then return nil end
	return t
end

-- A call into the game that may error: errors become nil.
function NG.Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local function pass(ok, ...) if ok then return ... end return nil end
	return pass(pcall(fn, ...))
end

-- Forever (WoW: Forever 1.60.x) and the modern auction house it runs. Known by its version
-- string ("1.60.x") first; the interface number is a fallback, since the client it is built
-- on may report a modern one.
function NG:IsForever()
	if not _G.GetBuildInfo then return false end
	local version, _, _, build = GetBuildInfo()
	version = tostring(version or "")
	if version:match("^1%.6%d") then return true end
	build = tonumber(build) or 0
	return build >= 16000 and build < 20000
end

function NG:HasModernAH()
	local C = _G.C_AuctionHouse
	return type(C) == "table" and type(C.SendBrowseQuery) == "function" and type(C.GetBrowseResults) == "function"
end

---------------------------------------------------------------------------------------------
-- Log (diagnostics): chat only for errors (once per context) and for debug when asked
---------------------------------------------------------------------------------------------
NG.LEVELS = { error = 1, warn = 2, info = 3, debug = 4 }
local LOG_SIZE = 200
local log, logHead = {}, 0
NG.errors = { count = 0, byContext = {}, latest = nil }
NG.TITLE = "|cffe8c46aNether|r|cff8fd14fGoblin|r"

local function Chat(msg)
	local f = _G.DEFAULT_CHAT_FRAME
	if f and f.AddMessage then f:AddMessage(NG.TITLE .. ": " .. msg) end
end
NG.Chat = Chat

function NG:Print(fmt, ...)
	local ok, msg = pcall(format, tostring(fmt), ...)
	Chat(ok and msg or tostring(fmt))
end

function NG:Log(level, fmt, ...)
	local lv = self.LEVELS[level] or 3
	local limit = self.LEVELS[self.db and self.db.logLevel or "warn"] or 2
	if lv > limit then return end
	local ok, msg = pcall(format, tostring(fmt), ...)
	msg = ok and msg or tostring(fmt)
	logHead = logHead % LOG_SIZE + 1
	log[logHead] = { t = _G.GetTime and GetTime() or 0, level = level, msg = msg }
	if level == "debug" then Chat("|cff888888" .. msg .. "|r") end
end

function NG:GetLog()
	local out = {}
	for i = 0, LOG_SIZE - 1 do
		local e = log[(logHead - i - 1) % LOG_SIZE + 1]
		if e then out[#out + 1] = e end
	end
	return out
end

function NG:RecordError(context, err)
	local E = self.errors
	E.count = E.count + 1
	E.byContext[context] = (E.byContext[context] or 0) + 1
	E.latest = { context = context, err = tostring(err), t = _G.GetTime and GetTime() or 0 }
	self:Log("error", "%s: %s", context, tostring(err))
	if E.byContext[context] == 1 then
		Chat(format("|cffff6060an error in %s was caught; /goblin diag shows it.|r", tostring(context)))
	end
end

-- Protected call at a boundary. Returns true plus fn's results, or false.
function NG:Safe(context, fn, ...)
	if type(fn) ~= "function" then return false end
	local res = { pcall(fn, ...) }
	if not res[1] then
		self:RecordError(context, res[2])
		return false
	end
	return unpack(res)
end

---------------------------------------------------------------------------------------------
-- Game events
---------------------------------------------------------------------------------------------
local frame = CreateFrame("Frame")
NG.frame = frame
local handlers = {}

frame:SetScript("OnEvent", function(_, event, ...)
	local list = handlers[event]
	if not list then return end
	for i = 1, #list do
		local fn = list[i]
		if fn then
			local ok, err = pcall(fn, event, ...)
			if not ok then NG:RecordError("event " .. event, err) end
		end
	end
end)

function NG:On(event, fn)
	local list = handlers[event]
	if not list then
		list = {}
		handlers[event] = list
		if not pcall(frame.RegisterEvent, frame, event) then
			-- an event this client doesn't have: fail quietly, remember nothing
			handlers[event] = nil
			self:Log("info", "event %s is not available on this client", event)
			return false
		end
	end
	list[#list + 1] = fn
	return true
end

function NG:Off(event, fn)
	local list = handlers[event]
	if not list then return end
	for i = #list, 1, -1 do if list[i] == fn then tremove(list, i) end end
	if #list == 0 then
		handlers[event] = nil
		pcall(frame.UnregisterEvent, frame, event)
	end
end

---------------------------------------------------------------------------------------------
-- Internal message bus (also what plugins listen to)
---------------------------------------------------------------------------------------------
local bus = {}

function NG:Register(msg, fn, owner)
	if type(fn) ~= "function" then return nil end
	local list = bus[msg]
	if not list then list = {} bus[msg] = list end
	local h = { fn = fn, owner = owner }
	list[#list + 1] = h
	return h
end

function NG:Unregister(msg, h)
	local list = bus[msg]
	if not list then return end
	for i = #list, 1, -1 do if list[i] == h then tremove(list, i) end end
end

function NG:Fire(msg, ...)
	local list = bus[msg]
	if not list then return end
	for i = 1, #list do
		local h = list[i]
		if h and not (h.owner and h.owner.disabled) then
			local ok, err = pcall(h.fn, msg, ...)
			if not ok then
				if h.owner and self.Plugin then self.Plugin:Failed(h.owner, msg, err)
				else self:RecordError("message " .. msg, err) end
			end
		end
	end
end

---------------------------------------------------------------------------------------------
-- Timers
---------------------------------------------------------------------------------------------
function NG:After(s, fn)
	if _G.C_Timer and C_Timer.After then
		C_Timer.After(s or 0, function() NG:Safe("timer", fn) end)
	end
end

local debounce = {}
function NG:Debounce(key, s, fn)
	local entry = debounce[key]
	if entry then entry.fn = fn entry.gen = entry.gen + 1 else entry = { fn = fn, gen = 1 } debounce[key] = entry end
	local gen = entry.gen
	self:After(s, function()
		local e = debounce[key]
		if e and e.gen == gen then debounce[key] = nil e.fn() end
	end)
end

local afterCombat, afterOrder = {}, {}
function NG:InCombat() return _G.InCombatLockdown and InCombatLockdown() or false end
function NG:AfterCombat(key, fn)
	if not self:InCombat() then return self:Safe("after combat " .. tostring(key), fn) end
	if not afterCombat[key] then afterOrder[#afterOrder + 1] = key end
	afterCombat[key] = fn
end
NG:On("PLAYER_REGEN_ENABLED", function()
	local order = afterOrder
	afterOrder = {}
	for _, key in ipairs(order) do
		local fn = afterCombat[key]
		afterCombat[key] = nil
		if fn then NG:Safe("after combat " .. tostring(key), fn) end
	end
end)

-- seconds since 1970 (saved timestamps), and the game's own clock for intervals
function NG:Now() return _G.GetServerTime and GetServerTime() or (_G.time and time()) or 0 end
function NG:Clock() return _G.GetTime and GetTime() or 0 end
-- days since 2020-01-01 (UTC); history is kept by day
NG.EPOCH_DAY0 = 1577836800
function NG:Today() return math.floor((self:Now() - self.EPOCH_DAY0) / 86400) end
