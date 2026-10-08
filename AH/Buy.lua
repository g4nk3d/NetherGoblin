--[[ NetherGoblin - AH/Buy.lua
	Buying. Every purchase needs a click of yours: the game only lets a hardware event (a click
	or a key bound to a button) spend gold. Nothing here ever buys on its own.

	Commodities (stackable goods), in two clicks:
	  Buy:Quote(itemID, qty)     click 1: the server works out the real total right now
	                             -> "BUY_QUOTE"(q) with q = { itemID, qty, unit, total, jump }
	                                (jump = % the price rose since the list was read)
	  Buy:Confirm()              click 2: buy at that quote
	  Buy:CancelQuote()
	  -> "BUY_DONE"(info) / "BUY_FAILED"(reason)

	Other items (gear, pets...), one click:
	  Buy:Buyout(row, detail)    the row's full buyout
	  Buy:Bid(row, amount, detail)
	  -> "BUY_DONE" / "BUY_FAILED"; the item's listings are read again afterwards ]]

local _, ns = ...
local NG = ns.NG
local Buy = NG:Module("Buy")
local Num, Call = NG.Num, NG.Call
local L = ns.L

local quote = nil      -- the commodity purchase in progress
local pendingBid = nil -- the bid / buyout sent, waiting for the server

function Buy:Quote(itemID, qty, listedUnit, info)
	local AH = _G.C_AuctionHouse
	itemID, qty = Num(itemID), Num(qty)
	if not (AH and AH.StartCommoditiesPurchase and itemID and qty and qty > 0 and NG.House:IsOpen()) then return false end
	quote = { itemID = itemID, qty = qty, listedUnit = Num(listedUnit), info = info, at = NG:Clock() }
	local ok = pcall(AH.StartCommoditiesPurchase, itemID, qty)
	if not ok then quote = nil return false end
	NG:Fire("BUY_QUOTING", quote)
	return true
end

function Buy:Quoting() return quote end

NG:On("COMMODITY_PRICE_UPDATED", function(_, unit, total)
	if not quote then return end
	quote.unit, quote.total = Num(unit), Num(total)
	if quote.listedUnit and quote.unit and quote.listedUnit > 0 then
		quote.jump = math.floor((quote.unit - quote.listedUnit) / quote.listedUnit * 100 + 0.5)
	end
	quote.ready = true
	quote.readyAt = NG:Clock()
	NG:Fire("BUY_QUOTE", quote)
end)

NG:On("COMMODITY_PRICE_UNAVAILABLE", function()
	if not quote then return end
	quote = nil
	NG:Fire("BUY_FAILED", L["That price is gone: someone bought those first."])
end)

function Buy:Confirm()
	local AH = _G.C_AuctionHouse
	if not (quote and quote.ready and AH and AH.ConfirmCommoditiesPurchase) then return false end
	quote.confirming = true
	local ok = pcall(AH.ConfirmCommoditiesPurchase, quote.itemID, quote.qty)
	if not ok then
		quote = nil
		NG:Fire("BUY_FAILED", L["The game refused the purchase."])
		return false
	end
	return true
end

function Buy:CancelQuote()
	local AH = _G.C_AuctionHouse
	if quote and AH and AH.CancelCommoditiesPurchase then pcall(AH.CancelCommoditiesPurchase) end
	quote = nil
	NG:Fire("BUY_QUOTE_CLEARED")
end

NG:On("COMMODITY_PURCHASE_SUCCEEDED", function()
	local q = quote
	quote = nil
	if not q then return end
	local info = q.info or {}
	NG.Ledger:Add("buy", { itemID = q.itemID, link = info.link, name = info.name, qty = q.qty, unit = q.unit, total = q.total })
	NG:Fire("BUY_DONE", { itemID = q.itemID, qty = q.qty, total = q.total, name = info.name })
	if info.itemKey and NG.Search then NG.Search:Item(info.itemKey) end
end)

NG:On("COMMODITY_PURCHASE_FAILED", function()
	if not quote then return end
	quote = nil
	NG:Fire("BUY_FAILED", L["The purchase failed (not enough gold, or the price moved)."])
end)

---------------------------------------------------------------------------------------------
-- Items: buyout and bid
---------------------------------------------------------------------------------------------
local function Place(row, amount, kind, detail)
	local AH = _G.C_AuctionHouse
	amount = Num(amount)
	if not (AH and AH.PlaceBid and row and row.auctionID and amount and amount > 0 and NG.House:IsOpen()) then return false end
	if _G.GetMoney and amount > GetMoney() then
		NG:Fire("BUY_FAILED", L["You don't have enough gold for that."])
		return false
	end
	pendingBid = { row = row, amount = amount, kind = kind, detail = detail, at = NG:Clock() }
	local ok = pcall(AH.PlaceBid, row.auctionID, amount)
	if not ok then pendingBid = nil NG:Fire("BUY_FAILED", L["The game refused the bid."]) return false end
	return true
end

function Buy:Buyout(row, detail) return Place(row, row and row.buyout, "buy", detail) end
function Buy:Bid(row, amount, detail) return Place(row, amount, "bid", detail) end

local function BidResult(success)
	local p = pendingBid
	if not p then return end
	pendingBid = nil
	local d = p.detail or {}
	if success then
		NG.Ledger:Add(p.kind, { itemID = d.itemID, link = p.row.link, name = d.name, qty = p.row.qty, total = p.amount })
		NG:Fire("BUY_DONE", { itemID = d.itemID, qty = p.row.qty, total = p.amount, name = d.name, kind = p.kind })
	else
		NG:Fire("BUY_FAILED", L["The auction house refused that bid."])
	end
	if d.itemKey and NG.Search then NG.Search:Item(d.itemKey) end
end

-- the server's answer comes as a system message (and on newer clients as its own event)
NG:On("CHAT_MSG_SYSTEM", function(_, msg)
	if not pendingBid or type(msg) ~= "string" or NG.IsSecret(msg) then return end
	if msg == _G.ERR_AUCTION_BID_PLACED then BidResult(true) end
end)
NG:On("AUCTION_HOUSE_PURCHASE_COMPLETED", function() BidResult(true) end)
NG:On("UI_ERROR_MESSAGE", function(_, _, msg)
	if not pendingBid or type(msg) ~= "string" or NG.IsSecret(msg) then return end
	if NG:Clock() - pendingBid.at < 5 then
		for _, key in ipairs({ "ERR_AUCTION_HIGHER_BID", "ERR_AUCTION_BID_INCREMENT", "ERR_AUCTION_BID_OWN", "ERR_NOT_ENOUGH_MONEY", "ERR_ITEM_NOT_FOUND", "ERR_AUCTION_DATABASE_ERROR" }) do
			if _G[key] and msg == _G[key] then return BidResult(false) end
		end
	end
end)

NG:Register("AH_CLOSED", function() quote = nil pendingBid = nil end)
