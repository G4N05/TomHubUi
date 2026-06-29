-- ============================================================
-- AutomaHub | MAIN MENU SHELL (custom sidebar rail)
-- ------------------------------------------------------------
-- Niru gambar referensi (yang KIRI / collapsed icon-rail):
--   - slot LOGO kosong di atas (reserved, isi sendiri nanti)
--   - LANGSUNG menu (tanpa Search/Notif/Settings group)
--   - TANPA theme toggle
--   - paling bawah = foto avatar Roblox kita
--   - icon menu diambil dari WindUI Icons lib (lucide) via GetIcon()
-- Tabs: Combat, Player, Visual, Settings, Aim
--
-- Standalone: paste di executor buat tes tampilan menu.
-- ============================================================

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer      = Players.LocalPlayer

-- ====== LOAD ICONS LIB (Footagesus/Icons) ======
-- GetIcon(name) balikin string "rbxassetid://..." (default set: lucide)
local function multiFetch(urls)
    for _, url in ipairs(urls) do
        local ok, content = pcall(function() return game:HttpGet(url) end)
        if ok and content and #content > 100 then return content end
    end
    return nil
end

local IconLib
do
    local content = multiFetch({
        "https://raw.githubusercontent.com/Footagesus/Icons/main/Main-v2.lua",
        "https://cdn.jsdelivr.net/gh/Footagesus/Icons@main/Main-v2.lua",
        "https://raw.githubusercontent.com/Footagesus/Icons/main/Main.lua",
    })
    if content then
        local fn = loadstring(content)
        if fn then
            local ok, lib = pcall(fn)
            if ok then IconLib = lib end
        end
    end
    if IconLib and type(IconLib.SetIconsType) == "function" then
        pcall(function() IconLib.SetIconsType("lucide") end)
    end
end

-- terapin icon ke ImageLabel; return true kalo dapet image
local function applyIcon(img, name)
    local asset
    pcall(function()
        if IconLib and type(IconLib.GetIcon) == "function" then
            asset = IconLib.GetIcon(name)
        end
    end)
    if type(asset) == "string" and asset ~= "" then
        img.Image = asset
        return true
    elseif type(asset) == "table" and asset.Image then
        img.Image = asset.Image
        if asset.ImageRectSize then img.ImageRectSize = asset.ImageRectSize end
        if asset.ImageRectOffset then img.ImageRectOffset = asset.ImageRectOffset end
        return true
    end
    return false
end

-- ====== PALETTE ======
local COL = {
    panel    = Color3.fromRGB(20, 20, 23),
    rail     = Color3.fromRGB(14, 14, 17),
    stroke   = Color3.fromRGB(255, 255, 255),
    iconIdle = Color3.fromRGB(140, 140, 150),
    iconActv = Color3.fromRGB(245, 245, 250),
    hi       = Color3.fromRGB(255, 255, 255),
    text     = Color3.fromRGB(235, 235, 240),
    subtext  = Color3.fromRGB(150, 150, 160),
    card     = Color3.fromRGB(28, 28, 33),
    row      = Color3.fromRGB(38, 38, 44),
    toggleOff= Color3.fromRGB(60, 60, 68),
    toggleOn = Color3.fromRGB(245, 245, 250),
    knobOn   = Color3.fromRGB(24, 24, 28),
    field    = Color3.fromRGB(22, 22, 26),
    knob     = Color3.fromRGB(245, 245, 250),
}

-- ====== TABS ======
local TABS = {
    {
        id = "Combat", icon = "swords", fallback = "C",
        items = {
            { t = "toggle",   name = "Kill Aura" },
            { t = "toggle",   name = "Auto Parry" },
            { t = "slider",   name = "Hit Range", min = 1, max = 50, default = 12 },
            { t = "input",    name = "Hit Delay (ms)", default = 100 },
            { t = "dropdown", name = "Target", options = { "Closest", "Lowest HP", "Cursor", "Random" } },
        },
    },
    {
        id = "Player", icon = "user", fallback = "P",
        items = {
            { t = "toggle", name = "Infinite Jump" },
            { t = "toggle", name = "Fly" },
            { t = "slider", name = "Walk Speed", min = 16, max = 200, default = 16 },
            { t = "slider", name = "Jump Power", min = 50, max = 300, default = 50 },
            { t = "input",  name = "Fly Speed", default = 50 },
        },
    },
    {
        id = "Visual", icon = "eye", fallback = "V",
        items = {
            { t = "toggle",   name = "Player ESP" },
            { t = "toggle",   name = "Name ESP" },
            { t = "toggle",   name = "Tracers" },
            { t = "dropdown", name = "ESP Mode", options = { "Box", "Highlight", "Corner" } },
            { t = "slider",   name = "Text Size", min = 8, max = 24, default = 14 },
        },
    },
    {
        id = "Settings", icon = "settings", fallback = "S",
        items = {
            { t = "toggle",   name = "Anti AFK" },
            { t = "toggle",   name = "Auto Rejoin" },
            { t = "input",    name = "Rejoin Delay (s)", default = 5 },
            { t = "dropdown", name = "UI Theme", options = { "Dark", "Darker", "Black" } },
        },
    },
    {
        id = "Aim", icon = "crosshair", fallback = "A",
        items = {
            { t = "toggle",   name = "Aimbot" },
            { t = "toggle",   name = "Silent Aim" },
            { t = "slider",   name = "FOV", min = 30, max = 500, default = 120 },
            { t = "dropdown", name = "Aim Part", options = { "Head", "Torso", "Nearest" } },
            { t = "dropdown", name = "Target Priority", options = { "Closest", "Lowest HP", "Crosshair" } },
            { t = "input",    name = "Smoothness", default = 10 },
        },
    },
}

-- ============================================================
-- BUILD
-- ============================================================
local parentGui = (gethui and gethui()) or game:GetService("CoreGui")
local old = parentGui:FindFirstChild("AutomaHubMenu")
if old then old:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutomaHubMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 9999
ScreenGui.Parent = parentGui

-- root panel
local Panel = Instance.new("Frame")
Panel.Name = "Panel"
Panel.AnchorPoint = Vector2.new(0.5, 0.5)
Panel.Position = UDim2.fromScale(0.5, 0.5)
Panel.Size = UDim2.fromOffset(560, 380)
Panel.BackgroundColor3 = COL.panel
Panel.BorderSizePixel = 0
Panel.Parent = ScreenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 16)
panelCorner.Parent = Panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = COL.stroke
panelStroke.Transparency = 0.9
panelStroke.Thickness = 1
panelStroke.Parent = Panel

-- ====== RAIL (sidebar collapsed) ======
local Rail = Instance.new("Frame")
Rail.Name = "Rail"
Rail.Size = UDim2.new(0, 64, 1, 0)
Rail.BackgroundColor3 = COL.rail
Rail.BorderSizePixel = 0
Rail.Parent = Panel

local railCorner = Instance.new("UICorner")
railCorner.CornerRadius = UDim.new(0, 16)
railCorner.Parent = Rail

-- nutupin sudut kanan rail biar nyambung ke panel (bukan rounded)
local railPatch = Instance.new("Frame")
railPatch.Size = UDim2.new(0, 16, 1, 0)
railPatch.Position = UDim2.new(1, -16, 0, 0)
railPatch.BackgroundColor3 = COL.rail
railPatch.BorderSizePixel = 0
railPatch.Parent = Rail

-- ---- LOGO SLOT (kosong, reserved) ----
local LogoSlot = Instance.new("Frame")
LogoSlot.Name = "LogoSlot"
LogoSlot.AnchorPoint = Vector2.new(0.5, 0)
LogoSlot.Position = UDim2.new(0.5, 0, 0, 16)
LogoSlot.Size = UDim2.fromOffset(40, 40)
LogoSlot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
LogoSlot.BackgroundTransparency = 0.94
LogoSlot.Parent = Rail

local logoCorner = Instance.new("UICorner")
logoCorner.CornerRadius = UDim.new(0, 10)
logoCorner.Parent = LogoSlot

local logoStroke = Instance.new("UIStroke")
logoStroke.Color = COL.stroke
logoStroke.Transparency = 0.82
logoStroke.Thickness = 1
logoStroke.Parent = LogoSlot

-- tempat naro logo nanti: bikin ImageLabel di sini & set .Image
-- contoh:
-- local Logo = Instance.new("ImageLabel"); Logo.Size = UDim2.fromScale(1,1)
-- Logo.BackgroundTransparency = 1; Logo.Image = "rbxassetid://XXXX"; Logo.Parent = LogoSlot

-- divider tipis di bawah logo
local Divider = Instance.new("Frame")
Divider.Name = "Divider"
Divider.AnchorPoint = Vector2.new(0.5, 0)
Divider.Position = UDim2.new(0.5, 0, 0, 68)
Divider.Size = UDim2.fromOffset(32, 1)
Divider.BackgroundColor3 = COL.stroke
Divider.BackgroundTransparency = 0.85
Divider.BorderSizePixel = 0
Divider.Parent = Rail

-- ---- NAV CONTAINER ----
local Nav = Instance.new("Frame")
Nav.Name = "Nav"
Nav.AnchorPoint = Vector2.new(0.5, 0)
Nav.Position = UDim2.new(0.5, 0, 0, 82)
Nav.Size = UDim2.new(1, 0, 1, -150)
Nav.BackgroundTransparency = 1
Nav.Parent = Rail

local navLayout = Instance.new("UIListLayout")
navLayout.FillDirection = Enum.FillDirection.Vertical
navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
navLayout.SortOrder = Enum.SortOrder.LayoutOrder
navLayout.Padding = UDim.new(0, 8)
navLayout.Parent = Nav

-- ====== HEADER BAR (atas, manjang sampe ujung kanan GUI) ======
local GAP = 10
local RIGHT_X = 64 + GAP
local RIGHT_W = 560 - RIGHT_X - GAP
local HEAD_H = 44

local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Position = UDim2.new(0, RIGHT_X, 0, GAP)
Header.Size = UDim2.new(0, RIGHT_W, 0, HEAD_H)
Header.BackgroundColor3 = COL.card
Header.BorderSizePixel = 0
Header.Parent = Panel

local headCorner = Instance.new("UICorner")
headCorner.CornerRadius = UDim.new(0, 12)
headCorner.Parent = Header

local headStroke = Instance.new("UIStroke")
headStroke.Color = COL.stroke
headStroke.Transparency = 0.9
headStroke.Thickness = 1
headStroke.Parent = Header

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.AnchorPoint = Vector2.new(0, 0.5)
Title.Position = UDim2.new(0, 16, 0.5, 0)
Title.Size = UDim2.new(1, -32, 1, 0)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.Text = "Combat"
Title.TextColor3 = COL.text
Title.TextSize = 18
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

-- ====== CONTENT PANEL (bawah header, buat toggle-toggle) ======
local ContentCard = Instance.new("Frame")
ContentCard.Name = "Content"
ContentCard.Position = UDim2.new(0, RIGHT_X, 0, GAP + HEAD_H + GAP)
ContentCard.Size = UDim2.new(0, RIGHT_W, 1, -(GAP + HEAD_H + GAP + GAP))
ContentCard.BackgroundColor3 = COL.card
ContentCard.BorderSizePixel = 0
ContentCard.Parent = Panel

local contentCorner = Instance.new("UICorner")
contentCorner.CornerRadius = UDim.new(0, 12)
contentCorner.Parent = ContentCard

local contentStroke = Instance.new("UIStroke")
contentStroke.Color = COL.stroke
contentStroke.Transparency = 0.9
contentStroke.Thickness = 1
contentStroke.Parent = ContentCard

local Scroll = Instance.new("ScrollingFrame")
Scroll.Name = "Scroll"
Scroll.Size = UDim2.fromScale(1, 1)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 4
Scroll.ScrollBarImageColor3 = COL.iconIdle
Scroll.CanvasSize = UDim2.new()
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.Parent = ContentCard

local scrollPad = Instance.new("UIPadding")
scrollPad.PaddingTop = UDim.new(0, 12)
scrollPad.PaddingBottom = UDim.new(0, 12)
scrollPad.PaddingLeft = UDim.new(0, 14)
scrollPad.PaddingRight = UDim.new(0, 14)
scrollPad.Parent = Scroll

local scrollLayout = Instance.new("UIListLayout")
scrollLayout.FillDirection = Enum.FillDirection.Vertical
scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
scrollLayout.Padding = UDim.new(0, 8)
scrollLayout.Parent = Scroll

-- ---- toggle builder (UI layer doang, callback no-op) ----
local function makeToggle(name)
    local row = Instance.new("Frame")
    row.Name = name
    row.Size = UDim2.new(1, 0, 0, 40)
    row.BackgroundColor3 = COL.row
    row.BackgroundTransparency = 0.35
    row.BorderSizePixel = 0

    local rc = Instance.new("UICorner")
    rc.CornerRadius = UDim.new(0, 8)
    rc.Parent = row

    local label = Instance.new("TextLabel")
    label.AnchorPoint = Vector2.new(0, 0.5)
    label.Position = UDim2.new(0, 12, 0.5, 0)
    label.Size = UDim2.new(1, -70, 1, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.Text = name
    label.TextColor3 = COL.text
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local track = Instance.new("TextButton")
    track.AnchorPoint = Vector2.new(1, 0.5)
    track.Position = UDim2.new(1, -12, 0.5, 0)
    track.Size = UDim2.fromOffset(38, 20)
    track.AutoButtonColor = false
    track.Text = ""
    track.BackgroundColor3 = COL.toggleOff
    track.Parent = row

    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(1, 0)
    tc.Parent = track

    local knob = Instance.new("Frame")
    knob.AnchorPoint = Vector2.new(0, 0.5)
    knob.Position = UDim2.new(0, 2, 0.5, 0)
    knob.Size = UDim2.fromOffset(16, 16)
    knob.BackgroundColor3 = COL.knob
    knob.BorderSizePixel = 0
    knob.Parent = track

    local kc = Instance.new("UICorner")
    kc.CornerRadius = UDim.new(1, 0)
    kc.Parent = knob

    local state = false
    local function render()
        TweenService:Create(track, TweenInfo.new(0.15), {
            BackgroundColor3 = state and COL.toggleOn or COL.toggleOff,
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {
            Position = state and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
            BackgroundColor3 = state and COL.knobOn or COL.knob,
        }):Play()
    end
    track.MouseButton1Click:Connect(function()
        state = not state
        render()
        -- TODO: sambungin ke fitur game (UI layer doang)
    end)

    return row
end

-- ---- slider builder ----
local function makeSlider(name, minV, maxV, default)
    local value = math.clamp(default, minV, maxV)
    local row = Instance.new("Frame")
    row.Name = name
    row.Size = UDim2.new(1, 0, 0, 54)
    row.BackgroundColor3 = COL.row
    row.BackgroundTransparency = 0.35
    row.BorderSizePixel = 0
    local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 8); rc.Parent = row

    local label = Instance.new("TextLabel")
    label.Position = UDim2.new(0, 12, 0, 8)
    label.Size = UDim2.new(1, -90, 0, 16)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.Text = name
    label.TextColor3 = COL.text
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local valLabel = Instance.new("TextLabel")
    valLabel.AnchorPoint = Vector2.new(1, 0)
    valLabel.Position = UDim2.new(1, -12, 0, 8)
    valLabel.Size = UDim2.new(0, 60, 0, 16)
    valLabel.BackgroundTransparency = 1
    valLabel.Font = Enum.Font.GothamBold
    valLabel.Text = tostring(value)
    valLabel.TextColor3 = COL.subtext
    valLabel.TextSize = 13
    valLabel.TextXAlignment = Enum.TextXAlignment.Right
    valLabel.Parent = row

    local track = Instance.new("Frame")
    track.Position = UDim2.new(0, 12, 1, -16)
    track.Size = UDim2.new(1, -24, 0, 6)
    track.BackgroundColor3 = COL.toggleOff
    track.BorderSizePixel = 0
    track.Parent = row
    local tcc = Instance.new("UICorner"); tcc.CornerRadius = UDim.new(1, 0); tcc.Parent = track

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = COL.knob
    fill.BorderSizePixel = 0
    fill.Size = UDim2.fromScale((value - minV) / (maxV - minV), 1)
    fill.Parent = track
    local fcc = Instance.new("UICorner"); fcc.CornerRadius = UDim.new(1, 0); fcc.Parent = fill

    local knob = Instance.new("Frame")
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new((value - minV) / (maxV - minV), 0, 0.5, 0)
    knob.Size = UDim2.fromOffset(16, 16)
    knob.BackgroundColor3 = COL.knob
    knob.BorderSizePixel = 0
    knob.Parent = track
    local kcc = Instance.new("UICorner"); kcc.CornerRadius = UDim.new(1, 0); kcc.Parent = knob

    -- hit area transparan, gede biar gampang di-grab
    local hit = Instance.new("TextButton")
    hit.Name = "Hit"
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.AutoButtonColor = false
    hit.AnchorPoint = Vector2.new(0, 0.5)
    hit.Position = UDim2.new(0, 0, 1, -13)
    hit.Size = UDim2.new(1, 0, 0, 30)
    hit.ZIndex = 5
    hit.Parent = row

    local function setFromX(px)
        local rel = math.clamp((px - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        value = math.floor(minV + (maxV - minV) * rel + 0.5)
        local pct = (value - minV) / (maxV - minV)
        fill.Size = UDim2.fromScale(pct, 1)
        knob.Position = UDim2.new(pct, 0, 0.5, 0)
        valLabel.Text = tostring(value)
    end

    local dragging = false
    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromX(input.Position.X)
        end
    end)
    hit.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            setFromX(input.Position.X)
        end
    end)

    return row
end

-- ---- number input builder ----
local function makeInput(name, default)
    local row = Instance.new("Frame")
    row.Name = name
    row.Size = UDim2.new(1, 0, 0, 40)
    row.BackgroundColor3 = COL.row
    row.BackgroundTransparency = 0.35
    row.BorderSizePixel = 0
    local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 8); rc.Parent = row

    local label = Instance.new("TextLabel")
    label.AnchorPoint = Vector2.new(0, 0.5)
    label.Position = UDim2.new(0, 12, 0.5, 0)
    label.Size = UDim2.new(1, -110, 1, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.Text = name
    label.TextColor3 = COL.text
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local box = Instance.new("TextBox")
    box.AnchorPoint = Vector2.new(1, 0.5)
    box.Position = UDim2.new(1, -12, 0.5, 0)
    box.Size = UDim2.fromOffset(80, 26)
    box.BackgroundColor3 = COL.field
    box.BorderSizePixel = 0
    box.Font = Enum.Font.GothamBold
    box.TextSize = 13
    box.TextColor3 = COL.text
    box.PlaceholderText = "0"
    box.PlaceholderColor3 = COL.subtext
    box.Text = tostring(default)
    box.ClearTextOnFocus = false
    box.Parent = row
    local bcc = Instance.new("UICorner"); bcc.CornerRadius = UDim.new(0, 6); bcc.Parent = box

    local lastValid = tostring(default)
    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if n then
            lastValid = tostring(n)
            box.Text = lastValid
            -- TODO: pakai nilai n (UI layer doang)
        else
            box.Text = lastValid
        end
    end)

    return row
end

-- ---- dropdown builder (buat milih target dll) ----
local function makeDropdown(name, options)
    local optH = 26
    local optGap = 4
    local holderH = 12 + #options * optH + math.max(#options - 1, 0) * optGap
    local selected = options[1]

    local row = Instance.new("Frame")
    row.Name = name
    row.Size = UDim2.new(1, 0, 0, 40)
    row.BackgroundColor3 = COL.row
    row.BackgroundTransparency = 0.35
    row.BorderSizePixel = 0
    row.ClipsDescendants = true
    local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 8); rc.Parent = row

    local label = Instance.new("TextLabel")
    label.Position = UDim2.new(0, 12, 0, 0)
    label.Size = UDim2.new(0.5, -12, 0, 40)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.Text = name
    label.TextColor3 = COL.text
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local valueBtn = Instance.new("TextButton")
    valueBtn.AnchorPoint = Vector2.new(1, 0)
    valueBtn.Position = UDim2.new(1, -12, 0, 7)
    valueBtn.Size = UDim2.fromOffset(120, 26)
    valueBtn.BackgroundColor3 = COL.field
    valueBtn.AutoButtonColor = false
    valueBtn.Font = Enum.Font.GothamBold
    valueBtn.TextSize = 13
    valueBtn.TextColor3 = COL.text
    valueBtn.Text = selected .. "   v"
    valueBtn.Parent = row
    local vcc = Instance.new("UICorner"); vcc.CornerRadius = UDim.new(0, 6); vcc.Parent = valueBtn

    local holder = Instance.new("Frame")
    holder.Position = UDim2.new(0, 0, 0, 40)
    holder.Size = UDim2.new(1, 0, 0, holderH)
    holder.BackgroundTransparency = 1
    holder.Visible = false
    holder.Parent = row
    local hpad = Instance.new("UIPadding")
    hpad.PaddingLeft = UDim.new(0, 12)
    hpad.PaddingRight = UDim.new(0, 12)
    hpad.PaddingBottom = UDim.new(0, 8)
    hpad.Parent = holder
    local hlay = Instance.new("UIListLayout")
    hlay.FillDirection = Enum.FillDirection.Vertical
    hlay.SortOrder = Enum.SortOrder.LayoutOrder
    hlay.Padding = UDim.new(0, optGap)
    hlay.Parent = holder

    local open = false
    local optButtons = {}
    local function setOpen(v)
        open = v
        holder.Visible = v
        valueBtn.Text = selected .. (v and "   ^" or "   v")
        TweenService:Create(row, TweenInfo.new(0.15), {
            Size = UDim2.new(1, 0, 0, v and (40 + holderH) or 40),
        }):Play()
    end

    for i, opt in ipairs(options) do
        local ob = Instance.new("TextButton")
        ob.Size = UDim2.new(1, 0, 0, optH)
        ob.BackgroundColor3 = COL.field
        ob.BackgroundTransparency = 0.2
        ob.AutoButtonColor = false
        ob.Font = Enum.Font.Gotham
        ob.TextSize = 13
        ob.TextColor3 = (opt == selected) and COL.text or COL.subtext
        ob.Text = opt
        ob.LayoutOrder = i
        ob.Parent = holder
        local occ = Instance.new("UICorner"); occ.CornerRadius = UDim.new(0, 6); occ.Parent = ob
        optButtons[opt] = ob
        ob.MouseEnter:Connect(function() ob.TextColor3 = COL.text end)
        ob.MouseLeave:Connect(function() ob.TextColor3 = (opt == selected) and COL.text or COL.subtext end)
        ob.MouseButton1Click:Connect(function()
            selected = opt
            for o, b in pairs(optButtons) do
                b.TextColor3 = (o == selected) and COL.text or COL.subtext
            end
            setOpen(false)
            -- TODO: pakai pilihan selected (UI layer doang)
        end)
    end

    valueBtn.MouseButton1Click:Connect(function() setOpen(not open) end)

    return row
end

local function populate(id)
    for _, ch in ipairs(Scroll:GetChildren()) do
        if ch:IsA("Frame") then ch:Destroy() end
    end
    for _, t in ipairs(TABS) do
        if t.id == id then
            for i, item in ipairs(t.items) do
                local el
                if item.t == "toggle" then
                    el = makeToggle(item.name)
                elseif item.t == "slider" then
                    el = makeSlider(item.name, item.min, item.max, item.default)
                elseif item.t == "input" then
                    el = makeInput(item.name, item.default)
                elseif item.t == "dropdown" then
                    el = makeDropdown(item.name, item.options)
                end
                if el then
                    el.LayoutOrder = i
                    el.Parent = Scroll
                end
            end
        end
    end
end

-- ====== AVATAR (paling bawah rail) ======
local AvatarHolder = Instance.new("Frame")
AvatarHolder.Name = "AvatarHolder"
AvatarHolder.AnchorPoint = Vector2.new(0.5, 1)
AvatarHolder.Position = UDim2.new(0.5, 0, 1, -14)
AvatarHolder.Size = UDim2.fromOffset(40, 40)
AvatarHolder.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
AvatarHolder.BackgroundTransparency = 0.9
AvatarHolder.Parent = Rail

local avhCorner = Instance.new("UICorner")
avhCorner.CornerRadius = UDim.new(1, 0)
avhCorner.Parent = AvatarHolder

local avhStroke = Instance.new("UIStroke")
avhStroke.Color = COL.stroke
avhStroke.Transparency = 0.55
avhStroke.Thickness = 1.5
avhStroke.Parent = AvatarHolder

local Avatar = Instance.new("ImageLabel")
Avatar.Name = "Avatar"
Avatar.AnchorPoint = Vector2.new(0.5, 0.5)
Avatar.Position = UDim2.fromScale(0.5, 0.5)
Avatar.Size = UDim2.fromOffset(34, 34)
Avatar.BackgroundTransparency = 1
Avatar.Parent = AvatarHolder

local avCorner = Instance.new("UICorner")
avCorner.CornerRadius = UDim.new(1, 0)
avCorner.Parent = Avatar

task.spawn(function()
    local ok, content = pcall(function()
        return Players:GetUserThumbnailAsync(
            LocalPlayer.UserId,
            Enum.ThumbnailType.HeadShot,
            Enum.ThumbnailSize.Size420x420
        )
    end)
    if ok and content then Avatar.Image = content end
end)

-- ============================================================
-- NAV ITEMS
-- ============================================================
local buttons = {}
local activeId = nil

local function selectTab(id)
    activeId = id
    for _, b in pairs(buttons) do
        local on = (b.id == id)
        TweenService:Create(b.btn, TweenInfo.new(0.15), {
            BackgroundTransparency = on and 0.88 or 1,
        }):Play()
        TweenService:Create(b.icon, TweenInfo.new(0.15), {
            ImageColor3 = on and COL.iconActv or COL.iconIdle,
        }):Play()
        b.txt.TextColor3 = on and COL.iconActv or COL.iconIdle
    end
    Title.Text = id
    populate(id)
end

for i, t in ipairs(TABS) do
    local btn = Instance.new("TextButton")
    btn.Name = t.id
    btn.Size = UDim2.fromOffset(40, 40)
    btn.BackgroundColor3 = COL.hi
    btn.BackgroundTransparency = 1
    btn.AutoButtonColor = false
    btn.Text = ""
    btn.LayoutOrder = i
    btn.Parent = Nav

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 10)
    c.Parent = btn

    -- fallback huruf (keliatan kalo icon WindUI gagal)
    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.fromScale(1, 1)
    txt.BackgroundTransparency = 1
    txt.Font = Enum.Font.GothamBold
    txt.Text = t.fallback
    txt.TextColor3 = COL.iconIdle
    txt.TextSize = 15
    txt.Parent = btn

    local icon = Instance.new("ImageLabel")
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Position = UDim2.fromScale(0.5, 0.5)
    icon.Size = UDim2.fromOffset(20, 20)
    icon.BackgroundTransparency = 1
    icon.ImageColor3 = COL.iconIdle
    icon.Parent = btn

    if applyIcon(icon, t.icon) then
        txt.Visible = false
    else
        icon.Visible = false
    end

    btn.MouseEnter:Connect(function()
        if activeId ~= t.id then
            TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundTransparency = 0.94 }):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if activeId ~= t.id then
            TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundTransparency = 1 }):Play()
        end
    end)
    btn.MouseButton1Click:Connect(function()
        selectTab(t.id)
    end)

    buttons[i] = { id = t.id, btn = btn, icon = icon, txt = txt }
end

selectTab("Combat")

-- ====== DRAG (lewat logo slot area / rail atas) ======
local dragging, dragStart, startPos
local function beginDrag(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Panel.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end
LogoSlot.InputBegan:Connect(beginDrag)
Header.InputBegan:Connect(beginDrag)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        Panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- ====== INTRO ANIM ======
Panel.BackgroundTransparency = 1
TweenService:Create(Panel, TweenInfo.new(0.25), { BackgroundTransparency = 0 }):Play()
