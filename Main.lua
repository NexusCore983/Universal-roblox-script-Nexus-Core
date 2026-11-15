-- Nexus Core | LocalScript (StarterPlayerScripts veya StarterGui içine koy)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

-- Anahtar düz metin olarak tutulmaz; sadece kodlanmış bayt tablosu var
local ENC = {92, 86, 108, 108, 109, 96, 111, 117, 107, 98, 94, 98, 98}

-- Girilen anahtarı aynı yöntemle kodlayıp karşılaştırır
local function checkKey(input)
	if type(input) ~= "string" or #input ~= #ENC then return false end
	local ok = true
	for i = 1, #input do
		local v = string.byte(input, i) + (i * 3 + 11)
		if v ~= ENC[i] then ok = false end
	end
	return ok
end

-- Eski arayüzleri temizle
for _, n in ipairs({"NexusCoreKey", "NexusCoreMain"}) do
	local old = PlayerGui:FindFirstChild(n)
	if old then old:Destroy() end
end

-- Yardımcı: arayüz elemanı oluştur
local function create(class, props, parent)
	local obj = Instance.new(class)
	for k, v in pairs(props) do obj[k] = v end
	obj.Parent = parent
	return obj
end

local function corner(obj, r)
	create("UICorner", {CornerRadius = UDim.new(0, r or 8)}, obj)
end

-- Sürüklenebilir yapma
local function makeDraggable(frame, handle)
	local dragging, startPos, startInput
	handle.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, startPos, startInput = true, frame.Position, i.Position
			i.Changed:Connect(function()
				if i.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - startInput
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
end

--------------------------------------------------------------------
-- ANA SCRIPT (key doğrulanınca çalışır)
--------------------------------------------------------------------
local function loadMain()
	local conns = {}
	local state = {
		esp = false, fly = false, aimbot = false,
		speed = false, speedValue = 32,
		infAmmo = false, autoFire = false, noRecoil = false,
	}
	local FLY_SPEED = 60
	local flyKeys = {W = false, A = false, S = false, D = false, Up = false, Down = false}
	local espObjects = {}
	local flyBV, flyBG

	local gui = create("ScreenGui", {
		Name = "NexusCoreMain", ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, PlayerGui)

	local main = create("Frame", {
		Size = UDim2.new(0, 280, 0, 400), Position = UDim2.new(0.5, -140, 0.5, -200),
		BackgroundColor3 = Color3.fromRGB(20, 20, 28), BorderSizePixel = 0,
	}, gui)
	corner(main, 10)

	local title = create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Color3.fromRGB(35, 30, 60),
		Text = "NEXUS CORE", TextColor3 = Color3.fromRGB(170, 140, 255),
		Font = Enum.Font.GothamBold, TextSize = 18, BorderSizePixel = 0,
	}, main)
	corner(title, 10)
	makeDraggable(main, title)

	local closeBtn = create("TextButton", {
		Size = UDim2.new(0, 28, 0, 28), Position = UDim2.new(1, -32, 0, 4),
		BackgroundColor3 = Color3.fromRGB(180, 50, 60), Text = "X",
		TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 14,
	}, main)
	corner(closeBtn, 6)

	local list = create("ScrollingFrame", {
		Size = UDim2.new(1, -16, 1, -48), Position = UDim2.new(0, 8, 0, 42),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
		CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, main)
	create("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, list)

	-- Aç/kapa butonu oluştur
	local function makeToggle(text, key, onChange)
		local btn = create("TextButton", {
			Size = UDim2.new(1, -6, 0, 34), BackgroundColor3 = Color3.fromRGB(40, 40, 55),
			Text = text .. ": KAPALI", TextColor3 = Color3.new(1, 1, 1),
			Font = Enum.Font.Gotham, TextSize = 14, AutoButtonColor = true,
		}, list)
		corner(btn, 6)
		btn.MouseButton1Click:Connect(function()
			state[key] = not state[key]
			btn.Text = text .. (state[key] and ": AÇIK" or ": KAPALI")
			btn.BackgroundColor3 = state[key] and Color3.fromRGB(90, 60, 170) or Color3.fromRGB(40, 40, 55)
			if onChange then pcall(onChange, state[key]) end
		end)
	end

	-- Karakter yardımcıları
	local function getChar() return LocalPlayer.Character end
	local function getRoot()
		local c = getChar()
		return c and c:FindFirstChild("HumanoidRootPart")
	end
	local function getHum()
		local c = getChar()
		return c and c:FindFirstChildOfClass("Humanoid")
	end

	----------------------------------------------------------------
	-- ESP
	----------------------------------------------------------------
	local function removeESP(plr)
		if espObjects[plr] then
			pcall(function() espObjects[plr]:Destroy() end)
			espObjects[plr] = nil
		end
	end

	local function applyESP(plr)
		if plr == LocalPlayer or not plr.Character then return end
		removeESP(plr)
		local hl = create("Highlight", {
			FillColor = Color3.fromRGB(170, 100, 255), OutlineColor = Color3.new(1, 1, 1),
			FillTransparency = 0.6, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		}, plr.Character)
		espObjects[plr] = hl
	end

	local function refreshESP()
		for _, p in ipairs(Players:GetPlayers()) do
			if state.esp then applyESP(p) else removeESP(p) end
		end
	end

	table.insert(conns, Players.PlayerAdded:Connect(function(p)
		p.CharacterAdded:Connect(function()
			task.wait(0.5)
			if state.esp then applyESP(p) end
		end)
	end))
	for _, p in ipairs(Players:GetPlayers()) do
		p.CharacterAdded:Connect(function()
			task.wait(0.5)
			if state.esp then applyESP(p) end
		end)
	end
	table.insert(conns, Players.PlayerRemoving:Connect(removeESP))

	----------------------------------------------------------------
	-- FLY
	----------------------------------------------------------------
	local function stopFly()
		if flyBV then flyBV:Destroy() flyBV = nil end
		if flyBG then flyBG:Destroy() flyBG = nil end
		local hum = getHum()
		if hum then hum.PlatformStand = false end
	end

	local function startFly()
		local root, hum = getRoot(), getHum()
		if not root or not hum then return end
		stopFly()
		flyBV = create("BodyVelocity", {MaxForce = Vector3.new(1e5, 1e5, 1e5), Velocity = Vector3.zero}, root)
		flyBG = create("BodyGyro", {MaxTorque = Vector3.new(1e5, 1e5, 1e5), P = 1e4, CFrame = root.CFrame}, root)
		hum.PlatformStand = true
	end

	local keyMap = {
		[Enum.KeyCode.W] = "W", [Enum.KeyCode.A] = "A", [Enum.KeyCode.S] = "S",
		[Enum.KeyCode.D] = "D", [Enum.KeyCode.Space] = "Up", [Enum.KeyCode.LeftControl] = "Down",
	}
	table.insert(conns, UserInputService.InputBegan:Connect(function(i, gp)
		if gp then return end
		local k = keyMap[i.KeyCode]
		if k then flyKeys[k] = true end
	end))
	table.insert(conns, UserInputService.InputEnded:Connect(function(i)
		local k = keyMap[i.KeyCode]
		if k then flyKeys[k] = false end
	end))

	----------------------------------------------------------------
	-- AIMBOT (sağ tık basılı tutunca en yakın oyuncuya kilitlenir)
	----------------------------------------------------------------
	local AIM_FOV = 200
	local function getTarget()
		local best, bestDist
		local mousePos = UserInputService:GetMouseLocation()
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LocalPlayer and p.Character then
				local head = p.Character:FindFirstChild("Head")
				local hum = p.Character:FindFirstChildOfClass("Humanoid")
				if head and hum and hum.Health > 0 and not (p.Team and p.Team == LocalPlayer.Team and p.Team ~= nil) then
					local pos, onScreen = Camera:WorldToViewportPoint(head.Position)
					if onScreen then
						local d = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
						if d < AIM_FOV and (not bestDist or d < bestDist) then
							best, bestDist = head, d
						end
					end
				end
			end
		end
		return best
	end

	----------------------------------------------------------------
	-- SİLAH MODLARI (genel yöntem, her oyunda çalışmayabilir)
	----------------------------------------------------------------
	local function patchValue(inst)
		local n = string.lower(inst.Name)
		local isAmmo = n:find("ammo") or n:find("mag") or n:find("clip") or n:find("bullet")
		local isRecoil = n:find("recoil") or n:find("spread") or n:find("kick")
		if inst:IsA("NumberValue") or inst:IsA("IntValue") then
			if state.infAmmo and isAmmo and not n:find("max") then inst.Value = 999 end
			if state.noRecoil and isRecoil then inst.Value = 0 end
		end
	end

	local function patchTool(tool)
		for _, d in ipairs(tool:GetDescendants()) do patchValue(d) end
		patchValue(tool)
		for name, val in pairs(tool:GetAttributes()) do
			local n = string.lower(name)
			if type(val) == "number" then
				if state.infAmmo and (n:find("ammo") or n:find("mag") or n:find("clip")) and not n:find("max") then
					tool:SetAttribute(name, 999)
				end
				if state.noRecoil and (n:find("recoil") or n:find("spread")) then
					tool:SetAttribute(name, 0)
				end
			end
		end
	end

	task.spawn(function()
		while gui.Parent do
			if state.infAmmo or state.noRecoil then
				local char = getChar()
				if char then
					local tool = char:FindFirstChildOfClass("Tool")
					if tool then pcall(patchTool, tool) end
				end
			end
			task.wait(0.25)
		end
	end)

	-- Otomatik ateş: sol tık basılıyken silahı sürekli tetikler
	task.spawn(function()
		while gui.Parent do
			if state.autoFire and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
				local char = getChar()
				local tool = char and char:FindFirstChildOfClass("Tool")
				if tool then pcall(function() tool:Activate() end) end
			end
			task.wait(0.05)
		end
	end)

	-- Geri tepme engelleme (kamera): ateş ederken kamera yukarı kaymasını azaltır
	local lastPitch
	table.insert(conns, RunService.RenderStepped:Connect(function()
		if state.noRecoil and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
			local _, y, _ = Camera.CFrame:ToOrientation()
			local x = select(1, Camera.CFrame:ToOrientation())
			if lastPitch and x > lastPitch + 0.002 then
				Camera.CFrame = CFrame.new(Camera.CFrame.Position) * CFrame.fromOrientation(lastPitch, y, 0)
			else
				lastPitch = x
			end
		else
			lastPitch = nil
		end
	end))

	----------------------------------------------------------------
	-- Ana döngü: fly, hız, aimbot
	----------------------------------------------------------------
	table.insert(conns, RunService.RenderStepped:Connect(function()
		Camera = workspace.CurrentCamera

		-- Hız
		if state.speed then
			local hum = getHum()
			if hum then hum.WalkSpeed = state.speedValue end
		end

		-- Fly
		if state.fly then
			local root = getRoot()
			if root then
				if not flyBV or flyBV.Parent ~= root then startFly() end
				if flyBV and flyBG then
					local cf = Camera.CFrame
					local dir = Vector3.zero
					if flyKeys.W then dir += cf.LookVector end
					if flyKeys.S then dir -= cf.LookVector end
					if flyKeys.D then dir += cf.RightVector end
					if flyKeys.A then dir -= cf.RightVector end
					if flyKeys.Up then dir += Vector3.yAxis end
					if flyKeys.Down then dir -= Vector3.yAxis end
					flyBV.Velocity = dir.Magnitude > 0 and dir.Unit * FLY_SPEED or Vector3.zero
					flyBG.CFrame = cf
				end
			end
		end

		-- Aimbot
		if state.aimbot and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			local target = getTarget()
			if target then
				local goal = CFrame.lookAt(Camera.CFrame.Position, target.Position)
				Camera.CFrame = Camera.CFrame:Lerp(goal, 0.35)
			end
		end
	end))

	----------------------------------------------------------------
	-- Menü elemanları
	----------------------------------------------------------------
	makeToggle("ESP", "esp", refreshESP)
	makeToggle("Fly (WASD/Space/Ctrl)", "fly", function(on)
		if on then startFly() else stopFly() end
	end)
	makeToggle("Aimbot (Sağ Tık)", "aimbot")
	makeToggle("Hız Değiştirici", "speed", function(on)
		if not on then
			local hum = getHum()
			if hum then hum.WalkSpeed = 16 end
		end
	end)

	-- Hız değeri girişi
	local speedBox = create("TextBox", {
		Size = UDim2.new(1, -6, 0, 34), BackgroundColor3 = Color3.fromRGB(30, 30, 42),
		Text = "32", PlaceholderText = "Hız (16-250)", TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.Gotham, TextSize = 14, ClearTextOnFocus = false,
	}, list)
	corner(speedBox, 6)
	speedBox.FocusLost:Connect(function()
		local n = tonumber(speedBox.Text)
		if n then
			state.speedValue = math.clamp(n, 1, 250)
			speedBox.Text = tostring(state.speedValue)
		else
			speedBox.Text = tostring(state.speedValue)
		end
	end)

	makeToggle("Sonsuz Mermi", "infAmmo")
	makeToggle("Otomatik Ateş", "autoFire")
	makeToggle("Geri Tepme Engel", "noRecoil")

	-- Kapatma: her şeyi temizle
	closeBtn.MouseButton1Click:Connect(function()
		for k in pairs(state) do
			if type(state[k]) == "boolean" then state[k] = false end
		end
		refreshESP()
		stopFly()
		local hum = getHum()
		if hum then hum.WalkSpeed = 16 end
		for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
		gui:Destroy()
	end)
end

--------------------------------------------------------------------
-- KEY ARAYÜZÜ (doğru key girilmeden ana script yüklenmez)
--------------------------------------------------------------------
local keyGui = create("ScreenGui", {Name = "NexusCoreKey", ResetOnSpawn = false}, PlayerGui)

local box = create("Frame", {
	Size = UDim2.new(0, 320, 0, 190), Position = UDim2.new(0.5, -160, 0.5, -95),
	BackgroundColor3 = Color3.fromRGB(20, 20, 28), BorderSizePixel = 0,
}, keyGui)
corner(box, 12)

local kTitle = create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Text = "NEXUS CORE",
	TextColor3 = Color3.fromRGB(170, 140, 255), Font = Enum.Font.GothamBold, TextSize = 22,
}, box)
makeDraggable(box, kTitle)

local keyInput = create("TextBox", {
	Size = UDim2.new(1, -40, 0, 38), Position = UDim2.new(0, 20, 0, 55),
	BackgroundColor3 = Color3.fromRGB(35, 35, 50), PlaceholderText = "Key gir...",
	Text = "", TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.Gotham,
	TextSize = 15, ClearTextOnFocus = false,
}, box)
corner(keyInput, 8)

local status = create("TextLabel", {
	Size = UDim2.new(1, -40, 0, 20), Position = UDim2.new(0, 20, 0, 100),
	BackgroundTransparency = 1, Text = "", TextColor3 = Color3.fromRGB(255, 90, 90),
	Font = Enum.Font.Gotham, TextSize = 13,
}, box)

local submit = create("TextButton", {
	Size = UDim2.new(1, -40, 0, 38), Position = UDim2.new(0, 20, 0, 130),
	BackgroundColor3 = Color3.fromRGB(90, 60, 170), Text = "Doğrula",
	TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 15,
}, box)
corner(submit, 8)

local busy = false
local function tryKey()
	if busy then return end
	busy = true
	local ok, valid = pcall(checkKey, keyInput.Text)
	if ok and valid then
		status.TextColor3 = Color3.fromRGB(90, 220, 120)
		status.Text = "Key doğru! Yükleniyor..."
		task.wait(0.6)
		keyGui:Destroy()
		local s, err = pcall(loadMain)
		if not s then warn("Nexus Core hata: " .. tostring(err)) end
	else
		status.TextColor3 = Color3.fromRGB(255, 90, 90)
		status.Text = "Yanlış key!"
		task.wait(1)
		status.Text = ""
		busy = false
	end
end

submit.MouseButton1Click:Connect(tryKey)
keyInput.FocusLost:Connect(function(enter)
	if enter then tryKey() end
end)
