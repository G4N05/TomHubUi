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
--   - Module return function(AutomaHub, services) -> set getgenv().AutomaHubMapFn (API mode)
--   - Kalo PlaceId ga dikenal -> config kosong -> menu tampilin "Unsupported Experience"
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
    local mapUrl = MAPS_URL .. tostring(placeId) .. ".lua"
    local mapSrc = httpGet(mapUrl)
    if not mapSrc then
        print("[AutomaHub] No script module for PlaceId " .. tostring(placeId))
        return nil
    end

    local fn = loadstring or load
    if not fn then return nil end
    local module = fn(mapSrc)
    if not module then return nil end
    local ok, config = pcall(module)
    if not ok then
        warn("[AutomaHub] Map module error: " .. tostring(config))
        return nil
    end

    -- support 2 format:
    --   1) return { tabs = {...} }         (langsung config table)
    --   2) return function(AutomaHub, services) ... end  (API mode)
    if type(config) == "table" and type(config.tabs) == "table" then
        return config
    elseif type(config) == "function" then
        return config
    end

    warn("[AutomaHub] Map module has no .tabs or function: " .. tostring(placeId))
    return nil
end

-- ============================================================
-- dipanggil pas key VALID (hook dari KeySystemAutomaHub.lua onValid)
-- ============================================================
local function onGranted(key)
    local mapConfig = loadMapConfig()

    if getgenv then
        if type(mapConfig) == "table" then
            getgenv().AutomaHubConfig = mapConfig
            getgenv().AutomaHubMapFn = nil
        elseif type(mapConfig) == "function" then
            getgenv().AutomaHubConfig = nil
            getgenv().AutomaHubMapFn = mapConfig
        else
            getgenv().AutomaHubConfig = nil
            getgenv().AutomaHubMapFn = nil
        end
    end

    local Loader = runSource(httpGet(LOAD_URL))
    local L
    if type(Loader) == "table" and type(Loader.new) == "function" then
        local ok, inst = pcall(Loader.new)
        if ok then L = inst end
    end
    if L then L:setStatus("Connecting to AutomaHub...") end

    if L then L:setProgress(0.15) end
    local menuSrc = httpGet(MENU_URL)
    if L then L:setStatus("Loading interface..."); L:setProgress(0.4) end
    local animSrc = httpGet(ANIM_URL)
    if L then L:setProgress(0.6) end

    if menuSrc then
        if getgenv then getgenv().AutomaHubStartHidden = true end
        runSource(menuSrc)
        -- kalo mapConfig adalah function (API mode), panggil sekarang
        if getgenv and type(getgenv().AutomaHubMapFn) == "function" then
            local api = getgenv().AutomaHub
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
                pcall(getgenv().AutomaHubMapFn, api, services)
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

if getgenv then getgenv().AutomaHubOnGranted = onGranted end

local keySrc = httpGet(KEY_URL)
if keySrc then
    runSource(keySrc)
else
    warn("[AutomaHub] gagal load Key UI dari " .. KEY_URL)
end
