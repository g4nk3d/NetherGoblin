--[[ NetherGoblin - AH/Scan.lua
	The quick scan: every item on the auction house with its cheapest price, in a few seconds.

	It is one browse search for everything. The server answers with one row per item (the
	lowest price and how many are listed), page by page. Each page is folded into the price
	database inside the frame budget (Core/Scheduler.lua) while the next page is being asked
	for, so network and work overlap and the game never hitches. No table per auction, no
	closure per row.

	  Scan:Start([reason])     needs the auction house open
	  Scan:Cancel(why)         a search of yours replaces the scan (the game keeps one browse)
	  Scan:IsRunning()
	  Scan:Progress()          rows done, rows received, full?
	  Scan:Last()              the last finished scan: { at, items, seconds }
	  Scan:Stale()             older than the "scan.autoAge" setting

	Fires "SCAN_STARTED", "SCAN_PROGRESS"(done, received), "SCAN_CANCELLED"(why) and
	"SCAN_DONE"(summary): { items, seconds, newLows, deals, undercut } (undercut counted by
	AH/Owned.lua from your own auctions). ]]

local _, ns = ...
local NG = ns.NG
local Scan = NG:Module("Scan")
local Num, Call, Open = NG.Num, NG.Call, NG.Open
local floor = math.floor

local S = nil   -- the running scan

function Scan:IsRunning() return S ~= nil end
function Scan:Progress()
	if not S then return 0, 0, true end
	return S.done, S.received, S.full
end

function Scan:Last()
	local r = NG.Prices:Realm()
	return r and r.scan or {}
end

function Scan:Stale()
	local last = self:Last().at
	if not last then return true end
	local age = tonumber(NG.Settings:Get("scan.autoAge")) or 30
	return NG:Now() - last > age * 60
end

local function SortPrice()
	local E = _G.Enum and _G.Enum.AuctionHouseSortOrder
	return E and E.Price or 0
end

local function Request(first)
	local AH = _G.C_AuctionHouse
	if not S then return end
	S.waiting = true
	S.sent = false   -- results that arrive before our request went out belong to someone else
	if first then
		local q = { searchString = "", sorts = { { sortOrder = SortPrice(), reverseSort = false } }, filters = {}, itemClassFilters = {} }
		NG.House:Send("scan", function() if S then S.sent = true end AH.SendBrowseQuery(q) end)
	else
		NG.House:Send("scan more", function() if S then S.sent = true end AH.RequestMoreBrowseResults() end)
	end
end

-- the work: fold rows into the database, a slice per frame
local function Work()
	local P, Sch = NG.Prices, NG.Scheduler
	local scanMin = S.scanMin
	while true do
		local page = table.remove(S.pages, 1)
		if page then
			for i = 1, #page do
				local r = Open(page[i])
				if r then
					local base, lv = P:KeysOfItemKey(r.itemKey)
					local price, qty = Num(r.minPrice), Num(r.totalQuantity) or 0
					if base and price and price > 0 then
						-- a deal: well under what it usually costs (before today's sighting counts)
						local mv = P:Market(base)
						if mv and price <= mv * 0.8 then S.deals = S.deals + 1 end
						if lv then
							if P:Record(lv, price, qty) then S.newLows = S.newLows + 1 end
							S.seen[lv] = true
						end
						local m = scanMin[base]
						if not m then
							local old = P:Entry(base)
							if not (old and old.m) or old.m ~= price then S.changed = S.changed + 1 end
						end
						if not m or price < m then
							scanMin[base] = price
							local newLow = P:Record(base, price, (S.qty[base] or 0) + qty)
							if newLow and not lv then S.newLows = S.newLows + 1 end
						end
						S.qty[base] = (S.qty[base] or 0) + qty
						if not S.seen[base] then S.seen[base] = true S.items = S.items + 1 end
						-- names for the guild price check ("@Linen Cloth"), when the game has them
						local id = Num(r.itemKey.itemID)
						if id and not lv and _G.C_Item and C_Item.GetItemNameByID then
							local name = Call(C_Item.GetItemNameByID, id)
							if name then P:NoteName(id, name) end
						end
					end
				end
				S.done = S.done + 1
				if i % 25 == 0 then Sch:Step() end
			end
			NG:Fire("SCAN_PROGRESS", S.done, S.received)
		elseif S.full then
			break
		else
			coroutine.yield()   -- waiting for the next page
		end
	end
	-- items not listed any more: their count drops to zero (their history stays). Not after a
	-- scan that saw far less than the last one: that was a cut-short answer, not an empty house.
	local last = P:Realm().scan
	if not (last and last.items and S.items < last.items * 0.5) then
		local r = P:Realm()
		local keys = {}
		for key in pairs(r.e) do keys[#keys + 1] = key end
		for i = 1, #keys do
			local e = r.e[keys[i]]
			if e and not S.seen[keys[i]] and (e.q or 0) > 0 then e.q = 0 end
			if i % 200 == 0 then Sch:Step() end
		end
	end
end

function Scan:Start(reason)
	if S or not (NG:HasModernAH() and NG.House:IsOpen()) then return false end
	if not NG.Prices:Realm() then return false end
	S = { started = NG:Clock(), done = 0, received = 0, items = 0, newLows = 0, deals = 0, changed = 0,
		pages = {}, seen = {}, scanMin = {}, qty = {}, full = false, reason = reason }
	NG.Prices.generation = NG.Prices.generation + 1
	NG.Scheduler:Run("scan", Work, { onDone = function(ok, err)
		if not S then return end
		if ok then Scan:Finish() elseif err ~= "cancelled" then Scan:Cancel("error") end
	end })
	Request(true)
	NG:Fire("SCAN_STARTED", reason)
	return true
end

function Scan:Cancel(why)
	if not S then return end
	S = nil
	NG.House:Drop("scan")
	NG.Scheduler:Cancel("scan")
	NG:Fire("SCAN_CANCELLED", why)
end

function Scan:Finish()
	local s = S
	S = nil
	local seconds = math.max(0, NG:Clock() - s.started)
	local r = NG.Prices:Realm()
	r.scan = { at = NG:Now(), items = s.items, seconds = floor(seconds * 10 + 0.5) / 10 }
	NG.Prices.generation = NG.Prices.generation + 1
	local summary = { items = s.items, seconds = seconds, newLows = s.newLows, deals = s.deals, changed = s.changed, undercut = 0, reason = s.reason }
	if NG.Owned then summary.undercut = NG.Owned:CountUndercut() or 0 end
	NG:Fire("SCAN_DONE", summary)
end

local function Page(isNew, added)
	if not S or not S.waiting or not S.sent then return end
	local AH = _G.C_AuctionHouse
	S.waiting = false
	local rows
	if isNew then
		rows = Call(AH.GetBrowseResults) or {}
		-- a first page arrives as the whole list so far; take only what is new
		if S.received > 0 then
			local new = {}
			for i = S.received + 1, #rows do new[#new + 1] = rows[i] end
			rows = new
		end
	else
		rows = added or {}
	end
	S.received = S.received + #rows
	S.pages[#S.pages + 1] = rows
	S.full = Call(AH.HasFullBrowseResults) and true or false
	if not S.full then Request(false) end
end

NG:On("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", function() Page(true) end)
NG:On("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", function(_, added) Page(false, Open(added)) end)
NG:On("AUCTION_HOUSE_BROWSE_FAILURE", function()
	if not S then return end
	S.fails = (S.fails or 0) + 1
	if S.fails > 3 then return Scan:Cancel("server") end
	NG:After(2, function() if S and S.waiting then Request(S.received == 0) end end)
end)
NG:Register("AH_CLOSED", function() if S then Scan:Cancel("closed") end end)

-- a scan when the auction house opens, if the last one is old
NG:Register("AH_OPEN", function()
	if NG.Settings:Get("scan.auto") and Scan:Stale() then
		NG:After(1.5, function() if NG.House:IsOpen() and not Scan:IsRunning() then Scan:Start("auto") end end)
	end
end)
