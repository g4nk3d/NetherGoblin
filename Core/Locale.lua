--[[ NetherGoblin - Core/Locale.lua
	Every string the player reads goes through L. Keys are the English text itself, so a
	missing translation simply shows English. Locales/enUS.lua holds the longer texts (the
	goblin's lines). There is no other language yet. ]]
local _, ns = ...
local L = setmetatable({}, { __index = function(_, k) return k end })
ns.L = L
ns.NG.L = L
