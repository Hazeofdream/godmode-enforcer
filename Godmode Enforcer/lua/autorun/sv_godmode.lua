if not SERVER then return end

-- Allow noclip only for godmode players or allowed groups.
hook.Add("PlayerNoClip", "GODMODE_ControlNoClip", function(ply, state)
    if ply:HasGodMode() and state then
        return true 
    end

    -- fallback checks for built-in admin flags
    if ply:IsSuperAdmin() then return true end
    if ply:IsAdmin() and table.HasValue(allowedNoClipGroups, "admin") then return true end

    return false
end)

-- Prevent damage from godmode players to non-godmode players.
-- If a godmode player damages a non-godmode player: nullify damage and kill the attacker, announce globally.
local recentlyPunished = {} -- steamid -> timestamp; to avoid multiple kills in same frame

hook.Add("EntityTakeDamage", "GODMODE_NullifyAndPunish", function(target, dmginfo)
    if not IsValid(target) or not target:IsPlayer() then return end

    local attacker = dmginfo:GetAttacker()
    if not IsValid(attacker) or not attacker:IsPlayer() then return end

    if attacker:HasGodMode() and not target:HasGodMode() then
        -- Prevent any damage to the target from this attacker
        dmginfo:SetDamage(0)
        dmginfo:ScaleDamage(0)
        dmginfo:SubtractDamage(dmginfo:GetDamage()) -- extra safety

        local sid = attacker:SteamID()
        local now = CurTime()
        if recentlyPunished[sid] and recentlyPunished[sid] > now then
            return true
        end

        recentlyPunished[sid] = now + 1

        if attacker:Alive() then
            attacker:Kill()

            local msg = string.format("%s attempted to damage %s while in Godmode!",attacker:Nick(), target:Nick())
            PrintMessage(HUD_PRINTTALK, msg)
        end

        -- Block any further damage processing
        return true
    end
end)

-- Hook into when a player's godmode status might change
hook.Add("Think", "GodmodeControl_CheckUnnoclip", function()
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end

        -- If they are in noclip and lost godmode without proper rank
        if ply:GetMoveType() == MOVETYPE_NOCLIP and not ply:HasGodMode() then
            if not ply:IsSuperAdmin() and not ply:IsAdmin() then
                ply:SetMoveType(MOVETYPE_WALK)
                ply:ChatPrint("You lost Godmode and were removed from noclip!")
            end
        end
    end
end)