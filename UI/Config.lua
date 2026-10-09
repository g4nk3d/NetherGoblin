--[[ NetherGoblin - UI/Config.lua
	The settings window (the gear on the auction house window, /goblin config, or the game's
	Options > AddOns > NetherGoblin). Pages on the left, the page's options on the right.
	Everything applies at once; nothing needs a reload.

	Slash commands: /goblin (or /ng): config | scan | blizzard | reset window | reset popups |
	diag | help ]]

local _, ns = ...
local NG = ns.NG
local Config = NG:Module("Config")
local W, Skin = NG.Widgets, NG.Skin
local L = ns.L
local S = function(k) return NG.Settings:Get(k) end
local Set = function(k, v) NG.Settings:Set(k, v) end
local floor = math.floor

local pages, order = {}, {}

local function Page(key, title, build) pages[key] = { title = title, build = build } order[#order + 1] = key end

local function Stack(parent)
	local y = 0
	return function(w, gap)
		w:SetPoint("TOPLEFT", 0, -y)
		y = y + (w:GetHeight() or 26) + (gap or 10)
		return w
	end
end

local function Check(add, p, key, label, tip) return add(W:Check(p, label, function() return S(key) end, function(v) Set(key, v) end, tip)) end

Page("general", L["Window & look"], function(p)
	local add = Stack(p)
	Check(add, p, "window.replaceBlizzard", L["Use NetherGoblin's auction window"], L["Off: the game's own auction window, with NetherGoblin's prices still in tooltips."])
	Check(add, p, "skin.followTheme", L["Follow NetherUI theme"], L["The theme's colours, panels and animations instead of the goblin brass. Works without NetherUI too (Nether colours)."])
	-- full or minimal: two boxes side by side under the switch, one ticked at a time
	local full = W:Check(p, L["Full theme"], function() return S("skin.themeStyle") ~= "minimal" end,
		function() Set("skin.themeStyle", "full") W:SyncAll() end,
		L["Nether's whole window, as NetherSuite and NetherUI's own windows wear it: ornate frame, title plate, Nether buttons, raised panels and wells."])
	local mini = W:Check(p, L["Minimal theme"], function() return S("skin.themeStyle") == "minimal" end,
		function() Set("skin.themeStyle", "minimal") W:SyncAll() end,
		L["Flat theme panels in the theme's colours: lighter, closer to the quest tracker's look."])
	add(full)
	local _, _, _, _, fy = full:GetPoint()
	full:ClearAllPoints()
	full:SetPoint("TOPLEFT", 28, fy or 0)
	mini:SetPoint("LEFT", full, "RIGHT", 24, 0)
	Config.styleChecks = { full = full, mini = mini }
	Check(add, p, "skin.portraitInTheme", L["Keep the goblin on the Scan Complete window in the theme look"])
	Check(add, p, "window.lock", L["Lock the window (no moving or resizing)"])
	Check(add, p, "window.perChar", L["This character keeps its own size and position"])
	add(W:Slider(p, L["Window size"], 50, 150, 5, function() return floor((NG.Settings:Get("window.scale") or 0.75) * 100 + 0.5) end,
		function(v) NG.Window:SetScale(v / 100) end, function(v) return v .. "%" end), 14)
	local b1 = W:Button(p, L["Reset window position"], 220, 34, { size = 15 })
	add(b1, 8)
	b1:SetScript("OnClick", function() NG.Window:ResetPosition() end)
	local b2 = W:Button(p, L["Reset popup positions"], 220, 34, { size = 15 })
	add(b2)
	b2:SetScript("OnClick", function() NG.Popups:ResetPositions() end)
end)

Page("scan", L["Scanning"], function(p)
	local add = Stack(p)
	Check(add, p, "scan.auto", L["Quick scan when the auction house opens"], L["Only when the last scan is older than the time below."])
	add(W:Slider(p, L["...if the last scan is older than"], 5, 240, 5, function() return S("scan.autoAge") end, function(v) Set("scan.autoAge", v) end, function(v) return v .. " " .. L["min"] end))
	add(W:Slider(p, L["Days of price history kept"], 7, 90, 1, function() return S("history.days") end, function(v) Set("history.days", v) end))
	add(W:Slider(p, L["Scan work per frame"], 1, 8, 1, function() return S("scan.budget") end, function(v) Set("scan.budget", v) end, function(v) return v .. " ms" end))
	local note = W:Text(p, 14, "textDim")
	note:SetWidth(460) note:SetWordWrap(true) note:SetJustifyH("LEFT")
	note:SetText(L["Lower = smoother frame rate, slower scan. It drops to 1 ms in combat and halves below 30 fps on its own."])
	note:SetHeight(40)
	add(note)
end)

Page("popup", L["Scan Complete window"], function(p)
	local add = Stack(p)
	Check(add, p, "popup.scan", L["Show the Scan Complete window"])
	Check(add, p, "popup.quips", L["Goblin jokes (off: just the facts)"])
	Check(add, p, "popup.sound", L["Ka-ching sound"])
	add(W:Slider(p, L["Fades after"], 3, 30, 1, function() return S("popup.seconds") end, function(v) Set("popup.seconds", v) end, function(v) return v .. " s" end))
	local note = W:Text(p, 14, "textDim")
	note:SetWidth(460) note:SetWordWrap(true) note:SetJustifyH("LEFT") note:SetHeight(60)
	note:SetText(L["Hovering keeps it open; a click closes it. Move it (and the Compatibility window) in the game's Edit Mode."])
	add(note)
	local test = W:Button(p, L["Show it now"], 180, 34, { size = 15 })
	add(test)
	test:SetScript("OnClick", function()
		local last = NG.Scan:Last()
		NG.Popups:ShowScan({ items = last.items or 0, seconds = last.seconds or 0, newLows = 0, deals = 0, undercut = 0, changed = 1 })
	end)
end)

Page("trade", L["Buying & selling"], function(p)
	local add = Stack(p)
	Check(add, p, "search.shiftClick", L["Shift+click an item to put its name in the search"], L["Bags, chat links, the character sheet: with the auction window open and no chat box open."])
	Check(add, p, "search.shiftClickGo", L["...and search for it at once"], L["Off: the name waits in the search box for you to press Enter."])
	add(W:Choice(p, L["Undercut by"], { { "copper", L["Copper"] }, { "percent", L["Percent"] } }, function() return S("sell.undercutMode") end, function(v) Set("sell.undercutMode", v) end))
	add(W:Slider(p, L["Copper"], 0, 100, 1, function() return S("sell.undercutCopper") end, function(v) Set("sell.undercutCopper", v) end, function(v) return v .. "c" end))
	add(W:Slider(p, L["Percent"], 0, 20, 1, function() return S("sell.undercutPercent") end, function(v) Set("sell.undercutPercent", v) end, function(v) return v .. "%" end))
	Check(add, p, "sell.confirmVendor", L["Ask before posting for less than a vendor pays"])
	Check(add, p, "sell.confirmLow", L["Ask before posting far under the usual price"])
	add(W:Slider(p, L["...more than this far under"], 10, 80, 5, function() return S("sell.lowPercent") end, function(v) Set("sell.lowPercent", v) end, function(v) return v .. "%" end))
	Check(add, p, "sell.chatLog", L["A chat line for each auction posted"])
	add(W:Slider(p, L["Warn when a price rose since the list by more than"], 0, 100, 5, function() return S("buy.confirmJump") end, function(v) Set("buy.confirmJump", v) end, function(v) return v .. "%" end))
end)

Page("tooltips", L["Tooltips"], function(p)
	local add = Stack(p)
	Check(add, p, "tooltip.enabled", L["Auction prices on item tooltips"])
	Check(add, p, "tooltip.market", L["Market value (the usual price)"])
	Check(add, p, "tooltip.lowest", L["Lowest price at the last scan"])
	Check(add, p, "tooltip.age", L["How old the price is"])
	Check(add, p, "tooltip.stack", L["The whole stack's value"])
end)

Page("guild", L["Price check"], function(p)
	local add = Stack(p)
	local note = W:Text(p, 14, "textDim")
	note:SetWidth(460) note:SetWordWrap(true) note:SetJustifyH("LEFT") note:SetHeight(76)
	note:SetText(L["Guild or party members type @ or $ and an item (a link or its exact name, optionally x20 for a stack). One NetherGoblin user answers by whisper, the one with the freshest price; prices older than 3 days are never used. Quiet in instances."])
	add(note)
	Check(add, p, "guild.enabled", L["Answer price checks"])
	Check(add, p, "guild.guild", L["In guild chat"])
	Check(add, p, "guild.party", L["In party chat"])
	Check(add, p, "guild.hideSent", L["Hide my answer whispers from my own chat"])
end)

Page("other", L["Other"], function(p)
	local add = Stack(p)
	Check(add, p, "compat.ask", L["Ask about other auction addons that change the same window"])
	Check(add, p, "minimap.button", L["Minimap button (the goblin's face)"], L["Left-click: settings. Right-click: Quick Scan at the auction house. Shift + drag moves it."])
	Check(add, p, "minimap.compartment", L["Entry in the minimap's addon menu"])
	local diag = W:Button(p, L["Diagnostics (chat)"], 220, 34, { size = 15 })
	add(diag)
	diag:SetScript("OnClick", function() Config:Diag() end)
	local reset = W:Button(p, L["Reset all settings"], 220, 34, { size = 15 })
	add(reset)
	reset:SetScript("OnClick", function()
		NG.Popups:Ask({ title = L["Reset all settings?"], text = L["Every NetherGoblin option goes back to its default. Prices, lists and history stay."],
			buttons = { { L["Reset"], function() NG.Settings:ResetAll() W:SyncAll() end, true }, { L["Cancel"] } } })
	end)
end)

function Config:Build()
	if self.frame then return self.frame end
	local f = W:Panel(UIParent, "A")
	f:SetSize(760, 600)
	f:SetPoint("CENTER", 0, 30)
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:Hide()
	local title = W:Text(f, 24, "header", "title")
	title:SetPoint("TOPLEFT", 20, -16)
	title:SetText(L["NetherGoblin settings"])
	local close = W:Button(f, "X", 34, 34, { size = 18 })
	close:SetPoint("TOPRIGHT", -12, -12)
	close:SetScript("OnClick", function() f:Hide() end)
	local nav = {}
	for i, key in ipairs(order) do
		local b = W:Button(f, pages[key].title, 210, 40, { size = 16 })
		b:SetPoint("TOPLEFT", 16, -64 - (i - 1) * 46)
		b:SetScript("OnClick", function() Config:Open(key) end)
		nav[key] = b
		local page = CreateFrame("Frame", nil, f)
		page:SetPoint("TOPLEFT", 252, -66)
		page:SetPoint("BOTTOMRIGHT", -20, 20)
		page:Hide()
		pages[key].frame = page
	end
	local ver = W:Text(f, 13, "textDim")
	ver:SetPoint("BOTTOMLEFT", 20, 16)
	ver:SetText("v" .. NG.VERSION)
	f.nav = nav
	if _G.UISpecialFrames then table.insert(UISpecialFrames, "NetherGoblinConfig") end
	_G.NetherGoblinConfig = f
	self.frame = f
	return f
end

function Config:Open(key)
	local f = self:Build()
	key = key or self.page or order[1]
	for k, pg in pairs(pages) do
		pg.frame:SetShown(k == key)
		f.nav[k]:SetActive(k == key)
		if k == key and not pg.built then pg.built = true NG:Safe("settings page " .. k, pg.build, pg.frame) end
	end
	self.page = key
	W:SyncAll()
	f:Show()
end

function Config:Toggle()
	if self.frame and self.frame:IsShown() then self.frame:Hide() else self:Open() end
end

function Config:Diag()
	local E = NG.errors
	NG:Print("v%s  ·  Forever %s  ·  modern auction house %s  ·  prices for %s: %d items", NG.VERSION, tostring(NG:IsForever()), tostring(NG:HasModernAH()),
		tostring(NG.Prices:RealmKey()), NG.Prices:Count())
	local last = NG.Scan:Last()
	NG:Print("last scan: %s  ·  %s items  ·  %s s", last.at and NG.Window.Ago(NG:Now() - last.at) or "never", tostring(last.items or 0), tostring(last.seconds or 0))
	NG:Print("errors caught: %d%s", E.count, E.latest and ("  ·  latest: " .. E.latest.context .. ": " .. E.latest.err) or "")
	if NG.PriceCheck then local st = NG.PriceCheck:Stats() NG:Print("price checks: answered %d, left to others %d, dropped %d", st.answered, st.yielded, st.dropped) end
end

-- /goblin fields: what the game hands back for the first listing of the item in the panel
-- (field names, types and values), for checking a client whose auction data differs
function Config:Fields()
	local cur = NG.Inspector and NG.Inspector:Current()
	local AH = _G.C_AuctionHouse
	if not (cur and cur.itemKey and AH) then NG:Print(L["Pick an item in the auction house first."]) return end
	local function describe(v)
		if NG.IsSecret(v) then return "secret" end
		if type(v) == "table" then
			local parts = {}
			for k, x in pairs(v) do parts[#parts + 1] = tostring(k) .. "=" .. (NG.IsSecret(x) and "secret" or tostring(x)) end
			table.sort(parts)
			return "{" .. table.concat(parts, " ") .. "}"
		end
		return tostring(v)
	end
	local function dump(label, t)
		if type(t) ~= "table" then NG:Print("%s: %s", label, tostring(t)) return end
		local keys = {}
		for k in pairs(t) do keys[#keys + 1] = tostring(k) end
		table.sort(keys)
		NG:Print("%s:", label)
		for _, k in ipairs(keys) do NG:Print("  %s = %s (%s)", k, describe(t[k]), type(t[k])) end
	end
	if cur.commodity then
		local n = NG.Num(NG.Call(AH.GetNumCommoditySearchResults, cur.itemKey.itemID)) or 0
		NG:Print("commodity %d: %d results", cur.itemKey.itemID, n)
		if n > 0 then dump("result 1", NG.Call(AH.GetCommoditySearchResultInfo, cur.itemKey.itemID, 1)) end
	else
		local n = NG.Num(NG.Call(AH.GetNumItemSearchResults, cur.itemKey)) or 0
		NG:Print("item %d: %d results", cur.itemKey.itemID, n)
		if n > 0 then dump("result 1", NG.Call(AH.GetItemSearchResultInfo, cur.itemKey, 1)) end
	end
	dump("item key info", NG.Call(AH.GetItemKeyInfo, cur.itemKey))
end

-- /goblin trace: print every post the auction house is asked for (ours or the game's own
-- window's) with its arguments and return, and every answer that follows, with timings.
-- Toggles. For finding out what a client wants in a post.
local traceEvents = { "UI_ERROR_MESSAGE", "AUCTION_HOUSE_SHOW_ERROR", "AUCTION_HOUSE_SHOW_NOTIFICATION", "AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION",
	"AUCTION_HOUSE_POST_ERROR", "AUCTION_HOUSE_POST_WARNING",
	"AUCTION_HOUSE_AUCTION_CREATED", "AUCTION_MULTISELL_START", "AUCTION_MULTISELL_FAILURE", "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" }
function Config:Trace()
	local AH = _G.C_AuctionHouse
	if not AH then return end
	if self.trace then
		AH.PostItem, AH.PostCommodity = self.trace.PostItem, self.trace.PostCommodity
		for _, ev in ipairs(traceEvents) do NG:Off(ev, self.trace.handler) end
		self.trace = nil
		NG:Print("trace off")
		return
	end
	local T = { PostItem = AH.PostItem, PostCommodity = AH.PostCommodity, t0 = 0 }
	self.trace = T
	local function V(v) if NG.IsSecret(v) then return "secret" end return tostring(v) end
	local function Loc(loc)
		if type(loc) ~= "table" then return V(loc) end
		local exists = _G.C_Item and C_Item.DoesItemExist and V(NG.Call(C_Item.DoesItemExist, loc))
		local valid = AH.IsSellItemValid and V(NG.Call(AH.IsSellItemValid, loc, false))
		local status = AH.GetItemCommodityStatus and V(NG.Call(AH.GetItemCommodityStatus, loc))
		local key = AH.GetItemKeyFromItem and NG.Open(NG.Call(AH.GetItemKeyFromItem, loc))
		return string.format("bag %s slot %s (exists %s, sellable %s, commodity status %s, itemID %s)",
			V(loc.bagID), V(loc.slotIndex), tostring(exists), tostring(valid), tostring(status), key and V(key.itemID) or "?")
	end
	local function Wrap(name, orig)
		return function(...)
			local n = select("#", ...)
			local a = { ... }
			local parts = {}
			for i = 2, n do parts[#parts + 1] = V(a[i]) end
			T.t0 = NG:Clock()
			NG:Print("%s(%s | %s) [%d args]", name, Loc(a[1]), table.concat(parts, ", "), n)
			local r = { orig(...) }
			NG:Print("  -> returned %s", #r > 0 and V(r[1]) or "nothing")
			return unpack(r)
		end
	end
	AH.PostItem = Wrap("PostItem", T.PostItem)
	AH.PostCommodity = Wrap("PostCommodity", T.PostCommodity)
	T.handler = function(event, ...)
		local parts = {}
		for i = 1, select("#", ...) do parts[#parts + 1] = V((select(i, ...))) end
		NG:Print("  %s (%s) %.2fs after the post", event, table.concat(parts, ", "), NG:Clock() - T.t0)
	end
	for _, ev in ipairs(traceEvents) do NG:On(ev, T.handler) end
	NG:Print("trace on: post something (here or in the game's window: /goblin blizzard), then /goblin trace to stop")
end

-- the game's Options > AddOns page: a button that opens this window
NG:Register("LOGIN", function()
	local SS = _G.Settings
	if not (SS and SS.RegisterCanvasLayoutCategory and SS.RegisterAddOnCategory) then return end
	local canvas = CreateFrame("Frame")
	local t = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	t:SetPoint("TOPLEFT", 16, -16) t:SetText("NetherGoblin")
	local b = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
	b:SetSize(260, 28) b:SetPoint("TOPLEFT", 16, -52)
	b:SetText(L["Open NetherGoblin settings"])
	b:SetScript("OnClick", function()
		if _G.SettingsPanel and SettingsPanel:IsShown() and _G.HideUIPanel then HideUIPanel(SettingsPanel) end
		Config:Open()
	end)
	local ok, cat = pcall(SS.RegisterCanvasLayoutCategory, canvas, "NetherGoblin")
	if ok and cat then pcall(SS.RegisterAddOnCategory, cat) end
end)

---------------------------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------------------------
_G.SLASH_NETHERGOBLIN1 = "/goblin"
_G.SLASH_NETHERGOBLIN2 = "/ng"
-- (never assign SlashCmdList itself: writing that global taints every slash command, /pvp included)
SlashCmdList.NETHERGOBLIN = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if msg == "" or msg == "config" or msg == "settings" then Config:Toggle()
	elseif msg == "scan" then
		if not NG.House:IsOpen() then NG:Print(L["Open the auction house first."]) else NG.Scan:Start("user") end
	elseif msg == "blizzard" then
		if NG.House:IsOpen() then NG.House:SetBlizzardShown(not NG.House.blizzardThisSession) else NG:Print(L["Open the auction house first."]) end
	elseif msg == "reset window" then NG.Window:ResetPosition() NG.Window:SetScale(NG.Window.DEFAULT_SCALE) NG:Print(L["Window size and position reset."])
	elseif msg == "reset popups" then NG.Popups:ResetPositions() NG:Print(L["Popup positions reset."])
	elseif msg == "diag" then Config:Diag()
	elseif msg == "fields" then Config:Fields()
	elseif msg == "trace" then Config:Trace()
	else
		NG:Print(L["/goblin: settings  ·  /goblin scan  ·  /goblin blizzard (the game's window this visit)  ·  /goblin reset window  ·  /goblin reset popups  ·  /goblin diag  ·  /goblin fields (raw listing data for the item in the panel)  ·  /goblin trace (print every post and the game's answers)"])
	end
end

-- the minimap's addon menu (AddonCompartmentFunc in the .toc)
_G.NetherGoblin_OnAddonCompartmentClick = function() Config:Toggle() end
