--[[ NetherGoblin - Features/PriceCheck.lua
	Guild and party price checks. Anyone (with or without NetherGoblin) types in guild or party
	chat:
	    @[Linen Cloth]          @Linen Cloth          $[Linen Cloth]x20          $Linen Cloth x20
	and ONE NetherGoblin user answers by whisper: the one whose price is freshest.

	How only one answers (Docs/PROTOCOL.md): every NetherGoblin that knows the item waits a
	moment, shorter the fresher its price (plus a little random), then claims the question on
	the addon channel and whispers. Anyone still waiting who sees the claim stays quiet. So a
	question costs one addon message and one whisper, however many members run NetherGoblin.

	Rules: prices older than 3 days are never used; typed names must match an item exactly
	(otherwise silence); you never answer yourself; one answer per asker every 4 s and one
	every 1.5 s overall; nothing in instances (the game blocks addon chat there); secret chat
	values are skipped untouched; names stay whole ("Derp Diggler" is never split). ]]

local _, ns = ...
local NG = ns.NG
local PC = NG:Module("PriceCheck")
local L = ns.L
local Num, Str, Call = NG.Num, NG.Str, NG.Call
local floor, min = math.floor, math.min

local PREFIX = "NGpc"
local MAX_AGE = 3 * 86400
local MARK = "NetherGoblin: "
local waiting = {}      -- hash -> true while this client is still deciding
local claimed = {}      -- hash -> time claimed (by anyone)
local claimedBy = {}    -- hash -> the name that sorts first among the claims seen

function PC:MyName()
	local name = Str(_G.UnitName and Call(UnitName, "player")) or "?"
	local realm = Str(_G.GetNormalizedRealmName and Call(GetNormalizedRealmName)) or ""
	return name .. "-" .. realm
end
local lastAsker, lastAny = {}, 0
local stats = { answered = 0, yielded = 0, dropped = 0 }
function PC:Stats() return stats end

-- the question's id: the same on every client that saw the same line (a simple 31-bit hash,
-- kept small so every client computes it exactly alike)
local function Hash(s)
	local h = 5381
	for i = 1, #s do h = (h * 33 + s:byte(i)) % 2147483647 end
	return string.format("%08x", h)
end

local function Enabled(channel)
	if not NG.Settings:Get("guild.enabled") then return false end
	if channel == "GUILD" then return NG.Settings:Get("guild.guild") end
	if channel == "PARTY" then return NG.Settings:Get("guild.party") end
	return false
end

local function Quiet()
	if _G.IsInInstance then
		local inside = Call(IsInInstance)
		if inside then return true end
	end
	local C = _G.C_ChatInfo
	return C and C.InChatMessagingLockdown and Call(C.InChatMessagingLockdown) == true or false
end

-- "@[link]x20", "@Linen Cloth", "$Linen Cloth x 10" -> link or name, count
function PC:Parse(text)
	text = Str(text)
	if not text then return nil end
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	local trigger = text:sub(1, 1)
	if trigger ~= "@" and trigger ~= "$" then return nil end
	local rest = text:sub(2):gsub("^%s+", "")
	local count = 1
	local n = rest:match("[xX]%s*(%d+)$")
	if n then
		count = tonumber(n)
		rest = rest:gsub("%s*[xX]%s*%d+$", "")
	end
	if count < 1 or count > 10000 then return nil end
	local link = rest:match("(|c[^|]*|Hitem:.-|h.-|h|r)") or rest:match("(|Hitem:.-|h.-|h)")
	if link then return { link = link, count = count } end
	if rest == "" or #rest > 80 or rest:find("|", 1, true) then return nil end
	return { name = rest, count = count }
end

-- the price this client would answer with, or nil
function PC:Lookup(q)
	local P = NG.Prices
	local e, key, link
	if q.link then
		e, key = P:ForLink(q.link)
		link = q.link
	else
		local id = P:NameToID(q.name)
		if not id then return nil end
		e, key = P:Entry(id), id
		local C = _G.C_Item
		link = select(2, Call(C and C.GetItemInfo or _G.GetItemInfo, id)) or q.name
	end
	if not (e and e.t) then return nil end
	local age = NG:Now() - e.t
	if age > MAX_AGE or age < 0 then return nil end
	local each = e.m or P:Market(key)
	if not each then return nil end
	return { link = link, each = each, market = P:Market(key), age = age, listed = e.q or 0 }
end

function PC:AnswerText(q, r)
	-- money as plain "1g 5s 20c" (no colour codes: the whisper carries the item link untouched)
	local function Money(c) return (NG.Money:Text(c, { plain = true }):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
	local parts = {}
	local what = (r.link or "?") .. (q.count > 1 and (" x" .. q.count) or "")
	if q.count > 1 then
		parts[#parts + 1] = string.format("%s: %s (%s %s)", what, Money(r.each * q.count), Money(r.each), L["each"])
	else
		parts[#parts + 1] = string.format("%s: %s", what, Money(r.each))
	end
	if r.market and r.market ~= r.each then parts[#parts + 1] = string.format(L["usual %s"], Money(r.market)) end
	parts[#parts + 1] = string.format(L["seen %s"], NG.Window.Ago(r.age))
	parts[#parts + 1] = string.format(L["%s auction house"], NG.Prices:RealmKey() or "?")
	return MARK .. table.concat(parts, " - ")
end

local function SendWhisper(text, target)
	local C = _G.C_ChatInfo
	local fn = (C and C.SendChatMessage) or _G.SendChatMessage
	if not fn then return false end
	return pcall(fn, text, "WHISPER", nil, target)
end

local function SendClaim(hash, channel)
	local C = _G.C_ChatInfo
	if not (C and C.SendAddonMessage) then return end
	pcall(C.SendAddonMessage, PREFIX, NG.PROTOCOL .. "|C|" .. hash, channel)
end

local function OnChat(channel, text, sender, guid)
	if NG.IsSecret(text) or NG.IsSecret(sender) then return end
	text, sender = Str(text), Str(sender)
	if not (text and sender and Enabled(channel)) then return end
	local first = text:sub(1, 1)
	if first ~= "@" and first ~= "$" then return end
	if Quiet() then return end
	-- never answer yourself
	local me = _G.UnitGUID and Call(UnitGUID, "player")
	if guid and not NG.IsSecret(guid) and me and guid == me then return end
	local q = PC:Parse(text)
	if not q then return end
	local r = PC:Lookup(q)
	if not r then return end   -- unknown item or old price: stay silent
	local hash = Hash(channel .. "\1" .. sender .. "\1" .. text)
	if claimed[hash] or waiting[hash] then return end
	-- fresher prices answer sooner
	local delay = 0.15 + 2.2 * min(1, r.age / MAX_AGE) + math.random() * 0.25
	waiting[hash] = true
	NG:After(delay, function()
		if not waiting[hash] then return end
		waiting[hash] = nil
		if claimed[hash] then stats.yielded = stats.yielded + 1 return end
		local now = NG:Clock()
		if now - lastAny < 1.5 or (lastAsker[sender] and now - lastAsker[sender] < 4) then stats.dropped = stats.dropped + 1 return end
		if Quiet() then stats.dropped = stats.dropped + 1 return end
		-- claim it, then give other claims a moment to arrive: when two clients claim at once,
		-- the one whose name sorts first answers and the other stays quiet
		claimed[hash] = now
		claimedBy[hash] = PC:MyName()
		SendClaim(hash, channel)
		NG:After(0.5, function()
			local winner = claimedBy[hash]
			if winner and winner ~= PC:MyName() then stats.yielded = stats.yielded + 1 return end
			if Quiet() then stats.dropped = stats.dropped + 1 return end
			lastAny, lastAsker[sender] = NG:Clock(), NG:Clock()
			if SendWhisper(PC:AnswerText(q, r), sender) then stats.answered = stats.answered + 1 end
		end)
	end)
end

NG:On("CHAT_MSG_GUILD", function(_, text, sender, _, _, _, _, _, _, _, _, _, guid) OnChat("GUILD", text, sender, guid) end)
NG:On("CHAT_MSG_PARTY", function(_, text, sender, _, _, _, _, _, _, _, _, _, guid) OnChat("PARTY", text, sender, guid) end)
NG:On("CHAT_MSG_PARTY_LEADER", function(_, text, sender, _, _, _, _, _, _, _, _, _, guid) OnChat("PARTY", text, sender, guid) end)

-- someone else claimed a question: stand down
NG:On("CHAT_MSG_ADDON", function(_, prefix, msg, channel, sender)
	if prefix ~= PREFIX or NG.IsSecret(msg) then return end
	msg = Str(msg)
	if not msg or #msg > 64 then stats.dropped = stats.dropped + 1 return end
	local ver, kind, hash = msg:match("^(%d+)|(%u)|(%x+)$")
	if not ver or tonumber(ver) > NG.PROTOCOL then return end
	if kind == "C" and #hash == 8 then
		claimed[hash] = NG:Clock()
		sender = Str(sender)
		if sender and (not claimedBy[hash] or sender < claimedBy[hash]) then claimedBy[hash] = sender end
		if waiting[hash] then waiting[hash] = nil stats.yielded = stats.yielded + 1 end
	end
end)

-- forget old claims now and then
NG:Register("LOGIN", function()
	local C = _G.C_ChatInfo
	if C and C.RegisterAddonMessagePrefix then pcall(C.RegisterAddonMessagePrefix, PREFIX) end
	if _G.C_Timer and C_Timer.NewTicker then
		C_Timer.NewTicker(5, function()
			local now = NG:Clock()
			for h, t in pairs(claimed) do if now - t >= 12 then claimed[h] = nil claimedBy[h] = nil end end
			for a, t in pairs(lastAsker) do if now - t > 120 then lastAsker[a] = nil end end
		end)
	end
	-- your own answer whispers stay out of your chat (setting)
	local add = (_G.ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or _G.ChatFrame_AddMessageEventFilter
	if add then
		pcall(add, "CHAT_MSG_WHISPER_INFORM", function(_, _, text)
			if NG.IsSecret(text) or type(text) ~= "string" then return false end
			return NG.Settings:Get("guild.hideSent") and text:sub(1, #MARK) == MARK or false
		end)
	end
end)

PC.Hash = Hash
