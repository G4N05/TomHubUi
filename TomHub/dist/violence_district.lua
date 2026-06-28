-- ============================================================
-- TomHub | Violence District (GAME LOGIC)
-- ------------------------------------------------------------
-- Format: return function(base)  <- `base` dari UICore.
-- Tugas: bikin tab+toggle khusus VD, setup core refs (killer
-- tracking, remotes, anim, namecall hook), bangun ctx, load
-- semua feature module, start hooks.
--
-- File INI yang nanti di-build jadi bundle + di-obfuscate ->
-- dist/violence_district.lua
-- ============================================================
return function(base)
    -- ambil dari base (UICore)
    local WindUI = base.WindUI
    local Window = base.Window
    local Players = base.Players
    local ReplicatedStorage = base.ReplicatedStorage
    local CollectionService = base.CollectionService
    local RunService = base.RunService
    local UserInputService = base.UserInputService
    local Teams = base.Teams
    local VirtualInputManager = base.VirtualInputManager
    local Workspace = base.Workspace
    local LocalPlayer = base.LocalPlayer

    -- ============================================================
    -- [TABS khusus VD]
    -- ============================================================
    local CombatTab = Window:Tab({ Title = "Survivor", Icon = "shield" })
    local PlayerTab = Window:Tab({ Title = "Player", Icon = "user" })
    local VisualTab = Window:Tab({ Title = "Visual", Icon = "eye" })
    local AimTab    = Window:Tab({ Title = "Aim", Icon = "crosshair" })

    -- daftarin pengecek in-match ke UICore (buat mouse-lock pas UI ditutup)
    local function isInMatch()
        local team = LocalPlayer.Team
        return team ~= nil and (team.Name == "Killer" or team.Name == "Survivors")
    end
    base.setMatchChecker(isInMatch)

    -- ============================================================
    -- [CORE REFS: character, remotes, killer tracking]
    -- ============================================================
    local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local Humanoid = Character:WaitForChild("Humanoid")
    local RootPart = Character:WaitForChild("HumanoidRootPart")

    local Remotes = ReplicatedStorage:WaitForChild("Remotes")
    local daggerFolder = Remotes:WaitForChild("Items"):WaitForChild("Parrying Dagger")
    local parryResult = daggerFolder:WaitForChild("parryResult")
    local DamagevizEvent = Remotes:WaitForChild("Killers"):WaitForChild("Damageviz")
    local SlowAttack = Remotes:WaitForChild("Killers"):FindFirstChild("SlowAttack")
    local KillerTeam = Teams:FindFirstChild("Killer")

    local killerDistance = 999
    local killerRoot = nil
    local killerFilterCache = { Character }

    -- rebind refs pas respawn
    LocalPlayer.CharacterAdded:Connect(function(newChar)
        Character = newChar
        Humanoid = newChar:WaitForChild("Humanoid")
        RootPart = newChar:WaitForChild("HumanoidRootPart")
    end)

    -- killer terdekat + filter cache buat raycast (single heartbeat)
    RunService.Heartbeat:Connect(function()
        if not RootPart or not RootPart.Parent then return end
        local nearest = 9999
        local nearestRoot = nil
        table.clear(killerFilterCache)
        table.insert(killerFilterCache, Character)
        if KillerTeam then
            for _, plr in ipairs(KillerTeam:GetPlayers()) do
                local kChar = plr.Character
                if kChar then
                    table.insert(killerFilterCache, kChar)
                    local kRoot = kChar:FindFirstChild("HumanoidRootPart")
                    if kRoot then
                        local d = (RootPart.Position - kRoot.Position).Magnitude
                        if d < nearest then nearest = d; nearestRoot = kRoot end
                    end
                end
            end
        end
        killerDistance = nearest
        killerRoot = nearestRoot
    end)

    -- Wallcheck dipake parry & dodge
    local function hasLineOfSight()
        if not RootPart or not RootPart.Parent or not killerRoot then return false end
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.IgnoreWater = true
        rayParams.FilterDescendantsInstances = killerFilterCache
        local result = Workspace:Raycast(RootPart.Position, killerRoot.Position - RootPart.Position, rayParams)
        if result then return false end
        return true
    end

    -- ============================================================
    -- [DISPATCHER ANIMASI KILLER] hook sekali, broadcast ke modul
    -- ============================================================
    local animHandlers = {}
    local killerAnimConnections = {}
    local function fireAnim(plr, idRaw, animId)
        for _, h in ipairs(animHandlers) do
            pcall(h, plr, idRaw, animId)
        end
    end
    local function hookKillerAnimators()
        for _, c in ipairs(killerAnimConnections) do c:Disconnect() end
        table.clear(killerAnimConnections)
        if KillerTeam then
            for _, plr in ipairs(KillerTeam:GetPlayers()) do
                local function hook(char)
                    local hum = char:WaitForChild("Humanoid", 5)
                    if hum then
                        local animator = hum:WaitForChild("Animator", 5)
                        if animator then
                            table.insert(killerAnimConnections, animator.AnimationPlayed:Connect(function(anim)
                                local id = anim.Animation and anim.Animation.AnimationId
                                local animId = id and tostring(id):match("%d+") or ""
                                fireAnim(plr, id, animId)
                            end))
                        end
                    end
                end
                if plr.Character then task.spawn(hook, plr.Character) end
                table.insert(killerAnimConnections, plr.CharacterAdded:Connect(hook))
            end
        end
    end

    -- ============================================================
    -- [HOOK __namecall TUNGGAL] buat Silent Aim (gun & veil)
    -- ============================================================
    local silentSupported = (getrawmetatable ~= nil) and (getnamecallmethod ~= nil) and (newcclosure ~= nil)
    local namecallHandlers = {}
    local rawCall = nil
    local function installNamecallHook()
        if not silentSupported then return end
        local mt = getrawmetatable(game)
        if setreadonly then pcall(setreadonly, mt, false) end
        if getgenv and getgenv().__tomaAimOrig then
            pcall(function() mt.__namecall = getgenv().__tomaAimOrig end)
        end
        local oldNamecall = mt.__namecall
        if getgenv then getgenv().__tomaAimOrig = oldNamecall end
        rawCall = function(self, ...) return oldNamecall(self, ...) end
        local hookFn = function(self, ...)
            if typeof(self) == "Instance" then
                local method = getnamecallmethod()
                for _, h in ipairs(namecallHandlers) do
                    local ok, res = h(self, method, ...)
                    if ok then return res end
                end
            end
            return oldNamecall(self, ...)
        end
        mt.__namecall = newcclosure and newcclosure(hookFn) or hookFn
    end

    -- ============================================================
    -- [CONTEXT] dibagi ke semua feature module
    -- ============================================================
    local ctx = {
        WindUI = WindUI,
        Window = Window,
        tabs = { Combat = CombatTab, Player = PlayerTab, Visual = VisualTab, Aim = AimTab },

        Players = Players,
        ReplicatedStorage = ReplicatedStorage,
        CollectionService = CollectionService,
        RunService = RunService,
        UserInputService = UserInputService,
        Teams = Teams,
        VirtualInputManager = VirtualInputManager,
        Workspace = Workspace,
        LocalPlayer = LocalPlayer,

        Remotes = Remotes,
        parryResult = parryResult,
        DamagevizEvent = DamagevizEvent,
        SlowAttack = SlowAttack,
        KillerTeam = KillerTeam,

        getCharacter = function() return Character end,
        getHumanoid = function() return Humanoid end,
        getRootPart = function() return RootPart end,
        getKillerRoot = function() return killerRoot end,
        getKillerDistance = function() return killerDistance end,
        hasLineOfSight = hasLineOfSight,

        silentSupported = silentSupported,
        onKillerAnim = function(fn) table.insert(animHandlers, fn) end,
        onNamecall = function(fn) table.insert(namecallHandlers, fn) end,
        callOriginal = function(self, ...) return rawCall(self, ...) end,
    }

    -- ============================================================
    -- [LOAD MODULES]
    -- DEV: fetch tiap module dari GitHub (butuh source ke-push).
    -- BUILD: blok di bawah diganti otomatis -> ambil dari embed.
    -- ============================================================
    -- [BUNDLED MODULES] di-inline (ga fetch GitHub)
    local __VD_MODULES = {}
    __VD_MODULES["Combat/AutoParry.lua"] = (function()
-- ============================================================
-- Combat/AutoParry.lua | Auto Parry (serangan biasa killer)
-- Owner state parry (dipake juga Dash Parry via ctx.parry).
-- ============================================================
return function(ctx)
    local CollectionService = ctx.CollectionService
    local UserInputService = ctx.UserInputService
    local VirtualInputManager = ctx.VirtualInputManager
    local RunService = ctx.RunService
    local LocalPlayer = ctx.LocalPlayer
    local parryResult = ctx.parryResult
    local DamagevizEvent = ctx.DamagevizEvent
    local SlowAttack = ctx.SlowAttack

    -- state parry
    local isOnCooldown = false
    local isResolving = false
    local isSilenced = false
    local isAutoParrying = false
    local autoParryEnabled = false
    local parryDistance = 9

    -- ID animasi serangan killer yg di-PARRY (verifikasi anim_logger, priority Action2).
    -- HANYA ID ini yang nge-trigger parry. 84093948968516 (Veil ancang2 lempar) SENGAJA ga dimasukin.
    local ATTACK_ANIM_IDS = {
        ["117042998468241"] = true, -- Myers
        ["129784271201071"] = true, -- Jeff (lunge)
        ["113255068724446"] = true, -- Hidden
        ["118907603246885"] = true, -- Abysswalker
        ["122812055447896"] = true, -- Veil
        ["110355011987939"] = true, -- Slasher
        ["135002183282873"] = true, -- Cure
        ["105374834496520"] = true, -- Mask Richter
        ["138720291317243"] = true, -- Mask Tony
        ["115244153053858"] = true, -- Mask Cobra
        ["106871536134254"] = true, -- Mask Alex
    }
    local lastPrePress = 0
    local rearmCooldown = 0.08      -- jeda antar klik auto-parry (biar ga spam tiap frame)
    local postParryCooldown = 0.25  -- cooldown lokal setelah parry sukses
    local lastAutoPress = 0
    local facingDotThreshold = 0.1

    local function canParry()
        if isOnCooldown or isSilenced or LocalPlayer:GetAttribute("IsDead") then return false end
        local Character = ctx.getCharacter()
        local RootPart = ctx.getRootPart()
        if not Character or not Character.Parent or Character:GetAttribute("IsCarried") or Character:GetAttribute("IsHooked") then return false end
        if CollectionService:HasTag(RootPart, "doing action") then return false end
        return true
    end

    -- Safety: kalau tag 'doing action' nyangkut tapi ga lagi repairing -> buang.
    local function cleanupStaleActionTag()
        local RootPart = ctx.getRootPart()
        if not RootPart or not RootPart.Parent then return end
        if CollectionService:HasTag(RootPart, "doing action") then
            local char = LocalPlayer.Character
            if char then
                local checkInt = char:FindFirstChild("CheckInterractable")
                if not checkInt or not checkInt:GetAttribute("isRepairing") then
                    CollectionService:RemoveTag(RootPart, "doing action")
                    if RootPart.Anchored then
                        RootPart.Anchored = false
                    end
                    isResolving = false
                    isOnCooldown = false
                end
            end
        end
    end

    -- [FACING FILTER] parry CUMA kalau killer ngehadap kita.
    local function isKillerFacing()
        local killerRoot = ctx.getKillerRoot()
        local RootPart = ctx.getRootPart()
        if not killerRoot or not killerRoot.Parent or not RootPart or not RootPart.Parent then return true end
        local dot = killerRoot.CFrame.LookVector:Dot((RootPart.Position - killerRoot.Position).Unit)
        return dot >= facingDotThreshold
    end

    -- Mekanik tekan parry (klik kanan)
    local function doParryPress()
        isAutoParrying = true
        lastAutoPress = os.clock()
        lastPrePress = os.clock()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 1, true, game, 1)
        task.delay(0.05, function()
            VirtualInputManager:SendMouseButtonEvent(0, 0, 1, false, game, 1)
            isAutoParrying = false
        end)
    end

    -- Inti auto-parry: cek range + rearm + LOS + facing, lalu klik parry.
    local function attemptParry(maxRange)
        if not autoParryEnabled or ctx.getKillerDistance() > maxRange or not canParry() then return end
        if (os.clock() - lastPrePress) < rearmCooldown then return end
        if not ctx.hasLineOfSight() then return end
        if not isKillerFacing() then return end
        doParryPress()
    end

    local function triggerParry()
        attemptParry(parryDistance)
    end

    -- Events
    DamagevizEvent.OnClientEvent:Connect(triggerParry)
    if SlowAttack then SlowAttack.OnClientEvent:Connect(triggerParry) end

    -- Anim killer terverifikasi -> langsung parry
    ctx.onKillerAnim(function(plr, idRaw, animId)
        if ATTACK_ANIM_IDS[animId] then
            triggerParry()
        end
    end)

    -- Sync state. cd mentah server JANGAN dipake task.delay (cd=90 -> lock 90 DETIK!).
    parryResult.OnClientEvent:Connect(function(success, cd)
        isResolving = false
        if success then
            isOnCooldown = true
            task.delay(postParryCooldown, function() isOnCooldown = false end)
        end
    end)

    UserInputService.InputBegan:Connect(function(input, gp)
        if not gp and input.UserInputType == Enum.UserInputType.MouseButton2 then
            -- Abaikan klik virtual dari auto-parry sendiri.
            if isAutoParrying or (os.clock() - lastAutoPress) < 0.2 then return end
            if canParry() then
                isResolving = true
            end
        end
    end)

    CollectionService:GetInstanceAddedSignal("Silenced"):Connect(function(i) if i == ctx.getCharacter() then isSilenced = true end end)
    CollectionService:GetInstanceRemovedSignal("Silenced"):Connect(function(i) if i == ctx.getCharacter() then isSilenced = false end end)

    LocalPlayer.CharacterAdded:Connect(function()
        isOnCooldown, isResolving, isSilenced = false, false, false
    end)

    -- Safety heartbeat: bersihin stale 'doing action' tag
    RunService.Heartbeat:Connect(function()
        local RootPart = ctx.getRootPart()
        if RootPart and CollectionService:HasTag(RootPart, "doing action") then
            cleanupStaleActionTag()
        end
    end)

    -- Export buat Dash Parry (Combat/AutoParryDashHidden.lua)
    ctx.parry = {
        isEnabled = function() return autoParryEnabled end,
        canParry = canParry,
        doParryPress = doParryPress,
    }

    -- ===================== UI =====================
    local Section = ctx.tabs.Combat:Section({
        Title = "Auto Parry",
        Desc = "Block serangan killer otomatis",
        Box = true,
        BoxBorder = true,
        Opened = true,
    })
    Section:Toggle({
        Title = "Auto Parry",
        Desc = "Automatically block killer attacks",
        Value = autoParryEnabled,
        Callback = function(state)
            autoParryEnabled = state
        end,
    })
    Section:Slider({
        Title = "Parry Distance",
        Desc = "Maximum distance to trigger Auto Parry",
        Step = 1,
        Value = { Min = 5, Max = 50, Default = 9 },
        Callback = function(value)
            if value and value >= 5 then
                parryDistance = value
            end
        end,
    })
end
    end)()

    __VD_MODULES["Combat/AutoParryDashHidden.lua"] = (function()
-- ============================================================
-- Combat/AutoParryDashHidden.lua | Dash Parry (M2 lunge killer)
-- Detect anim wind-up -> delay ~775ms -> parry pas hitbox lunge aktif.
-- Depend ke Combat/AutoParry.lua (ctx.parry) -> WAJIB di-load duluan.
-- ============================================================
return function(ctx)
    if not ctx.parry then
        warn("[TomaHub] Dash Parry butuh AutoParry di-load duluan.")
        return
    end

    local DASH_WINDUP_ID = "98163597193511" -- anim wind-up dash killer (acuan timing)
    local dashDistance = 30                 -- jarak deteksi dash killer
    local dashParryDelay = 0.775            -- sweet spot 0.75-0.80
    local dashFacingAngleDeg = 10           -- killer harus ngehadap kita, meleset maks segini
    local dashFacingDotMin = math.cos(math.rad(dashFacingAngleDeg))
    local dashRecheckFacing = true          -- cek ulang facing pas mau pencet
    local dashRetriggerGuard = 1.4          -- jeda min antar-jadwal dash parry (detik)
    local dashPending = false
    local lastDashSchedule = -999

    local function dashFacingInfo(kr)
        local RootPart = ctx.getRootPart()
        if not kr or not kr.Parent or not RootPart or not RootPart.Parent then return 999, false end
        local toPlayer = RootPart.Position - kr.Position
        local dist = toPlayer.Magnitude
        if dist < 0.01 then return dist, true end
        local dot = math.clamp(kr.CFrame.LookVector:Dot(toPlayer.Unit), -1, 1)
        return dist, (dot >= dashFacingDotMin)
    end

    -- Abis delay: re-check jarak + facing + LOS, baru pencet parry.
    local function fireDashParry(getKr)
        dashPending = false
        if not ctx.parry.isEnabled() then return end
        local kr = getKr()
        local dist, facingOk = dashFacingInfo(kr)
        if dist > dashDistance then return end
        if dashRecheckFacing and not facingOk then return end
        if not ctx.parry.canParry() then return end
        if not ctx.hasLineOfSight() then return end
        ctx.parry.doParryPress()
    end

    -- Detect wind-up -> jadwalin dash parry (delay dashParryDelay).
    local function scheduleDashParry(plr, kr)
        if not ctx.parry.isEnabled() or dashPending or (os.clock() - lastDashSchedule) < dashRetriggerGuard then return end
        local dist, facingOk = dashFacingInfo(kr)
        if dist > dashDistance or not facingOk then return end
        dashPending = true
        lastDashSchedule = os.clock()
        task.delay(dashParryDelay, function()
            fireDashParry(function()
                return plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            end)
        end)
    end

    ctx.onKillerAnim(function(plr, idRaw, animId)
        if idRaw and tostring(idRaw):find(DASH_WINDUP_ID) then
            scheduleDashParry(plr, plr.Character and plr.Character:FindFirstChild("HumanoidRootPart"))
        end
    end)

    -- ===================== UI =====================
    local Section = ctx.tabs.Combat:Section({
        Title = "Dash Parry",
        Desc = "Auto parry dash (M2) killer",
        Box = true,
        BoxBorder = true,
        Opened = true,
    })
    Section:Slider({
        Title = "Dash Parry Distance",
        Desc = "Jarak deteksi dash (M2) killer",
        Step = 1,
        Value = { Min = 5, Max = 60, Default = 30 },
        Callback = function(value)
            if value and value >= 5 then
                dashDistance = value
            end
        end,
    })
end
    end)()

    __VD_MODULES["Combat/AutoDogdeAbbys.lua"] = (function()
-- ============================================================
-- Combat/AutoDogdeAbbys.lua | Auto Dodge Abysswalker
-- Jongkok (Ctrl) otomatis pas Abysswalker pake skill.
-- Wallcheck + persistent window biar skill dari balik tembok tetep kedeteksi.
-- ============================================================
return function(ctx)
    local VirtualInputManager = ctx.VirtualInputManager

    local autoDodgeEnabled = false
    local dodgeDistance = 25         -- jarak deteksi skill Abysswalker
    local crouchHoldTime = 1.0       -- lama tahan jongkok (Ctrl)
    local dodgeTriggerDelay = 0.1    -- delay sebelum jongkok
    local dodgeSkillWindow = 2.0     -- lama skill dianggap aktif
    local dodgeCheckInterval = 0.1   -- interval re-check wallcheck
    local ABYSS_SKILL_ID = "80411309607666" -- anim skill Abysswalker
    local isDodging = false
    local dodgeSkillPending = false

    local function doCrouch()
        if isDodging then return end
        isDodging = true
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftControl, false, game)
        task.delay(crouchHoldTime, function()
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, game)
            isDodging = false
        end)
    end

    local function triggerDodge()
        if not autoDodgeEnabled or isDodging then return end
        if ctx.getKillerDistance() <= dodgeDistance and ctx.hasLineOfSight() then
            task.delay(dodgeTriggerDelay, function()
                if not isDodging and not dodgeSkillPending and ctx.getKillerDistance() <= dodgeDistance and ctx.hasLineOfSight() then
                    doCrouch()
                end
            end)
            return
        end
        if dodgeSkillPending then return end
        dodgeSkillPending = true
        task.spawn(function()
            local elapsed = 0
            while elapsed < dodgeSkillWindow do
                task.wait(dodgeCheckInterval)
                elapsed = elapsed + dodgeCheckInterval
                if not autoDodgeEnabled or isDodging then break end
                if ctx.getKillerDistance() <= dodgeDistance and ctx.hasLineOfSight() then
                    task.delay(dodgeTriggerDelay, function()
                        if not isDodging and not dodgeSkillPending and ctx.getKillerDistance() <= dodgeDistance and ctx.hasLineOfSight() then
                            doCrouch()
                        end
                    end)
                    break
                end
            end
            dodgeSkillPending = false
        end)
    end

    ctx.onKillerAnim(function(plr, idRaw, animId)
        if idRaw and tostring(idRaw):find(ABYSS_SKILL_ID) then
            triggerDodge()
        end
    end)

    -- ===================== UI =====================
    local Section = ctx.tabs.Combat:Section({
        Title = "Auto Dodge",
        Desc = "Auto jongkok lawan Abysswalker",
        Box = true,
        BoxBorder = true,
        Opened = true,
    })
    Section:Toggle({
        Title = "Auto Dodge Abysswalker",
        Desc = "Auto jongkok pas Abysswalker pake skill",
        Value = autoDodgeEnabled,
        Callback = function(state)
            autoDodgeEnabled = state
        end,
    })
    Section:Slider({
        Title = "Dodge Distance",
        Desc = "Jarak deteksi skill Abysswalker",
        Step = 1,
        Value = { Min = 5, Max = 60, Default = 25 },
        Callback = function(value)
            if value and value >= 5 then
                dodgeDistance = value
            end
        end,
    })
end
    end)()

    __VD_MODULES["Combat/SkillCheck.lua"] = (function()
-- ============================================================
-- Combat/SkillCheck.lua | Auto Perfect Skillcheck
-- Monitor Check.Visible; pencet Space pas diff (Line-Goal)%360 masuk zona sukses.
-- Zona: Great [102,116], Good (116,159]. Game client routing remote sendiri.
-- ============================================================
return function(ctx)
    local RunService = ctx.RunService
    local VirtualInputManager = ctx.VirtualInputManager
    local LocalPlayer = ctx.LocalPlayer

    local autoSkillCheckEnabled = false
    local scFireLow = 104    -- jangan < 102 (early fail/meledak)
    local scFireHigh = 150   -- batas atas aman (sebelum 159 = kelewat)
    local scRetrySec = 0.35  -- retry kalo press gagal & Goal ga ganti
    local scPressed = false
    local scLastGoal = nil
    local scPressedAt = 0

    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    -- Ref di-RESOLVE ULANG (GUI di-recreate tiap ganti match).
    local SkillCheckFrame, SkillCheckLine, SkillCheckGoal = nil, nil, nil
    local function resolveSkillCheckRefs()
        local gui = PlayerGui:FindFirstChild("SkillCheckPromptGui")
        local check = gui and gui:FindFirstChild("Check")
        if not check then
            SkillCheckFrame, SkillCheckLine, SkillCheckGoal = nil, nil, nil
            return false
        end
        SkillCheckFrame = check
        SkillCheckLine = check:FindFirstChild("Line")
        SkillCheckGoal = check:FindFirstChild("Goal")
        return (SkillCheckLine ~= nil and SkillCheckGoal ~= nil)
    end
    resolveSkillCheckRefs()

    RunService.Heartbeat:Connect(function()
        if not autoSkillCheckEnabled then return end
        if not SkillCheckFrame or not SkillCheckFrame.Parent or not SkillCheckLine or not SkillCheckGoal then
            resolveSkillCheckRefs()
        end
        if SkillCheckFrame and SkillCheckFrame.Parent and SkillCheckFrame.Visible then
            local goal = SkillCheckGoal.Rotation % 360
            local line = SkillCheckLine.Rotation % 360
            local diff = (line - goal) % 360
            if scLastGoal == nil or math.abs(goal - scLastGoal) > 0.5 then
                scLastGoal = goal
                scPressed = false
            end
            if scPressed and (os.clock() - scPressedAt) > scRetrySec then
                scPressed = false
            end
            if not scPressed and diff >= scFireLow and diff <= scFireHigh then
                scPressed = true
                scPressedAt = os.clock()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                task.delay(0.04, function()
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                end)
            end
        else
            scPressed = false
            scLastGoal = nil
        end
    end)

    -- ===================== UI =====================
    local Section = ctx.tabs.Combat:Section({
        Title = "Auto Skillcheck",
        Desc = "Auto skillcheck (generator & healing)",
        Box = true,
        BoxBorder = true,
        Opened = true,
    })
    Section:Toggle({
        Title = "Auto Skillcheck",
        Desc = "Auto success skillcheck (generator & healing)",
        Value = autoSkillCheckEnabled,
        Callback = function(state)
            autoSkillCheckEnabled = state
        end,
    })
end
    end)()

    __VD_MODULES["Visual/Esp.lua"] = (function()
-- ============================================================
-- Visual/Esp.lua | ESP (highlight + nametag + jarak)
-- ============================================================
return function(ctx)
    local Players = ctx.Players
    local LocalPlayer = ctx.LocalPlayer

    local espEnabled = false
    local activeConnections = {}
    local activeHighlights = {}

    local function getPlayerColor(player)
        if player.Team and (player.Team.Name:lower():find("killer") or player.Team.Name:lower():find("hunter")) then
            return Color3.fromRGB(255, 0, 0)
        elseif player:GetAttribute("Role") == "Killer" or player:GetAttribute("Killer") then
            return Color3.fromRGB(255, 0, 0)
        end
        return Color3.fromRGB(0, 255, 0)
    end

    local function cleanupModel(model)
        pcall(function()
            if activeHighlights[model] then
                for _, obj in ipairs(activeHighlights[model]) do
                    obj:Destroy()
                end
                activeHighlights[model] = nil
            end
        end)
    end

    local function cleanupPlayer(player)
        pcall(function()
            if activeConnections[player] then
                for _, conn in ipairs(activeConnections[player]) do
                    conn:Disconnect()
                end
                activeConnections[player] = nil
            end
            if player.Character then cleanupModel(player.Character) end
        end)
    end

    local function updateESPColor(player, hl, nameLabel)
        pcall(function()
            local color = getPlayerColor(player)
            if hl and hl.Parent then
                hl.FillColor = color
                hl.OutlineColor = color
            end
            if nameLabel and nameLabel.Parent then
                nameLabel.TextColor3 = color
            end
        end)
    end

    local function applyESP(model, defaultColor, nameText)
        cleanupModel(model)
        if not espEnabled then return end

        local hl = Instance.new("Highlight")
        hl.FillColor = defaultColor
        hl.OutlineColor = defaultColor
        hl.FillTransparency = 0.6
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = model

        local created = {hl}

        local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")
        if root then
            local bill = Instance.new("BillboardGui")
            bill.Size = UDim2.new(0, 200, 0, 45)
            bill.StudsOffset = Vector3.new(0, 2.5, 0)
            bill.AlwaysOnTop = true
            bill.LightInfluence = 0
            bill.MaxDistance = 2000
            bill.Name = "ESP_NameTag"
            bill.Adornee = root
            bill.Parent = root
            table.insert(created, bill)

            local container = Instance.new("Frame")
            container.Size = UDim2.new(1, 0, 1, 0)
            container.BackgroundTransparency = 1
            container.Parent = bill

            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(1, 0, 0.6, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.TextSize = 14
            nameLabel.Font = Enum.Font.SourceSansBold
            nameLabel.TextColor3 = defaultColor
            nameLabel.Text = nameText
            nameLabel.TextStrokeTransparency = 0
            nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
            nameLabel.Parent = container

            local distLabel = Instance.new("TextLabel")
            distLabel.Size = UDim2.new(1, 0, 0.4, 0)
            distLabel.Position = UDim2.new(0, 0, 0.6, 0)
            distLabel.BackgroundTransparency = 1
            distLabel.TextSize = 11
            distLabel.Font = Enum.Font.SourceSans
            distLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            distLabel.Text = ""
            distLabel.TextStrokeTransparency = 0
            distLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
            distLabel.Parent = container

            local player = Players:GetPlayerFromCharacter(model)
            if player then
                updateESPColor(player, hl, nameLabel)
            end

            task.spawn(function()
                while bill and bill.Parent and espEnabled do
                    pcall(function()
                        local charRoot = model:FindFirstChild("HumanoidRootPart")
                        local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        if charRoot and localRoot then
                            distLabel.Text = "[" .. tostring(math.floor((charRoot.Position - localRoot.Position).Magnitude)) .. "m]"
                        else
                            distLabel.Text = ""
                        end
                    end)
                    task.wait(0.3)
                end
            end)
        end

        activeHighlights[model] = created
    end

    local function setupPlayer(player)
        if player == LocalPlayer then return end
        cleanupPlayer(player)
        activeConnections[player] = {}

        local function onCharacter(char)
            task.wait(0.5)
            pcall(function()
                if not espEnabled then return end
                applyESP(char, getPlayerColor(player), player.Name)
                local hl = char:FindFirstChildOfClass("Highlight")
                local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
                local bill = root and root:FindFirstChild("ESP_NameTag")
                local nameLabel = bill and bill:FindFirstChildOfClass("Frame") and bill:FindFirstChildOfClass("Frame"):FindFirstChildOfClass("TextLabel")
                if hl and nameLabel then
                    table.insert(activeConnections[player], player:GetPropertyChangedSignal("Team"):Connect(function()
                        updateESPColor(player, hl, nameLabel)
                    end))
                end
            end)
        end

        if player.Character then task.spawn(onCharacter, player.Character) end
        table.insert(activeConnections[player], player.CharacterAdded:Connect(onCharacter))
    end

    local function startESP()
        for _, p in ipairs(Players:GetPlayers()) do setupPlayer(p) end
    end

    local function stopESP()
        for _, p in ipairs(Players:GetPlayers()) do cleanupPlayer(p) end
        for model in pairs(activeHighlights) do cleanupModel(model) end
    end

    Players.PlayerAdded:Connect(setupPlayer)
    Players.PlayerRemoving:Connect(cleanupPlayer)

    -- ===================== UI =====================
    ctx.tabs.Visual:Toggle({
        Title = "ESP",
        Desc = "Lihat posisi pemain tembus pandang.",
        Value = false,
        Callback = function(state)
            espEnabled = state
            if state then
                startESP()
            else
                stopESP()
            end
        end,
    })
end
    end)()

    __VD_MODULES["Aim/AimTwistOfFate.lua"] = (function()
-- ============================================================
-- Aim/AimTwistOfFate.lua | Gun Aimbot (peluru 'Twist of Fate')
-- Silent Aim + Aim Lock. Physics: speed 200, no drop (gravity 0).
-- Remote: Remotes.Items[*].Fire(Tool, Direction) (di-hook via ctx.onNamecall).
-- ============================================================
return function(ctx)
    local Workspace = ctx.Workspace
    local Teams = ctx.Teams
    local UserInputService = ctx.UserInputService
    local RunService = ctx.RunService
    local Players = ctx.Players
    local LocalPlayer = ctx.LocalPlayer
    local silentSupported = ctx.silentSupported

    local aimTargetMode = "Killer"          -- "Killer" / "Survivor"
    local silentAimEnabled = false
    local aimLockEnabled = false
    local magicBullet = false               -- abaikan FOV, auto-lock target terdeket
    local aimWallcheck = true               -- cuma target yg keliatan (LOS)
    local enableLead = true                 -- prediksi gerak target
    local fovRadius = 120
    local fovFollowMouse = true
    local AIM_TARGET_PART = "HumanoidRootPart"
    local AIM_BULLET_SPEED = 200
    local AIM_MUZZLE_OFFSET = Vector3.new(-1.41, -1.10, -5.44) -- cam object-space (R,U,F)
    local AIM_LEAD_MULT = 1.0
    local AIM_SMOOTH = 0.25

    local AimCamera = Workspace.CurrentCamera
    local aimSilentDir = nil                -- arah peluru ke target (dibaca hook)
    local aimTargetVel = nil
    local aimVelSampleName, aimVelSamplePos, aimVelSampleT = nil, nil, 0
    local aimShowFov = true

    local function aimGetTeam()
        if aimTargetMode == "Survivor" then
            return Teams:FindFirstChild("Survivors")
        end
        return Teams:FindFirstChild("Killer")
    end

    local function aimGetFovCenter()
        if fovFollowMouse then
            local m = UserInputService:GetMouseLocation()
            return Vector2.new(m.X, m.Y)
        end
        local vp = AimCamera.ViewportSize
        return Vector2.new(vp.X / 2, vp.Y / 2)
    end

    local function aimGetPart(plr)
        return plr and plr.Character and plr.Character:FindFirstChild(AIM_TARGET_PART)
    end

    -- Wallcheck: LOS dari kamera ke target. Exclude semua karakter player -> cuma tembok yg block.
    local function aimHasLOS(part)
        if not part or not part.Parent then return false end
        local origin = AimCamera.CFrame.Position
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        rp.IgnoreWater = true
        local ignore = {}
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Character then table.insert(ignore, plr.Character) end
        end
        rp.FilterDescendantsInstances = ignore
        local char = part.Parent
        local points = { part.Position }
        local head = char and char:FindFirstChild("Head")
        if head then table.insert(points, head.Position) end
        table.insert(points, part.Position + Vector3.new(0, 2.5, 0))
        table.insert(points, part.Position - Vector3.new(0, 2.5, 0))
        for _, p in ipairs(points) do
            if Workspace:Raycast(origin, p - origin, rp) == nil then
                return true
            end
        end
        return false
    end

    -- target terdeket ke pusat FOV (magic bullet: abaikan radius FOV)
    local function aimGetTarget()
        local team = aimGetTeam()
        if not team then return nil end
        local center = aimGetFovCenter()
        local best, bestDist = nil, (magicBullet and math.huge or fovRadius)
        for _, plr in ipairs(team:GetPlayers()) do
            if plr ~= LocalPlayer then
                local part = aimGetPart(plr)
                if part then
                    local sp, onScreen = AimCamera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                        if d <= bestDist then
                            if (not aimWallcheck) or aimHasLOS(part) then
                                best, bestDist = plr, d
                            end
                        end
                    end
                end
            end
        end
        return best
    end

    -- arah muzzle -> target (+ lead). NO drop (gravity 0).
    local function aimComputeDir(part, targetVel)
        local muzzle = AimCamera.CFrame:PointToWorldSpace(AIM_MUZZLE_OFFSET)
        local tp = part.Position
        local aimPoint = tp
        if enableLead and targetVel then
            local tvel = targetVel * AIM_LEAD_MULT
            local tof = (tp - muzzle).Magnitude / AIM_BULLET_SPEED
            for _ = 1, 2 do
                local predicted = tp + tvel * tof
                tof = (predicted - muzzle).Magnitude / AIM_BULLET_SPEED
            end
            aimPoint = tp + tvel * tof
        end
        local dir = (aimPoint - muzzle)
        if dir.Magnitude < 0.01 then return nil end
        return dir.Unit
    end

    -- FOV circle (visual feedback)
    local aimFovCircle = nil
    if Drawing then
        aimFovCircle = Drawing.new("Circle")
        aimFovCircle.Thickness = 2
        aimFovCircle.NumSides = 64
        aimFovCircle.Radius = fovRadius
        aimFovCircle.Filled = false
        aimFovCircle.Visible = false
        aimFovCircle.Color = Color3.fromRGB(255, 255, 255)
    end

    -- LOOP: hitung target + arah
    local aimRenderConn = RunService.RenderStepped:Connect(function()
        AimCamera = Workspace.CurrentCamera
        if not (silentAimEnabled or aimLockEnabled) then
            aimSilentDir = nil
            if aimFovCircle then aimFovCircle.Visible = false end
            return
        end
        if aimFovCircle then
            aimFovCircle.Visible = aimShowFov
            aimFovCircle.Radius = fovRadius
            aimFovCircle.Position = aimGetFovCenter()
        end
        local target = aimGetTarget()
        if target then
            local part = aimGetPart(target)
            if part then
                local pos = part.Position
                local now = tick()
                if aimVelSampleName == target.Name and aimVelSamplePos then
                    local dt = now - aimVelSampleT
                    if dt >= 0.04 then
                        local instVel = (pos - aimVelSamplePos) / dt
                        aimTargetVel = aimTargetVel and aimTargetVel:Lerp(instVel, 0.5) or instVel
                        aimVelSamplePos = pos
                        aimVelSampleT = now
                    end
                else
                    aimVelSampleName = target.Name
                    aimVelSamplePos = pos
                    aimVelSampleT = now
                    aimTargetVel = Vector3.zero
                end
                local dir = aimComputeDir(part, aimTargetVel)
                aimSilentDir = (silentAimEnabled and dir) or nil
                if aimFovCircle then aimFovCircle.Color = Color3.fromRGB(255, 0, 0) end
                if aimLockEnabled and dir and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
                    local cf = AimCamera.CFrame
                    local goal = CFrame.new(cf.Position, cf.Position + dir)
                    AimCamera.CFrame = cf:Lerp(goal, AIM_SMOOTH)
                end
            else
                aimSilentDir = nil
                aimVelSampleName = nil
                if aimFovCircle then aimFovCircle.Color = Color3.fromRGB(255, 255, 255) end
            end
        else
            aimSilentDir = nil
            aimVelSampleName = nil
            if aimFovCircle then aimFovCircle.Color = Color3.fromRGB(255, 255, 255) end
        end
    end)

    -- HOOK silent aim: timpa arg Direction pas FireServer 'Fire'
    ctx.onNamecall(function(self, method, ...)
        if method == "FireServer" and silentAimEnabled and aimSilentDir and self.Name == "Fire" then
            local p = self.Parent
            if p and p.Parent and p.Parent.Name == "Items" then
                local args = { ... }
                if typeof(args[2]) == "Vector3" then
                    args[2] = aimSilentDir
                    return true, ctx.callOriginal(self, unpack(args))
                end
                for i, v in ipairs(args) do
                    if typeof(v) == "Vector3" then
                        args[i] = aimSilentDir
                        return true, ctx.callOriginal(self, unpack(args))
                    end
                end
            end
        end
        return false
    end)

    -- cleanup loop + circle lama pas re-execute
    if getgenv then
        local g = getgenv()
        if g.__tomaAimRender then pcall(function() g.__tomaAimRender:Disconnect() end) end
        g.__tomaAimRender = aimRenderConn
        if g.__tomaFov then pcall(function() g.__tomaFov:Remove() end) end
        g.__tomaFov = aimFovCircle
    end

    -- ===================== UI =====================
    local AimGunSection = ctx.tabs.Aim:Section({
        Title = "Auto Aim Gun",
        Desc = "Silent Aim & Aim Lock (peluru Twist of Fate)",
        Box = true,
        BoxBorder = true,
        Opened = true,
    })

    AimGunSection:Dropdown({
        Title = "Aim Target",
        Desc = "Killer / Survivor",
        Values = { "Killer", "Survivor" },
        Value = "Killer",
        Callback = function(option)
            if option == "Killer" or option == "Survivor" then
                aimTargetMode = option
            end
        end,
    })

    local SilentToggle = AimGunSection:Toggle({
        Title = silentSupported and "Silent Aim" or "Silent Aim (Unsupported Executor)",
        Desc = silentSupported and "Timpa arah peluru ke target (kamera ga gerak)" or "Executor lo ga support metatable hook. Pake Aim Lock aja.",
        Locked = not silentSupported,
        Value = silentAimEnabled,
        Callback = function(state)
            if not silentSupported then return end
            silentAimEnabled = state
        end,
    })
    if (not silentSupported) and SilentToggle then
        pcall(function() SilentToggle:Lock("Unsupported Executor") end)
    end

    AimGunSection:Toggle({
        Title = "Aim Lock",
        Desc = "Hold klik kanan -> kamera lock ke target",
        Value = aimLockEnabled,
        Callback = function(state)
            aimLockEnabled = state
        end,
    })

    AimGunSection:Toggle({
        Title = "Wallcheck",
        Desc = "Cuma aim target yg keliatan (ga nembus tembok)",
        Value = aimWallcheck,
        Callback = function(state)
            aimWallcheck = state
        end,
    })

    AimGunSection:Toggle({
        Title = "Lead Prediction",
        Desc = "Prediksi gerak target (penting, peluru ga instan)",
        Value = enableLead,
        Callback = function(state)
            enableLead = state
        end,
    })

    AimGunSection:Slider({
        Title = "Lead Strength",
        Desc = "Pengali offset prediksi (1.0 = fisika pas)",
        Step = 0.1,
        Value = { Min = 0, Max = 3, Default = 1 },
        Callback = function(value)
            if value then AIM_LEAD_MULT = value end
        end,
    })

    AimGunSection:Toggle({
        Title = "POV Circle",
        Desc = "Tampilin/sembunyiin lingkaran visual POV (tracking tetep jalan)",
        Value = aimShowFov,
        Callback = function(state)
            aimShowFov = state
        end,
    })

    AimGunSection:Slider({
        Title = "FOV Radius",
        Desc = "Radius lingkaran FOV (pixel)",
        Step = 5,
        Value = { Min = 40, Max = 400, Default = 120 },
        Callback = function(value)
            if value and value >= 40 then
                fovRadius = value
            end
        end,
    })
end
    end)()

    __VD_MODULES["Aim/AimVeil.lua"] = (function()
-- ============================================================
-- Aim/AimVeil.lua | Veil Aimbot (lempar tombak, killer first-person)
-- Hook Spearthrow(direction, speed, origin) -> timpa 'direction' pake
-- ballistic arc solver + lead per-jarak. Tombak NEMBUS TEMBOK -> NO wallcheck.
-- Gravity efektif 98.1 (arc). Aim lock cuma aktif pas attribute spearmode=true.
-- ============================================================
return function(ctx)
    local Workspace = ctx.Workspace
    local Teams = ctx.Teams
    local UserInputService = ctx.UserInputService
    local RunService = ctx.RunService
    local LocalPlayer = ctx.LocalPlayer
    local silentSupported = ctx.silentSupported

    local veilEnabled = false
    local veilEnableLead = true
    local veilFovRadius = 150
    local veilFovFollowMouse = true
    local veilAimLock = false        -- kamera ngunci ke target pas hold klik kiri (stance lempar)
    local veilShowFov = true
    local VEIL_TARGET_PART = "HumanoidRootPart"
    local VEIL_GRAVITY = 98.1
    local VEIL_AIM_SMOOTH = 0.35
    local VEIL_AIM_LOCK_SPEED = 165  -- full charge = 165, jarak max

    -- Offset lead per jarak (mult). Hook cari bracket jarak TERDEKAT ke jarak target.
    local veilOffsets = {
        { dist = 40, offset = 1.9 },
        { dist = 60, offset = 1.4 },
        { dist = 80, offset = 1.0 },
    }
    local function veilOffsetForDist(dist)
        local best, bestDiff = 1.0, math.huge
        for _, e in ipairs(veilOffsets) do
            local diff = math.abs(dist - e.dist)
            if diff < bestDiff then bestDiff = diff; best = e.offset end
        end
        return best
    end

    -- state Veil (di-update loop, dibaca hook)
    local veilTargetPos, veilTargetVel, veilTargetName = nil, nil, nil
    local veilSampleName, veilSamplePos, veilSampleT = nil, nil, 0
    local veilLockedPlayer = nil     -- target yg dikunci selama hold
    local veilLockGraceUntil = 0     -- pertahanin target sebentar abis lepas (buat throw)

    local function veilGetFovCenter()
        if veilFovFollowMouse then
            local m = UserInputService:GetMouseLocation()
            return Vector2.new(m.X, m.Y)
        end
        local vp = Workspace.CurrentCamera.ViewportSize
        return Vector2.new(vp.X / 2, vp.Y / 2)
    end

    local function veilGetPart(plr)
        return plr and plr.Character and plr.Character:FindFirstChild(VEIL_TARGET_PART)
    end

    -- Cek target masih dalem JANGKAUAN lempar (speed max = full charge 165). root>=0 = reachable.
    local function veilInRange(origin, targetPos, speed, g)
        local disp = targetPos - origin
        local dy = disp.Y
        local flatX, flatZ = disp.X, disp.Z
        local dx = math.sqrt(flatX * flatX + flatZ * flatZ)
        if dx < 0.001 then return true end
        local v2 = speed * speed
        local root = v2 * v2 - g * (g * dx * dx + 2 * dy * v2)
        return root >= 0
    end

    local function veilGetTarget()
        local team = Teams:FindFirstChild("Survivors")
        if not team then return nil end
        local cam = Workspace.CurrentCamera
        local origin = cam.CFrame.Position
        local center = veilGetFovCenter()
        local best, bestDist = nil, veilFovRadius
        for _, plr in ipairs(team:GetPlayers()) do
            if plr ~= LocalPlayer then
                local part = veilGetPart(plr)
                if part then
                    local sp, onScreen = cam:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                        -- WAJIB dalem jangkauan lempar. NO wallcheck (tombak nembus tembok).
                        if d <= bestDist and veilInRange(origin, part.Position, VEIL_AIM_LOCK_SPEED, VEIL_GRAVITY) then
                            best, bestDist = plr, d
                        end
                    end
                end
            end
        end
        return best
    end

    -- ballistic arc solver (math murni -> aman dipanggil di hook)
    local function veilSolveBallistic(origin, target, speed, g)
        local disp = target - origin
        local dy = disp.Y
        local flatX, flatZ = disp.X, disp.Z
        local dx = math.sqrt(flatX * flatX + flatZ * flatZ)
        if dx < 0.001 then
            return (disp.Magnitude > 0) and disp.Unit or nil, 0
        end
        local v2 = speed * speed
        local root = v2 * v2 - g * (g * dx * dx + 2 * dy * v2)
        local tanTheta
        if root < 0 then
            tanTheta = 1  -- di luar jangkauan fisik -> 45deg best-effort
        else
            local sq = math.sqrt(root)
            tanTheta = (v2 - sq) / (g * dx)
        end
        local horiz = Vector3.new(flatX / dx, 0, flatZ / dx)
        local dir = (horiz + Vector3.new(0, tanTheta, 0))
        if dir.Magnitude < 0.001 then return nil end
        dir = dir.Unit
        local cosTheta = math.sqrt(dir.X * dir.X + dir.Z * dir.Z)
        local tof = (speed * cosTheta > 0.001) and (dx / (speed * cosTheta)) or 0
        return dir, tof
    end

    local function veilSolveLead(origin, targetPos, targetVel, speed, g)
        local pred = targetPos
        local dist = (targetPos - origin).Magnitude
        local applyLead = veilEnableLead and targetVel
        local mult = applyLead and veilOffsetForDist(dist) or 0
        local dir, tof
        for _ = 1, 3 do
            dir, tof = veilSolveBallistic(origin, pred, speed, g)
            if not dir then return nil end
            if applyLead then
                pred = targetPos + targetVel * (tof * mult)
            end
        end
        return dir, tof
    end

    -- FOV circle Veil
    local veilFovCircle = nil
    if Drawing then
        veilFovCircle = Drawing.new("Circle")
        veilFovCircle.Thickness = 2
        veilFovCircle.NumSides = 64
        veilFovCircle.Radius = veilFovRadius
        veilFovCircle.Filled = false
        veilFovCircle.Visible = false
        veilFovCircle.Color = Color3.fromRGB(255, 255, 255)
    end

    -- LOOP Veil: track target + velocity manual (pos delta) + circle
    local veilRenderConn = RunService.RenderStepped:Connect(function()
        if not (veilEnabled or veilAimLock) then
            veilTargetPos, veilTargetVel, veilTargetName = nil, nil, nil
            veilSampleName = nil
            veilLockedPlayer = nil
            if veilFovCircle then veilFovCircle.Visible = false end
            return
        end
        if veilFovCircle then
            veilFovCircle.Visible = veilShowFov
            veilFovCircle.Radius = veilFovRadius
            veilFovCircle.Position = veilGetFovCenter()
        end
        -- HOLD klik kiri PAS DI STANCE LEMPAR (spearmode) -> kunci target POV; ga ganti sampe lepas.
        local stanceChar = LocalPlayer.Character
        local inThrowStance = stanceChar and stanceChar:GetAttribute("spearmode") == true
        local holding = inThrowStance and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
        local target
        if holding then
            if not veilLockedPlayer then
                veilLockedPlayer = veilGetTarget()  -- capture target pas mulai hold
            end
            if not (veilLockedPlayer and veilLockedPlayer.Parent and veilGetPart(veilLockedPlayer)) then
                veilLockedPlayer = veilGetTarget()  -- locked target ilang/mati -> ambil baru
            end
            target = veilLockedPlayer
            veilLockGraceUntil = tick() + 0.3
        elseif veilLockedPlayer and tick() < veilLockGraceUntil
            and veilLockedPlayer.Parent and veilGetPart(veilLockedPlayer) then
            target = veilLockedPlayer       -- grace: pertahanin buat throw yg fire pas lepas hold
        else
            veilLockedPlayer = nil
            target = veilGetTarget()        -- ga hold -> preview bebas
        end
        if target then
            local part = veilGetPart(target)
            if part then
                local pos = part.Position
                local now = tick()
                if veilSampleName == target.Name and veilSamplePos then
                    local dt = now - veilSampleT
                    if dt >= 0.04 then
                        local instVel = (pos - veilSamplePos) / dt
                        veilTargetVel = veilTargetVel and veilTargetVel:Lerp(instVel, 0.5) or instVel
                        veilSamplePos = pos
                        veilSampleT = now
                    end
                else
                    veilSampleName = target.Name
                    veilSamplePos = pos
                    veilSampleT = now
                    veilTargetVel = Vector3.zero
                end
                veilTargetPos = pos
                veilTargetName = target.Name
                if veilFovCircle then veilFovCircle.Color = Color3.fromRGB(255, 0, 0) end
                -- AIM LOCK: arahin kamera ke ARAH LEMPAR (ballistic arc), bukan flat ke target.
                if veilAimLock and holding then
                    local cam = Workspace.CurrentCamera
                    local origin = cam.CFrame.Position
                    local dir = veilSolveLead(origin, pos, veilTargetVel, VEIL_AIM_LOCK_SPEED, VEIL_GRAVITY)
                    if dir then
                        local goal = CFrame.new(origin, origin + dir)
                        cam.CFrame = cam.CFrame:Lerp(goal, VEIL_AIM_SMOOTH)
                    end
                end
            else
                veilTargetPos, veilTargetVel = nil, nil
                veilSampleName = nil
            end
        else
            veilTargetPos, veilTargetVel = nil, nil
            veilSampleName = nil
            if veilFovCircle then veilFovCircle.Color = Color3.fromRGB(255, 255, 255) end
        end
    end)

    -- HOOK silent aim Veil: timpa arah Spearthrow
    ctx.onNamecall(function(self, method, ...)
        if method == "FireServer" and veilEnabled and veilTargetPos and self.Name == "Spearthrow" then
            local p = self.Parent
            if p and p.Name == "Veil" then
                local args = { ... }
                local dirArg, speedArg, originArg = args[1], args[2], args[3]
                if typeof(dirArg) == "Vector3" and type(speedArg) == "number" and typeof(originArg) == "Vector3" then
                    local newDir = veilSolveLead(originArg, veilTargetPos, veilTargetVel, speedArg, VEIL_GRAVITY)
                    if newDir then
                        args[1] = newDir
                        return true, ctx.callOriginal(self, unpack(args))
                    end
                end
            end
        end
        return false
    end)

    -- cleanup loop + circle lama pas re-execute
    if getgenv then
        local g = getgenv()
        if g.__tomaVeilRender then pcall(function() g.__tomaVeilRender:Disconnect() end) end
        g.__tomaVeilRender = veilRenderConn
        if g.__tomaVeilFov then pcall(function() g.__tomaVeilFov:Remove() end) end
        g.__tomaVeilFov = veilFovCircle
    end

    -- ===================== UI =====================
    local VeilSection = ctx.tabs.Aim:Section({
        Title = "Veil Aim",
        Desc = "Aimbot lempar tombak Veil (offset lead per jarak)",
        Box = true,
        BoxBorder = true,
        Opened = true,
    })

    local VeilToggle = VeilSection:Toggle({
        Title = silentSupported and "Veil Aim" or "Veil Aim (Unsupported Executor)",
        Desc = silentSupported and "Auto-arah tombak ke survivor di FOV (nembus tembok)" or "Executor lo ga support metatable hook.",
        Locked = not silentSupported,
        Value = veilEnabled,
        Callback = function(state)
            if not silentSupported then return end
            veilEnabled = state
        end,
    })
    if (not silentSupported) and VeilToggle then
        pcall(function() VeilToggle:Lock("Unsupported Executor") end)
    end

    VeilSection:Toggle({
        Title = "Aim Lock (hold klik kiri)",
        Desc = "Pas stance lempar (spearmode), hold klik kiri -> kamera ngunci ke target. Lepas buat ganti target.",
        Value = veilAimLock,
        Callback = function(state)
            veilAimLock = state
        end,
    })

    VeilSection:Toggle({
        Title = "Lead Prediction",
        Desc = "Prediksi gerak survivor (offset ke arah lari)",
        Value = veilEnableLead,
        Callback = function(state)
            veilEnableLead = state
        end,
    })

    VeilSection:Toggle({
        Title = "POV Circle",
        Desc = "Tampilin/sembunyiin lingkaran visual POV (tracking tetep jalan)",
        Value = veilShowFov,
        Callback = function(state)
            veilShowFov = state
        end,
    })

    VeilSection:Slider({
        Title = "FOV Radius",
        Desc = "Radius lingkaran FOV Veil (pixel)",
        Step = 5,
        Value = { Min = 40, Max = 400, Default = 150 },
        Callback = function(value)
            if value and value >= 40 then veilFovRadius = value end
        end,
    })

    -- Offset lead per jarak: Distance = Input keyboard, Offset = Slider.
    VeilSection:Paragraph({
        Title = "Offset per Jarak",
        Desc = "Ketik jarak (studs) di Input, atur offset-nya pake slider. Tombol + buat nambah.",
    })

    local veilOffsetCount = 0
    local function veilAddOffsetUI(entry)
        veilOffsetCount = veilOffsetCount + 1
        local n = veilOffsetCount
        VeilSection:Input({
            Title = "Jarak #" .. n .. " (studs)",
            Desc = "Ketik jarak buat bracket ini",
            Value = tostring(entry.dist),
            Type = "Input",
            Placeholder = "contoh: 40",
            Callback = function(input)
                local num = tonumber(input)
                if num then entry.dist = num end
            end,
        })
        VeilSection:Slider({
            Title = "Offset #" .. n,
            Desc = "Lead multiplier pas jarak segini",
            Step = 0.1,
            Value = { Min = 0, Max = 5, Default = entry.offset },
            Callback = function(value)
                if value then entry.offset = value end
            end,
        })
    end

    for _, e in ipairs(veilOffsets) do
        veilAddOffsetUI(e)
    end

    VeilSection:Button({
        Title = "+ Tambah Setingan Jarak",
        Desc = "Tambah bracket jarak -> offset baru",
        Callback = function()
            local newEntry = { dist = 100, offset = 2.0 }
            table.insert(veilOffsets, newEntry)
            veilAddOffsetUI(newEntry)
        end,
    })
end
    end)()

    local function loadModule(path)
        local ret = __VD_MODULES[path]
        if ret == nil then
            warn("[TomHub/VD] module ga ada di bundle: " .. path)
            return nil
        end
        return ret
    end

    local function runModule(path)
        local init = loadModule(path)
        if type(init) == "function" then
            local ok, err = pcall(init, ctx)
            if not ok then warn("[TomHub/VD] init error " .. path .. ": " .. tostring(err)) end
        elseif init ~= nil then
            warn("[TomHub/VD] module tidak return function: " .. path)
        end
    end

    runModule("Combat/AutoParry.lua")
    runModule("Combat/AutoParryDashHidden.lua")
    runModule("Combat/AutoDogdeAbbys.lua")
    runModule("Combat/SkillCheck.lua")
    runModule("Visual/Esp.lua")
    runModule("Aim/AimTwistOfFate.lua")
    runModule("Aim/AimVeil.lua")

    -- ============================================================
    -- [START HOOKS] setelah semua handler kedaftar
    -- ============================================================
    installNamecallHook()
    if KillerTeam then
        hookKillerAnimators()
        KillerTeam.PlayerAdded:Connect(hookKillerAnimators)
        KillerTeam.PlayerRemoved:Connect(hookKillerAnimators)
    end

    WindUI:Notify({
        Title = "TomHub",
        Content = "Violence District loaded! Press H to toggle UI.",
        Duration = 5,
    })
end
