--[[ NetherGoblin - Core/Lifecycle.lua
	Start-up and shut-down, in order:

	  ADDON_LOADED (ours)   saved tables read and migrated; settings, prices, ledger, lists
	                        ready; fires "DB_READY"
	  PLAYER_LOGIN          fires "LOGIN" (UI pieces that need the game world: tooltips,
	                        chat, compatibility check, integrations)
	  PLAYER_LOGOUT         prices packed to one string; fires "LOGOUT"

	Saved tables: NetherGoblinDB (account: settings, prices, item names, shopping lists, recent
	searches, window) and NetherGoblinCharDB (this character: ledger, own window when chosen). ]]

local ADDON, ns = ...
local NG = ns.NG

local function Migrate(db, char)
	db.schema = db.schema or NG.SCHEMA
	char.schema = char.schema or NG.CHAR_SCHEMA
	-- (schema 1 is the first layout; later layouts add their steps here, oldest first)
end

NG:On("ADDON_LOADED", function(_, name)
	if name ~= ADDON or NG.loaded then return end
	NG.loaded = true
	_G.NetherGoblinDB = type(_G.NetherGoblinDB) == "table" and _G.NetherGoblinDB or {}
	_G.NetherGoblinCharDB = type(_G.NetherGoblinCharDB) == "table" and _G.NetherGoblinCharDB or {}
	local db, char = _G.NetherGoblinDB, _G.NetherGoblinCharDB
	NG.db, NG.char = db, char
	Migrate(db, char)
	NG.Settings:Init(db, char)
	NG.Prices:Init(db)
	NG.Ledger:Init(char)
	NG.Lists:Init(db)
	NG:Fire("DB_READY")
end)

NG:On("PLAYER_LOGIN", function()
	NG.loggedIn = true
	NG:Fire("LOGIN")
	-- unpack this auction house's prices a little after login, not on the first tooltip
	NG:After(6, function() NG.Prices:Realm() end)
end)

NG:On("PLAYER_LOGOUT", function()
	NG:Fire("LOGOUT")
	NG:Safe("pack prices", NG.Prices.Pack, NG.Prices)
end)
