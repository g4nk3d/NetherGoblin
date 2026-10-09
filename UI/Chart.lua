--[[ NetherGoblin - UI/Chart.lua
	The price trend: an item's daily lows over the last 14 days, its average as a dashed line,
	today as a bright dot. Drawn with line regions (frame:CreateLine) where the client has
	them, otherwise with small dots along the path.

	While there are fewer than LIVE_DAYS days of history, the item's live listings are drawn
	instead once they arrive: how much is listed at each price (bars, cheapest on the left),
	with marks for the lowest price (green), the most-listed price (accent), the highest and
	your own price (gold).

	  Chart:New(parent, w, h)  -> chart; chart:SetHistory(points) with points from
	                              Prices:History(key) ({ day, low, qty }); chart:Clear()
	  chart:SetLive(rows, mine)   rows = a live search's rows ({ unit, qty }); drawn only
	                              while history is thin. chart:SetMine(price) moves your mark.
	  chart.mode                  "history" | "live" | nil ]]

local _, ns = ...
local NG = ns.NG
local Chart = NG:Module("Chart")
local W, Skin = NG.Widgets, NG.Skin
local L = ns.L
local WHITE = Skin.WHITE
local floor, max, min = math.floor, math.max, math.min
local DAYS = 14
Chart.LIVE_DAYS = 3     -- fewer days of history than this: the live spread is drawn instead
local BUCKETS = 28

function Chart:New(parent, w, h)
	local c = W:Inset(parent)
	c:SetSize(w, h)
	c.title = W:Text(c, 15, "header")
	c.title:SetPoint("TOPLEFT", 10, -8)
	c.title:SetText(L["14 days"])
	c.range = W:Text(c, 13, "textDim")
	c.range:SetPoint("TOPRIGHT", -10, -9)
	c.avgLabel = W:Text(c, 12, "accent")
	c.avgLabel:SetPoint("BOTTOMRIGHT", -8, 5)
	c.empty = W:Text(c, 14, "textDim")
	c.empty:SetPoint("CENTER", 0, -6)
	c.empty:SetText(L["No price history yet: it builds up with every scan."])
	c.empty:SetWordWrap(true) c.empty:SetWidth(w - 40)
	c.plot = { x = 14, y = 30, w = w - 28, h = h - 44 }
	c.lines, c.dots, c.fills, c.dash = {}, {}, {}, {}
	c.canLine = type(c.CreateLine) == "function"
	c.today = c:CreateTexture(nil, "OVERLAY", nil, 3)
	c.today:SetTexture(NG.MEDIA .. "Round") c.today:SetSize(11, 11)
	c.today:SetVertexColor(0.35, 0.9, 0.3, 1)
	for k, v in pairs(Chart) do if type(v) == "function" and k ~= "New" then c[k] = v end end
	c:Clear()
	return c
end

local function Line(c, i)
	local l = c.lines[i]
	if not l then
		l = c:CreateLine(nil, "OVERLAY", nil, 2)
		l:SetTexture(WHITE)
		l:SetThickness(2.5)
		c.lines[i] = l
	end
	return l
end

local function Dot(c, pool, i, size, layerSub)
	local d = c[pool][i]
	if not d then
		d = c:CreateTexture(nil, "OVERLAY", nil, layerSub or 1)
		d:SetTexture(WHITE)
		c[pool][i] = d
	end
	d:SetSize(size, size)
	return d
end

local function Bar(c, i)
	local b = c.fills[i]
	if not b then
		b = c:CreateTexture(nil, "ARTWORK")
		b:SetTexture(WHITE)
		c.fills[i] = b
	end
	return b
end

function Chart:Clear()
	for _, t in ipairs(self.lines) do t:Hide() end
	for _, t in ipairs(self.dots) do t:Hide() end
	for _, t in ipairs(self.fills) do t:Hide() end
	for _, t in ipairs(self.dash) do t:Hide() end
	self.today:Hide()
	if self.marks then for _, t in ipairs(self.marks) do t:Hide() end end
	self.range:SetText("")
	self.avgLabel:SetText("")
	self.title:SetText(L["14 days"])
	self.empty:Show()
	self.mode = nil
	self.live = nil
	self.days = 0
end

function Chart:SetHistory(points)
	self:Clear()
	local today = NG:Today()
	local pts = {}
	for _, p in ipairs(points or {}) do
		if today - p[1] < DAYS then pts[#pts + 1] = p end
	end
	self.days = #pts
	if #pts == 0 then return end
	self.empty:Hide()
	self.mode = "history"
	local lo, hi, sum = math.huge, 0, 0
	for _, p in ipairs(pts) do lo, hi, sum = min(lo, p[2]), max(hi, p[2]), sum + p[2] end
	local avg = floor(sum / #pts + 0.5)
	self.range:SetText(string.format(L["low %s  ·  high %s"], NG.Money:Text(lo, { plain = true, short = true }), NG.Money:Text(hi, { plain = true, short = true })))
	self.avgLabel:SetText(string.format(L["avg %s (dashed)"], NG.Money:Text(avg, { plain = true, short = true })))
	local P = self.plot
	local span = hi - lo
	if span <= 0 then span = max(1, hi * 0.1) lo = lo - span / 2 end
	local pad = span * 0.12
	lo, hi = lo - pad, hi + pad
	local function X(day) return P.x + P.w * (DAYS - 1 - (today - day)) / (DAYS - 1) end
	local function Y(v) return P.y + P.h * (v - lo) / (hi - lo) end   -- from the bottom
	local r, g, b = Skin:Color("accent")
	-- filled area under the line: one thin column per pixel step between points
	local col = 0
	for i = 1, #pts - 1 do
		local x1, y1, x2, y2 = X(pts[i][1]), Y(pts[i][2]), X(pts[i + 1][1]), Y(pts[i + 1][2])
		local steps = max(1, floor((x2 - x1) / 3))
		for s = 0, steps - 1 do
			col = col + 1
			local t = (s + 0.5) / steps
			local bx, by = x1 + (x2 - x1) * s / steps, y1 + (y2 - y1) * t
			local bar = Bar(self, col)
			bar:ClearAllPoints()
			bar:SetPoint("BOTTOMLEFT", bx, P.y)
			bar:SetSize(max(1, (x2 - x1) / steps + 0.5), max(1, by - P.y))
			bar:SetVertexColor(r, g, b, 0.16)
			bar:Show()
		end
	end
	-- the line
	for i = 1, #pts - 1 do
		local x1, y1, x2, y2 = X(pts[i][1]), Y(pts[i][2]), X(pts[i + 1][1]), Y(pts[i + 1][2])
		if self.canLine then
			local l = Line(self, i)
			l:SetStartPoint("BOTTOMLEFT", x1, y1)
			l:SetEndPoint("BOTTOMLEFT", x2, y2)
			l:SetVertexColor(r, g, b, 1)
			l:Show()
		else
			local n = max(2, floor(math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2) / 3))
			for s = 0, n do
				local d = Dot(self, "dots", (i - 1) * 64 + s + 1, 3)
				d:ClearAllPoints()
				d:SetPoint("CENTER", self, "BOTTOMLEFT", x1 + (x2 - x1) * s / n, y1 + (y2 - y1) * s / n)
				d:SetVertexColor(r, g, b, 1)
				d:Show()
			end
		end
	end
	-- the average, dashed
	local ay = Y(avg)
	local i = 0
	for x = P.x, P.x + P.w - 7, 14 do
		i = i + 1
		local d = Dot(self, "dash", i, 1)
		d:ClearAllPoints()
		d:SetPoint("BOTTOMLEFT", x, ay)
		d:SetSize(7, 1.2)
		d:SetVertexColor(r * 0.8, g * 0.65, b * 0.4, 0.95)
		d:Show()
	end
	local last = pts[#pts]
	self.today:ClearAllPoints()
	self.today:SetPoint("CENTER", self, "BOTTOMLEFT", X(last[1]), Y(last[2]))
	self.today:Show()
	if #pts == 1 then
		-- one day only: a dot, no line
		self.today:SetPoint("CENTER", self, "BOTTOMLEFT", X(last[1]), Y(last[2]))
	end
end

---------------------------------------------------------------------------------------------
-- today's live spread (while the history is thin)
---------------------------------------------------------------------------------------------
local function Mark(c, i)
	c.marks = c.marks or {}
	local m = c.marks[i]
	if not m then
		m = c:CreateTexture(nil, "OVERLAY", nil, 4)
		m:SetTexture(WHITE)
		c.marks[i] = m
	end
	return m
end

-- rows: { { unit, qty }, ... }; mine: your price (copper) or nil
function Chart:SetLive(rows, mine)
	self.live = { rows = rows or {}, mine = mine }
	if (self.days or 0) < Chart.LIVE_DAYS then self:DrawLive() end
end

function Chart:SetMine(mine)
	if not self.live then return end
	if self.live.mine == mine then return end
	self.live.mine = mine
	if self.mode == "live" then self:DrawLive() end
end

function Chart:DrawLive()
	local live = self.live
	-- (Clear without forgetting the live data)
	for _, t in ipairs(self.lines) do t:Hide() end
	for _, t in ipairs(self.dots) do t:Hide() end
	for _, t in ipairs(self.fills) do t:Hide() end
	for _, t in ipairs(self.dash) do t:Hide() end
	if self.marks then for _, t in ipairs(self.marks) do t:Hide() end end
	self.today:Hide()
	local rows = {}
	for _, r in ipairs(live and live.rows or {}) do
		local u, q = tonumber(r.unit), tonumber(r.qty) or 1
		if u and u > 0 and q > 0 then rows[#rows + 1] = { u, q } end
	end
	if #rows == 0 then
		self.mode = nil
		self.title:SetText(L["14 days"])
		self.range:SetText("") self.avgLabel:SetText("")
		self.empty:Show()
		return
	end
	self.empty:Hide()
	self.mode = "live"
	self.title:SetText(L["Listed now"])
	local lo, hi = math.huge, 0
	for _, r in ipairs(rows) do lo, hi = min(lo, r[1]), max(hi, r[1]) end
	-- the most listed price (by quantity)
	local byPrice, most, mostQ = {}, nil, -1
	for _, r in ipairs(rows) do
		byPrice[r[1]] = (byPrice[r[1]] or 0) + r[2]
		if byPrice[r[1]] > mostQ or (byPrice[r[1]] == mostQ and r[1] < most) then most, mostQ = r[1], byPrice[r[1]] end
	end
	local mine = live.mine and live.mine > 0 and live.mine or nil
	local xlo, xhi = lo, hi
	if mine then xlo, xhi = min(xlo, mine), max(xhi, mine) end
	local span = xhi - xlo
	if span <= 0 then span = max(1, xhi * 0.1) xlo = xlo - span / 2 xhi = xhi + span / 2 end
	local P = self.plot
	local function X(v) return P.x + P.w * (v - xlo) / (xhi - xlo) end
	-- quantity per bucket
	local qty, top = {}, 0
	for _, r in ipairs(rows) do
		local b = min(BUCKETS, floor((r[1] - xlo) / (xhi - xlo) * BUCKETS) + 1)
		qty[b] = (qty[b] or 0) + r[2]
		top = max(top, qty[b])
	end
	local r, g, b = Skin:Color("accent")
	local bw = P.w / BUCKETS
	local n = 0
	for k = 1, BUCKETS do
		local q = qty[k]
		if q then
			n = n + 1
			local bar = Bar(self, n)
			bar:ClearAllPoints()
			bar:SetPoint("BOTTOMLEFT", P.x + (k - 1) * bw + 1, P.y)
			bar:SetSize(max(1, bw - 2), max(2, P.h * 0.85 * (q / top)))
			bar:SetVertexColor(r, g, b, 0.45)
			bar:Show()
		end
	end
	local m = 0
	local function V(v, cr, cg, cb, a, wdt)
		m = m + 1
		local t = Mark(self, m)
		t:ClearAllPoints()
		t:SetPoint("BOTTOM", self, "BOTTOMLEFT", X(v), P.y)
		t:SetSize(wdt or 2, P.h)
		t:SetVertexColor(cr, cg, cb, a)
		t:Show()
	end
	V(lo, 0.35, 0.9, 0.3, 0.95)                       -- lowest
	if most ~= lo then V(most, r, g, b, 0.95) end      -- most listed
	if hi ~= lo then V(hi, 0.6, 0.6, 0.6, 0.6) end     -- highest
	if mine then V(mine, 1, 0.82, 0.2, 1, 3) end       -- yours
	self.range:SetText(string.format(L["low %s  ·  high %s"], NG.Money:Text(lo, { plain = true, short = true }), NG.Money:Text(hi, { plain = true, short = true })))
	self.avgLabel:SetText(string.format(L["most listed %s"], NG.Money:Text(most, { plain = true, short = true })) .. (mine and ("  ·  " .. string.format(L["yours %s"], NG.Money:Text(mine, { plain = true, short = true }))) or ""))
end
