--[[ NetherGoblin - UI/TabBuy.lua
	The Buy tab, laid out exactly as the approved design: favourites star, search box, Filters,
	Search, market label (top); categories and recent searches (left); results with price, item,
	quantity and a deal badge (middle); the selected item (right, UI/Inspector.lua).

	Shift-click a result: put its link in chat. Ctrl-click: try it on. The column headers sort
	what has been loaded; scrolling to the end asks the server for the next page. ]]

local _, ns = ...
local NG = ns.NG
local Buy = NG:Module("TabBuy")
local W, Skin = NG.Widgets, NG.Skin
local L = ns.L
local Num, Call, Open = NG.Num, NG.Call, NG.Open
local floor, max, min = math.floor, math.max, math.min

local c, list, recentButtons = nil, nil, {}
local state = { cat = nil, sort = "price", desc = false, filters = { exact = false, usable = false, minLevel = nil, maxLevel = nil, quality = {} } }

-- rarity filters: the game's own quality filters (several picked = any of them; none = all)
Buy.QUALITIES = {
	{ 0, "PoorQuality", L["Poor"] }, { 1, "CommonQuality", L["Common"] }, { 2, "UncommonQuality", L["Uncommon"] },
	{ 3, "RareQuality", L["Rare"] }, { 4, "EpicQuality", L["Epic"] }, { 5, "LegendaryQuality", L["Legendary"] },
}

-- the item classes on the left (game class IDs; one search filter each)
Buy.CATEGORIES = {
	{ L["Weapons"], 2, "Interface\\Icons\\INV_Sword_04" },
	{ L["Armor"], 4, "Interface\\Icons\\INV_Chest_Chain" },
	{ L["Containers"], 1, "Interface\\Icons\\INV_Misc_Bag_08" },
	{ L["Consumables"], 0, "Interface\\Icons\\INV_Potion_51" },
	{ L["Trade Goods"], 7, "Interface\\Icons\\INV_Fabric_Linen_01" },
	{ L["Ammo"], 6, "Interface\\Icons\\INV_Ammo_Arrow_01" },
	{ L["Recipes"], 9, "Interface\\Icons\\INV_Scroll_03" },
	{ L["Quest Items"], 12, "Interface\\Icons\\INV_Misc_Note_01" },
	{ L["Miscellaneous"], 15, "Interface\\Icons\\INV_Misc_Gear_01" },
}

local function KeyInfo(k)
	local AH = _G.C_AuctionHouse
	return AH and AH.GetItemKeyInfo and Open(Call(AH.GetItemKeyInfo, k)) or nil
end

local function DealOf(row)
	local base, lv = NG.Prices:KeysOfItemKey(row.itemKey)
	local mv = NG.Prices:Market(lv or base)
	local p = Num(row.minPrice)
	if not (mv and p and mv > 0) then return L["New"], "fair", nil end
	local r = p / mv
	if r <= 0.8 then return L["Great"], "great", "down" end
	if r <= 0.95 then return L["Good"], "good", "down" end
	if r <= 1.1 then return L["Fair"], "fair", nil end
	return L["Pricey"], "pricey", "up"
end

local function Filters()
	local E = _G.Enum and _G.Enum.AuctionHouseFilter
	local out = {}
	if E then
		if state.filters.exact and E.ExactMatch then out[#out + 1] = E.ExactMatch end
		if state.filters.usable and E.UsableOnly then out[#out + 1] = E.UsableOnly end
		for _, q in ipairs(Buy.QUALITIES) do
			if state.filters.quality[q[1]] and E[q[2]] then out[#out + 1] = E[q[2]] end
		end
	end
	return out
end

function Buy:Search(text)
	if text ~= nil then c.search:SetText(text) end
	text = c.search:GetText()
	local cls = state.cat and state.cat.filters or {}
	if not NG.House:IsOpen() then return end
	NG.Inspector:Clear()
	list:Select(nil)
	NG.Search:Browse({ text = text, classFilters = cls, filters = Filters(), minLevel = state.filters.minLevel, maxLevel = state.filters.maxLevel })
	c.resultNote:SetText(L["Searching..."])
	c.resultNote:Show()
end

-- the level an item needs (nil until the game has described the item; it is asked to)
local askedInfo = {}
local function RequiredLevel(itemID)
	local C = _G.C_Item
	local fn = (C and C.GetItemInfo) or _G.GetItemInfo
	if not fn then return nil end
	local minLevel = select(5, Call(fn, itemID))
	minLevel = Num(minLevel)
	if minLevel == nil and C and C.RequestLoadItemDataByID and not askedInfo[itemID] then
		askedInfo[itemID] = true
		Call(C.RequestLoadItemDataByID, itemID)
	end
	return minLevel
end
Buy.RequiredLevel = RequiredLevel

-- the level range, applied here as well as by the server (an item the game has not described
-- yet is kept; the list is refreshed when its description arrives)
local function InLevelRange(r)
	local lo, hi = state.filters.minLevel, state.filters.maxLevel
	if not (lo or hi) then return true end
	local lv = RequiredLevel(r.itemKey.itemID)
	if not lv then return true end
	if lo and lv < lo then return false end
	if hi and lv > hi then return false end
	return true
end

local function SortRows(rows)
	local key, desc = state.sort, state.desc
	local out = {}
	for _, r in ipairs(rows) do if InLevelRange(r) then out[#out + 1] = r end end
	table.sort(out, function(a, b)
		local x, y
		if key == "name" then
			local ia, ib = KeyInfo(a.itemKey), KeyInfo(b.itemKey)
			x, y = ia and ia.itemName or "~", ib and ib.itemName or "~"
		elseif key == "qty" then
			x, y = Num(a.totalQuantity) or 0, Num(b.totalQuantity) or 0
		elseif key == "lvl" then
			x, y = RequiredLevel(a.itemKey.itemID) or 0, RequiredLevel(b.itemKey.itemID) or 0
		else
			x, y = Num(a.minPrice) or 0, Num(b.minPrice) or 0
		end
		if x == y then return (Num(a.itemKey.itemID) or 0) < (Num(b.itemKey.itemID) or 0) end
		if desc then return x > y end
		return x < y
	end)
	return out
end

function Buy:ShowRows()
	if not list then return end
	Buy.list, Buy.state = list, state
	list:SetData(SortRows(NG.Search:Rows()), true)
end

---------------------------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------------------------
local function Header(parent)
	local P = NG.Window.P
	local hy = NG.Window.HEADER_Y
	local star = W:Button(parent, "", 52, 52)
	star:SetPoint("TOPLEFT", P, -hy)
	local st = star:CreateTexture(nil, "OVERLAY")
	st:SetTexture("Interface\\Common\\ReputationStar") st:SetTexCoord(0, 0.5, 0, 0.5)
	st:SetSize(30, 30) st:SetPoint("CENTER") st:SetVertexColor(0.16, 0.1, 0.03)
	star:SetScript("OnClick", function()
		local text = c.search:GetText()
		if text ~= "" then
			NG.Lists:Add(1, text)
			NG.Window:SetStatus(string.format(L["\"%s\" added to your shopping list."], text), 5)
		else
			NG.Window:SelectTab("shopping")
		end
	end)
	W:Tip(star, L["Favourite"], L["Adds this search to your shopping list (Shopping tab). With an empty search box it opens your lists."])
	-- a single-line box clipped to its own rectangle: typing scrolls the text left, nothing spills out
	c.search = W:Edit(parent, 500, 48, L["Search items, e.g. Linen Cloth"], { size = 21, padL = 40, maxLetters = 60, onEnter = function() Buy:Search() end })
	c.search:SetPoint("TOPLEFT", P + 64, -(hy + 2))
	local mg = c.search:CreateTexture(nil, "OVERLAY")
	mg:SetTexture("Interface\\Common\\UI-Searchbox-Icon") mg:SetSize(18, 18) mg:SetPoint("LEFT", 12, -1)
	mg:SetVertexColor(0.75, 0.7, 0.6)
	-- the title plaque hangs over this row: its left spike at x 596-620 and its red cloth at
	-- 806-848; Filters sits between them and Search just right of the cloth
	local fb = W:Button(parent, L["Filters"], 120, 48, { size = 22 })
	fb:SetPoint("TOPLEFT", P + 632, -(hy + 2))
	fb:SetScript("OnClick", function() Buy:ToggleFilters(fb) end)
	local sb = W:Button(parent, L["Search"], 130, 48, { size = 22, primary = true })
	sb:SetPoint("TOPLEFT", P + 850, -(hy + 2))
	sb:SetScript("OnClick", function() Buy:Search() end)
	c.filterButton = fb
	Buy.filterButtonForProbe = fb
end

---------------------------------------------------------------------------------------------
-- The category tree: the game's own auction categories (the table its window uses), with
-- every sub-category and sub-sub-category, each carrying the exact filters the game's window
-- sends. Without that table (it loads with the auction house) the nine fixed classes stand in.
---------------------------------------------------------------------------------------------
local CAT_W = 300
local tree, treeRows, recentBox = nil, {}, nil
local ICON_BY_NAME = {}   -- the top level's icons, by the game's own category names
local function IconFor(name)
	if not next(ICON_BY_NAME) then
		local map = { WEAPONS = "weapons", ARMOR = "armor", CONTAINERS = "containers", CONSUMABLES = "consumables", TRADE_GOODS = "trade",
			PROJECTILE = "ammo", QUIVER = "ammo", RECIPES = "recipes", QUEST_ITEMS = "quest", MISCELLANEOUS = "misc", GLYPHS = "recipes", GEMS = "trade",
			BATTLE_PETS = "misc", ITEM_ENHANCEMENT = "trade" }
		for k, v in pairs(map) do
			local g = _G["AUCTION_CATEGORY_" .. k]
			if type(g) == "string" then ICON_BY_NAME[g] = v end
		end
		for _, cat in ipairs(Buy.CATEGORIES) do ICON_BY_NAME[cat[1]] = ICON_BY_NAME[cat[1]] or cat[3] end
	end
	for _, cat in ipairs(Buy.CATEGORIES) do if cat[1] == name then return cat[3] end end
	local k = ICON_BY_NAME[name]
	for _, cat in ipairs(Buy.CATEGORIES) do if cat[3] == k then return cat[3] end end
	return "Interface\\Icons\\INV_Misc_Gear_01"
end

-- nodes: { name, filters, children, depth, parent, open }
local function Node(entry, depth, parent)
	local n = { name = NG.Str(entry.name) or "?", filters = type(entry.filters) == "table" and entry.filters or {}, depth = depth, parent = parent, children = {} }
	if type(entry.subCategories) == "table" then
		for _, sub in ipairs(entry.subCategories) do n.children[#n.children + 1] = Node(sub, depth + 1, n) end
	end
	return n
end

-- The game's category list carries a WoW Token entry (flagged WOW_TOKEN_FLAG). Forever has no
-- token; elsewhere it is shown only while the commerce system says tokens trade.
local function IsTokenCategory(entry)
	local flags = type(entry.flags) == "table" and entry.flags or nil
	local name = NG.Str(entry.name)
	local isToken = (flags and flags.WOW_TOKEN_FLAG) or (name ~= nil and (name == _G.AUCTION_CATEGORY_WOW_TOKEN or name == "WoW Token"))
	if not isToken then return false end
	if NG:IsForever() then return true end
	local TP = _G.C_WowTokenPublic
	return not (TP and TP.GetCommerceSystemStatus and Call(TP.GetCommerceSystemStatus) == true)
end

function Buy:BuildTree()
	local roots = {}
	local AC = rawget(_G, "AuctionCategories")
	if type(AC) == "table" and #AC > 0 then
		for _, cat in ipairs(AC) do
			if type(cat) == "table" and not IsTokenCategory(cat) then roots[#roots + 1] = Node(cat, 0, nil) end
		end
	else
		for _, cat in ipairs(Buy.CATEGORIES) do roots[#roots + 1] = { name = cat[1], filters = { { classID = cat[2] } }, depth = 0, children = {} } end
	end
	tree = roots
	Buy.tree = tree
	return tree
end

-- the rows shown: open nodes show their children under them
local function Flatten()
	local out = {}
	local function walk(nodes)
		for _, n in ipairs(nodes) do
			out[#out + 1] = n
			if n.open and #n.children > 0 then walk(n.children) end
		end
	end
	walk(tree or Buy:BuildTree())
	return out
end

-- fold a branch and everything under it
local function Close(n)
	n.open = false
	for _, ch in ipairs(n.children) do Close(ch) end
end

-- pick one entry: its siblings fold (one open branch per level, like an accordion) and it
-- opens when it has anything under it
local function Open(n)
	local siblings = n.parent and n.parent.children or tree
	for _, s in ipairs(siblings or {}) do if s ~= n then Close(s) end end
	if #n.children > 0 then n.open = true end
end

function Buy:SelectNode(n)
	if state.cat == n then
		-- the same entry again: fold it, or open it back up
		if #n.children > 0 then if n.open then Close(n) else Open(n) end end
	else
		state.cat = n
		Open(n)
	end
	self:SyncCategories()
	self:Search()
end

local function Categories(parent)
	local top, bottom = NG.Window.TOP, NG.Window.BOTTOM
	local box = W:Panel(parent, "B")
	box:SetPoint("TOPLEFT", NG.Window.P, -top)
	box:SetSize(CAT_W, bottom - top)
	local RECENT_H = 150
	local RH = 44
	local catList = W:List(box, CAT_W - 8, (bottom - top) - RECENT_H - 12, RH, function(r)
		r.arrow = W:Text(r, 16, "textDim") r.arrow:SetPoint("LEFT", 10, 0)
		r.icon = W:Icon(r, 30)
		r.text = W:Text(r, 19, "text") r.text:SetJustifyH("LEFT")
		r.bar = r:CreateTexture(nil, "ARTWORK") r.bar:SetTexture(Skin.WHITE) r.bar:SetPoint("TOPLEFT", 0, -6) r.bar:SetPoint("BOTTOMLEFT", 0, 6) r.bar:SetWidth(4)
		Skin:Paint(r.bar, "accent")
		r:SetScript("OnClick", function(self) if self.data then Buy:SelectNode(self.data) end end)
	end, function(r, n, sel)
		local x = 10 + n.depth * 22
		r.arrow:ClearAllPoints() r.arrow:SetPoint("LEFT", x, 0)
		r.arrow:SetText(#n.children > 0 and (n.open and "v" or ">") or "")
		r.arrow:SetShown(#n.children > 0)
		r.icon:SetShown(n.depth == 0)
		if n.depth == 0 then
			r.icon:ClearAllPoints() r.icon:SetPoint("LEFT", x + 18, 0)
			r.icon:SetItem(IconFor(n.name), false)
			r.text:ClearAllPoints() r.text:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
		else
			r.text:ClearAllPoints() r.text:SetPoint("LEFT", x + 18, 0)
		end
		r.text:SetPoint("RIGHT", -6, 0)
		r.text:SetText(n.name)
		local on = state.cat == n
		-- a parent of the selected node is marked more quietly
		local under = false
		local p = state.cat and state.cat.parent
		while p do if p == n then under = true break end p = p.parent end
		Skin:Paint(r.text, on and "header" or (under and "accent" or "text"))
		Skin:Font(r.text, "body", n.depth == 0 and 19 or 17)
		r.bar:SetShown(on)
	end)
	catList:SetPoint("TOPLEFT", 4, -6)
	-- the selected row is highlighted by the list itself (rowSel); make the list know it
	Buy.catList = catList
	-- recent searches, fixed at the bottom
	local ry = (bottom - top) - RECENT_H
	local line = box:CreateTexture(nil, "ARTWORK") line:SetTexture(Skin.WHITE) line:SetHeight(1)
	line:SetPoint("TOPLEFT", 14, -ry) line:SetPoint("TOPRIGHT", -14, -ry)
	Skin:Paint(line, "border")
	local rt = W:Text(box, 16, "header") rt:SetPoint("TOPLEFT", 14, -(ry + 9)) rt:SetText(L["Recent searches"])
	for j = 1, 3 do
		local b = CreateFrame("Button", nil, box)
		b:SetSize(CAT_W - 24, 30)
		b:SetPoint("TOPLEFT", 12, -(ry + 30 + (j - 1) * 36))
		local bg = b:CreateTexture(nil, "BACKGROUND") bg:SetTexture(NG.MEDIA .. "Pill") bg:SetAllPoints()
		Skin:Paint(bg, "rowA")
		local hl = b:CreateTexture(nil, "HIGHLIGHT") hl:SetTexture(NG.MEDIA .. "Pill") hl:SetAllPoints() hl:SetVertexColor(1, 0.85, 0.5, 0.1)
		local ic = b:CreateTexture(nil, "ARTWORK") ic:SetTexture("Interface\\Common\\UI-Searchbox-Icon") ic:SetSize(13, 13) ic:SetPoint("LEFT", 10, 0)
		ic:SetVertexColor(0.7, 0.66, 0.58)
		b.text = W:Text(b, 16, "text")
		b.text:SetPoint("LEFT", 30, 0) b.text:SetPoint("RIGHT", -8, 0) b.text:SetJustifyH("LEFT")
		b:SetScript("OnClick", function(self) if self.query then Buy:Search(self.query) end end)
		recentButtons[j] = b
	end
	Buy:SyncCategories()
end

function Buy:SyncCategories()
	if not self.catList then return end
	local rows = Flatten()
	self.catList.selected = state.cat
	self.catList:SetData(rows, true)
end

-- the game's category table arrives with its auction house code (loaded on the first visit,
-- maybe a moment after our window): adopt it as soon as it is there
function Buy:AdoptGameTree()
	if Buy.treeFromGame or not c then return end
	local AC = rawget(_G, "AuctionCategories")
	if type(AC) == "table" and #AC > 0 then
		Buy.treeFromGame = true
		state.cat = nil
		Buy:BuildTree()
		Buy:SyncCategories()
	end
end
NG:Register("AH_OPEN", function() Buy:AdoptGameTree() NG:After(0.5, function() Buy:AdoptGameTree() end) end)
NG:On("ADDON_LOADED", function(_, name) if name == "Blizzard_AuctionHouseUI" then NG:After(0, function() Buy:AdoptGameTree() end) end end)

function Buy:SyncRecent()
	local rec = NG.Lists:Recent()
	for j, b in ipairs(recentButtons) do
		local q = rec[j]
		b.query = q
		b.text:SetText(q or "")
		b:SetShown(q ~= nil)
	end
end

local function Results(parent)
	local top, bottom = NG.Window.TOP, NG.Window.BOTTOM
	local x1 = NG.Window.P + CAT_W + 12
	local w = (NG.Window.W - NG.Window.P - 400 - 12) - x1
	local box = W:Panel(parent, "C")
	box:SetPoint("TOPLEFT", x1, -top)
	box:SetSize(w, bottom - top)
	-- column headers
	local head = CreateFrame("Frame", nil, box)
	head:SetPoint("TOPLEFT", 8, -8) head:SetSize(w - 16, 38)
	local hb = head:CreateTexture(nil, "BACKGROUND") hb:SetTexture(Skin.WHITE) hb:SetAllPoints()
	Skin:Paint(hb, "rowSel", { mul = 0.85 })
	W.Edges(head, "BORDER", 1, "border")
	local function HeadButton(label, key, x, anchor, width)
		local b = CreateFrame("Button", nil, head)
		b:SetSize(width, 38)
		b:SetPoint(anchor, head, anchor == "LEFT" and "LEFT" or "RIGHT", x, 0)
		local t = W:Text(b, 19, "header")
		t:SetPoint(anchor, 0, 0) t:SetText(label)
		local arrow = b:CreateTexture(nil, "OVERLAY")
		arrow:SetSize(12, 12) arrow:SetPoint(anchor == "LEFT" and "LEFT" or "RIGHT", t, anchor == "LEFT" and "RIGHT" or "LEFT", anchor == "LEFT" and 6 or -6, 0)
		arrow:SetTexture("Interface\\Buttons\\Arrow-Up-Up")
		b.arrow = arrow
		b:SetScript("OnClick", function()
			if state.sort == key then state.desc = not state.desc else state.sort, state.desc = key, false end
			Buy:SyncHeads()
			Buy:ShowRows()
		end)
		return b
	end
	c.heads = {
		price = HeadButton(L["Price"], "price", 14, "LEFT", 90),
		name = HeadButton(L["Item"], "name", 200, "LEFT", 120),
		qty = HeadButton(L["Qty"], "qty", -104, "RIGHT", 60),
		lvl = HeadButton(L["Lvl"], "lvl", -186, "RIGHT", 50),
	}
	local dl = W:Text(head, 19, "header") dl:SetPoint("RIGHT", -24, 0) dl:SetText(L["Deal"])
	-- rows
	local RH = 48
	list = W:List(box, w - 8, (bottom - top) - 54 - 8, RH, function(r)
		r.price = W:Text(r, 20, "text") r.price:SetPoint("RIGHT", r, "LEFT", 142, 0)
		r.icon = W:Icon(r, 36) r.icon:SetPoint("LEFT", 156, 0)
		r.name = W:Text(r, 20, "text") r.name:SetPoint("LEFT", 200, 0) r.name:SetPoint("RIGHT", -236, 0) r.name:SetJustifyH("LEFT")
		r.lvl = W:Text(r, 19, "textDim") r.lvl:SetPoint("RIGHT", -186, 0)
		r.qty = W:Text(r, 20, "text") r.qty:SetPoint("RIGHT", -104, 0)
		r.badge = W:Badge(r, 76, 26) r.badge:SetPoint("RIGHT", -12, 0)
		r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		r:SetScript("OnClick", function(self, button) Buy:RowClick(self.data, button) end)
		r:SetScript("OnEnter", function(self)
			local d = self.data
			if not d or not _G.GameTooltip then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			local k = d.itemKey
			if GameTooltip.SetItemKey then pcall(GameTooltip.SetItemKey, GameTooltip, k.itemID, k.itemLevel or 0, k.itemSuffix or 0)
			elseif GameTooltip.SetItemByID then pcall(GameTooltip.SetItemByID, GameTooltip, k.itemID) end
			-- the game's group tooltip leaves the level requirement out: add it when the tooltip has none
			local need = RequiredLevel(k.itemID)
			if need and need > 1 then
				local shown = false
				for i = 2, GameTooltip:NumLines() do
					local fs = _G["GameTooltipTextLeft" .. i]
					local t = fs and fs.GetText and fs:GetText()
					if type(t) == "string" and not NG.IsSecret(t) and t:find(string.format(_G.ITEM_MIN_LEVEL or "Requires Level %d", need), 1, true) then shown = true break end
				end
				if not shown then GameTooltip:AddLine(string.format(_G.ITEM_MIN_LEVEL or "Requires Level %d", need), 1, 1, 1) end
			end
			GameTooltip:Show()
		end)
		r:SetScript("OnLeave", function() if _G.GameTooltip then GameTooltip:Hide() end end)
	end, function(r, d, sel)
		local info = KeyInfo(d.itemKey)
		r.price:SetText(NG.Money:Text(Num(d.minPrice)))
		local q = info and Num(info.quality)
		r.icon:SetItem(info and info.iconFileID or (_G.C_Item and C_Item.GetItemIconByID and Call(C_Item.GetItemIconByID, d.itemKey.itemID)), q)
		local name = info and info.itemName or L["Loading..."]
		-- the level it needs, and for gear its item level (several item levels of one item are separate rows)
		local need = RequiredLevel(d.itemKey.itemID)
		local lv = Num(d.itemKey.itemLevel)
		if lv and lv > 1 and NG.Prices:IsGear(d.itemKey.itemID) then name = name .. "  |cff9a8f7ai" .. lv .. "|r" end
		r.name:SetText(name)
		r.lvl:SetText(need and need > 1 and tostring(need) or "")
		local col = q and _G.ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
		if col then r.name:SetTextColor(col.r, col.g, col.b) else Skin:Paint(r.name, "text") end
		local n = Num(d.totalQuantity) or 0
		r.qty:SetText(_G.BreakUpLargeNumbers and BreakUpLargeNumbers(n) or tostring(n))
		local label, role, mark = DealOf(d)
		r.badge:Set(label, role, mark)
	end)
	list:SetPoint("TOPLEFT", 8, -54)
	list.onScroll = function(offset, maxOffset)
		if offset >= maxOffset - 2 and not NG.Search:IsFull() then NG.Search:More() end
	end
	c.resultNote = W:Text(box, 18, "textDim")
	c.resultNote:SetPoint("CENTER", 0, 0)
	c.resultNote:SetWordWrap(true) c.resultNote:SetWidth(w - 60)
	c.results = box
end

function Buy:SyncHeads()
	for key, b in pairs(c.heads) do
		b.arrow:SetShown(state.sort == key)
		b.arrow:SetTexture(state.desc and "Interface\\Buttons\\Arrow-Down-Up" or "Interface\\Buttons\\Arrow-Up-Up")
	end
end

function Buy:RowClick(d, button)
	if not d then return end
	if _G.IsModifiedClick and IsModifiedClick("CHATLINK") then
		local link = select(2, Call(_G.C_Item and C_Item.GetItemInfo or _G.GetItemInfo, d.itemKey.itemID))
		local detail = NG.Search:Detail(d.itemKey)
		if detail and detail.rows[1] and detail.rows[1].link then link = detail.rows[1].link end
		if link and _G.ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
		return
	end
	if _G.IsModifiedClick and IsModifiedClick("DRESSUP") then
		local link = select(2, Call(_G.C_Item and C_Item.GetItemInfo or _G.GetItemInfo, d.itemKey.itemID))
		if link and _G.DressUpItemLink then DressUpItemLink(link) end
		return
	end
	list:Select(d)
	NG.Inspector:SetItem(d)
end

-- the Filters pop-out: exact match, usable only, level range
function Buy:ToggleFilters(anchor)
	if c.filters then c.filters:SetShown(not c.filters:IsShown()) return end
	local f = W:Panel(c, "A")
	f:SetSize(320, 350)
	f:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
	f:SetFrameLevel(c:GetFrameLevel() + 60)
	f:EnableMouse(true)
	local t = W:Text(f, 18, "header") t:SetPoint("TOPLEFT", 14, -12) t:SetText(L["Filters"])
	local ex = W:Check(f, L["Exact name only"], function() return state.filters.exact end, function(v) state.filters.exact = v end)
	ex:SetPoint("TOPLEFT", 14, -44)
	local us = W:Check(f, L["Usable by me only"], function() return state.filters.usable end, function(v) state.filters.usable = v end)
	us:SetPoint("TOPLEFT", 14, -76)
	-- rarity, in the game's quality colours, two columns
	local rt = W:Text(f, 15, "text") rt:SetPoint("TOPLEFT", 14, -112) rt:SetText(L["Rarity (any of the ticked; none = all)"])
	local qchecks = {}
	for i, q in ipairs(Buy.QUALITIES) do
		local quality = q[1]
		local ch = W:Check(f, q[3], function() return state.filters.quality[quality] and true or false end,
			function(v) state.filters.quality[quality] = v or nil end)
		ch:SetPoint("TOPLEFT", 14 + ((i - 1) % 2) * 150, -(134 + math.floor((i - 1) / 2) * 28))
		ch:SetWidth(140)
		local col = _G.ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
		if col then Skin:Unpaint(ch.text) ch.text:SetTextColor(col.r, col.g, col.b) end
		qchecks[i] = ch
	end
	local lt = W:Text(f, 15, "text") lt:SetPoint("TOPLEFT", 14, -230) lt:SetText(L["Level range"])
	local lo = W:Edit(f, 70, 32, L["min"], { numeric = true, maxLetters = 3, onChange = function(v) state.filters.minLevel = tonumber(v) end })
	lo:SetPoint("TOPLEFT", 14, -254)
	local hi = W:Edit(f, 70, 32, L["max"], { numeric = true, maxLetters = 3, onChange = function(v) state.filters.maxLevel = tonumber(v) end })
	hi:SetPoint("LEFT", lo, "RIGHT", 10, 0)
	local go = W:Button(f, L["Search"], 120, 34, { size = 17, primary = true })
	go:SetPoint("BOTTOMRIGHT", -14, 14)
	go:SetScript("OnClick", function() f:Hide() Buy:Search() end)
	local clear = W:Button(f, L["Clear"], 100, 34, { size = 17 })
	clear:SetPoint("RIGHT", go, "LEFT", -8, 0)
	clear:SetScript("OnClick", function()
		state.filters = { exact = false, usable = false, quality = {} }
		lo:SetText("") hi:SetText("")
		ex:Sync() us:Sync()
		for _, ch in ipairs(qchecks) do ch:Sync() end
	end)
	f.qualityChecks, f.clearButton = qchecks, clear
	c.filters = f
	Buy.filtersFrame = f
end

function Buy:Build(container)
	c = container
	Header(c)
	Categories(c)
	Results(c)
	NG.Inspector:Build(c, NG.Window.W - NG.Window.P - 400, NG.Window.TOP, 400, NG.Window.BOTTOM - NG.Window.TOP)
	self:SyncCategories()
	self:SyncRecent()
	self:SyncHeads()
	c.resultNote:SetText(L["Search for something, pick a category, or run a Quick Scan."])
end

function Buy:OnShow()
	self:SyncRecent()
	if #NG.Search:Rows() > 0 then self:ShowRows() end
end

NG:Register("BROWSE_RESULTS", function(_, rows, full)
	if not list then return end
	Buy:ShowRows()
	if #rows == 0 and full then
		c.resultNote:SetText(L["Nothing listed matches that. Not even a little."])
		c.resultNote:Show()
	else
		c.resultNote:Hide()
	end
end)
NG:Register("BROWSE_FAILED", function() if c then c.resultNote:SetText(L["The auction house didn't answer. Try again in a moment."]) c.resultNote:Show() end end)
NG:Register("RECENT_CHANGED", function() if c then Buy:SyncRecent() end end)
NG:On("ITEM_KEY_ITEM_INFO_RECEIVED", function() if list and list:IsVisible() then NG:Debounce("buyrows", 0.1, function() list:Refresh() end) end end)
-- an item's description arrived (its level requirement among it): the rows and the level range follow
NG:On("GET_ITEM_INFO_RECEIVED", function() if list and list:IsVisible() then NG:Debounce("buyrows", 0.15, function() Buy:ShowRows() end) end end)
NG:On("ITEM_DATA_LOAD_RESULT", function() if list and list:IsVisible() then NG:Debounce("buyrows", 0.15, function() Buy:ShowRows() end) end end)
NG:Register("SCAN_DONE", function() if list and list:IsVisible() then list:Refresh() end end)

NG.Window:AddTab("buy", L["Buy"], Buy)
