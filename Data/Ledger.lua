--[[ NetherGoblin - Data/Ledger.lua
	What you did at the auction house (this character): posted, bought, cancelled. Plus the
	shopping lists and the recent searches (account-wide).

	  Ledger:Add(kind, info)        kind "post" | "buy" | "bid" | "cancel"
	                                info: { itemID, link, name, qty, unit (copper each), total }
	  Ledger:List([kind])           newest first
	  Ledger:Totals(days)           spent, posted value, counts over the last days

	  Lists:All()                   { { name, items = { { text, max } } } }
	  Lists:Add(listIndex, text [, max]) / Lists:Remove(listIndex, i)
	  Lists:New(name) / Lists:Delete(listIndex) / Lists:Rename(listIndex, name)
	  Lists:Recent() / Lists:NoteSearch(text) ]]

local _, ns = ...
local NG = ns.NG
local Ledger = NG:Module("Ledger")
local Lists = NG:Module("Lists")
local Num, Str = NG.Num, NG.Str

local MAX_LEDGER = 600
local MAX_RECENT = 6

function Ledger:Init(char)
	char.ledger = char.ledger or {}
	self.rows = char.ledger
end

function Ledger:Add(kind, info)
	if not self.rows or type(info) ~= "table" then return end
	local row = {
		k = kind, t = NG:Now(),
		id = Num(info.itemID), link = Str(info.link), name = Str(info.name),
		q = Num(info.qty) or 1, u = Num(info.unit), tot = Num(info.total),
	}
	if not row.tot and row.u then row.tot = row.u * row.q end
	table.insert(self.rows, 1, row)
	for i = #self.rows, MAX_LEDGER + 1, -1 do self.rows[i] = nil end
	NG:Fire("LEDGER_CHANGED", row)
end

function Ledger:List(kind)
	if not self.rows then return {} end
	if not kind then return self.rows end
	local out = {}
	for _, r in ipairs(self.rows) do if r.k == kind then out[#out + 1] = r end end
	return out
end

function Ledger:Totals(days)
	local since = NG:Now() - (days or 7) * 86400
	local t = { spent = 0, posted = 0, buys = 0, posts = 0, cancels = 0 }
	for _, r in ipairs(self.rows or {}) do
		if r.t >= since then
			if r.k == "buy" then t.spent = t.spent + (r.tot or 0) t.buys = t.buys + 1
			elseif r.k == "post" then t.posted = t.posted + (r.tot or 0) t.posts = t.posts + 1
			elseif r.k == "cancel" then t.cancels = t.cancels + 1 end
		end
	end
	return t
end

---------------------------------------------------------------------------------------------
-- Shopping lists and recent searches
---------------------------------------------------------------------------------------------
function Lists:Init(db)
	db.shopping = db.shopping or {}
	if #db.shopping == 0 then db.shopping[1] = { name = NG.L["My list"], items = {} } end
	db.recent = db.recent or {}
	self.lists, self.recent = db.shopping, db.recent
end

function Lists:All() return self.lists or {} end

function Lists:New(name)
	name = Str(name) or NG.L["New list"]
	table.insert(self.lists, { name = name, items = {} })
	NG:Fire("LISTS_CHANGED")
	return #self.lists
end

function Lists:Delete(i)
	if not self.lists[i] then return end
	table.remove(self.lists, i)
	if #self.lists == 0 then self.lists[1] = { name = NG.L["My list"], items = {} } end
	NG:Fire("LISTS_CHANGED")
end

function Lists:Rename(i, name)
	name = Str(name)
	if self.lists[i] and name then self.lists[i].name = name NG:Fire("LISTS_CHANGED") end
end

function Lists:Add(i, text, max)
	local list = self.lists[i]
	text = Str(text)
	if not (list and text) then return false end
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	for _, it in ipairs(list.items) do if it.text:lower() == text:lower() then it.max = Num(max) or it.max NG:Fire("LISTS_CHANGED") return true end end
	table.insert(list.items, { text = text, max = Num(max) })
	NG:Fire("LISTS_CHANGED")
	return true
end

function Lists:Remove(i, j)
	local list = self.lists[i]
	if list and list.items[j] then table.remove(list.items, j) NG:Fire("LISTS_CHANGED") end
end

function Lists:Recent() return self.recent or {} end

function Lists:NoteSearch(text)
	text = Str(text)
	if not (text and self.recent) then return end
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" then return end
	for i = #self.recent, 1, -1 do if self.recent[i]:lower() == text:lower() then table.remove(self.recent, i) end end
	table.insert(self.recent, 1, text)
	for i = #self.recent, MAX_RECENT + 1, -1 do self.recent[i] = nil end
	NG:Fire("RECENT_CHANGED")
end
