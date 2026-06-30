-- ============================================================
-- AutomaHub | MAIN MENU (Kinetic Precision / industrial)
-- ------------------------------------------------------------
-- Niru referensi screen.png (dashboard monokrom industrial):
--   - SIDEBAR kiri full-height: LOGO atas -> icon menu (tabs)
--   - HEADER: judul gede kiri = NAMA MENU yang kepilih
--             + profil kanan-atas = AVATAR + NAMA akun Roblox kita
--   - CONTENT: panel grid, isi menu (toggle/slider/input/dropdown)
--   - TANPA gear/settings di bawah sidebar
--
-- Logo di-load dari raw GitHub via writefile + getcustomasset
-- (ImageLabel Roblox ga bisa load URL langsung).
-- Standalone: paste di executor buat tes tampilan.
-- ============================================================

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer      = Players.LocalPlayer

local LOGO_URL = "https://raw.githubusercontent.com/G4N05/TomHubUi/main/Icon/AutomaHubLogo.png"

-- ====== LOAD ICONS LIB (Footagesus/Icons) ======
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

-- ====== LOAD LOGO (download -> writefile -> getcustomasset) ======
local function loadLogo()
    local ok, asset = pcall(function()
        local data = game:HttpGet(LOGO_URL)
        local fname = "AutomaHubLogo.png"
        local writer = writefile or (syn and syn.write_file)
        if writer then writer(fname, data) end
        local getter = getcustomasset or getsynasset or (syn and syn.getcustomasset)
        if getter then return getter(fname) end
        return nil
    end)
    if ok and type(asset) == "string" and asset ~= "" then return asset end
    return nil
end

-- ====== PALETTE (Kinetic Precision, monokrom, no biru) ======
local COL = {
    bg        = Color3.fromRGB(15, 15, 15),
    sidebar   = Color3.fromRGB(27, 28, 27),
    card      = Color3.fromRGB(31, 32, 31),
    border    = Color3.fromRGB(68, 71, 72),
    borderHi  = Color3.fromRGB(120, 123, 124),
    text      = Color3.fromRGB(228, 226, 224),
    subtext   = Color3.fromRGB(142, 145, 146),
    iconIdle  = Color3.fromRGB(120, 122, 122),
    iconActv  = Color3.fromRGB(240, 240, 238),
    hi        = Color3.fromRGB(255, 255, 255),
    -- dipakai builders (jangan ganti nama key)
    row       = Color3.fromRGB(42, 43, 42),
    field     = Color3.fromRGB(20, 21, 20),
    toggleOff = Color3.fromRGB(62, 62, 62),
    toggleOn  = Color3.fromRGB(245, 245, 245),
    knob      = Color3.fromRGB(245, 245, 245),
    knobOn    = Color3.fromRGB(26, 26, 26),
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
Panel.Size = UDim2.fromOffset(660, 460)
Panel.BackgroundColor3 = COL.bg
Panel.BorderSizePixel = 0
Panel.Parent = ScreenGui
local panelCorner = Instance.new("UICorner"); panelCorner.CornerRadius = UDim.new(0, 12); panelCorner.Parent = Panel
local panelStroke = Instance.new("UIStroke"); panelStroke.Color = COL.border; panelStroke.Thickness = 1; panelStroke.Parent = Panel
local panelPad = Instance.new("UIPadding")
panelPad.PaddingTop = UDim.new(0, 14); panelPad.PaddingBottom = UDim.new(0, 14)
panelPad.PaddingLeft = UDim.new(0, 14); panelPad.PaddingRight = UDim.new(0, 14)
panelPad.Parent = Panel

-- ====== SIDEBAR ======
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Position = UDim2.fromOffset(0, 0)
Sidebar.Size = UDim2.new(0, 60, 1, 0)
Sidebar.BackgroundColor3 = COL.sidebar
Sidebar.BorderSizePixel = 0
Sidebar.Parent = Panel
local sbCorner = Instance.new("UICorner"); sbCorner.CornerRadius = UDim.new(0, 10); sbCorner.Parent = Sidebar
local sbStroke = Instance.new("UIStroke"); sbStroke.Color = COL.border; sbStroke.Thickness = 1; sbStroke.Transparency = 0.4; sbStroke.Parent = Sidebar

-- logo
local LogoHolder = Instance.new("Frame")
LogoHolder.Name = "LogoHolder"
LogoHolder.AnchorPoint = Vector2.new(0.5, 0)
LogoHolder.Position = UDim2.new(0.5, 0, 0, 12)
LogoHolder.Size = UDim2.fromOffset(36, 36)
LogoHolder.BackgroundTransparency = 1
LogoHolder.Parent = Sidebar

local LogoImg = Instance.new("ImageLabel")
LogoImg.Name = "LogoImg"
LogoImg.Size = UDim2.fromScale(1, 1)
LogoImg.BackgroundTransparency = 1
LogoImg.ScaleType = Enum.ScaleType.Fit
LogoImg.Image = ""
LogoImg.Parent = LogoHolder

local LogoFallback = Instance.new("TextLabel")
LogoFallback.Size = UDim2.fromScale(1, 1)
LogoFallback.BackgroundTransparency = 1
LogoFallback.Font = Enum.Font.GothamBold
LogoFallback.Text = "A"
LogoFallback.TextColor3 = COL.hi
LogoFallback.TextSize = 22
LogoFallback.Visible = false
LogoFallback.Parent = LogoHolder

-- nav container
local Nav = Instance.new("Frame")
Nav.Name = "Nav"
Nav.Position = UDim2.new(0, 0, 0, 60)
Nav.Size = UDim2.new(1, 0, 1, -68)
Nav.BackgroundTransparency = 1
Nav.Parent = Sidebar
local navPad = Instance.new("UIPadding")
navPad.PaddingLeft = UDim.new(0, 8); navPad.PaddingRight = UDim.new(0, 8); navPad.PaddingTop = UDim.new(0, 6)
navPad.Parent = Nav
local navLayout = Instance.new("UIListLayout")
navLayout.FillDirection = Enum.FillDirection.Vertical
navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
navLayout.SortOrder = Enum.SortOrder.LayoutOrder
navLayout.Padding = UDim.new(0, 8)
navLayout.Parent = Nav

-- ====== MAIN AREA ======
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Position = UDim2.new(0, 72, 0, 0)
Main.Size = UDim2.new(1, -72, 1, 0)
Main.BackgroundTransparency = 1
Main.Parent = Panel

-- header
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Position = UDim2.fromOffset(0, 0)
Header.Size = UDim2.new(1, 0, 0, 46)
Header.BackgroundTransparency = 1
Header.Parent = Main

-- judul = nama menu kepilih (ganti "Overview")
local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.AnchorPoint = Vector2.new(0, 0.5)
Title.Position = UDim2.new(0, 2, 0.5, 0)
Title.Size = UDim2.new(0.5, 0, 1, 0)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.Text = "Overview"
Title.TextColor3 = COL.text
Title.TextSize = 26
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

-- profil user (avatar + nama akun) kanan-atas
local Profile = Instance.new("Frame")
Profile.Name = "Profile"
Profile.AnchorPoint = Vector2.new(1, 0.5)
Profile.Position = UDim2.new(1, 0, 0.5, 0)
Profile.Size = UDim2.fromOffset(172, 38)
Profile.BackgroundColor3 = COL.hi
Profile.BackgroundTransparency = 0.94
Profile.BorderSizePixel = 0
Profile.Parent = Header
local profCorner = Instance.new("UICorner"); profCorner.CornerRadius = UDim.new(1, 0); profCorner.Parent = Profile
local profStroke = Instance.new("UIStroke"); profStroke.Color = COL.border; profStroke.Thickness = 1; profStroke.Transparency = 0.3; profStroke.Parent = Profile

local AvatarHolder = Instance.new("Frame")
AvatarHolder.AnchorPoint = Vector2.new(0, 0.5)
AvatarHolder.Position = UDim2.new(0, 5, 0.5, 0)
AvatarHolder.Size = UDim2.fromOffset(28, 28)
AvatarHolder.BackgroundColor3 = COL.field
AvatarHolder.BorderSizePixel = 0
AvatarHolder.Parent = Profile
local avCorner = Instance.new("UICorner"); avCorner.CornerRadius = UDim.new(1, 0); avCorner.Parent = AvatarHolder
local avStroke = Instance.new("UIStroke"); avStroke.Color = COL.hi; avStroke.Thickness = 1; avStroke.Transparency = 0.7; avStroke.Parent = AvatarHolder

local AvatarImg = Instance.new("ImageLabel")
AvatarImg.Size = UDim2.fromScale(1, 1)
AvatarImg.BackgroundTransparency = 1
AvatarImg.Image = ""
AvatarImg.Parent = AvatarHolder
local avImgCorner = Instance.new("UICorner"); avImgCorner.CornerRadius = UDim.new(1, 0); avImgCorner.Parent = AvatarImg

local NameLabel = Instance.new("TextLabel")
NameLabel.AnchorPoint = Vector2.new(0, 0)
NameLabel.Position = UDim2.new(0, 40, 0, 5)
NameLabel.Size = UDim2.new(1, -50, 0, 15)
NameLabel.BackgroundTransparency = 1
NameLabel.Font = Enum.Font.GothamBold
NameLabel.Text = LocalPlayer and LocalPlayer.DisplayName or "Player"
NameLabel.TextColor3 = COL.text
NameLabel.TextSize = 13
NameLabel.TextXAlignment = Enum.TextXAlignment.Left
NameLabel.TextTruncate = Enum.TextTruncate.AtEnd
NameLabel.Parent = Profile

local UserLabel = Instance.new("TextLabel")
UserLabel.AnchorPoint = Vector2.new(0, 0)
UserLabel.Position = UDim2.new(0, 40, 0, 20)
UserLabel.Size = UDim2.new(1, -50, 0, 13)
UserLabel.BackgroundTransparency = 1
UserLabel.Font = Enum.Font.Gotham
UserLabel.Text = "@" .. (LocalPlayer and LocalPlayer.Name or "username")
UserLabel.TextColor3 = COL.subtext
UserLabel.TextSize = 11
UserLabel.TextXAlignment = Enum.TextXAlignment.Left
UserLabel.TextTruncate = Enum.TextTruncate.AtEnd
UserLabel.Parent = Profile

-- content card
local Content = Instance.new("Frame")
Content.Name = "Content"
Content.Position = UDim2.new(0, 0, 0, 54)
Content.Size = UDim2.new(1, 0, 1, -54)
Content.BackgroundColor3 = COL.card
Content.BackgroundTransparency = 0.25
Content.BorderSizePixel = 0
Content.ClipsDescendants = true
Content.Parent = Main
local contentCorner = Instance.new("UICorner"); contentCorner.CornerRadius = UDim.new(0, 12); contentCorner.Parent = Content
local contentStroke = Instance.new("UIStroke"); contentStroke.Color = COL.border; contentStroke.Thickness = 1; contentStroke.Transparency = 0.3; contentStroke.Parent = Content

-- grid background (faint, industrial)
local GridBG = Instance.new("Frame")
GridBG.Name = "GridBG"
GridBG.Size = UDim2.fromScale(1, 1)
GridBG.BackgroundTransparency = 1
GridBG.ClipsDescendants = true
GridBG.ZIndex = 0
GridBG.Parent = Content
local GRID_V, GRID_H = 14, 9
for i = 1, GRID_V - 1 do
    local ln = Instance.new("Frame")
    ln.Size = UDim2.new(0, 1, 1, 0)
    ln.Position = UDim2.fromScale(i / GRID_V, 0)
    ln.BackgroundColor3 = COL.hi
    ln.BackgroundTransparency = 0.94
    ln.BorderSizePixel = 0
    ln.ZIndex = 0
    ln.Parent = GridBG
end
for i = 1, GRID_H - 1 do
    local ln = Instance.new("Frame")
    ln.Size = UDim2.new(1, 0, 0, 1)
    ln.Position = UDim2.fromScale(0, i / GRID_H)
    ln.BackgroundColor3 = COL.hi
    ln.BackgroundTransparency = 0.94
    ln.BorderSizePixel = 0
    ln.ZIndex = 0
    ln.Parent = GridBG
end

-- scroll area
local Scroll = Instance.new("ScrollingFrame")
Scroll.Name = "Scroll"
Scroll.Position = UDim2.fromOffset(0, 0)
Scroll.Size = UDim2.fromScale(1, 1)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 0
Scroll.ScrollingEnabled = false  -- scroll manual dimatiin; navigasi pake tab
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.ZIndex = 1
Scroll.Parent = Content
local scrollPad = Instance.new("UIPadding")
scrollPad.PaddingTop = UDim.new(0, 14); scrollPad.PaddingBottom = UDim.new(0, 14)
scrollPad.PaddingLeft = UDim.new(0, 14); scrollPad.PaddingRight = UDim.new(0, 14)
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

-- ====== POPULATE + SELECT ======
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

local navButtons = {}
local activeId = nil

local function selectTab(id)
    activeId = id
    Title.Text = id  -- header = nama menu kepilih
    for tid, n in pairs(navButtons) do
        local on = (tid == id)
        TweenService:Create(n.btn, TweenInfo.new(0.15), {
            BackgroundTransparency = on and 0.88 or 1,
        }):Play()
        local c = on and COL.iconActv or COL.iconIdle
        if n.icon then n.icon.ImageColor3 = c end
        if n.letter then n.letter.TextColor3 = c end
    end
    populate(id)
    -- animasi ganti tab: konten turun dari atas (kaya scroll ke bawah)
    Scroll.Position = UDim2.fromOffset(0, -22)
    TweenService:Create(Scroll, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.fromOffset(0, 0),
    }):Play()
end

-- bikin tombol nav (tabs)
for order, tab in ipairs(TABS) do
    local btn = Instance.new("TextButton")
    btn.Name = tab.id
    btn.Size = UDim2.new(0, 44, 0, 44)
    btn.BackgroundColor3 = COL.hi
    btn.BackgroundTransparency = 1
    btn.AutoButtonColor = false
    btn.Text = ""
    btn.LayoutOrder = order
    btn.Parent = Nav
    local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 8); bc.Parent = btn

    local icon = Instance.new("ImageLabel")
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Position = UDim2.fromScale(0.5, 0.5)
    icon.Size = UDim2.fromOffset(22, 22)
    icon.BackgroundTransparency = 1
    icon.ImageColor3 = COL.iconIdle
    icon.Parent = btn

    local letter = nil
    local got = applyIcon(icon, tab.icon)
    if not got then
        icon.Visible = false
        letter = Instance.new("TextLabel")
        letter.Size = UDim2.fromScale(1, 1)
        letter.BackgroundTransparency = 1
        letter.Font = Enum.Font.GothamBold
        letter.Text = tab.fallback
        letter.TextColor3 = COL.iconIdle
        letter.TextSize = 16
        letter.Parent = btn
    end

    navButtons[tab.id] = { btn = btn, icon = icon, letter = letter }

    btn.MouseButton1Click:Connect(function() selectTab(tab.id) end)
    btn.MouseEnter:Connect(function()
        if activeId ~= tab.id then btn.BackgroundTransparency = 0.92 end
    end)
    btn.MouseLeave:Connect(function()
        if activeId ~= tab.id then btn.BackgroundTransparency = 1 end
    end)
end

-- ====== AVATAR + LOGO LOAD (async) ======
task.spawn(function()
    if not LocalPlayer then return end
    local ok, content = pcall(function()
        return Players:GetUserThumbnailAsync(
            LocalPlayer.UserId,
            Enum.ThumbnailType.HeadShot,
            Enum.ThumbnailSize.Size420x420
        )
    end)
    if ok and content then AvatarImg.Image = content end
end)

task.spawn(function()
    local asset = loadLogo()
    if asset then
        LogoImg.Image = asset
    else
        LogoImg.Visible = false
        LogoFallback.Visible = true
    end
end)

-- ====== DRAG (lewat header / logo) ======
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
Header.InputBegan:Connect(beginDrag)
LogoHolder.InputBegan:Connect(beginDrag)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        Panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- ====== INTRO ANIM + DEFAULT TAB ======
-- Mode hidden: kalo loader minta (getgenv().AutomaHubStartHidden), menu di-BUILD
-- tapi disembunyiin dulu (Panel.Visible=false). Nanti Animate.lua yg munculin
-- lewat getgenv().AutomaHubRevealMenu(). Layout/AbsolutePosition tetep keitung
-- walau Visible=false, jadi logo intro tetep bisa mendarat pas di LogoHolder.
local startHidden = (getgenv and getgenv().AutomaHubStartHidden) and true or false
if startHidden then Panel.Visible = false end

selectTab(TABS[1].id)

local function revealPanel()
    Panel.Visible = true
    Panel.BackgroundTransparency = 1
    TweenService:Create(Panel, TweenInfo.new(0.25), { BackgroundTransparency = 0 }):Play()
end

if startHidden then
    if getgenv then
        getgenv().AutomaHubStartHidden = nil
        getgenv().AutomaHubRevealMenu = revealPanel
    end
else
    revealPanel()
end
