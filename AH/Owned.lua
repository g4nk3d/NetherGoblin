--[[ NetherGoblin - AH/Owned.lua
	Your own auctions, and who undercut them.

	  Owned:Query()               ask the server for your auctions (when the house opens, after
	                              every post / cancel, and from the Auctions tab)
	  Owned:List()                -> { { auctionID, itemKey, itemID, link, name, qty, unit,
	                                     buyout, bid, bidder, sold, timeLeft, status } }
	  Owned:CountUndercut()       from the last scan: auctions where someone else lists the
	                              same item for less (quick, no searches)
	  Owned:Check([cb])           exact check: each item's live listings are read (one search
	                              per item, queued) and each auction gets .ahead (how many are
	                              listed cheaper by others), .undercut, .tied (how many others
	                              list at exactly your price) and .matched (tied, not undercut)
	  Owned:CanCancel(id) / Owned:CancelCost(id)
	  Owned:Cancel(auctionID)     needs your click (the game's rule)
	  -> "OWNED_UPDATED"(list), "UNDERCUT_CHECKED"(list), "CANCELLED"(auctionID) ]]

local _, ns = ...
local NG = ns.NG
local Owned = NG:Module("Owned")
local Num, Str, Call, Open = NG.Num, NG.Str, NG.Call, NG.Open
local L = ns.L

local list = {}
Owned.list = list

function Owned:List() return list end

function Owned:Query()
	local AH = _G.C_AuctionHouse
	if not (AH and AH.QueryOwnedAuctions and NG.House:IsOpen()) then return false end
	NG.House:Send("owned", function() AH.QueryOwnedAuctions({}) end)
	return true
end

local function SoldStatus()
	local E = _G.Enum and _G.Enum.AuctionStatus
	return E and E.Sold or 1
end

local function ReadOwned()
	local AH = _G.C_AuctionHouse
	if not AH then return end
	local old = {}
	for _, a in ipairs(list) do old[a.auctionID] = a end
	NG.wipe(list)
	local n = Num(Call(AH.GetNumOwnedAuctions)) or 0
	for i = 1, n do
		local r = Open(Call(AH.GetOwnedAuctionInfo, i))
		if r and Num(r.auctionID) then
			local k = Open(r.itemKey)
			local qty = Num(r.quantity) or 1
			local commodity = k and NG.Search:IsCommodity(k)
			if commodity == nil then Owned.needInfo = true end
			local buyout = Num(r.buyoutAmount)
			-- commodities report the price of one; other items the price of the whole auction
			local unit = buyout and (commodity and buyout or math.floor(buyout / math.max(1, qty)))
			local link = Str(r.itemLink)
			local a = { auctionID = r.auctionID, itemKey = k, itemID = k and Num(k.itemID), link = link, qty = qty, unit = unit,
				buyout = buyout, bid = Num(r.bidAmount), bidder = Str(r.bidder), status = Num(r.status),
				timeLeft = Num(r.timeLeftSeconds), commodity = commodity }
			-- a commodity auction has no link: its name comes from the item key, or the item
			-- itself (asked for, and read again when it arrives)
			a.name = link and link:match("%[(.-)%]") or nil
			if not a.name and k then
				local info = AH.GetItemKeyInfo and Open(Call(AH.GetItemKeyInfo, k))
				a.name = info and Str(info.itemName) or nil
				if not a.name and a.itemID and _G.C_Item then
					a.name = C_Item.GetItemNameByID and Str(Call(C_Item.GetItemNameByID, a.itemID)) or nil
					if not a.name then
						Owned.needInfo = true
						if C_Item.RequestLoadItemDataByID then Call(C_Item.RequestLoadItemDataByID, a.itemID) end
					end
				end
			end
			a.sold = a.status == SoldStatus()
			local was = old[a.auctionID]
			if was then a.ahead, a.undercut, a.checked, a.tied, a.matched = was.ahead, was.undercut, was.checked, was.tied, was.matched end
			list[#list + 1] = a
		end
	end
	NG:Fire("OWNED_UPDATED", list)
end
NG:On("OWNED_AUCTIONS_UPDATED", function() Owned.needInfo = false ReadOwned() end)
-- an auction's item was not described yet (commodity or not): read the list again when it is
local function InfoArrived()
	if Owned.needInfo and NG.House:IsOpen() then NG:Debounce("owned info", 0.2, function() Owned.needInfo = false ReadOwned() end) end
end
NG:On("ITEM_KEY_ITEM_INFO_RECEIVED", InfoArrived)
NG:On("GET_ITEM_INFO_RECEIVED", InfoArrived)
NG:On("ITEM_DATA_LOAD_RESULT", InfoArrived)

-- the quick count after a scan: is anyone listing the same thing for less than you?
function Owned:CountUndercut()
	local n = 0
	-- your own cheapest auction of each item: the scan's lowest may simply be you
	local ownMin = {}
	for _, a in ipairs(list) do
		if not a.sold and a.unit and a.itemKey then
			local base, lv = NG.Prices:KeysOfItemKey(a.itemKey)
			local key = lv or base
			if key and (not ownMin[key] or a.unit < ownMin[key]) then ownMin[key] = a.unit end
		end
	end
	for _, a in ipairs(list) do
		if not a.sold and a.unit and a.itemKey then
			local base, lv = NG.Prices:KeysOfItemKey(a.itemKey)
			local key = lv or base
			local e = NG.Prices:Entry(key)
			if e and e.m and e.m < a.unit and e.m < (ownMin[key] or math.huge) and (e.q or 0) > 0 then
				a.undercut = true
				n = n + 1
			elseif a.undercut == nil or not a.checked then
				a.undercut = false
			end
		end
	end
	return n
end

-- exact check, item by item
local checking = nil
function Owned:Checking() return checking ~= nil end

function Owned:Check(cb)
	if checking or not NG.House:IsOpen() then return false end
	local items, seen = {}, {}
	for _, a in ipairs(list) do
		if not a.sold and a.itemKey then
			local ks = NG.Search:KeyString(a.itemKey)
			if not seen[ks] then seen[ks] = true items[#items + 1] = a.itemKey end
		end
	end
	checking = { left = #items, cb = cb }
	if #items == 0 then
		checking = nil
		NG:Fire("UNDERCUT_CHECKED", list)
		if cb then cb(list) end
		return true
	end
	for _, k in ipairs(items) do
		NG.Search:Item(k, function(d) Owned:ApplyDetail(d) end)
	end
	return true
end

function Owned:ApplyDetail(d)
	if not d then return end
	for _, a in ipairs(list) do
		if not a.sold and a.itemKey and NG.Search:KeyString(a.itemKey) == d.key and a.unit then
			local ahead, tied = 0, 0
			for _, r in ipairs(d.rows) do
				if r.unit and not r.own then
					if r.unit < a.unit then ahead = ahead + (r.qty or 1)
					elseif r.unit == a.unit then tied = tied + (r.qty or 1) end
				end
			end
			-- matched: someone lists at exactly your price (buyers may take theirs first)
			a.ahead, a.undercut, a.checked = ahead, ahead > 0, true
			a.tied, a.matched = tied, ahead == 0 and tied > 0
			a.lowest = d.lowest
		end
	end
	if checking and d.full then
		checking.left = checking.left - 1
		if checking.left <= 0 then
			local cb = checking.cb
			checking = nil
			NG:Fire("UNDERCUT_CHECKED", list)
			if cb then cb(list) end
		end
	end
end

function Owned:CanCancel(id)
	local AH = _G.C_AuctionHouse
	return AH and AH.CanCancelAuction and Call(AH.CanCancelAuction, id) and true or false
end

function Owned:CancelCost(id)
	local AH = _G.C_AuctionHouse
	return AH and AH.GetCancelCost and Num(Call(AH.GetCancelCost, id)) or 0
end

local cancelling = {}
function Owned:Cancel(id)
	local AH = _G.C_AuctionHouse
	id = Num(id)
	if not (AH and AH.CancelAuction and id and NG.House:IsOpen()) then return false end
	if not self:CanCancel(id) then
		NG:Fire("CANCEL_FAILED", L["That auction can't be cancelled (sold, or someone has bid on it)."])
		return false
	end
	local ok = pcall(AH.CancelAuction, id)
	if ok then cancelling[id] = true end
	return ok
end

NG:On("AUCTION_CANCELED", function(_, id)
	id = Num(id)
	for _, a in ipairs(list) do
		if a.auctionID == id then
			NG.Ledger:Add("cancel", { itemID = a.itemID, link = a.link, name = a.name, qty = a.qty, unit = a.unit })
			break
		end
	end
	cancelling[id or 0] = nil
	NG:Fire("CANCELLED", id)
	Owned:Query()
end)

NG:Register("AH_OPEN", function() NG:After(0.5, function() Owned:Query() end) end)
NG:Register("POSTED", function() NG:After(0.5, function() Owned:Query() end) end)
NG:Register("AH_CLOSED", function() checking = nil NG.wipe(cancelling) end)
