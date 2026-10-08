--[[ NetherGoblin - UI/Widgets.lua
	The pieces every screen is built from, each wearing both looks (UI/Skin.lua).

	  W:Text(parent, size, role [, kind])            font string
	  W:Button(parent, label, w, h [, opts])         gold plate / theme button
	      opts: { primary, small, onClick, tip = { title, text } }
	      b:SetLabel(s), b:SetActive(on), b:SetEnabled(on)
	  W:Panel(parent, tex)                           leather panel (tex "A" | "B" | "C") / theme
	  W:Inset(parent)                                dark inset box
	  W:Edit(parent, w, h, hint [, opts])            text box: opts.onEnter, opts.onChange, opts.numeric
	  W:MoneyBox(parent)                             gold / silver / copper boxes: :Get(), :Set(c)
	  W:Icon(parent, size)                           item icon with rarity edge: :SetItem(icon, quality);
	                                                 quality false = not an item (border-coloured edge)
	  W:Badge(parent, w, h)                          pill: :Set(text, role)
	  W:List(parent, w, h, rowH, make, fill)         virtual list: :SetData(t), :Refresh(), :Top()
	  W:Check(parent, label, get, set [, tip])
	  W:Slider(parent, label, min, max, step, get, set [, fmt])
	  W:Choice(parent, label, options, get, set)     options = { { value, text } }
	  W:Tip(owner, title, ...)                       a tooltip on hover ]]

local _, ns = ...
local NG = ns.NG
local W = NG:Module("Widgets")
local Skin = NG.Skin
local WHITE = Skin.WHITE
local MEDIA = NG.MEDIA
local floor, max, min = math.floor, math.max, math.min

local buttons = setmetatable({}, { __mode = "k" })

function W:Text(parent, size, role, kind, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	Skin:Font(fs, kind or "body", size or 14)
	Skin:Paint(fs, role or "text")
	fs:SetWordWrap(false)
	return fs
end

function W:Tip(owner, title, ...)
	local lines = { ... }
	owner:HookScript("OnEnter", function(self)
		local tt = _G.GameTooltip
		if not tt then return end
		tt:SetOwner(self, "ANCHOR_RIGHT")
		tt:SetText(type(title) == "function" and title() or title, 1, 0.86, 0.5)
		for _, l in ipairs(lines) do
			local s = type(l) == "function" and l() or l
			if s then tt:AddLine(s, 0.9, 0.9, 0.9, true) end
		end
		tt:Show()
	end)
	owner:HookScript("OnLeave", function() if _G.GameTooltip then GameTooltip:Hide() end end)
end

---------------------------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------------------------
-- Media/Button.tga: 128 x 128, normal plate rows 0-48, active rows 64-112, caps 20 px wide
local CAP_U, ROW = 20 / 128, { normal = { 0, 48 / 128 }, active = { 64 / 128, 112 / 128 } }

-- Nether's own button art for the theme look (fill + border, the same textures as
-- NetherUI_ButtonTemplate), when NetherUI is there
local ButtonLook
local function NetherButton(b)
	local A = Skin.NetherUI()
	if b.nb ~= nil then return b.nb end
	b.nb = false
	if not (A and type(A.Art) == "function" and A.Theme and A.Theme.SetRole) then return false end
	local fill = b:CreateTexture(nil, "BACKGROUND", nil, 1)
	fill:SetAllPoints()
	local edge = b:CreateTexture(nil, "BORDER", nil, 1)
	edge:SetAllPoints()
	if not (pcall(A.Art, A, fill, "Button_Normal", "button") and pcall(A.Art, A, edge, "Button_UI_Border", "borderHighlight")) then
		fill:Hide() edge:Hide()
		return false
	end
	b.nb = { fill = fill, edge = edge, A = A }
	b:HookScript("OnEnter", function(self) self.hover = true ButtonLook(self) end)
	b:HookScript("OnLeave", function(self) self.hover = false ButtonLook(self) end)
	return b.nb
end

function ButtonLook(b)
	local goblin = Skin:Mode() == "goblin"
	local row = (b.active or b.primary) and ROW.active or ROW.normal
	local nb = NetherButton(b)
	for _, t in ipairs(b.gob) do t:SetShown(goblin) end
	local full = nb and Skin:Style() == "full"
	for _, t in ipairs(b.thm) do t:SetShown(not goblin and not full) end
	if nb then
		nb.fill:SetShown(not goblin and full) nb.edge:SetShown(not goblin and full)
		if not goblin and full then
			local on, enabled = b.active or b.primary, b:IsEnabled()
			pcall(nb.A.Art, nb.A, nb.fill, (b.hover and enabled) and "Button_Hover" or "Button_Normal", "button")
			pcall(nb.A.Theme.SetRole, nb.A.Theme, nb.edge, (on or (b.hover and enabled)) and "accent" or "borderHighlight", true)
			nb.fill:SetAlpha(enabled and 1 or 0.5) nb.edge:SetAlpha(enabled and 1 or 0.5)
		end
	end
	b.gob[1]:SetTexCoord(0, CAP_U, row[1], row[2])
	b.gob[2]:SetTexCoord(CAP_U, 1 - CAP_U, row[1], row[2])
	b.gob[3]:SetTexCoord(1 - CAP_U, 1, row[1], row[2])
	local enabled = b:IsEnabled()
	for _, t in ipairs(b.gob) do
		if t.SetDesaturated then t:SetDesaturated(not enabled) end
		t:SetAlpha(enabled and 1 or 0.55)
	end
	Skin:Paint(b.thmFill, (b.active or b.primary) and "rowSel" or "rowA")
	Skin:Paint(b.thmEdge[1], (b.active or b.primary) and "accent" or "border")
	Skin:Paint(b.label, goblin and "ink" or ((b.active or b.primary) and "header" or "text"), { alpha = enabled and 1 or 0.5 })
	b.label:SetShadowColor(0, 0, 0, goblin and 0 or 0.8)
end

function W:Button(parent, label, w, h, opts)
	opts = opts or {}
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w or 120, h or 40)
	b.primary = opts.primary
	h = h or 40
	local cap = floor(20 * h / 48 + 0.5)
	local gl = b:CreateTexture(nil, "BACKGROUND")
	gl:SetTexture(MEDIA .. "Button") gl:SetPoint("TOPLEFT") gl:SetPoint("BOTTOMLEFT") gl:SetWidth(cap)
	local gr = b:CreateTexture(nil, "BACKGROUND")
	gr:SetTexture(MEDIA .. "Button") gr:SetPoint("TOPRIGHT") gr:SetPoint("BOTTOMRIGHT") gr:SetWidth(cap)
	local gm = b:CreateTexture(nil, "BACKGROUND")
	gm:SetTexture(MEDIA .. "Button") gm:SetPoint("TOPLEFT", gl, "TOPRIGHT") gm:SetPoint("BOTTOMRIGHT", gr, "BOTTOMLEFT")
	b.gob = { gl, gm, gr }
	-- theme look: fill + edge
	local f = b:CreateTexture(nil, "BACKGROUND")
	f:SetTexture(WHITE) f:SetAllPoints()
	local edge = {}
	for i, p in ipairs({ { "TOPLEFT", "TOPRIGHT", "h" }, { "BOTTOMLEFT", "BOTTOMRIGHT", "h" }, { "TOPLEFT", "BOTTOMLEFT", "v" }, { "TOPRIGHT", "BOTTOMRIGHT", "v" } }) do
		local e = b:CreateTexture(nil, "BORDER")
		e:SetTexture(WHITE) e:SetPoint(p[1]) e:SetPoint(p[2])
		if p[3] == "h" then e:SetHeight(1) else e:SetWidth(1) end
		edge[i] = e
	end
	b.thmFill, b.thmEdge = f, edge
	b.thm = { f, edge[1], edge[2], edge[3], edge[4] }
	for i = 2, 4 do Skin:Paint(edge[i], "border") end
	-- hover glow
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetTexture(MEDIA .. "Glow") hl:SetBlendMode("ADD")
	hl:SetPoint("TOPLEFT", 6, -2) hl:SetPoint("BOTTOMRIGHT", -6, 2)
	hl:SetVertexColor(1, 0.9, 0.6, 0.35)
	b.label = W:Text(b, opts.size or floor(h * 0.48 + 0.5), "ink")
	b.label:SetPoint("CENTER", 0, 1)
	b.label:SetText(label or "")
	b:SetScript("OnMouseDown", function(self) if self:IsEnabled() then self.label:SetPoint("CENTER", 1, 0) end end)
	b:SetScript("OnMouseUp", function(self) self.label:SetPoint("CENTER", 0, 1) end)
	if opts.onClick then b:SetScript("OnClick", opts.onClick) end
	function b:SetLabel(s) self.label:SetText(s or "") end
	function b:SetActive(on) self.active = on and true or false ButtonLook(self) end
	local baseEnable = b.SetEnabled
	b.enabled = true
	function b:SetEnabled(on) self.enabled = on and true or false baseEnable(self, self.enabled) ButtonLook(self) end
	function b:IsEnabled() return self.enabled end
	if opts.tip then W:Tip(b, opts.tip[1], select(2, unpack(opts.tip))) end
	buttons[b] = true
	ButtonLook(b)
	return b
end

Skin:OnChange(function() for b in pairs(buttons) do ButtonLook(b) end end)

---------------------------------------------------------------------------------------------
-- Panels and insets
---------------------------------------------------------------------------------------------
local function Edges(frame, layer, size, role, inset)
	local list = {}
	inset = inset or 0
	for i, p in ipairs({ { "TOPLEFT", "TOPRIGHT", "h", 0, -inset, 0, -inset }, { "BOTTOMLEFT", "BOTTOMRIGHT", "h", 0, inset, 0, inset },
		{ "TOPLEFT", "BOTTOMLEFT", "v", inset, 0, inset, 0 }, { "TOPRIGHT", "BOTTOMRIGHT", "v", -inset, 0, -inset, 0 } }) do
		local e = frame:CreateTexture(nil, layer)
		e:SetTexture(WHITE)
		e:SetPoint(p[1], p[4], p[5]) e:SetPoint(p[2], p[6], p[7])
		if p[3] == "h" then e:SetHeight(size) else e:SetWidth(size) end
		if role then Skin:Paint(e, role) end
		list[i] = e
	end
	return list
end
W.Edges = Edges

function W:Panel(parent, tex, opts)
	local f = CreateFrame("Frame", nil, parent)
	local g, t = Skin:Layers(f, 0)
	local bg = g:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture(MEDIA .. "Panel_" .. (tex or "A"))
	bg:SetAllPoints()
	bg:SetVertexColor(0.62, 0.6, 0.58, 0.97)
	local outer = Edges(g, "BORDER", 3)
	for _, e in ipairs(outer) do e:SetVertexColor(0, 0, 0, 0.9) end
	Edges(g, "BORDER", 2, "border", 3)
	Skin:ThemePanel(t, { noShadow = true, noAccent = opts and opts.noAccent, fillRole = "bgInset" })
	f.goblin, f.theme = g, t
	return f
end

function W:Inset(parent)
	local f = CreateFrame("Frame", nil, parent)
	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture(WHITE) bg:SetAllPoints()
	Skin:Paint(bg, "inset")
	Edges(f, "BORDER", 2, "border")
	local shade = f:CreateTexture(nil, "BORDER")
	shade:SetTexture(WHITE) shade:SetPoint("TOPLEFT", 3, -3) shade:SetPoint("TOPRIGHT", -3, -3) shade:SetHeight(2)
	shade:SetVertexColor(0, 0, 0, 0.5)
	f.bg = bg
	return f
end

---------------------------------------------------------------------------------------------
-- Text boxes
---------------------------------------------------------------------------------------------
function W:Edit(parent, w, h, hint, opts)
	opts = opts or {}
	local box = W:Inset(parent)
	box:SetSize(w, h)
	local e = CreateFrame("EditBox", nil, box)
	e:SetPoint("TOPLEFT", opts.padL or 10, 0) e:SetPoint("BOTTOMRIGHT", -8, 0)
	e:SetAutoFocus(false)
	if e.SetMultiLine then e:SetMultiLine(false) end   -- one line: long text scrolls left, never past the box
	Skin:Font(e, "body", opts.size or floor(h * 0.45 + 0.5))
	Skin:Paint(e, "text")
	if opts.numeric then e:SetNumeric(true) end
	if opts.maxLetters then e:SetMaxLetters(opts.maxLetters) end
	if opts.justify then e:SetJustifyH(opts.justify) end
	local ph = W:Text(box, opts.size or floor(h * 0.45 + 0.5), "textDim")
	ph:SetPoint("LEFT", e, "LEFT", 0, 0)
	ph:SetPoint("RIGHT", e, "RIGHT", 0, 0)   -- never wider than the box: a hint that does not fit is cut with "..."
	ph:SetJustifyH("LEFT")
	ph:SetWordWrap(false)
	ph:SetText(hint or "")
	local function Hint() ph:SetShown((e:GetText() or "") == "" and not e:HasFocus()) end
	e:SetScript("OnEditFocusGained", function() ph:Hide() end)
	e:SetScript("OnEditFocusLost", Hint)
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	e:SetScript("OnEnterPressed", function(self) self:ClearFocus() if opts.onEnter then opts.onEnter(self:GetText()) end end)
	e:SetScript("OnTextChanged", function(self, user) Hint() if opts.onChange then opts.onChange(self:GetText(), user) end end)
	box.edit, box.hint = e, ph
	function box:GetText() return e:GetText() or "" end
	function box:SetText(s) e:SetText(s or "") Hint() end
	Hint()
	return box
end

-- gold / silver / copper, like the game's own money boxes
function W:MoneyBox(parent, h, onChange)
	h = h or 34
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(220, h)
	local parts, x = {}, 0
	for i, coin in ipairs({ { "g", 80, "UI-GoldIcon" }, { "s", 54, "UI-SilverIcon" }, { "c", 54, "UI-CopperIcon" } }) do
		local box = W:Edit(f, coin[2], h, "", { numeric = true, maxLetters = i == 1 and 7 or 2, justify = "RIGHT", padL = 4,
			onChange = function(_, user) if user and onChange then onChange(f:Get()) end end })
		box:SetPoint("LEFT", x, 0)
		box.edit:SetPoint("BOTTOMRIGHT", -18, 0)
		local icon = box:CreateTexture(nil, "OVERLAY")
		icon:SetTexture("Interface\\MoneyFrame\\" .. coin[3])
		icon:SetSize(13, 13)
		icon:SetPoint("RIGHT", -4, 0)
		parts[coin[1]] = box
		x = x + coin[2] + 4
	end
	f:SetWidth(x - 4)
	function f:Get()
		local g, s, c = tonumber(parts.g:GetText()) or 0, tonumber(parts.s:GetText()) or 0, tonumber(parts.c:GetText()) or 0
		return NG.Money:Join(g, min(s, 99), min(c, 99))
	end
	function f:Set(copper)
		if not copper then parts.g:SetText("") parts.s:SetText("") parts.c:SetText("") return end
		local g, s, c = NG.Money:Split(copper)
		parts.g:SetText(g > 0 and tostring(g) or "")
		parts.s:SetText((g > 0 or s > 0) and tostring(s) or "")
		parts.c:SetText(tostring(c))
	end
	f.parts = parts
	return f
end

---------------------------------------------------------------------------------------------
-- Icons and badges
---------------------------------------------------------------------------------------------
function W:Icon(parent, size)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(size, size)
	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture(WHITE) bg:SetAllPoints() bg:SetVertexColor(0.11, 0.09, 0.07, 1)
	local tex = f:CreateTexture(nil, "ARTWORK")
	tex:SetPoint("TOPLEFT", 2, -2) tex:SetPoint("BOTTOMRIGHT", -2, 2)
	tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local edges = Edges(f, "OVERLAY", 2)
	f.tex, f.edges = tex, edges
	-- An item keeps its rarity edge (poor grey, common white, uncommon green...; white while
	-- the quality isn't known yet). quality = false means "not an item" (a category, the empty
	-- panel): the edge is the frame's own border colour and follows the skin.
	function f:SetItem(icon, quality)
		self.tex:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
		if quality == false then
			for _, e in ipairs(self.edges) do Skin:Paint(e, "border") end
			return
		end
		local c = quality and _G.ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
		local r, g, b = 0.9, 0.9, 0.9
		if c then r, g, b = c.r, c.g, c.b end
		for _, e in ipairs(self.edges) do Skin:Unpaint(e) e:SetVertexColor(r, g, b, 1) end
	end
	f:SetItem(nil, false)
	return f
end

---------------------------------------------------------------------------------------------
-- Name plate and divider: the goblin's brass art, or the theme's own look
---------------------------------------------------------------------------------------------
-- W:NamePlate(parent, w) -> plate (anchor it with :SetPoint), plate.name (the text), plate.h.
-- Goblin skin: the title plate art. Theme: a slim theme panel across the same place, the
-- name in the theme's header colour, an accent rule under it.
function W:NamePlate(parent, w, size)
	local h = floor(w * 150 / 512 + 0.5)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(w, h)
	f.h = h
	local art = f:CreateTexture(nil, "ARTWORK")
	art:SetTexture(MEDIA .. "TitlePlate") art:SetTexCoord(0, 1, 0, 150 / 256)
	art:SetAllPoints()
	local cy = -floor(h * 0.47)
	-- the theme look: a light band in the accent colour (the colour of the rule it replaces),
	-- a thin border, and the name over it with a drop shadow
	local band = CreateFrame("Frame", nil, f)
	band:SetPoint("TOPLEFT", f, "TOPLEFT", 26, cy + 22)
	band:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -26, cy - 22)
	local fill = band:CreateTexture(nil, "BACKGROUND")
	fill:SetTexture(WHITE) fill:SetAllPoints()
	Skin:Paint(fill, "accent", { alpha = 0.85 })
	Edges(band, "BORDER", 1, "border")
	-- the text on its own frame above the band (a child frame draws over its parent's own
	-- text)
	local holder = CreateFrame("Frame", nil, f)
	holder:SetAllPoints()
	holder:SetFrameLevel(band:GetFrameLevel() + 5)
	local name = W:Text(holder, size or 24, "white")
	name:SetPoint("CENTER", f, "TOP", 0, cy)
	name:SetWidth(w - 120)
	f.art, f.band, f.name = art, band, name
	local function Look()
		local goblin = Skin:Mode() == "goblin"
		art:SetShown(goblin)
		band:SetShown(not goblin)
		name:SetShadowColor(0, 0, 0, goblin and 0.8 or 1)
		name:SetShadowOffset(goblin and 1 or 2, goblin and -1 or -2)
		if not name.keepColour then Skin:Paint(name, goblin and "white" or "header") end
	end
	Look()
	Skin:OnChange(Look)
	return f
end

-- W:Divider(parent, w, h): the coin chain in the goblin skin; in the theme, a hairline with a
-- small accent diamond at its middle.
function W:Divider(parent, w, h)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(w, h)
	local chain = f:CreateTexture(nil, "ARTWORK")
	chain:SetTexture(MEDIA .. "CoinChain") chain:SetTexCoord(0, 1, 0, 63 / 64)
	chain:SetAllPoints()
	local line = f:CreateTexture(nil, "ARTWORK")
	line:SetTexture(WHITE) line:SetHeight(1)
	line:SetPoint("LEFT", 0, 0) line:SetPoint("RIGHT", 0, 0)
	Skin:Paint(line, "border")
	local gem = f:CreateTexture(nil, "OVERLAY")
	gem:SetTexture(WHITE) gem:SetSize(7, 7)
	gem:SetPoint("CENTER")
	if gem.SetRotation then gem:SetRotation(math.pi / 4) end
	Skin:Paint(gem, "accent")
	local function Look()
		local goblin = Skin:Mode() == "goblin"
		chain:SetShown(goblin)
		line:SetShown(not goblin)
		gem:SetShown(not goblin)
	end
	Look()
	Skin:OnChange(Look)
	f.chain, f.line, f.gem = chain, line, gem
	return f
end

function W:Badge(parent, w, h)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(w or 76, h or 24)
	local bg = f:CreateTexture(nil, "ARTWORK")
	bg:SetTexture(MEDIA .. "Pill") bg:SetAllPoints()
	local mark = f:CreateTexture(nil, "OVERLAY")
	mark:SetSize(10, 10) mark:SetPoint("LEFT", 9, 0)
	local text = W:Text(f, floor((h or 24) * 0.6), "white")
	text:SetPoint("CENTER", 6, 0)
	f.bg, f.mark, f.text = bg, mark, text
	-- marks: down = cheap, up = pricey, dot = fair
	local ARROW = "Interface\\Buttons\\Arrow-Down-Up"
	function f:Set(label, role, markKind)
		self.text:SetText(label or "")
		Skin:Paint(self.bg, role or "fair")
		if markKind == "down" then self.mark:SetTexture("Interface\\Buttons\\Arrow-Down-Up") self.mark:SetTexCoord(0, 1, 0, 1)
		elseif markKind == "up" then self.mark:SetTexture("Interface\\Buttons\\Arrow-Up-Up") self.mark:SetTexCoord(0, 1, 0, 1)
		else self.mark:SetTexture(MEDIA .. "Round") self.mark:SetTexCoord(0, 1, 0, 1) end
		self.mark:SetSize(markKind and 12 or 6, markKind and 12 or 6)
	end
	return f
end

---------------------------------------------------------------------------------------------
-- Virtual list: a fixed set of rows showing a window onto the data
---------------------------------------------------------------------------------------------
function W:List(parent, w, h, rowH, make, fill)
	local L = CreateFrame("Frame", nil, parent)
	L:SetSize(w, h)
	L.data, L.offset, L.rowH = {}, 0, rowH
	L.rows = {}
	local count = floor(h / rowH)
	L.visible = count
	for i = 1, count do
		local r = CreateFrame("Button", nil, L)
		r:SetSize(w - 14, rowH - 4)
		r:SetPoint("TOPLEFT", 0, -(i - 1) * rowH)
		r.bg = r:CreateTexture(nil, "BACKGROUND")
		r.bg:SetTexture(WHITE) r.bg:SetAllPoints()
		r.edge = Edges(r, "BORDER", 1)
		local hl = r:CreateTexture(nil, "HIGHLIGHT")
		hl:SetTexture(WHITE) hl:SetAllPoints() hl:SetVertexColor(1, 0.85, 0.5, 0.07)
		r.index = i
		make(r, i)
		r:Hide()
		L.rows[i] = r
	end
	-- scroll bar
	local track = L:CreateTexture(nil, "BACKGROUND")
	track:SetTexture(WHITE) track:SetPoint("TOPRIGHT", -3, 0) track:SetPoint("BOTTOMRIGHT", -3, 4) track:SetWidth(7)
	Skin:Paint(track, "inset")
	local thumb = CreateFrame("Frame", nil, L)
	thumb:SetWidth(7)
	local tt = thumb:CreateTexture(nil, "ARTWORK")
	tt:SetTexture(WHITE) tt:SetAllPoints()
	Skin:Paint(tt, "border")
	thumb:EnableMouse(true)
	L.track, L.thumb = track, thumb

	local function MaxOffset() return max(0, #L.data - count) end
	function L:Refresh()
		local n = #self.data
		if self.offset > MaxOffset() then self.offset = MaxOffset() end
		for i, r in ipairs(self.rows) do
			local d = self.data[self.offset + i]
			if d then
				local sel = self.selected ~= nil and self.selected == d
				Skin:Paint(r.bg, sel and "rowSel" or (((self.offset + i) % 2 == 1) and "rowA" or "rowB"))
				for k, e in ipairs(r.edge) do Skin:Paint(e, sel and "accent" or "border", { alpha = sel and 1 or 0.35 }) end
				r.data = d
				fill(r, d, sel)
				r:Show()
			else
				r.data = nil
				r:Hide()
			end
		end
		local trackH = h - 4
		if n > count then
			local th = max(24, trackH * count / n)
			thumb:SetHeight(th)
			thumb:ClearAllPoints()
			thumb:SetPoint("TOPRIGHT", -3, -((trackH - th) * self.offset / MaxOffset()))
			thumb:Show()
		else
			thumb:Hide()
		end
		if self.onScroll then self.onScroll(self.offset, MaxOffset()) end
	end
	function L:SetData(t, keepOffset)
		self.data = t or {}
		if not keepOffset then self.offset = 0 end
		self:Refresh()
	end
	function L:Scroll(delta)
		self.offset = min(MaxOffset(), max(0, self.offset - delta))
		self:Refresh()
	end
	function L:Select(d) self.selected = d self:Refresh() end
	L:EnableMouseWheel(true)
	L:SetScript("OnMouseWheel", function(self, delta) self:Scroll(delta * 3) end)
	local function ThumbUpdate()
		local dr = thumb.drag
		if not dr then return end
		if not IsMouseButtonDown("LeftButton") then thumb.drag = nil thumb:SetScript("OnUpdate", nil) return end
		local _, cy = GetCursorPosition()
		local dy = dr.y - cy / L:GetEffectiveScale()
		local per = (h - thumb:GetHeight()) / max(1, MaxOffset())
		L.offset = min(MaxOffset(), max(0, floor(dr.off + dy / max(1, per) + 0.5)))
		L:Refresh()
	end
	thumb:SetScript("OnMouseDown", function()
		local _, cy = GetCursorPosition()
		thumb.drag = { y = cy / L:GetEffectiveScale(), off = L.offset }
		thumb:SetScript("OnUpdate", ThumbUpdate)
	end)
	thumb:SetScript("OnMouseUp", function() thumb.drag = nil thumb:SetScript("OnUpdate", nil) end)
	return L
end

---------------------------------------------------------------------------------------------
-- Settings controls
---------------------------------------------------------------------------------------------
local checks = setmetatable({}, { __mode = "k" })
function W:Check(parent, label, get, set, tip)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(360, 26)
	local box = W:Inset(b)
	box:SetSize(20, 20) box:SetPoint("LEFT")
	local mark = box:CreateTexture(nil, "OVERLAY")
	mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check") mark:SetPoint("CENTER") mark:SetSize(22, 22)
	local text = W:Text(b, 15, "text")
	text:SetPoint("LEFT", box, "RIGHT", 8, 0)
	text:SetText(label)
	b:SetWidth(30 + max(200, text:GetStringWidth() + 10))
	b.text = text
	function b:Sync() mark:SetShown(get() and true or false) end
	b:SetScript("OnClick", function(self) set(not get()) self:Sync() end)
	if tip then W:Tip(b, label, tip) end
	b:Sync()
	checks[b] = true
	return b
end
function W:SyncAll() for b in pairs(checks) do b:Sync() end end

function W:Slider(parent, label, lo, hi, step, get, set, fmt)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(360, 46)
	local text = W:Text(f, 15, "text")
	text:SetPoint("TOPLEFT")
	local track = W:Inset(f)
	track:SetSize(260, 10) track:SetPoint("TOPLEFT", 0, -26)
	local knob = CreateFrame("Button", nil, f)
	knob:SetSize(16, 22)
	local kt = knob:CreateTexture(nil, "ARTWORK")
	kt:SetTexture(WHITE) kt:SetAllPoints()
	Skin:Paint(kt, "accent")
	local function Show()
		local v = get()
		text:SetText(label .. ":  " .. (fmt and fmt(v) or tostring(v)))
		local t = (v - lo) / max(0.0001, hi - lo)
		knob:ClearAllPoints()
		knob:SetPoint("CENTER", track, "LEFT", t * 260, 0)
	end
	local function FromCursor()
		local x = GetCursorPosition() / track:GetEffectiveScale()
		local t = min(1, max(0, (x - track:GetLeft()) / 260))
		local v = lo + floor(t * (hi - lo) / step + 0.5) * step
		if v ~= get() then set(v) end
		Show()
	end
	local function KnobUpdate()
		if not IsMouseButtonDown("LeftButton") then knob.drag = nil knob:SetScript("OnUpdate", nil) return end
		FromCursor()
	end
	knob:SetScript("OnMouseDown", function() knob.drag = true knob:SetScript("OnUpdate", KnobUpdate) end)
	knob:SetScript("OnMouseUp", function() knob.drag = nil knob:SetScript("OnUpdate", nil) end)
	track:EnableMouse(true)
	track:SetScript("OnMouseDown", FromCursor)
	f.Sync = Show
	checks[f] = true
	Show()
	return f
end

function W:Choice(parent, label, options, get, set)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(420, 52)
	local text = W:Text(f, 15, "text")
	text:SetPoint("TOPLEFT") text:SetText(label)
	local bs, x = {}, 0
	for i, o in ipairs(options) do
		local b = W:Button(f, o[2], o.w or 110, 26, { size = 14 })
		b:SetPoint("TOPLEFT", x, -22)
		b:SetScript("OnClick", function() set(o[1]) f:Sync() end)
		x = x + (o.w or 110) + 6
		bs[i] = b
	end
	function f:Sync() for i, o in ipairs(options) do bs[i]:SetActive(get() == o[1]) end end
	checks[f] = true
	f:Sync()
	return f
end
