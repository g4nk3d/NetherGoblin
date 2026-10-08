--[[ NetherGoblin - Features/Compat.lua
	Other auction addons that change the same auction house window. Once per addon (and only
	while "compat.ask" is on) the Compatibility window asks what to do:

	  Disable <addon> and reload   that addon is switched off for this character set (the game's
	                               AddOns list), then the interface reloads
	  Keep both                    nothing changes; NetherGoblin's window opens, the other
	                               addon's extras stay in the game's window ("/goblin blizzard"
	                               shows that window for one visit). Not asked again.
	  Ask me later                 asked again next login

	And once only, the first time NetherGoblin runs with NetherUI installed: which look?
	NetherUI's theme (the one chosen in NetherUI, named in the question) or the goblin's own.
	Either answer is kept in Settings > Window & look > "Follow NetherUI theme". ]]

local _, ns = ...
local NG = ns.NG
local Compat = NG:Module("Compat")
local L = ns.L
local Call = NG.Call

Compat.KNOWN = {
	{ "Auctionator", "Auctionator" },
	{ "TradeSkillMaster", "TradeSkillMaster" },
	{ "Auc-Advanced", "Auctioneer" },
	{ "aux-addon", "aux" },
	{ "AuctionFaster", "AuctionFaster" },
}

local function Loaded(name)
	local C = _G.C_AddOns
	if C and C.IsAddOnLoaded then return Call(C.IsAddOnLoaded, name) and true or false end
	return _G.IsAddOnLoaded and Call(IsAddOnLoaded, name) and true or false
end

local function Disable(name)
	local C = _G.C_AddOns
	if C and C.DisableAddOn then pcall(C.DisableAddOn, name) elseif _G.DisableAddOn then pcall(DisableAddOn, name) end
end

function Compat:Check()
	if not NG.Settings:Get("compat.ask") then return end
	NG.db.compat = NG.db.compat or {}
	for _, a in ipairs(self.KNOWN) do
		local folder, title = a[1], a[2]
		if Loaded(folder) and NG.db.compat[folder] ~= "keep" then
			NG.Popups:Ask({
				title = L["Another auction addon"],
				text = string.format(L["%s also changes the auction house window. Both can run: NetherGoblin's window opens, and %s's extras stay in the game's own window (/goblin blizzard shows it for a visit)."], title, title),
				buttons = {
					{ string.format(L["Disable %s + reload"], title), function() Disable(folder) if _G.ReloadUI then ReloadUI() end end, true },
					{ L["Keep both"], function() NG.db.compat[folder] = "keep" end },
					{ L["Ask me later"] },
				},
			})
		end
	end
end

-- the name of NetherUI's current theme, for the question
local function ThemeName()
	local A = rawget(_G, "NetherUI")
	local key = type(A) == "table" and type(A.db) == "table" and A.db.theme
	local M = rawget(_G, "NetherMedia")
	local t = key and type(M) == "table" and type(M.themes) == "table" and M.themes[key]
	local name = type(t) == "table" and NG.Str(t.name) or NG.Str(key)
	return name
end

-- Once, the first time NetherGoblin runs beside NetherUI: its theme, or the goblin look?
function Compat:AskTheme()
	if NG.db.themeAsked then return end
	if not (Loaded("NetherUI") and NG.Skin.NetherUI()) then return end
	local name = ThemeName()
	NG.db.themeAsked = true
	NG.Popups:Ask({
		title = L["Which look?"],
		text = name and string.format(L["NetherUI is here with its %s theme. NetherGoblin can wear that theme (its panels, colours and animations) or keep its own goblin brass and leather. Change it any time in Settings > Window & look."], name)
			or L["NetherUI is here. NetherGoblin can wear its theme (panels, colours and animations) or keep its own goblin brass and leather. Change it any time in Settings > Window & look."],
		buttons = {
			{ name and string.format(L["Use %s"], name) or L["Use the NetherUI theme"], function() NG.Settings:Set("skin.followTheme", true) end, true },
			{ L["Keep the goblin look"], function() NG.Settings:Set("skin.followTheme", false) end },
		},
	})
end

NG:Register("LOGIN", function()
	NG:After(2, function() Compat:AskTheme() end)
	NG:After(4, function() Compat:Check() end)
end)
