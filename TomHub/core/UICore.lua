-- ============================================================
-- TomHub | UICore (UI SHELL, shared semua game)
-- ------------------------------------------------------------
-- Tanggung jawab: bersihin CoreGui, load WindUI, bikin window +
-- toggle key + fix mouse, sediain services & helper (base).
-- GA NGERTI game apapun. Tiap game plug ke sini lewat `base`.
--
-- Dipanggil: local base = loadstring(UICore)({ title = "TomHub" })
-- Return: tabel `base` yang dipake script game.
-- ============================================================
return function(opts)
    opts = opts or {}

    local CoreGui = game:GetService("CoreGui")
    if CoreGui:FindFirstChild("WindUI") then
        CoreGui:FindFirstChild("WindUI"):Destroy()
    end

    -- [MULTI-CDN FETCH] bypass blokir ISP (raw.github sering keblokir)
    local function multiFetch(urls)
        for _, url in ipairs(urls) do
            local ok, content = pcall(function() return game:HttpGet(url) end)
            if ok and content and #content > 100 then
                return content
            end
        end
        return nil
    end

    -- [LOAD WINDUI] library pihak ketiga, di-fetch dari repo aslinya
    local WindUI = nil
    do
        local content = multiFetch({
            "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua",
            "https://cdn.jsdelivr.net/gh/Footagesus/WindUI@main/dist/main.lua",
            "https://raw.gitmirror.com/Footagesus/WindUI/main/dist/main.lua",
        })
        if content and #content > 500 then
            local fn = loadstring(content)
            if fn then
                local ok, lib = pcall(fn)
                if ok and lib then WindUI = lib end
            end
        end
    end
    if not WindUI then
        error("[TomHub] Gagal memuat WindUI! Nyalain Cloudflare WARP atau cek koneksi.")
    end

    -- [SERVICES]
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local CollectionService = game:GetService("CollectionService")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Teams = game:GetService("Teams")
    local VirtualInputManager = game:GetService("VirtualInputManager")
    local Workspace = game:GetService("Workspace")

    -- [WINDOW]
    local Window = WindUI:CreateWindow({
        Title = opts.title or "TomHub",
        Author = opts.author or "by LO",
        Size = opts.size or UDim2.fromOffset(580, 400),
        Transparent = true,
        Theme = "Dark",
    })
    Window:SetToggleKey(opts.toggleKey or Enum.KeyCode.H)

    -- [FIX MOUSE LOCK] generic: cursor bebas selama UI kebuka.
    -- Lock-on-close diatur game lewat base.setMatchChecker(fn).
    local matchChecker = function() return false end
    local windowOpen = false
    Window:OnOpen(function()
        windowOpen = true
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
    end)
    Window:OnClose(function()
        windowOpen = false
        if matchChecker() then
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
            UserInputService.MouseIconEnabled = false
        else
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
        end
    end)
    RunService.RenderStepped:Connect(function()
        if windowOpen and UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
        end
    end)

    -- [BASE] dibagi ke script game
    local base = {
        WindUI = WindUI,
        Window = Window,

        Players = Players,
        ReplicatedStorage = ReplicatedStorage,
        CollectionService = CollectionService,
        RunService = RunService,
        UserInputService = UserInputService,
        Teams = Teams,
        VirtualInputManager = VirtualInputManager,
        Workspace = Workspace,
        LocalPlayer = Players.LocalPlayer,

        multiFetch = multiFetch,
        -- game daftarin pengecek "lagi in-match" buat mouse-lock pas UI ditutup
        setMatchChecker = function(fn)
            if type(fn) == "function" then matchChecker = fn end
        end,
    }

    return base
end
