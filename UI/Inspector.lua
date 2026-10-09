--[[ NetherGoblin - UI/Inspector.lua
	The selected item, on the right of the Buy tab: name plate, 14-day trend, market value,
	lowest now, how many are listed, how many you carry, the deal meter, and buying.

	Commodities: quantity (- / + / Max), the total for the cheapest units, Buyout (click 1 asks
	the server for the exact price, click 2 confirms). Bids are not possible on commodities (the
	game's rule) so that row is greyed with the reason.
	Other items: the cheapest auction first, < > to step through them, Buyout, or Bid with your
	amount (the minimum bid filled in).

	  Inspector:Build(parent, x, y, w, h)
	  Inspector:SetItem(row)   row = a browse result ({ itemKey, minPrice, totalQuantity }) ]]

local _, ns = ...
local NG = ns.NG
local Inspector = NG:Module("Inspector")
local W, Skin = NG.Widgets, NG.Skin
local L = ns.L
local Num, Call, Open = NG.Num, NG.Call, NG.Open
local floor, max, min = math.floor, math.max, math.min
local MEDIA = NG.MEDIA

local f            -- the panel
local cur = nil    -- { row, itemKey, base, key, detail, qty, auction (index) }

local function ItemCount(id)
	local C = _G.C_Item
	if C and C.GetItemCount then return Num(Call(C.GetItemCount, id, true)) or 0 end
	return _G.GetItemCount and Num(Call(GetItemCount, id, true)) or 0
end

local function KeyInfo(itemKey)
	local AH = _G.C_AuctionHouse
	return AH and AH.GetItemKeyInfo and Open(Call(AH.GetItemKeyInfo, itemKey)) or nil
end

local function ClassText(itemID)
	local C = _G.C_Item
	local fn = (C and C.GetItemInfoInstant) or _G.GetItemInfoInstant
	if not fn then return "" end
	local _, itemType, subType = Call(fn, itemID)
	if itemType and subType and subType ~= itemType then return itemType .. "  ·  " .. subType end
	return itemType or ""
end

function Inspector:Build(parent, x, y, w, h)
	f = W:Panel(parent, "A")
	f:SetPoint("TOPLEFT", x, -y)
	f:SetSize(w, h)
	self.frame = f
	-- name plate
	local plate = W:NamePlate(f, w - 40, 24)
	plate:SetPoint("TOPLEFT", 20, -2)
	-- the item's name keeps its quality colour (Fill sets it), in either look
	plate.name.keepColour = true
	Skin:Unpaint(plate.name)
	f.plate, f.name = plate, plate.name
	local yy = plate.h + 2
	f.icon = W:Icon(f, 56)
	f.icon:SetPoint("TOPLEFT", 18, -yy)
	f.class = W:Text(f, 18, "text")
	f.class:SetPoint("TOPLEFT", 88, -(yy + 6))
	f.kind = W:Text(f, 16, "textDim")
	f.kind:SetPoint("TOPLEFT", 88, -(yy + 31))
	yy = yy + 60
	local chain = W:Divider(f, 190, 47)
	chain:SetPoint("TOP", f, "TOPLEFT", w / 2, -(yy - 8))
	f.chain = chain
	yy = yy + 45
	f.chart = NG.Chart:New(f, w - 28, 104)
	f.chart:SetPoint("TOPLEFT", 14, -yy)
	yy = yy + 114
	-- stats
	local cw = floor((w - 28 - 10) / 2)
	f.stats = {}
	for i, label in ipairs({ L["Market value"], L["Lowest now"], L["Listed"], L["In your bags"] }) do
		local box = W:Inset(f)
		box:SetSize(cw, 43)
		box:SetPoint("TOPLEFT", 14 + ((i - 1) % 2) * (cw + 10), -(yy + floor((i - 1) / 2) * 48))
		local k = W:Text(box, 14, "textDim") k:SetPoint("TOPLEFT", 10, -5) k:SetText(label)
		local v = W:Text(box, 18, "text") v:SetPoint("BOTTOMRIGHT", -9, 5)
		f.stats[i] = v
	end
	yy = yy + 100
	-- deal meter
	local dl = W:Text(f, 16, "textDim") dl:SetPoint("TOPLEFT", 14, -(yy + 2)) dl:SetText(L["Deal"])
	f.dealText = W:Text(f, 16, "positive")
	f.dealText:SetPoint("TOPRIGHT", -14, -(yy + 2))
	local bar = CreateFrame("Frame", nil, f)
	bar:SetSize(w - 28, 14)
	bar:SetPoint("TOPLEFT", 14, -(yy + 24))
	local grad = bar:CreateTexture(nil, "ARTWORK")
	grad:SetTexture(Skin.WHITE) grad:SetAllPoints()
	if grad.SetGradient and _G.CreateColor then
		pcall(grad.SetGradient, grad, "HORIZONTAL", CreateColor(0.27, 0.75, 0.24, 1), CreateColor(0.94, 0.24, 0.24, 1))
	else
		grad:SetVertexColor(0.6, 0.5, 0.24, 1)
	end
	W.Edges(bar, "OVERLAY", 2)
	local marker = bar:CreateTexture(nil, "OVERLAY", nil, 2)
	marker:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
	marker:SetSize(16, 16)
	marker:SetVertexColor(1, 0.95, 0.85, 1)
	f.dealBar, f.dealMarker = bar, marker
	yy = yy + 52
	-- buy box
	local box = W:Inset(f)
	box:SetPoint("TOPLEFT", 14, -yy)
	box:SetPoint("BOTTOMRIGHT", -14, 12)
	f.box = box
	local bw = w - 28
	-- quantity row (commodities) / auction stepper (other items)
	local ql = W:Text(box, 17, "textDim") ql:SetPoint("TOPLEFT", 12, -20) ql:SetText(L["Quantity"])
	f.qtyLabel = ql
	local minus = W:Button(box, "-", 38, 40, { size = 22 })
	minus:SetPoint("TOPLEFT", 100, -12)
	-- typing: an empty box (Backspace) or a 0 is allowed while it has the cursor; the totals
	-- follow every number typed, and the box shows the quantity again when the cursor leaves
	local qe = W:Edit(box, 80, 40, "", { numeric = true, maxLetters = 5, justify = "CENTER", size = 22,
		onChange = function(text, user)
			if not (user and cur) then return end
			local n = tonumber(text)
			if n and n >= 1 then cur.qty = n Inspector:QtyChanged() end
		end })
	qe:SetPoint("LEFT", minus, "RIGHT", 8, 0)
	-- the first click selects the number, so typing replaces it; a click while it already has
	-- the cursor just places the cursor (the box's own behaviour)
	qe.edit:HookScript("OnEditFocusGained", function(self)
		C_Timer.After(0, function() if self:HasFocus() then self:HighlightText() end end)
	end)
	qe.edit:HookScript("OnEditFocusLost", function(self)
		self:HighlightText(0, 0)
		if cur then qe:SetText(tostring(max(1, cur.qty or 1))) end
	end)
	local plus = W:Button(box, "+", 38, 40, { size = 22 })
	plus:SetPoint("LEFT", qe, "RIGHT", 8, 0)
	local maxb = W:Button(box, L["Max"], bw - 12 - 100 - 180 - 4, 40, { size = 19 })
	maxb:SetPoint("LEFT", plus, "RIGHT", 8, 0)
	minus:SetScript("OnClick", function() if cur then cur.qty = max(1, (cur.qty or 1) - 1) Inspector:QtyChanged() end end)
	plus:SetScript("OnClick", function() if cur then cur.qty = (cur.qty or 1) + 1 Inspector:QtyChanged() end end)
	maxb:SetScript("OnClick", function() if cur then cur.qty = Inspector:Available() Inspector:QtyChanged() end end)
	W:Tip(maxb, L["Max"], L["Everything listed, or as much as your gold covers."])
	f.minus, f.qtyEdit, f.plus, f.maxb = minus, qe, plus, maxb
	-- stepper for gear
	local prev = W:Button(box, "<", 38, 40, { size = 20 })
	prev:SetPoint("TOPLEFT", 100, -12)
	local next = W:Button(box, ">", 38, 40, { size = 20 })
	next:SetPoint("TOPRIGHT", -12, -12)
	local which = W:Text(box, 17, "text")
	which:SetPoint("LEFT", prev, "RIGHT", 10, 0) which:SetPoint("RIGHT", next, "LEFT", -10, 0)
	prev:SetScript("OnClick", function() Inspector:Step(-1) end)
	next:SetScript("OnClick", function() Inspector:Step(1) end)
	f.prev, f.next, f.which = prev, next, which
	-- total
	local tl = W:Text(box, 17, "textDim") tl:SetPoint("TOPLEFT", 12, -78) tl:SetText(L["Total"])
	f.total = W:Text(box, 21, "text") f.total:SetPoint("LEFT", tl, "RIGHT", 10, 0)
	f.each = W:Text(box, 14, "textDim") f.each:SetPoint("LEFT", f.total, "RIGHT", 8, -1)
	f.warn = W:Text(box, 14, "warning") f.warn:SetPoint("TOPRIGHT", -12, -80) f.warn:SetJustifyH("RIGHT")
	-- buyout
	local buy = W:Button(box, L["Buyout"], bw - 24, 46, { primary = true, size = 26 })
	buy:SetPoint("TOPLEFT", 12, -100)
	buy:SetScript("OnClick", function() Inspector:BuyClick() end)
	f.buy = buy
	local cancel = W:Button(box, L["Cancel"], 90, 30, { size = 15 })
	cancel:SetPoint("BOTTOMRIGHT", buy, "TOPRIGHT", 0, 4)
	cancel:SetScript("OnClick", function() NG.Buy:CancelQuote() Inspector:Totals() end)
	cancel:Hide()
	f.cancel = cancel
	-- bid row
	local bidBox = NG.Widgets:MoneyBox(box, 36)
	bidBox:SetPoint("TOPLEFT", 12, -156)
	f.bidBox = bidBox
	local bid = W:Button(box, L["Bid"], bw - 24 - bidBox:GetWidth() - 10, 36, { size = 19 })
	bid:SetPoint("LEFT", bidBox, "RIGHT", 10, 0)
	bid:SetScript("OnClick", function() Inspector:BidClick() end)
	f.bid = bid
	f.bidNote = W:Text(box, 14, "textDim")
	f.bidNote:SetPoint("TOPLEFT", 14, -200)
	f.empty = W:Text(f, 18, "textDim")
	f.empty:SetPoint("CENTER", 0, 40)
	f.empty:SetText(L["Pick an item on the left."])
	self:Clear()
	return f
end

local function SetMoneyStat(i, copper) f.stats[i]:SetText(copper and NG.Money:Text(copper) or "-") end

function Inspector:Clear()
	cur = nil
	if not f then return end
	f.name:SetText("") f.class:SetText("") f.kind:SetText("")
	f.icon:SetItem(nil, false)
	f.chart:Clear()
	for i = 1, 4 do f.stats[i]:SetText("-") end
	f.dealText:SetText("") f.dealMarker:Hide()
	f.total:SetText("-") f.each:SetText("") f.warn:SetText("")
	f.buy:SetEnabled(false) f.bid:SetEnabled(false)
	f.cancel:Hide()
	-- no item: neither the quantity row nor the auction stepper (both would draw on top of each other)
	for _, b in ipairs({ f.minus, f.qtyEdit, f.plus, f.maxb, f.prev, f.next, f.which }) do b:Hide() end
	f.bidBox:Hide()
	f.qtyLabel:SetText("")
	f.bidNote:SetText("")
	f.empty:Show()
end

function Inspector:Current() return cur end

-- how many of the item can be bought (listed, and within your gold for commodities)
function Inspector:Available()
	if not (cur and cur.detail) then return 1 end
	local total, gold, have = 0, _G.GetMoney and GetMoney() or 0, 0
	for _, r in ipairs(cur.detail.rows) do
		if not r.own and r.unit then
			local afford = floor((gold - total) / r.unit)
			local take = min(r.qty or 0, afford)
			if take <= 0 then break end
			have = have + take
			total = total + take * r.unit
			if take < (r.qty or 0) then break end
		end
	end
	return max(1, have)
end

-- the cost of the cheapest `qty` units (others' listings only)
local function CostOf(rows, qty)
	local total, left = 0, qty
	for _, r in ipairs(rows) do
		if not r.own and r.unit and left > 0 then
			local take = min(left, r.qty or 0)
			total = total + take * r.unit
			left = left - take
		end
	end
	if left > 0 then return nil end
	return total
end

-- a different quantity: any price quote was for the old one
function Inspector:QtyChanged()
	if NG.Buy:Quoting() then NG.Buy:CancelQuote() end
	self:Totals()
end

function Inspector:Totals()
	if not (f and cur) then return end
	local d = cur.detail
	local quote = NG.Buy:Quoting()
	f.cancel:SetShown(quote ~= nil)
	if cur.commodity then
		cur.qty = max(1, cur.qty or 1)
		-- while the player is typing in it, the box keeps what they typed (even empty)
		if not (f.qtyEdit.edit.HasFocus and f.qtyEdit.edit:HasFocus()) then f.qtyEdit:SetText(tostring(cur.qty)) end
		local total = d and CostOf(d.rows, cur.qty)
		if quote and quote.ready then
			f.total:SetText(NG.Money:Text(quote.total))
			f.each:SetText(string.format(L["%s each"], NG.Money:Text(quote.unit, { plain = true })))
			f.buy:SetLabel(string.format(L["Confirm %s"], NG.Money:Text(quote.total, { plain = true, short = true })))
			local jump = tonumber(NG.Settings:Get("buy.confirmJump")) or 10
			f.warn:SetText(quote.jump and quote.jump > jump and string.format(L["Up %d%% since the list"], quote.jump) or "")
			-- the real price has to be on screen for half a second before a click can confirm it
			local wait = 0.5 - (NG:Clock() - (quote.readyAt or 0))
			if wait > 0 then
				f.buy:SetEnabled(false)
				NG:After(wait, function() if NG.Buy:Quoting() == quote then Inspector:Totals() end end)
			else
				f.buy:SetEnabled(true)
			end
		elseif quote then
			f.buy:SetLabel(L["Getting the price..."])
			f.buy:SetEnabled(false)
		else
			f.total:SetText(total and NG.Money:Text(total) or (d and L["Not that many listed"] or "..."))
			f.each:SetText(total and string.format(L["%s each"], NG.Money:Text(floor(total / cur.qty), { plain = true })) or "")
			f.buy:SetLabel(L["Buyout"])
			f.warn:SetText(total and _G.GetMoney and total > GetMoney() and L["Not enough gold"] or "")
			f.buy:SetEnabled(total ~= nil and NG.House:IsOpen() and not (_G.GetMoney and total > GetMoney()))
		end
		f.bid:SetEnabled(false)
		f.bidNote:SetText(L["Commodities are buyout only: the game has no bids on them."])
	else
		local rows = d and d.rows or {}
		local i = min(max(1, cur.auction or 1), max(1, #rows))
		cur.auction = i
		local r = rows[i]
		f.which:SetText(#rows > 0 and string.format(L["Auction %d of %d"], i, #rows) or (d and L["None listed"] or "..."))
		f.prev:SetEnabled(i > 1) f.next:SetEnabled(i < #rows)
		f.total:SetText(r and r.buyout and NG.Money:Text(r.buyout) or (r and L["Bid only"] or "-"))
		f.each:SetText(r and r.own and L["(yours)"] or "")
		f.buy:SetLabel(L["Buyout"])
		f.buy:SetEnabled(r ~= nil and r.buyout ~= nil and not r.own and NG.House:IsOpen())
		f.warn:SetText(r and r.buyout and _G.GetMoney and r.buyout > GetMoney() and L["Not enough gold"] or "")
		local minBid = r and (r.minBid or r.bid)
		f.bid:SetEnabled(r ~= nil and minBid ~= nil and not r.own and NG.House:IsOpen())
		if r and minBid and not cur.bidSet then f.bidBox:Set(minBid) cur.bidSet = true end
		f.bidNote:SetText(r and minBid and string.format(L["Minimum bid %s"], NG.Money:Text(minBid, { plain = true })) or "")
	end
end

function Inspector:Step(dir)
	if not cur then return end
	cur.auction = (cur.auction or 1) + dir
	cur.bidSet = nil
	self:Totals()
end

local function Deal(price, mv)
	if not (price and mv and mv > 0) then
		f.dealText:SetText(L["Not enough history yet"])
		Skin:Paint(f.dealText, "textDim")
		f.dealMarker:Hide()
		return
	end
	local ratio = price / mv
	local pct = floor(math.abs(1 - ratio) * 100 + 0.5)
	if pct < 2 then
		f.dealText:SetText(L["At market"]) Skin:Paint(f.dealText, "text")
	elseif ratio < 1 then
		f.dealText:SetText(string.format(L["%d%% under market"], pct)) Skin:Paint(f.dealText, "positive")
	else
		f.dealText:SetText(string.format(L["%d%% over market"], pct)) Skin:Paint(f.dealText, "negative")
	end
	local t = min(1, max(0, (ratio - 0.6) / 0.8))
	f.dealMarker:ClearAllPoints()
	f.dealMarker:SetPoint("BOTTOM", f.dealBar, "TOPLEFT", t * f.dealBar:GetWidth(), -6)
	f.dealMarker:Show()
end

function Inspector:Fill()
	if not (f and cur) then return end
	local info = KeyInfo(cur.itemKey)
	local d = cur.detail
	local id = cur.itemKey.itemID
	f.empty:Hide()
	local nameText = (info and info.itemName) or (d and d.name) or (_G.C_Item and C_Item.GetItemNameByID and Call(C_Item.GetItemNameByID, id)) or "..."
	local q = info and Num(info.quality)
	local c = q and _G.ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
	f.name:SetText(nameText)
	if c then f.name:SetTextColor(c.r, c.g, c.b) end
	f.icon:SetItem(info and info.iconFileID or (_G.C_Item and C_Item.GetItemIconByID and Call(C_Item.GetItemIconByID, id)), q)
	f.class:SetText(ClassText(id))
	if cur.commodity == nil and info then cur.commodity = info.isCommodity and true or false end
	f.kind:SetText(cur.commodity and L["Commodity: buyout only"] or (cur.commodity == false and (NG:IsForever() and L["Buyout only"] or L["Bids allowed"]) or ""))
	local isC = cur.commodity ~= false
	for _, b in ipairs({ f.minus, f.qtyEdit, f.plus, f.maxb }) do b:SetShown(isC) end
	f.qtyLabel:SetText(isC and L["Quantity"] or L["Auction"])
	for _, b in ipairs({ f.prev, f.next, f.which }) do b:SetShown(not isC) end
	f.bidBox:SetShown(not isC)
	-- numbers
	local P = NG.Prices
	local key = cur.key
	f.chart:SetHistory(P:History(key))
	local mv = P:Market(key)
	local lowest = d and d.lowest or Num(cur.row.minPrice) or P:Lowest(key)
	SetMoneyStat(1, mv)
	SetMoneyStat(2, lowest)
	local listed = Num(cur.row.totalQuantity)
	if d then listed = 0 for _, r in ipairs(d.rows) do listed = listed + (r.qty or 0) end end
	f.stats[3]:SetText(listed and (_G.BreakUpLargeNumbers and BreakUpLargeNumbers(listed) or tostring(listed)) or "-")
	f.stats[4]:SetText(tostring(ItemCount(id)))
	Deal(lowest, mv)
	self:Totals()
end

function Inspector:SetItem(row)
	if not f then return end
	if not (row and type(row.itemKey) == "table") then return self:Clear() end
	if NG.Buy:Quoting() then NG.Buy:CancelQuote() end
	local base, lv = NG.Prices:KeysOfItemKey(row.itemKey)
	cur = { row = row, itemKey = row.itemKey, key = lv or base, qty = 1, auction = 1 }
	cur.commodity = NG.Search:IsCommodity(row.itemKey)
	cur.detail = NG.Search:Detail(row.itemKey)
	self:Fill()
	NG.Search:Item(row.itemKey, function(d)
		if cur and cur.itemKey == row.itemKey then
			cur.detail = d
			if cur.commodity == nil then cur.commodity = d.commodity end
			Inspector:Fill()
		end
	end)
end

function Inspector:BuyClick()
	if not cur then return end
	local q = NG.Buy:Quoting()
	if cur.commodity ~= false then
		if q and q.ready then NG.Buy:Confirm() return end
		local info = { itemKey = cur.itemKey, name = f.name:GetText() }
		local d = cur.detail
		local total = d and CostOf(d.rows, cur.qty)
		NG.Buy:Quote(cur.itemKey.itemID, cur.qty, total and floor(total / cur.qty), info)
		self:Totals()
	else
		local r = cur.detail and cur.detail.rows[cur.auction or 1]
		if r then NG.Buy:Buyout(r, { itemID = cur.itemKey.itemID, itemKey = cur.itemKey, name = f.name:GetText() }) end
	end
end

function Inspector:BidClick()
	if not cur or cur.commodity ~= false then return end
	local r = cur.detail and cur.detail.rows[cur.auction or 1]
	local amount = f.bidBox:Get()
	local minBid = r and (r.minBid or r.bid)
	if minBid and amount < minBid then
		NG.Window:SetStatus(string.format(L["The minimum bid is %s."], NG.Money:Text(minBid, { plain = true })), 5)
		return
	end
	if r then NG.Buy:Bid(r, amount, { itemID = cur.itemKey.itemID, itemKey = cur.itemKey, name = f.name:GetText() }) end
end

NG:Register("BUY_QUOTE", function() Inspector:Totals() end)
NG:Register("BUY_QUOTING", function() Inspector:Totals() end)
NG:Register("BUY_QUOTE_CLEARED", function() Inspector:Totals() end)
NG:Register("BUY_DONE", function(_, info)
	NG.Window:SetStatus(string.format(L["Bought %s x%d for %s."], info.name or "?", info.qty or 1, NG.Money:Text(info.total or 0, { plain = true })), 6)
	if cur then cur.bidSet = nil Inspector:Totals() end
end)
NG:Register("BUY_FAILED", function(_, why)
	NG.Window:SetStatus(why or L["That didn't work."], 6)
	Inspector:Totals()
end)
NG:On("ITEM_KEY_ITEM_INFO_RECEIVED", function() if cur and f and f:IsVisible() then NG:Debounce("inspector info", 0.1, function() if cur then Inspector:Fill() end end) end end)
-- the item's listings changed (a purchase, a page, a repeat search): show the current ones
NG:Register("ITEM_RESULTS", function(_, d)
	if not (cur and f and d and d.key == NG.Search:KeyString(cur.itemKey)) then return end
	cur.detail = d
	if cur.commodity == nil then cur.commodity = d.commodity end
	if cur.auction and cur.auction > #d.rows then cur.auction = max(1, #d.rows) end
	cur.bidSet = nil
	Inspector:Fill()
end)
NG:On("BAG_UPDATE_DELAYED", function() if cur and f and f:IsVisible() then f.stats[4]:SetText(tostring(ItemCount(cur.itemKey.itemID))) end end)
