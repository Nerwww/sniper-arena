-- ============================================================
--  Optimized Sniper Arena Toolkit (Clean Rewrite)
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Подключаем библиотеку интерфейсов (Linoria Lib)
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua"))()
local ThemeManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/SaveManager.lua"))()

-- Настройки (Config)
local Options = {
    ESP_Enabled = true,
    ESP_Boxes = true,
    ESP_Names = true,
    ESP_Health = true,
    ESP_Distance = true,
    MaxDist = 3000,
    
    Aimbot_Enabled = true,
    Aimbot_Key = Enum.UserInputType.MouseButton2, -- Зажатие ПКМ
    Aimbot_FOV = 250,
    Aimbot_Smoothness = 0.15, -- Плавность (чем меньше, тем быстрее ведет, но без дерготни)
    Aimbot_TargetPart = "Head",
    TeamCheck = true,
    WallCheck = false,
}

-- Создание окна интерфейса
local Window = Library:CreateWindow({
    Title = 'Sniper Arena Toolkit | Optimized',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

-- Вкладки
local Tabs = {
    Visuals = Window:AddTab('Visuals (ESP)'),
    Combat = Window:AddTab('Combat (Aimbot)'),
    Settings = Window:AddTab('UI Settings'),
}

-- Секция ESP
local ESPGroupBox = Tabs.Visuals:AddLeftGroupbox('ESP Settings')
ESPGroupBox:AddToggle('ESP_Enabled', { Text = 'Enable ESP', Default = true }):OnChanged(function(v) Options.ESP_Enabled = v end)
ESPGroupBox:AddToggle('ESP_Boxes', { Text = 'Boxes', Default = true }):OnChanged(function(v) Options.ESP_Boxes = v end)
ESPGroupBox:AddToggle('ESP_Names', { Text = 'Names', Default = true }):OnChanged(function(v) Options.ESP_Names = v end)
ESPGroupBox:AddToggle('ESP_Health', { Text = 'Health Bar', Default = true }):OnChanged(function(v) Options.ESP_Health = v end)
ESPGroupBox:AddToggle('ESP_Distance', { Text = 'Distance', Default = true }):OnChanged(function(v) Options.ESP_Distance = v end)
ESPGroupBox:AddSlider('MaxDist', { Text = 'Max Distance', Default = 3000, Min = 100, Max = 5000, Step = 50 }):OnChanged(function(v) Options.MaxDist = v end)

-- Секция Aimbot
local AimbotGroupBox = Tabs.Combat:AddLeftGroupbox('Aimbot Settings')
AimbotGroupBox:AddToggle('Aimbot_Enabled', { Text = 'Enable Aimbot', Default = true }):OnChanged(function(v) Options.Aimbot_Enabled = v end)
AimbotGroupBox:AddSlider('Aimbot_FOV', { Text = 'FOV Radius', Default = 250, Min = 20, Max = 800, Step = 5 }):OnChanged(function(v) Options.Aimbot_FOV = v end)
AimbotGroupBox:AddSlider('Aimbot_Smoothness', { Text = 'Smoothness', Default = 0.15, Min = 0.01, Max = 1, Step = 0.01 }):OnChanged(function(v) Options.Aimbot_Smoothness = v end)
AimbotGroupBox:AddDropdown('Aimbot_TargetPart', { Text = 'Target Part', Values = {'Head', 'HumanoidRootPart'}, Default = 1 }):OnChanged(function(v) Options.Aimbot_TargetPart = v end)
AimbotGroupBox:AddToggle('TeamCheck', { Text = 'Team Check', Default = true }):OnChanged(function(v)
