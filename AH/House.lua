--[[ NetherGoblin - AH/House.lua
	The auction house itself: is it open, one queue for every request we send it, and the
	game's own auction window kept out of the way while ours is shown.

	  House:IsOpen()
	  House:Send(label, fn)         queue a request; sent when the game's message throttle is
	                                ready (C_AuctionHouse.IsThrottledMessageSystemReady), in order;
	                                a request the server dropped is sent again (twice at most)
	  House:Clear()                 forget queued requests (the house closed)
	  House:Close()                 close the auction house (our close button)
	  House:SetBlizzardShown(show)  this session: the game's window instead of ours

	Fires "AH_OPEN" and "AH_CLOSED".

	The game's window: Blizzard's AuctionHouseFrame closes the auction house when it is hidden,
	so it is never hidden. While ours is up it is made invisible and tiny (alpha 0, scale
	0.0001) so nothing in it can be clicked by accident, and restored as soon as ours closes or
	the player switches back to it. ]]

local _, ns = ...
local NG = ns.NG
local House = NG:Module("House")
local Call = NG.Call

local queue, retries = {}, 0
local lastSent
local pump = CreateFrame("Frame")
pump:Hide()

function House:IsOpen() return self.open == true end

local function Ready()
	local C = _G.C_AuctionHouse
	if not (C and House.open) then return false end
	if C.IsThrottledMessageSystemReady then
		local ok, ready = pcall(C.IsThrottledMessageSystemReady)
		return ok and ready ~= false
	end
	return true
end

pump:SetScript("OnUpdate", function(self)
	if #queue == 0 or not House.open then self:Hide() return end
	if not Ready() then return end
	local req = table.remove(queue, 1)
	lastSent = req
	NG:Safe("auction request " .. tostring(req.label), req.fn)
end)

function House:Send(label, fn)
	queue[#queue + 1] = { label = label, fn = fn, tries = 0 }
	pump:Show()
end

function House:Clear() NG.wipe(queue) lastSent = nil pump:Hide() end
function House:Pending() return #queue end
-- forget queued requests whose label starts with prefix (a cancelled scan's next page)
function House:Drop(prefix)
	for i = #queue, 1, -1 do
		if queue[i].label:sub(1, #prefix) == prefix then table.remove(queue, i) end
	end
end

NG:On("AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED", function()
	local req = lastSent
	if req and req.tries < 2 then
		req.tries = req.tries + 1
		table.insert(queue, 1, req)
		pump:Show()
		NG:Log("info", "request %s dropped by the server; sending again", tostring(req.label))
	end
end)
NG:On("AUCTION_HOUSE_THROTTLED_SYSTEM_READY", function() if #queue > 0 then pump:Show() end end)

---------------------------------------------------------------------------------------------
-- The game's own window
---------------------------------------------------------------------------------------------
local hidden = false
function House:BlizzardFrame() return rawget(_G, "AuctionHouseFrame") end

function House:WantOurs()
	if self.blizzardThisSession then return false end
	return NG.Settings:Get("window.replaceBlizzard") and NG.Window and NG.Window.Available and NG.Window:Available() or false
end

function House:HideBlizzard()
	local f = self:BlizzardFrame()
	if not f or hidden then return end
	hidden = true
	local sc = f:GetScale()
	if sc and sc > 0.01 then self.savedScale = sc end
	f:SetAlpha(0)
	f:SetScale(0.0001)
end

function House:RestoreBlizzard()
	local f = self:BlizzardFrame()
	if not f or not hidden then return end
	hidden = false
	f:SetScale(self.savedScale or 1)
	f:SetAlpha(1)
end

function House:SetBlizzardShown(show)
	self.blizzardThisSession = show and true or nil
	if show then
		self:RestoreBlizzard()
		if NG.Window then NG.Window:Hide() end
	else
		self:HideBlizzard()
		if NG.Window then NG.Window:Show() end
	end
end

local hooked = false
local function HookBlizzard()
	local f = House:BlizzardFrame()
	if hooked or not f then return end
	hooked = true
	-- whenever the game shows its window again (it re-shows on every visit), hide it again
	f:HookScript("OnShow", function()
		if House.open and House:WantOurs() then hidden = false House:HideBlizzard() end
	end)
end

function House:Close()
	local C = _G.C_AuctionHouse
	if C and C.CloseAuctionHouse then
		Call(C.CloseAuctionHouse)
	else
		local f = self:BlizzardFrame()
		if f and _G.HideUIPanel then HideUIPanel(f) end
	end
end

NG:On("AUCTION_HOUSE_SHOW", function()
	House.open = true
	House.openedAt = NG:Clock()
	-- the game loads its auction UI on this same event; look for it a moment later too
	HookBlizzard()
	if House:WantOurs() then House:HideBlizzard() end
	NG:Fire("AH_OPEN")
	NG:After(0, function()
		HookBlizzard()
		if House.open and House:WantOurs() then hidden = false House:HideBlizzard() end
	end)
end)

NG:On("AUCTION_HOUSE_CLOSED", function()
	if not House.open then return end
	House.open = false
	House:Clear()
	House:RestoreBlizzard()
	House.blizzardThisSession = nil
	NG:Fire("AH_CLOSED")
end)
