--[[ NetherGoblin - UI/TabAuctions.lua
	Two tabs about your own auctions.

	Auctions: everything you have up, sold ones marked (collect the gold from your mailbox),
	what each asks, time left, bids, and whether someone lists the same thing for less.
	Select one to cancel it (the game charges a fee for some) or to sell more like it.

	Undercuts: only the auctions someone has undercut. "Check now" reads each item's live
	listings (one search per item) for an exact count of how many are listed cheaper than yours.
	"Cancel next" cancels the next undercut auction: one click each (the game's rule), so you
	can clear a long list quickly and still decide every time. ]]

local _, ns = ...
local NG = ns.NG
local TA = NG:Module("TabAuctions")
local TU = NG:Module("TabUndercuts")
local W, Skin = NG.Widgets, NG.Skin
local L = ns.L
local Num, Call, Open = NG.Num, NG.Call, NG.Open
local floor, max = math.floor, math.max

local function TimeLeft(a)
	local s = a.timeLeft
	if s then
		if s >= 3600 then return string.format(L["%d h"], floor(s / 3600 + 0.5)) end
		return string.format(L["%d min"], max(1, floor(s / 60 + 0.5)))
	end
	return ""
end

local function Status(a)
	if a.sold then return "|cff7fe07f" .. L["Sold: collect at the mailbox"] .. "|r" end
	if a.bidder or (a.bid and a.bid > 0) then return string.format(L["Bid %s  ·  %s left"], NG.Money:Text(a.bid or 0, { plain = true, short = true }), TimeLeft(a)) end
	return TimeLeft(a) ~= "" and string.format(L["%s left"], TimeLeft(a)) or ""
end

local function IconOf(a)
	local id = a.itemID
	return id and _G.C_Item and C_Item.GetItemIconByID and Call(C_Item.GetItemIconByID, id) or nil
end

local function QualityOf(a)
	local AH = _G.C_AuctionHouse
	local info = a.itemKey and AH and AH.GetItemKeyInfo and Open(Call(AH.GetItemKeyInfo, a.itemKey))
	return info and Num(info.quality)
end

-- a list of auctions (shared by both tabs)
local function AuctionList(parent, w, h, extra)
	local list = W:List(parent, w, h, 48, function(r)
		r.icon = W:Icon(r, 36) r.icon:SetPoint("LEFT", 6, 0)
		r.name = W:Text(r, 19, "text") r.name:SetPoint("LEFT", 50, 0) r.name:SetWidth(w * 0.38) r.name:SetJustifyH("LEFT")
		r.price = W:Text(r, 19, "text") r.price:SetPoint("LEFT", 50 + w * 0.38 + 10, 0)
		r.info = W:Text(r, 16, "textDim") r.info:SetPoint("RIGHT", -110, 0)
		r.badge = W:Badge(r, 92, 26) r.badge:SetPoint("RIGHT", -10, 0)
		r:SetScript("OnEnter", function(self)
			if self.data and self.data.link and _G.GameTooltip then GameTooltip:SetOwner(self, "ANCHOR_RIGHT") GameTooltip:SetHyperlink(self.data.link) GameTooltip:Show() end
		end)
		r:SetScript("OnLeave", function() if _G.GameTooltip then GameTooltip:Hide() end end)
	end, function(r, a)
		r.icon:SetItem(IconOf(a), QualityOf(a))
		r.name:SetText((a.name or "?") .. (a.qty and a.qty > 1 and ("  |cffb0a080x" .. a.qty .. "|r") or ""))
		r.price:SetText(a.unit and NG.Money:Text(a.unit) or L["bid only"])
		extra(r, a)
	end)
	return list
end

---------------------------------------------------------------------------------------------
-- Auctions
---------------------------------------------------------------------------------------------
local ca, alist, adet
local sel

function TA:Build(c)
	ca = c
	local P = NG.Window.P
	local title = W:Text(c, 28, "header", "title") title:SetPoint("TOPLEFT", P + 4, -(NG.Window.HEADER_Y + 14)) title:SetText(L["Your auctions"])
	c.count = W:Text(c, 17, "textDim") c.count:SetPoint("LEFT", title, "RIGHT", 20, -2)
	local refresh = W:Button(c, L["Refresh"], 140, 44, { size = 19 })
	refresh:SetPoint("TOPRIGHT", -NG.Window.HEADER_RIGHT, -(NG.Window.HEADER_Y + 2))
	refresh:SetScript("OnClick", function() NG.Owned:Query() end)
	local lw = NG.Window.W - P * 2 - 400 - 12
	local panel = W:Panel(c, "C")
	panel:SetPoint("TOPLEFT", P, -NG.Window.TOP)
	panel:SetSize(lw, NG.Window.BOTTOM - NG.Window.TOP)
	alist = AuctionList(panel, lw - 8, NG.Window.BOTTOM - NG.Window.TOP - 16, function(r, a)
		r.info:SetText(Status(a))
		if a.sold then r.badge:Set(L["Sold"], "great", nil)
		elseif a.undercut then r.badge:Set(L["Undercut"], "pricey", "down")
		elseif a.checked then r.badge:Set(L["Cheapest"], "good", nil)
		else r.badge:Set(L["Listed"], "fair", nil) end
	end)
	alist:SetPoint("TOPLEFT", 4, -8)
	for _, r in ipairs(alist.rows) do r:SetScript("OnClick", function(self) if self.data then TA:Select(self.data) end end) end
	c.note = W:Text(panel, 18, "textDim") c.note:SetPoint("CENTER") c.note:SetWordWrap(true) c.note:SetWidth(lw - 80)
	-- details
	adet = W:Panel(c, "A")
	adet:SetPoint("TOPLEFT", NG.Window.W - P - 400, -NG.Window.TOP)
	adet:SetSize(400, NG.Window.BOTTOM - NG.Window.TOP)
	adet.icon = W:Icon(adet, 64) adet.icon:SetPoint("TOP", 0, -24)
	adet.name = W:Text(adet, 22, "text") adet.name:SetPoint("TOP", adet.icon, "BOTTOM", 0, -12) adet.name:SetWidth(360)
	local y = 150
	local function Row(label)
		local k = W:Text(adet, 17, "textDim") k:SetPoint("TOPLEFT", 18, -y) k:SetText(label)
		local v = W:Text(adet, 18, "text") v:SetPoint("TOPRIGHT", -18, -y)
		y = y + 32
		return v
	end
	adet.unit, adet.total, adet.time, adet.bid, adet.lowest = Row(L["Price each"]), Row(L["Total"]), Row(L["Time left"]), Row(L["Highest bid"]), Row(L["Lowest now (others)"])
	adet.cost = W:Text(adet, 15, "textDim") adet.cost:SetPoint("TOPLEFT", 18, -(y + 8)) adet.cost:SetWidth(364) adet.cost:SetWordWrap(true) adet.cost:SetJustifyH("LEFT")
	adet.cancel = W:Button(adet, L["Cancel auction"], 372, 48, { size = 22 })
	adet.cancel:SetPoint("BOTTOMLEFT", 14, 72)
	adet.cancel:SetScript("OnClick", function() if sel then NG.Owned:Cancel(sel.auctionID) end end)
	adet.more = W:Button(adet, L["Sell more like this"], 372, 44, { size = 19 })
	adet.more:SetPoint("BOTTOMLEFT", 14, 18)
	adet.more:SetScript("OnClick", function() if sel then TA:SellMore(sel) end end)
	self:Detail(nil)
end

function TA:SellMore(a)
	NG.Window:SelectTab("sell")
	for _, it in ipairs(NG.Sell:BagItems()) do
		if it.itemID == a.itemID then NG.TabSell:Select(it) return end
	end
	NG.Window:SetStatus(L["You have none of those in your bags."], 5)
end

function TA:Detail(a)
	sel = a
	adet.icon:SetShown(a ~= nil)
	if not a then
		adet.name:SetText(L["Pick one of your auctions."])
		for _, v in ipairs({ adet.unit, adet.total, adet.time, adet.bid, adet.lowest }) do v:SetText("") end
		adet.cost:SetText("")
		adet.cancel:SetEnabled(false) adet.more:SetEnabled(false)
		return
	end
	adet.icon:SetItem(IconOf(a), QualityOf(a))
	adet.name:SetText((a.name or "?") .. (a.qty > 1 and ("  x" .. a.qty) or ""))
	adet.unit:SetText(a.unit and NG.Money:Text(a.unit) or "-")
	adet.total:SetText(a.unit and NG.Money:Text(a.unit * a.qty) or "-")
	adet.time:SetText(a.sold and L["Sold"] or TimeLeft(a))
	adet.bid:SetText(a.bid and a.bid > 0 and NG.Money:Text(a.bid) or L["none"])
	local base, lv
	if a.itemKey then base, lv = NG.Prices:KeysOfItemKey(a.itemKey) end
	local lowest = a.lowest or NG.Prices:Lowest(lv or base)
	adet.lowest:SetText(lowest and NG.Money:Text(lowest) or "-")
	local can = not a.sold and NG.Owned:CanCancel(a.auctionID)
	local cost = can and NG.Owned:CancelCost(a.auctionID) or 0
	adet.cost:SetText(a.sold and L["Sold auctions can't be cancelled."] or (not can and L["This one can't be cancelled (someone has bid on it)."])
		or (cost > 0 and string.format(L["Cancelling costs %s."], NG.Money:Text(cost)) or L["Cancelling is free; the deposit is not returned."]))
	adet.cancel:SetEnabled(can and NG.House:IsOpen())
	adet.more:SetEnabled(true)
end

function TA:Select(a) alist:Select(a) self:Detail(a) end

function TA:Show()
	if not alist then return end
	local l = NG.Owned:List()
	alist:SetData(l, true)
	local sold, up = 0, 0
	for _, a in ipairs(l) do if a.sold then sold = sold + 1 else up = up + 1 end end
	ca.count:SetText(string.format(L["%d up  ·  %d sold"], up, sold))
	ca.note:SetText(#l == 0 and L["Nothing up for sale. The Sell tab fixes that."] or "")
	ca.note:SetShown(#l == 0)
	if sel then
		local still
		for _, a in ipairs(l) do if a.auctionID == sel.auctionID then still = a end end
		self:Select(still)
	end
end

function TA:OnShow() NG.Owned:Query() self:Show() end

---------------------------------------------------------------------------------------------
-- Undercuts
---------------------------------------------------------------------------------------------
local cu, ulist, usel

local function Undercut()
	local out = {}
	for _, a in ipairs(NG.Owned:List()) do if a.undercut and not a.sold then out[#out + 1] = a end end
	return out
end

function TU:Build(c)
	cu = c
	local P = NG.Window.P
	local title = W:Text(c, 28, "header", "title") title:SetPoint("TOPLEFT", P + 4, -(NG.Window.HEADER_Y + 14)) title:SetText(L["Undercuts"])
	c.count = W:Text(c, 17, "textDim") c.count:SetPoint("LEFT", title, "RIGHT", 20, -2)
	local check = W:Button(c, L["Check now"], 170, 44, { size = 19, primary = true })
	check:SetPoint("TOPRIGHT", -NG.Window.HEADER_RIGHT, -(NG.Window.HEADER_Y + 2))
	check:SetScript("OnClick", function()
		if NG.Owned:Check() then NG.Window:SetStatus(L["Checking each of your items..."], 4) end
	end)
	W:Tip(check, L["Check now"], L["Reads the live listings of every item you have up (one search each) and counts how many are listed cheaper than yours."])
	local lw = NG.Window.W - P * 2 - 400 - 12
	local panel = W:Panel(c, "C")
	panel:SetPoint("TOPLEFT", P, -NG.Window.TOP)
	panel:SetSize(lw, NG.Window.BOTTOM - NG.Window.TOP)
	ulist = AuctionList(panel, lw - 8, NG.Window.BOTTOM - NG.Window.TOP - 16, function(r, a)
		local base, lv
		if a.itemKey then base, lv = NG.Prices:KeysOfItemKey(a.itemKey) end
		local lowest = a.lowest or NG.Prices:Lowest(lv or base)
		r.info:SetText(lowest and string.format(L["lowest %s"], NG.Money:Text(lowest, { plain = true, short = true })) or "")
		if a.ahead then r.badge:Set(string.format(L["%d ahead"], a.ahead), "pricey", "down")
		else r.badge:Set(L["Undercut"], "pricey", "down") end
	end)
	ulist:SetPoint("TOPLEFT", 4, -8)
	for _, r in ipairs(ulist.rows) do r:SetScript("OnClick", function(self) if self.data then usel = self.data ulist:Select(usel) TU:Sync() end end) end
	c.note = W:Text(panel, 18, "textDim") c.note:SetPoint("CENTER") c.note:SetWordWrap(true) c.note:SetWidth(lw - 80)
	-- actions
	local act = W:Panel(c, "A")
	act:SetPoint("TOPLEFT", NG.Window.W - P - 400, -NG.Window.TOP)
	act:SetSize(400, NG.Window.BOTTOM - NG.Window.TOP)
	local h = W:Text(act, 20, "header") h:SetPoint("TOP", 0, -24) h:SetText(L["Undercut? Undercut back."])
	local tx = W:Text(act, 16, "textDim") tx:SetPoint("TOP", 0, -58) tx:SetWidth(360) tx:SetWordWrap(true)
	tx:SetText(L["Cancel the undercut auctions (one click each: the game's rule), then repost them on the Sell tab at the new price."])
	act.next = W:Button(act, L["Cancel next undercut"], 372, 52, { primary = true, size = 22 })
	act.next:SetPoint("TOPLEFT", 14, -140)
	act.next:SetScript("OnClick", function()
		for _, a in ipairs(Undercut()) do
			if NG.Owned:CanCancel(a.auctionID) then NG.Owned:Cancel(a.auctionID) return end
		end
		NG.Window:SetStatus(L["Nothing left to cancel here."], 4)
	end)
	act.one = W:Button(act, L["Cancel selected"], 372, 44, { size = 19 })
	act.one:SetPoint("TOPLEFT", 14, -204)
	act.one:SetScript("OnClick", function() if usel then NG.Owned:Cancel(usel.auctionID) end end)
	act.repost = W:Button(act, L["Repost selected (Sell tab)"], 372, 44, { size = 19 })
	act.repost:SetPoint("TOPLEFT", 14, -256)
	act.repost:SetScript("OnClick", function() if usel then TA:SellMore(usel) end end)
	act.foot = W:Text(act, 15, "textDim") act.foot:SetPoint("BOTTOM", 0, 24) act.foot:SetWidth(360) act.foot:SetWordWrap(true)
	cu.act = act
	self:Sync()
end

function TU:Sync()
	if not ulist then return end
	local l = Undercut()
	ulist:SetData(l, true)
	local checked = false
	for _, a in ipairs(NG.Owned:List()) do if a.checked then checked = true break end end
	cu.count:SetText(string.format(L["%d undercut"], #l))
	cu.note:SetShown(#l == 0)
	cu.note:SetText(#NG.Owned:List() == 0 and L["You have no auctions up."] or L["Nobody is undercutting you. Enjoy it while it lasts."])
	cu.act.next:SetEnabled(#l > 0 and NG.House:IsOpen())
	cu.act.one:SetEnabled(usel ~= nil and NG.House:IsOpen())
	cu.act.repost:SetEnabled(usel ~= nil)
	cu.act.foot:SetText(checked and L["Counts from the live listings (Check now)."] or L["From the last scan. Check now for exact counts."])
end

function TU:OnShow() NG.Owned:CountUndercut() self:Sync() end

NG:Register("OWNED_UPDATED", function()
	NG.Owned:CountUndercut()
	if ca and ca:IsVisible() then TA:Show() end
	if cu and cu:IsVisible() then TU:Sync() end
end)
NG:Register("UNDERCUT_CHECKED", function(_, l)
	if cu and cu:IsVisible() then TU:Sync() end
	if ca and ca:IsVisible() then TA:Show() end
	local n = 0
	for _, a in ipairs(l) do if a.undercut and not a.sold then n = n + 1 end end
	NG.Window:SetStatus(string.format(L["Checked: %d of your auctions undercut."], n), 6)
end)
NG:Register("CANCELLED", function()
	usel = nil
	NG.Window:SetStatus(L["Auction cancelled."], 4)
end)
NG:Register("CANCEL_FAILED", function(_, why) NG.Window:SetStatus(why, 5) end)

NG.Window:AddTab("auctions", L["Auctions"], TA)
NG.Window:AddTab("undercuts", L["Undercuts"], TU)
