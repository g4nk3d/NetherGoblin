--[[ NetherGoblin - UI/TabShopping.lua
	Two tabs:

	Shopping: your lists of things to buy (the star on the Buy tab adds the current search).
	Each item may have a most-you-will-pay price. "Search this list" looks every item up, one
	after another, and shows the cheapest of each, marked when it is within your price; click a
	line to open it on the Buy tab.

	History: what you did here (this character): posts, purchases, bids, cancels, with this
	week's totals. Sales are paid by mail and are not in this list. ]]

local _, ns = ...
local NG = ns.NG
local TS = NG:Module("TabShopping")
local TH = NG:Module("TabHistory")
local W, Skin = NG.Widgets, NG.Skin
local L = ns.L
local Num, Call, Open = NG.Num, NG.Call, NG.Open
local floor, max = math.floor, math.max

local cs, lists, items, found
local cur = 1
local run = nil     -- the list search in progress: { list, i, results }

local function KeyInfo(k)
	local AH = _G.C_AuctionHouse
	return AH and AH.GetItemKeyInfo and Open(Call(AH.GetItemKeyInfo, k)) or nil
end

function TS:Build(c)
	cs = c
	local P = NG.Window.P
	local title = W:Text(c, 28, "header", "title") title:SetPoint("TOPLEFT", P + 4, -(NG.Window.HEADER_Y + 14)) title:SetText(L["Shopping lists"])
	local top, bottom = NG.Window.TOP, NG.Window.BOTTOM
	local H = bottom - top
	-- lists
	local left = W:Panel(c, "B") left:SetPoint("TOPLEFT", P, -top) left:SetSize(300, H)
	lists = W:List(left, 292, H - 120, 46, function(r)
		r.name = W:Text(r, 19, "text") r.name:SetPoint("LEFT", 12, 0) r.name:SetPoint("RIGHT", -50, 0) r.name:SetJustifyH("LEFT")
		r.count = W:Text(r, 16, "textDim") r.count:SetPoint("RIGHT", -12, 0)
		r:SetScript("OnClick", function(self) if self.data then cur = self.data.i TS:Sync() end end)
	end, function(r, d) r.name:SetText(d.list.name) r.count:SetText(#d.list.items) end)
	lists:SetPoint("TOPLEFT", 4, -8)
	local nb = W:Button(left, L["New list"], 136, 40, { size = 17 })
	nb:SetPoint("BOTTOMLEFT", 10, 58)
	nb:SetScript("OnClick", function() cur = NG.Lists:New(L["New list"]) TS:Sync() end)
	local db = W:Button(left, L["Delete list"], 136, 40, { size = 17 })
	db:SetPoint("BOTTOMRIGHT", -10, 58)
	db:SetScript("OnClick", function() NG.Lists:Delete(cur) cur = 1 TS:Sync() end)
	c.rename = W:Edit(left, 280, 38, L["Rename this list..."], { size = 16, onEnter = function(t) NG.Lists:Rename(cur, t) c.rename:SetText("") end })
	c.rename:SetPoint("BOTTOMLEFT", 10, 12)
	-- the list's items
	local mx = P + 300 + 12
	local mw = NG.Window.W - P - 400 - 12 - mx
	local mid = W:Panel(c, "C") mid:SetPoint("TOPLEFT", mx, -top) mid:SetSize(mw, H)
	c.add = W:Edit(mid, mw - 150, 40, L["Add an item name..."], { size = 18, onEnter = function() TS:AddItem() end })
	c.add:SetPoint("TOPLEFT", 10, -10)
	local ab = W:Button(mid, L["Add"], 120, 40, { size = 18, primary = true })
	ab:SetPoint("TOPRIGHT", -10, -10)
	ab:SetScript("OnClick", function() TS:AddItem() end)
	local ml = W:Text(mid, 15, "textDim") ml:SetPoint("TOPLEFT", 12, -60) ml:SetText(L["Most you'll pay (each, optional):"])
	c.max = W:MoneyBox(mid, 32)
	c.max:SetPoint("TOPRIGHT", -10, -54)
	items = W:List(mid, mw - 8, H - 110, 44, function(r)
		r.text = W:Text(r, 19, "text") r.text:SetPoint("LEFT", 12, 0) r.text:SetPoint("RIGHT", -190, 0) r.text:SetJustifyH("LEFT")
		r.max = W:Text(r, 16, "textDim") r.max:SetPoint("RIGHT", -56, 0)
		r.del = W:Button(r, "x", 34, 30, { size = 16 })
		r.del:SetPoint("RIGHT", -8, 0)
		r.del:SetScript("OnClick", function() if r.data then NG.Lists:Remove(cur, r.data.j) TS:Sync() end end)
		r:SetScript("OnClick", function(self) if self.data then NG.Window:SelectTab("buy") NG.TabBuy:Search(self.data.item.text) end end)
	end, function(r, d)
		r.text:SetText(d.item.text)
		r.max:SetText(d.item.max and string.format(L["up to %s"], NG.Money:Text(d.item.max, { plain = true, short = true })) or "")
	end)
	items:SetPoint("TOPLEFT", 4, -102)
	c.itemsNote = W:Text(mid, 17, "textDim") c.itemsNote:SetPoint("CENTER", 0, -40) c.itemsNote:SetWidth(mw - 60) c.itemsNote:SetWordWrap(true)
	-- search the list
	local right = W:Panel(c, "A") right:SetPoint("TOPLEFT", NG.Window.W - P - 400, -top) right:SetSize(400, H)
	c.go = W:Button(right, L["Search this list"], 372, 52, { primary = true, size = 22 })
	c.go:SetPoint("TOPLEFT", 14, -14)
	c.go:SetScript("OnClick", function() if run then TS:Stop() else TS:Run() end end)
	found = W:List(right, 392, H - 90, 50, function(r)
		r.name = W:Text(r, 18, "text") r.name:SetPoint("TOPLEFT", 10, -6) r.name:SetPoint("RIGHT", -10, 0) r.name:SetJustifyH("LEFT")
		r.price = W:Text(r, 16, "textDim") r.price:SetPoint("BOTTOMLEFT", 10, 6)
		r.ok = W:Text(r, 16, "positive") r.ok:SetPoint("BOTTOMRIGHT", -10, 6)
		r:SetScript("OnClick", function(self) if self.data then NG.Window:SelectTab("buy") NG.TabBuy:Search(self.data.text) end end)
	end, function(r, d)
		r.name:SetText(d.text)
		if d.price then
			r.price:SetText(string.format(L["cheapest %s  ·  %s listed"], NG.Money:Text(d.price, { plain = true }), d.qty or 0))
			if d.max then
				r.ok:SetText(d.price <= d.max and L["within your price"] or L["too dear"])
				Skin:Paint(r.ok, d.price <= d.max and "positive" or "negative")
			else r.ok:SetText("") end
		else
			r.price:SetText(d.done and L["none listed"] or L["looking..."])
			r.ok:SetText("")
		end
	end)
	found:SetPoint("TOPLEFT", 4, -80)
	self:Sync()
end

function TS:AddItem()
	local t = cs.add:GetText()
	if t == "" then return end
	local m = cs.max:Get()
	NG.Lists:Add(cur, t, m > 0 and m or nil)
	cs.add:SetText("")
	cs.max:Set(nil)
	self:Sync()
end

function TS:Sync()
	if not lists then return end
	local all = NG.Lists:All()
	if not all[cur] then cur = 1 end
	local ld = {}
	for i, l in ipairs(all) do ld[i] = { i = i, list = l } end
	lists:SetData(ld, true)
	lists:Select(ld[cur])
	local id = {}
	for j, it in ipairs(all[cur] and all[cur].items or {}) do id[j] = { j = j, item = it } end
	items:SetData(id, true)
	cs.itemsNote:SetText(L["Empty. Add item names above, or press the star on the Buy tab."])
	cs.itemsNote:SetShown(#id == 0)
	cs.go:SetLabel(run and L["Stop"] or L["Search this list"])
	cs.go:SetEnabled(#id > 0 and NG.House:IsOpen() or run ~= nil)
end

function TS:Run()
	local l = NG.Lists:All()[cur]
	if not (l and #l.items > 0 and NG.House:IsOpen()) then return end
	run = { list = l, i = 0, results = {} }
	for j, it in ipairs(l.items) do run.results[j] = { text = it.text, max = it.max } end
	found:SetData(run.results)
	self:Next()
	self:Sync()
end

function TS:Stop() run = nil self:Sync() end

function TS:Next()
	if not run then return end
	run.i = run.i + 1
	local r = run.results[run.i]
	if not r then run = nil NG.Window:SetStatus(L["Shopping list searched."], 5) self:Sync() return end
	run.current = r
	NG.Search:Browse({ text = r.text, quiet = true })
end

NG:Register("BROWSE_RESULTS", function(_, rows, full)
	if not (run and run.current) then return end
	if not full then NG.Search:More() return end
	local r = run.current
	local want = r.text:lower()
	local best
	for _, row in ipairs(rows) do
		local info = KeyInfo(row.itemKey)
		local p = Num(row.minPrice)
		local exact = info and info.itemName and info.itemName:lower() == want
		if p and (exact or not best or not best.exact) then
			if not best or (exact and not best.exact) or p < best.p then best = { p = p, q = Num(row.totalQuantity), exact = exact } end
		end
	end
	r.price, r.qty, r.done = best and best.p, best and best.q, true
	run.current = nil
	found:Refresh()
	NG:After(0.2, function() TS:Next() end)
end)
NG:Register("BROWSE_FAILED", function() if run and run.current then run.current.done = true run.current = nil TS:Next() end end)
NG:Register("LISTS_CHANGED", function() if cs and cs:IsVisible() then TS:Sync() end end)
NG:Register("AH_CLOSED", function() run = nil end)

function TS:OnShow() self:Sync() end

---------------------------------------------------------------------------------------------
-- History
---------------------------------------------------------------------------------------------
local ch, hlist
local filter = nil
local KIND = { post = L["Posted"], buy = L["Bought"], bid = L["Bid"], cancel = L["Cancelled"] }
local KIND_ROLE = { post = "info", buy = "positive", bid = "warning", cancel = "textDim" }

function TH:Build(c)
	ch = c
	local P = NG.Window.P
	local title = W:Text(c, 28, "header", "title") title:SetPoint("TOPLEFT", P + 4, -(NG.Window.HEADER_Y + 14)) title:SetText(L["History"])
	c.totals = W:Text(c, 16, "textDim") c.totals:SetPoint("LEFT", title, "RIGHT", 24, -2)
	local x = 0
	c.filters = {}
	for i, f in ipairs({ { nil, L["All"] }, { "post", L["Posted"] }, { "buy", L["Bought"] }, { "bid", L["Bids"] }, { "cancel", L["Cancelled"] } }) do
		local b = W:Button(c, f[2], 110, 40, { size = 17 })
		b:SetPoint("TOPRIGHT", -NG.Window.HEADER_RIGHT - (4 - (i - 1)) * 116, -(NG.Window.HEADER_Y + 4))
		b:SetScript("OnClick", function() filter = f[1] TH:Sync() end)
		b.kind = f[1]
		c.filters[i] = b
	end
	local panel = W:Panel(c, "C")
	panel:SetPoint("TOPLEFT", P, -NG.Window.TOP)
	panel:SetSize(NG.Window.W - P * 2, NG.Window.BOTTOM - NG.Window.TOP)
	local w = NG.Window.W - P * 2 - 8
	hlist = W:List(panel, w, NG.Window.BOTTOM - NG.Window.TOP - 16, 44, function(r)
		r.when = W:Text(r, 16, "textDim") r.when:SetPoint("LEFT", 12, 0)
		r.kind = W:Text(r, 17, "text") r.kind:SetPoint("LEFT", 150, 0)
		r.name = W:Text(r, 18, "text") r.name:SetPoint("LEFT", 270, 0) r.name:SetWidth(420) r.name:SetJustifyH("LEFT")
		r.qty = W:Text(r, 17, "text") r.qty:SetPoint("LEFT", 700, 0)
		r.each = W:Text(r, 17, "text") r.each:SetPoint("RIGHT", -260, 0)
		r.total = W:Text(r, 18, "text") r.total:SetPoint("RIGHT", -24, 0)
		r:SetScript("OnEnter", function(self) if self.data and self.data.link and _G.GameTooltip then GameTooltip:SetOwner(self, "ANCHOR_RIGHT") GameTooltip:SetHyperlink(self.data.link) GameTooltip:Show() end end)
		r:SetScript("OnLeave", function() if _G.GameTooltip then GameTooltip:Hide() end end)
	end, function(r, d)
		r.when:SetText(_G.date and date("%b %d  %H:%M", d.t) or "")
		r.kind:SetText(KIND[d.k] or d.k)
		Skin:Paint(r.kind, KIND_ROLE[d.k] or "text")
		r.name:SetText(d.link or d.name or "?")
		r.qty:SetText("x" .. (d.q or 1))
		r.each:SetText(d.u and (NG.Money:Text(d.u) .. " " .. L["each"]) or "")
		r.total:SetText(d.tot and NG.Money:Text(d.tot) or "")
	end)
	hlist:SetPoint("TOPLEFT", 4, -8)
	c.note = W:Text(panel, 18, "textDim") c.note:SetPoint("CENTER") c.note:SetText(L["Nothing yet. Buy something, post something: it all lands here."])
end

function TH:Sync()
	if not hlist then return end
	local rows = NG.Ledger:List(filter)
	hlist:SetData(rows, true)
	ch.note:SetShown(#rows == 0)
	for _, b in ipairs(ch.filters) do b:SetActive(b.kind == filter) end
	local t = NG.Ledger:Totals(7)
	ch.totals:SetText(string.format(L["This week: spent %s  ·  posted %s"], NG.Money:Text(t.spent, { plain = true, short = true }), NG.Money:Text(t.posted, { plain = true, short = true })))
end

function TH:OnShow() self:Sync() end
NG:Register("LEDGER_CHANGED", function() if ch and ch:IsVisible() then TH:Sync() end end)

NG.Window:AddTab("shopping", L["Shopping"], TS)
NG.Window:AddTab("history", L["History"], TH)
