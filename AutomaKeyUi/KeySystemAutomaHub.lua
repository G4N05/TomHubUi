-- ============================================================
-- AutomaHub | KEY SYSTEM UI (custom, glassmorphism)
-- ------------------------------------------------------------
-- Desain niru contoh login-card (frosted glass), diubah jadi:
--   - avatar bulet = foto profil Roblox kita
--   - username kita di bawah avatar
--   - field License Key
--   - link Get Key + Community
--   - tombol CHECK KEY
-- Pas key valid -> card ilang -> onValid() (load menu script).
--
-- Standalone: bisa langsung paste di executor buat tes UI.
-- Key tes (pencet Get Key buat auto-copy): AUTOMAHUB-PREVIEW-2026
-- ============================================================

-- ====== CONFIG ======
local DISCORD_LINK = "https://discord.gg/DGjeCsPQR"
local PREVIEW_KEY  = "AUTOMAHUB-PREVIEW-2026"   -- key tes (sementara)
-- =====================

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local Lighting          = game:GetService("Lighting")
local LocalPlayer       = Players.LocalPlayer

-- ====== HELPERS ======
local function copyToClipboard(text)
    return pcall(function()
        if typeof(setclipboard) == "function" then setclipboard(text)
        elseif typeof(toclipboard) == "function" then toclipboard(text)
        elseif syn and typeof(syn.write_clipboard) == "function" then syn.write_clipboard(text)
        else error("no clipboard fn") end
    end)
end

local ERROR_MSG = {
    INVALID          = "Key salah / ga ketemu.",
    KEY_EXPIRED      = "Key udah expired.",
    HWID_MISMATCH    = "HWID ga cocok.",
    HWID_BANNED      = "HWID kamu kena ban.",
    SERVICE_MISMATCH = "Key buat service lain.",
}

local function validateKey(key)
    if getgenv and typeof(getgenv().AutomaHubValidateKey) == "function" then
        local ok, status = pcall(getgenv().AutomaHubValidateKey, key)
        if ok and type(status) == "string" then return status end
        return "INVALID"
    end
    if not key or key == "" then return "INVALID" end
    if key == PREVIEW_KEY then return "VALID" end
    return "INVALID"
end

-- prefill dari loader kalo ada
local prefillKey = ""
if getgenv and type(getgenv().SCRIPT_KEY) == "string" then
    prefillKey = getgenv().SCRIPT_KEY
end

-- onValid: dipanggil pas key valid. Ganti isinya buat load menu script.
local function onValid(key)
    if getgenv then getgenv().SCRIPT_KEY = key end
    print("[AutomaHub] ACCESS GRANTED. key = " .. tostring(key))
    -- TODO: di sini load script game (UICore/WindUI menu).
end

-- ============================================================
-- BUILD GUI
-- ============================================================
local parentGui = (gethui and gethui()) or game:GetService("CoreGui")
local old = parentGui:FindFirstChild("AutomaHubKeyUI")
if old then old:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutomaHubKeyUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 9999
ScreenGui.Parent = parentGui

-- dim overlay
local Overlay = Instance.new("Frame")
Overlay.Name = "Overlay"
Overlay.Size = UDim2.fromScale(1, 1)
Overlay.BackgroundColor3 = Color3.fromRGB(10, 8, 18)
Overlay.BackgroundTransparency = 1
Overlay.BorderSizePixel = 0
Overlay.Parent = ScreenGui

-- frosted background blur
local Blur = Instance.new("BlurEffect")
Blur.Name = "AutomaHubKeyBlur"
Blur.Size = 0
Blur.Parent = Lighting

-- ====== CARD ======
local Card = Instance.new("Frame")
Card.Name = "Card"
Card.AnchorPoint = Vector2.new(0.5, 0.5)
Card.Position = UDim2.fromScale(0.5, 0.5)
Card.Size = UDim2.fromOffset(330, 0) -- height di-tween masuk
Card.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
Card.BackgroundTransparency = 0.86
Card.BorderSizePixel = 0
Card.ClipsDescendants = true
Card.Parent = ScreenGui

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 18)
cardCorner.Parent = Card

local cardStroke = Instance.new("UIStroke")
cardStroke.Color = Color3.fromRGB(255, 255, 255)
cardStroke.Transparency = 0.6
cardStroke.Thickness = 1.5
cardStroke.Parent = Card

-- gradient tipis biar ada depth
local cardGrad = Instance.new("UIGradient")
cardGrad.Rotation = 90
cardGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(190, 170, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 170, 255)),
})
cardGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.86),
    NumberSequenceKeypoint.new(1, 0.92),
})
cardGrad.Parent = Card

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 64)
pad.PaddingBottom = UDim.new(0, 22)
pad.PaddingLeft = UDim.new(0, 26)
pad.PaddingRight = UDim.new(0, 26)
pad.Parent = Card

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 10)
layout.Parent = Card

-- ====== AVATAR (foto profil Roblox) ======
local AvatarHolder = Instance.new("Frame")
AvatarHolder.Name = "AvatarHolder"
AvatarHolder.Size = UDim2.fromOffset(92, 92)
AvatarHolder.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
AvatarHolder.BackgroundTransparency = 0.75
AvatarHolder.LayoutOrder = 1
AvatarHolder.Parent = Card

local avHolderCorner = Instance.new("UICorner")
avHolderCorner.CornerRadius = UDim.new(1, 0)
avHolderCorner.Parent = AvatarHolder

local avHolderStroke = Instance.new("UIStroke")
avHolderStroke.Color = Color3.fromRGB(255, 255, 255)
avHolderStroke.Transparency = 0.3
avHolderStroke.Thickness = 2
avHolderStroke.Parent = AvatarHolder

local Avatar = Instance.new("ImageLabel")
Avatar.Name = "Avatar"
Avatar.AnchorPoint = Vector2.new(0.5, 0.5)
Avatar.Position = UDim2.fromScale(0.5, 0.5)
Avatar.Size = UDim2.fromOffset(84, 84)
Avatar.BackgroundTransparency = 1
Avatar.Image = "rbxassetid://0"
Avatar.Parent = AvatarHolder

local avCorner = Instance.new("UICorner")
avCorner.CornerRadius = UDim.new(1, 0)
avCorner.Parent = Avatar

-- fetch foto profil
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

-- ====== USERNAME (di bawah avatar) ======
local NameLabel = Instance.new("TextLabel")
NameLabel.Name = "DisplayName"
NameLabel.Size = UDim2.new(1, 0, 0, 22)
NameLabel.BackgroundTransparency = 1
NameLabel.Font = Enum.Font.GothamBold
NameLabel.Text = LocalPlayer.DisplayName
NameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
NameLabel.TextSize = 18
NameLabel.LayoutOrder = 2
NameLabel.Parent = Card

local UserLabel = Instance.new("TextLabel")
UserLabel.Name = "Username"
UserLabel.Size = UDim2.new(1, 0, 0, 16)
UserLabel.BackgroundTransparency = 1
UserLabel.Font = Enum.Font.Gotham
UserLabel.Text = "@" .. LocalPlayer.Name
UserLabel.TextColor3 = Color3.fromRGB(225, 220, 255)
UserLabel.TextTransparency = 0.25
UserLabel.TextSize = 13
UserLabel.LayoutOrder = 3
UserLabel.Parent = Card

-- spacer
local Spacer1 = Instance.new("Frame")
Spacer1.Size = UDim2.new(1, 0, 0, 6)
Spacer1.BackgroundTransparency = 1
Spacer1.LayoutOrder = 4
Spacer1.Parent = Card

-- ====== KEY INPUT ======
local InputBox = Instance.new("Frame")
InputBox.Name = "InputBox"
InputBox.Size = UDim2.new(1, 0, 0, 42)
InputBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
InputBox.BackgroundTransparency = 0.8
InputBox.LayoutOrder = 5
InputBox.Parent = Card

local inputCorner = Instance.new("UICorner")
inputCorner.CornerRadius = UDim.new(0, 10)
inputCorner.Parent = InputBox

local inputStroke = Instance.new("UIStroke")
inputStroke.Color = Color3.fromRGB(255, 255, 255)
inputStroke.Transparency = 0.55
inputStroke.Thickness = 1
inputStroke.Parent = InputBox

local KeyTextBox = Instance.new("TextBox")
KeyTextBox.Name = "KeyTextBox"
KeyTextBox.Size = UDim2.new(1, -28, 1, 0)
KeyTextBox.Position = UDim2.fromOffset(14, 0)
KeyTextBox.BackgroundTransparency = 1
KeyTextBox.Font = Enum.Font.Gotham
KeyTextBox.PlaceholderText = "License Key"
KeyTextBox.PlaceholderColor3 = Color3.fromRGB(225, 220, 255)
KeyTextBox.Text = prefillKey
KeyTextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
KeyTextBox.TextSize = 14
KeyTextBox.TextXAlignment = Enum.TextXAlignment.Left
KeyTextBox.ClearTextOnFocus = false
KeyTextBox.Parent = InputBox

-- ====== ROW: Get Key | Community ======
local Row = Instance.new("Frame")
Row.Name = "Row"
Row.Size = UDim2.new(1, 0, 0, 18)
Row.BackgroundTransparency = 1
Row.LayoutOrder = 6
Row.Parent = Card

local GetKeyBtn = Instance.new("TextButton")
GetKeyBtn.Name = "GetKey"
GetKeyBtn.Size = UDim2.fromScale(0.5, 1)
GetKeyBtn.Position = UDim2.fromScale(0, 0)
GetKeyBtn.BackgroundTransparency = 1
GetKeyBtn.Font = Enum.Font.GothamMedium
GetKeyBtn.Text = "Get Key"
GetKeyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
GetKeyBtn.TextSize = 12
GetKeyBtn.TextXAlignment = Enum.TextXAlignment.Left
GetKeyBtn.AutoButtonColor = false
GetKeyBtn.Parent = Row

local CommBtn = Instance.new("TextButton")
CommBtn.Name = "Community"
CommBtn.Size = UDim2.fromScale(0.5, 1)
CommBtn.Position = UDim2.fromScale(0.5, 0)
CommBtn.BackgroundTransparency = 1
CommBtn.Font = Enum.Font.GothamMedium
CommBtn.Text = "Community"
CommBtn.TextColor3 = Color3.fromRGB(225, 220, 255)
CommBtn.TextSize = 12
CommBtn.TextXAlignment = Enum.TextXAlignment.Right
CommBtn.AutoButtonColor = false
CommBtn.Parent = Row

-- ====== CHECK KEY BUTTON ======
local CheckBtn = Instance.new("TextButton")
CheckBtn.Name = "CheckKey"
CheckBtn.Size = UDim2.new(1, 0, 0, 44)
CheckBtn.BackgroundColor3 = Color3.fromRGB(47, 51, 82)
CheckBtn.Font = Enum.Font.GothamBold
CheckBtn.Text = "CHECK KEY"
CheckBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CheckBtn.TextSize = 15
CheckBtn.AutoButtonColor = false
CheckBtn.LayoutOrder = 7
CheckBtn.Parent = Card

local checkCorner = Instance.new("UICorner")
checkCorner.CornerRadius = UDim.new(0, 11)
checkCorner.Parent = CheckBtn

-- ====== STATUS LABEL ======
local Status = Instance.new("TextLabel")
Status.Name = "Status"
Status.Size = UDim2.new(1, 0, 0, 16)
Status.BackgroundTransparency = 1
Status.Font = Enum.Font.Gotham
Status.Text = ""
Status.TextColor3 = Color3.fromRGB(255, 120, 120)
Status.TextSize = 12
Status.TextWrapped = true
Status.LayoutOrder = 8
Status.Parent = Card

-- ============================================================
-- INTERAKSI
-- ============================================================
local function setStatus(text, isError)
    Status.Text = text or ""
    Status.TextColor3 = isError and Color3.fromRGB(255, 120, 120) or Color3.fromRGB(150, 255, 170)
end

local function pulse(btn)
    TweenService:Create(btn, TweenInfo.new(0.08), { TextTransparency = 0.4 }):Play()
    task.delay(0.12, function()
        TweenService:Create(btn, TweenInfo.new(0.12), { TextTransparency = 0 }):Play()
    end)
end

GetKeyBtn.MouseButton1Click:Connect(function()
    pulse(GetKeyBtn)
    if copyToClipboard(PREVIEW_KEY) then
        setStatus("Key valid kecopy ke clipboard, paste di atas.", false)
    else
        setStatus("Gagal akses clipboard.", true)
    end
end)

CommBtn.MouseButton1Click:Connect(function()
    pulse(CommBtn)
    if copyToClipboard(DISCORD_LINK) then
        setStatus("Link Discord kecopy ke clipboard.", false)
    else
        setStatus(DISCORD_LINK, false)
    end
end)

local busy = false
local function closeUI()
    TweenService:Create(Blur, TweenInfo.new(0.3), { Size = 0 }):Play()
    TweenService:Create(Overlay, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
    local t = TweenService:Create(Card, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = UDim2.fromOffset(330, 0),
        BackgroundTransparency = 1,
    })
    t:Play()
    t.Completed:Wait()
    pcall(function() Blur:Destroy() end)
    ScreenGui:Destroy()
end

CheckBtn.MouseButton1Click:Connect(function()
    if busy then return end
    busy = true
    local key = KeyTextBox.Text
    if (not key or key == "") and getgenv and type(getgenv().SCRIPT_KEY) == "string" then
        key = getgenv().SCRIPT_KEY
    end

    CheckBtn.Text = "CHECKING..."
    setStatus("Lagi ngecek key...", false)

    task.spawn(function()
        task.wait(0.35)
        local status = validateKey(key)
        if status == "VALID" then
            CheckBtn.Text = "ACCESS GRANTED"
            setStatus("Key valid! Loading menu...", false)
            task.wait(0.6)
            closeUI()
            local ok, err = pcall(onValid, key)
            if not ok then warn("[AutomaHub] onValid error: " .. tostring(err)) end
        else
            CheckBtn.Text = "CHECK KEY"
            setStatus(ERROR_MSG[status] or ERROR_MSG.INVALID, true)
            busy = false
        end
    end)
end)

-- enter buat submit
KeyTextBox.FocusLost:Connect(function(enter)
    if enter then CheckBtn.MouseButton1Click:Fire() end
end)

-- hover effect tombol check
CheckBtn.MouseEnter:Connect(function()
    TweenService:Create(CheckBtn, TweenInfo.new(0.15), { Size = UDim2.new(1, 6, 0, 46) }):Play()
end)
CheckBtn.MouseLeave:Connect(function()
    TweenService:Create(CheckBtn, TweenInfo.new(0.15), { Size = UDim2.new(1, 0, 0, 44) }):Play()
end)

-- ====== DRAG ======
local dragging, dragStart, startPos
Card.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Card.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        Card.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- ============================================================
-- ANIMASI MASUK
-- ============================================================
TweenService:Create(Overlay, TweenInfo.new(0.35), { BackgroundTransparency = 0.35 }):Play()
TweenService:Create(Blur, TweenInfo.new(0.45), { Size = 18 }):Play()
TweenService:Create(Card, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Size = UDim2.fromOffset(330, 372),
}):Play()
