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
-- Folder module per-map
local MAPS_URL = REPO .. "AutomaHubMenu/maps/"
-- =========================

-- guard biar ga jalan dobel
if getgenv and getgenv().AutomaHubLoaderRan then return end
if getgenv then getgenv().AutomaHubLoaderRan = true end

-- matiin demo bawaan Load.lua (dipakai sebagai module)
if getgenv then getgenv().AutomaHubLoaderModule = true end

local function httpGet(url)
    local ok, res = pcall(function() return game:HttpGet(url) end)
    if ok and type(res) == "string" and #res > 30 then return res end
    return nil
end

local function runSource(src)
    if not src then return nil end
    local loader = loadstring or load
    if not loader then return nil end
    local fn = loader(src)
    if not fn then return nil end
    local ok, ret = pcall(fn)
    if not ok then
        warn("[AutomaHub] run error: " .. tostring(ret))
        return nil
    end
    return ret
end

-- ============================================================
-- PER-MAP ROUTING
-- ============================================================
local function loadMapConfig()
    local placeId = game.PlaceId
    -- coba fetch module per-map: maps/<placeId>.lua
    local mapUrl = MAPS_URL .. tostring(placeId) .. ".lua"
    local mapSrc = httpGet(mapUrl)
    if not mapSrc then
        -- ga ada module buat PlaceId ini
        print("[AutomaHub] No script module for PlaceId " .. tostring(placeId))
        return nil
    end

    -- module harus return table dengan field .tabs
    -- contoh: return { tabs = { { id="Combat", icon="swords", ... } } }
    local fn = loadstring or load
    if not fn then return nil end
    local module = fn(mapSrc)
    if not module then return nil end
    local ok, config = pcall(module)
    if not ok or type(config) ~= "table" then
        warn("[AutomaHub] Map module returned invalid config: " .. tostring(config))
        return nil
    end

    -- support 2 format:
    --   1) return { tabs = {...} }         (langsung)
    --   2) return function(AutomaHub) ... end  (via API)
    if type(config.tabs) == "table" then
        return config
    elseif type(config) == "function" then
        -- config adalah function AutomaHub(api) -> setup tabs via API
        -- jalankan setelah menu_ui di-build (di onGranted)
        return config
    end

    warn("[AutomaHub] Map module has no .tabs or function: " .. tostring(placeId))
    return nil
end

-- ============================================================
-- dipanggil pas key VALID (hook dari KeySystemAutomaHub.lua onValid)
-- ============================================================
local function onGranted(key)
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
    local Loader = runSource(httpGet(LOAD_URL))
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
        runSource(menuSrc)
        -- kalo mapConfig adalah function (API mode), panggil sekarang
        -- (menu udah ke-build, API getgenv().AutomaHub udah ada)
        if getgenv and type(getgenv().AutomaHubMapFn) == "function" then
            local api = getgenv().AutomaHub
            if api then
                pcall(getgenv().AutomaHubMapFn, api)
                if type(api.rebuild) == "function" then
                    pcall(api.rebuild)
                end
            end
            getgenv().AutomaHubMapFn = nil
        end
    end
    if L then L:setProgress(0.9) end

    local function startIntro()
        if animSrc then
            runSource(animSrc)
        else
            runSource(httpGet(ANIM_URL))
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

-- daftarin hook SEBELUM key UI dibuka
if getgenv then getgenv().AutomaHubOnGranted = onGranted end

-- ============================================================
-- buka Key UI (dia yang manggil onGranted pas valid)
-- ============================================================
local keySrc = httpGet(KEY_URL)
if keySrc then
    runSource(keySrc)
else
    warn("[AutomaHub] gagal load Key UI dari " .. KEY_URL)
end
