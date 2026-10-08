--[[ NetherGoblin - API/Plugin.lua
	The public face: the one global, NetherGoblin. Other Nether addons (and anyone's plugin)
	read prices and follow scans through it; Docs/API.md has examples.

	  NetherGoblin.API_VERSION, NetherGoblin.VERSION
	  NetherGoblin:GetPrice(item)       -> { market, lowest, listed, age } or nil
	                                       item: a link, "item:123", or an item ID
	  NetherGoblin:GetMarketValue(item) -> copper or nil
	  NetherGoblin:GetLowest(item)      -> copper or nil (the last scan's lowest)
	  NetherGoblin:History(item)        -> { { day, low, qty }, ... }
	  NetherGoblin:LastScan()           -> { at, items, seconds }
	  NetherGoblin:IsAuctionHouseOpen()
	  NetherGoblin:FormatMoney(copper)
	  NetherGoblin:RegisterPlugin(name [, version]) -> plugin
	      plugin:On(message, fn)        "SCAN_DONE"(summary), "AH_OPEN", "AH_CLOSED", "POSTED"(info),
	                                    "BUY_DONE"(info), "CANCELLED"(auctionID), "SKIN_CHANGED"(mode)
	      A plugin's listener that fails 5 times is switched off (and said so once, in chat);
	      the core never stops because of a plugin. ]]

local _, ns = ...
local NG = ns.NG
local Plugin = NG:Module("Plugin")
local Num = NG.Num

local API = { API_VERSION = NG.API_VERSION, VERSION = NG.VERSION }
local plugins = {}

local function Link(item)
	if type(item) == "number" then return "item:" .. item end
	if type(item) == "string" and not NG.IsSecret(item) then return item end
	return nil
end

function API:GetPrice(item)
	local link = Link(item)
	if not link then return nil end
	local e, key = NG.Prices:ForLink(link)
	if not e then return nil end
	return { market = NG.Prices:Market(key), lowest = e.m, listed = e.q or 0, age = e.t and (NG:Now() - e.t) or nil }
end
function API:GetMarketValue(item) local p = self:GetPrice(item) return p and p.market end
function API:GetLowest(item) local p = self:GetPrice(item) return p and p.lowest end
function API:History(item)
	local link = Link(item)
	local _, key = link and NG.Prices:ForLink(link)
	return key and NG.Prices:History(key) or {}
end
function API:LastScan() local s = NG.Scan:Last() return { at = s.at, items = s.items, seconds = s.seconds } end
function API:IsAuctionHouseOpen() return NG.House:IsOpen() end
function API:FormatMoney(c) return NG.Money:Text(Num(c) or 0) end

function API:RegisterPlugin(name, version)
	if type(name) ~= "string" or name == "" then return nil end
	local p = plugins[name] or { name = name, version = version, failures = 0, disabled = false }
	plugins[name] = p
	function p:On(msg, fn) return NG:Register(msg, function(_, ...) fn(...) end, p) end
	return p
end

function Plugin:Failed(p, msg, err)
	p.failures = p.failures + 1
	NG:Log("warn", "plugin %s failed on %s: %s", p.name, tostring(msg), tostring(err))
	if p.failures >= 5 and not p.disabled then
		p.disabled = true
		NG:Print(ns.L["The plugin %s kept failing and was switched off for this session."], p.name)
	end
end
function Plugin:List() return plugins end

_G.NetherGoblin = API
