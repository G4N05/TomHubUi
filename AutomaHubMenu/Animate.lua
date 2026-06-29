
if getgenv and getgenv().AutomaHubIntroRan then return end
if getgenv then getgenv().AutomaHubIntroRan = true end

local Lighting        = game:GetService("Lighting")
local TweenService    = game:GetService("TweenService")
local RunService      = game:GetService("RunService")

-- ====== CONFIG ======
local LOGO_URL = "https://raw.githubusercontent.com/G4N05/TomHubUi/main/Icon/AutomaHubLogo.png"
local MENU_URL = "https://raw.githubusercontent.com/G4N05/TomHubUi/main/AutomaHubMenu/menu_ui.lua"

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
    if ok then return asset end
    return nil
end

local logoAsset = loadLogo()
local parentGui = (gethui and gethui()) or game:GetService("CoreGui")

-- ====== OVERLAY ======
local Intro = Instance.new("ScreenGui")
Intro.Name = "AutomaHubIntro"
Intro.ResetOnSpawn = false
Intro.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Intro.IgnoreGuiInset = true
Intro.DisplayOrder = 1000000  -- di atas menu (9999)
Intro.Parent = parentGui

-- backdrop gelap (semi transparan biar blur game keliatan = efek frosted)
local Dark = Instance.new("Frame")
Dark.Name = "Dark"
Dark.Size = UDim2.fromScale(1, 1)
Dark.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
Dark.BackgroundTransparency = 0.22
Dark.BorderSizePixel = 0
Dark.ZIndex = 1
Dark.Parent = Intro

-- logo intro (gambar)
local Logo = Instance.new("ImageLabel")
Logo.Name = "IntroLogo"
Logo.AnchorPoint = Vector2.new(0.5, 0.5)
Logo.Position = UDim2.fromScale(0.5, 0.5)
Logo.Size = UDim2.fromOffset(220, 220)
Logo.BackgroundTransparency = 1
Logo.ScaleType = Enum.ScaleType.Fit
Logo.ImageTransparency = 1
Logo.ZIndex = 3
Logo.Parent = Intro

-- fallback huruf "A" kalo logo gagal load
local LogoFallback = Instance.new("TextLabel")
LogoFallback.Name = "IntroLogoFallback"
LogoFallback.AnchorPoint = Vector2.new(0.5, 0.5)
LogoFallback.Position = UDim2.fromScale(0.5, 0.5)
LogoFallback.Size = UDim2.fromOffset(220, 220)
LogoFallback.BackgroundTransparency = 1
LogoFallback.Font = Enum.Font.GothamBold
LogoFallback.Text = "A"
LogoFallback.TextColor3 = Color3.fromRGB(232, 230, 228)
LogoFallback.TextSize = 120
LogoFallback.TextTransparency = 1
LogoFallback.ZIndex = 3
LogoFallback.Visible = false
LogoFallback.Parent = Intro

local usingFallback = false
if logoAsset then
    Logo.Image = logoAsset
else
    usingFallback = true
    Logo.Visible = false
    LogoFallback.Visible = true
end

-- elemen aktif yg dianimasiin (logo / fallback)
local Mark = usingFallback and LogoFallback or Logo
local transProp = usingFallback and "TextTransparency" or "ImageTransparency"

-- status text mono (vibe industrial)
local Status = Instance.new("TextLabel")
Status.Name = "Status"
Status.AnchorPoint = Vector2.new(0.5, 0)
Status.Position = UDim2.new(0.5, 0, 0.5, 132)
Status.Size = UDim2.fromOffset(360, 16)
Status.BackgroundTransparency = 1
Status.Font = Enum.Font.Code
Status.Text = "INITIALIZING"
Status.TextColor3 = Color3.fromRGB(140, 140, 140)
Status.TextSize = 12
Status.TextTransparency = 1
Status.ZIndex = 3
Status.Parent = Intro

-- blur (di game world)
local Blur = Instance.new("BlurEffect")
Blur.Name = "AutomaHubIntroBlur"
Blur.Size = 0
Blur.Parent = Lighting

-- ====== SEQUENCE ======
task.spawn(function()
    -- Phase 1: blur masuk + logo fade-in & settle (dari gede dikit -> normal)
    Mark.Size = UDim2.fromOffset(280, 280)
    TweenService:Create(Blur, TweenInfo.new(0.5), { Size = 24 }):Play()
    TweenService:Create(Mark, TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(200, 200),
    }):Play()
    TweenService:Create(Mark, TweenInfo.new(0.45), { [transProp] = 0 }):Play()
    TweenService:Create(Status, TweenInfo.new(0.45), { TextTransparency = 0.15 }):Play()

    task.wait(0.7)
    Status.Text = "LOADING INTERFACE"

    -- Phase 2: load GUI menu dari GitHub (build di belakang overlay)
    pcall(function()
        local src = game:HttpGet(MENU_URL)
        local loader = loadstring or load
        if loader then
            local fn = loader(src)
            if fn then fn() end
        end
    end)

    -- cari logo asli di menu (AutomaHubMenu -> Panel -> Sidebar -> LogoHolder)
    local realHolder, realImg, realFallback
    local t0 = os.clock()
    repeat
        local sg = parentGui:FindFirstChild("AutomaHubMenu")
        if sg then
            local panel = sg:FindFirstChild("Panel")
            local sidebar = panel and panel:FindFirstChild("Sidebar")
            realHolder = sidebar and sidebar:FindFirstChild("LogoHolder")
            if realHolder then
                realImg = realHolder:FindFirstChild("LogoImg")
                realFallback = realHolder:FindFirstChildWhichIsA("TextLabel")
            end
        end
        if realHolder and realHolder.AbsoluteSize.X > 0 then break end
        RunService.RenderStepped:Wait()
    until (os.clock() - t0) > 4

    -- pasang logo preloaded ke logo asli biar ga flash pas reveal
    if realImg and logoAsset then
        realImg.Image = logoAsset
        realImg.Visible = true
        if realFallback then realFallback.Visible = false end
    end

    Status.Text = "READY"

    if realHolder and realHolder.AbsoluteSize.X > 0 then
        -- target = tengah LogoHolder (px layar)
        local pos = realHolder.AbsolutePosition
        local sz = realHolder.AbsoluteSize
        local cx = pos.X + sz.X / 2
        local cy = pos.Y + sz.Y / 2

        local moveInfo = TweenInfo.new(0.78, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
        TweenService:Create(Mark, moveInfo, {
            Position = UDim2.fromOffset(cx, cy),
            Size = UDim2.fromOffset(sz.X, sz.Y),
        }):Play()
        TweenService:Create(Status, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()

        -- reveal: blur & gelap ilang sambil logo terbang
        task.wait(0.18)
        TweenService:Create(Blur, TweenInfo.new(0.6), { Size = 0 }):Play()
        TweenService:Create(Dark, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
        task.wait(0.62)

        -- handoff: logo intro fade out (logo GUI asli udah pas di bawahnya)
        TweenService:Create(Mark, TweenInfo.new(0.18), { [transProp] = 1 }):Play()
        task.wait(0.2)
    else
        -- fallback kalo menu ga ketemu: fade out semua aja
        TweenService:Create(Blur, TweenInfo.new(0.5), { Size = 0 }):Play()
        TweenService:Create(Dark, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
        TweenService:Create(Mark, TweenInfo.new(0.5), { [transProp] = 1 }):Play()
        task.wait(0.55)
    end

    -- cleanup
    if Blur then Blur:Destroy() end
    if Intro then Intro:Destroy() end
    if getgenv then getgenv().AutomaHubIntroRan = nil end
end)
