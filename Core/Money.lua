--[[ NetherGoblin - Core/Money.lua
	Copper amounts as text, and back.

	  Money:Text(copper [, opts])   "1g 05s 20c" with the coin icons; opts.plain = no icons,
	                                 opts.short = drop zero copper/silver on gold amounts
	  Money:Split(copper)           gold, silver, copper
	  Money:Join(g, s, c)           copper
	  Money:Parse(text)             copper or nil: "1g 5s 20c", "1g5s", "2.5g", "75s", "30c",
	                                 a bare number is gold ("12" = 12g) ]]

local _, ns = ...
local NG = ns.NG
local Money = NG:Module("Money")
local floor, format, tonumber = math.floor, string.format, tonumber

local ICON = {
	g = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:1:0|t",
	s = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:1:0|t",
	c = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:1:0|t",
}
local LETTER = { g = "|cffffd24ag|r", s = "|cffc7c7cfs|r", c = "|cffd8884ac|r" }

function Money:Split(copper)
	copper = floor(tonumber(copper) or 0)
	if copper < 0 then copper = 0 end
	return floor(copper / 10000), floor(copper / 100) % 100, copper % 100
end

function Money:Join(g, s, c)
	return floor((tonumber(g) or 0) * 10000 + (tonumber(s) or 0) * 100 + (tonumber(c) or 0) + 0.5)
end

function Money:Text(copper, opts)
	if copper == nil then return "-" end
	local g, s, c = self:Split(copper)
	local mark = (opts and opts.plain) and LETTER or ICON
	local parts = {}
	if g > 0 then
		parts[#parts + 1] = (g >= 1000 and (_G.BreakUpLargeNumbers and BreakUpLargeNumbers(g) or tostring(g)) or tostring(g)) .. mark.g
	end
	local short = opts and opts.short and g > 0
	if (g > 0 or s > 0) and not (short and s == 0 and c == 0) then
		parts[#parts + 1] = (g > 0 and format("%02d", s) or tostring(s)) .. mark.s
	end
	if not (short and c == 0) and (c > 0 or (g == 0 and s == 0) or not short) then
		parts[#parts + 1] = ((g > 0 or s > 0) and format("%02d", c) or tostring(c)) .. mark.c
	end
	return table.concat(parts, " ")
end

function Money:Parse(text)
	if type(text) ~= "string" then return nil end
	text = text:lower():gsub(",", ""):gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" then return nil end
	local bare = tonumber(text)
	if bare then return bare >= 0 and floor(bare * 10000 + 0.5) or nil end
	local total, found = 0, false
	for num, unit in text:gmatch("([%d%.]+)%s*([gsc])") do
		local n = tonumber(num)
		if not n then return nil end
		found = true
		total = total + n * (unit == "g" and 10000 or unit == "s" and 100 or 1)
	end
	if not found then return nil end
	-- anything left that is not a number+unit pair: not money
	if text:gsub("[%d%.]+%s*[gsc]", ""):gsub("%s", "") ~= "" then return nil end
	return floor(total + 0.5)
end
