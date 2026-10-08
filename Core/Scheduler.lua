--[[ NetherGoblin - Core/Scheduler.lua
	One place where long work runs, a little every frame, so the game never stutters.

	A job is a function run as a coroutine. It calls Scheduler:Step() between small pieces of
	work; Step yields when this frame's budget is spent and the job carries on next frame.

	  Scheduler:Run(name, fn [, opts])  start (a running job of the same name is replaced)
	                                    opts.onDone(ok, err), opts.pauseHidden = frame (waits
	                                    while that frame is hidden)
	  Scheduler:Cancel(name)            stop it (onDone gets false, "cancelled")
	  Scheduler:IsRunning(name)
	  Scheduler:Step()                  inside a job: yield if over budget
	  Scheduler:Budget()                ms this frame: the "scan.budget" setting, 1 ms in combat,
	                                    and half when the frame rate is below 30

	Time is measured with debugprofilestop() where the client has it. ]]

local _, ns = ...
local NG = ns.NG
local Scheduler = NG:Module("Scheduler")

local jobs, order = {}, {}
local driver = CreateFrame("Frame")
driver:Hide()
local clock = _G.debugprofilestop or function() return (_G.GetTime and GetTime() or 0) * 1000 end
local sliceEnd = 0

function Scheduler:Budget()
	local ms = tonumber(NG.Settings and NG.Settings:Get("scan.budget")) or 4
	if NG:InCombat() then ms = 1 end
	local fps = _G.GetFramerate and GetFramerate() or 60
	if type(fps) == "number" and fps > 0 and fps < 30 then ms = ms * 0.5 end
	if ms < 0.5 then ms = 0.5 elseif ms > 12 then ms = 12 end
	return ms
end

function Scheduler:Step()
	if clock() >= sliceEnd and coroutine.running() then coroutine.yield() end
end

local function Finish(name, ok, err)
	local j = jobs[name]
	if not j then return end
	jobs[name] = nil
	for i = #order, 1, -1 do if order[i] == name then table.remove(order, i) end end
	if j.onDone then NG:Safe("job done " .. name, j.onDone, ok, err) end
	if #order == 0 then driver:Hide() end
end

driver:SetScript("OnUpdate", function()
	local budget = Scheduler:Budget()
	local start = clock()
	sliceEnd = start + budget
	local i = 1
	while i <= #order and clock() < sliceEnd do
		local name = order[i]
		local j = jobs[name]
		if j and not (j.pauseHidden and not j.pauseHidden:IsShown()) then
			local ok, err = coroutine.resume(j.co)
			if not ok then
				NG:RecordError("job " .. name, err)
				Finish(name, false, err)
			elseif coroutine.status(j.co) == "dead" then
				Finish(name, true)
			else
				i = i + 1
			end
		else
			i = i + 1
		end
	end
end)

function Scheduler:Run(name, fn, opts)
	if jobs[name] then self:Cancel(name) end
	jobs[name] = { co = coroutine.create(fn), onDone = opts and opts.onDone, pauseHidden = opts and opts.pauseHidden }
	order[#order + 1] = name
	driver:Show()
end

function Scheduler:Cancel(name)
	if jobs[name] then Finish(name, false, "cancelled") end
end

function Scheduler:IsRunning(name) return jobs[name] ~= nil end

-- run every job to the end right now (tests, logout)
function Scheduler:Drain(name)
	local j = jobs[name]
	if not j then return end
	sliceEnd = math.huge
	while jobs[name] and coroutine.status(j.co) ~= "dead" do
		local ok, err = coroutine.resume(j.co)
		if not ok then NG:RecordError("job " .. name, err) Finish(name, false, err) return end
	end
	if jobs[name] then Finish(name, true) end
end
