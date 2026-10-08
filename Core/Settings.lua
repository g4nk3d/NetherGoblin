--[[ NetherGoblin - Core/Settings.lua
	Every option, its default, and where it is kept. QoL features default to on.

	  Settings:Get(key)            the value (default when never set)
	  Settings:Set(key, value)     store it; fires SETTING_CHANGED(key, value)
	  Settings:Reset(key)          back to the default
	  Settings.DEFAULTS            key -> default

	The window's size and position are account-wide unless "window.perChar" is on, in which
	case this character keeps its own (NetherGoblinCharDB.window). ]]

local _, ns = ...
local NG = ns.NG
local Settings = NG:Module("Settings")

Settings.DEFAULTS = {
	-- window
	["window.replaceBlizzard"] = true,   -- NetherGoblin's window instead of the game's
	["window.scale"] = 0.75,             -- 75% of the art's full size
	["window.perChar"] = false,
	["window.lock"] = false,
	-- look
	["skin.followTheme"] = false,        -- goblin skin by default
	["skin.themeStyle"] = "full",        -- the theme look: "full" Nether window or "minimal"
	["skin.portraitInTheme"] = true,     -- the Scan Complete window's goblin in the theme look (the window itself has none)
	-- scanning
	["scan.auto"] = true,                -- quick scan when the auction house opens
	["scan.autoAge"] = 30,               -- ...if the last one is older than this (minutes)
	["scan.budget"] = 4,                 -- ms per frame the scan may use (lower in combat)
	["history.days"] = 30,               -- days of price history kept per item
	-- scan complete window
	["popup.scan"] = true,
	["popup.seconds"] = 8,
	["popup.sound"] = true,
	["popup.quips"] = true,
	-- buying
	["buy.confirmJump"] = 10,            -- warn when the price rose more than this % since the list
	-- selling
	["sell.undercutMode"] = "copper",    -- "copper" | "percent"
	["sell.undercutCopper"] = 1,
	["sell.undercutPercent"] = 1,
	["sell.duration"] = 3,               -- 1 / 2 / 3 = short / medium / long
	["sell.confirmLow"] = true,          -- ask before posting far under the market value
	["sell.lowPercent"] = 30,
	["sell.confirmVendor"] = true,       -- ask before posting for less than a vendor pays
	["sell.chatLog"] = false,            -- a chat line for each auction posted
	-- tooltips
	["tooltip.enabled"] = true,
	["tooltip.market"] = true,
	["tooltip.lowest"] = true,
	["tooltip.age"] = true,
	["tooltip.stack"] = true,            -- the stack's total when it holds more than one
	-- guild / party price check
	["guild.enabled"] = true,
	["guild.guild"] = true,
	["guild.party"] = true,
	["guild.hideSent"] = true,           -- the answer whisper is not echoed in your own chat
	-- other
	["compat.ask"] = true,
	["minimap.compartment"] = true,
	["minimap.button"] = true,          -- the goblin's face on the minimap
}

local GLOBAL_ONLY = { ["window.perChar"] = true }
local WINDOW_KEYS = { ["window.scale"] = true }

function Settings:Init(db, char)
	self.db, self.char = db, char
	db.settings = db.settings or {}
	char.window = char.window or {}
end

local function Store(self, key)
	if WINDOW_KEYS[key] and self.db.settings["window.perChar"] then return self.char.window end
	return self.db.settings
end

function Settings:Get(key)
	if not self.db then return self.DEFAULTS[key] end
	local v = Store(self, key)[key]
	if v == nil then v = self.DEFAULTS[key] end
	return v
end

function Settings:Set(key, value)
	if not self.db then return end
	if value == self.DEFAULTS[key] and not GLOBAL_ONLY[key] then value = nil end
	Store(self, key)[key] = value
	NG:Fire("SETTING_CHANGED", key, self:Get(key))
end

function Settings:Reset(key) self:Set(key, self.DEFAULTS[key]) end

function Settings:ResetAll()
	if not self.db then return end
	NG.wipe(self.db.settings)
	NG.wipe(self.char.window)
	NG:Fire("SETTING_CHANGED", "*")
end

-- where the window keeps its position (account or this character)
function Settings:WindowStore()
	if not self.db then return {} end
	if self:Get("window.perChar") then return self.char.window end
	self.db.window = self.db.window or {}
	return self.db.window
end
