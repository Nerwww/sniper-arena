-- ============================================================
--  Sniper Arena Toolkit — ESP + Aimbot + Misc (Fixed)
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local WS = game:GetService("Workspace")
local LP = Players.LocalPlayer
local Cam = WS.CurrentCamera

local function getGuiParent()
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then return cg end
    if LP and LP:FindFirstChild("PlayerGui") then
        return LP.PlayerGui
    end
    return nil
end

local guiP = getGuiParent()
if not guiP then return end

-- THEME
local Theme = {
    Bg=Color3.fromRGB(22,22,30), PanelBg=Color3.fromRGB(32,32,44),
    RowBg=Color3.fromRGB(42,42,56), RowHover=Color3.fromRGB(58,58,78),
    Accent=Color3.fromRGB(120,130,255), AccentDim=Color3.fromRGB(70,80,180),
    Text=Color3.fromRGB(230,230,240), TextDim=Color3.fromRGB(160,165,180),
    Green=Color3.fromRGB(90,200,120), Red=Color3.fromRGB(220,70,70),
    Yellow=Color3.fromRGB(240,200,80),
}

local Connections = {}
local Killed = false
local function track(c) table.insert(Connections, c); return c end

local function kill()
    if Killed then return end
    Killed = true
    for _, c in ipairs(Connections) do 
        pcall(function() c:Disconnect() end) 
    end
    pcall(function() RunService:UnbindFromRenderStep("SniperCombatCam") end)
    pcall(function() RunService:UnbindFromRenderStep("SniperMisc") end)
    pcall(function() RunService:UnbindFromRenderStep("SniperMouseGuard") end)
    
    local p = getGuiParent()
    if p then
        for _, g in ipairs(p:GetChildren()) do
            if g.Name == "SniperToolkit" or g.Name == "SniperESP"
            or g.Name == "SniperFOV" then
                pcall(function() g:Destroy() end)
            end
        end
    end
    pcall(function()
        UIS.ModalEnabled = false
        UIS.MouseIconEnabled = true
        UIS.MouseBehavior = Enum.MouseBehavior.Default
    end)
    print("[Sniper] Terminated safely.")
end
_G.__SniperKill = kill

-- CONFIG
local Config = {
    ESP = {
        Enabled = true, NPCs = true, Players = true,
        Box = true, Name = true, Distance = true, Health = true,
        MaxDist = 3000,
        NPCColor = Color3.fromRGB(255, 170, 60),
        EnemyColor = Color3.fromRGB(255, 70, 70),
        TeamColor = Color3.fromRGB(80, 220, 130),
    },
    Aimbot = {
        Enabled = false, FOV = 250, Smoothness = 0.25,
        TeamCheck = true, ShowFOV = true,
        TargetPart = "Head",
        WallCheck = false,
    },
    Misc = {
        WalkSpeed = {Enabled = false, Value = 100},
        JumpPower = {Enabled = false, Value = 100},
        Flight = {Enabled = false, Speed = 80},
        NoClip = false,
    },
    UI = { ToggleKey = Enum.KeyCode.RightShift, FreeMouse = true },
}

-- HELPERS
local function getRoot()
    local c = LP and LP.Character
    if not c then return nil end
    return c:FindFirstChild("HumanoidRootPart")
end

local function localPos()
    local r = getRoot()
    return r and r.Position or nil
end

local function viewportCenter()
    if not Cam then Cam = WS.CurrentCamera end
    local vp = Cam and Cam.ViewportSize or Vector2.new(1920,1080)
    return Vector2.new(vp.X*0.5, vp.Y*0.5)
end

-- NPC SCANNER
local NPCContainer = nil
local function getNPCContainer()
    if NPCContainer and NPCContainer.Parent then return NPCContainer end
    local hl = WS:FindFirstChild("Highlight")
    if hl then
        local en = hl:FindFirstChild("Enemy")
        if en then
            local hh = en:FindFirstChild("HighlightHolder")
            if hh then NPCContainer = hh; return hh end
        end
    end
    return nil
end

local function resolveChar(inst)
    if not inst or not inst.Parent then return nil end
    if inst:IsA("Highlight") then
        local ad = inst.Adornee
        if not ad then return nil end
        if ad:IsA("Model") then return ad end
        if ad:IsA("BasePart") then return ad:FindFirstAncestorOfClass("Model") end
        return nil
    end
    if inst:IsA("Model") then
        if inst:FindFirstChildOfClass("Humanoid") then return inst end
        return nil
    end
    if inst:IsA("BasePart") then
        return inst:FindFirstAncestorOfClass("Model")
    end
    return nil
end

local function scanNPCs()
    local list = {}
    local container = getNPCContainer()
    if not container then return list end
    local seen = {}
    local function tryAdd(char)
        if not char or seen[char] or not char.Parent then return end
        seen[char] = true
        local hum = char:FindFirstChildOfClass("Humanoid")
        local head = char:FindFirstChild("Head")
        local root = char:FindFirstChild("HumanoidRootPart")
            or char:FindFirstChild("UpperTorso") or char.PrimaryPart
        if hum and head and root and hum.Health > 0 then
            table.insert(list, {
                Character=char, Humanoid=hum, Head=head, Root=root,
                IsNPC=true, Label="NPC",
            })
        end
    end
    pcall(function()
        for _, d in ipairs(container:GetDescendants()) do tryAdd(resolveChar(d)) end
        for _, c in ipairs(container:GetChildren()) do tryAdd(resolveChar(c)) end
    end)
    return list
end

local function scanPlayers()
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local char = plr.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                local head = char:FindFirstChild("Head")
                local root = char:FindFirstChild("HumanoidRootPart")
                if hum and head and root and hum.Health > 0 then
                    table.insert(list, {
                        Character=char, Humanoid=hum, Head=head, Root=root,
                        Player=plr, IsNPC=false, Label=plr.Name, Team=plr.Team,
                    })
                end
            end
        end
    end
    return list
end

local function scanAll()
    local list = {}
    for _, t in ipairs(scanNPCs()) do table.insert(list, t) end
    for _, t in ipairs(scanPlayers()) do table.insert(list, t) end
    return list
end

-- WALL CHECK
local function hasLineOfSight(fromPos, toPos, target)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true
    local ignore = {}
    if LP.Character then table.insert(ignore, LP.Character) end
    if target and target.Character then table.insert(ignore, target.Character) end
    params.FilterDescendantsInstances = ignore
    local ok, result = pcall(function()
        return WS:Raycast(fromPos, toPos - fromPos, params)
    end)
    return ok and result == nil
end

-- ESP GUI
local ESPGui = Instance.new("ScreenGui")
ESPGui.Name = "SniperESP"
ESPGui.ResetOnSpawn = false
ESPGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ESPGui.IgnoreGuiInset = true
ESPGui.DisplayOrder = 998
ESPGui.Parent = guiP

local espDrawings = {}
local function createESP()
    local d = {}
    d.hl = Instance.new("Highlight")
    d.hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    d.hl.FillTransparency = 0.55
    d.hl.OutlineTransparency = 0
    d.hl.Enabled = false
    d.hl.Parent = ESPGui

    d.box = Instance.new("Frame")
    d.box.BackgroundTransparency = 1
    d.box.BorderSizePixel = 0
    d.box.Visible = false
    d.box.Parent = ESPGui
    local st = Instance.new("UIStroke")
    st.Thickness = 1.5
    st.Color = Color3.fromRGB(255,255,255)
    st.Parent = d.box
    d.stroke = st

    d.name = Instance.new("TextLabel")
    d.name.BackgroundTransparency = 1
    d.name.TextColor3 = Color3.fromRGB(255,255,255)
    d.name.TextStrokeTransparency = 0
    d.name.Font = Enum.Font.GothamBold
    d.name.TextSize = 13
    d.name.Visible = false
    d.name.Parent = ESPGui

    d.dist = Instance.new("TextLabel")
    d.dist.BackgroundTransparency = 1
    d.dist.TextColor3 = Color3.fromRGB(220,220,220)
    d.dist.TextStrokeTransparency = 0
    d.dist.Font = Enum.Font.Gotham
    d.dist.TextSize = 11
    d.dist.Visible = false
    d.dist.Parent = ESPGui

    d.hpBg = Instance.new("Frame")
    d.hpBg.BackgroundColor3 = Color3.fromRGB(30,30,30)
    d.hpBg.BorderSizePixel = 0
    d.hpBg.Visible = false
    d.hpBg.Parent = ESPGui

    d.hpFill = Instance.new("Frame")
    d.hpFill.BackgroundColor3 = Color3.fromRGB(90,220,90)
    d.hpFill.BorderSizePixel = 0
    d.hpFill.Visible = false
    d.hpFill.Parent = ESPGui

    return d
end

local function hideESP(d)
    if not d then return end
    pcall(function()
        d.hl.Enabled = false
        d.box.Visible = false
        d.name.Visible = false
        d.dist.Visible = false
        d.hpBg.Visible = false
        d.hpFill.Visible = false
    end)
end

local function getESP(char)
    local d = espDrawings[char]
    if not d then 
        d = createESP()
        espDrawings[char] = d 
    end
    return d
end

local function updateESP()
    if Killed then return end
    if not Cam or not Cam.Parent then Cam = WS.CurrentCamera end
    if not Cam then return end
    
    if not Config.ESP.Enabled then
        for _, d in pairs(espDrawings) do hideESP(d) end
        return
    end
    
    local lPos = localPos()
    if not lPos then
        for _, d in pairs(espDrawings) do hideESP(d) end
        return
    end
    
    local seen = {}
    local targets = scanAll()
    
    for _, t in ipairs(targets) do
        if t and t.Character and t.Character.Parent then
            if (t.IsNPC and Config.ESP.NPCs) or (not t.IsNPC and Config.ESP.Players) then
                seen[t.Character] = true
                local d = getESP(t.Character)
                if t.Root and t.Head then
                    local dist = (t.Root.Position - lPos).Magnitude
                    if dist <= Config.ESP.MaxDist then
                        local top = t.Head.Position + Vector3.new(0, 0.6, 0)
                        local bot = t.Root.Position - Vector3.new(0, 3, 0)
                        local ts, on1 = Cam:WorldToViewportPoint(top)
                        local bs, on2 = Cam:WorldToViewportPoint(bot)
                        if on1 and on2 and ts.Z > 0 and bs.Z > 0 then
                            local h = math.abs(bs.Y - ts.Y)
                            local w = math.max(h * 0.55, 12)
                            local x = ts.X - w * 0.5
                            local y = ts.Y
                            local col
                            if t.IsNPC then
                                col = Config.ESP.NPCColor
                            elseif t.Player and LP.Team and t.Team and t.Team == LP.Team then
                                col = Config.ESP.TeamColor
                            else
                                col = Config.ESP.EnemyColor
                            end
                            d.hl.Adornee = t.Character
                            d.hl.FillColor = col
                            d.hl.OutlineColor = Color3.fromRGB(255,255,255)
                            d.hl.Enabled = true
                            d.box.Visible = Config.ESP.Box
                            d.box.Position = UDim2.fromOffset(x, y)
                            d.box.Size = UDim2.fromOffset(w, h)
                            d.stroke.Color = col
                            d.name.Visible = Config.ESP.Name
                            d.name.Text = t.IsNPC and "NPC" or t.Label
                            d.name.TextColor3 = col
                            d.name.Position = UDim2.fromOffset(ts.X - 100, y - 18)
                            d.name.Size = UDim2.fromOffset(200, 14)
                            d.name.TextXAlignment = Enum.TextXAlignment.Center
                            d.dist.Visible = Config.ESP.Distance
                            d.dist.Text = string.format("[%dm]", math.floor(dist))
                            d.dist.Position = UDim2.fromOffset(ts.X - 100, y + h + 2)
                            d.dist.Size = UDim2.fromOffset(200, 12)
                            d.dist.TextXAlignment = Enum.TextXAlignment.Center
                            if Config.ESP.Health and t.Humanoid then
                                local hp = math.clamp(t.Humanoid.Health / math.max(t.Humanoid.MaxHealth, 1), 0, 1)
                                d.hpBg.Visible = true
                                d.hpBg.Position = UDim2.fromOffset(x - 6, y)
                                d.hpBg.Size = UDim2.fromOffset(3, h)
                                d.hpFill.Visible = true
                                d.hpFill.Position = UDim2.fromOffset(x - 6, y + h * (1 - hp))
                                d.hpFill.Size = UDim2.fromOffset(3, h * hp)
                                d.hpFill.BackgroundColor3 = Color3.fromRGB(
                                    math.floor(255*(1-hp)), math.floor(255*hp), 0)
                            else
                                d.hpBg.Visible = false
                                d.hpFill.Visible = false
                            end
                        else hideESP(d) end
                    else hideESP(d) end
                else hideESP(d) end
            end
        end
    end
    
    for char, d in pairs(espDrawings) do
        if not seen[char] or not char.Parent then
            hideESP(d)
            if not char.Parent then
                for _, part in pairs(d) do
                    if typeof(part) == "Instance" then
                        pcall(function() part:Destroy() end)
                    end
                end
                espDrawings[char] = nil
            end
        end
    end
end

-- AIMBOT
local function aimCameraAt(target, part, smoothness)
    if not target or not part or not part.Parent then return false end
    if not Cam or not Cam.Parent then Cam = WS.CurrentCamera end
    if not Cam then return false end
    local ok = pcall(function()
        local goal = CFrame.new(Cam.CFrame.Position, part.Position)
        Cam.CFrame = Cam.CFrame:Lerp(goal, smoothness)
    end)
    return ok
end

local function findBestTarget()
    if not Cam or not Cam.Parent then Cam = WS.CurrentCamera end
    if not Cam then return nil end
    local center = viewportCenter()
    local best, bestD = nil, math.huge
    local lPos = localPos()
    if not lPos then return nil end
    local camPos = Cam.CFrame.Position
    
    for _, t in ipairs(scanAll()) do
        if t and t.Character and t.Character.Parent then
            if t.IsNPC or not (LP.Team and t.Team and t.Team == LP.Team) then
                local part = Config.Aimbot.TargetPart == "Head" and t.Head or t.Root
                if part and part.Parent then
                    local sp, on = Cam:WorldToViewportPoint(part.Position)
                    if on and sp.Z > 0 then
                        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                        if d <= Config.Aimbot.FOV and d < bestD then
                            local pass = true
                            if Config.Aimbot.WallCheck then
                                pass = hasLineOfSight(camPos, part.Position, t)
                            end
                            if pass then
                                bestD = d; best = t
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

local function updateAimbot()
    if Killed or not Config.Aimbot.Enabled then return end
    pcall(function()
        if not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
        if UIS:GetFocusedTextBox() then return end
        local target = findBestTarget()
        if not target then return end
        local part = Config.Aimbot.TargetPart == "Head" and target.Head or target.Root
        aimCameraAt(target, part, Config.Aimbot.Smoothness)
    end)
end

-- FOV circle
local fovGui = Instance.new("ScreenGui")
fovGui.Name = "SniperFOV"
fovGui.ResetOnSpawn = false
fovGui.IgnoreGuiInset = true
fovGui.DisplayOrder = 999
fovGui.Parent = guiP

local fovCircle = Instance.new("Frame")
fovCircle.BackgroundTransparency = 1
fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
fovCircle.Visible = false
fovCircle.Parent = fovGui
local fovCorner = Instance.new("UICorner")
fovCorner.CornerRadius = UDim.new(1, 0)
fovCorner.Parent = fovCircle
local fovStroke = Instance.new("UIStroke")
fovStroke.Thickness = 1.5
fovStroke.Color = Theme.Accent
fovStroke.Parent = fovCircle

local function updateFOVCircle()
    if Killed then return end
    if not Cam then Cam = WS.CurrentCamera end
    local vp = Cam and Cam.ViewportSize or Vector2.new(1920,1080)
    fovCircle.Visible = Config.Aimbot.Enabled and Config.Aimbot.ShowFOV
    if fovCircle.Visible then
        local d = Config.Aimbot.FOV * 2
        fovCircle.Position = UDim2.fromOffset(vp.X/2, vp.Y/2)
        fovCircle.Size = UDim2.fromOffset(d, d)
    end
end

-- MISC (flight state)
local FlightBV = nil
local function flightStart()
    local char = LP and LP.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end
    pcall(function() hum.PlatformStand = true end)
    if not FlightBV or FlightBV.Parent ~= hrp then
        if FlightBV then pcall(function() FlightBV:Destroy() end) end
        FlightBV = Instance.new("BodyVelocity")
        FlightBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        FlightBV.Velocity = Vector3.zero
        FlightBV.P = 1000
        FlightBV.Parent = hrp
    end
end

local function flightStop()
    if FlightBV then 
        pcall(function() FlightBV:Destroy() end) 
        FlightBV = nil 
    end
    local char = LP and LP.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum.PlatformStand = false end) end
    end
end

local function updateMisc()
    if Killed then return end
    pcall(function()
        local char = LP and LP.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum then return end

        if Config.Misc.WalkSpeed.Enabled then
            hum.WalkSpeed = Config.Misc.WalkSpeed.Value
        end

        if Config.Misc.JumpPower.Enabled then
            hum.UseJumpPower = true
            hum.JumpPower = Config.Misc.JumpPower.Value
        end

        if Config.Misc.NoClip then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then
                    p.CanCollide = false
                end
            end
        end

        if Config.Misc.Flight.Enabled then
            if not FlightBV or not hrp then
                flightStart()
            end
            if FlightBV and hrp then
                local cam = WS.CurrentCamera
                if cam then
                    local move = Vector3.zero
                    local speed = Config.Misc.Flight.Speed
                    if UIS:IsKeyDown(Enum.KeyCode.W) then move = move + cam.CFrame.LookVector end
                    if UIS:IsKeyDown(Enum.KeyCode.S) then move = move - cam.CFrame.LookVector end
                    if UIS:IsKeyDown(Enum.KeyCode.A) then move = move - cam.CFrame.RightVector end
                    if UIS:IsKeyDown(Enum.KeyCode.D) then move = move + cam.CFrame.RightVector end
                    if UIS:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0,1,0) end
                    if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then move = move - Vector3.new(0,1,0) end
                    if move.Magnitude > 0 then move = move.Unit * speed end
                    FlightBV.Velocity = move
                end
            end
        else
            if FlightBV then flightStop() end
        end
    end)
end

-- GUI
for _, g in ipairs(guiP:GetChildren()) do
    if g.Name == "SniperToolkit" then pcall(function() g:Destroy() end) end
end
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SniperToolkit"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 1000
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = guiP

local function newFrame(parent, props, cn)
    local inst = Instance.new(cn or "Frame")
    for k, v in pairs(props) do inst[k] = v end
    inst.Parent = parent
    return inst
end

local function initToolkit()
    local Window = newFrame(ScreenGui, {
        Size=UDim2.new(0, 440, 0, 520),
        Position=UDim2.new(0.5, -220, 0.5, -260),
        BackgroundColor3=Theme.Bg, BorderSizePixel=0,
        Active=true, Draggable=true, ZIndex=1,
    })
    newFrame(Window, {CornerRadius=UDim.new(0,12)}, "UICorner")
    newFrame(Window, {Color=Theme.Accent, Thickness=2}, "UIStroke")

    newFrame(Window, {
        Size=UDim2.new(1,-50,0,30), Position=UDim2.new(0,14,0,6),
        BackgroundTransparency=1, Text="Sniper Arena Toolkit",
        TextColor3=Theme.Accent, Font=Enum.Font.GothamBold, TextSize=16,
        TextXAlignment=Enum.TextXAlignment.Left, ZIndex=5,
    }, "TextLabel")

    local CloseBtn = newFrame(Window, {
        Size=UDim2.new(0,26,0,26), Position=UDim2.new(1,-34,0,8),
        BackgroundColor3=Theme.Red, BorderSizePixel=0, Text="X",
        TextColor3=Color3.fromRGB(255,255,255),
        Font=Enum.Font.GothamBold, TextSize=14, ZIndex=50,
    }, "TextButton")
    newFrame(CloseBtn, {CornerRadius=UDim.new(0,6)}, "UICorner")
    CloseBtn.MouseButton1Down:Connect(function() kill() end)

    local TabBar = newFrame(Window, {
        Size=UDim2.new(1,-20,0,30), Position=UDim2.new(0,10,0,40),
        BackgroundColor3=Theme.PanelBg, BorderSizePixel=0, ZIndex=2,
    })
    newFrame(TabBar, {CornerRadius=UDim.new(0,6)}, "UICorner")
    newFrame(TabBar, {
        Padding=UDim.new(0,2), SortOrder=Enum.SortOrder.LayoutOrder,
        FillDirection=Enum.FillDirection.Horizontal,
        HorizontalAlignment=Enum.HorizontalAlignment.Center,
        VerticalAlignment=Enum.VerticalAlignment.Center,
    }, "UIListLayout")

    local Content = newFrame(Window, {
        Size=UDim2.new(1,-20,1,-130), Position=UDim2.new(0,10,0,76),
        BackgroundTransparency=1, ZIndex=2,
    })

    local tabs = {}
    local function createTab(name)
        local btn = newFrame(TabBar, {
            Size=UDim2.new(1/4,-2,1,-6), BackgroundColor3=Theme.RowBg,
            BorderSizePixel=0, Text=name, TextColor3=Theme.TextDim,
            Font=Enum.Font.GothamBold, TextSize=11,
            AutoButtonColor=false, ZIndex=3,
        }, "TextButton")
        newFrame(btn, {CornerRadius=UDim.new(0,5)}, "UICorner")
        local scroll = newFrame(Content, {
            Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
            CanvasSize=UDim2.new(0,0,0,0),
            AutomaticCanvasSize=Enum.AutomaticSize.Y,
            ScrollBarThickness=5, Visible=false,
        }, "ScrollingFrame")
        newFrame(scroll, {Padding=UDim.new(0,6),
            SortOrder=Enum.SortOrder.LayoutOrder}, "UIListLayout")
        local function activate()
            for _, t in pairs(tabs) do
                t.Scroll.Visible = false
                t.Button.BackgroundColor3 = Theme.RowBg
                t.Button.TextColor3 = Theme.TextDim
            end
            scroll.Visible = true
            btn.BackgroundColor3 = Theme.Accent
            btn.TextColor3 = Color3.fromRGB(20,20,30)
        end
        btn.MouseButton1Click:Connect(activate)
        tabs[name] = {Button=btn, Scroll=scroll, Activate=activate}
        return tabs[name]
    end

    local function createSection(parent, title)
        local f = newFrame(parent, {
            Size=UDim2.new(1,0,0,0),
            AutomaticSize=Enum.AutomaticSize.Y,
            BackgroundColor3=Theme.PanelBg, BorderSizePixel=0,
        })
        newFrame(f, {CornerRadius=UDim.new(0,6)}, "UICorner")
        newFrame(f, {
            PaddingTop=UDim.new(0,6), PaddingBottom=UDim.new(0,6),
            PaddingLeft=UDim.new(0,6), PaddingRight=UDim.new(0,6),
        }, "UIPadding")
        newFrame(f, {Padding=UDim.new(0,6),
            SortOrder=Enum.SortOrder.LayoutOrder}, "UIListLayout")
        newFrame(f, {
            Size=UDim2.new(1,0,0,22), BackgroundTransparency=1,
            Text=title, TextColor3=Theme.Accent,
            Font=Enum.Font.GothamBold, TextSize=13,
            TextXAlignment=Enum.TextXAlignment.Left, LayoutOrder=0,
        }, "TextLabel")
        return f
    end

    local function createToggle(parent, props)
        local f = newFrame(parent, {
            Size=UDim2.new(1,0,0,32), BackgroundColor3=Theme.RowBg,
            BorderSizePixel=0,
        })
        newFrame(f, {CornerRadius=UDim.new(0,6)}, "UICorner")
        newFrame(f, {
            Size=UDim2.new(0.6,0,1,0), Position=UDim2.new(0,10,0,0),
            BackgroundTransparency=1, Text=props.Name,
            TextColor3=Theme.Text, Font=Enum.Font.Gotham, TextSize=12,
            TextXAlignment=Enum.TextXAlignment.Left,
        }, "TextLabel")
        local bg = newFrame(f, {
            Size=UDim2.new(0,40,0,20), Position=UDim2.new(1,-50,0.5,-10),
            BackgroundColor3=Theme.RowBg, BorderSizePixel=0,
        })
        newFrame(bg, {CornerRadius=UDim.new(0,10)}, "UICorner")
        local handle = newFrame(bg, {
            Size=UDim2.new(0,16,0,16), Position=UDim2.new(0,2,0.5,-8),
            BackgroundColor3=Color3.fromRGB(255,255,255), BorderSizePixel=0,
        })
        newFrame(handle, {CornerRadius=UDim.new(1,0)}, "UICorner")
        local on = props.Default or false
        local function upd(s)
            on = s
            handle.Position = UDim2.new(0, s and 22 or 2, 0.5, -8)
            bg.BackgroundColor3 = s and Theme.Accent or Theme.RowBg
            if props.OnChange then pcall(function() props.OnChange(s) end) end
        end
        bg.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
                upd(not on)
            end
        end)
        upd(on)
        return f
    end

    local function createSlider(parent, props)
        local f = newFrame(parent, {
            Size=UDim2.new(1,0,0,38), BackgroundColor3=Theme.RowBg,
            BorderSizePixel=0,
        })
        newFrame(f, {CornerRadius=UDim.new(0,6)}, "UICorner")
        newFrame(f, {
            Size=UDim2.new(0.4,-10,1,0), Position=UDim2.new(0,10,0,0),
            BackgroundTransparency=1, Text=props.Name,
            TextColor3=Theme.Text, Font=Enum.Font.Gotham, TextSize=12,
            TextXAlignment=Enum.TextXAlignment.Left,
        }, "TextLabel")
        local vLbl = newFrame(f, {
            Size=UDim2.new(0.2,-10,1,0), Position=UDim2.new(0.8,0,0,0),
            BackgroundTransparency=1,
            Text=string.format("%.0f", props.Default),
            TextColor3=Theme.Accent, Font=Enum.Font.GothamBold, TextSize=12,
            TextXAlignment=Enum.TextXAlignment.Right,
        }, "TextLabel")
        local bg = newFrame(f, {
            Size=UDim2.new(0.35,-10,0,6), Position=UDim2.new(0.45,0,0.5,-3),
            BackgroundColor3=Theme.PanelBg, BorderSizePixel=0,
        })
        newFrame(bg, {CornerRadius=UDim.new(0,3)}, "UICorner")
        local r0 = (props.Default - props.Min) / (props.Max - props.Min)
        local fill = newFrame(bg, {
            Size=UDim2.new(r0,0,1,0), BackgroundColor3=Theme.Accent,
            BorderSizePixel=0,
        })
        newFrame(fill, {CornerRadius=UDim.new(0,3)}, "UICorner")
        local handle = newFrame(bg, {
            Size=UDim2.new(0,12,0,12), Position=UDim2.new(r0,-6,0.5,-6),
            BackgroundColor3=Color3.fromRGB(255,255,255), BorderSizePixel=0,
        })
        newFrame(handle, {CornerRadius=UDim.new(1,0)}, "UICorner")
        local drag, sX = false, 0
        local curV = props.Default
        handle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
                drag = true; sX = input.Position.X; sV = curV
            end
        end)
        handle.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then drag = false end
        end)
        track(UIS.InputChanged:Connect(function(input)
            if not drag then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
            local rng = bg.AbsoluteSize.X
            if rng <= 0 then return end
            local nv = math.clamp(
                curV + (input.Position.X - sX)/rng*(props.Max-props.Min),
                props.Min, props.Max)
            curV = nv
            local ratio = (nv - props.Min)/(props.Max - props.Min)
            fill.Size = UDim2.new(ratio,0,1,0)
            handle.Position = UDim2.new(ratio,-6,0.5,-6)
            vLbl.Text = string.format("%.0f", nv)
            if props.OnChange then pcall(function() props.OnChange(nv) end) end
        end))
        return f
    end

    local function createCycler(parent, props)
        local f = newFrame(parent, {
            Size=UDim2.new(1,0,0,32), BackgroundColor3=Theme.RowBg,
            BorderSizePixel=0,
        })
        newFrame(f, {CornerRadius=UDim.new(0,6)}, "UICorner")
        newFrame(f, {
            Size=UDim2.new(0.5,0,1,0), Position=UDim2.new(0,10,0,0),
            BackgroundTransparency=1, Text=props.Name,
            TextColor3=Theme.Text, Font=Enum.Font.Gotham, TextSize=12,
            TextXAlignment=Enum.TextXAlignment.Left,
        }, "TextLabel")
        local btn = newFrame(f, {
            Size=UDim2.new(0.4,-10,0,22), Position=UDim2.new(0.6,0,0.5,-11),
            BackgroundColor3=Theme.AccentDim, BorderSizePixel=0,
            Text=props.Default, TextColor3=Color3.fromRGB(255,255,255),
            Font=Enum.Font.GothamBold, TextSize=12, AutoButtonColor=true,
        }, "TextButton")
        newFrame(btn, {CornerRadius=UDim.new(0,5)}, "UICorner")
        local idx = 1
        for i, v in ipairs(props.Options) do
            if v == props.Default then idx = i break end
        end
        btn.MouseButton1Click:Connect(function()
            idx = idx % #props.Options + 1
            local v = props.Options[idx]
            btn.Text = v
            if props.OnChange then pcall(function() props.OnChange(v) end) end
        end)
        return f
    end

    local function createKeybind(parent, props)
        local f = newFrame(parent, {
            Size=UDim2.new(1,0,0,32), BackgroundColor3=Theme.RowBg,
            BorderSizePixel=0,
        })
        newFrame(f, {CornerRadius=UDim.new(0,6)}, "UICorner")
        newFrame(f, {
            Size=UDim2.new(0.5,0,1,0), Position=UDim2.new(0,10,0,0),
            BackgroundTransparency=1, Text=props.Name,
            TextColor3=Theme.Text, Font=Enum.Font.Gotham, TextSize=12,
            TextXAlignment=Enum.TextXAlignment.Left,
        }, "TextLabel")
        local btn = newFrame(f, {
            Size=UDim2.new(0.4,-10,0,22), Position=UDim2.new(0.6,0,0.5,-11),
            BackgroundColor3=Theme.AccentDim, BorderSizePixel=0,
            Text=props.Default.Name, TextColor3=Color3.fromRGB(255,255,255),
            Font=Enum.Font.GothamBold, TextSize=12, AutoButtonColor=true,
        }, "TextButton")
        newFrame(btn, {CornerRadius=UDim.new(0,5)}, "UICorner")
        local listening = false
        btn.MouseButton1Click:Connect(function()
            listening = true
            btn.Text = "press a key..."
            btn.BackgroundColor3 = Theme.Accent
        end)
        track(UIS.InputBegan:Connect(function(input)
            if not listening then return end
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            listening = false
            btn.BackgroundColor3 = Theme.AccentDim
            if input.KeyCode == Enum.KeyCode.Escape then
                btn.Text = props.Default.Name; return
            end
            props.Default = input.KeyCode
            btn.Text = input.KeyCode.Name
            if props.OnChange then pcall(function() props.OnChange(input.KeyCode) end) end
        end))
        return f
    end

    local function createCheckbox(parent, props)
        local f = newFrame(parent, {
            Size=UDim2.new(1,0,0,32), BackgroundColor3=Theme.RowBg,
            BorderSizePixel=0,
        })
        newFrame(f, {CornerRadius=UDim.new(0,6)}, "UICorner")
        newFrame(f, {
            Size=UDim2.new(0.7,0,1,0), Position=UDim2.new(0,10,0,0),
            BackgroundTransparency=1, Text=props.Name,
            TextColor3=Theme.Text, Font=Enum.Font.Gotham, TextSize=12,
            TextXAlignment=Enum.TextXAlignment.Left,
        }, "TextLabel")
        local box = newFrame(f, {
            Size=UDim2.new(0,20,0,20), Position=UDim2.new(1,-30,0.5,-10),
            BackgroundColor3=Theme.RowBg, BorderSizePixel=0,
            Text="", TextTransparency=1,
        }, "TextButton")
        newFrame(box, {CornerRadius=UDim.new(0,4)}, "UICorner")
        local stroke = newFrame(box,
            {Color=Theme.TextDim, Thickness=1.5}, "UIStroke")
        local check = newFrame(box, {
            Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
            Text="✓", TextColor3=Color3.fromRGB(20,20,30),
            Font=Enum.Font.GothamBold, TextSize=14, Visible=false,
        }, "TextLabel")
        local checked = props.Default or false
        local function upd(s)
            checked = s
            check.Visible = s
            box.BackgroundColor3 = s and Theme.Accent or Theme.RowBg
            stroke.Color = s and Theme.Accent or Theme.TextDim
            if props.OnChange then pcall(function() props.OnChange(s) end) end
        end
        box.MouseButton1Click:Connect(function() upd(not checked) end)
        upd(checked)
        return f
    end

    -- Visual Tab
    local VisualTab = createTab("Visual")
    local espSec = createSection(VisualTab.Scroll, "ESP")
    createToggle(espSec, {Name="Enable ESP", Default=true, OnChange=function(v) Config.ESP.Enabled = v end})
    createToggle(espSec, {Name="Show NPCs", Default=true, OnChange=function(v) Config.ESP.NPCs = v end})
    createToggle(espSec, {Name="Show Players", Default=true, OnChange=function(v) Config.ESP.Players = v end})
    createToggle(espSec, {Name="Box", Default=true, OnChange=function(v) Config.ESP.Box = v end})
    createToggle(espSec, {Name="Name", Default=true, OnChange=function(v) Config.ESP.Name = v end})
    createToggle(espSec, {Name="Distance", Default=true, OnChange=function(v) Config.ESP.Distance = v end})
    createToggle(espSec, {Name="Health Bar", Default=true, OnChange=function(v) Config.ESP.Health = v end})
    createSlider(espSec, {Name="Max Distance", Min=100, Max=5000, Default=3000, OnChange=function(v) Config.ESP.MaxDist = v end})

    -- Aimbot Tab
    local CombatTab = createTab("Aimbot")
    local aimSec = createSection(CombatTab.Scroll, "Aimbot (hold RMB)")
    createToggle(aimSec, {Name="Enable Aimbot", Default=false, OnChange=function(v) Config.Aimbot.Enabled = v end})
    createSlider(aimSec, {Name="FOV", Min=20, Max=800, Default=250, OnChange=function(v) Config.Aimbot.FOV = v end})
    createSlider(aimSec, {Name="Smoothness (x100)", Min=5, Max=100, Default=25, OnChange=function(v) Config.Aimbot.Smoothness = v / 100 end})
    createCycler(aimSec, {Name="Target Part", Options={"Head","HumanoidRootPart"}, Default="Head", OnChange=function(v) Config.Aimbot.TargetPart = v end})
    createToggle(aimSec, {Name="Team Check", Default=true, OnChange=function(v) Config.Aimbot.TeamCheck = v end})
    createToggle(aimSec, {Name="Wall Check", Default=false, OnChange=function(v) Config.Aimbot.WallCheck = v end})
    createToggle(aimSec, {Name="Show FOV Circle", Default=true, OnChange=function(v) Config.Aimbot.ShowFOV = v end})

    -- Misc Tab
    local MiscTab = createTab("Misc")
    local moveSec = createSection(MiscTab.Scroll, "Movement")
    createToggle(moveSec, {Name="Custom WalkSpeed", Default=false, OnChange=function(v) Config.Misc.WalkSpeed.Enabled = v end})
    createSlider(moveSec, {Name="WalkSpeed", Min=16, Max=500, Default=100, OnChange=function(v) Config.Misc.WalkSpeed.Value = v end})
    createToggle(moveSec, {Name="Custom JumpPower", Default=false, OnChange=function(v) Config.Misc.JumpPower.Enabled = v end})
    createSlider(moveSec, {Name="JumpPower", Min=50, Max=500, Default=100, OnChange=function(v) Config.Misc.JumpPower.Value = v end})
    createToggle(moveSec, {Name="NoClip", Default=false, OnChange=function(v) Config.Misc.NoClip = v end})

    local flySec = createSection(MiscTab.Scroll, "Flight")
    createToggle(flySec, {Name="Enable Flight", Default=false, OnChange=function(v) Config.Misc.Flight.Enabled = v end})
    createSlider(flySec, {Name="Flight Speed", Min=10, Max=500, Default=80, OnChange=function(v) Config.Misc.Flight.Speed = v end})
    newFrame(flySec, {
        Size=UDim2.new(1,0,0,32), BackgroundTransparency=1,
        Text="WASD to move  •  Space to rise\nLeft-Ctrl to descend",
        TextColor3=Theme.TextDim, Font=Enum.Font.Gotham, TextSize=10,
        TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Top,
    }, "TextLabel")

    -- Settings Tab
    local SetTab = createTab("Settings")
    local kbSec = createSection(SetTab.Scroll, "Keybinds")
    createKeybind(kbSec, {Name="Menu Toggle", Default=Config.UI.ToggleKey, OnChange=function(k) Config.UI.ToggleKey = k end})
    local mouseSec = createSection(SetTab.Scroll, "Mouse")
    createCheckbox(mouseSec, {Name="Free Mouse While Open", Default=true, OnChange=function(v) Config.UI.FreeMouse = v end})

    VisualTab.Activate()

    -- LOOPS
    track(RunService.RenderStepped:Connect(function()
        if Killed then return end
        updateESP()
        updateFOVCircle()
    end))

    pcall(function() RunService:UnbindFromRenderStep("SniperCombatCam") end)
    track(RunService:BindToRenderStep("SniperCombatCam", Enum.RenderPriority.Camera.Value + 5, function()
        if Killed then return end
        updateAimbot()
    end))

    pcall(function() RunService:UnbindFromRenderStep("SniperMisc") end)
    track(RunService:BindToRenderStep("SniperMisc", Enum.RenderPriority.Character.Value + 1, function()
        if Killed then return end
        updateMisc()
    end))

    -- Menu toggle
    local menuOpen = true
    local function applyMouseMode()
        if Killed then return end
        pcall(function()
            if menuOpen and Config.UI.FreeMouse then
                UIS.ModalEnabled = true
                UIS.MouseIconEnabled = true
                UIS.MouseBehavior = Enum.MouseBehavior.Default
            else
                UIS.ModalEnabled = false
                UIS.MouseIconEnabled = false
                UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
            end
        end)
    end
    
    track(UIS.InputBegan:Connect(function(input)
        if Killed then return end
        if input.KeyCode ~= Config.UI.ToggleKey then return end
        if UIS:GetFocusedTextBox() then return end
        menuOpen = not menuOpen
        ScreenGui.Enabled = menuOpen
        applyMouseMode()
    end))
    
    track(RunService:BindToRenderStep("SniperMouseGuard", Enum.RenderPriority.Camera.Value + 1, function()
        if Killed or not menuOpen or not Config.UI.FreeMouse then return end
        pcall(function()
            UIS.ModalEnabled = true
            UIS.MouseIconEnabled = true
            if UIS.MouseBehavior ~= Enum.MouseBehavior.Default then
                UIS.MouseBehavior = Enum.MouseBehavior.Default
            end
        end)
    end))
    
    applyMouseMode()
end

initToolkit()

print("[Sniper] Loaded safely.")
