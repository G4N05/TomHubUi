-- ============================================================
-- AutomaHub | LOADING SCREEN (Load.lua)
-- ------------------------------------------------------------
-- Niru referensi three.js (gear/gerigi muter, monokrom).
-- Roblox ga bisa jalanin three.js (itu WebGL/JS), jadi gue
-- bikin ulang pake UI Luau: gear muter (Rotation + RenderStepped),
-- layar di-BLUR, + progress bar di bawah.
--
-- Dipakai 2 cara:
--  1) STANDALONE (preview): paste di executor -> jalan demo
--     progress 0->100 terus fade out.
--  2) MODULE (buat digabung): set getgenv().AutomaHubLoaderModule = true
--     SEBELUM loadstring, terus pake tabel Loader yang di-return:
--        local Loader = loadstring(game:HttpGet(URL))()
--        local L = Loader.new()
--        L:setStatus("Loading menu...")
--        L:setProgress(0.5)
--        L:finish(function() --[[ load menu di sini ]] end)
-- ============================================================

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local Lighting         = game:GetService("Lighting")

-- ====== PALETTE (monokrom, no biru) ======
local COL = {
    overlay = Color3.fromRGB(10, 8, 18),
    gear1   = Color3.fromRGB(96, 96, 102),   -- main  (three.js 0x444444)
    gear2   = Color3.fromRGB(134, 134, 140),  -- small (0x666666)
    gear3   = Color3.fromRGB(114, 114, 120),  -- med   (0x555555)
    gear4   = Color3.fromRGB(74, 74, 80),     -- tiny  (0x333333)
    rim     = Color3.fromRGB(160, 160, 168),  -- highlight tipis di rim
    track   = Color3.fromRGB(42, 42, 48),
    fill    = Color3.fromRGB(245, 245, 250),  -- progress putih
    title   = Color3.fromRGB(245, 245, 250),
    sub     = Color3.fromRGB(150, 150, 160),
}

local function getParentGui()
    local ok, hui = pcall(function() return gethui and gethui() end)
    if ok and hui then return hui end
    local okc, core = pcall(function() return game:GetService("CoreGui") end)
    if okc and core then return core end
    return Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- ====== GEAR FACTORY ======
-- diameterUnits: ukuran (unit referensi), SCALE -> px
-- posUnits: {x=, y=} relatif tengah stage (y ke ATAS positif, kaya three.js)
local SCALE = 24
local function makeGear(parent, diameterUnits, toothCount, color, posUnits, speedDegPerSec)
    local d      = diameterUnits * SCALE
    local tube   = math.max(d * 0.08, 4)
    local toothW = tube * 2.2
    local toothH = d * 0.14
    local box    = d + toothH * 2 + 8

    local gear = Instance.new("Frame")
    gear.Name = "Gear"
    gear.AnchorPoint = Vector2.new(0.5, 0.5)
    gear.Size = UDim2.fromOffset(box, box)
    gear.Position = UDim2.fromOffset(posUnits.x * SCALE, -posUnits.y * SCALE)
    gear.BackgroundTransparency = 1
    gear.Parent = parent

    -- rim (cincin) pake UIStroke di lingkaran transparan
    local ring = Instance.new("Frame")
    ring.AnchorPoint = Vector2.new(0.5, 0.5)
    ring.Position = UDim2.fromScale(0.5, 0.5)
    ring.Size = UDim2.fromOffset(d, d)
    ring.BackgroundTransparency = 1
    ring.Parent = gear
    local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(1, 0); rc.Parent = ring
    local rs = Instance.new("UIStroke"); rs.Thickness = tube; rs.Color = color; rs.Parent = ring

    -- teeth (gerigi)
    for i = 0, toothCount - 1 do
        local ang = (i / toothCount) * math.pi * 2
        local r = d / 2
        local tooth = Instance.new("Frame")
        tooth.AnchorPoint = Vector2.new(0.5, 0.5)
        tooth.Size = UDim2.fromOffset(toothW, toothH)
        tooth.Position = UDim2.new(0.5, math.cos(ang) * r, 0.5, -math.sin(ang) * r)
        tooth.Rotation = -math.deg(ang)
        tooth.BackgroundColor3 = color
        tooth.BorderSizePixel = 0
        tooth.Parent = gear
        local tcc = Instance.new("UICorner"); tcc.CornerRadius = UDim.new(0, 2); tcc.Parent = tooth
    end

    -- hub (poros tengah)
    local hub = Instance.new("Frame")
    hub.AnchorPoint = Vector2.new(0.5, 0.5)
    hub.Position = UDim2.fromScale(0.5, 0.5)
    hub.Size = UDim2.fromOffset(d * 0.36, d * 0.36)
    hub.BackgroundColor3 = color
    hub.BorderSizePixel = 0
    hub.Parent = gear
    local hc = Instance.new("UICorner"); hc.CornerRadius = UDim.new(1, 0); hc.Parent = hub

    -- lubang tengah (biar keliatan kaya gear)
    local hole = Instance.new("Frame")
    hole.AnchorPoint = Vector2.new(0.5, 0.5)
    hole.Position = UDim2.fromScale(0.5, 0.5)
    hole.Size = UDim2.fromOffset(d * 0.16, d * 0.16)
    hole.BackgroundColor3 = COL.overlay
    hole.BorderSizePixel = 0
    hole.Parent = gear
    local holc = Instance.new("UICorner"); holc.CornerRadius = UDim.new(1, 0); holc.Parent = hole

    return { frame = gear, speed = speedDegPerSec }
end

-- ====== LOADER ======
local Loader = {}
Loader.__index = Loader

function Loader.new()
    local self = setmetatable({}, Loader)
    self._progress = 0
    self._gears = {}
    self._conns = {}

    -- blur layar
    local blur = Instance.new("BlurEffect")
    blur.Name = "AutomaHubLoadBlur"
    blur.Size = 0
    blur.Parent = Lighting
    self._blur = blur
    TweenService:Create(blur, TweenInfo.new(0.35), { Size = 18 }):Play()

    -- screengui
    local gui = Instance.new("ScreenGui")
    gui.Name = "AutomaHubLoader"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 100000
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = getParentGui()
    self._gui = gui

    -- overlay gelap (transparan dikit biar blur keliatan)
    local overlay = Instance.new("Frame")
    overlay.Name = "Overlay"
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3 = COL.overlay
    overlay.BackgroundTransparency = 1
    overlay.BorderSizePixel = 0
    overlay.Parent = gui
    self._overlay = overlay
    TweenService:Create(overlay, TweenInfo.new(0.3), { BackgroundTransparency = 0.35 }):Play()

    -- stage (titik tengah buat naro gear), size 0 -> anchor = center point
    local stage = Instance.new("Frame")
    stage.Name = "Stage"
    stage.AnchorPoint = Vector2.new(0.5, 0.5)
    stage.Position = UDim2.fromScale(0.5, 0.40)
    stage.Size = UDim2.fromOffset(0, 0)
    stage.BackgroundTransparency = 1
    stage.Parent = overlay

    -- 4 gear, niru layout three.js
    table.insert(self._gears, makeGear(stage, 6.0, 12, COL.gear1, { x = 0,    y = 0    },  34))
    table.insert(self._gears, makeGear(stage, 3.0, 12, COL.gear2, { x = -3.5, y = 3.5  }, -69))
    table.insert(self._gears, makeGear(stage, 4.4, 12, COL.gear3, { x = 4.0,  y = -2.0 }, -52))
    table.insert(self._gears, makeGear(stage, 2.0, 12, COL.gear4, { x = 1.0,  y = 1.0  }, 103))

    -- intro: gear scale-in
    for _, g in ipairs(self._gears) do
        local target = g.frame.Size
        g.frame.Size = UDim2.fromOffset(0, 0)
        TweenService:Create(g.frame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = target }):Play()
    end

    -- title
    local title = Instance.new("TextLabel")
    title.AnchorPoint = Vector2.new(0.5, 0.5)
    title.Position = UDim2.fromScale(0.5, 0.64)
    title.Size = UDim2.fromOffset(400, 30)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = "AUTOMAHUB"
    title.TextColor3 = COL.title
    title.TextSize = 24
    title.TextTransparency = 1
    title.Parent = overlay
    TweenService:Create(title, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()

    -- status text
    local status = Instance.new("TextLabel")
    status.AnchorPoint = Vector2.new(0.5, 0.5)
    status.Position = UDim2.fromScale(0.5, 0.70)
    status.Size = UDim2.fromOffset(400, 18)
    status.BackgroundTransparency = 1
    status.Font = Enum.Font.Gotham
    status.Text = "Loading..."
    status.TextColor3 = COL.sub
    status.TextSize = 13
    status.Parent = overlay
    self._status = status

    -- progress track
    local track = Instance.new("Frame")
    track.AnchorPoint = Vector2.new(0.5, 0.5)
    track.Position = UDim2.fromScale(0.5, 0.755)
    track.Size = UDim2.fromOffset(320, 6)
    track.BackgroundColor3 = COL.track
    track.BorderSizePixel = 0
    track.Parent = overlay
    local tcc = Instance.new("UICorner"); tcc.CornerRadius = UDim.new(1, 0); tcc.Parent = track

    local fill = Instance.new("Frame")
    fill.Size = UDim2.fromScale(0, 1)
    fill.BackgroundColor3 = COL.fill
    fill.BorderSizePixel = 0
    fill.Parent = track
    local fcc = Instance.new("UICorner"); fcc.CornerRadius = UDim.new(1, 0); fcc.Parent = fill
    self._fill = fill

    -- percent label
    local pct = Instance.new("TextLabel")
    pct.AnchorPoint = Vector2.new(0.5, 0.5)
    pct.Position = UDim2.fromScale(0.5, 0.80)
    pct.Size = UDim2.fromOffset(120, 16)
    pct.BackgroundTransparency = 1
    pct.Font = Enum.Font.GothamBold
    pct.Text = "0%"
    pct.TextColor3 = COL.sub
    pct.TextSize = 12
    pct.Parent = overlay
    self._pct = pct

    -- spin loop
    local conn = RunService.RenderStepped:Connect(function(dt)
        for _, g in ipairs(self._gears) do
            g.frame.Rotation = g.frame.Rotation + g.speed * dt
        end
    end)
    table.insert(self._conns, conn)

    return self
end

function Loader:setStatus(text)
    if self._status then self._status.Text = tostring(text) end
end

function Loader:setProgress(p)
    p = math.clamp(p, 0, 1)
    self._progress = p
    if self._fill then
        TweenService:Create(self._fill, TweenInfo.new(0.2), { Size = UDim2.fromScale(p, 1) }):Play()
    end
    if self._pct then
        self._pct.Text = tostring(math.floor(p * 100 + 0.5)) .. "%"
    end
end

function Loader:finish(callback)
    self:setProgress(1)
    task.delay(0.25, function()
        -- fade out semua
        if self._overlay then
            TweenService:Create(self._overlay, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
            for _, ch in ipairs(self._overlay:GetDescendants()) do
                if ch:IsA("TextLabel") then
                    TweenService:Create(ch, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
                elseif ch:IsA("Frame") then
                    TweenService:Create(ch, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
                elseif ch:IsA("UIStroke") then
                    TweenService:Create(ch, TweenInfo.new(0.4), { Transparency = 1 }):Play()
                end
            end
        end
        if self._blur then
            TweenService:Create(self._blur, TweenInfo.new(0.4), { Size = 0 }):Play()
        end
        task.delay(0.45, function()
            self:destroy()
            if type(callback) == "function" then
                local ok, err = pcall(callback)
                if not ok then warn("[AutomaHub] loader callback error: " .. tostring(err)) end
            end
        end)
    end)
end

function Loader:destroy()
    for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
    self._conns = {}
    if self._gui then pcall(function() self._gui:Destroy() end) end
    if self._blur then pcall(function() self._blur:Destroy() end) end
end

-- ====== STANDALONE PREVIEW (demo) ======
-- Kalo dipakai sbg module, set getgenv().AutomaHubLoaderModule = true
-- biar demo ini ga jalan.
if not (getgenv and getgenv().AutomaHubLoaderModule) then
    task.spawn(function()
        local L = Loader.new()
        L:setStatus("Loading AutomaHub...")
        local p = 0
        while p < 1 do
            p = math.min(1, p + math.random(2, 6) / 100)
            L:setProgress(p)
            task.wait(0.06)
        end
        L:setStatus("Done!")
        L:finish(function()
            print("[AutomaHub] loading selesai (demo)")
        end)
    end)
end

return Loader
