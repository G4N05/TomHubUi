-- ============================================================
-- TomHub | LOADER (ENTRY PUBLIK)
-- ------------------------------------------------------------
-- Ini yang user jalanin:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/G4N05/Violence-District/main/TomHub/loader.lua"))()
--
-- Alur: load UICore -> bikin window -> deteksi game (PlaceId) ->
--       load script game yg sesuai (obfus dari dist/).
-- File ini AMAN publik (ga ada logic rahasia).
-- ============================================================

-- ====== CONFIG REPO ======
local GITHUB_USER     = "G4N05"
local GITHUB_REPO     = "TomHubUi"
local GITHUB_BRANCH   = "main"
local GITHUB_BASEPATH = "TomHub"          -- subfolder repo. Kosongin "" kalo di root
-- =========================

local function fullPath(path)
    if GITHUB_BASEPATH ~= "" then return GITHUB_BASEPATH .. "/" .. path end
    return path
end

local function urlsFor(path)
    local p = fullPath(path)
    return {
        string.format("https://raw.githubusercontent.com/%s/%s/%s/%s", GITHUB_USER, GITHUB_REPO, GITHUB_BRANCH, p),
        string.format("https://cdn.jsdelivr.net/gh/%s/%s@%s/%s", GITHUB_USER, GITHUB_REPO, GITHUB_BRANCH, p),
        string.format("https://raw.gitmirror.com/%s/%s/%s/%s", GITHUB_USER, GITHUB_REPO, GITHUB_BRANCH, p),
    }
end

local function multiFetch(urls)
    for _, url in ipairs(urls) do
        local ok, content = pcall(function() return game:HttpGet(url) end)
        if ok and content and #content > 50 then return content end
    end
    return nil
end

-- fetch file dari repo -> loadstring -> jalanin -> return value
local function fetchRun(path)
    local content = multiFetch(urlsFor(path))
    if not content then
        warn("[TomHub] Gagal fetch: " .. path)
        return nil
    end
    local fn, err = loadstring(content)
    if not fn then
        warn("[TomHub] Syntax error " .. path .. ": " .. tostring(err))
        return nil
    end
    local ok, ret = pcall(fn)
    if not ok then
        warn("[TomHub] Run error " .. path .. ": " .. tostring(ret))
        return nil
    end
    return ret
end

-- ============================================================
-- [1] UICore -> bikin window (shell)
-- ============================================================
local UICore = fetchRun("core/UICore.lua")
if type(UICore) ~= "function" then
    error("[TomHub] UICore gagal dimuat.")
end
local base = UICore({ title = "TomHub" })
base.fetchRun = fetchRun   -- dipake game buat dev-fetch module (mode source)
base.urlsFor = urlsFor

-- ============================================================
-- [2] GAME REGISTRY: PlaceId -> path script game (di dist/)
-- ------------------------------------------------------------
-- Tambah game baru cukup tambah 1 baris di sini.
-- Cara dapet PlaceId: print(game.PlaceId) pas di game itu.
-- ============================================================
local GAMES = {
    -- [PLACEID_VIOLENCE_DISTRICT] = "dist/violence_district.lua",
    -- contoh: [1234567890] = "dist/violence_district.lua",
}

-- Sementara PLACEID belum diisi, pake DEFAULT_GAME biar tetep jalan.
-- Kalo udah punya banyak game, isi GAMES di atas & set DEFAULT_GAME = nil.
local DEFAULT_GAME = "dist/violence_district.lua"

-- ============================================================
-- [3] Deteksi game & load
-- ============================================================
local placeId = game.PlaceId
local gamePath = GAMES[placeId] or DEFAULT_GAME

if not gamePath then
    base.WindUI:Notify({
        Title = "TomHub",
        Content = "Game ini belum disupport (PlaceId: " .. tostring(placeId) .. ")",
        Duration = 8,
    })
    return
end

local gameInit = fetchRun(gamePath)
if type(gameInit) == "function" then
    local ok, err = pcall(gameInit, base)
    if not ok then warn("[TomHub] Game init error: " .. tostring(err)) end
else
    base.WindUI:Notify({
        Title = "TomHub",
        Content = "Gagal load script game (" .. gamePath .. ")",
        Duration = 8,
    })
end
