--[[ NetherGoblin - Features/LinkSearch.lua
	Shift+click an item (in your bags, a chat link, the character sheet, a row of ours) while
	NetherGoblin's auction window is up and no chat box is open: its name goes into our search,
	as it does in the game's own auction window. The game hands the click to the game's window
	(kept invisible behind ours), so without this the name went nowhere you could see.

	Where the name goes:
	  - one of our text boxes that takes item names, if it has the cursor (the Buy search, the
	    Shopping tab's "Add an item name...")
	  - on the Shopping tab: its "Add an item name..." box
	  - anywhere else: the Buy tab's search box, and the search runs at once
	A chat box that is open still gets the link, and a text box of another addon (or the game's
	macro window) that has the cursor is left alone.

	Settings (Buying & selling): search.shiftClick, search.shiftClickGo ]]

local _, ns = ...
local NG = ns.NG
local LS = NG:Module("LinkSearch")
local Call = NG.Call

-- an item link's name: the game's item info, else the name printed in the link itself
function LS:Name(link)
	if type(link) ~= "string" or not link:find("item:", 1, true) then return nil end
	local name = Call(_G.C_Item and C_Item.GetItemInfo or _G.GetItemInfo, link)
	if type(name) ~= "string" or name == "" then name = link:match("|h%[(.-)%]|h") end
	if type(name) ~= "string" or name == "" then return nil end
	return name
end

local function Focused(box) return box and box.edit and box.edit.HasFocus and box.edit:HasFocus() == true end

-- our boxes that take item names
local function Boxes()
	local out = {}
	local s = NG.TabBuy and NG.TabBuy.SearchBox and NG.TabBuy:SearchBox()
	local a = NG.TabShopping and NG.TabShopping.AddBox and NG.TabShopping:AddBox()
	if s then out[#out + 1] = s end
	if a then out[#out + 1] = a end
	return out
end

local function Ours(edit)
	for _, b in ipairs(Boxes()) do if b.edit == edit then return true end end
	return false
end

function LS:Insert(link)
	if NG.Settings:Get("search.shiftClick") == false then return false end
	if not (NG.Window and NG.Window:IsShown()) then return false end
	local chat = _G.ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
	if chat then return false end
	local focus = _G.GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
	if focus and not Ours(focus) then return false end
	local name = self:Name(link)
	if not name then return false end
	-- a box of ours with the cursor
	for _, b in ipairs(Boxes()) do
		if Focused(b) then
			b:SetText(name)
			if b.edit.SetCursorPosition then b.edit:SetCursorPosition(#name) end
			return true
		end
	end
	-- the Shopping tab: its Add box, ready for Enter
	local add = NG.TabShopping and NG.TabShopping.AddBox and NG.TabShopping:AddBox()
	if NG.Window.current == "shopping" and add then
		add:SetText(name)
		if add.edit.SetFocus then add.edit:SetFocus() end
		return true
	end
	-- anywhere else: the Buy tab's search
	if NG.Window.current ~= "buy" then NG.Window:SelectTab("buy") end
	if NG.Settings:Get("search.shiftClickGo") ~= false then
		NG.TabBuy:Search(name)
	else
		local s = NG.TabBuy:SearchBox()
		if s then s:SetText(name) end
	end
	return true
end

-- ChatEdit_InsertLink (and ChatFrameUtil.InsertLink where the client has it, which the old
-- name may call) - once per click
local lastLink, lastTime
local function After(link)
	local now = _G.GetTime and GetTime() or 0
	if link == lastLink and now == lastTime then return end
	lastLink, lastTime = link, now
	NG:Safe("shift-click search", LS.Insert, LS, link)
end

if _G.hooksecurefunc then
	if type(_G.ChatEdit_InsertLink) == "function" then hooksecurefunc("ChatEdit_InsertLink", After) end
	local U = rawget(_G, "ChatFrameUtil")
	if type(U) == "table" and type(U.InsertLink) == "function" then hooksecurefunc(U, "InsertLink", After) end
end
