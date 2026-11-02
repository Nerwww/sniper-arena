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
        local goal = CFrame
