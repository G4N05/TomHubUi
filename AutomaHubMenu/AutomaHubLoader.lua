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
--   4) menu_ui.lua tampil
--
-- Catatan: file ini UI-layer doang, ga nyentuh logic key/obfus/backend.
-- ============================================================

-- ====== CONFIG REPO ======
local REPO     = "https://raw.githubusercontent.com/G4N05/TomHubUi/main/"
local KEY_URL  = REPO .. "AutomaKeyUi/KeySystemAutomaHub.lua"
local LOAD_URL = REPO .. "AutomaHubMenu/Load.lua"
local ANIM_URL = REPO .. "AutomaHubMenu/Animate.lua"
local MENU_URL = REPO .. "AutomaHubMenu/menu_ui.lua"
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
-- dipanggil pas key VALID (hook dari KeySystemAutomaHub.lua onValid)
-- ============================================================
local function onGranted(key)
    -- [1] loading screen (Load.lua return Loader table)
    local Loader = runSource(httpGet(LOAD_URL))
    local L
    if type(Loader) == "table" and type(Loader.new) == "function" then
        local ok, inst = pcall(Loader.new)
        if ok then L = inst end
    end
    if L then L:setStatus("Connecting to AutomaHub...") end

    -- [2] prefetch resource sambil progress jalan
    if L then L:setProgress(0.2) end
    local menuSrc = httpGet(MENU_URL)
    if L then L:setProgress(0.55) end
    local animSrc = httpGet(ANIM_URL)
    if L then L:setProgress(0.85) end

    -- simpen menu source -> Animate.lua bakal pakai ini (ga fetch ulang)
    if getgenv and menuSrc then getgenv().AutomaHubMenuSource = menuSrc end

    local function startIntro()
        -- Animate.lua urus: logo intro + blur + load & reveal menu
        if animSrc then
            runSource(animSrc)
        else
            runSource(httpGet(ANIM_URL))
        end
    end

    -- [3] kelarin loading -> jalanin intro
    if L then
        L:setStatus("Starting interface...")
        L:setProgress(1)
        L:finish(function()
            startIntro()
        end)
    else
        -- Load.lua gagal dimuat -> langsung intro aja
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
