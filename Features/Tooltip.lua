--[[ NetherGoblin - Features/Tooltip.lua
	Auction prices on item tooltips (everywhere the game shows an item: bags, links, loot,
	vendors, the auction house itself):

	  Auction (usual)   7s 85c
	  Auction (lowest)  7s 20c   · 2 h ago
	  Auction x20       1g 44s

	Hooked once through TooltipDataProcessor (the game's own tooltip pipeline). In a dungeon
	the game may hand tooltip data back as secret values: anything secret is left alone and
	the tooltip simply gets no prices. ]]

local _, ns = ...
local NG = ns.NG
local Tip = NG:Module("Tooltip")
local L = ns.L
local Num, Str, Call, Open = NG.Num, NG.Str, NG.Call, NG.Open

local GOLD = { 0.91, 0.77, 0.42 }

local function StackCount(tooltip)
	local owner = tooltip.GetOwner and Call(tooltip.GetOwner, tooltip)
	if not owner then return nil end
	local bag = owner.GetBagID and Call(owner.GetBagID, owner)
	local slot = owner.GetID and Call(owner.GetID, owner)
	bag, slot = Num(bag), Num(slot)
	local CC = _G.C_Container
	if bag and slot and CC and CC.GetContainerItemInfo then
		local info = Open(Call(CC.GetContainerItemInfo, bag, slot))
		return info and Num(info.stackCount)
	end
	return nil
end

function Tip:Add(tooltip, link)
	if not NG.Settings:Get("tooltip.enabled") then return end
	if not (tooltip and tooltip.AddDoubleLine) then return end
	local e, key = NG.Prices:ForLink(link)
	if not e then return end
	local M = NG.Money
	local any = false
	if NG.Settings:Get("tooltip.market") then
		local mv = NG.Prices:Market(key)
		if mv then tooltip:AddDoubleLine(L["Auction (usual)"], M:Text(mv), GOLD[1], GOLD[2], GOLD[3], 1, 1, 1) any = true end
	end
	if NG.Settings:Get("tooltip.lowest") and e.m then
		local right = M:Text(e.m)
		if NG.Settings:Get("tooltip.age") and e.t then right = right .. "  |cff9a8f7a" .. NG.Window.Ago(NG:Now() - e.t) .. "|r" end
		if (e.q or 0) == 0 then right = right .. "  |cff9a8f7a" .. L["(none listed)"] .. "|r" end
		tooltip:AddDoubleLine(L["Auction (lowest)"], right, GOLD[1], GOLD[2], GOLD[3], 1, 1, 1)
		any = true
	end
	if NG.Settings:Get("tooltip.stack") then
		local n = StackCount(tooltip)
		local each = NG.Prices:Market(key) or e.m
		if n and n > 1 and each then tooltip:AddDoubleLine(string.format(L["Auction x%d"], n), M:Text(each * n), GOLD[1], GOLD[2], GOLD[3], 1, 1, 1) any = true end
	end
	if any and tooltip.Show then tooltip:Show() end
end

local function PostCall(tooltip, data)
	if NG.IsSecret(tooltip) then return end
	data = Open(data)
	if not data then return end
	local link
	if tooltip.GetItem then
		local ok, _, l = pcall(tooltip.GetItem, tooltip)
		if ok then link = Str(l) end
	end
	if not link then
		local id = Num(data.id)
		if not id then return end
		link = "item:" .. id
	end
	Tip:Add(tooltip, link)
end

NG:Register("LOGIN", function()
	local TDP, E = _G.TooltipDataProcessor, _G.Enum and _G.Enum.TooltipDataType
	if TDP and TDP.AddTooltipPostCall and E and E.Item then
		TDP.AddTooltipPostCall(E.Item, function(tooltip, data) NG:Safe("tooltip", PostCall, tooltip, data) end)
	end
end)
