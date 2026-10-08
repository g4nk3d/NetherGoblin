--[[ NetherGoblin - UI/Skin.lua
	The two looks, and the switch between them (live, no reload).

	  goblin   the default: brass frame, gold plates, leather panels, Philosopher / Cinzel
	  theme    "Follow NetherUI theme" on: flat panels and buttons in the colours of the
	           player's NetherUI theme, using NetherUI's own panel art (so a theme's animated
	           backgrounds, like Matrix Terminal's code rain, and its animated colour changes
	           apply here too). Without NetherUI it uses the family's "Nether Void" colours.

	Every surface asks for a ROLE, never a raw colour:
	  text, textDim, header, accent, border, ink (text on gold), positive, negative, warning,
	  info, rowA, rowB, rowSel, inset, panel

	  Skin:Mode()                    "goblin" | "theme"
	  Skin:Color(role)               r, g, b, a
	  Skin:Paint(obj, role [, kind]) colour a texture / font string by role, kept on change
	  Skin:Font(fs, kind, size)      kind: body | title | number; kept on change
	  Skin:Layers(frame)             -> goblinLayer, themeLayer: two child frames under the
	                                 frame's content; only the current look's is shown
	  Skin:ThemePanel(frame)         NetherUI's panel art on that frame (or a flat panel)
	  Skin:OnChange(fn)              after every switch / theme change ]]

local _, ns = ...
local NG = ns.NG
local Skin = NG:Module("Skin")
local WHITE = "Interface\\Buttons\\WHITE8X8"
Skin.WHITE = WHITE

local function rgb(r, g, b, a) return { r / 255, g / 255, b / 255, a or 1 } end
Skin.GOBLIN = {
	text = rgb(234, 218, 182), textDim = rgb(168, 152, 124), header = rgb(232, 196, 106),
	accent = rgb(232, 196, 106), border = rgb(150, 112, 48), ink = rgb(36, 24, 10),
	positive = rgb(130, 225, 115), negative = rgb(235, 95, 80), warning = rgb(242, 192, 84), info = rgb(120, 190, 255),
	rowA = rgb(40, 32, 24, 0.92), rowB = rgb(30, 24, 18, 0.92), rowSel = rgb(78, 58, 24, 0.98),
	inset = rgb(14, 11, 9, 0.92), panel = rgb(20, 16, 12, 0.96), white = rgb(255, 255, 255),
	great = rgb(64, 140, 60), good = rgb(48, 96, 54), fair = rgb(84, 76, 60), pricey = rgb(128, 52, 40),
}
-- the family's own colours when NetherUI is not installed ("Nether Void")
Skin.NATIVE = {
	text = { 0.92, 0.93, 0.97, 1 }, textDim = { 0.60, 0.63, 0.72, 1 }, header = { 0.95, 0.86, 0.60, 1 },
	accent = { 0.788, 0.635, 0.29, 1 }, border = { 0.11, 0.13, 0.22, 1 }, ink = { 0.92, 0.93, 0.97, 1 },
	positive = { 0.373, 0.89, 0.631, 1 }, negative = { 1, 0.365, 0.451, 1 }, warning = { 0.949, 0.757, 0.306, 1 }, info = { 0.435, 0.765, 1, 1 },
	rowA = { 0.075, 0.09, 0.165, 0.9 }, rowB = { 0.043, 0.055, 0.11, 0.9 }, rowSel = { 0.23, 0.26, 0.40, 0.95 },
	inset = { 0.02, 0.027, 0.06, 0.95 }, panel = { 0.043, 0.055, 0.11, 0.95 }, white = { 1, 1, 1, 1 },
	great = { 0.20, 0.50, 0.30, 1 }, good = { 0.16, 0.36, 0.26, 1 }, fair = { 0.24, 0.26, 0.34, 1 }, pricey = { 0.50, 0.18, 0.22, 1 },
}
-- our roles in NetherUI's palette
local FROM_THEME = { rowA = "bgAlt", rowB = "bg", rowSel = "accentSoft", inset = "bgInset", panel = "bg", ink = "text" }

local function NetherUI()
	local A = rawget(_G, "NetherUI")
	if type(A) == "table" and type(A.palette) == "table" and type(A.palette.bg) == "table" then return A end
	return nil
end
Skin.NetherUI = NetherUI

function Skin:Mode()
	return NG.Settings:Get("skin.followTheme") and "theme" or "goblin"
end

-- How much of NetherUI the theme look takes: "full" (Nether's whole window: ornate frame,
-- title plate, button art, raised panels and wells, as NetherSuite wears) or "minimal" (flat
-- theme panels and colours). Only matters in the theme look, and only with NetherUI there.
function Skin:Style()
	return NG.Settings:Get("skin.themeStyle") == "minimal" and "minimal" or "full"
end

-- a pair of frames for one theme piece: [1] the full style, [2] the minimal one; shown by style
local pairsList = {}
local function StylePair(frame)
	local full = CreateFrame("Frame", nil, frame)
	full:SetAllPoints() full:SetFrameLevel(frame:GetFrameLevel())
	local min = CreateFrame("Frame", nil, frame)
	min:SetAllPoints() min:SetFrameLevel(frame:GetFrameLevel())
	frame.styleFull, frame.styleMin = full, min
	pairsList[#pairsList + 1] = { full, min }
	local isFull = Skin:Style() == "full"
	full:SetShown(isFull) min:SetShown(not isFull)
	return full, min
end

function Skin:Color(role)
	if self:Mode() == "goblin" then
		local c = self.GOBLIN[role] or self.GOBLIN.text
		return c[1], c[2], c[3], c[4] or 1
	end
	local A = NetherUI()
	if A then
		local key = FROM_THEME[role] or role
		local c = A.palette[key]
		if type(c) == "table" then
			local a = c[4] or 1
			if role == "rowA" or role == "rowB" then a = math.min(a, 0.9) end
			if role == "great" or role == "good" or role == "fair" or role == "pricey" then
				-- badges: the theme's state colours, darkened to sit behind light text
				local src = (role == "pricey" and A.palette.negative) or (role == "fair" and A.palette.bgAlt) or A.palette.positive
				if type(src) == "table" then
					local m = role == "great" and 0.55 or role == "good" and 0.4 or role == "fair" and 1 or 0.55
					return (src[1] or 0) * m, (src[2] or 0) * m, (src[3] or 0) * m, 1
				end
			end
			return c[1] or 1, c[2] or 1, c[3] or 1, a
		end
	end
	local c = self.NATIVE[role] or self.NATIVE.text
	return c[1], c[2], c[3], c[4] or 1
end

---------------------------------------------------------------------------------------------
-- Painted objects, re-painted on every change
---------------------------------------------------------------------------------------------
local painted = setmetatable({}, { __mode = "k" })
local fonts = setmetatable({}, { __mode = "k" })
local layers = setmetatable({}, { __mode = "k" })
local listeners = {}

local function Apply(obj, e)
	local r, g, b, a = Skin:Color(e.role)
	if e.alpha then a = a * e.alpha end
	if e.mul then r, g, b = r * e.mul, g * e.mul, b * e.mul end
	local kind = obj.GetObjectType and obj:GetObjectType()
	if kind == "FontString" or kind == "EditBox" then obj:SetTextColor(r, g, b, a)
	elseif obj.SetVertexColor then obj:SetVertexColor(r, g, b, a) end
end

function Skin:Paint(obj, role, opts)
	if not obj then return obj end
	local e = { role = role, alpha = opts and opts.alpha, mul = opts and opts.mul }
	painted[obj] = e
	Apply(obj, e)
	return obj
end

function Skin:Unpaint(obj) painted[obj] = nil end

local function FontFile(kind)
	if Skin:Mode() == "theme" then
		local A = NetherUI()
		if A and type(A.fonts) == "table" then
			local p = A.fonts[kind == "title" and "header" or "body"] or A.fonts.body
			if type(p) == "string" then return p end
		end
	end
	return kind == "title" and NG.FONT_TITLE or NG.FONT_BODY
end

local function ApplyFont(fs, f)
	local ok = pcall(fs.SetFont, fs, FontFile(f.kind), f.size, f.flags or "")
	if not ok or (fs.GetFont and not fs:GetFont()) then
		pcall(fs.SetFont, fs, _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", f.size, f.flags or "")
	end
	fs:SetShadowOffset(1, -1)
	fs:SetShadowColor(0, 0, 0, Skin:Mode() == "goblin" and 0.9 or 0.8)
end

function Skin:Font(fs, kind, size, flags)
	if not fs then return fs end
	local f = { kind = kind or "body", size = size or 14, flags = flags }
	fonts[fs] = f
	ApplyFont(fs, f)
	return fs
end

function Skin:SetFontSize(fs, size)
	local f = fonts[fs]
	if f then f.size = size ApplyFont(fs, f) end
end

-- two child frames (goblin art / theme art) under a frame's content
function Skin:Layers(frame, level)
	local g = CreateFrame("Frame", nil, frame)
	g:SetAllPoints()
	g:SetFrameLevel(math.max(0, frame:GetFrameLevel() + (level or 0)))
	local t = CreateFrame("Frame", nil, frame)
	t:SetAllPoints()
	t:SetFrameLevel(math.max(0, frame:GetFrameLevel() + (level or 0)))
	layers[frame] = { g = g, t = t }
	local goblin = self:Mode() == "goblin"
	g:SetShown(goblin)
	t:SetShown(not goblin)
	return g, t
end

-- NetherUI's integration kit: the same panel art its own windows (and NetherSuite) wear,
-- PRISM-aware, re-coloured on every theme switch
local kitRec
local function Kit()
	local A = NetherUI()
	local I = A and A.Integrations
	if not (I and I.Kit and I.Kit.New) then return nil end
	if not kitRec then kitRec = I.Kit:New("nethergoblin") end
	return kitRec
end
Skin.Kit = Kit

-- A full Nether window around frame: drop shadow, chamfered fill, arcane weave, inner and
-- outer borders, the corner accent or the ornate frame ("Ornate window frames"), and the
-- Spectrum edge on the RGB themes. Returns true when NetherUI drew it.
function Skin:ThemeWindow(frame)
	local rec, A = Kit(), NetherUI()
	if not rec then self:FlatPanel(frame) return false end
	local full, min = StylePair(frame)
	local ok = pcall(rec.Panel, rec, full, { ornate = true })
	if ok and A.Spectrum and A.Spectrum.Register then pcall(A.Spectrum.Register, A.Spectrum, full) end
	if not ok then self:FlatPanel(full) end
	self:FlatPanel(min)
	return ok
end

-- The window's title plate, as on Nether's own windows: the plate art with its gradient and
-- accent border, the name in two theme colours ("Nether" accent, "Goblin" gem).
local function PlainTitle(plate, size)
	Skin:FlatPanel(plate)
	local st = plate:CreateFontString(nil, "OVERLAY")
	Skin:Font(st, "title", size)
	Skin:Paint(st, "header")
	st:SetPoint("CENTER") st:SetText("NetherGoblin")
end

function Skin:ThemeTitle(frame, size)
	local A = NetherUI()
	if not (A and type(A.Art) == "function" and A.Theme and A.Theme.RegisterGradient) then PlainTitle(frame, size) return false end
	local plate, min = StylePair(frame)
	PlainTitle(min, size)
	do
		local fill = plate:CreateTexture(nil, "ARTWORK")
		fill:SetAllPoints()
		local okA = pcall(A.Art, A, fill, "TitleBar", "white")
		if okA then
			pcall(A.Theme.RegisterGradient, A.Theme, fill, "titlePlate", "VERTICAL")
			local edge = plate:CreateTexture(nil, "OVERLAY")
			edge:SetAllPoints()
			pcall(A.Art, A, edge, "TitleBar_Border", "accent")
			local font = A.BRAND_FONT or NG.FONT_BODY
			local a = plate:CreateFontString(nil, "OVERLAY")
			local b = plate:CreateFontString(nil, "OVERLAY")
			for _, fs in ipairs({ a, b }) do
				if not pcall(fs.SetFont, fs, font, size, "") then fs:SetFont(NG.FONT_BODY, size, "") end
				fs:SetShadowColor(0, 0, 0, 0.8) fs:SetShadowOffset(1, -1)
			end
			a:SetText("Nether") b:SetText("Goblin")
			local wa, wb = a:GetStringWidth() or 0, b:GetStringWidth() or 0
			a:SetPoint("LEFT", plate, "CENTER", -(wa + wb) / 2, 1)
			b:SetPoint("LEFT", a, "RIGHT", 0, 0)
			if A.Theme.Register then
				pcall(A.Theme.Register, A.Theme, a, "accent")
				pcall(A.Theme.Register, A.Theme, b, "gem")
			end
			return true
		end
		PlainTitle(plate, size)
	end
	return false
end

-- NetherUI's own panel art (theme colours, animated effects), or a flat panel without it.
-- Inner panels and wells come from the kit like NetherSuite's (a raised small panel, or an
-- inset well with fillRole "bgInset").
function Skin:ThemePanel(frame, opts)
	local rec = Kit()
	if not rec then return self:FlatPanel(frame, opts) end
	local full, min = StylePair(frame)
	local inset = opts and opts.fillRole == "bgInset"
	local ok, p = pcall(rec.Panel, rec, full, inset and { inset = true, alpha = 0.9 } or { small = true })
	if not ok then self:FlatPanel(full, opts) end
	return self:FlatPanel(min, opts)
end

-- the minimal look: NetherUI's plain panel textures (theme colours), or a flat panel
function Skin:FlatPanel(frame, opts)
	local A = NetherUI()
	if A and type(A.PanelTextures) == "function" then
		local ok, p = pcall(A.PanelTextures, A, frame, opts)
		if ok and p then return p end
	end
	local fill = frame:CreateTexture(nil, "BACKGROUND")
	fill:SetAllPoints()
	fill:SetTexture(WHITE)
	self:Paint(fill, (opts and opts.fillRole) == "bgInset" and "inset" or "panel")
	local edges = {}
	for i, pts in ipairs({ { "TOPLEFT", "TOPRIGHT", 0, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, 1 }, { "TOPLEFT", "BOTTOMLEFT", 1, 0 }, { "TOPRIGHT", "BOTTOMRIGHT", 1, 0 } }) do
		local e = frame:CreateTexture(nil, "BORDER")
		e:SetTexture(WHITE)
		e:SetPoint(pts[1]) e:SetPoint(pts[2])
		if pts[3] == 1 then e:SetWidth(1) else e:SetHeight(1) end
		self:Paint(e, i <= 2 and "accent" or "border", { alpha = 0.8 })
		edges[i] = e
	end
	return { fill = fill, edges = edges }
end

function Skin:OnChange(fn) listeners[#listeners + 1] = fn end

function Skin:Refresh()
	local goblin = self:Mode() == "goblin"
	local isFull = self:Style() == "full"
	for _, pr in ipairs(pairsList) do pr[1]:SetShown(isFull) pr[2]:SetShown(not isFull) end
	for frame, l in pairs(layers) do
		l.g:SetShown(goblin)
		l.t:SetShown(not goblin)
	end
	for obj, e in pairs(painted) do Apply(obj, e) end
	for fs, f in pairs(fonts) do ApplyFont(fs, f) end
	for _, fn in ipairs(listeners) do NG:Safe("skin change", fn, self:Mode()) end
	NG:Fire("SKIN_CHANGED", self:Mode())
end

NG:Register("SETTING_CHANGED", function(_, key)
	if key == "skin.followTheme" or key == "skin.themeStyle" or key == "skin.portraitInTheme" or key == "*" then Skin:Refresh() end
end)

-- NetherUI's theme switches: repaint (only matters in the theme look)
NG:Register("LOGIN", function()
	local A = NetherUI()
	if A and type(A.RegisterCallback) == "function" then
		pcall(A.RegisterCallback, A, "THEME_CHANGED", function()
			if Skin:Mode() == "theme" then NG:Debounce("theme", 0.05, function() Skin:Refresh() end) end
		end)
	end
end)
