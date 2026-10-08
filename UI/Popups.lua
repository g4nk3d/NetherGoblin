--[[ NetherGoblin - UI/Popups.lua
	The goblin talks: his portrait beside the parchment speech bubble. Two separate windows.

	Scan Complete window (lower half of the screen, middle; movable in Edit Mode):
	  a random headline picked by what the scan found (Locales/enUS.lua), the scan's real
	  numbers, a sign-off. Waits out combat; fades after "popup.seconds" (hovering pauses,
	  clicking closes); "ka-ching" unless switched off; jokes can be switched off (facts only).
	  Clicking the undercut line opens the Undercuts tab (or, with the auction house closed, a
	  read-only list of the undercut auctions).

	Compatibility window (middle of the screen; movable in Edit Mode): anything that needs an
	answer, with up to three buttons (for example Disable + Reload). It stays until answered.
	  Popups:Ask({ title, text, buttons = { { label, fn [, primary] } } })   queued, one at a time

	In the theme look the parchment becomes a theme panel; the portrait stays when
	"skin.portraitInTheme" is on. ]]

local _, ns = ...
local NG = ns.NG
local Popups = NG:Module("Popups")
local W, Skin = NG.Widgets, NG.Skin
local L = ns.L
local G = ns.GEOMETRY
local floor, max, min = math.floor, math.max, math.min
local MEDIA = NG.MEDIA

local INK = { 0.15, 0.10, 0.04 }

-- one popup: portrait + bubble; returns the frame and its text area
local function Make(name, portraitSize, bubbleW)
	local B = G.bubble
	local bubbleH = floor(bubbleW / B.aspect + 0.5)
	local f = CreateFrame("Frame", name, UIParent)
	local overlap = floor(portraitSize * 0.12)
	f:SetSize(portraitSize + bubbleW - overlap, max(portraitSize, bubbleH))
	f:SetFrameStrata("DIALOG")
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:Hide()
	local port = CreateFrame("Frame", nil, f)
	port:SetSize(portraitSize, portraitSize)
	port:SetPoint("LEFT", 0, 0)
	port:SetFrameLevel(f:GetFrameLevel() + 5)
	local pt = port:CreateTexture(nil, "ARTWORK")
	pt:SetTexture(MEDIA .. "Portrait") pt:SetAllPoints()
	local bubble = CreateFrame("Frame", nil, f)
	bubble:SetSize(bubbleW, bubbleH)
	bubble:SetPoint("LEFT", port, "RIGHT", -overlap, 0)
	local g, t = Skin:Layers(bubble, 0)
	local bt = g:CreateTexture(nil, "ARTWORK")
	bt:SetTexture(MEDIA .. "Bubble") bt:SetAllPoints()
	local inner = CreateFrame("Frame", nil, t)
	inner:SetPoint("TOPLEFT", bubbleW * 0.11, -bubbleH * 0.14)
	inner:SetPoint("BOTTOMRIGHT", -bubbleW * 0.04, bubbleH * 0.12)
	Skin:ThemePanel(inner)
	-- the parchment area, where the text goes
	local area = CreateFrame("Frame", nil, bubble)
	area:SetPoint("TOPLEFT", bubbleW * B.text[1], -bubbleH * B.text[2])
	area:SetPoint("BOTTOMRIGHT", -(bubbleW * (1 - B.text[3])), bubbleH * (1 - B.text[4]))
	area:SetFrameLevel(bubble:GetFrameLevel() + 5)
	f.port, f.bubble, f.area = port, bubble, area
	f.fontStrings = {}
	return f
end

-- text colour on the parchment (dark ink) or on a theme panel (the theme's colour)
local function InkText(f, fs, role)
	f.fontStrings[fs] = role or "ink"
end
local function Recolour(f)
	local goblin = Skin:Mode() == "goblin"
	for fs, role in pairs(f.fontStrings) do
		if goblin then
			fs:SetTextColor(INK[1], INK[2], INK[3], 1)
			fs:SetShadowColor(0, 0, 0, 0)
		else
			fs:SetTextColor(Skin:Color(role == "ink" and "text" or "header"))
			fs:SetShadowColor(0, 0, 0, 0.8)
		end
	end
	f.port:SetShown(goblin or NG.Settings:Get("skin.portraitInTheme"))
end

---------------------------------------------------------------------------------------------
-- Positions (each window its own; Edit Mode moves them)
---------------------------------------------------------------------------------------------
local function Store(key)
	NG.db.popups = NG.db.popups or {}
	return NG.db.popups, key
end

local function Place(f, key, defaultY)
	local db = Store(key)
	local p = db[key]
	f:ClearAllPoints()
	if p and p.x and p.y then
		f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", p.x, p.y)
	else
		f:SetPoint("CENTER", UIParent, "CENTER", 0, defaultY())
	end
end

local function SavePlace(f, key)
	local x, y = f:GetCenter()
	if not (x and y) then return end
	local s = f:GetScale()
	local db = Store(key)
	db[key] = { x = floor(x * s + 0.5), y = floor(y * s + 0.5) }
end

-- the lower half's middle: centre about 28% up from the bottom
local function LowerMiddle() return -(UIParent:GetHeight() * 0.22) end
local function Middle() return UIParent:GetHeight() * 0.06 end

---------------------------------------------------------------------------------------------
-- Scan Complete window
---------------------------------------------------------------------------------------------
local scan
local recentQuips = {}

local function Pick(pool)
	local list = ns.QUIPS[pool] or ns.QUIPS.normal
	local seen = {}
	for _, q in ipairs(NG.db and NG.db.recentQuips or recentQuips) do seen[q] = true end
	local choices = {}
	for _, q in ipairs(list) do if not seen[q] then choices[#choices + 1] = q end end
	if #choices == 0 then choices = list end
	local q = choices[math.random(#choices)]
	local rq = NG.db and NG.db.recentQuips or recentQuips
	if NG.db then NG.db.recentQuips = rq end
	table.insert(rq, 1, q)
	for i = #rq, 11, -1 do rq[i] = nil end
	return q
end

local function PoolFor(s)
	if (s.undercut or 0) > 0 then return "undercut" end
	if (s.deals or 0) > 0 then return "deals" end
	if (s.seconds or 99) < 10 then return "fast" end
	if (s.seconds or 0) > 60 then return "slow" end
	if (s.changed or 1) == 0 then return "quiet" end
	return "normal"
end

local function Big(n) return _G.BreakUpLargeNumbers and BreakUpLargeNumbers(n) or tostring(n) end

function Popups:BuildScan()
	if scan then return scan end
	scan = Make("NetherGoblinScanPopup", 168, 430)
	local a = scan.area
	local head = a:CreateFontString(nil, "OVERLAY")
	Skin:Font(head, "body", 19)
	head:SetPoint("TOPLEFT") head:SetPoint("TOPRIGHT")
	head:SetJustifyH("CENTER") head:SetWordWrap(true)
	InkText(scan, head)
	scan.head = head
	scan.lines = {}
	for i = 1, 5 do
		local b = CreateFrame("Button", nil, a)
		b:SetHeight(19)
		b:SetPoint("LEFT") b:SetPoint("RIGHT")
		local fs = b:CreateFontString(nil, "OVERLAY")
		Skin:Font(fs, "body", 15)
		fs:SetAllPoints() fs:SetJustifyH("CENTER")
		InkText(scan, fs)
		b.fs = fs
		b:SetScript("OnClick", function(self) if self.onClick then self.onClick() end Popups:HideScan() end)
		b:SetScript("OnEnter", function(self) scan.hover = true if self.onClick then self.fs:SetAlpha(0.75) end end)
		b:SetScript("OnLeave", function(self) scan.hover = false self.fs:SetAlpha(1) end)
		scan.lines[i] = b
	end
	scan:SetScript("OnEnter", function() scan.hover = true end)
	scan:SetScript("OnLeave", function() scan.hover = false end)
	scan:SetScript("OnMouseUp", function(_, button) if not Popups.editing and button == "LeftButton" then Popups:HideScan() end end)
	scan:SetScript("OnUpdate", function(self, el)
		if Popups.editing then return end
		if self.fadeIn then
			self.fadeIn = self.fadeIn + el
			self:SetAlpha(min(1, self.fadeIn / 0.25))
			if self.fadeIn >= 0.25 then self.fadeIn = nil end
			return
		end
		if self.hover then return end
		self.left = (self.left or 0) - el
		if self.left <= 0 then
			local a = self:GetAlpha() - el / 0.6
			if a <= 0 then self:Hide() else self:SetAlpha(a) end
		end
	end)
	Place(scan, "scan", LowerMiddle)
	Recolour(scan)
	return scan
end

function Popups:HideScan() if scan and not self.editing then scan:Hide() end end

local function Layout(f, head, lines)
	local y = 0
	head:SetWidth(f.area:GetWidth())
	y = (head:GetStringHeight() or 20) + 8
	for _, b in ipairs(lines) do
		if b:IsShown() then
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", 0, -y) b:SetPoint("TOPRIGHT", 0, -y)
			y = y + 20
		end
	end
	-- centre the block vertically on the parchment
	local pad = max(0, (f.area:GetHeight() - y) / 2)
	head:ClearAllPoints()
	head:SetPoint("TOPLEFT", 0, -pad) head:SetPoint("TOPRIGHT", 0, -pad)
	local yy = pad + (head:GetStringHeight() or 20) + 8
	for _, b in ipairs(lines) do
		if b:IsShown() then
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", 0, -yy) b:SetPoint("TOPRIGHT", 0, -yy)
			yy = yy + 20
		end
	end
end

function Popups:ShowScan(s)
	if not NG.Settings:Get("popup.scan") then return end
	if NG:InCombat() then
		return NG:AfterCombat("scan popup", function() Popups:ShowScan(s) end)
	end
	local f = self:BuildScan()
	local quips = NG.Settings:Get("popup.quips")
	f.head:SetText(quips and Pick(PoolFor(s)) or L["Scan complete."])
	local facts = {}
	facts[#facts + 1] = { string.format(L["%s prices updated in %s."], Big(s.items or 0),
		(s.seconds or 0) < 60 and string.format(L["%.1f seconds"], s.seconds or 0) or string.format(L["%d min %d s"], floor(s.seconds / 60), floor(s.seconds % 60))) }
	if (s.newLows or 0) > 0 then facts[#facts + 1] = { string.format(L["%s items hit a new %d-day low."], Big(s.newLows), tonumber(NG.Settings:Get("history.days")) or 30) } end
	if (s.undercut or 0) > 0 then
		facts[#facts + 1] = { string.format(L["You've been undercut on %d auctions: |cff8a1a10see them|r"], s.undercut), function() Popups:OpenUndercuts() end }
	end
	if (s.deals or 0) > 0 then
		facts[#facts + 1] = { string.format(L["%s great deals waiting in Buy: |cff8a1a10take a look|r"], Big(s.deals)), function() Popups:OpenBuy() end }
	end
	if quips then facts[#facts + 1] = { Pick("signoff") } end
	for i, b in ipairs(f.lines) do
		local fct = facts[i]
		b:SetShown(fct ~= nil)
		if fct then b.fs:SetText(fct[1]) b.onClick = fct[2] end
	end
	Recolour(f)
	Layout(f, f.head, f.lines)
	f.left = tonumber(NG.Settings:Get("popup.seconds")) or 8
	f.fadeIn = 0
	f:SetAlpha(0)
	f.hover = false
	f:Show()
	if NG.Settings:Get("popup.sound") then
		local kit = _G.SOUNDKIT and (SOUNDKIT.LOOT_WINDOW_COIN_SOUND or SOUNDKIT.MONEY_FRAME_CLOSE)
		if kit and _G.PlaySound then pcall(PlaySound, kit, "SFX") end
	end
end

-- the Buy tab, when the auction house is open (the deals need live listings)
function Popups:OpenBuy()
	if NG.House:IsOpen() and NG.Window:IsShown() then NG.Window:SelectTab("buy") end
end

function Popups:OpenUndercuts()
	if NG.House:IsOpen() and NG.Window:IsShown() then
		NG.Window:SelectTab("undercuts")
		return
	end
	-- the auction house is closed: a read-only list
	local lines = {}
	for _, a in ipairs(NG.Owned:List()) do
		if a.undercut and not a.sold then
			lines[#lines + 1] = string.format("%s  %s", a.name or "?", a.unit and NG.Money:Text(a.unit, { plain = true, short = true }) or "")
			if #lines >= 6 then break end
		end
	end
	self:Ask({ title = L["Your undercut auctions"], text = (#lines > 0 and table.concat(lines, "\n") or L["None right now."]) .. "\n\n" .. L["Cancel and repost them at the auction house."],
		buttons = { { L["OK"], nil, true } } })
end

NG:Register("SCAN_DONE", function(_, s) Popups:ShowScan(s) end)

---------------------------------------------------------------------------------------------
-- Compatibility window
---------------------------------------------------------------------------------------------
local ask
local queue = {}

function Popups:BuildAsk()
	if ask then return ask end
	ask = Make("NetherGoblinCompatPopup", 190, 520)
	local a = ask.area
	local title = a:CreateFontString(nil, "OVERLAY")
	Skin:Font(title, "title", 18)
	title:SetPoint("TOPLEFT") title:SetPoint("TOPRIGHT") title:SetJustifyH("CENTER")
	InkText(ask, title, "header")
	local text = a:CreateFontString(nil, "OVERLAY")
	Skin:Font(text, "body", 15)
	text:SetPoint("TOPLEFT", 0, -28) text:SetPoint("TOPRIGHT", 0, -28)
	text:SetJustifyH("CENTER") text:SetJustifyV("TOP") text:SetWordWrap(true)
	InkText(ask, text)
	ask.title, ask.text = title, text
	ask.buttons = {}
	for i = 1, 3 do
		local b = W:Button(a, "", 120, 32, { size = 15 })
		b:SetScript("OnClick", function(self)
			local fn = self.fn
			ask:Hide()
			if fn then NG:Safe("popup answer", fn) end
			Popups:NextAsk()
		end)
		ask.buttons[i] = b
	end
	Place(ask, "compat", Middle)
	return ask
end

function Popups:Ask(spec)
	queue[#queue + 1] = spec
	if not (ask and ask:IsShown()) then self:NextAsk() end
end

function Popups:NextAsk()
	if self.editing then return end
	local spec = table.remove(queue, 1)
	if not spec then return end
	local f = self:BuildAsk()
	f.title:SetText(spec.title or "NetherGoblin")
	f.text:SetText(spec.text or "")
	local n = #(spec.buttons or {})
	local aw = f.area:GetWidth()
	local bw = n > 0 and min(170, floor((aw - (n - 1) * 8) / n)) or 0
	for i, b in ipairs(f.buttons) do
		local s = spec.buttons and spec.buttons[i]
		b:SetShown(s ~= nil)
		if s then
			b:SetLabel(s[1])
			b.fn = s[2]
			b.primary = s[3]
			b:SetActive(s[3] and true or false)
			b:SetWidth(bw)
			b:ClearAllPoints()
			b:SetPoint("BOTTOMLEFT", f.area, "BOTTOM", -(n * bw + (n - 1) * 8) / 2 + (i - 1) * (bw + 8), 0)
		end
	end
	Recolour(f)
	f:SetAlpha(1)
	f:Show()
end

---------------------------------------------------------------------------------------------
-- Edit Mode: both windows show a sample and can be dragged; positions saved on exit
---------------------------------------------------------------------------------------------
local function Mover(f, key, label)
	local m = CreateFrame("Frame", nil, f)
	m:SetAllPoints()
	m:SetFrameLevel(f:GetFrameLevel() + 40)
	local bg = m:CreateTexture(nil, "OVERLAY")
	bg:SetTexture(Skin.WHITE) bg:SetAllPoints() bg:SetVertexColor(0.3, 0.6, 1, 0.18)
	W.Edges(m, "OVERLAY", 2)
	local t = m:CreateFontString(nil, "OVERLAY")
	Skin:Font(t, "body", 15) t:SetPoint("BOTTOM", m, "TOP", 0, 4) t:SetText(label) t:SetTextColor(0.6, 0.85, 1)
	m:EnableMouse(true)
	m:SetScript("OnMouseDown", function(_, b) if b == "LeftButton" then f:StartMoving() end end)
	m:SetScript("OnMouseUp", function(_, b)
		f:StopMovingOrSizing()
		if b == "RightButton" then
			local db = Store(key) db[key] = nil
			Place(f, key, key == "scan" and LowerMiddle or Middle)
		else
			SavePlace(f, key)
		end
	end)
	m:Hide()
	return m
end

function Popups:EnterEditMode()
	self.editing = true
	local s = self:BuildScan()
	local a = self:BuildAsk()
	s.mover = s.mover or Mover(s, "scan", L["NetherGoblin: Scan Complete window (drag; right-click resets)"])
	a.mover = a.mover or Mover(a, "compat", L["NetherGoblin: Compatibility window (drag; right-click resets)"])
	if not s:IsShown() then
		s.head:SetText(L["Ka-ching! Scan's done, boss."])
		for i, b in ipairs(s.lines) do b:SetShown(i <= 2) end
		s.lines[1].fs:SetText(L["2,314 prices updated in 4.1 seconds."]) s.lines[2].fs:SetText(L["In gold we trust!"])
		Recolour(s)
		Layout(s, s.head, s.lines)
	end
	s:SetAlpha(1) s:Show() s.mover:Show()
	if not a:IsShown() then
		a.title:SetText(L["Compatibility"])
		a.text:SetText(L["Questions from NetherGoblin appear here."])
		for _, b in ipairs(a.buttons) do b:Hide() end
		Recolour(a)
		a.sample = true
	end
	a:Show() a.mover:Show()
end

function Popups:ExitEditMode()
	self.editing = false
	if scan then scan.mover:Hide() scan:Hide() end
	if ask then
		ask.mover:Hide()
		if ask.sample then ask.sample = nil ask:Hide() end
	end
	self:NextAsk()
end

function Popups:ResetPositions()
	if NG.db then NG.db.popups = nil end
	if scan then Place(scan, "scan", LowerMiddle) end
	if ask then Place(ask, "compat", Middle) end
end

NG:Register("LOGIN", function()
	local ER = _G.EventRegistry
	if ER and ER.RegisterCallback then
		pcall(ER.RegisterCallback, ER, "EditMode.Enter", function() Popups:EnterEditMode() end, Popups)
		pcall(ER.RegisterCallback, ER, "EditMode.Exit", function() Popups:ExitEditMode() end, Popups)
	end
end)
Skin:OnChange(function() if scan then Recolour(scan) end if ask then Recolour(ask) end end)
