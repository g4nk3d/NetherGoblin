--[[ NetherGoblin - Features/Minimap.lua
	The goblin's face on the minimap. Left-click: settings. Right-click: the Quick Scan when the
	auction house is open, otherwise the last scan's numbers in chat. Shift + drag: slide it
	around the minimap's edge (round or square). A plain named button on the minimap, so button
	collectors take it into their drawer like any other.

	The ring is tinted: gold in the goblin look, the theme's accent colour in the theme look.
	"minimap.button" (on by default) shows or hides it; its place is kept account-wide. ]]

local _, ns = ...
local NG = ns.NG
local MM = NG:Module("MinimapButton")
local L = ns.L
local Skin = NG.Skin
local SIZE, OFFSET = 30, 2
local floor, rad, deg, cos, sin, atan2, abs, max = math.floor, math.rad, math.deg, math.cos, math.sin, math.atan2, math.abs, math.max

local function DB()
	NG.db.minimap = NG.db.minimap or {}
	local m = NG.db.minimap
	if m.angle == nil then m.angle = 215 end
	return m
end

local function Square()
	local ok, shape = pcall(function() return _G.GetMinimapShape and GetMinimapShape() end)
	return ok and shape == "SQUARE"
end

-- on the map's edge, from the saved angle; left alone while a button collector holds it
function MM:Place()
	local b = self.button
	if not (b and _G.Minimap) or b:GetParent() ~= Minimap then return end
	local a = rad(DB().angle)
	local cx, cy = cos(a), sin(a)
	local dist = Minimap:GetWidth() / 2 + OFFSET
	if Square() then dist = dist / max(abs(cx), abs(cy)) end
	b:ClearAllPoints()
	b:SetPoint("CENTER", Minimap, "CENTER", cx * dist, cy * dist)
end

function MM:Tint()
	local b = self.button
	if not b then return end
	if Skin:Mode() == "goblin" then
		b.ring:SetVertexColor(0.91, 0.77, 0.42, 1)
	else
		Skin:Paint(b.ring, "accent")
	end
end

local function Tooltip(self)
	local tt = _G.GameTooltip
	if not tt then return end
	tt:SetOwner(self, "ANCHOR_LEFT")
	tt:SetText(NG.TITLE)
	local last = NG.Scan:Last()
	if last.at then
		tt:AddLine(string.format(L["Prices %s  ·  %s items  ·  %s auction house"], NG.Window.Ago(NG:Now() - last.at),
			_G.BreakUpLargeNumbers and BreakUpLargeNumbers(last.items or 0) or tostring(last.items or 0), NG.Prices:RealmKey() or "?"), 0.8, 0.8, 0.8, true)
	else
		tt:AddLine(L["No scan yet. Open the auction house and the goblin gets to work."], 0.8, 0.8, 0.8, true)
	end
	tt:AddLine(L["Left-click: settings"], 1, 1, 1)
	tt:AddLine(NG.House:IsOpen() and L["Right-click: Quick Scan"] or L["Right-click: the last scan, in chat"], 1, 1, 1)
	if self:GetParent() == Minimap then tt:AddLine(L["Shift + drag: move around the minimap"], 0.7, 0.7, 0.7) end
	tt:Show()
end

function MM:Build()
	if self.button or not _G.Minimap then return self.button end
	local b = CreateFrame("Button", "NetherGoblinMinimapButton", Minimap)
	self.button = b
	b:SetSize(SIZE, SIZE)
	b:SetFrameStrata("MEDIUM")
	b:SetFrameLevel(Minimap:GetFrameLevel() + 20)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetClampedToScreen(true)
	local shadow = b:CreateTexture(nil, "BACKGROUND", nil, -8)
	shadow:SetTexture(NG.MEDIA .. "Glow")
	shadow:SetPoint("TOPLEFT", -10, 10) shadow:SetPoint("BOTTOMRIGHT", 10, -10)
	shadow:SetVertexColor(0, 0, 0, 0.7)
	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(NG.MEDIA .. "MinimapIcon")
	icon:SetAllPoints()
	local ring = b:CreateTexture(nil, "OVERLAY")
	ring:SetTexture(NG.MEDIA .. "MinimapRing")
	ring:SetAllPoints()
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetTexture(NG.MEDIA .. "Glow") hl:SetBlendMode("ADD")
	hl:SetPoint("TOPLEFT", -4, 4) hl:SetPoint("BOTTOMRIGHT", 4, -4)
	hl:SetVertexColor(1, 0.85, 0.5, 0.35)
	b.icon, b.ring = icon, ring
	self:Tint()

	local function Drag(self)
		local mx, my = GetCursorPosition()
		local scale = Minimap:GetEffectiveScale()
		local ox, oy = Minimap:GetCenter()
		if not (ox and oy) then return end
		DB().angle = floor(deg(atan2(my / scale - oy, mx / scale - ox)) % 360 + 0.5)
		MM:Place()
	end
	b:SetScript("OnMouseDown", function(self, mouse)
		if mouse == "LeftButton" and IsShiftKeyDown() and self:GetParent() == Minimap then
			self.dragging = true
			self:SetScript("OnUpdate", Drag)
		end
		self.icon:SetPoint("TOPLEFT", 1, -1) self.icon:SetPoint("BOTTOMRIGHT", 1, -1)
	end)
	b:SetScript("OnMouseUp", function(self)
		self.icon:SetAllPoints()
		if self.dragging then
			self:SetScript("OnUpdate", nil)
			self.dragEnded = true
			NG:After(0, function() self.dragEnded = nil end)
		end
		self.dragging = nil
	end)
	b:SetScript("OnClick", function(self, mouse)
		if self.dragEnded or IsShiftKeyDown() then return end
		if mouse == "RightButton" then
			if NG.House:IsOpen() then
				if NG.Scan:IsRunning() then NG.Scan:Cancel("user") else NG.Scan:Start("user") end
			else
				local last = NG.Scan:Last()
				if last.at then
					NG:Print(L["Last scan %s: %s items in %s s on the %s auction house."], NG.Window.Ago(NG:Now() - last.at),
						_G.BreakUpLargeNumbers and BreakUpLargeNumbers(last.items or 0) or tostring(last.items or 0), tostring(last.seconds or 0), NG.Prices:RealmKey() or "?")
				else
					NG:Print(L["No scan yet. Open the auction house and the goblin gets to work."])
				end
			end
		else
			NG.Config:Toggle()
		end
	end)
	b:SetScript("OnEnter", Tooltip)
	b:SetScript("OnLeave", function() if _G.GameTooltip then GameTooltip:Hide() end end)

	-- NetherUI: its Classic Vanilla ring levels the buttons on it; its shape changes move them
	local AUI = Skin.NetherUI()
	if AUI then
		AUI.ringButtons = AUI.ringButtons or {}
		table.insert(AUI.ringButtons, b)
		if type(AUI.SetMinimapShape) == "function" and _G.hooksecurefunc then hooksecurefunc(AUI, "SetMinimapShape", function() MM:Place() end) end
		if type(AUI.RegisterCallback) == "function" then pcall(AUI.RegisterCallback, AUI, "THEME_CHANGED", function() NG:After(0.5, function() MM:Place() end) end) end
	end
	Minimap:HookScript("OnSizeChanged", function() MM:Place() end)
	self:Place()
	return b
end

function MM:SetShown(on)
	if on then self:Build() end
	if self.button then self.button:SetShown(on and true or false) end
end

-- built at login, before button collectors gather the minimap's buttons
NG:Register("LOGIN", function()
	if NG.Settings:Get("minimap.button") then NG:Safe("minimap button", MM.Build, MM) end
end)
NG:Register("SETTING_CHANGED", function(_, key)
	if key == "minimap.button" or key == "*" then MM:SetShown(NG.Settings:Get("minimap.button")) end
end)
Skin:OnChange(function() MM:Tint() end)
