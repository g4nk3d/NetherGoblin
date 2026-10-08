--[[ NetherGoblin - UI/TabSell.lua
	The Sell tab: what you carry that can be sold (left), what it sells for right now (middle),
	and the post (right): price each (filled in from the cheapest listing minus your undercut),
	quantity, duration, deposit, what you keep after the cut, and Post.

	If a price looks wrong (under the vendor price, or far under its usual price), the first
	click on Post shows why and the button becomes "Post anyway"; the second click posts. ]]

local _, ns = ...
local NG = ns.NG
local Sell = NG:Module("TabSell")
local W, Skin = NG.Widgets, NG.Skin
local L = ns.L
local Num, Call = NG.Num, NG.Call
local floor, max, min = math.floor, math.max, math.min

local c, bags, listings, post
local cur = nil   -- { item, detail, qty, duration, armed }

-- 1 / 2 / 3 as the game counts them; the label is the game's own ("12 Hours") shortened,
-- else Short / Medium / Long
local DURATIONS = { { 1, L["Short"], "AUCTION_DURATION_ONE" }, { 2, L["Medium"], "AUCTION_DURATION_TWO" }, { 3, L["Long"], "AUCTION_DURATION_THREE" } }
local function DurationLabel(d)
	local g = NG.Str(_G[d[3]])
	if g then
		local n = g:match("^(%d+)")
		if n then return n .. " " .. L["h"] end
		return g
	end
	return d[2]
end

local function Panel(parent, tex, x, w)
	local p = W:Panel(parent, tex)
	p:SetPoint("TOPLEFT", x, -NG.Window.TOP)
	p:SetSize(w, NG.Window.BOTTOM - NG.Window.TOP)
	return p
end

function Sell:Build(container)
	c = container
	local P = NG.Window.P
	local title = W:Text(c, 28, "header", "title") title:SetPoint("TOPLEFT", P + 4, -(NG.Window.HEADER_Y + 14)) title:SetText(L["Sell"])
	c.rule = W:Text(c, 16, "textDim") c.rule:SetPoint("LEFT", title, "RIGHT", 24, -2)
	local refresh = W:Button(c, L["Refresh bags"], 170, 44, { size = 19 })
	refresh:SetPoint("TOPRIGHT", -NG.Window.HEADER_RIGHT, -(NG.Window.HEADER_Y + 2))
	refresh:SetScript("OnClick", function() Sell:Bags() end)
	-- left: your items
	local left = Panel(c, "B", P, 300)
	local lt = W:Text(left, 17, "header") lt:SetPoint("TOPLEFT", 14, -12) lt:SetText(L["In your bags"])
	bags = W:List(left, 292, NG.Window.BOTTOM - NG.Window.TOP - 48, 48, function(r)
		r.icon = W:Icon(r, 36) r.icon:SetPoint("LEFT", 6, 0)
		r.name = W:Text(r, 18, "text") r.name:SetPoint("LEFT", 50, 0) r.name:SetPoint("RIGHT", -50, 0) r.name:SetJustifyH("LEFT")
		r.count = W:Text(r, 17, "textDim") r.count:SetPoint("RIGHT", -10, 0)
		r:SetScript("OnClick", function(self) if self.data then Sell:Select(self.data) end end)
		r:SetScript("OnEnter", function(self)
			if self.data and self.data.link and _G.GameTooltip then GameTooltip:SetOwner(self, "ANCHOR_RIGHT") GameTooltip:SetHyperlink(self.data.link) GameTooltip:Show() end
		end)
		r:SetScript("OnLeave", function() if _G.GameTooltip then GameTooltip:Hide() end end)
	end, function(r, d)
		r.icon:SetItem(d.icon, d.quality)
		r.name:SetText(d.name or "?")
		local col = d.quality and _G.ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[d.quality]
		if col then r.name:SetTextColor(col.r, col.g, col.b) end
		r.count:SetText("x" .. d.count)
	end)
	bags:SetPoint("TOPLEFT", 4, -40)
	c.bagNote = W:Text(left, 16, "textDim") c.bagNote:SetPoint("CENTER") c.bagNote:SetWordWrap(true) c.bagNote:SetWidth(260)
	-- middle: listings now
	local mx = P + 300 + 12
	local mw = NG.Window.W - P - 400 - 12 - mx
	local mid = Panel(c, "C", mx, mw)
	local mt = W:Text(mid, 17, "header") mt:SetPoint("TOPLEFT", 14, -12) mt:SetText(L["For sale right now"])
	c.midTitle = mt
	listings = W:List(mid, mw - 8, NG.Window.BOTTOM - NG.Window.TOP - 48, 40, function(r)
		r.price = W:Text(r, 19, "text") r.price:SetPoint("LEFT", 14, 0)
		r.qty = W:Text(r, 18, "text") r.qty:SetPoint("RIGHT", -110, 0)
		r.own = W:Text(r, 16, "positive") r.own:SetPoint("RIGHT", -14, 0)
		r:SetScript("OnClick", function(self)
			local d = self.data
			if d and d.unit and cur then post.price:Set(d.own and NG.Sell:RoundPrice(cur.item, d.unit) or NG.Sell:Undercut(d.unit, cur.item)) Sell:Update() end
		end)
	end, function(r, d)
		r.price:SetText(NG.Money:Text(d.unit))
		r.qty:SetText("x" .. (d.qty or 1))
		r.own:SetText(d.own and L["yours"] or "")
	end)
	listings:SetPoint("TOPLEFT", 4, -40)
	c.listNote = W:Text(mid, 16, "textDim") c.listNote:SetPoint("CENTER") c.listNote:SetWordWrap(true) c.listNote:SetWidth(mw - 60)
	-- right: the post
	local rx = NG.Window.W - P - 400
	post = Panel(c, "A", rx, 400)
	Sell.post = post   -- for probes
	local plate = W:NamePlate(post, 360, 22)
	plate:SetPoint("TOPLEFT", 20, -2)
	post.name, post.plate = plate.name, plate
	-- the item's name keeps its quality colour (set when an item is picked), in either look
	post.name.keepColour = true
	Skin:Unpaint(post.name)
	local y = plate.h + 4
	post.chart = NG.Chart:New(post, 372, 104)
	post.chart:SetPoint("TOPLEFT", 14, -y)
	y = y + 116
	local function Label(text, yy) local t = W:Text(post, 17, "textDim") t:SetPoint("TOPLEFT", 16, -yy) t:SetText(text) return t end
	Label(L["Price each"], y + 9)
	post.price = W:MoneyBox(post, 36, function() if cur then cur.armed = false Sell:Update() end end)
	post.price:SetPoint("TOPRIGHT", -14, -y)
	post.why = W:Text(post, 14, "textDim") post.why:SetPoint("TOPRIGHT", -16, -(y + 40))
	y = y + 62
	-- gear only: an optional starting bid (empty = buyout only)
	post.bidLabel = Label(L["Starting bid"], y + 9)
	post.bid = W:MoneyBox(post, 36, function() if cur then cur.armed = false Sell:Update() end end)
	post.bid:SetPoint("TOPRIGHT", -14, -y)
	post.bidNote = W:Text(post, 14, "textDim") post.bidNote:SetPoint("TOPRIGHT", -16, -(y + 40)) post.bidNote:SetText(L["empty = same as the price (buyout only)"])
	y = y + 50
	Label(L["Quantity"], y + 9)
	post.qty = W:Edit(post, 90, 36, "", { numeric = true, maxLetters = 5, justify = "CENTER", size = 19,
		onChange = function(text, user) if user and cur then cur.qty = max(1, tonumber(text) or 1) cur.armed = false Sell:Update(true) end end })
	post.qty:SetPoint("TOPLEFT", 140, -y)
	local maxb = W:Button(post, L["All"], 80, 36, { size = 17 })
	maxb:SetPoint("LEFT", post.qty, "RIGHT", 8, 0)
	maxb:SetScript("OnClick", function() if cur then cur.qty = NG.Sell:MaxQty(cur.item) cur.armed = false Sell:Update() end end)
	post.stack = W:Text(post, 15, "textDim") post.stack:SetPoint("LEFT", maxb, "RIGHT", 10, 0)
	y = y + 50
	Label(L["Duration"], y + 6)
	post.dur = {}
	for i, d in ipairs(DURATIONS) do
		local b = W:Button(post, DurationLabel(d), 76, 32, { size = 15 })
		if NG.Str(_G[d[3]]) then W:Tip(b, _G[d[3]]) end
		b:SetPoint("TOPLEFT", 140 + (i - 1) * 82, -y)
		b:SetScript("OnClick", function() if cur then cur.duration = d[1] NG.Settings:Set("sell.duration", d[1]) cur.armed = false Sell:Update() end end)
		post.dur[i] = b
	end
	y = y + 46
	local function Row(label, yy)
		Label(label, yy)
		local v = W:Text(post, 18, "text") v:SetPoint("TOPRIGHT", -16, -yy)
		return v
	end
	post.total = Row(L["Total"], y)
	post.deposit = Row(L["Deposit"], y + 28)
	post.keep = Row(L["You keep (after 5% cut)"], y + 56)
	y = y + 90
	post.warn = W:Text(post, 15, "warning")
	post.warn:SetPoint("TOPLEFT", 16, -y) post.warn:SetPoint("TOPRIGHT", -16, -y)
	post.warn:SetWordWrap(true) post.warn:SetJustifyH("LEFT") post.warn:SetJustifyV("TOP")
	post.warn:SetHeight(60)
	post.button = W:Button(post, L["Post"], 372, 48, { primary = true, size = 26 })
	post.button:SetPoint("BOTTOMLEFT", 14, 14)
	post.button:SetScript("OnClick", function() Sell:PostClick() end)
	post.empty = W:Text(post, 18, "textDim") post.empty:SetPoint("CENTER", 0, 60) post.empty:SetText(L["Pick an item from your bags."])
	self:Clear()
end

function Sell:Clear()
	cur = nil
	if not post then return end
	post.name:SetText("") post.chart:Clear() post.price:Set(nil) post.bid:Set(nil) post.qty:SetText("")
	post.bidLabel:Hide() post.bid:Hide() post.bidNote:Hide()
	post.why:SetText("") post.total:SetText("-") post.deposit:SetText("-") post.keep:SetText("-") post.warn:SetText("")
	post.button:SetEnabled(false) post.button:SetLabel(L["Post"])
	post.empty:Show()
	listings:SetData({})
	c.listNote:SetText(L["Pick an item to see what it sells for."])
	c.listNote:Show()
end

function Sell:Bags()
	local items = NG.Sell:BagItems()
	bags:SetData(items, true)
	if #items == 0 then c.bagNote:SetText(L["Nothing in your bags can go on the auction house."]) c.bagNote:Show() else c.bagNote:Hide() end
	-- the selected item still there?
	if cur then
		local still = false
		for _, it in ipairs(items) do if it.itemID == cur.item.itemID and (it.commodity or it.link == cur.item.link) then still = it break end end
		if still then cur.item = still bags:Select(still) else self:Clear() end
	end
end

function Sell:Rule()
	local mode = NG.Settings:Get("sell.undercutMode")
	local txt = mode == "percent" and string.format(L["Undercut: %s%%"], tostring(NG.Settings:Get("sell.undercutPercent")))
		or string.format(L["Undercut: %s"], NG.Money:Text(NG.Settings:Get("sell.undercutCopper"), { plain = true }))
	c.rule:SetText(txt .. "  ·  " .. L["change it in Settings"])
end

function Sell:Select(item)
	bags:Select(item)
	cur = { item = item, qty = item.commodity and NG.Sell:MaxQty(item) or 1, duration = tonumber(NG.Settings:Get("sell.duration")) or 3 }
	post.empty:Hide()
	post.name:SetText(item.name or "?")
	local col = item.quality and _G.ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality]
	if col then post.name:SetTextColor(col.r, col.g, col.b) end
	local e, key = NG.Prices:ForLink(item.link)
	post.chart:SetHistory(key and NG.Prices:History(key) or {})
	-- a price from what we know until the live listings arrive
	local p, why = NG.Sell:Suggest(nil, item)
	post.price:Set(p)
	cur.why = why
	listings:SetData({})
	c.listNote:SetText(L["Asking the auction house..."])
	c.listNote:Show()
	if item.itemKey then
		NG.Search:Item(item.itemKey, function(d)
			if cur and cur.item == item then
				cur.detail = d
				listings:SetData(d.rows)
				if #d.rows == 0 then c.listNote:SetText(L["None listed. You set the price."]) c.listNote:Show() else c.listNote:Hide() end
				local sp, sw = NG.Sell:Suggest(d, item)
				if sp then post.price:Set(sp) cur.why = sw end
				Sell:Update()
			end
		end)
	end
	self:Update()
end

function Sell:Update(keepQty)
	if not cur then return end
	local item = cur.item
	local maxQ = NG.Sell:MaxQty(item)
	cur.qty = min(max(1, cur.qty or 1), maxQ)
	if not keepQty then post.qty:SetText(tostring(cur.qty)) end
	post.stack:SetText(string.format(L["of %d"], maxQ))
	for i, b in ipairs(post.dur) do b:SetActive(DURATIONS[i][1] == cur.duration) end
	-- a starting bid only where the game bids at all (Forever doesn't)
	local gear = item.commodity == false and not NG:IsForever()
	post.bidLabel:SetShown(gear) post.bid:SetShown(gear) post.bidNote:SetShown(gear)
	local unit = post.price:Get()
	local whyText = { undercut = L["cheapest listing minus your undercut"], yours = L["you're already the cheapest"], market = L["from its usual price (none listed)"], none = L["no price known: set one"] }
	local why = whyText[cur.why or "none"] or ""
	if NG.Sell:PriceStep(item) == 100 then why = why .. "  " .. L["(gear sells in whole silver here)"] end
	post.why:SetText(why)
	if unit and unit > 0 then
		local total = unit * cur.qty
		post.total:SetText(NG.Money:Text(total))
		post.keep:SetText(NG.Money:Text(floor(total * NG.Sell.CUT)))
		local dep = NG.Sell:Deposit(item, cur.duration, cur.qty)
		post.deposit:SetText(dep and NG.Money:Text(dep) or "-")
	else
		post.total:SetText("-") post.keep:SetText("-") post.deposit:SetText("-")
	end
	local warns = (unit and unit > 0) and NG.Sell:Warnings(item, unit, cur.qty) or {}
	post.warn:SetText(cur.armed and table.concat(warns, "\n") or "")
	post.button:SetLabel(cur.armed and #warns > 0 and L["Post anyway"] or L["Post"])
	post.button:SetEnabled(unit ~= nil and unit > 0 and NG.House:IsOpen())
end

function Sell:PostClick()
	if not cur then return end
	local unit = post.price:Get()
	if not unit or unit <= 0 then return end
	-- a price the game won't take as typed (gear on Forever: whole silver): bring it onto the
	-- step, show it, and let the next press post it
	local rounded = NG.Sell:RoundPrice(cur.item, unit)
	if rounded ~= unit then
		post.price:Set(rounded)
		cur.armed = false
		self:Update()
		NG.Window:SetStatus(string.format(L["Gear sells in whole silver here: rounded to %s. Press Post again."], NG.Money:Text(rounded, { plain = true })), 8)
		return
	end
	local warns = NG.Sell:Warnings(cur.item, unit, cur.qty)
	if #warns > 0 and not cur.armed then
		cur.armed = true
		self:Update()
		return
	end
	cur.armed = false
	local bid = cur.item.commodity == false and not NG:IsForever() and post.bid:Get() or nil
	if bid and bid <= 0 then bid = nil end
	if bid and bid > unit then
		NG.Window:SetStatus(L["The starting bid can't be above the price."], 5)
		return
	end
	if NG.Sell:Post(cur.item, cur.duration, cur.qty, unit, bid) then
		post.button:SetEnabled(false)
		post.button:SetLabel(L["Posting..."])
	end
end

function Sell:OnShow()
	self:Rule()
	self:Bags()
end

NG:Register("POSTED", function(_, p)
	if not c then return end
	NG.Window:SetStatus(string.format(L["Posted %s x%d at %s each."], p.item.name or "?", p.qty, NG.Money:Text(p.unit, { plain = true })), 6)
	NG:After(0.3, function() if c:IsVisible() then Sell:Bags() if cur and cur.item.itemKey then NG.Search:Item(cur.item.itemKey, function(d) if cur then cur.detail = d listings:SetData(d.rows) end end) end Sell:Update() end end)
end)
NG:Register("POST_FAILED", function(_, why) if c then NG.Window:SetStatus(why, 6) Sell:Update() end end)
NG:Register("SELL_PROGRESS", function(_, done, total) if c and total > 0 then NG.Window:SetStatus(string.format(L["Posting %d of %d..."], done, total), 4) end end)
NG:On("BAG_UPDATE_DELAYED", function() if c and c:IsVisible() then NG:Debounce("sellbags", 0.2, function() Sell:Bags() end) end end)
NG:Register("SETTING_CHANGED", function(_, key) if c and key:find("^sell%.") then Sell:Rule() end end)

NG.Window:AddTab("sell", L["Sell"], Sell)
