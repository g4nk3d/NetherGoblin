--[[ NetherGoblin - UI/Window.lua
	The auction house window: the brass frame (Media/Frame tiles, placed by Data/Geometry.lua),
	the six tabs, the gold / scan / Quick Scan row, moving, and resizing by the corner gear.

	The window is laid out at the art's full size (1204 x 834 inside the frame) and shown with
	SetScale, so resizing never re-flows anything: everything grows and shrinks together and
	the layout always fits. Default 75%; drag the bottom-right gear to resize (50% up to the
	largest that fits the screen); double-click it for 75% again. Size and position are kept
	(account-wide, or per character when chosen); "window.lock" freezes both.

	  Window:Available()          the window can be built (the client has what it needs)
	  Window:Show() / Hide() / Toggle()
	  Window:AddTab(key, label, module)   module:Build(container), module:OnShow(), OnHide()
	  Window:SelectTab(key)
	  Window:SetStatus(text)      a short message in the scan bar for a few seconds ]]

local _, ns = ...
local NG = ns.NG
local Window = NG:Module("Window")
local W, Skin = NG.Widgets, NG.Skin
local L = ns.L
local G = ns.GEOMETRY
local floor, max, min = math.floor, math.max, math.min
local MEDIA = NG.MEDIA

Window.W, Window.H = G.w, G.h
Window.P = 12
Window.HEADER_Y = 6              -- the header row starts here (the frame's cloth tails end just above)
Window.TOP = 72                  -- columns start here (below the header row)
-- the lantern's cloth hangs into the top-right corner: nothing goes there
Window.POCKET_W, Window.POCKET_H = (G.pocket and G.pocket[1] or 0), (G.pocket and G.pocket[2] or 0)
-- the header row's right end: left of the close and settings buttons (and the pocket)
Window.HEADER_RIGHT = Window.P + ((Window.POCKET_H > Window.HEADER_Y) and Window.POCKET_W or 0) + 80
Window.BOTTOM = G.h - 12 - 52    -- columns end here (above the status row)
Window.STATUS_Y = G.h - 12 - 44
Window.MIN_SCALE, Window.DEFAULT_SCALE = 0.5, 0.75

local tabs, order = {}, {}
local frame

function Window:Available() return type(G) == "table" and G.w ~= nil end
function Window:Frame() return frame end

-- What is drawn around the window, in window units (for clamping to the screen, centring and
-- the largest scale). The goblin skin: its art (the crest, lanterns and tabs reach well past
-- the window). The theme look: the theme panel (10 past each edge), the title strip above
-- (14 + 46) and the tabs below (18 + 50) - so the window can go much higher on the screen.
local THEME_BOX = { -10, -(14 + 46), 10, 18 + 50 }
local function ArtBox()
	if Skin:Mode() ~= "goblin" then
		local t = THEME_BOX
		return t[1], t[2], G.w + t[3], G.h + t[4]
	end
	local a = G.art
	return a[1], a[2], a[3], a[4]
end

-- the screen clamp follows the look
local function Clamp()
	if not frame then return end
	local x0, y0, x1, y1 = ArtBox()
	frame:SetClampRectInsets(x0, x1 - G.w, -y0, -(y1 - G.h))
end

-- Sizes are in screen pixels: 100% draws the art one pixel per pixel, whatever the game's UI
-- Scale, so 75% means the same on every screen (about 1185 x 1020 pixels for the whole art).
local function Screen()
	local w, h
	if _G.GetPhysicalScreenSize then w, h = GetPhysicalScreenSize() end
	w, h = tonumber(w), tonumber(h)
	if not (w and h and w > 0 and h > 0) then w, h = tonumber(_G.GetScreenWidth and GetScreenWidth()) or 1920, tonumber(_G.GetScreenHeight and GetScreenHeight()) or 1080 end
	return w, h
end

-- frame scale for one art unit = one screen pixel
function Window:PixelFactor()
	local _, ph = Screen()
	local ues = UIParent:GetEffectiveScale()
	if not (ues and ues > 0) then ues = 1 end
	return (768 / ph) / ues
end

function Window:MaxScale()
	local x0, y0, x1, y1 = ArtBox()
	local pw, ph = Screen()
	return max(self.MIN_SCALE, min(1.5, min(pw / (x1 - x0), ph / (y1 - y0)) * 0.98))
end

local function ClampScale(s)
	s = tonumber(s) or Window.DEFAULT_SCALE
	return max(Window.MIN_SCALE, min(Window:MaxScale(), s))
end

---------------------------------------------------------------------------------------------
-- Position and scale
---------------------------------------------------------------------------------------------
local function Place()
	local s = ClampScale(NG.Settings:Get("window.scale")) * Window:PixelFactor()
	frame:SetScale(s)
	local pos = NG.Settings:WindowStore().pos
	frame:ClearAllPoints()
	if pos and pos.x and pos.y then
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.x / s, pos.y / s)
	else
		-- centred: the art as a whole, not just the window inside it
		local x0, y0, x1, y1 = ArtBox()
		local cx, cy = (x0 + x1) / 2 - G.w / 2, (y0 + y1) / 2 - G.h / 2
		frame:SetPoint("CENTER", UIParent, "CENTER", -cx, cy + 10 / s)
	end
end

local function SavePos()
	local s = frame:GetScale()
	local l, t = frame:GetLeft(), frame:GetTop()
	if not (l and t) then return end
	NG.Settings:WindowStore().pos = { x = floor(l * s + 0.5), y = floor(t * s + 0.5) }
end

function Window:ResetPosition()
	NG.Settings:WindowStore().pos = nil
	if frame then Place() end
end

local function SetScaleKeepTopLeft(s)
	local old = frame:GetScale()
	local l, t = frame:GetLeft(), frame:GetTop()
	frame:SetScale(s)
	if l and t then
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l * old / s, t * old / s)
	end
end

function Window:SetScale(s)
	s = ClampScale(s)
	if frame then SetScaleKeepTopLeft(s * Window:PixelFactor()) SavePos() end
	NG.Settings:Set("window.scale", s)
end

-- the size as the player sees it (1 = full size)
function Window:UserScale() return frame and frame:GetScale() / Window:PixelFactor() or ClampScale(NG.Settings:Get("window.scale")) end

---------------------------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------------------------
local function Grip()
	-- the gear on the bottom-right corner piece (measured on the art: 102, 7 from the piece's centre)
	local g = G.grip
	local b = CreateFrame("Button", nil, frame)
	b:SetSize(76, 76)
	b:SetPoint("CENTER", frame, "TOPLEFT", g[1] + 102, -(g[2] + 7))
	b:SetFrameLevel(frame:GetFrameLevel() + 40)
	local glow = b:CreateTexture(nil, "OVERLAY")
	glow:SetTexture(MEDIA .. "Glow") glow:SetBlendMode("ADD")
	glow:SetAllPoints() glow:SetVertexColor(1, 0.85, 0.4, 0)
	b.glow = glow
	local readout = W:Text(frame, 20, "header")
	readout:SetPoint("BOTTOMRIGHT", b, "TOPLEFT", 0, 0)
	readout:Hide()
	b:SetScript("OnEnter", function(self)
		if NG.Settings:Get("window.lock") then return end
		glow:SetVertexColor(1, 0.85, 0.4, 0.45)
		if _G.SetCursor then pcall(SetCursor, "UI_RESIZE_CURSOR") end
		local tt = _G.GameTooltip
		if tt then
			tt:SetOwner(self, "ANCHOR_TOPLEFT")
			tt:SetText(L["Resize"], 1, 0.86, 0.5)
			tt:AddLine(L["Drag to make the whole window bigger or smaller. Double-click for the default size."], 0.9, 0.9, 0.9, true)
			tt:Show()
		end
	end)
	b:SetScript("OnLeave", function()
		if not b.drag then glow:SetVertexColor(1, 0.85, 0.4, 0) end
		if _G.ResetCursor then pcall(ResetCursor) end
		if _G.GameTooltip then GameTooltip:Hide() end
	end)
	b:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" or NG.Settings:Get("window.lock") then return end
		local now = NG:Clock()
		if self.lastPress and now - self.lastPress < 0.35 then
			self.lastPress = nil
			Window:SetScale(Window.DEFAULT_SCALE)
			return
		end
		self.lastPress = now
		local x, y = GetCursorPosition()
		local es = UIParent:GetEffectiveScale()
		local s = frame:GetScale()
		local l, t = frame:GetLeft() * s, frame:GetTop() * s  -- UIParent units
		-- distance from the window's top-left to the cursor, at the start
		local dx, dy = x / es - l, t - y / es
		self.drag = { l = l, t = t, s = s, d = math.sqrt(dx * dx + dy * dy) }
		readout:Show()
		self:SetScript("OnUpdate", self.Drag)
	end)
	b:SetScript("OnMouseUp", function(self)
		self:SetScript("OnUpdate", nil)
		if not self.drag then return end
		self.drag = nil
		readout:Hide()
		glow:SetVertexColor(1, 0.85, 0.4, self:IsMouseOver() and 0.45 or 0)
		SavePos()
		NG.Settings:Set("window.scale", Window:UserScale())
	end)
	b.Drag = function(self)
		local d = self.drag
		if not d then self:SetScript("OnUpdate", nil) return end
		if not IsMouseButtonDown("LeftButton") then self:GetScript("OnMouseUp")(self) return end
		local x, y = GetCursorPosition()
		local es = UIParent:GetEffectiveScale()
		local dx, dy = x / es - d.l, d.t - y / es
		local dist = math.sqrt(dx * dx + dy * dy)
		local f = Window:PixelFactor()
		local user = ClampScale(d.s / f * dist / max(1, d.d))
		local s = user * f
		frame:SetScale(s)
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", d.l / s, d.t / s)
		readout:SetText(floor(user * 100 + 0.5) .. "%")
	end
	return b
end

local function ShowFlag(b, on)
	local goblin = Skin:Mode() == "goblin"
	b.flagCoin:SetShown(on and goblin)
	b.flagBar:SetShown(on and not goblin)
	b.flagGlow:SetShown(on and not goblin)
end

local function Tabs()
	local tw, tg, th = 150, 12, 50
	local gap = G.medalHalf + 26
	local left = G.midx - gap - 3 * tw - 2 * tg
	frame.tabButtons = {}
	for i, key in ipairs(order) do
		local t = tabs[key]
		local b = W:Button(frame, t.label, tw, th, { size = 22 })
		local x = i <= 3 and (left + (i - 1) * (tw + tg)) or (G.midx + gap + (i - 4) * (tw + tg))
		b.gx, b.gy = x, G.tabsY
		b:SetPoint("TOPLEFT", x, -G.tabsY)
		-- above the theme's outer border and its ornate frame (that sits at +29)
		b:SetFrameLevel(frame:GetFrameLevel() + 50)
		-- the "this tab" mark: the goblin skin tucks the bottom half of a gold coin under the
		-- tab; a theme shows a slim accent bar with a soft glow
		-- the coin lives on a frame one level under the button, so the tab overlaps it (tucked
		-- behind, not pasted over the button's bottom edge)
		local under = CreateFrame("Frame", nil, frame)
		under:SetFrameLevel(b:GetFrameLevel() - 1)
		under:SetSize(48, 24)
		under:SetPoint("TOP", b, "BOTTOM", 1, 8)   -- +1: the coin sits a hair left of centre in its texture
		local coin = under:CreateTexture(nil, "ARTWORK")
		coin:SetTexture(MEDIA .. "Coin")
		coin:SetTexCoord(0, 1, 0.5, 1)
		coin:SetAllPoints()
		local bar = b:CreateTexture(nil, "OVERLAY")
		bar:SetTexture(Skin.WHITE)
		bar:SetSize(56, 3)
		bar:SetPoint("TOP", b, "BOTTOM", 0, 1)
		Skin:Paint(bar, "accent")
		local glow = b:CreateTexture(nil, "OVERLAY", nil, -1)
		glow:SetTexture(MEDIA .. "Glow")
		glow:SetBlendMode("ADD")
		glow:SetSize(90, 22)
		glow:SetPoint("CENTER", bar, "CENTER", 0, -2)
		Skin:Paint(glow, "accent", { alpha = 0.45 })
		b.flagCoin, b.flagBar, b.flagGlow = coin, bar, glow
		b.flag = coin
		b:SetScript("OnClick", function() Window:SelectTab(key) end)
		frame.tabButtons[key] = b
	end
end

local function StatusRow()
	local P, sy = Window.P, Window.STATUS_Y
	local gold = W:Inset(frame)
	gold:SetPoint("TOPLEFT", P, -sy) gold:SetSize(214, 44)
	local gl = W:Text(gold, 16, "textDim")
	gl:SetPoint("LEFT", 12, 0) gl:SetText(L["Gold"])
	local gv = W:Text(gold, 18, "text")
	gv:SetPoint("RIGHT", -10, 0)
	frame.goldText = gv
	local vial = W:Inset(frame)
	vial:SetPoint("TOPLEFT", P + 214 + 12, -sy)
	vial:SetSize(G.w - P * 2 - 214 - 12 - 170 - 12, 44)
	local glass = vial:CreateTexture(nil, "ARTWORK")
	glass:SetTexture(MEDIA .. "Glass")
	glass:SetPoint("TOPLEFT", 8, -10) glass:SetPoint("BOTTOMLEFT", 8, 10)
	glass:SetVertexColor(0.31, 0.82, 0.24, 1)
	local back = vial:CreateTexture(nil, "BORDER")
	back:SetTexture(Skin.WHITE)
	back:SetPoint("TOPLEFT", 8, -10) back:SetPoint("BOTTOMRIGHT", -8, 10)
	back:SetVertexColor(0.08, 0.16, 0.06, 1)
	local ticks = {}
	for k = 1, 11 do
		local t = vial:CreateTexture(nil, "OVERLAY")
		t:SetTexture(Skin.WHITE) t:SetSize(1, 24)
		t:SetPoint("LEFT", 8 + (vial:GetWidth() - 16) * k / 12, 0)
		t:SetVertexColor(0.15, 0.45, 0.12, 0.8)
		ticks[k] = t
	end
	local vt = W:Text(vial, 17, "white")
	Skin:Unpaint(vt)   -- PaintVial colours it from the fill, not from a palette role
	vt:SetPoint("CENTER", 0, 0)
	vt:SetShadowOffset(1, -1)
	frame.vial, frame.vialFill, frame.vialBack, frame.vialText = vial, glass, back, vt
	local qs = W:Button(frame, L["Quick Scan"], 170, 46, { size = 20 })
	qs:SetPoint("TOPLEFT", G.w - P - 170, -(sy - 1))
	qs:SetScript("OnClick", function()
		if NG.Scan:IsRunning() then NG.Scan:Cancel("user") else NG.Scan:Start("user") end
	end)
	W:Tip(qs, L["Quick Scan"], L["Reads every item's lowest price from the auction house in one pass. It only works a few milliseconds per frame, so the game stays smooth."])
	frame.quickScan = qs
end

local function HeaderRight()
	local P = Window.P
	local close = W:Button(frame, "X", 34, 34, { size = 18 })
	local pocket = Window.POCKET_H > Window.HEADER_Y and Window.POCKET_W or 0
	close:SetPoint("TOPRIGHT", -(P + pocket), -(Window.HEADER_Y + 9))
	close:SetScript("OnClick", function() Window:Hide() end)
	W:Tip(close, L["Close"], L["Closes the auction house."])
	local gear = W:Button(frame, "", 34, 34)
	gear:SetPoint("RIGHT", close, "LEFT", -6, 0)
	local gi = gear:CreateTexture(nil, "OVERLAY")
	gi:SetTexture("Interface\\Buttons\\UI-OptionsButton") gi:SetSize(18, 18) gi:SetPoint("CENTER")
	gear:SetScript("OnClick", function() if NG.Config then NG.Config:Toggle() end end)
	W:Tip(gear, L["Settings"], L["NetherGoblin's settings."])
	local market = W:Text(frame, 18, "header")
	market:SetPoint("TOPRIGHT", gear, "TOPLEFT", -12, 4)
	local age = W:Text(frame, 15, "textDim")
	age:SetPoint("TOPRIGHT", market, "BOTTOMRIGHT", 0, -4)
	frame.marketText, frame.ageText = market, age
end

local function Art()
	-- the leather backing inside the frame
	local b = G.backing
	local back = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
	back:SetTexture(MEDIA .. "Backing")
	back:SetPoint("TOPLEFT", b[1], -b[2])
	back:SetSize(b[3], b[4])
	back:SetVertexColor(0.45, 0.43, 0.41, 1)
	frame.backing = back
	-- the frame, in tiles (never inside the window: they were cut that way)
	frame.tiles = {}
	for _, t in ipairs(G.tiles) do
		local tex = frame:CreateTexture(nil, "BORDER")
		tex:SetTexture(MEDIA .. "Frame\\" .. t[1])
		tex:SetSize(256, 256)
		tex:SetPoint("TOPLEFT", t[2], -t[3])
		frame.tiles[#frame.tiles + 1] = tex
	end
	local pl = W:Text(frame, 34, "header", "body")
	pl:SetPoint("CENTER", frame, "TOPLEFT", G.plaque[1], -G.plaque[2])
	pl:SetText("NetherGoblin")
	frame.plaqueText = pl
	-- portrait (its own frame so it sits above the frame art and can catch the mouse)
	local p = G.portrait
	local pf = CreateFrame("Frame", nil, frame)
	pf:SetSize(p[3], p[3])
	pf:SetPoint("TOPLEFT", p[1], -p[2])
	pf:SetFrameLevel(frame:GetFrameLevel() + 20)
	local pt = pf:CreateTexture(nil, "ARTWORK")
	pt:SetTexture(MEDIA .. "Portrait") pt:SetAllPoints()
	frame.portrait = pf
	-- the theme look: a full Nether window around it (as NetherSuite and Nether's own windows
	-- wear), and Nether's title plate sitting on its top edge
	local themeBack = CreateFrame("Frame", nil, frame)
	themeBack:SetPoint("TOPLEFT", -10, 10) themeBack:SetPoint("BOTTOMRIGHT", 10, -10)
	themeBack:SetFrameLevel(max(0, frame:GetFrameLevel() - 1))
	Skin:ThemeWindow(themeBack)
	local strip = CreateFrame("Frame", nil, frame)
	strip:SetSize(420, 46) strip:SetPoint("BOTTOM", frame, "TOP", 0, 2)
	-- above the window's border and its ornate frame, so no edge runs through the title
	strip:SetFrameLevel(frame:GetFrameLevel() + 45)
	Skin:ThemeTitle(strip, 26)
	frame.themeBack, frame.themeStrip = themeBack, strip
end

-- The scan bar: the goblin skin keeps its green vial; a theme fills it with its "positive"
-- colour. The text is white on a dark fill and black on a light one, each with a shadow of
-- the opposite colour, so it reads on the fill and on the empty vial alike.
local VIAL_GREEN, VIAL_BACK = { 0.31, 0.82, 0.24 }, { 0.08, 0.16, 0.06 }
local function PaintVial()
	if not (frame and frame.vialFill) then return end
	local r, g, b = VIAL_GREEN[1], VIAL_GREEN[2], VIAL_GREEN[3]
	local br, bg, bb = VIAL_BACK[1], VIAL_BACK[2], VIAL_BACK[3]
	if Skin:Mode() ~= "goblin" then
		r, g, b = Skin:Color("positive")
		br, bg, bb = Skin:Color("inset")
	end
	frame.vialFill:SetVertexColor(r, g, b, 1)
	frame.vialBack:SetVertexColor(br, bg, bb, 1)
	-- perceived brightness of the fill (sRGB linearised); the goblin green sits near 0.48,
	-- so only a pale fill (cream, pastel, near-white) flips the text to black
	local function lin(c) return c <= 0.04045 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4 end
	local lum = 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
	if lum > 0.7 then
		frame.vialText:SetTextColor(0.05, 0.04, 0.02, 1)
		frame.vialText:SetShadowColor(1, 1, 1, 0.6)
	else
		frame.vialText:SetTextColor(1, 1, 1, 1)
		frame.vialText:SetShadowColor(0, 0, 0, 0.9)
	end
end
Window.PaintVial = PaintVial

local function ApplyLook()
	if not frame then return end
	local goblin = Skin:Mode() == "goblin"
	-- the clamp and the largest size follow the look; the window is placed again inside them
	-- (switching back to the goblin skin moves it down if its crest would leave the screen)
	Clamp()
	if frame.placed then Place() end
	PaintVial()
	frame.backing:SetShown(goblin)
	for _, t in ipairs(frame.tiles) do t:SetShown(goblin) end
	frame.plaqueText:SetShown(goblin)
	-- the goblin's portrait belongs to the goblin skin: a theme window has no portrait
	frame.portrait:SetShown(goblin)
	frame.themeBack:SetShown(not goblin)
	frame.themeStrip:SetShown(not goblin)
	frame.grip:SetShown(true)
	for k, b in pairs(frame.tabButtons or {}) do
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", b.gx, goblin and -b.gy or -(G.h + 18))
		ShowFlag(b, k == Window.current)
	end
	if goblin then
		frame.portrait:ClearAllPoints()
		frame.portrait:SetPoint("TOPLEFT", G.portrait[1], -G.portrait[2])
	else
		frame.portrait:ClearAllPoints()
		frame.portrait:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", 60, -40)
	end
end
Skin:OnChange(ApplyLook)

function Window:Build()
	if frame or not self:Available() then return frame end
	frame = CreateFrame("Frame", "NetherGoblinFrame", UIParent)
	frame:SetSize(G.w, G.h)
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	Clamp()
	-- the whole backing area can be grabbed to move the window
	local b = G.backing
	frame:SetHitRectInsets(b[1], G.w - (b[1] + b[3]), b[2], G.h - (b[2] + b[4]))
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self)
		if NG.Settings:Get("window.lock") then return end
		self:StartMoving()
	end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePos()
		Place()
	end)
	frame:Hide()
	Art()
	frame.grip = Grip()
	HeaderRight()
	StatusRow()
	Tabs()
	for _, key in ipairs(order) do
		local t = tabs[key]
		local c = CreateFrame("Frame", nil, frame)
		c:SetPoint("TOPLEFT") c:SetSize(G.w, Window.STATUS_Y - 6)
		c:Hide()
		t.container = c
		NG:Safe("build tab " .. key, t.module.Build, t.module, c)
	end
	frame:SetScript("OnShow", function() Window:Refresh() end)
	frame:SetScript("OnHide", function()
		-- closing our window closes the auction house (the game's window is hidden behind it)
		if NG.House:IsOpen() and NG.House:WantOurs() then NG.House:Close() end
		if NG.Config and NG.Config.frame then NG.Config.frame:Hide() end
	end)
	if _G.UISpecialFrames then table.insert(UISpecialFrames, "NetherGoblinFrame") end
	frame.placed = true
	ApplyLook()
	self:SelectTab(self.current or order[1])
	return frame
end

function Window:AddTab(key, label, module)
	if tabs[key] then return end
	tabs[key] = { key = key, label = label, module = module }
	order[#order + 1] = key
end

function Window:SelectTab(key)
	if not (frame and tabs[key]) then self.current = key return end
	local prev = self.current and tabs[self.current]
	if prev and prev.key ~= key and prev.container then
		prev.container:Hide()
		if prev.module.OnHide then NG:Safe("tab hide", prev.module.OnHide, prev.module) end
	end
	self.current = key
	for k, b in pairs(frame.tabButtons) do
		b:SetActive(k == key)
		ShowFlag(b, k == key)
	end
	local t = tabs[key]
	t.container:Show()
	if t.module.OnShow then NG:Safe("tab show", t.module.OnShow, t.module) end
end

function Window:Show()
	if not self:Build() then return end
	frame:Show()
end

function Window:Hide() if frame then frame:Hide() end end
function Window:IsShown() return frame and frame:IsShown() or false end
function Window:Toggle() if self:IsShown() then self:Hide() else self:Show() end end

---------------------------------------------------------------------------------------------
-- Live bits: gold, the scan bar, the market label
---------------------------------------------------------------------------------------------
local statusUntil = 0
function Window:SetStatus(text, seconds)
	if not frame then return end
	frame.vialText:SetText(text or "")
	statusUntil = NG:Clock() + (seconds or 5)
end

local function Ago(sec)
	if not sec then return L["never"] end
	if sec < 90 then return L["just now"] end
	if sec < 5400 then return string.format(L["%d min ago"], floor(sec / 60 + 0.5)) end
	if sec < 172800 then return string.format(L["%d h ago"], floor(sec / 3600 + 0.5)) end
	return string.format(L["%d days ago"], floor(sec / 86400 + 0.5))
end
Window.Ago = Ago

function Window:RefreshScanBar()
	if not frame then return end
	local fullW = frame.vial:GetWidth() - 16
	if NG.Scan:IsRunning() then
		local done, received, full = NG.Scan:Progress()
		local last = NG.Scan:Last().items
		local frac = last and last > 0 and min(0.98, done / last) or (full and 0.95 or min(0.9, done / max(1, received + 500)))
		frame.vialFill:SetWidth(max(2, fullW * frac))
		frame.vialText:SetText(string.format(L["Scanning...  %s items"], _G.BreakUpLargeNumbers and BreakUpLargeNumbers(done) or done))
		frame.quickScan:SetLabel(L["Stop"])
		return
	end
	frame.quickScan:SetLabel(L["Quick Scan"])
	local last = NG.Scan:Last()
	frame.vialFill:SetWidth(last.at and fullW or 2)
	if NG:Clock() < statusUntil then return end
	if last.at then
		frame.vialText:SetText(string.format(L["Last scan %s  •  %s items  •  %s s"], Ago(NG:Now() - last.at),
			_G.BreakUpLargeNumbers and BreakUpLargeNumbers(last.items or 0) or (last.items or 0), tostring(last.seconds or 0)))
	else
		frame.vialText:SetText(L["No scan yet: press Quick Scan"])
	end
end

function Window:Refresh()
	if not frame then return end
	frame.goldText:SetText(NG.Money:Text(_G.GetMoney and GetMoney() or 0))
	frame.marketText:SetText(string.format(L["Market: %s"], NG.Prices:RealmKey() or "?"))
	local last = NG.Scan:Last()
	frame.ageText:SetText(last.at and string.format(L["Prices %s"], Ago(NG:Now() - last.at)) or L["No prices yet"])
	self:RefreshScanBar()
end

NG:On("PLAYER_MONEY", function() if frame and frame:IsShown() then frame.goldText:SetText(NG.Money:Text(GetMoney())) end end)
NG:Register("SCAN_STARTED", function() Window:RefreshScanBar() end)
NG:Register("SCAN_PROGRESS", function() if frame and frame:IsShown() then Window:RefreshScanBar() end end)
NG:Register("SCAN_CANCELLED", function(_, why)
	if not frame then return end
	Window:SetStatus(why == "search" and L["Scan stopped: your search took over the auction house."] or L["Scan stopped."], 6)
	Window:RefreshScanBar()
end)
NG:Register("SCAN_DONE", function(_, s)
	if not frame then return end
	Window:SetStatus(string.format(L["Quick scan done  •  %s items  •  %.1f s"], _G.BreakUpLargeNumbers and BreakUpLargeNumbers(s.items) or s.items, s.seconds), 8)
	Window:Refresh()
end)
NG:Register("AH_OPEN", function()
	if NG.House:WantOurs() then Window:Show() end
end)
NG:Register("AH_CLOSED", function() Window:Hide() end)
NG:Register("SETTING_CHANGED", function(_, key)
	if not frame then return end
	if key == "window.scale" or key == "window.perChar" or key == "*" then Place() end
end)
-- the screen changed size: keep the window on it
NG:On("UI_SCALE_CHANGED", function() if frame then Place() end end)
NG:On("DISPLAY_SIZE_CHANGED", function() if frame then Place() end end)
