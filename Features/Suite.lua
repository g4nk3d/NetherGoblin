--[[ NetherGoblin - Features/Suite.lua
	NetherGoblin on NetherSuite's shelf, when the hub is installed: a tile with the family
	banner on the home page, its own page in the hub (nether://nethergoblin), status lines,
	diagnostics, and every setting in the hub's search (a result opens the right page of the
	settings window). The hub only reads values; every change is still made here.

	Nothing in this file runs without NetherSuite: the descriptor is handed over at login
	when the hub's API is there, or left in NetherSuite_Queue for it to collect. ]]

local _, ns = ...
local NG = ns.NG
local Suite = NG:Module("Suite")
local L = ns.L

local type, pairs, ipairs, pcall, concat = type, pairs, ipairs, pcall, table.concat

-- the settings window's pages, in its order
local PAGES = {
	{ id = "general", label = L["Window & look"] },
	{ id = "scan", label = L["Scanning"] },
	{ id = "popup", label = L["Scan Complete window"] },
	{ id = "trade", label = L["Buying & selling"] },
	{ id = "tooltips", label = L["Tooltips"] },
	{ id = "guild", label = L["Price check"] },
	{ id = "other", label = L["Other"] },
}

-- every control of UI/Config.lua, as the hub's records: { key, kind, label, page, extras }
local function T(key, label, page, extra) local r = { id = key, kind = "toggle", label = label, page = page } for k, v in pairs(extra or {}) do r[k] = v end return r end
local function Sl(key, label, page, min, max, step, fmt, extra) local r = { id = key, kind = "slider", label = label, page = page, min = min, max = max, step = step, fmt = fmt } for k, v in pairs(extra or {}) do r[k] = v end return r end

local function Records()
	local out = {
		T("window.replaceBlizzard", L["Use NetherGoblin's auction window"], "general", { tip = L["Off: the game's own auction window, with NetherGoblin's prices still in tooltips."], keywords = { "blizzard", "default" } }),
		T("skin.followTheme", L["Follow NetherUI theme"], "general", { keywords = { "skin", "look", "colours" } }),
		{ id = "skin.themeStyle", kind = "choice", label = L["Theme style"], page = "general", keywords = { "full", "minimal", "netherui" },
			values = { { value = "full", label = L["Full theme"] }, { value = "minimal", label = L["Minimal theme"] } } },
		T("skin.portraitInTheme", L["Keep the goblin on the Scan Complete window in the theme look"], "general"),
		T("window.lock", L["Lock the window (no moving or resizing)"], "general"),
		T("window.perChar", L["This character keeps its own size and position"], "general"),
		Sl("window.scale", L["Window size"], "general", 50, 150, 5, "%d%%", { keywords = { "scale", "resize" } }),
		{ id = "window.reset", kind = "button", label = L["Reset window position"], page = "general" },
		{ id = "popup.reset", kind = "button", label = L["Reset popup positions"], page = "general" },
		T("scan.auto", L["Quick scan when the auction house opens"], "scan", { keywords = { "automatic" } }),
		Sl("scan.autoAge", L["...if the last scan is older than"], "scan", 5, 240, 5, "%d min"),
		Sl("history.days", L["Days of price history kept"], "scan", 7, 90, 1, "%d", { keywords = { "trend", "database" } }),
		Sl("scan.budget", L["Scan work per frame"], "scan", 1, 8, 1, "%d ms", { keywords = { "fps", "stutter", "performance" } }),
		T("popup.scan", L["Show the Scan Complete window"], "popup"),
		T("popup.quips", L["Goblin jokes (off: just the facts)"], "popup", { keywords = { "humour", "snark" } }),
		T("popup.sound", L["Ka-ching sound"], "popup", { keywords = { "sound" } }),
		Sl("popup.seconds", L["Fades after"], "popup", 3, 30, 1, "%d s"),
		{ id = "sell.undercutMode", kind = "choice", label = L["Undercut by"], page = "trade", values = { { value = "copper", label = L["Copper"] }, { value = "percent", label = L["Percent"] } } },
		Sl("sell.undercutCopper", L["Copper"], "trade", 0, 100, 1, "%dc", { keywords = { "undercut" } }),
		Sl("sell.undercutPercent", L["Percent"], "trade", 0, 20, 1, "%d%%", { keywords = { "undercut" } }),
		T("sell.confirmVendor", L["Ask before posting for less than a vendor pays"], "trade"),
		T("sell.confirmLow", L["Ask before posting far under the usual price"], "trade"),
		Sl("sell.lowPercent", L["...more than this far under"], "trade", 10, 80, 5, "%d%%"),
		T("sell.chatLog", L["A chat line for each auction posted"], "trade"),
		Sl("buy.confirmJump", L["Warn when a price rose since the list by more than"], "trade", 0, 100, 5, "%d%%"),
		T("tooltip.enabled", L["Auction prices on item tooltips"], "tooltips"),
		T("tooltip.market", L["Market value (the usual price)"], "tooltips"),
		T("tooltip.lowest", L["Lowest price at the last scan"], "tooltips"),
		T("tooltip.age", L["How old the price is"], "tooltips"),
		T("tooltip.stack", L["The whole stack's value"], "tooltips"),
		T("guild.enabled", L["Answer price checks"], "guild", { keywords = { "chat", "whisper" } }),
		T("guild.guild", L["In guild chat"], "guild"),
		T("guild.party", L["In party chat"], "guild"),
		T("guild.hideSent", L["Hide my answer whispers from my own chat"], "guild"),
		T("compat.ask", L["Ask about other auction addons that change the same window"], "other", { keywords = { "auctionator", "auctioneer" } }),
		T("minimap.button", L["Minimap button (the goblin's face)"], "other"),
		T("minimap.compartment", L["Entry in the minimap's addon menu"], "other"),
	}
	for _, r in ipairs(out) do
		r.path = { r.id }   -- the setting's key, as one path element
		r.section = nil
	end
	return out
end

local function Descriptor()
	return {
		id = "nethergoblin", name = "NetherGoblin", version = NG.VERSION, apiVersion = 1, addon = "NetherGoblin",
		icon = NG.MEDIA .. "Logo", banner = NG.MEDIA .. "Banner",
		description = L["An auction house goblin: fast scans, prices on every tooltip, 14-day trends, undercut alerts, shopping lists and guild price checks."],
		category = "Economy", slash = { "/goblin", "/ng" },
		optional = { "NetherUI" },
		pages = PAGES,
		open = function(page) NG.Config:Open(page) return true end,
		status = function()
			local last = NG.Scan:Last()
			local owned = NG.Owned and NG.Owned:List() or {}
			return {
				{ L["Prices for"], tostring(NG.Prices:RealmKey()) },
				{ L["Items priced"], tostring(NG.Prices:Count()) },
				{ L["Last scan"], last.at and NG.Window.Ago(NG:Now() - last.at) or L["never"] },
				{ L["Your auctions"], tostring(#owned) },
			}
		end,
		diagnostics = function()
			local E = NG.errors
			return { errors = E.count, latest = E.latest and (E.latest.context .. ": " .. E.latest.err) or nil,
				report = ("NetherGoblin v%s, Forever %s, modern auction house %s, %d items priced"):format(NG.VERSION, tostring(NG:IsForever()), tostring(NG:HasModernAH()), NG.Prices:Count()) }
		end,
		settings = Records,
		value = function(path)
			local key = type(path) == "table" and concat(path, ".") or tostring(path)
			local v = NG.Settings:Get(key)
			if key == "window.scale" and type(v) == "number" then return math.floor(v * 100 + 0.5) end
			return v
		end,
		focus = function(id, page)
			NG.Config:Open(page)
			return true
		end,
	}
end

function Suite:Join()
	if self.joined then return end
	local S = rawget(_G, "NetherSuite")
	if type(S) == "table" and type(S.RegisterAddon) == "function" then
		self.joined = pcall(S.RegisterAddon, S, Descriptor())
	elseif _G.C_AddOns and C_AddOns.DoesAddOnExist and C_AddOns.DoesAddOnExist("NetherSuite") then
		-- the hub loads later (load on demand, or after us): it collects the queue at login
		_G.NetherSuite_Queue = _G.NetherSuite_Queue or {}
		table.insert(_G.NetherSuite_Queue, Descriptor())
		self.joined = true
	end
end

NG:Register("LOGIN", function() Suite:Join() end)
-- the hub loaded after login (enabled later, or load on demand)
NG:On("ADDON_LOADED", function(_, name) if name == "NetherSuite" then NG:After(0, function() Suite:Join() end) end end)
