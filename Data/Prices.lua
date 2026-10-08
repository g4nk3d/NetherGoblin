--[[ NetherGoblin - Data/Prices.lua
	The price database: what everything costs on this auction house, and how that changed.

	Where: NetherGoblinDB.realms[<auction house>]. Forever runs one auction house per ruleset
	(regional unique names), so the key is the ruleset: "PvE", "PvP", "RP", "Hardcore", or a
	mix such as "RP-PvP" when the game runs one. Each is its own book; a client without game
	rules uses the realm name.

	Keys are numbers, not strings: the item ID; gear also gets its own entry per item level
	(itemLevel * 10000000 + itemID); battle pets are -speciesID. Every item is also kept under
	its plain item ID (the cheapest of its item levels), which is what tooltips fall back to.

	An entry: { m = lowest price now (copper), q = how many are listed, t = when last seen,
	            d = day of today's figures, l = today's lowest, a = today's most listed,
	            h = older days, packed "day:low:qty;day:low:qty" }
	One table per item and a short string: tens of thousands of items stay small. The whole
	auction house is packed to one CBOR string at logout (C_EncodingUtil) and unpacked the first
	time it is needed, so logging in costs nothing.

	  Prices:Realm()                       this auction house's table (unpacked on first use)
	  Prices:KeyOf(itemID, itemLevel, species)
	  Prices:KeysOfItemKey(itemKey)        -> base key, level key or nil
	  Prices:KeysOfLink(link)              -> level key or nil, base key
	  Prices:Record(key, copper, qty)      a sighting from a scan; true when it is a new low for
	                                       the days kept
	  Prices:Entry(key)
	  Prices:Lowest(key) / Prices:Market(key) / Prices:Age(key)
	  Prices:History(key)                  -> { { day, low, qty }, ... } oldest first
	  Prices:ForLink(link)                 -> entry, key (level entry first, then the plain item)
	  Prices:NameToID(name) / Prices:NoteName(itemID, name)
	  Prices:Count()                       items known here ]]

local _, ns = ...
local NG = ns.NG
local Prices = NG:Module("Prices")
local Num, Str, Call = NG.Num, NG.Str, NG.Call
local floor, tonumber, tostring, pairs, type = math.floor, tonumber, tostring, pairs, type

local LEVEL_MUL = 10000000
local realm, realmKey, market = nil, nil, setmetatable({}, { __mode = "k" })
Prices.generation = 0

---------------------------------------------------------------------------------------------
-- Which auction house
---------------------------------------------------------------------------------------------
function Prices:AuctionHouseKey()
	local GR, E = _G.C_GameRules, _G.Enum and _G.Enum.GameRule
	if GR and GR.IsGameRuleActive and E then
		-- every ruleset gets its own book: PvE, PvP, RP, Hardcore, and any mix the game runs
		-- (an RP-PvP or Hardcore-PvP realm keeps "RP-PvP" / "Hardcore-PvP"), so new rulesets at
		-- launch need no change here and never mix their prices
		local parts = {}
		if E.HardcoreRuleset and Call(GR.IsGameRuleActive, E.HardcoreRuleset) then parts[#parts + 1] = "Hardcore" end
		if E.RPRuleset and Call(GR.IsGameRuleActive, E.RPRuleset) then parts[#parts + 1] = "RP" end
		if E.PvPRuleset and Call(GR.IsGameRuleActive, E.PvPRuleset) then parts[#parts + 1] = "PvP" end
		if #parts == 0 then return "PvE" end
		return table.concat(parts, "-")
	end
	return Str(_G.GetRealmName and GetRealmName()) or "Realm"
end

local function Unpack(stored)
	if type(stored) ~= "table" then return nil end
	if stored.cbor then
		local E = _G.C_EncodingUtil
		if E and E.DeserializeCBOR then
			local ok, t = pcall(E.DeserializeCBOR, stored.cbor)
			if ok and type(t) == "table" then return t end
		end
		NG:Log("warn", "saved prices could not be unpacked; starting fresh")
		return nil
	end
	return stored
end

function Prices:Init(db)
	self.db = db
	db.realms = db.realms or {}
	db.names = db.names or {}
end

function Prices:Realm()
	if realm then return realm end
	if not self.db then return nil end
	realmKey = self:AuctionHouseKey()
	realm = Unpack(self.db.realms[realmKey]) or { v = 1, e = {}, scan = {} }
	realm.e = realm.e or {}
	realm.scan = realm.scan or {}
	self.db.realms[realmKey] = realm
	return realm
end

function Prices:RealmKey() self:Realm() return realmKey end

-- drop the cached book (tests, or when the ruleset becomes known late); it is re-read on next use
function Prices:Reload()
	if realm then self:Pack() end
	realm, realmKey = nil, nil
end

-- logout: pack this auction house into one string (the others stay packed as they were)
function Prices:Pack()
	if not (realm and self.db) then return end
	local E = _G.C_EncodingUtil
	if E and E.SerializeCBOR then
		local ok, s = pcall(E.SerializeCBOR, realm)
		if ok and type(s) == "string" then
			self.db.realms[realmKey] = { cbor = s, v = 1 }
			return true
		end
	end
	self.db.realms[realmKey] = realm
end

---------------------------------------------------------------------------------------------
-- Keys
---------------------------------------------------------------------------------------------
function Prices:KeyOf(itemID, itemLevel, species)
	species = Num(species)
	if species and species > 0 then return -species end
	itemID = Num(itemID)
	if not itemID then return nil end
	itemLevel = Num(itemLevel)
	if itemLevel and itemLevel > 1 then return itemLevel * LEVEL_MUL + itemID end
	return itemID
end

-- base key (plain item / pet), and the level key for gear (nil otherwise)
function Prices:KeysOfItemKey(k)
	if type(k) ~= "table" then return nil end
	local species = Num(k.battlePetSpeciesID)
	if species and species > 0 then return -species, nil end
	local id = Num(k.itemID)
	if not id then return nil end
	local lv = Num(k.itemLevel)
	if lv and lv > 1 and self:IsGear(id) then return id, lv * LEVEL_MUL + id end
	return id, nil
end

-- gear = something you wear (only gear gets per-level prices)
local gearCache = {}
function Prices:IsGear(itemID)
	local g = gearCache[itemID]
	if g ~= nil then return g end
	local C = _G.C_Item
	local ok = C and C.IsEquippableItem and Call(C.IsEquippableItem, itemID)
	if ok == nil and _G.IsEquippableItem then ok = Call(IsEquippableItem, itemID) end
	if ok == nil then return false end   -- not known yet: ask again next time
	gearCache[itemID] = ok and true or false
	return gearCache[itemID]
end

function Prices:IDOfLink(link)
	link = Str(link)
	if not link then return nil end
	local species = link:match("|Hbattlepet:(%d+)")
	if species then return nil, tonumber(species) end
	return tonumber(link:match("|Hitem:(%d+)") or link:match("^item:(%d+)")), nil
end

function Prices:KeysOfLink(link)
	local id, species = self:IDOfLink(link)
	if species then return nil, -species end
	if not id then return nil end
	local lvKey
	if self:IsGear(id) then
		local C = _G.C_Item
		local lv = C and C.GetDetailedItemLevelInfo and Num(Call(C.GetDetailedItemLevelInfo, link))
		if not lv and _G.GetDetailedItemLevelInfo then lv = Num(Call(GetDetailedItemLevelInfo, link)) end
		if lv and lv > 1 then lvKey = lv * LEVEL_MUL + id end
	end
	return lvKey, id
end

function Prices:ItemIDOfKey(key)
	key = Num(key)
	if not key or key < 0 then return nil end
	return key % LEVEL_MUL
end

---------------------------------------------------------------------------------------------
-- History string helpers
---------------------------------------------------------------------------------------------
local function KeepDays()
	local n = tonumber(NG.Settings and NG.Settings:Get("history.days")) or 30
	if n < 3 then n = 3 elseif n > 180 then n = 180 end
	return n
end

-- move "today" into the history string when the day has changed
local function Roll(e, today)
	if e.d and e.d ~= today and e.l then
		local seg = e.d .. ":" .. e.l .. ":" .. (e.a or 0)
		local h = e.h and (e.h .. ";" .. seg) or seg
		-- drop days older than the window (oldest first, so only the front is ever cut)
		local oldest = today - KeepDays()
		while h do
			local day = tonumber(h:match("^(%d+):"))
			if day and day < oldest then
				local cut = h:find(";", 1, true)
				h = cut and h:sub(cut + 1) or nil
			else
				break
			end
		end
		e.h = h
		e.l, e.a = nil, nil
	end
	e.d = today
end

function Prices:Record(key, copper, qty)
	local r = self:Realm()
	if not (r and key) then return false end
	copper, qty = Num(copper), Num(qty) or 0
	if not copper or copper <= 0 then return false end
	local today = NG:Today()
	local e = r.e[key]
	if not e then e = {} r.e[key] = e end
	Roll(e, today)
	-- a new low: cheaper than every day kept
	local newLow = false
	if e.h or e.l then
		local lowest = e.l
		if e.h then
			for low in e.h:gmatch("%d+:(%d+):") do
				low = tonumber(low)
				if not lowest or low < lowest then lowest = low end
			end
		end
		newLow = lowest ~= nil and copper < lowest
	end
	e.m, e.q, e.t = copper, qty, NG:Now()
	if not e.l or copper < e.l then e.l = copper end
	if not e.a or qty > e.a then e.a = qty end
	market[e] = nil
	return newLow
end

-- the same item not seen in a full scan: no longer listed (its history stays)
function Prices:MarkGone(key)
	local r = self:Realm()
	local e = r and r.e[key]
	if e then e.q = 0 end
end

function Prices:Entry(key)
	local r = self:Realm()
	return r and key and r.e[key] or nil
end

function Prices:Lowest(key)
	local e = self:Entry(key)
	return e and e.m or nil
end

function Prices:Age(key)
	local e = self:Entry(key)
	if not (e and e.t) then return nil end
	return NG:Now() - e.t
end

function Prices:History(key)
	local e = self:Entry(key)
	local out = {}
	if not e then return out end
	if e.h then
		for day, low, q in e.h:gmatch("(%d+):(%d+):(%d+)") do
			out[#out + 1] = { tonumber(day), tonumber(low), tonumber(q) }
		end
	end
	if e.d and e.l then out[#out + 1] = { e.d, e.l, e.a or 0 } end
	return out
end

-- market value: the daily lows of the last 14 days, recent days counting more
function Prices:Market(key)
	local e = self:Entry(key)
	if not e then return nil end
	local cached = market[e]
	if cached then return cached end
	local today = NG:Today()
	local sum, wsum = 0, 0
	if e.h then
		for day, low in e.h:gmatch("(%d+):(%d+):") do
			local age = today - tonumber(day)
			if age >= 0 and age < 14 then
				local w = 1 / (1 + age * 0.2)
				sum, wsum = sum + tonumber(low) * w, wsum + w
			end
		end
	end
	if e.d and e.l then
		local age = today - e.d
		if age >= 0 and age < 14 then
			local w = 1 / (1 + age * 0.2)
			sum, wsum = sum + e.l * w, wsum + w
		end
	end
	local v = wsum > 0 and floor(sum / wsum + 0.5) or e.m
	market[e] = v
	return v
end

function Prices:ForLink(link)
	local lvKey, base = self:KeysOfLink(link)
	if lvKey then
		local e = self:Entry(lvKey)
		if e then return e, lvKey end
	end
	if base then
		local e = self:Entry(base)
		if e then return e, base end
	end
	return nil, base
end

function Prices:Count()
	local r = self:Realm()
	if not r then return 0 end
	local n = 0
	for k in pairs(r.e) do if k > 0 and k < LEVEL_MUL or k < 0 then n = n + 1 end end
	return n
end

---------------------------------------------------------------------------------------------
-- Item names (typed names in the guild price check: "@Linen Cloth")
---------------------------------------------------------------------------------------------
function Prices:NoteName(itemID, name)
	itemID, name = Num(itemID), Str(name)
	if not (itemID and name and self.db) then return end
	self.db.names[name:lower()] = itemID
end

function Prices:NameToID(name)
	name = Str(name)
	if not (name and self.db) then return nil end
	name = name:gsub("^%s+", ""):gsub("%s+$", "")
	return self.db.names[name:lower()]
end
