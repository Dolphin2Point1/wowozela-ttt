local wowozela = _G.wowozela_ttt or {}
_G.wowozela_ttt = wowozela


wowozela.ValidNotes = {
    ["Left"] = IN_ATTACK,
    ["Right"] = IN_ATTACK2
}

wowozela.ValidKeys = {IN_ATTACK, IN_ATTACK2, IN_WALK, IN_SPEED, IN_USE}

wowozela.KnownSamples = wowozela.KnownSamples or {}


function wowozela.GetSamples()
    return wowozela.KnownSamples
end

function wowozela.GetSample(i)
    return wowozela.KnownSamples[i]
end

if CLIENT then
    wowozela.Samplers = {}
    wowozela.volume = CreateClientConVar("wowozela_volume", "0.5", true, false)
    wowozela.hudtext = CreateClientConVar("wowozela_hudtext", "1", true, false)
    wowozela.pitchbar = CreateClientConVar("wowozela_pitchbar", "1", true, false)
    wowozela.help = CreateClientConVar("wowozela_help", "1", true, false)
    wowozela.defaultpage = CreateClientConVar("wowozela_defaultpage", "", true, false)

    local function set_sample_index(which, note_index)
        local wep = LocalPlayer():GetActiveWeapon()

        if not wep:IsValid() or wep:GetClass() ~= "ttt_wowozela" then
            return
        end

        net.Start("wowozela_ttt")
            net.WriteInt(wowozela.NET.wowozela_select, 4)
            net.WriteInt(which, 32)
            net.WriteInt(note_index, 32)
        net.SendToServer()
    end

    function wowozela.SetSampleIndexLeft(noteIndex)
        return set_sample_index(IN_ATTACK, noteIndex)
    end

    function wowozela.SetSampleIndexRight(noteIndex)
        return set_sample_index(IN_ATTACK2, noteIndex)
    end


    function wowozela.RequestCustomSamplesIndexes(samples)
        net.Start("wowozela_ttt")
            net.WriteInt(wowozela.NET.wowozela_customsample, 4)
            net.WriteTable(samples)
        net.SendToServer()
    end

    local FOLDER = "wowozela_cache"
    file.CreateDir(FOLDER, "DATA")
    local ID_OGG = "\x4F\x67\x67\x53"
    local ID_ID3 = "\x49\x44\x33"
    local ID_MP3_1 = "\xFF\xFB"
    local ID_MP3_2 = "\xFF\xF3"
    local ID_MP3_3 = "\xFF\xF2"
    local FILE_LIMIT_MB = 10
    local FILE_LIMIT = FILE_LIMIT_MB * 1024 * 1024
    local function isOGGorMP3(data)
        return  data:sub(1, 3) == ID_ID3 or
                data:sub(1, 4) == ID_OGG or
                data:sub(1, 2) == ID_MP3_1 or
                data:sub(1, 2) == ID_MP3_2 or
                data:sub(1, 2) == ID_MP3_3
    end
    local function GetURLSound(url, back, fail)
        if url == "" then return end
        local path = FOLDER .. "/" .. util.CRC(url) .. ".dat"

        local exists = file.Exists(path, "DATA")
        if exists then
            back("data/" .. path)
            return
        end

        http.Fetch(url, function(data,len,hdr,code)
            if string.len(data) > FILE_LIMIT then
                return fail(("Too big (>%s MB)."):format(FILE_LIMIT_MB))
            end
            if not isOGGorMP3(data) then
                return fail("Downloaded file was not an ogg/mp3, not a direct link?")
            end
            file.Write(path, data)
            back("data/" .. path)
        end, function(err)
            fail(("HTTP %s"):format(err))
        end, {
            ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.214 Safari/537.36 Vivaldi/3.8.2259.42"
        })
    end

    local patterns = {
        ["^https?://drive%.google%.com/file/d/(.-)/"] = "https://drive.google.com/u/0/uc?id=%s&export=download",
        ["^https?://drive%.google%.com/file/d/(.-)$"] = "https://drive.google.com/u/0/uc?id=%s&export=download",
        ["^https?://drive%.google%.com/open%?id=(.-)$"] = "https://drive.google.com/u/0/uc?id=%s&export=download",
        ["^https?://www%.dropbox%.com/s/(.+)%?dl%=[01]$"] = "https://dl.dropboxusercontent.com/s/%s",
        ["^https?://www%.dropbox%.com/s/(.+)$"] = "https://dl.dropboxusercontent.com/s/%s",
        ["^https?://dl%.dropbox%.com/s/(.+)%?dl%=[01]$"] = "https://dl.dropboxusercontent.com/s/%s",
        ["^https?://dl%.dropbox%.com/s/(.+)$"] = "https://dl.dropboxusercontent.com/s/%s",
        ["^https://vocaroo.com/(.+)$"] = "https://media1.vocaroo.com/mp3/%s",
    }
    function wowozela.ProcessURL(url)
        for pattern, replace in pairs(patterns) do
            local match = string.match(url, pattern)
            if match then
                return string.format(replace, match), match
            end
        end

        return url
    end

    function wowozela.PlayURL(name, settings, callback, failurecallback)
        if #name == 0 then return failurecallback and failurecallback("Empty URL?") end
        if not wowozela.URLWhitelist(name) then
            return failurecallback and failurecallback("Not a whitelisted URL.")
        end

        name = wowozela.ProcessURL(name)
        GetURLSound(name, function(sndPath)
            sound.PlayFile(sndPath, settings, callback)
        end, failurecallback or function() end)
    end
end


if SERVER then
    function wowozela.LoadSamples()
        wowozela.KnownSamples = {}

        local _, directories = file.Find("sound/ttt_wowozela/samples/*", "GAME")

        for _, directory in ipairs(directories) do
            for _, file_name in ipairs(file.Find("sound/ttt_wowozela/samples/" .. directory .. "/*", "GAME")) do
                if file_name:EndsWith(".ogg") or file_name:EndsWith(".mp3") then
                    table.insert(wowozela.KnownSamples, {
                        category = directory,
                        path = "ttt_wowozela/samples/" .. directory .. "/" .. file_name,
                        name = file_name:match("(.+)%.")
                    })
                end
            end
        end

        table.sort(wowozela.KnownSamples, function(a, b)
            return a.path < b.path
        end)
    end
    wowozela.LoadSamples()

    util.AddNetworkString("wowozela_ttt")

    resource.AddWorkshop("2976397303")

    function wowozela.BroacastSamples(ply)
        net.Start("wowozela_ttt")
            net.WriteInt(wowozela.NET.wowozela_update_samples, 4)
            net.WriteTable(wowozela.KnownSamples)
            net.WriteBool(true)
            net.WriteInt(0, 10)
        net.Send(ply)
    end

    hook.Add("PlayerInitialSpawn", "send_wowozela_samples", function(ply)
        local hookName = "wowozela_" .. ply:SteamID64()
        hook.Add("SetupMove", hookName, function(oply, _, cmd)
            if ply == oply and not cmd:IsForced() then
                wowozela.BroacastSamples(oply)
                hook.Remove("SetupMove", hookName)
            end
        end)
    end)

end

function wowozela.IsValidKey(key)
    return table.HasValue(wowozela.ValidKeys, key)
end

function wowozela.KeyToButton(key)
    for k, v in pairs(wowozela.ValidNotes) do
        if v == key then
            return k
        end
    end
    return false
end

-- Do Networking
wowozela.NET = {
    ["wowozela_pitch"] = 0,
    ["wowozela_key"] = 1,
    ["wowozela_select"] = 2,
    ["wowozela_customsample"] = 3,
    ["wowozela_update_samples"] = 4,
    ["wowozela_sample"] = 5,
    ["wowozela_togglelooping"] = 6,
}
wowozela.allowcustomsamples = CreateConVar("wowozela_customsamples", "1", {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY})

local keys = {
    [IN_ATTACK] = "Left",
    [IN_ATTACK2] = "Right"
}

if SERVER then
    local netFuncs = {
        [wowozela.NET.wowozela_pitch] = function(len, ply)
            local pitch = net.ReadFloat()
            ply.net_incoming_rate_count = nil
            ply.wowozela_real_pitch = pitch

            net.Start("wowozela_ttt", true)
                net.WriteInt(wowozela.NET.wowozela_pitch, 4)
                net.WriteEntity(ply)
                net.WriteFloat(pitch)
            net.SendOmit(ply)
        end,
        [wowozela.NET.wowozela_select] = function(len, ply)
            local key, value = net.ReadInt(32), net.ReadInt(32)
            local wep = ply:GetActiveWeapon()
            if wep:IsValid() and wep:GetClass() == "ttt_wowozela" then
                local function_name = "SetNoteIndex" .. keys[key]

                if wep[function_name] then
                    wep[function_name](wep, value)
                    net.Start("wowozela_ttt")
                        net.WriteInt(wowozela.NET.wowozela_sample, 4)
                        net.WriteEntity(ply)
                        net.WriteInt(key, 32)
                        net.WriteInt(value, 32)
                    net.Broadcast()
                end
            end
        end,
        [wowozela.NET.wowozela_customsample] = function(len, ply)
            local samples = net.ReadTable()
            local startID = 4500 + ply:EntIndex() * 15
            for I = startID, startID + 11 do
                wowozela.KnownSamples[I] = nil
            end

            if not wowozela.allowcustomsamples:GetBool() then return end

            local newSamples = {}
            for k,v in pairs(samples) do
                if k > 0 and k <= 10 then
                    local newSample = {
                        category = "custom-sample-hidden",
                        owner = ply:EntIndex(),
                        custom = true,
                        path = v[1],
                        name = v[2]
                    }

                    wowozela.KnownSamples[startID + k] = newSample
                    newSamples[startID + k] = newSample
                end
            end

            net.Start("wowozela_ttt")
                net.WriteInt(wowozela.NET.wowozela_update_samples, 4)
                net.WriteTable(newSamples)
                net.WriteBool(false)
                net.WriteUInt(ply:EntIndex(), 10)
            net.Broadcast()
        end,
        [wowozela.NET.wowozela_togglelooping] = function(len, ply)
            local wep = ply:GetActiveWeapon()
            if wep:IsValid() and wep:GetClass() == "ttt_wowozela" then
                wep:SetLooping(not wep:GetLooping())
            end
        end
    }
    net.Receive("wowozela_ttt", function(len, ply)
        local func = netFuncs[net.ReadInt(4)]
        if func then func(len, ply) end
    end)
else
    local function update_sample(ply, i, v)
        local sampler = wowozela.GetSampler(ply)
        if not sampler then return end
        if v then
            sampler:SetSample(i, v.custom, v.path)
        elseif sampler.Samples and sampler.Samples[i] then
            if IsValid(sampler.Samples[i].obj) then
                sampler.Samples[i].obj:Stop()
            end
            sampler.Samples[i] = nil
        end
    end

    local netFuncs = {
        [wowozela.NET.wowozela_pitch] = function()
            local ply = net.ReadEntity()
            if not IsValid(ply) or not wowozela.GetSampler(ply) then return end
            ply.wowozela_real_pitch = net.ReadFloat()
        end,
        [wowozela.NET.wowozela_key] = function()
            local ply = net.ReadEntity()
            if not IsValid(ply) or not wowozela.GetSampler(ply) then return end
            wowozela.KeyEvent(ply, net.ReadInt(32), net.ReadBool())
        end,
        [wowozela.NET.wowozela_update_samples] = function()
            for i, v in pairs(net.ReadTable()) do
                wowozela.KnownSamples[i] = v
            end

            if not net.ReadBool() then
                local updatedPly = 4500 + net.ReadUInt(10) * 15
                for _, ply in ipairs(player.GetHumans()) do
                    for i = updatedPly, updatedPly + 11 do
                        local v = wowozela.KnownSamples[i]
                        update_sample(ply, i, v)
                    end
                end
                return
            end

            wowozela.SetSampleIndexLeft(1)
            wowozela.SetSampleIndexRight(1)

            for _, ply in ipairs(player.GetHumans()) do
                local sampler = wowozela.GetSampler(ply)
                if sampler then
                    for _,v in pairs(sampler.Samples or {}) do
                        if v.obj then
                            v.obj:Stop()
                        end
                    end
                    wowozela.CreateSampler(ply)
                end
                local wep = ply:GetActiveWeapon()
                if wep:IsValid() and wep:GetClass() == "ttt_wowozela" then
                    wep:LoadPages()
                end
            end
        end,
        [wowozela.NET.wowozela_sample] = function()
            local ply = net.ReadEntity()
            if not IsValid(ply) or not wowozela.GetSampler(ply) then return end
            local sampler = wowozela.GetSampler(ply)
            local key = net.ReadInt(32)
            local id = net.ReadInt(32)

            if sampler:IsPlaying() then
                sampler:Start(id, key)
            end
        end,
    }
    net.Receive("wowozela_ttt", function()
        local func = netFuncs[net.ReadInt(4)]
        if func then func() end
    end)
end


if CLIENT then -- sample meta
    local META = {}
    META.__index = META

    function META:Initialize(ply)
        self.Player = NULL

        self.Pitch = 100
        self.Volume = 1

        self.Keys = {}
        self.Samples = {}

        self.Player = ply
        for i, sample in pairs(wowozela.KnownSamples) do
            self:SetSample(i, sample.custom, sample.path)
        end

        self.KeyToSample = {}
    end

    function META:KeyToSampleIndex(key)
        local button = wowozela.KeyToButton(key)
        if button then
            local wep = self.Player:GetActiveWeapon()
            local get = "GetNoteIndex" .. button
            if IsValid(wep) and wep:GetClass() == "ttt_wowozela" and wep[get] then
                return wep[get](wep)
            end
        end
    end

    function META:CanPlay()
        if not IsValid(self.Player) then return false end

        local wep = self.Player:GetActiveWeapon()
        if IsValid(wep) and wep:GetClass() == "ttt_wowozela" then
            return true
        end

        return false
    end

    function META:GetPos()
        if self.Player == LocalPlayer() and not self.Player:ShouldDrawLocalPlayer() then
            return self.Player:EyePos()
        end

        local id = self.Player:LookupBone("ValveBiped.Bip01_Head1")
        local pos = id and self.Player:GetBonePosition(id)
        return pos or self.Player:EyePos()
    end

    function META:GetAngles()
        local ang = self.Player:GetAimVector():Angle()
        ang.r = 0

        return ang
    end

    function META:IsPlaying() -- hm
        for _, on in pairs(self.Keys) do
            if on then
                return true
            end
        end

        return false
    end

    local function create_sound(path, isHttp, sampler)
        local processing = false
        local _smeta = {
            __index = function(self, index)
                if index == "create" then
                    return function(callback)
                        if IsValid(rawget(self, "obj")) then
                            callback()
                        else
                            if processing then return end
                            processing = true
                            local func, newPath =  (isHttp and wowozela.PlayURL or sound.PlayFile), isHttp and path or "sound/" .. path
                            func(newPath, "3d noplay noblock", function(snd, errnum, err)
                                if not snd or err then return end
                                processing = false
                                self.paused = true
                                self.obj = snd
                                snd:EnableLooping(sampler.Looping)
                                snd:SetVolume(wowozela.intvolume or 1)
                                snd:SetPlaybackRate((sampler.Pitch or 100) / 100)
                                snd:Set3DEnabled(sampler.Player ~= LocalPlayer())
                                callback()
                            end)
                        end
                    end
                end
                return rawget(self, index)
            end
        }

        return setmetatable({}, _smeta)
    end

    local function set_volume(snd, num, sampler)
        if not IsValid(snd.obj) then return end

        snd.obj:SetVolume(num * (wowozela.intvolume or 1))
        snd.obj:SetPos(sampler.Player:EyePos(), sampler.Player:GetAimVector())
    end

    local function set_pitch(snd, num, sampler)
        if not IsValid(snd.obj) then return end

        snd.obj:SetPlaybackRate(num / 100)
        snd.obj:SetPos(sampler.Player:EyePos(), sampler.Player:GetAimVector())
    end

    local function stop_sound(snd, sampler)
        if not IsValid(snd.obj) then return end
        if snd.paused then return end

        snd.obj:Pause()
        snd.obj:SetTime(0)
        snd.paused = true
    end

    local function play_sound(snd, sampler)
        if not IsValid(snd.obj) then return end
        if not snd.paused or wowozela.disabled then return end

        snd.obj:Play()
        snd.obj:SetPos(sampler.Player:EyePos(), sampler.Player:GetAimVector())

        snd.paused = false
    end

    function META:SetSample(i, ishttp, path)
        if self.Samples[i] and IsValid(self.Samples[i].obj) then
            self.Samples[i].obj:Stop()
            self.Samples[i].obj = nil
        end
        self.Samples[i] = create_sound(path or wowozela.DefaultSound, ishttp, self)
    end

    function META:SetPitch(num) -- ???
        num = num or 1

        if self:IsKeyDown(IN_WALK) then
            num = num - 7 / 12
        end

        local lastPitch = self.Pitch
        self.Pitch = math.Clamp(math.floor((100 * 2 ^ num) * 100) / 100, 0.01, 2048)
        if lastPitch ~= self.Pitch then
            for _, sample in pairs(self.Samples) do
                set_pitch(sample, self.Pitch, self)
            end
        end
    end

    function META:SetLooping(loop)
        local lastVal = self.Looping

        if lastVal ~= loop then
            self.Looping = loop
            for k,v in pairs(self.Samples) do
                if IsValid(v.obj) then
                    v.obj:EnableLooping(loop)
                    v.obj:SetTime(0)
                end
            end
        end
    end

    function META:SetVolume(num)
        local lastVol = self.Volume
        self.Volume = math.Clamp(num or self.Volume, 0.0001, 1)

        if lastVol ~= self.Volume then
            for _, sample in pairs(self.Samples) do
                set_volume(sample, self.Volume, self)
            end
        end
    end

    cvars.AddChangeCallback("wowozela_volume", function(cvar, oldval, newval)
        if oldval == newval then return end

        local vol = tonumber(newval) or 0.5
        wowozela.intvolume = math.Clamp(vol, 0, 1)
        wowozela.disabled = vol < 0.01

        for _, ply in ipairs(player.GetHumans()) do
            local sampler = wowozela.GetSampler(ply)

            if sampler and sampler.Samples then
                for _, sample in pairs(sampler.Samples) do
                    set_volume(sample, sampler.Volume, sampler)
                end
            end
        end
    end, "wowozela_ttt")

    function META:Start(sample_index, key)
        if not self:CanPlay() then
            return
        end

        local sample = self.Samples[sample_index]
        if not sample then
            return
        end

        if key then
            local previous_sample = self.KeyToSample[key]
            if previous_sample then
                stop_sound(previous_sample, self)
            end

            self.KeyToSample[key] = sample


            sample.create(function()
                if self.KeyToSample[key] == sample and IsValid(self.Player) then
                    play_sound(sample, self)
                end
            end)
        end
    end

    function META:Stop(sample_index, key)
        local sample = self.Samples[sample_index]
        if not sample then
            return
        end

        if sample == self.last_sample then return end
        if key then
            for k,v in pairs(self.KeyToSample) do
                if v == sample and key ~= k then

                    stop_sound(sample, self)
                    play_sound(sample, self)

                    self.KeyToSample[key] = nil
                    return
                end
            end

            local previous_sample = self.KeyToSample[key]
            if previous_sample then
                stop_sound(previous_sample, self)
                -- previous_sample:Stop() 
            end

            self.KeyToSample[key] = nil
        end

        if sample then
            -- sample:Stop()
            stop_sound(sample, self)
        end
    end

    function META:IsKeyDown(key)
        return self.Keys[key] == true
    end

    function META:OnKeyEvent(key, press)
        local id = self:KeyToSampleIndex(key)
        if id then
            if press then
                self:Start(id, key)
                self:SetVolume(1)
            else
                self:Stop(id, key)
            end
        end
    end
    function META:GetPlayerPitch()
        local ply = self.Player

        if ply.wowozela_real_pitch then
            return -(ply.wowozela_real_pitch / 90)
        end

        local pitch = self:GetAngles().p
        return -pitch / 89
    end

    function META:StopPlaying()
        if not self.WasPlaying then return end
        for _, csp in pairs(self.Samples) do
            if not csp.paused then
                stop_sound(csp, self)
            end
        end
        self.WasPlaying = nil
    end

    function META:Think()
        if not self:CanPlay() or wowozela.disabled then
            return
        end

        self.WasPlaying = true

        local wep = self.Player:GetActiveWeapon()
        local ang = self:GetAngles()
        local looping = IsValid(wep) and wep.GetLooping and wep:GetLooping()

        self:SetLooping(looping)

        if self:IsKeyDown(IN_USE) then
            if self.using_angle then
                self:SetVolume(math.abs(ang.y - self.using_angle) / 20)
            else
                self.using_angle = ang.y
            end
        else
            self.using_angle = false
            self:SetVolume(1)
        end

        self:SetPitch(self:GetPlayerPitch())

        if self:IsKeyDown(IN_ATTACK) or self:IsKeyDown(IN_ATTACK2) then
            self:MakeParticle()
        end
    end

    local emitter
    local function fade_in(p)
        local f = p:GetLifeTime()
        p:SetStartSize(p:GetRoll() * (f ^ 0.25))
        if f < 1 then
            p:SetNextThink(CurTime())
        end
    end

    function META:Destroy()
        for _,v in pairs(self.Samples) do
            if v.obj then
                v.obj:Stop()
                v.obj = nil
            end
        end

        self.Samples = {}
    end

    local partDist = 2048 * 2048
    function META:MakeParticle()
        if LocalPlayer() ~= self.Player and LocalPlayer():GetPos():DistToSqr(self:GetPos()) > partDist then
            return
        end

        local pitch = self.Pitch

        emitter = emitter or ParticleEmitter(Vector())

        local scale = self.Player:GetModelScale()

        local forward = self:GetAngles():Forward()

        local fft = {}
        for _, sample in pairs(self.KeyToSample) do
            if sample.obj then
                sample.obj:FFT(fft, 1)
            end
        end


        local avg = 0
        for i = 1, #fft do
            avg = avg + fft[i]
        end
        avg = avg / #fft
        local m = ((avg ^ 0.5) * 10)

        local particle = emitter:Add("particle/fire", self:GetPos() + forward * scale)


        if particle then
            local col = HSVToColor(pitch * 2.55, self.Volume, 1)
            particle:SetColor(col.r, col.g, col.b, self.Volume)

            particle:SetVelocity(self.Volume * self:GetAngles():Forward() * 500 * scale)
            particle:SetNextThink(CurTime())

            particle:SetDieTime(5)
            particle:SetLifeTime(0)
            particle:SetBounce(1)
            particle:SetCollide(true)

            particle:SetThinkFunction(fade_in)

            local size = ((-pitch + 255) / 250) + 1

            particle:SetAngles(AngleRand())

            local s = math.max(size * 2 * scale, 1) * m
            particle:SetStartSize(0)
            particle:SetEndSize(s)
            particle:SetRoll(s)

            particle:SetStartAlpha(255 * self.Volume)
            particle:SetEndAlpha(0)

            -- particle:SetRollDelta(math.Rand(-1,1)*20)
            particle:SetAirResistance(500)
            -- particle:SetGravity(Vector(math.Rand(-1,1), math.Rand(-1,1), math.Rand(-1, 1)) * 8 )
        end
    end

    wowozela.SamplerMeta = META

    function wowozela.CreateSampler(ply)
        if ply:IsBot() then return end -- bots are not permitted to play the wowozela

        local sampler = setmetatable({}, wowozela.SamplerMeta)
        sampler:Initialize(ply)

        wowozela.Samplers[ply:UserID()] = sampler
        return sampler
    end

    function wowozela.GetSampler(ply)
        return wowozela.Samplers[ply:UserID()]
    end
end

do -- hooks
    hook.Add("KeyPress", "wowozela_keypress", function(ply, key)
        if not IsFirstTimePredicted() and not game.SinglePlayer() then
            return
        end

        local wep = ply:GetActiveWeapon()
        if wep:IsValid() and wep:GetClass() == "ttt_wowozela" and wowozela.IsValidKey(key) then
            if SERVER and wep.OnKeyEvent then
                wowozela.BroadcastKeyEvent(ply, key, true)
                wep:OnKeyEvent(key, true)
            end

            if CLIENT then
                wowozela.KeyEvent(ply, key, true)
            end
        end
    end)

    hook.Add("KeyRelease", "wowozela_keyrelease", function(ply, key)
        if not IsFirstTimePredicted() and not game.SinglePlayer() then
            return
        end

        local wep = ply:GetActiveWeapon()
        if wep:IsValid() and wep:GetClass() == "ttt_wowozela" and wowozela.IsValidKey(key) then
            if SERVER and wep.OnKeyEvent then
                wowozela.BroadcastKeyEvent(ply, key, false)
                wep:OnKeyEvent(key, false)
            end

            if CLIENT then
                wowozela.KeyEvent(ply, key, false)
            end
        end
    end)

    if CLIENT then
        function wowozela.KeyEvent(ply, key, press)
            local sampler = wowozela.GetSampler(ply)
            if sampler then
                sampler.Keys[key] = press
                return sampler:OnKeyEvent(key, press)
            end
        end

        function wowozela.Think()
            for k, sampler in next, wowozela.Samplers do
                if sampler:CanPlay() then
                    sampler:Think()
                end
            end
        end

        function wowozela.SlowThink()
            if not wowozela.KnownSamples[1] then
                return
            end

            local vol = wowozela.volume:GetFloat()
            wowozela.intvolume = math.Clamp(vol, 0, 1)
            wowozela.disabled = vol < 0.01

            for _, ply in ipairs(player.GetHumans()) do
                if not wowozela.Samplers[ply:UserID()] then
                    wowozela.CreateSampler(ply)
                end
            end

            for k, sampler in next, wowozela.Samplers do
                if not IsValid(sampler.Player) then
                    sampler:Destroy()
                    wowozela.Samplers[k] = nil
                elseif not sampler:CanPlay() then
                    sampler:StopPlaying()
                end
            end
        end

        hook.Add("Think", "wowozela_think", wowozela.Think)
        timer.Create("WowozelaSlowThink", 0.5, 0, wowozela.SlowThink)
    else
        function wowozela.BroadcastKeyEvent(ply, key, press, filter)
            net.Start("wowozela_ttt", true)
            net.WriteInt(wowozela.NET.wowozela_key, 4)
            net.WriteEntity(ply)
            net.WriteInt(key, 32)
            net.WriteBool(press)
            if not filter then
                net.SendOmit(ply)
            else
                net.Broadcast()
            end
        end
    end
end

if CLIENT then
    for _, ply in ipairs(player.GetHumans()) do
        wowozela.CreateSampler(ply)
    end
end

if SERVER then
    timer.Simple(0.1, function()
        for _, ply in ipairs(player.GetHumans()) do
            wowozela.BroacastSamples(ply)
        end
    end)
end


---------------------------------------------
-- https://github.com/Metastruct/gurl/     --
---------------------------------------------
local URLWhiteList = {}

local TYPE_SIMPLE = 1
local TYPE_PATTERN = 2
local TYPE_BLACKLIST = 4

local function pattern(pattern)
  URLWhiteList[#URLWhiteList + 1] = {TYPE_PATTERN, "^http[s]?://" .. pattern}
end
local function simple(txt)
  URLWhiteList[#URLWhiteList + 1] = {TYPE_SIMPLE, "^http[s]?://" .. txt}
end
local function blacklist(txt)
  URLWhiteList[#URLWhiteList + 1] = {TYPE_BLACKLIST, txt}
end


simple [[www.dropbox.com/s/]]
simple [[dl.dropboxusercontent.com/]]
simple [[dl.dropbox.com/]] --Sometimes redirects to usercontent link

-- OneDrive
-- Examples: 
-- https://onedrive.live.com/redir?resid=123!178&authkey=!gweg&v=3&ithint=abcd%2cefg

simple [[onedrive.live.com/redir]]

-- Google Drive
--- Examples: 
---  https://docs.google.com/uc?export=download&confirm=UYyi&id=0BxUpZqVaDxVPeENDM1RtZDRvaTA

simple [[docs.google.com/uc]]
simple [[drive.google.com/file/d/]]
simple [[drive.google.com/u/0/uc]]
simple [[drive.google.com/open]]

--[=[
-- Imgur
--- Examples: 
---  http://i.imgur.com/abcd123.xxx

simple [[i.imgur.com/]]


-- pastebin
--- Examples: 
---  http://pastebin.com/abcdef

simple [[pastebin.com/]]
]=]

-- github / gist
--- Examples: 
---  https://gist.githubusercontent.com/LUModder/f2b1c0c9bf98224f9679/raw/5644006aae8f0a8b930ac312324f46dd43839189/sh_sbdc.lua
---  https://raw.githubusercontent.com/LUModder/FWP/master/weapon_template.txt

simple [[raw.githubusercontent.com/]]
simple [[gist.githubusercontent.com/]]
simple [[github.com/]]
simple [[www.github.com/]]

-- pomf
-- note: there are a lot of forks of pomf so there are tons of sites. I only listed the mainly used ones. --Flex
--- Examples: 
---  https://my.mixtape.moe/gxiznr.png
---  http://a.1339.cf/fppyhby.txt
---  http://b.1339.cf/fppyhby.txt
---  http://a.pomf.cat/jefjtb.txt

simple [[my.mixtape.moe/]]
simple [[a.1339.cf/]]
simple [[b.1339.cf/]]
simple [[a.pomf.cat/]]

--[=[
-- TinyPic
--- Examples: 
---  http://i68.tinypic.com/24b3was.gif
pattern [[i(.+)%.tinypic%.com/]]


-- paste.ee
--- Examples: 
---  https://paste.ee/r/J3jle
simple [[paste.ee/]]


-- hastebin
--- Examples: 
---  http://hastebin.com/icuvacogig.txt
simple [[hastebin.com/]]
]=]

-- puush
--- Examples:
---  http://puu.sh/asd/qwe.obj
simple [[puu.sh/]]

-- Steam
--- Examples:
---  http://images.akamai.steamusercontent.com/ugc/367407720941694853/74457889F41A19BD66800C71663E9077FA440664/
---  https://steamcdn-a.akamaihd.net/steamcommunity/public/images/apps/4000/dca12980667e32ab072d79f5dbe91884056a03a2.jpg
simple [[images.akamai.steamusercontent.com/]]
simple [[steamcdn-a.akamaihd.net/]]
simple [[steamcommunity.com/]]
simple [[www.steamcommunity.com/]]
simple [[store.steampowered.com/]]
blacklist [[steamcommunity.com/linkfilter/]]
blacklist [[www.steamcommunity.com/linkfilter/]]

---------------------------------------------
-- https://github.com/thegrb93/StarfallEx/ --
---------------------------------------------

-- Discord
--- Examples:
---  https://cdn.discordapp.com/attachments/269175189382758400/421572398689550338/unknown.png
---  https://images-ext-2.discordapp.net/external/UVPTeOLUWSiDXGwwtZ68cofxU1uaA2vMb2ZCjRY8XXU/https/i.imgur.com/j0QGfKN.jpg?width=1202&height=677

pattern [[cdn[%w-_]*.discordapp%.com/(.+)]]
pattern [[images-([%w%-]+)%.discordapp%.net/external/(.+)]]

-- Reddit
--- Examples:
---  https://i.redd.it/u46wumt13an01.jpg
---  https://i.redditmedia.com/RowF7of6hQJAdnJPfgsA-o7ioo_uUzhwX96bPmnLo0I.jpg?w=320&s=116b72a949b6e4b8ac6c42487ffb9ad2
---  https://preview.redd.it/injjlk3t6lb51.jpg?width=640&height=800&crop=smart&auto=webp&s=19261cc37b68ae0216bb855f8d4a77ef92b76937

simple [[i.redditmedia.com]]
simple [[i.redd.it]]
simple [[preview.redd.it]]
--[=[
-- Furry things
--- Examples:
--- https://static1.e621.net/data/8f/db/8fdbc9af34698d470c90ca6cb69c5529.jpg

simple [[static1.e621.net]]
]=]
-- ipfs
--- Examples:
--- https://ipfs.io/ipfs/QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco/I/m/Ellis_Sigil.jpg

simple [[ipfs.io]]
simple [[www.ipfs.io]]

-- neocities
--- Examples:
--- https://fauux.neocities.org/LainDressSlow.gif

pattern [[([%w-_]+)%.neocities%.org/(.+)]]

--[=[
-- Soundcloud
--- Examples:
--- https://i1.sndcdn.com/artworks-000046176006-0xtkjy-large.jpg
pattern [[(%w+)%.sndcdn%.com/(.+)]]

-- Shoutcast
--- Examples:
--- http://yp.shoutcast.com/sbin/tunein-station.pls?id=567807
simple [[yp.shoutcast.com]]

-- Google Translate API
--- Examples:
--- http://translate.google.com/translate_tts?&q=Hello%20World&ie=utf-8&client=tw-ob&tl=en
simple [[translate.google.com]]
]=]


-- END OF SHARED --

-- Vocaroo
--- Examples:
--- https://media1.vocaroo.com/mp3/1mO2ie6J4r3O
--- http://vocaroo.com/16aWnwy2hwVH
pattern [[media%d.vocaroo.com/mp3/]]
simple [[vocaroo.com/]]


function wowozela.URLWhitelist(url)
    local out = 0x000
    for _, testPattern in pairs(URLWhiteList) do
        if testPattern[1] == TYPE_SIMPLE then
            if string.find(url, testPattern[2]) then
                out = bit.bor(out, TYPE_SIMPLE)
            end
        elseif testPattern[1] == TYPE_PATTERN then
            if string.match(url, testPattern[2]) then
                out = bit.bor(out, TYPE_PATTERN)
            end
        elseif testPattern[1] == TYPE_BLACKLIST then
            if string.find(url, testPattern[2]) then
                out = bit.bor(out, TYPE_BLACKLIST)
            end
        end
    end

    if bit.band(out, TYPE_BLACKLIST) == TYPE_BLACKLIST then return false end
    if bit.band(out, TYPE_SIMPLE) == TYPE_SIMPLE or bit.band(out, TYPE_PATTERN) == TYPE_PATTERN then return true end
    return false
end
