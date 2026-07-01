-- ============================================================
-- AutomaHub | UNIVERSAL LOADER  (Key -> Loading -> Intro -> Menu)
-- ------------------------------------------------------------
-- Entry TUNGGAL. User cukup jalanin ini:
--   loadstring(game:HttpGet(
--     "https://raw.githubusercontent.com/G4N05/TomHubUi/main/AutomaHubMenu/AutomaHubLoader.lua"
--   ))()
--
-- Alur:
--   1) Key UI (KeySystemAutomaHub.lua) -> user input license key
--   2) Key VALID -> Load.lua (gear loading + progress) sambil prefetch menu
--   3) Loading kelar -> Animate.lua (logo intro + blur) -> handoff logo
--   4) menu_ui.lua tampil (config-driven: support multi-map atau placeholder)
--
-- Per-map routing:
--   - Deteksi game.PlaceId -> cari module di maps/<placeId>.lua
--   - Module return config table { tabs = {...} } -> set getgenv().AutomaHubConfig
--   - Kalo PlaceId ga kekenal -> config kosong -> menu tampilin "Unsupported Experience"
-- ============================================================

-- ====== CONFIG REPO ======
local REPO     = "https://raw.githubusercontent.com/G4N05/TomHubUi/main/"
local KEY_URL  = REPO .. "AutomaKeyUi/KeySystemAutomaHub.lua"
local LOAD_URL = REPO .. "AutomaHubMenu/Load.lua"
local ANIM_URL = REPO .. "AutomaHubMenu/Animate.lua"
local MENU_URL = REPO .. "AutomaHubMenu/menu_ui.lua"
-- =========================
-- Per-map routing: PlaceId -> URL loader luaegis (1 script luaegis per map)
local MAP_LOADERS = {
    [93978595733734] = "https://luaegis.net/scripts/v4/loaders/c5415f48-f199-4ae5-ad15-a398710f53ee.lua",
}
-- =========================

-- guard biar ga jalan dobel
if getgenv and getgenv().AutomaHubLoaderRan then return end
if getgenv then getgenv().AutomaHubLoaderRan = true end

-- matiin demo bawaan Load.lua (dipakai sebagai module)
if getgenv then getgenv().AutomaHubLoaderModule = true end

local function httpGet(url)
    -- retry 3x biar ga gampang gagal pas HttpGet hiccup / rate-limit
    for attempt = 1, 3 do
        local ok, res = pcall(function() return game:HttpGet(url) end)
        if ok and type(res) == "string" and #res > 30 then return res end
        if attempt < 3 then task.wait(0.5 * attempt) end
    end
    return nil
end

local function runSource(src, label)
    if not src then return nil end
    local loader = loadstring or load
    if not loader then return nil end
    local fn = loader(src)
    if not fn then
        warn("[AutomaHub] " .. (label or "source") .. " failed to compile")
        return nil
    end
    local ok, ret = pcall(fn)
    if not ok then
        warn("[AutomaHub] " .. (label or "source") .. " run error: " .. tostring(ret))
        return nil
    end
    return ret
end

-- ============================================================
-- KEY PERSIST (auto-check: inget key valid buat execute berikutnya)
-- ============================================================
local KEY_FILE = "AutomaHub/key.txt"
local function saveKey(key)
    if type(key) ~= "string" or key == "" then return end
    pcall(function()
        if type(makefolder) == "function" and type(isfolder) == "function" and not isfolder("AutomaHub") then
            makefolder("AutomaHub")
        end
        if type(writefile) == "function" then writefile(KEY_FILE, key) end
    end)
end
local function readSavedKey()
    local ok, data = pcall(function()
        if type(isfile) == "function" and isfile(KEY_FILE) and type(readfile) == "function" then
            return readfile(KEY_FILE)
        end
        return nil
    end)
    if ok and type(data) == "string" and data ~= "" then return data end
    return nil
end
local function clearSavedKey()
    pcall(function()
        if type(isfile) == "function" and isfile(KEY_FILE) and type(delfile) == "function" then
            delfile(KEY_FILE)
        end
    end)
end

-- ============================================================
-- PER-MAP ROUTING
-- ============================================================
local function loadMapConfig()
    -- udah ke-load pas validasi key (AutomaHubValidateKey)? pakai itu, jangan dobel-load.
    if getgenv then
        if type(getgenv().AutomaHubConfig) == "table" then return getgenv().AutomaHubConfig end
        if type(getgenv().AutomaHubMapFn) == "function" then return getgenv().AutomaHubMapFn end
    end

    local placeId = game.PlaceId
    -- cari loader luaegis buat PlaceId ini
    local loaderUrl = MAP_LOADERS[placeId]
    if not loaderUrl then
        return nil
    end

    -- jembatani key AutomaHub -> script_key luaegis (Jalan A)
    if getgenv and type(getgenv().SCRIPT_KEY) == "string" then
        getgenv().script_key = getgenv().SCRIPT_KEY
    end

    -- jalanin loader luaegis. Script asli yang di-protect WAJIB daftar sendiri:
    --   getgenv().AutomaHubMapFn = function(AutomaHub, services) ... end
    -- (luaegis ga jamin return value tembus, jadi kita baca dari getgenv)
    local src = httpGet(loaderUrl)
    if not src then
        warn("[AutomaHub] Gagal fetch luaegis loader buat PlaceId " .. tostring(placeId))
        return nil
    end
    runSource(src, "luaegis:" .. tostring(placeId))

    -- baca balik hasil yang didaftarin script map
    if getgenv then
        if type(getgenv().AutomaHubConfig) == "table" then
            return getgenv().AutomaHubConfig
        end
        if type(getgenv().AutomaHubMapFn) == "function" then
            return getgenv().AutomaHubMapFn
        end
    end

    warn("[AutomaHub] Script map ga daftarin AutomaHubMapFn/AutomaHubConfig: " .. tostring(placeId))
    return nil
end

-- ============================================================
-- dipanggil pas key VALID (hook dari KeySystemAutomaHub.lua onValid)
-- ============================================================
local function onGranted(key)
    -- inget key valid ini buat auto-check di execute berikutnya
    saveKey(key)
    -- [0] cek per-map config (sebelum loading screen)
    local mapConfig = loadMapConfig()

    -- set config ke getgenv supaya menu_ui bisa baca
    if getgenv then
        if type(mapConfig) == "table" then
            getgenv().AutomaHubConfig = mapConfig
            getgenv().AutomaHubMapFn = nil
        elseif type(mapConfig) == "function" then
            getgenv().AutomaHubConfig = nil
            getgenv().AutomaHubMapFn = mapConfig
        else
            -- ga ada config -> Unsupported Experience placeholder
            getgenv().AutomaHubConfig = nil
            getgenv().AutomaHubMapFn = nil
        end
    end

    -- [1] loading screen (Load.lua return Loader table)
    local Loader = runSource(httpGet(LOAD_URL), "Load.lua")
    local L
    if type(Loader) == "table" and type(Loader.new) == "function" then
        local ok, inst = pcall(Loader.new)
        if ok then L = inst end
    end
    if L then L:setStatus("Connecting to AutomaHub...") end

    -- [2] ambil source-nya
    if L then L:setProgress(0.15) end
    local menuSrc = httpGet(MENU_URL)
    if L then L:setStatus("Loading interface..."); L:setProgress(0.4) end
    local animSrc = httpGet(ANIM_URL)
    if L then L:setProgress(0.6) end

    -- BUILD menu BENERAN pas loading, tapi HIDDEN (ga dimunculin dulu).
    -- menu_ui akan baca getgenv().AutomaHubConfig (table config) atau
    -- tampilin "Unsupported Experience" kalo config kosong.
    if menuSrc then
        if getgenv then getgenv().AutomaHubStartHidden = true end
        runSource(menuSrc, "menu_ui.lua")
        -- kalo mapConfig adalah function (API mode), panggil sekarang
        -- (menu udah ke-build, API getgenv().AutomaHub udah ada)
        if getgenv and type(getgenv().AutomaHubMapFn) == "function" then
            -- coba ambas: getgenv() dan _G (beberapa executor getgenv() balikin table beda)
            local api = (getgenv and getgenv().AutomaHub) or _G.AutomaHub
            if api then
                local services = {
                    Players = game:GetService("Players"),
                    ReplicatedStorage = game:GetService("ReplicatedStorage"),
                    CollectionService = game:GetService("CollectionService"),
                    RunService = game:GetService("RunService"),
                    UserInputService = game:GetService("UserInputService"),
                    Teams = game:GetService("Teams"),
                    VirtualInputManager = game:GetService("VirtualInputManager"),
                    Workspace = game:GetService("Workspace"),
                    LocalPlayer = game:GetService("Players").LocalPlayer,
                }
                -- JANGAN pcall — biar error keliatan di console!
                getgenv().AutomaHubMapFn(api, services)
                if type(api.rebuild) == "function" then
                    api.rebuild()
                end
            else
                warn("[AutomaHub] ERROR: AutomaHub API table tidak ditemukan! getgenv=" .. tostring(getgenv and getgenv().AutomaHub) .. " _G=" .. tostring(_G.AutomaHub))
            end
            getgenv().AutomaHubMapFn = nil
        end
    end
    if L then L:setProgress(0.9) end

    local function startIntro()
        if animSrc then
            runSource(animSrc, "Animate.lua")
        else
            runSource(httpGet(ANIM_URL), "Animate.lua")
        end
    end

    if L then
        L:setStatus("Ready")
        L:setProgress(1)
        L:finish(function()
            startIntro()
        end)
    else
        startIntro()
    end
end

-- ============================================================
-- VALIDASI KEY via luaegis (Jalan A: luaegis = key system tunggal)
-- KeySystemAutomaHub.lua otomatis pakai hook ini kalau ada.
-- ============================================================
local function validateKeyViaLuaegis(key)
    if not key or key == "" then return "INVALID" end
    local placeId = game.PlaceId
    local loaderUrl = MAP_LOADERS[placeId]
    -- map ga didukung -> tetep ijinin masuk (nanti menu "Unsupported Experience")
    if not loaderUrl then return "VALID" end

    -- set key buat luaegis, reset penanda map
    if getgenv then
        getgenv().script_key = key
        getgenv().AutomaHubMapFn = nil
        getgenv().AutomaHubConfig = nil
    end

    -- jalanin loader luaegis = sekaligus validasi key + load map
    local src = httpGet(loaderUrl)
    if not src then return "INVALID" end
    pcall(function() runSource(src, "luaegis-validate") end)

    -- tunggu bentar kalau luaegis async, cek penanda map kedaftar
    local deadline = os.clock() + 8
    while os.clock() < deadline do
        if getgenv and (type(getgenv().AutomaHubMapFn) == "function" or type(getgenv().AutomaHubConfig) == "table") then
            return "VALID"
        end
        task.wait(0.1)
    end
    return "INVALID"
end

-- daftarin hook SEBELUM key UI dibuka
if getgenv then
    getgenv().AutomaHubOnGranted = onGranted
    getgenv().AutomaHubValidateKey = validateKeyViaLuaegis
end

-- ============================================================
-- AUTO-CHECK: coba key tersimpan dulu (skip Key UI kalau masih valid)
-- ============================================================
local autoOk = false
local savedKey = readSavedKey()
if savedKey then
    if getgenv then getgenv().SCRIPT_KEY = savedKey end
    if validateKeyViaLuaegis(savedKey) == "VALID" then
        autoOk = true
        onGranted(savedKey)
    else
        -- key tersimpan udah ga valid / expired -> buang, lanjut Key UI manual
        clearSavedKey()
        if getgenv then getgenv().SCRIPT_KEY = nil end
    end
end

-- ============================================================
-- buka Key UI (dia yang manggil onGranted pas valid)
-- ============================================================
if not autoOk then
    local keySrc = httpGet(KEY_URL)
    if keySrc then
        runSource(keySrc, "KeySystem")
    else
        warn("[AutomaHub] gagal load Key UI dari " .. KEY_URL)
    end
end
