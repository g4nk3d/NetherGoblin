--[[ NetherGoblin - AH/Sell.lua
	Selling: what in your bags can go on the auction house, what to ask for it, and posting.
	Posting needs a click of yours each time (the game's rule).

	  Sell:BagItems()                 -> list of { itemID, link, name, icon, quality, count,
	                                     location (first stack), commodity, itemKey }
	  Sell:Suggest(detail, item)      -> unit price, why ("undercut" | "yours" | "market" |
	                                     "none"); from the item's live listings and your undercut
	                                     setting (1 copper, or a percent)
	  Sell:PriceStep(item)            -> 1, or 100 for gear on Forever (whole silver only)
	  Sell:RoundPrice(item, price)    -> the price on that step
	  Sell:Deposit(item, duration, qty)
	  Sell:Warnings(item, unit, qty)  -> list of texts that need a yes before posting
	  Sell:Post(item, duration, qty, unit [, bid])   -> true when sent
	  -> "POSTED"(info) / "POST_FAILED"(reason) / "SELL_PROGRESS"(done, total)

	Durations: 1 / 2 / 3 = the game's short / medium / long. ]]

local _, ns = ...
local NG = ns.NG
local Sell = NG:Module("Sell")
local Num, Str, Call, Open = NG.Num, NG.Str, NG.Call, NG.Open
local L = ns.L
local floor, max = math.floor, math.max

Sell.CUT = 0.95   -- what you keep after the auction house's cut (5%)

local function Bags()
	local list = {}
	local n = tonumber(_G.NUM_BAG_SLOTS) or 4
	for b = 0, n do list[#list + 1] = b end
	local reagent = _G.Enum and _G.Enum.BagIndex and _G.Enum.BagIndex.ReagentBag
	if reagent then list[#list + 1] = reagent end
	return list
end

local function ItemLocation(bag, slot)
	local IL = _G.ItemLocation
	if IL and IL.CreateFromBagAndSlot then return IL:CreateFromBagAndSlot(bag, slot) end
	return nil
end

local function CommodityStatus(loc)
	local AH = _G.C_AuctionHouse
	local E = _G.Enum and _G.Enum.ItemCommodityStatus
	if not (AH and AH.GetItemCommodityStatus and loc) then return nil end
	local st = Call(AH.GetItemCommodityStatus, loc)
	if E and st == E.Commodity then return true end
	if E and st == E.Item then return false end
	return nil
end

function Sell:BagItems()
	local AH, CC = _G.C_AuctionHouse, _G.C_Container
	local out, byKey = {}, {}
	if not (AH and CC and CC.GetContainerNumSlots and CC.GetContainerItemInfo) then return out end
	for _, bag in ipairs(Bags()) do
		local slots = Num(Call(CC.GetContainerNumSlots, bag)) or 0
		for slot = 1, slots do
			local info = Open(Call(CC.GetContainerItemInfo, bag, slot))
			if info and Num(info.itemID) and not info.isBound then
				local loc = ItemLocation(bag, slot)
				local valid = loc and AH.IsSellItemValid and Call(AH.IsSellItemValid, loc, false)
				if valid then
					local commodity = CommodityStatus(loc)
					-- stackable goods merge into one line; gear keeps one line per item (stats differ)
					local key = commodity and ("c" .. info.itemID) or ("i" .. tostring(info.hyperlink))
					local it = byKey[key]
					if it then
						it.count = it.count + (Num(info.stackCount) or 1)
					else
						it = { itemID = info.itemID, link = Str(info.hyperlink), icon = info.iconFileID, quality = Num(info.quality),
							count = Num(info.stackCount) or 1, location = loc, bag = bag, slot = slot, commodity = commodity }
						it.name = it.link and it.link:match("%[(.-)%]") or nil
						it.itemKey = AH.GetItemKeyFromItem and Open(Call(AH.GetItemKeyFromItem, loc)) or nil
						byKey[key] = it
						out[#out + 1] = it
					end
				end
			end
		end
	end
	table.sort(out, function(a, b) return (a.name or "") < (b.name or "") end)
	return out
end

-- how many of this item can go up in one post (the game's own count when it has one)
function Sell:MaxQty(item)
	local AH = _G.C_AuctionHouse
	if item and item.location and AH and AH.GetAvailablePostCount then
		local n = Num(Call(AH.GetAvailablePostCount, item.location))
		if n and n > 0 then return n end
	end
	return item and item.count or 1
end

-- The smallest price step the game takes for an item. WoW: Forever posts gear in whole
-- silver only (a buyout with copper in it is refused as an "internal auction error"; stacks
-- of goods take copper). Found by posting: 13s 95c, 13s 50c and 15s 50c refused; 13s and
-- 14s accepted; skins at a copper price accepted.
function Sell:PriceStep(item)
	if NG:IsForever() and item and item.commodity == false then return 100 end
	return 1
end

-- a price brought onto the item's step (down, never below one step)
function Sell:RoundPrice(item, price)
	price = Num(price)
	if not price then return nil end
	local step = self:PriceStep(item)
	return max(step, floor(price / step) * step)
end

function Sell:Undercut(price, item)
	price = Num(price)
	if not price then return nil end
	local mode = NG.Settings:Get("sell.undercutMode")
	local step = self:PriceStep(item)
	local p
	if mode == "percent" then
		local pct = tonumber(NG.Settings:Get("sell.undercutPercent")) or 1
		p = floor(price * (1 - pct / 100))
	else
		p = price - max(step, tonumber(NG.Settings:Get("sell.undercutCopper")) or 1)
	end
	p = floor(p / step) * step
	if p < step then p = step end
	return p
end

function Sell:Suggest(detail, item)
	local first = detail and detail.rows and detail.rows[1]
	if first and first.unit then
		if first.own then return self:RoundPrice(item, first.unit), "yours" end
		return self:Undercut(first.unit, item), "undercut"
	end
	if item and item.link then
		local e, key = NG.Prices:ForLink(item.link)
		local mv = e and key and NG.Prices:Market(key)
		if mv then return self:RoundPrice(item, mv), "market" end
	end
	return nil, "none"
end

function Sell:Deposit(item, duration, qty)
	local AH = _G.C_AuctionHouse
	if not (AH and item and item.location) then return nil end
	if item.commodity and AH.CalculateCommodityDeposit then
		return Num(Call(AH.CalculateCommodityDeposit, item.itemID, duration, qty))
	elseif AH.CalculateItemDeposit then
		return Num(Call(AH.CalculateItemDeposit, item.location, duration, qty))
	end
	return nil
end

function Sell:VendorPrice(item)
	if not item then return nil end
	local C = _G.C_Item
	local fn = (C and C.GetItemInfo) or _G.GetItemInfo
	if not fn then return nil end
	local sell = select(11, Call(fn, item.link or item.itemID))
	return Num(sell)
end

function Sell:Warnings(item, unit, qty)
	local out = {}
	unit, qty = Num(unit), Num(qty) or 1
	if not unit then return out end
	if NG.Settings:Get("sell.confirmVendor") then
		local v = self:VendorPrice(item)
		if v and v > 0 and v > floor(unit * self.CUT) then
			out[#out + 1] = string.format(L["A vendor pays %s each; after the auction house's cut you'd get %s."], NG.Money:Text(v), NG.Money:Text(floor(unit * self.CUT)))
		end
	end
	if NG.Settings:Get("sell.confirmLow") then
		local e, key = NG.Prices:ForLink(item.link)
		local mv = e and key and NG.Prices:Market(key)
		local pct = tonumber(NG.Settings:Get("sell.lowPercent")) or 30
		if mv and unit < mv * (1 - pct / 100) then
			out[#out + 1] = string.format(L["That's %d%% under its usual price (%s)."], floor((1 - unit / mv) * 100 + 0.5), NG.Money:Text(mv))
		end
	end
	return out
end

---------------------------------------------------------------------------------------------
-- Posting
---------------------------------------------------------------------------------------------
local posting = nil

function Sell:Post(item, duration, qty, unit, bid)
	local AH = _G.C_AuctionHouse
	qty, unit, bid = Num(qty), Num(unit), Num(bid)
	if not (AH and item and item.location and qty and qty > 0 and unit and unit > 0 and NG.House:IsOpen()) then return false end
	if _G.C_Item and C_Item.DoesItemExist and not Call(C_Item.DoesItemExist, item.location) then
		NG:Fire("POST_FAILED", L["That item is no longer in your bags."])
		return false
	end
	duration = Num(duration) or 3
	-- commodity or item? The bag list may have been built before the game knew ("unknown"):
	-- ask again now, then the item key, then the stack size. Posting a stack of goods through
	-- PostItem (or gear through PostCommodity) is what the server calls an internal error.
	local commodity = item.commodity
	if commodity == nil then commodity = CommodityStatus(item.location) end
	if commodity == nil and item.itemKey then
		local info = AH.GetItemKeyInfo and Open(Call(AH.GetItemKeyInfo, item.itemKey))
		if info and info.isCommodity ~= nil then commodity = info.isCommodity and true or false end
	end
	if commodity == nil and _G.C_Item and C_Item.GetItemMaxStackSizeByID then
		local stack = Num(Call(C_Item.GetItemMaxStackSizeByID, item.itemID))
		if stack then commodity = stack > 1 end
	end
	if commodity == nil then
		NG:Fire("POST_FAILED", L["The auction house hasn't said yet whether that is a commodity; try again in a moment."])
		return false
	end
	item.commodity = commodity
	if bid and bid <= 0 then bid = nil end
	if bid and bid > unit then bid = unit end
	-- WoW: Forever has no bidding: its listings carry no minimum bid and a post that names
	-- one is refused by the client ("Internal auction error"). The game's own window sends
	-- the item with no bid and a buyout; so do we.
	if NG:IsForever() then bid = nil end
	-- the post is on record before the call: the client can raise its red error text from
	-- inside the call itself, and that text should land on this post
	posting = { item = item, qty = qty, unit = unit, duration = duration, at = NG:Clock() }
	local ok, sent
	if commodity then
		ok, sent = pcall(AH.PostCommodity, item.location, duration, qty, unit)
	else
		-- gear: each item becomes its own auction at this buyout, with a starting bid only
		-- where the client takes one (never on Forever)
		ok, sent = pcall(AH.PostItem, item.location, duration, qty, bid, unit)
	end
	if not ok then posting = nil NG:Fire("POST_FAILED", L["The game refused the post."]) return false end
	if not posting then return false end   -- the client already refused it (its red text)
	-- when the game first wants a confirmation (its own warning dialog), it reads the post it
	-- is confirming from its own sell frame: hand that frame the post, as the game does itself
	if sent then
		local f = NG.House:BlizzardFrame()
		local sf = f and (commodity and f.CommoditiesSellFrame or f.ItemSellFrame)
		if sf and sf.CachePendingPost then
			if commodity then pcall(sf.CachePendingPost, sf, item.location, duration, qty, unit)
			else pcall(sf.CachePendingPost, sf, item.location, duration, qty, bid, unit) end
		end
	end
	-- nothing heard back: let the Sell tab go again (the post itself either happened or not)
	local mine = posting
	NG:After(8, function() if posting == mine then posting = nil NG:Fire("POST_FAILED", L["No answer from the auction house; check your auctions."]) end end)
	return true
end

local function Posted()
	local p = posting
	if not p then return end
	posting = nil
	NG.Ledger:Add("post", { itemID = p.item.itemID, link = p.item.link, name = p.item.name, qty = p.qty, unit = p.unit })
	if NG.Settings:Get("sell.chatLog") then
		NG:Print(L["Posted %s x%d at %s each."], p.item.link or p.item.name or "?", p.qty, NG.Money:Text(p.unit))
	end
	NG:Fire("POSTED", p)
end

NG:On("AUCTION_HOUSE_AUCTION_CREATED", function() Posted() end)
-- the server refused the post (the game shows the reason itself)
NG:On("AUCTION_HOUSE_POST_ERROR", function()
	if not posting then return end
	posting = nil
	NG:Fire("POST_FAILED", L["The auction house refused that post."])
end)
-- the game's red error text while a post is out ("Internal auction error." and friends): the
-- reason goes in our status row and the log, and the Sell tab is freed up again. The modern
-- auction house reports these through AUCTION_HOUSE_SHOW_ERROR with a code; the text for a
-- code comes from the game's own strings where it has one.
local ERROR_TEXT = {
	[0] = "ERR_AUCTION_ITEM_NOT_FOUND", [1] = "ERR_NOT_ENOUGH_MONEY", [2] = "ERR_AUCTION_DATABASE_ERROR",
	[3] = "ERR_AUCTION_HIGHER_BID", [4] = "ERR_AUCTION_BID_INCREMENT", [5] = "ERR_AUCTION_BID_OWN",
	[6] = "ERR_RESTRICTED_ACCOUNT_TRIAL", [7] = "ERR_AUCTION_HOUSE_BUSY", [8] = "ERR_AUCTION_HOUSE_UNAVAILABLE",
	[9] = "ERR_AUCTION_ITEM_HAS_QUOTE", [10] = "ERR_AUCTION_HOUSE_DISABLED", [11] = "ERR_AUCTION_ITEM_NOT_FOUND",
}
local function Refused(text)
	local p = posting
	if not p then return end
	posting = nil
	NG:Log("warn", "post of %s x%d at %s (%s, duration %s) refused: %s", tostring(p.item.name), p.qty, tostring(p.unit),
		p.item.commodity and "commodity" or "item", tostring(p.duration), text)
	NG:Fire("POST_FAILED", string.format(L["The auction house said: %s"], text))
end
NG:On("UI_ERROR_MESSAGE", function(_, _, text)
	text = Str(text)
	if text then Refused(text) end
end)
-- the exact red text the game shows (its error frame), whatever event carried it
if _G.UIErrorsFrame and _G.hooksecurefunc then
	hooksecurefunc(_G.UIErrorsFrame, "AddMessage", function(_, text)
		text = Str(text)
		if text and posting then Refused(text) end
	end)
end
NG:On("AUCTION_HOUSE_SHOW_ERROR", function(_, code)
	if not posting then return end
	code = Num(code)
	local name
	local E = _G.Enum and _G.Enum.AuctionHouseError
	if E and code then for k, v in pairs(E) do if v == code then name = k end end end
	local key = name and ("ERR_AUCTION_" .. name:upper()) or (code and ERROR_TEXT[code])
	local text = key and Str(_G[key]) or (name and string.format(L["refused (%s)"], name)) or (code and string.format(L["error %d"], code)) or L["an error"]
	Refused(text)
end)
-- the game wants a confirmation first (its own dialog asks; the post goes through from there)
NG:On("AUCTION_HOUSE_POST_WARNING", function() if posting then NG:Fire("POST_WAITING") end end)
NG:On("AUCTION_MULTISELL_START", function(_, total) NG:Fire("SELL_PROGRESS", 0, Num(total) or 0) end)
NG:On("AUCTION_MULTISELL_UPDATE", function(_, done, total) NG:Fire("SELL_PROGRESS", Num(done) or 0, Num(total) or 0) end)
NG:On("AUCTION_MULTISELL_FAILURE", function()
	posting = nil
	NG:Fire("POST_FAILED", L["Posting stopped partway (the game's multi-post was interrupted)."])
end)
NG:Register("AH_CLOSED", function() posting = nil end)
