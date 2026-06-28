# TomHub (Multi-Game Script Hub)

Launcher multi-game: 1 loader, deteksi otomatis lagi main game apa, terus load
script game yang sesuai. **UI dipisah dari logic**, dan logic per-game di-obfuscate.

## Struktur

```
TomHub/
├─ loader.lua                 # ENTRY publik. User loadstring ini.
├─ core/
│  └─ UICore.lua              # UI SHELL (window, WindUI, services) - shared, PUBLIK
├─ games/                     # SOURCE dev (pecah-pecah, buat ngedit) - JANGAN push publik
│  └─ ViolenceDistrict/
│     ├─ init.lua             # logic VD: tab, ctx, killer tracking, load modules
│     ├─ Combat/ Aim/ Visual/ # feature modules (return function(ctx))
│     └─ Player/
├─ dist/                      # OUTPUT build (di-obfus -> di-push)
│  └─ violence_district.lua   # bundle VD (hasil build_game.py)
└─ build_game.py              # gabung init + modules -> dist/violence_district.lua
```

## Alur runtime

```
user loadstring(loader.lua)
   │
   ├─ fetch core/UICore.lua  -> bikin window TomHub (shell)
   ├─ deteksi game.PlaceId
   │     ├─ cocok di GAMES{}  -> load dist/<game>.lua
   │     └─ ga cocok          -> notify "belum disupport"
   └─ script game (obfus) = return function(base) -> bikin tab+toggle + logic
```

## Pemisahan UI vs Logic

| Bagian | File | Status push |
|---|---|---|
| UI shell (window, theme, services) | `core/UICore.lua` | PUBLIK (ga rahasia) |
| Entry + deteksi game | `loader.lua` | PUBLIK |
| Logic + UI khusus game | `dist/violence_district.lua` | **OBFUS** (rahasia) |
| Source dev | `games/ViolenceDistrict/...` | JANGAN push publik (mentah) |

## Workflow

### Edit / benerin bug
Selalu di **file pecahan** `games/ViolenceDistrict/...` (gampang, rapih).

### Tambah fitur baru
1 fitur = 1 file di folder yg pas (`return function(ctx)`), lengkap: UI + toggle +
logic + cleanup. Tes standalone dulu, baru daftarin di `init.lua` (`runModule`).

### Rilis
```bash
python3 build_game.py            # -> dist/violence_district.lua
```
Lalu obfuscate `dist/violence_district.lua` (Prometheus Playground, Lua Version = LuaU),
tes di executor, push ke GitHub.

### Tambah game baru
1. Bikin folder `games/<NamaGame>/` (init.lua + modules).
2. Bikin build buat game itu -> `dist/<nama_game>.lua`.
3. Daftarin PlaceId di `loader.lua` -> `GAMES[<placeId>] = "dist/<nama_game>.lua"`.

## Setup loader (penting)

Di `loader.lua`:
- Set `GITHUB_USER / REPO / BRANCH / BASEPATH`.
- Isi `GAMES = { [PlaceId] = "dist/violence_district.lua" }` (cara dapet PlaceId:
  `print(game.PlaceId)` pas di game-nya).
- Sementara `DEFAULT_GAME` masih nge-load VD biar tetep jalan walau PlaceId belum diisi.
  Kalo udah multi-game, isi `GAMES` & set `DEFAULT_GAME = nil`.

## One-liner

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/G4N05/Violence-District/main/TomHub/loader.lua"))()
```
