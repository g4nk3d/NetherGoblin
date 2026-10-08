--[[ NetherGoblin - AH/Search.lua
	Asking the auction house what is for sale.

	Browse (one row per item, the cheapest price and how many are listed):
	  Search:Browse(query)          query = { text, classFilters, minLevel, maxLevel, exact }
	                                cancels a running scan (the game keeps one browse at a time)
	  Search:More()                 the next page, when there is one
	  Search:Rows() / Search:IsFull()
	  fires "BROWSE_RESULTS"(rows, full, isNew)

	One item's listings (detail):
	  Search:Item(itemKey [, cb])   commodities: every price level, cheapest first
	                                other items: every auction, cheapest buyout first
	                                cb(detail) and "ITEM_RESULTS"(detail), where
	                                detail = { key, itemKey, itemID, commodity, rows, full,
	                                           lowest, name, icon, quality }
	                                rows: { unit, qty, own, auctionID, bid, minBid, buyout,
	                                        link, timeLeft }
	  Search:KeyString(itemKey)     a stable text key for an itemKey

	Results seen here also go into the price database (they are live prices). ]]

local _, ns = ...
local NG = ns.NG
local Search = NG:Module("Search")
local Num, Str, Call, Open = NG.Num, NG.Str, NG.Call, NG.Open
local C = function() return _G.C_AuctionHouse end

local function SortOrder(name, fallback)
	local E = _G.Enum and _G.Enum.AuctionHouseSortOrder
	return E and E[name] or fallback
end

function Search:KeyString(k)
	if type(k) ~= "table" then return nil end
	return (k.itemID or 0) .. ":" .. (k.itemLevel or 0) .. ":" .. (k.itemSuffix or 0) .. ":" .. (k.battlePetSpeciesID or 0)
end

---------------------------------------------------------------------------------------------
-- Browse
---------------------------------------------------------------------------------------------
local browse = { rows = {}, full = true, query = nil, active = false }
Search.browse = browse

function Search:Rows() return browse.rows end
function Search:IsFull() return browse.full end
function Search:Query() return browse.query end

local function NoteRows(rows, from)
	local P = NG.Prices
	for i = from or 1, #rows do
		local r = Open(rows[i])
		if r then
			local base, lv = P:KeysOfItemKey(r.itemKey)
			local price, qty = Num(r.minPrice), Num(r.totalQuantity)
			if base and price and price > 0 then
				if lv then P:Record(lv, price, qty) end
				local e = P:Entry(base)
				-- the plain item keeps the cheapest of its item levels
				if not lv or not e or not e.m or price <= e.m or (e.t and NG:Now() - e.t > 600) then
					P:Record(base, price, qty)
				end
			end
		end
	end
end

function Search:Browse(query)
	local AH = C()
	if not (AH and NG.House:IsOpen()) then return false end
	query = query or {}
	if NG.Scan and NG.Scan:IsRunning() then NG.Scan:Cancel("search") end
	browse.query = query
	browse.rows = {}
	browse.full = false
	browse.active = true
	browse.started = NG:Clock()
	local q = {
		searchString = query.text or "",
		sorts = { { sortOrder = SortOrder("Price", 0), reverseSort = false } },
		filters = query.filters or {},
		itemClassFilters = query.classFilters or {},
	}
	if query.minLevel then q.minLevel = query.minLevel end
	if query.maxLevel then q.maxLevel = query.maxLevel end
	if query.text and query.text ~= "" and NG.Lists and not query.quiet then NG.Lists:NoteSearch(query.text) end
	NG.House:Send("browse", function() AH.SendBrowseQuery(q) end)
	NG:Fire("BROWSE_STARTED", query)
	return true
end

function Search:More()
	local AH = C()
	if not (AH and browse.active and not browse.full and NG.House:IsOpen()) then return end
	if browse.requested then return end
	browse.requested = true
	NG.House:Send("browse more", function() AH.RequestMoreBrowseResults() end)
end

local function BrowseUpdate(isNew, added)
	if not browse.active or (NG.Scan and NG.Scan:IsRunning()) then return end
	local AH = C()
	browse.requested = false
	if added and not isNew then
		local from = #browse.rows + 1
		for _, r in ipairs(added) do browse.rows[#browse.rows + 1] = r end
		NoteRows(browse.rows, from)
	else
		local rows = Call(AH.GetBrowseResults) or {}
		browse.rows = rows
		NoteRows(rows)
	end
	browse.full = Call(AH.HasFullBrowseResults) and true or false
	NG:Fire("BROWSE_RESULTS", browse.rows, browse.full, isNew)
end

NG:On("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", function() BrowseUpdate(true) end)
NG:On("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", function(_, added) BrowseUpdate(false, Open(added)) end)
NG:On("AUCTION_HOUSE_BROWSE_FAILURE", function()
	if browse.active and not (NG.Scan and NG.Scan:IsRunning()) then
		browse.requested = false
		NG:Fire("BROWSE_FAILED")
	end
end)
NG:Register("AH_CLOSED", function() browse.active = false browse.requested = false end)

---------------------------------------------------------------------------------------------
-- One item's listings
---------------------------------------------------------------------------------------------
local details, waiting = {}, {}    -- keyString -> detail; keyString -> { itemKey, cbs }
local pendingInfo = {}              -- itemID -> keyString waiting for the item key's info
Search.details = details

local function Info(itemKey)
	local AH = C()
	local info = AH and AH.GetItemKeyInfo and Open(Call(AH.GetItemKeyInfo, itemKey))
	return info
end

function Search:IsCommodity(itemKey)
	local info = Info(itemKey)
	if info then return info.isCommodity and true or false end
	return nil
end

local function SendDetail(ks)
	local w = waiting[ks]
	local AH = C()
	if not (w and AH) then return end
	local info = Info(w.itemKey)
	if not info then
		-- the game ignores searches for an item it has not described yet: wait for it
		pendingInfo[w.itemKey.itemID] = ks
		return
	end
	w.commodity = info.isCommodity and true or false
	w.name, w.icon, w.quality = Str(info.itemName), info.iconFileID, Num(info.quality)
	if w.commodity then
		local sorts = { { sortOrder = SortOrder("Price", 0), reverseSort = false } }
		NG.House:Send("commodity search", function() AH.SendSearchQuery(w.itemKey, sorts, false) end)
	else
		local sorts = { { sortOrder = SortOrder("Buyout", 4), reverseSort = false } }
		NG.House:Send("item search", function() AH.SendSearchQuery(w.itemKey, sorts, true) end)
	end
end

NG:On("ITEM_KEY_ITEM_INFO_RECEIVED", function(_, itemID)
	local ks = pendingInfo[itemID]
	if ks then pendingInfo[itemID] = nil SendDetail(ks) end
end)

function Search:Item(itemKey, cb)
	local AH = C()
	if not (AH and NG.House:IsOpen() and type(itemKey) == "table") then return false end
	local ks = self:KeyString(itemKey)
	local w = waiting[ks]
	if w then
		if cb then w.cbs[#w.cbs + 1] = cb end
		return true
	end
	waiting[ks] = { itemKey = itemKey, cbs = { cb }, at = NG:Clock() }
	SendDetail(ks)
	-- a search the server never answers must not block the next one for this item
	NG:After(12, function()
		local x = waiting[ks]
		if x and NG:Clock() - x.at >= 11.5 then
			-- the server never finished: hand over what arrived (or nothing) so nobody waits forever
			waiting[ks] = nil
			local d = details[ks] or { key = ks, itemKey = x.itemKey, itemID = x.itemKey.itemID, commodity = x.commodity, rows = {}, full = true, timedOut = true, name = x.name, icon = x.icon, quality = x.quality, at = NG:Clock() }
			d.full = true
			for _, cb in ipairs(x.cbs) do NG:Safe("item search answer", cb, d) end
			NG:Fire("ITEM_RESULTS", d)
		end
	end)
	return true
end

function Search:Detail(itemKey) return details[self:KeyString(itemKey)] end

local function Deliver(ks, d)
	details[ks] = d
	local w = waiting[ks]
	if d.full then
		waiting[ks] = nil
		if w then for _, cb in ipairs(w.cbs) do NG:Safe("item search answer", cb, d) end end
	else
		-- a long list arrives in pages: ask for the rest, the callbacks run when it is whole
		Search:MoreItem(d)
	end
	NG:Fire("ITEM_RESULTS", d)
end

local function FindWaitingByID(itemID)
	for ks, w in pairs(waiting) do
		if w.itemKey.itemID == itemID and w.commodity then return ks, w end
	end
	-- a commodity search started elsewhere (the game's own window): describe it anyway
	return nil
end

local function CommodityResults(itemID)
	itemID = Num(itemID)
	local AH = C()
	if not (itemID and AH) then return end
	local ks, w = FindWaitingByID(itemID)
	local itemKey = w and w.itemKey or { itemID = itemID, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 }
	ks = ks or Search:KeyString(itemKey)
	local rows = {}
	local n = Num(Call(AH.GetNumCommoditySearchResults, itemID)) or 0
	for i = 1, n do
		local r = Open(Call(AH.GetCommoditySearchResultInfo, itemID, i))
		if r then
			rows[#rows + 1] = { unit = Num(r.unitPrice), qty = Num(r.quantity) or 0, own = (Num(r.numOwnerItems) or 0) > 0 or r.containsOwnerItem and true or false,
				ownQty = Num(r.numOwnerItems) or 0, timeLeft = Num(r.timeLeftSeconds) }
		end
	end
	local full = true
	if AH.HasFullCommoditySearchResults then full = Call(AH.HasFullCommoditySearchResults, itemID) ~= false end
	local d = { key = ks, itemKey = itemKey, itemID = itemID, commodity = true, rows = rows, full = full and true or false,
		lowest = rows[1] and rows[1].unit, name = w and w.name, icon = w and w.icon, quality = w and w.quality, at = NG:Clock() }
	if d.lowest then
		local qty = 0
		for _, r in ipairs(rows) do qty = qty + r.qty end
		NG.Prices:Record(itemID, d.lowest, qty)
	end
	Deliver(ks, d)
end

local function ItemResults(itemKey)
	local AH = C()
	itemKey = Open(itemKey)
	if not (AH and itemKey) then return end
	local ks = Search:KeyString(itemKey)
	local w = waiting[ks]
	local rows = {}
	local n = Num(Call(AH.GetNumItemSearchResults, itemKey)) or 0
	for i = 1, n do
		local r = Open(Call(AH.GetItemSearchResultInfo, itemKey, i))
		if r then
			local qty = Num(r.quantity) or 1
			local buyout = Num(r.buyoutAmount)
			rows[#rows + 1] = { auctionID = Num(r.auctionID), qty = qty, buyout = buyout, unit = buyout and math.floor(buyout / math.max(1, qty)),
				bid = Num(r.bidAmount), minBid = Num(r.minBid), link = Str(r.itemLink), own = r.containsOwnerItem and true or false,
				timeLeft = Num(r.timeLeft), bidder = Str(r.bidder) }
		end
	end
	-- cheapest buyout first; bid-only auctions last
	table.sort(rows, function(a, b)
		if a.unit and b.unit then return a.unit < b.unit end
		return a.unit ~= nil
	end)
	local full = true
	if AH.HasFullItemSearchResults then full = Call(AH.HasFullItemSearchResults, itemKey) ~= false end
	local d = { key = ks, itemKey = itemKey, itemID = itemKey.itemID, commodity = false, rows = rows, full = full and true or false,
		lowest = rows[1] and rows[1].unit, name = w and w.name, icon = w and w.icon, quality = w and w.quality, at = NG:Clock() }
	if d.lowest then
		local base, lv = NG.Prices:KeysOfItemKey(itemKey)
		if lv then NG.Prices:Record(lv, d.lowest, #rows) end
		local e = base and NG.Prices:Entry(base)
		if base and (not e or not e.m or d.lowest <= e.m) then NG.Prices:Record(base, d.lowest, #rows) end
	end
	Deliver(ks, d)
end
NG:On("COMMODITY_SEARCH_RESULTS_UPDATED", function(_, itemID) CommodityResults(itemID) end)
NG:On("COMMODITY_SEARCH_RESULTS_ADDED", function(_, itemID) CommodityResults(itemID) end)
NG:On("ITEM_SEARCH_RESULTS_UPDATED", function(_, itemKey) ItemResults(itemKey) end)
NG:On("ITEM_SEARCH_RESULTS_ADDED", function(_, itemKey) ItemResults(itemKey) end)

-- more listings for an item (the server sends long lists in pages)
function Search:MoreItem(d)
	local AH = C()
	if not (AH and d and not d.full and NG.House:IsOpen()) then return end
	if d.commodity then
		if AH.RequestMoreCommoditySearchResults then
			NG.House:Send("commodity more", function() AH.RequestMoreCommoditySearchResults(d.itemID) end)
		end
	elseif AH.RequestMoreItemSearchResults then
		NG.House:Send("item more", function() AH.RequestMoreItemSearchResults(d.itemKey) end)
	end
end

NG:Register("AH_CLOSED", function() NG.wipe(waiting) NG.wipe(pendingInfo) NG.wipe(details) end)
