if not CLIENT then return end

-- Branding Options
local PanelCategory = "Excelsus"
local PanelName = "Nametags"

local settingsFile = "godmode_enforcer/settings.json"
local settings = {}

-- Default settings
local defaultSettings = {
    enable = true,
    throughWalls = false,
    alwaysOnLook = true,
    neverScale = false,
    maxDist = 2000,
    scale = 1.0,
    coneLeniency = 3,
    tagColor = { r = 255, g = 220, b = 0 },
    boxAlpha = 160
}

-- ===== Settings load/save =====
local function LoadSettings()
    if file.Exists(settingsFile, "DATA") then
        local data = file.Read(settingsFile, "DATA")
        local tbl = util.JSONToTable(data or "")
        if istable(tbl) then
            settings = table.Merge(table.Copy(defaultSettings), tbl)
            return
        end
    end
    settings = table.Copy(defaultSettings)
end

local function SaveSettings()
    if not file.Exists("godmode_enforcer", "DATA") then
        file.CreateDir("godmode_enforcer")
    end
    file.Write(settingsFile, util.TableToJSON(settings, true))
end

LoadSettings()

-- ===== Helpers =====
local function CanSeePlayer(localply, target)
    if not IsValid(localply) or not IsValid(target) then return false end
    local tr = util.TraceLine({
        start = localply:EyePos(),
        endpos = target:EyePos(),
        filter = { localply, target },
        mask = MASK_SHOT_HULL
    })
    if not tr.Hit then return true end
    if IsValid(tr.Entity) and tr.Entity == target then return true end
    return false
end

local function IsLookingAt(localply, target, coneDeg)
    if not IsValid(localply) or not IsValid(target) then return false end
    local eyeTr = localply:GetEyeTrace()
    if IsValid(eyeTr.Entity) and eyeTr.Entity == target then return true end
    coneDeg = coneDeg or 6
    local dir = localply:EyeAngles():Forward()
    local toTarget = (target:EyePos() - localply:EyePos()):GetNormalized()
    local dot = dir:Dot(toTarget)
    local cosTol = math.cos(math.rad(coneDeg))
    return dot >= cosTol
end

-- ===== Font cache =====
local FontCache = {}
local function GetScaledFontName(size)
    size = math.max(10, math.floor(size))
    local name = "GodmodeEnforcer_Font_" .. tostring(size)
    if not FontCache[name] then
        surface.CreateFont(name, {
            font = "Trebuchet MS",
            size = size,
            weight = 700,
            antialias = true
        })
        FontCache[name] = true
    end
    return name
end

-- ===== HUDPaint draw tag =====
hook.Add("HUDPaint", "GodmodeEnforcer_2D_Draw", function()
    local lp = LocalPlayer()
    if not IsValid(lp) or not lp:Alive() then return end
    if not settings.enable then return end

    local maxdist      = math.max(0, tonumber(settings.maxDist) or defaultSettings.maxDist)
    local unlimited    = (maxdist <= 0)
    local throughWalls = settings.throughWalls
    local alwaysOnLook = settings.alwaysOnLook
    local neverScale   = settings.neverScale
    local scaleMult    = tonumber(settings.scale) or defaultSettings.scale
    local coneLen      = math.Clamp(tonumber(settings.coneLeniency) or defaultSettings.coneLeniency, 1, 16)
    local boxAlpha     = math.Clamp(tonumber(settings.boxAlpha) or defaultSettings.boxAlpha, 0, 255)
    local col          = settings.tagColor or defaultSettings.tagColor
    local tagCol       = Color(col.r, col.g, col.b, 255)

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or ply == lp then continue end
        if not ply:Alive() then continue end
        if not ply:HasGodMode() then continue end

        local headWorld = ply:EyePos() + Vector(0, 0, 12)
        local scr = headWorld:ToScreen()
        if not scr.visible then continue end

        local dist = lp:GetPos():Distance(ply:GetPos())
        local withinRange = unlimited or (dist <= maxdist)

        local looking = IsLookingAt(lp, ply, coneLen)
        if looking and alwaysOnLook then
            withinRange = true -- affects distance only
        end
        if not withinRange then continue end

        -- line-of-sight check is separate
        if not throughWalls and not CanSeePlayer(lp, ply) then
            continue
        end

        -- ===== FONT SCALING =====
        local baseSize = 22
        local fontSize = baseSize * scaleMult

        if neverScale and not unlimited then
            local norm = math.min(dist / maxdist, 1)
            local ease = math.sqrt(norm) -- smoother curve
            local scaleFactor = 1 - ease
            scaleFactor = math.Clamp(scaleFactor, 0.5, 1.5)
            fontSize = math.max(10, math.Round(fontSize * scaleFactor))
        else
            fontSize = math.max(10, math.Round(fontSize))
        end

        local fontToUse = GetScaledFontName(fontSize)
        local text = ply:IsFrozen() and "FROZEN" or "GODMODE"

        surface.SetFont(fontToUse)
        local tw, th = surface.GetTextSize(text)
        local x = scr.x
        local y = scr.y - 10 - th

        -- box
        local paddingX, paddingY = 8, 4
        local boxW, boxH = tw + paddingX, th + paddingY
        local boxX, boxY = x - boxW / 2, y - paddingY / 2
        draw.RoundedBox(6, boxX - 2, boxY - 2, boxW + 4, boxH + 4, Color(0, 0, 0, boxAlpha))

        draw.SimpleTextOutlined(text, fontToUse, x, y, tagCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, Color(0,0,0,200))
    end
end)

-- ===== Options menu =====
hook.Add("PopulateToolMenu", "GodmodeEnforcer_OptionsMenu", function()
    spawnmenu.AddToolMenuOption("Options", PanelCategory, "GodmodePanel", PanelName, "", "", function(panel)
        panel:Clear()

        local enable = vgui.Create("DCheckBoxLabel", panel)
        enable:SetText("Enable")
        enable:SetValue(settings.enable and 1 or 0)
        enable:Dock(TOP)
        enable:DockMargin(4,2,4,2)
        enable.OnChange = function(_, val) settings.enable = val; SaveSettings() end
        enable:SetFont("DermaDefaultBold")
        panel:AddItem(enable)

        local walls = vgui.Create("DCheckBoxLabel", panel)
        walls:SetText("Through Walls")
        walls:SetValue(settings.throughWalls and 1 or 0)
        walls:Dock(TOP)
        walls:DockMargin(4,2,4,2)
        walls.OnChange = function(_, val) settings.throughWalls = val; SaveSettings() end
        walls:SetFont("DermaDefaultBold")
        panel:AddItem(walls)

        local look = vgui.Create("DCheckBoxLabel", panel)
        look:SetText("Force when Looking")
        look:SetValue(settings.alwaysOnLook and 1 or 0)
        look:Dock(TOP)
        look:DockMargin(4,2,4,2)
        look.OnChange = function(_, val) settings.alwaysOnLook = val; SaveSettings() end
        look:SetFont("DermaDefaultBold")
        panel:AddItem(look)

        local nscale = vgui.Create("DCheckBoxLabel", panel)
        nscale:SetText("Never Scale Nametag on Distance")
        nscale:SetValue(settings.neverScale and 1 or 0)
        nscale:Dock(TOP)
        nscale:DockMargin(4,2,4,2)
        nscale.OnChange = function(_, val) settings.neverScale = val; SaveSettings() end
        nscale:SetFont("DermaDefaultBold")
        panel:AddItem(nscale)

        local dist = vgui.Create("DNumSlider", panel)
        dist:SetText("Max Distance")
        dist:SetMin(0)
        dist:SetMax(20000)
        dist:SetDecimals(0)
        dist:SetValue(settings.maxDist)
        dist:Dock(TOP)
        dist:DockMargin(4,2,4,2)
        dist.OnValueChanged = function(_, val) settings.maxDist = math.floor(val); SaveSettings() end
        dist.Label:SetFont("DermaDefaultBold")
        panel:AddItem(dist)
        panel:ControlHelp("Tags will not render past this")
        panel:ControlHelp("0 = unlimited distance")

        local scale = vgui.Create("DNumSlider", panel)
        scale:SetText("Scale")
        scale:SetMin(0.1)
        scale:SetMax(5)
        scale:SetDecimals(1)
        scale:SetValue(settings.scale)
        scale:Dock(TOP)
        scale:DockMargin(4,2,4,2)
        scale.OnValueChanged = function(_, val) settings.scale = val; SaveSettings() end
        scale.Label:SetFont("DermaDefaultBold")
        panel:AddItem(scale)

        local cone = vgui.Create("DNumSlider", panel)
        cone:SetText("Cone Leniency")
        cone:SetMin(1)
        cone:SetMax(16)
        cone:SetDecimals(0)
        cone:SetValue(settings.coneLeniency)
        cone:Dock(TOP)
        cone:DockMargin(4,2,4,2)
        cone.OnValueChanged = function(_, val) settings.coneLeniency = math.Clamp(math.floor(val),1,16); SaveSettings() end
        cone.Label:SetFont("DermaDefaultBold")
        panel:AddItem(cone)
        panel:ControlHelp("How lenient the search for player nametags is")

        local alpha = vgui.Create("DNumSlider", panel)
        alpha:SetText("Box Alpha")
        alpha:SetMin(0)
        alpha:SetMax(255)
        alpha:SetDecimals(0)
        alpha:SetValue(settings.boxAlpha)
        alpha:Dock(TOP)
        alpha:DockMargin(4,2,4,2)
        alpha.OnValueChanged = function(_, val) settings.boxAlpha = math.Clamp(math.floor(val),0,255); SaveSettings() end
        alpha.Label:SetFont("DermaDefaultBold")
        panel:AddItem(alpha)

        local colorMixer = vgui.Create("DColorMixer", panel)
        colorMixer:SetPalette(true)
        colorMixer:SetAlphaBar(false)
        colorMixer:SetWangs(true)
        colorMixer:SetColor(Color(settings.tagColor.r, settings.tagColor.g, settings.tagColor.b))
        colorMixer:Dock(TOP)
        colorMixer:SetTall(160)
        colorMixer.ValueChanged = function(_, col)
            settings.tagColor = { r = col.r, g = col.g, b = col.b }
            SaveSettings()
        end
        panel:AddItem(colorMixer)
    end)
end)

-- First run hint
if not file.Exists("godmode_enforcer/seen_hint.txt", "DATA") then
    print("Open the spawnmenu (Q) → Options → Godmode Enforcer to edit settings.")
    file.CreateDir("godmode_enforcer")
    file.Write("godmode_enforcer/seen_hint.txt", "1")
end