-- ============================================================================
-- VANTA 5.0 · Crimson Obsidian
-- Target: Universal Mobile Environment (Delta / Codex / Arceus X)
-- Compiler: Luau VM
-- ============================================================================

local VANTA = (function()
    local Players = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    local CoreGui = game:GetService("CoreGui")
    local RunService = game:GetService("RunService")
    local Stats = game:GetService("Stats")
    local MarketplaceService = game:GetService("MarketplaceService")
    local LocalizationService = game:GetService("LocalizationService")

    local LocalPlayer = Players.LocalPlayer

    -- Destroi a instancia anterior (GUI, loops e drawings) ao reexecutar
    local env = (getgenv and getgenv()) or _G
    if env.VANTA_INSTANCE then
        pcall(function() env.VANTA_INSTANCE:Destroy() end)
    end

    local Library = {}
    Library.Connections = {}
    Library.Drawings = {}
    Library.Tabs = {}
    Library.Destroyed = false
    Library.ThemeObservers = {}

    local Theme = {
        Background = Color3.fromRGB(13, 13, 17),
        Surface = Color3.fromRGB(20, 20, 26),
        Surface2 = Color3.fromRGB(28, 28, 36),
        Surface3 = Color3.fromRGB(38, 38, 48),
        Accent = Color3.fromRGB(190, 35, 55),
        Accent2 = Color3.fromRGB(240, 80, 100),
        AccentDark = Color3.fromRGB(115, 20, 35),
        Text = Color3.fromRGB(240, 240, 245),
        Muted = Color3.fromRGB(135, 135, 150),
        Border = Color3.fromRGB(46, 42, 54),
        Success = Color3.fromRGB(70, 190, 120),
        Danger = Color3.fromRGB(235, 80, 90),
    }
    Library.Theme = Theme

    -- ------------------------------------------------------------------
    -- Utilitarios
    -- ------------------------------------------------------------------
    local function Connect(signal, callback)
        local connection = signal:Connect(callback)
        table.insert(Library.Connections, connection)
        return connection
    end

    local function TrackDrawing(drawing)
        table.insert(Library.Drawings, drawing)
        return drawing
    end

    local function UntrackDrawing(drawing)
        for index, value in ipairs(Library.Drawings) do
            if value == drawing then
                table.remove(Library.Drawings, index)
                return
            end
        end
    end

    local HttpService = game:GetService("HttpService")
    local palette = {
        ["Crimson Obsidian"] = {0x101016, 0xB73350, 0x643044, 0xF17C91},
        ["Midnight Blue"] = {0x0B111D, 0x3B69B2, 0x253C6A, 0xA5C9FF},
        Emerald = {0x0B1513, 0x217C61, 0x24584B, 0x8BE9C2},
        Amethyst = {0x100C19, 0x8849CD, 0x51277D, 0xC898FF},
        Cyberpunk = {0x0A141C, 0x188B9C, 0x683458, 0xF7ADE4},
        ["Pure Black"] = {0x000000, 0x53535F, 0x32323A, 0xD1D1DB},
        Arctic = {0x17212A, 0x426C86, 0x40586D, 0xBDE9FF},
    }
    local themeNames = {"Crimson Obsidian", "Midnight Blue", "Emerald", "Amethyst", "Cyberpunk", "Pure Black", "Arctic"}
    local defaults = {
        theme = "Amethyst", primary = "", secondary = "", highlight = "",
        scale = 100, transparency = 0, density = "Confortável", animations = true,
        reduced = false, lowPower = false, diagnostics = true, avatar = true,
        notifications = true, notificationSeconds = 0, floatSize = 52, floatSide = "Esquerda", floatOpacity = 100, aimSize = 60, aimOpacity = 100,
        refreshSeconds = 1, keybind = "RightShift", autoPlaceProfile = true, safeAimStartup = true,
    }
    local settings = table.clone(defaults)
    local bindings = {}
    local function Bind(object, property, resolver)
        bindings[object] = bindings[object] or {}
        bindings[object][property] = resolver
        object[property] = resolver()
    end

    local function Hex(value)
        if type(value) ~= "string" then return nil end
        local digits = value:match("^#?(%x%x%x%x%x%x)$")
        return digits and digits:upper()
    end

    local function Color(value)
        return Color3.fromRGB(math.floor(value / 65536), math.floor(value / 256) % 256, value % 256)
    end

    local function ResolvePalette()
        local values = palette[settings.theme]
        local background = Color(values[1])
        local white = Color3.new(1, 1, 1)
        Theme.Background = background
        Theme.Surface = background:Lerp(white, 0.035)
        Theme.Surface2 = background:Lerp(white, 0.07)
        Theme.Surface3 = background:Lerp(white, 0.12)
        Theme.Border = background:Lerp(white, 0.2)
        Theme.Accent = Color(tonumber(settings.primary, 16) or values[2])
        Theme.AccentDark = Color(tonumber(settings.secondary, 16) or values[3])
        Theme.Accent2 = Color(tonumber(settings.highlight, 16) or values[4])
        Theme.Muted = background:Lerp(white, 0.60)
        Theme.Icon = background:Lerp(white, 0.76)
        Theme.Focus = Theme.Accent2:Lerp(white, 0.34)
        Theme.Success = Color(0x66D5A0):Lerp(Theme.Accent2, 0.15)
        Theme.Danger = Color(0xFF8096):Lerp(Theme.Accent2, 0.15)
    end

    local registered = {}
    ResolvePalette()

    local function ValidateOption(key, value)
        local default = defaults[key]
        if type(value) ~= type(default) then return nil end
        if key == "theme" then return palette[value] and value end
        if key == "primary" or key == "secondary" or key == "highlight" then
            return value == "" and "" or Hex(value)
        end
        if key == "density" then return (value == "Compacta" or value == "Confortável") and value end
        if key == "floatSide" then return (value == "Esquerda" or value == "Direita") and value end
        if key == "keybind" then
            local ok, item = pcall(function() return Enum.KeyCode[value] end)
            return ok and item and item ~= Enum.KeyCode.Unknown and value or nil
        end
        local control = registered[key]
        if control then return control.Validate(value) end
        if type(default) == "boolean" then return value end
        return nil
    end

    local function ProfileName(value)
        return type(value) == "string" and #value <= 32 and value:match("^[%w][%w _%-]*$") and value
    end

    local function Decode(raw)
        if type(raw) ~= "string" or #raw > 65536 then return nil end
        local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
        return ok and type(decoded) == "table" and decoded or nil
    end

    local function ValidateProfile(data, strict)
        if type(data) ~= "table" or type(data.values) ~= "table" then return nil end
        local profile = {values = {}}
        for key, value in pairs(data.values) do
            local clean
            if defaults[key] ~= nil then clean = ValidateOption(key, value)
            elseif registered[key] then clean = registered[key].Validate(value) end
            if clean ~= nil then profile.values[key] = clean
            elseif strict then return nil end
        end
        return profile
    end

    local profiles = {Padrao = {values = {}}}
    local activeProfile = "Padrao"
    local placeProfiles = {}
    local placeKey = game.PlaceId and game.PlaceId > 0 and tostring(game.PlaceId) or nil
    local revision, slot = 0, 2
    local filesAvailable = type(readfile) == "function" and type(writefile) == "function"
    local dirty, saving, loading = false, false, false
    local status = filesAvailable and "Armazenamento disponível" or "Somente memória nesta sessão"
    local function SlotPath(index)
        return "VANTA5-profiles-" .. index .. ".json"
    end

    local function ReadSlot(index)
        local ok, raw = pcall(readfile, SlotPath(index))
        local data = ok and Decode(raw)
        if not data or data.schema ~= 1 or type(data.profiles) ~= "table" then return nil end
        local rev = data.revision
        if type(rev) ~= "number" or rev < 1 or rev >= 2^53 or rev % 1 ~= 0 then return nil end
        local result, count = {}, 0
        for name, profile in pairs(data.profiles) do
            count = count + 1
            if count > 16 or not ProfileName(name) then return nil end
            result[name] = ValidateProfile(profile, true)
            if not result[name] then return nil end
        end
        if not ProfileName(data.active) or not result[data.active] then return nil end
        local associations, placeCount = {}, 0
        if type(data.places) == "table" then
            for id, name in pairs(data.places) do
                if placeCount < 64 and type(id) == "string" and id:match("^[1-9]%d*$")
                    and #id <= 20 and type(name) == "string" and result[name] then
                    associations[id], placeCount = name, placeCount + 1
                end
            end
        end
        return {revision = rev, profiles = result, active = data.active, places = associations,
            autoPlace = data.autoPlace ~= false}
    end

    local function Snapshot()
        local values = table.clone(settings)
        for key, control in pairs(registered) do values[key] = control.Get() end
        return {values = values}
    end

    local function Flush()
        if not dirty then return end
        profiles[activeProfile] = Snapshot()
        dirty = false
        if not filesAvailable then return end
        local nextSlot = 3 - slot
        local ok, encoded = pcall(HttpService.JSONEncode, HttpService, {
            schema = 1, revision = revision + 1, active = activeProfile, profiles = profiles,
            places = placeProfiles, autoPlace = settings.autoPlaceProfile,
        })
        if ok then
            ok = pcall(writefile, SlotPath(nextSlot), encoded)
            if ok then
                local readOk, roundTrip = pcall(readfile, SlotPath(nextSlot))
                ok = readOk and roundTrip == encoded
            end
        end
        if ok then
            revision, slot = revision + 1, nextSlot
            status = "Perfis salvos no dispositivo"
        else
            status = "Falha na gravação · alterações em memória"
        end
    end

    local function Changed()
        if loading then return end
        dirty = true
        if saving then return end
        saving = true
        task.delay(0.6, function()
            saving = false
            if not Library.Destroyed then
                Flush()
                if Library.RefreshProfileStatus then Library.RefreshProfileStatus() end
            end
        end)
    end

    local function Register(options, control, validate)
        if not options.Key then return end
        assert(not registered[options.Key], "Chave de configuração duplicada: " .. options.Key)
        local original = options.Callback
        options.Callback = function(value)
            if original then original(value) end
            Changed()
        end
        registered[options.Key] = {
            Get = function() return control:Get() end,
            Set = function(value) control:Set(value, options.PassiveRestore) end,
            Default = control:Get(),
            Validate = validate,
        }
    end

    local activeTweens = {}
    local function Tween(object, properties, duration, style, direction)
        local previous = activeTweens[object]
        if previous then
            for property in pairs(properties) do
                local tween = previous[property]
                if tween then tween:Cancel() end
            end
        end
        if not settings.animations or settings.reduced or settings.lowPower then
            for property, value in pairs(properties) do object[property] = value end
            return
        end
        local tween = TweenService:Create(
            object,
            TweenInfo.new(duration or 0.2, style or Enum.EasingStyle.Quart, direction or Enum.EasingDirection.Out),
            properties
        )
        local running = activeTweens[object] or {}
        activeTweens[object] = running
        for property in pairs(properties) do running[property] = tween end
        tween.Completed:Once(function()
            for property in pairs(properties) do
                if running[property] == tween then running[property] = nil end
            end
            if not next(running) and activeTweens[object] == running then activeTweens[object] = nil end
            tween:Destroy()
        end)
        tween:Play()
    end

    local function Create(className, properties, parent)
        local object = Instance.new(className)
        for property, value in pairs(properties or {}) do
            if type(value) == "string" and value:sub(1, 1) == "@" and Theme[value:sub(2)] and property:find("Color") then
                local role = value:sub(2)
                Bind(object, property, function() return Theme[role] end)
            else
                object[property] = value
            end
        end
        object.Parent = parent
        return object
    end

    local function Corner(parent, radius)
        return Create("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, parent)
    end

    local function Stroke(parent, color, transparency, thickness)
        return Create("UIStroke", {
            Color = color or "@Border",
            Transparency = transparency or 0,
            Thickness = thickness or 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        }, parent)
    end

    local function Padding(parent, left, right, top, bottom)
        return Create("UIPadding", {
            PaddingLeft = UDim.new(0, left or 0),
            PaddingRight = UDim.new(0, right or 0),
            PaddingTop = UDim.new(0, top or 0),
            PaddingBottom = UDim.new(0, bottom or 0)
        }, parent)
    end

    local function Gradient(parent, color0, color1, rotation)
        local gradient = Create("UIGradient", {Rotation = rotation or 90}, parent)
        Bind(gradient, "Color", function()
            return ColorSequence.new(Theme[color0], Theme[color1])
        end)
        return gradient
    end

    local function Text(parent, properties)
        properties.BackgroundTransparency = 1
        properties.Font = properties.Font or Enum.Font.Gotham
        properties.TextSize = properties.TextSize or 12
        properties.TextColor3 = properties.TextColor3 or "@Text"
        properties.TextXAlignment = properties.TextXAlignment or Enum.TextXAlignment.Left
        return Create("TextLabel", properties, parent)
    end

    -- efeito de clique (encolhe levemente)
    -- Banner incorporado, exibido no dashboard.
    local atlasRegions = {banner = {0, 0, 320, 118}}
    local function LoadAtlas()
        local customAsset = type(getcustomasset) == "function" and getcustomasset or getsynasset
        if type(customAsset) ~= "function" then return nil end
        local path = "VantaHub-ui-banner-v2.png"
        if type(isfile) == "function" then
            local exists, cached = pcall(isfile, path)
            if exists and cached then
                local ok, uri = pcall(customAsset, path)
                if ok and type(uri) == "string" and uri ~= "" then return uri end
            end
        end
        if type(writefile) ~= "function" then return nil end

        local encoded = [=[
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
pSGiZzl6oqX3Vedn7LB+SwnP9b+XQKCmB+Z31L0US+AXWHKLM5NBbIOSeHbj8vlc/KgHfw/MMskNVLEAqbPaFSsiuGPNx5L4QAfVl/TomKV1m7pgk71US7BZ
gxUVSGVcm9qmgtZNiRFkcDITTtv/jt7MrE8h3Yb1j/VD+1XewCYBflCzmziaXO/O8DkOjL9wdPdHBG5akwX1e6ZhM4dD5il3a8s/51eZ3PJB/mec/JdJmb/f
PZNNfQwoy81I1vug+qPBT2hcrNnSt+BZb/m8PJOYqZwQcItV+yv6Yn883G8JvJgE846ykJlZG88FddBlM/Qs2A529LSwaq9nxrU6g+jxETCxbkXNt/VGls0r
bmMOJWIcwvZG7ehAPjC6pNZaO23i+N2x9ciil2o4xiSrOEk32YID8xy7WZhX8vxlA3xBv8955rNoDArpet3DneUNfI2X1GdS6A0q4eYb7HI17OVbDno39apk
e+NclWdYcKb/LPgNrtvMfEbD/6KfmrBoXuGfjR4JHGAWo+OL5JiFlnbV/jK/l9V036/Zf8SLo/u9yD/j+aze1L3TMiX7Ddd23LDXdFzjO1qPjoW/10f1l7yk
N+w6mdex8IqzMHEtPiDL6Zxal9S6lIrXgfauvCO7V+yw4Jpv7v68Ld/WHdmR54eHDVhryqbFfq74S2ySk/5QKs5zi9/S1jQm2bPMxlbeUFS8nD3YvNT2uKTc
0FrnN7ctfKa4RGRqwf+bc4ob/FP9I3lvb6i5xfP8Jl/QLa6IM6Lsc1MwK17wNV5kL7O0NfZKEe4Rzzzf/ZfmP5A/3wPqFt8D4Mvd3y3+EpdwYL7Fkq/yOa7J
JX3c08Ilw3Jk4ritesZbZEw4gi8uhH3Z3jbnON1zqX1dmlq3tJKamsqPRO1ly329buskZUnNod70eZeGyVOiArKpO1Tc5DbHRpPW1CL/MwvZlV3ZklJmpY+J
uVi8kz2+oS0xM3S+MLPlnNnidhIg72WoEi7qLs+4AJ6Y3CYkC7Iw40PFj/M9v2VECr6Ks7yRT/J15/sYI99s2D9bLHlW4lsR9F9tN8zt4SXJSxqotmHLmERT
OTR2zRu2bS7IAqi5KTe9MWLbC1utqS0Ws2Fnvt1DazNX2AaFD7M9zDctYMtssyV3Re0hR/YIv8bInLMXxNnObuhta3Ap3d0Y1nYi4sm4aCifjb4HYLQDJGkn
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
]=]
        encoded = encoded:gsub("%s", "")
        local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        local decode = {["="] = 0}
        for index = 1, #alphabet do decode[alphabet:sub(index, index)] = index - 1 end
        local bytes = {}
        for a, b, c, d in encoded:gmatch("(.)(.)(.)(.)") do
            local value = decode[a] * 262144 + decode[b] * 4096 + decode[c] * 64 + decode[d]
            local first, second, third = math.floor(value / 65536), math.floor(value / 256) % 256, value % 256
            if c == "=" then
                bytes[#bytes + 1] = string.char(first)
            elseif d == "=" then
                bytes[#bytes + 1] = string.char(first, second)
            else
                bytes[#bytes + 1] = string.char(first, second, third)
            end
        end
        if not pcall(writefile, path, table.concat(bytes)) then return nil end
        local ok, uri = pcall(customAsset, path)
        return ok and type(uri) == "string" and uri ~= "" and uri or nil
    end

    local assetUri = LoadAtlas()
    local function Art(parent, key, size, position, fallback, zIndex)
        local region = atlasRegions[key]
        if not assetUri or not region then return nil end
        local image = Create("ImageLabel", {
            Name = "VantaArt_" .. key, BackgroundTransparency = 1,
            Position = position, Size = size, Image = assetUri,
            ImageRectOffset = Vector2.new(region[1], region[2]),
            ImageRectSize = Vector2.new(region[3], region[4]),
            ScaleType = Enum.ScaleType.Fit, ZIndex = zIndex or 3, Visible = false,
        }, parent)
        Bind(image, "ImageColor3", function()
            return Theme.Accent2:Lerp(Theme.Text, key == "banner" and 0.22 or 0.35)
        end)
        local function RefreshImage()
            image.Visible = image.IsLoaded
            if fallback then fallback.Visible = not image.IsLoaded end
        end
        Connect(image:GetPropertyChangedSignal("IsLoaded"), RefreshImage)
        RefreshImage()
        return image
    end

    local function Glow(parent, role, intensity, rotation)
        local gradient = Create("UIGradient", {Rotation = rotation}, parent)
        Bind(gradient, "Color", function()
            local strength = (settings.reduced or settings.lowPower) and intensity * 0.4 or intensity
            return ColorSequence.new({
                ColorSequenceKeypoint.new(0, Theme.Surface2:Lerp(Theme[role], strength)),
                ColorSequenceKeypoint.new(0.46, Theme.Surface:Lerp(Theme[role], strength * 0.25)),
                ColorSequenceKeypoint.new(1, Theme.Background),
            })
        end)
    end

    -- Os traços usam coordenadas de 24 unidades para manter nitidez em qualquer escala.
    local glyphPaths = {
        home = {{3,11,12,4,21,11}, {6,10,6,20,10,20,10,15,14,15,14,20,18,20,18,10}},
        aim = {{12,2,12,7}, {12,17,12,22}, {2,12,7,12}, {17,12,22,12}},
        silent = {{3,8,3,4,7,4}, {17,4,21,4,21,8}, {21,16,21,20,17,20}, {7,20,3,20,3,16},
            {5,19,19,5}},
        kill = {{12,2,22,12,12,22,2,12,12,2}, {9,12,15,12}, {12,9,12,15}},
        eye = {{2,12,6,8,12,6,18,8,22,12,18,16,12,18,6,16,2,12}},
        settings = {{9,3,15,3,16,6,19,6,22,11,20,13,20,16,17,20,14,19,12,22,8,20,8,17,
            4,17,2,12,5,10,4,7,8,5,9,3}},
        close = {{6,6,18,18}, {18,6,6,18}},
        grip = {{5,8,19,8}, {5,12,19,12}, {5,16,19,16}},
        brand = {{3,4,8,6,12,15,16,6,21,4,12,21,3,4}, {8,6,12,12,16,6}},
    }
    local glyphRings = {aim = 15, eye = 7, settings = 7, silent = 9}
    local function Glyph(parent, name, size, position, role, zIndex)
        local frame = Create("Frame", {
            Name = "Glyph_" .. name, Size = size, Position = position,
            BackgroundTransparency = 1, ZIndex = zIndex or 4,
        }, parent)
        local colorRole = role
        local function ResolveColor() return Theme[colorRole] end
        local primitives = {}
        local function Paint(object, property)
            Bind(object, property, ResolveColor)
            table.insert(primitives, {object, property})
        end
        for _, path in ipairs(glyphPaths[name] or glyphPaths.brand) do
            for index = 1, #path - 3, 2 do
                local x1, y1, x2, y2 = path[index], path[index + 1], path[index + 2], path[index + 3]
                local dx, dy = x2 - x1, y2 - y1
                local line = Create("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale((x1 + x2) / 48, (y1 + y2) / 48),
                    Size = UDim2.fromScale((math.sqrt(dx * dx + dy * dy) + 0.9) / 24, 1.7 / 24),
                    Rotation = math.deg(math.atan2(dy, dx)), BorderSizePixel = 0, ZIndex = frame.ZIndex,
                }, frame)
                Corner(line, 5)
                Paint(line, "BackgroundColor3")
            end
        end
        if glyphRings[name] then
            local ringSize = glyphRings[name] / 24
            local ring = Create("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromScale(ringSize, ringSize), BackgroundTransparency = 1, ZIndex = frame.ZIndex,
            }, frame)
            Create("UICorner", {CornerRadius = UDim.new(0.5, 0)}, ring)
            Paint(Stroke(ring, nil, 0, 1.5), "Color")
        end
        local function SetRole(newRole)
            if newRole == colorRole then return end
            colorRole = newRole
            for _, part in ipairs(primitives) do
                Tween(part[1], {[part[2]] = ResolveColor()}, 0.12)
            end
        end
        return frame, SetRole
    end

    local function AddPress(button)
        local scale = Create("UIScale", { Scale = 1 }, button)
        Connect(button.MouseButton1Down, function() Tween(scale, { Scale = 0.96 }, 0.08) end)
        Connect(button.MouseButton1Up, function() Tween(scale, { Scale = 1 }, 0.18, Enum.EasingStyle.Back) end)
        Connect(button.MouseLeave, function() Tween(scale, { Scale = 1 }, 0.12) end)
    end

    local function Hover(button, normal, hovered)
        local inside = false
        local function Resolve() return Theme[inside and hovered or normal] end
        Bind(button, "BackgroundColor3", Resolve)
        Connect(button.MouseEnter, function()
            inside = true
            Tween(button, {BackgroundColor3 = Resolve()}, 0.15)
        end)
        Connect(button.MouseLeave, function()
            inside = false
            Tween(button, {BackgroundColor3 = Resolve()}, 0.15)
        end)
    end

    local function ExecutorName()
        local name = "Desconhecido"
        pcall(function()
            if identifyexecutor then name = tostring((identifyexecutor())) end
        end)
        return name
    end

    local function LoadAvatar(imageLabel)
        task.spawn(function()
            local ok, content = pcall(function()
                return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
            end)
            if ok and content and imageLabel.Parent then imageLabel.Image = content end
        end)
    end

    -- ------------------------------------------------------------------
    -- ScreenGui
    -- ------------------------------------------------------------------
    local ScreenGui = Create("ScreenGui", {
        Name = "VANTA_RONIX",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 999,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    })

    local parented = pcall(function()
        if type(gethui) == "function" then
            ScreenGui.Parent = gethui()
        else
            ScreenGui.Parent = CoreGui
        end
    end)
    if not parented or not ScreenGui.Parent then
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
    Library.ScreenGui = ScreenGui

    -- Janela adaptativa com contorno temático e fade
    local Root = Create("Frame", {
        Name = "Root",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(640, 380),
        BackgroundTransparency = 1,
        Visible = false
    }, ScreenGui)
    local FitScale = Create("UIScale", { Scale = 1 }, Root)
    Corner(Root, 12)

    local RootStroke = Create("UIStroke", {
        Thickness = 1.5,
        Color = Color3.new(1, 1, 1),
        Transparency = 0.3,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    }, Root)
    local StrokeGradient = Create("UIGradient", {Rotation = 35}, RootStroke)
    Bind(StrokeGradient, "Color", function()
        return ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.Accent2),
            ColorSequenceKeypoint.new(0.4, Theme.Border),
            ColorSequenceKeypoint.new(1, Theme.Accent),
        })
    end)
    for index = 1, 3 do
        local shadow = Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, index * 2),
            Size = UDim2.new(1, index * 4, 1, index * 4), ZIndex = 1,
            BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.87,
        }, Root)
        Corner(shadow, 12)
    end

    local Main = Create("CanvasGroup", {
        Name = "Main",
        ZIndex = 2,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        GroupTransparency = 1
    }, Root)
    Corner(Main, 12)
    local MainBackground = Create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 1
    }, Main)
    Glow(MainBackground, "AccentDark", 0.32, 120)
    local IntroScale = Create("UIScale", { Scale = 0.94 }, Main)
    Library.Main = Main

    -- escala adaptativa a tela (rebind quando a camera mudar)
    local viewportConnection
    local updateDashboardLayout
    local function UpdateScale()
        local camera = workspace.CurrentCamera
        if not camera then return end
        local viewport = ScreenGui.AbsoluteSize
        if viewport.X <= 0 or viewport.Y <= 0 then viewport = camera.ViewportSize end
        local targetScale = settings.scale / 100
        local width = math.clamp((viewport.X - 24) / targetScale, 290, 760)
        local height = math.clamp((viewport.Y - 24) / targetScale, 355, 540)
        Root.Size = UDim2.fromOffset(width, height)
        FitScale.Scale = math.max(0.1, math.min(targetScale, (viewport.X - 12) / width, (viewport.Y - 12) / height))
        if updateDashboardLayout then updateDashboardLayout(width < 560, height) end
    end
    local function BindCamera()
        if viewportConnection then viewportConnection:Disconnect() viewportConnection = nil end
        local camera = workspace.CurrentCamera
        if camera then
            viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
                Root.Position = UDim2.fromScale(0.5, 0.5)
                UpdateScale()
            end)
        end
        Root.Position = UDim2.fromScale(0.5, 0.5)
        UpdateScale()
    end
    BindCamera()
    Connect(workspace:GetPropertyChangedSignal("CurrentCamera"), BindCamera)
    table.insert(Library.Connections, {
        Disconnect = function() if viewportConnection then viewportConnection:Disconnect() end end
    })

    -- ------------------------------------------------------------------
    -- Topbar
    -- ------------------------------------------------------------------
    local Topbar = Create("Frame", {
        Name = "Topbar",
        Active = true,
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = "@Surface",
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0
    }, Main)
    Create("Frame", {
        Position = UDim2.new(0, 0, 1, -1),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = "@Border",
        BorderSizePixel = 0
    }, Topbar)

    local HeaderLine = Create("Frame", {
        Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(0.55, 0, 0, 1),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2,
    }, Topbar)
    Gradient(HeaderLine, "Accent2", "Border", 0)

    local Logo = Create("Frame", {
        Position = UDim2.fromOffset(10, 4), Size = UDim2.fromOffset(34, 34),
        BackgroundColor3 = "@Surface3", BorderSizePixel = 0,
    }, Topbar)
    Corner(Logo, 8)
    Stroke(Logo, "@Accent", 0.28)
    Glyph(Logo, "brand", UDim2.fromOffset(24, 24), UDim2.fromOffset(5, 5), "Focus", 4)

    local TitleLabel = Text(Topbar, {
        Position = UDim2.fromOffset(48, 0),
        Size = UDim2.new(1, -238, 1, 0),
        RichText = true,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = "VANTA HUB  /  5.0"
    })

    task.spawn(function()
        local ok, info = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
        if ok and info and info.Name and TitleLabel.Parent then
            local safe = string.gsub(tostring(info.Name), "[<>&]", "")
            TitleLabel.Text = "VANTA HUB  /  " .. safe
        end
    end)

    local function TopButton(glyph, xOffset)
        local button = Create("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, xOffset, 0.5, 0),
            Size = UDim2.fromOffset(28, 28),
            BackgroundColor3 = "@Surface2",
            Text = glyph,
            TextColor3 = "@Text",
            TextSize = 16,
            Font = Enum.Font.GothamBold,
            AutoButtonColor = false
        }, Topbar)
        Corner(button, 8)
        Hover(button, "Surface2", "Surface3")
        AddPress(button)
        return button
    end
    local MinButton = TopButton("–", -46)
    local CloseButton = TopButton("", -12)
    Glyph(CloseButton, "close", UDim2.fromOffset(18, 18), UDim2.fromOffset(5, 5), "Icon", 4)

    -- arrastar a janela (corrigido para UIScale)
    local dragging = false
    local dragStart, startPosition
    Connect(Topbar.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then return end
            dragging = input
            dragStart = input.Position
            startPosition = Root.Position
        end
    end)
    Connect(UserInputService.InputChanged, function(input)
        if not dragging then return end
        if input == dragging or (dragging.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - dragStart
            local camera = workspace.CurrentCamera
            local viewport = camera and camera.ViewportSize or Vector2.new(800, 400)
            local size = Root.AbsoluteSize
            local horizontal = math.max(0, (viewport.X - size.X) / 2)
            local vertical = math.max(0, (viewport.Y - size.Y) / 2)
            local x = math.clamp(startPosition.X.Offset + delta.X, -horizontal, horizontal)
            local y = math.clamp(startPosition.Y.Offset + delta.Y, -vertical, vertical)
            Root.Position = UDim2.new(startPosition.X.Scale, x, startPosition.Y.Scale, y)
        end
    end)
    Connect(UserInputService.InputEnded, function(input)
        if input == dragging then
            dragging = false
        end
    end)

    -- ------------------------------------------------------------------
    -- Sidebar (icones + indicador animado)
    -- ------------------------------------------------------------------
    local Sidebar = Create("Frame", {
        Name = "Sidebar",
        Position = UDim2.fromOffset(0, 42),
        Size = UDim2.new(0, 52, 1, -42),
        BackgroundColor3 = "@Surface",
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0
    }, Main)
    Create("Frame", {
        Position = UDim2.new(1, -1, 0, 0),
        Size = UDim2.new(0, 1, 1, 0),
        BackgroundColor3 = "@Border",
        BorderSizePixel = 0
    }, Sidebar)

    local Indicator = Create("Frame", {
        Position = UDim2.fromOffset(8, 10),
        Size = UDim2.fromOffset(42, 42),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 2
    }, Sidebar)
    Corner(Indicator, 8)
    Glow(Indicator, "Accent", 0.65, 55)
    local IndicatorEdge = Stroke(Indicator, "@Accent2", 0.32, 1.4)

    local AvatarFrame = Create("ImageLabel", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 10, 1, -10),
        Size = UDim2.fromOffset(32, 32),
        BackgroundColor3 = "@Surface3",
        BorderSizePixel = 0,
        Image = "",
        ZIndex = 3
    }, Sidebar)
    Corner(AvatarFrame, 16)
    Stroke(AvatarFrame, "@Accent", 0.2, 1.5)
    LoadAvatar(AvatarFrame)

    -- area de conteudo
    local Content = Create("Frame", {
        Name = "Content",
        Position = UDim2.fromOffset(60, 50),
        Size = UDim2.new(1, -68, 1, -58),
        BackgroundTransparency = 1,
        ClipsDescendants = true
    }, Main)
    local Pages = Create("Frame", { Name = "Pages", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, Content)

    local TabFlash = Create("Frame", {
        Position = UDim2.fromOffset(2, 0), Size = UDim2.new(0.44, 0, 0, 2),
        BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ZIndex = 8,
    }, Content)
    Gradient(TabFlash, "Accent2", "Surface", 0)

    local CurrentTab = nil
    local visibleState = false
    local visibleToken = 0

    -- ------------------------------------------------------------------
    -- Notificacoes (entram deslizando, com barra de tempo)
    -- ------------------------------------------------------------------
    local NotificationHolder = Create("Frame", {
        Name = "Notifications",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, 14),
        Size = UDim2.fromOffset(250, 400),
        BackgroundTransparency = 1,
        ZIndex = 100
    }, ScreenGui)
    Create("UIListLayout", {
        Padding = UDim.new(0, 8),
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder = Enum.SortOrder.LayoutOrder
    }, NotificationHolder)
    local notificationOrder = 0

    function Library:Notify(options)
        if Library.Destroyed then return end
        options = options or {}
        if not settings.notifications and not options.Force then return end
        local duration = settings.notificationSeconds > 0 and settings.notificationSeconds or options.Duration or 3
        local category = options.Category or "info"
        local role = category == "warning" and "@Danger" or category == "success" and "@Success" or "@Accent"
        local prefix = category == "warning" and "!  " or category == "success" and "✓  " or "•  "
        local function Remove(wrapper)
            for _, child in ipairs(wrapper:GetDescendants()) do bindings[child] = nil end
            wrapper:Destroy()
        end
        local cards = NotificationHolder:GetChildren()
        if #cards >= 5 then
            local oldest
            for _, child in ipairs(cards) do
                if child:IsA("Frame") and (not oldest or child.LayoutOrder < oldest.LayoutOrder) then oldest = child end
            end
            if oldest then Remove(oldest) end
        end
        notificationOrder = notificationOrder + 1

        local Wrapper = Create("Frame", {
            Size = UDim2.fromOffset(250, 64),
            BackgroundTransparency = 1,
            LayoutOrder = notificationOrder,
            ClipsDescendants = true,
            ZIndex = 101
        }, NotificationHolder)

        local Card = Create("Frame", {
            Position = UDim2.fromOffset(270, 0),
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = "@Surface",
            BorderSizePixel = 0,
            ZIndex = 102
        }, Wrapper)
        Corner(Card, 10)
        Stroke(Card, "@Border")

        local Bar = Create("Frame", {
            Size = UDim2.fromOffset(3, 64),
            BackgroundColor3 = role,
            BorderSizePixel = 0,
            ZIndex = 103
        }, Card)
        Corner(Bar, 2)

        Text(Card, {
            Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -22, 0, 18),
            Text = prefix .. (options.Title or "VANTA"), Font = Enum.Font.GothamBold, TextSize = 12, ZIndex = 103
        })
        Text(Card, {
            Position = UDim2.fromOffset(14, 26), Size = UDim2.new(1, -22, 0, 26),
            Text = options.Description or "", TextSize = 10, TextColor3 = "@Muted",
            TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 103
        })

        local Progress = Create("Frame", {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 0, 1, 0),
            Size = UDim2.new(1, 0, 0, 2),
            BackgroundColor3 = role,
            BorderSizePixel = 0,
            ZIndex = 103
        }, Card)

        Tween(Card, { Position = UDim2.fromOffset(0, 0) }, 0.35, Enum.EasingStyle.Back)
        if settings.animations and not settings.reduced and not settings.lowPower then
            Tween(Progress, {Size = UDim2.new(0, 0, 0, 2)}, duration, Enum.EasingStyle.Linear)
        end

        task.delay(duration, function()
            if Wrapper and Wrapper.Parent then
                Tween(Card, { Position = UDim2.fromOffset(270, 0) }, 0.25)
                task.wait(0.28)
                if Wrapper.Parent then Remove(Wrapper) end
            end
        end)
    end

    -- ------------------------------------------------------------------
    -- Janela de confirmacao
    -- ------------------------------------------------------------------
    local Overlay = Create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1,
        Visible = false,
        Active = true,
        ZIndex = 50
    }, Main)

    local ConfirmCard = Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(280, 128),
        BackgroundColor3 = "@Surface",
        BorderSizePixel = 0,
        ZIndex = 51
    }, Overlay)
    Corner(ConfirmCard, 12)
    Stroke(ConfirmCard, "@Border")
    local ConfirmScale = Create("UIScale", { Scale = 0.9 }, ConfirmCard)

    local ConfirmTitle = Text(ConfirmCard, {
        Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 20),
        Text = "Descarregar VANTA?", Font = Enum.Font.GothamBold, TextSize = 14, ZIndex = 52
    })
    local ConfirmMessage = Text(ConfirmCard, {
        Position = UDim2.fromOffset(16, 36), Size = UDim2.new(1, -32, 0, 34),
        Text = "A interface e todas as funções serão encerradas.", TextSize = 11,
        TextColor3 = "@Muted", TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 52
    })

    local ConfirmYes = Create("TextButton", {
        Position = UDim2.new(0, 16, 1, -42), Size = UDim2.new(0.5, -22, 0, 30),
        BackgroundColor3 = "@Accent", Text = "Descarregar", TextColor3 = Color3.new(1, 1, 1),
        TextSize = 12, Font = Enum.Font.GothamBold, AutoButtonColor = false, ZIndex = 52
    }, ConfirmCard)
    Corner(ConfirmYes, 8)
    Hover(ConfirmYes, "Accent", "Accent2")
    AddPress(ConfirmYes)

    local ConfirmNo = Create("TextButton", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 1, -42), Size = UDim2.new(0.5, -22, 0, 30),
        BackgroundColor3 = "@Surface3", Text = "Cancelar", TextColor3 = "@Text",
        TextSize = 12, Font = Enum.Font.GothamBold, AutoButtonColor = false, ZIndex = 52
    }, ConfirmCard)
    Corner(ConfirmNo, 8)
    Hover(ConfirmNo, "Surface3", "Border")
    AddPress(ConfirmNo)

    local confirmCallback = nil
    local confirmToken = 0
    local function HideConfirm()
        Tween(Overlay, { BackgroundTransparency = 1 }, 0.15)
        Tween(ConfirmScale, { Scale = 0.9 }, 0.15)
        local token = confirmToken
        task.delay(0.16, function()
            if Overlay.Parent and token == confirmToken then Overlay.Visible = false end
        end)
    end

    function Library:Confirm(title, message, yesText, callback)
        confirmToken = confirmToken + 1
        ConfirmTitle.Text = title or "Confirmar"
        ConfirmMessage.Text = message or ""
        ConfirmYes.Text = yesText or "Confirmar"
        confirmCallback = callback
        Overlay.Visible = true
        Tween(Overlay, { BackgroundTransparency = 0.45 }, 0.18)
        Tween(ConfirmScale, { Scale = 1 }, 0.25, Enum.EasingStyle.Back)
    end

    Connect(ConfirmYes.Activated, function()
        local callback = confirmCallback
        confirmCallback = nil
        HideConfirm()
        if callback then callback() end
    end)
    Connect(ConfirmNo.Activated, function()
        confirmCallback = nil
        HideConfirm()
    end)

    -- ------------------------------------------------------------------
    -- Botao flutuante (restaurar) + mostrar/ocultar
    -- ------------------------------------------------------------------
    local FloatButton = Create("TextButton", {
        Name = "VANTA_Restore",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 14, 0.5, 0),
        Size = UDim2.fromOffset(44, 44),
        BackgroundColor3 = Color3.new(1, 1, 1),
        Text = "",
        AutoButtonColor = false,
        Visible = false,
        ZIndex = 200
    }, ScreenGui)
    FloatButton.BackgroundTransparency = 1
    local function FloatingSurface(button, zIndex)
        local shell = Create("CanvasGroup", {
            Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ZIndex = zIndex,
            BackgroundColor3 = Color3.new(1, 1, 1),
        }, button)
        Corner(shell, 12)
        Glow(shell, "AccentDark", 0.74, 42)
        local edge = Stroke(shell, "@Accent2", 0.28, 1.5)
        return shell, edge
    end

    local FloatShell, FloatEdge = FloatingSurface(FloatButton, 201)
    Glyph(FloatShell, "brand", UDim2.fromScale(0.67, 0.67), UDim2.fromScale(0.165, 0.165), "Focus", 202)
    AddPress(FloatButton)
    Connect(FloatButton.MouseEnter, function() Tween(FloatEdge, {Transparency = 0.04}, 0.16) end)
    Connect(FloatButton.MouseLeave, function() Tween(FloatEdge, {Transparency = 0.28}, 0.16) end)

    local function PositionInside(button, target, delta)
        local screen, size, anchor = ScreenGui.AbsoluteSize, button.AbsoluteSize, button.AnchorPoint
        local x = target.X.Scale * screen.X + target.X.Offset
        local y = target.Y.Scale * screen.Y + target.Y.Offset
        if delta then x, y = x + delta.X, y + delta.Y end
        local minX, minY = anchor.X * size.X, anchor.Y * size.Y
        return UDim2.fromOffset(
            math.clamp(x, minX, math.max(minX, screen.X - (1 - anchor.X) * size.X)),
            math.clamp(y, minY, math.max(minY, screen.Y - (1 - anchor.Y) * size.Y))
        )
    end
    Library.PositionInside = PositionInside

    function Library:CreateAimButton()
        local button = Create("TextButton", {
            Name = "VANTA_AimButton", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -20, 0.6, 0),
            Size = UDim2.fromOffset(settings.aimSize, settings.aimSize), Visible = false, ZIndex = 180,
        }, ScreenGui)
        local shell, edge = FloatingSurface(button, 181)
        local cross, colorCross = Glyph(shell, "aim", UDim2.fromScale(0.51, 0.51), UDim2.fromScale(0.245, 0.11), "Icon", 182)
        local grip = Glyph(shell, "grip", UDim2.fromScale(0.51, 0.51), UDim2.fromScale(0.245, 0.11), "Focus", 182)
        grip.Visible = false
        local label = Text(shell, {
            Position = UDim2.fromScale(0, 0.65), Size = UDim2.fromScale(1, 0.25), Text = "AIM",
            TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBold, TextSize = 10,
            TextColor3 = "@Focus", ZIndex = 182,
        })
        local function Update()
            button.Size = UDim2.fromOffset(settings.aimSize, settings.aimSize)
            shell.GroupTransparency = 1 - settings.aimOpacity / 100
            if button.Visible and ScreenGui.AbsoluteSize.X > 0 then
                button.Position = PositionInside(button, button.Position)
            end
        end
        table.insert(Library.ThemeObservers, Update)
        Connect(ScreenGui:GetPropertyChangedSignal("AbsoluteSize"), Update)
        Update()
        return button, function(state)
            grip.Visible = state == "move"
            cross.Visible = not grip.Visible
            label.Text = grip.Visible and "MOVER" or state == "hold" and "ATIVO" or "AIM"
            colorCross(state == "hold" and "Focus" or "Icon")
            Tween(edge, {Transparency = state == "idle" and 0.28 or 0.04}, 0.13)
        end
    end

    local appliedFloatSide
    local function UpdateLauncherAppearance()
        FloatButton.Size = UDim2.fromOffset(settings.floatSize, settings.floatSize)
        FloatShell.GroupTransparency = 1 - settings.floatOpacity / 100
        if FloatButton.Visible and ScreenGui.AbsoluteSize.X > 0 then
            FloatButton.Position = PositionInside(FloatButton, FloatButton.Position)
        end
    end
    Connect(ScreenGui:GetPropertyChangedSignal("AbsoluteSize"), UpdateLauncherAppearance)

    function Library:SetVisible(state)
        if Library.Destroyed or state == visibleState then return end
        visibleState = state
        visibleToken = visibleToken + 1
        local token = visibleToken
        if state then
            FloatButton.Visible = false
            Root.Visible = true
            Tween(Main, { GroupTransparency = 0 }, 0.25)
            Tween(IntroScale, { Scale = 1 }, 0.4, Enum.EasingStyle.Back)
        else
            Tween(Main, { GroupTransparency = 1 }, 0.18)
            Tween(IntroScale, { Scale = 0.94 }, 0.18)
            task.delay(0.19, function()
                if visibleToken == token and not Library.Destroyed then
                    Root.Visible = false
                    FloatButton.Visible = true
                end
            end)
        end
    end

    -- botao flutuante arrastavel (toque curto restaura)
    local floatDragging, floatMoved = false, 0
    local floatStart, floatStartPos
    Connect(FloatButton.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if floatDragging then return end
            floatDragging, floatMoved = input, 0
            floatStart, floatStartPos = input.Position, FloatButton.Position
        end
    end)
    Connect(UserInputService.InputChanged, function(input)
        if floatDragging and (input == floatDragging or (floatDragging.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement)) then
            local delta = input.Position - floatStart
            floatMoved = math.max(floatMoved, delta.Magnitude)
            FloatButton.Position = PositionInside(FloatButton, floatStartPos, delta)
        end
    end)
    Connect(UserInputService.InputEnded, function(input)
        if input == floatDragging then
            floatDragging = false
            if floatMoved < 8 then Library:SetVisible(true) end
        end
    end)

    Connect(MinButton.Activated, function() Library:SetVisible(false) end)
    Connect(CloseButton.Activated, function()
        Library:Confirm("Descarregar VANTA?", "A interface e todas as funções serão encerradas.", "Descarregar", function()
            Library:Destroy()
        end)
    end)
    Connect(UserInputService.InputBegan, function(input, processed)
        if not processed and not Library.CapturingKey and not UserInputService:GetFocusedTextBox() and input.KeyCode.Name == settings.keybind then
            Library:SetVisible(not visibleState)
        end
    end)

    Library.NavigationHint = Text(Topbar, {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -86, 0.5, 0),
        Size = UDim2.fromOffset(96, 22), Text = "", TextColor3 = "@Muted",
        TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd,
    })

    local tabGlyphs = {Home = "home", Aimbot = "aim", ["Silent Aim"] = "silent", ["Aim Kill"] = "kill",
        Visuals = "eye", Settings = "settings"}
    local navLabels = {Home = "HOME", Aimbot = "AIM", ["Silent Aim"] = "SILENT", ["Aim Kill"] = "KILL", Visuals = "VISUAL", Settings = "SETUP"}

    local function IsPress(input)
        return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
    end

    local sliderInput, sliderUpdate, sliderScroll
    Connect(UserInputService.InputChanged, function(input)
        if sliderInput and (input == sliderInput or (
            sliderInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseMovement
        )) then sliderUpdate(input) end
    end)
    Connect(UserInputService.InputEnded, function(input)
        if input == sliderInput then
            sliderScroll.ScrollingEnabled = true
            sliderInput, sliderUpdate, sliderScroll = nil, nil, nil
        end
    end)

    function Library:IsTabVisible(tab)
        return visibleState and CurrentTab == tab
    end

    function Library:CreateTab(name)
        local index = #Library.Tabs + 1
        local y = 8 + (index - 1) * 46

        local NavButton = Create("TextButton", {
            Name = name,
            Position = UDim2.fromOffset(5, y),
            Size = UDim2.fromOffset(42, 42),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 3
        }, Sidebar)
        AddPress(NavButton)
        Connect(NavButton.MouseEnter, function() Library.NavigationHint.Text = name end)
        Connect(NavButton.MouseLeave, function() Library.NavigationHint.Text = CurrentTab and CurrentTab.Name or "Dashboard" end)

        local _, ColorIcon = Glyph(NavButton, tabGlyphs[name], UDim2.fromOffset(22, 22),
            UDim2.fromOffset(10, 4), "Icon", 5)
        local caption = Text(NavButton, {
            Position = UDim2.fromOffset(0, 27), Size = UDim2.new(1, 0, 0, 12),
            Text = navLabels[name] or name, TextSize = 8, Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = "@Text", ZIndex = 4,
        })
        local function SetIconActive(active)
            ColorIcon(active and "Focus" or "Icon")
            Tween(caption, {TextTransparency = active and 0 or 0.2}, 0.12)
        end

        local PageGroup = Create("CanvasGroup", {
            Name = name,
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            GroupTransparency = 1,
            Visible = false
        }, Pages)

        local Scroll = Create("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = "@Accent",
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y
        }, PageGroup)
        Padding(Scroll, 2, 8, 2, 8)
        Create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, Scroll)

        local Tab = { Name = name, Group = PageGroup, Scroll = Scroll, SetIconActive = SetIconActive, Y = y, Sections = {} }

        local function SelectTab()
            if CurrentTab == Tab then return end
            local previous = CurrentTab
            CurrentTab = Tab
            Library.NavigationHint.Text = name
    
            if previous then
                previous.Group.Visible = false
                previous.Group.GroupTransparency = 1
                previous.SetIconActive(false)
            end

            PageGroup.Position = UDim2.fromOffset(0, 12)
            PageGroup.GroupTransparency = 1
            PageGroup.Visible = true
            Tween(PageGroup, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, 0.25)
            SetIconActive(true)
            if settings.animations and not settings.reduced and not settings.lowPower then
                TabFlash.BackgroundTransparency = 0.18
                TabFlash.Size = UDim2.new(0.18, 0, 0, 2)
                Tween(TabFlash, {Size = UDim2.new(0.95, 0, 0, 2), BackgroundTransparency = 1}, 0.32)
            else
                Tween(TabFlash, {BackgroundTransparency = 1}, 0)
            end

            Indicator.Visible = true
            IndicatorEdge.Transparency = 0.12
            Tween(IndicatorEdge, {Transparency = 0.38}, 0.28)
            Tween(Indicator, { Position = UDim2.fromOffset(5, y) }, 0.28, Enum.EasingStyle.Quart)
        end

        Tab.Select = SelectTab
        Connect(NavButton.Activated, SelectTab)
        table.insert(Library.Tabs, Tab)

        if index == 1 then
            Indicator.Position = UDim2.fromOffset(5, y)
            SelectTab()
        end

        if name ~= "Home" then
            local search = Create("TextBox", {
                Size = UDim2.new(1, 0, 0, 43), LayoutOrder = -1, BackgroundColor3 = "@Surface",
                TextColor3 = "@Text", PlaceholderColor3 = "@Muted", PlaceholderText = "Buscar nesta aba",
                Text = "", ClearTextOnFocus = false, TextSize = 13, Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, Scroll)
            Corner(search, 8)
            Stroke(search)
            Padding(search, 12, 12)
            Connect(search:GetPropertyChangedSignal("Text"), function()
                local query = string.lower(search.Text)
                for card, title in pairs(Tab.Sections) do
                    local searchable = title
                    for _, child in ipairs(card:GetDescendants()) do
                        if child:IsA("TextLabel") or child:IsA("TextButton") then searchable = searchable .. " " .. child.Text end
                    end
                    card.Visible = string.find(string.lower(searchable), query, 1, true) ~= nil
                end
            end)
        end

        local sectionOrder = 0

        function Tab:CreateSection(title, description)
            sectionOrder = sectionOrder + 1
            local Card = Create("Frame", {
                Size = UDim2.new(1, 0, 0, 40),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = Color3.new(1, 1, 1),
                BorderSizePixel = 0,
                LayoutOrder = sectionOrder
            }, Scroll)
            Tab.Sections[Card] = title or ""
            Corner(Card, 10)
            Stroke(Card, "@Border")
            Gradient(Card, "Surface2", "Background", 90)
            Padding(Card, 12, 12, 10, 12)
            local layout = Create("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, Card)
            Bind(layout, "Padding", function() return UDim.new(0, settings.density == "Compacta" and 4 or 8) end)

            local order = 0
            local function NextOrder()
                order = order + 1
                return order
            end

            local Header = Create("Frame", {
                Size = UDim2.new(1, 0, 0, description and 32 or 20),
                BackgroundTransparency = 1,
                LayoutOrder = NextOrder()
            }, Card)
            Text(Header, { Size = UDim2.new(1, 0, 0, 18), Text = title or "Section", Font = Enum.Font.GothamBold, TextSize = 13 })
            if description then
                Text(Header, {
                    Position = UDim2.fromOffset(0, 17), Size = UDim2.new(1, 0, 0, 14),
                    Text = description, TextSize = 10, TextColor3 = "@Muted", TextTruncate = Enum.TextTruncate.AtEnd
                })
            end

            local Section = {}

            function Section:CreateInput(options)
                local height = options.Multiline and 105 or 50
                local Box = Create("TextBox", {
                    Size = UDim2.new(1, 0, 0, height), LayoutOrder = NextOrder(),
                    BackgroundColor3 = "@Surface2", TextColor3 = "@Text",
                    PlaceholderColor3 = "@Muted", PlaceholderText = options.Name,
                    Text = options.Default or "", ClearTextOnFocus = false,
                    MultiLine = options.Multiline == true, TextWrapped = true,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = options.Multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
                    Font = Enum.Font.Gotham, TextSize = 12,
                }, Card)
                Corner(Box, 8)
                Stroke(Box)
                Padding(Box, 10, 10, options.Multiline and 8 or 0, 0)
                Connect(Box.FocusLost, function()
                    local limit = options.Multiline and 65536 or 128
                    if #Box.Text > limit then Box.Text = options.Default or "" end
                    if options.Callback then options.Callback(Box.Text) end
                end)
                return {
                    Get = function() return Box.Text end,
                    Set = function(_, value) Box.Text = value end,
                }
            end

            function Section:CreateSwatches()
                local row = Create("Frame", {
                    Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = NextOrder(),
                }, Card)
                local swatches = {}
                for index = 1, 3 do
                    swatches[index] = Create("Frame", {
                        Size = UDim2.new(1/3, -4, 1, 0), Position = UDim2.fromScale((index - 1)/3, 0),
                    }, row)
                    Corner(swatches[index], 5)
                end
                return function(colors)
                    for index, swatch in ipairs(swatches) do swatch.BackgroundColor3 = colors[index] end
                end
            end

            function Section:CreateColorPicker(options)
                local draft = options.Default
                local swatch = self:CreateSwatches()
                local input = self:CreateInput({Name = options.Name .. " · #RRGGBB (vazio = tema)", Default = draft})
                local hue = self:CreateSlider({Name = options.Name .. " · matiz", Max = 359, Callback = function(value)
                    local color = Color3.fromHSV(value / 360, 0.68, 0.88)
                    input:Set(color:ToHex())
                    swatch({color, color:Lerp(Color3.new(1, 1, 1), 0.25), color:Lerp(Color3.new(0, 0, 0), 0.25)})
                end})
                local control = {Get = function() return draft end}
                local function Validate(value) return value == "" and "" or Hex(value) end
                local role = ({primary = "Accent", secondary = "AccentDark", highlight = "Accent2"})[options.Key]
                local function Preview()
                    local color = (draft ~= "" and Color(tonumber(draft, 16))) or Theme[role]
                    swatch({color, color:Lerp(Color3.new(1, 1, 1), 0.25), color:Lerp(Color3.new(0, 0, 0), 0.25)})
                end
                table.insert(Library.ThemeObservers, Preview)
                function control:Set(value)
                    local clean = Validate(value)
                    if clean == nil then
                        Library:Notify({Title = options.Name, Description = "Use seis dígitos hexadecimais ou deixe vazio.", Category = "warning", Force = true})
                        return
                    end
                    draft = clean
                    input:Set(clean)
                    if options.Callback then options.Callback(clean) end
                    Preview()
                end
                Register(options, control, Validate)
                Preview()
                self:CreateButton({Name = "Aplicar cor · " .. options.Name, Icon = "✓", Callback = function() control:Set(input:Get()) end})
                return control
            end

            function Section:CreateKeybind(options)
                local value = options.Default
                local awaiting = false
                local button
                button = self:CreateButton({Name = options.Name, Icon = "⌘", Callback = function()
                    awaiting = true
                    Library.CapturingKey = true
                    button.Text = "Pressione uma tecla · Esc cancela"
                end})
                local control = {Get = function() return value end}
                local function Validate(candidate)
                    if type(candidate) ~= "string" then return nil end
                    local ok, item = pcall(function() return Enum.KeyCode[candidate] end)
                    return ok and item and item ~= Enum.KeyCode.Unknown and candidate or nil
                end
                function control:Set(candidate)
                    value = candidate
                    button.Text = "⌘  " .. options.Name .. " · " .. value
                    if options.Callback then options.Callback(value) end
                end
                button.Text = "⌘  " .. options.Name .. " · " .. value
                Connect(UserInputService.InputBegan, function(input, processed)
                    if not awaiting or processed or input.KeyCode == Enum.KeyCode.Unknown then return end
                    awaiting = false
                    task.defer(function() Library.CapturingKey = false end)
                    if input.KeyCode == Enum.KeyCode.Escape then
                        button.Text = "⌘  " .. options.Name .. " · " .. value
                    else
                        control:Set(input.KeyCode.Name)
                    end
                end)
                Register(options, control, Validate)
                return control
            end

            -- Toggle ---------------------------------------------------
            function Section:CreateToggle(options)
                options = options or {}
                local value = options.Default == true

                local Row = Create("Frame", {
                    Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = "@Surface2",
                    BorderSizePixel = 0, LayoutOrder = NextOrder()
                }, Card)
                Corner(Row, 8)

                Text(Row, {
                    Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -70, 1, 0),
                    Text = options.Name or "Toggle", Font = Enum.Font.GothamMedium,
                    TextTruncate = Enum.TextTruncate.AtEnd
                })

                local Track = Create("Frame", {
                    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
                    Size = UDim2.fromOffset(38, 20),
                    BackgroundColor3 = value and Theme.Accent or Theme.Surface3, BorderSizePixel = 0
                }, Row)
                Corner(Track, 10)

                local Knob = Create("Frame", {
                    AnchorPoint = Vector2.new(0, 0.5),
                    Position = value and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
                    Size = UDim2.fromOffset(14, 14), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0
                }, Track)
                Corner(Knob, 7)

                local Hit = Create("TextButton", {
                    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
                    AutoButtonColor = false, ZIndex = 5
                }, Row)

                local Control = {}
                local function TrackColor() return value and Theme.Accent or Theme.Surface3 end
                Bind(Track, "BackgroundColor3", TrackColor)
                function Control:Set(newValue)
                    value = newValue == true
                    Tween(Track, { BackgroundColor3 = value and Theme.Accent or Theme.Surface3 }, 0.18)
                    Tween(Knob, { Position = value and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }, 0.22, Enum.EasingStyle.Back)
                    if options.Callback then options.Callback(value) end
                end
                function Control:Get() return value end

                Register(options, Control, function(candidate)
                    if type(candidate) == "boolean" then return candidate end
                    return nil
                end)
                Connect(Hit.Activated, function() Control:Set(not value) end)
                return Control
            end

            -- Slider ---------------------------------------------------
            function Section:CreateSlider(options)
                options = options or {}
                local minimum = options.Min or 0
                local maximum = options.Max or 100
                local step = options.Step or 1
                local value = math.clamp(options.Default or minimum, minimum, maximum)

                local Row = Create("Frame", {
                    Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = "@Surface2",
                    BorderSizePixel = 0, LayoutOrder = NextOrder()
                }, Card)
                Corner(Row, 8)

                Text(Row, {
                    Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -90, 0, 18),
                    Text = options.Name or "Slider", Font = Enum.Font.GothamMedium,
                    TextTruncate = Enum.TextTruncate.AtEnd
                })
                local ValueLabel = Text(Row, {
                    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 6), Size = UDim2.fromOffset(70, 18),
                    Text = tostring(value), TextColor3 = "@Accent2", Font = Enum.Font.GothamBold,
                    TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right
                })

                local Bar = Create("Frame", {
                    Position = UDim2.fromOffset(12, 36), Size = UDim2.new(1, -24, 0, 6),
                    BackgroundColor3 = "@Surface3", BorderSizePixel = 0
                }, Row)
                Corner(Bar, 3)

                local normalized0 = (value - minimum) / math.max(maximum - minimum, 1e-6)
                local Fill = Create("Frame", {
                    Size = UDim2.new(normalized0, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0
                }, Bar)
                Corner(Fill, 3)
                Gradient(Fill, "AccentDark", "Accent2", 0)

                local Knob = Create("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(normalized0, 0, 0.5, 0),
                    Size = UDim2.fromOffset(14, 14), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0
                }, Bar)
                Corner(Knob, 7)

                local Hit = Create("TextButton", {
                    Position = UDim2.fromOffset(0, 19), Size = UDim2.new(1, 0, 0, 37),
                    BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 5
                }, Row)

                local Control = {}

                local function Apply(newValue, silent)
                    value = math.clamp(math.floor((newValue - minimum) / step + 0.5) * step + minimum, minimum, maximum)
                    value = tonumber(string.format("%.3f", value))
                    local normalized = (value - minimum) / math.max(maximum - minimum, 1e-6)
                    Fill.Size = UDim2.new(normalized, 0, 1, 0)
                    Knob.Position = UDim2.new(normalized, 0, 0.5, 0)
                    ValueLabel.Text = tostring(value)
                    if not silent and options.Callback then options.Callback(value) end
                end

                local function FromInput(input)
                    if Bar.AbsoluteSize.X <= 0 then return end
                    local percent = math.clamp((input.Position.X - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)
                    Apply(minimum + (maximum - minimum) * percent)
                end

                function Control:Set(newValue) Apply(newValue) end
                function Control:Get() return value end

                Register(options, Control, function(candidate)
                    if type(candidate) ~= "number" or candidate ~= candidate or candidate < minimum or candidate > maximum then return nil end
                    return candidate
                end)
                Connect(Hit.InputBegan, function(input)
                    if sliderInput or not IsPress(input) then return end
                    sliderInput, sliderUpdate, sliderScroll = input, FromInput, Scroll
                    Scroll.ScrollingEnabled = false
                    FromInput(input)
                end)

                return Control
            end

            -- Dropdown -------------------------------------------------
            function Section:CreateDropdown(options)
                options = options or {}
                local items = options.Options or {}
                local selected = options.Default or items[1] or "None"
                local expanded = false
                local listHeight = math.min(#items * 45 + 2, 176)

                local Holder = Create("Frame", {
                    Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = "@Surface2",
                    BorderSizePixel = 0, ClipsDescendants = true, LayoutOrder = NextOrder()
                }, Card)
                Corner(Holder, 8)

                local Header = Create("TextButton", {
                    Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Text = "",
                    AutoButtonColor = false, ZIndex = 5
                }, Holder)

                Text(Holder, {
                    Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.5, -12, 0, 44),
                    Text = options.Name or "Dropdown", Font = Enum.Font.GothamMedium,
                    TextTruncate = Enum.TextTruncate.AtEnd
                })
                local SelectedLabel = Text(Holder, {
                    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -30, 0, 0), Size = UDim2.new(0.4, 0, 0, 44),
                    Text = tostring(selected), TextColor3 = "@Accent2", Font = Enum.Font.GothamBold,
                    TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd
                })
                local Arrow = Text(Holder, {
                    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0), Size = UDim2.fromOffset(16, 44),
                    Text = "v", TextColor3 = "@Muted", Font = Enum.Font.GothamBold,
                    TextXAlignment = Enum.TextXAlignment.Center
                })

                local List = Create("ScrollingFrame", {
                    Position = UDim2.fromOffset(6, 48), Size = UDim2.new(1, -12, 0, 0),
                    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
                    ScrollBarImageColor3 = "@Accent", CanvasSize = UDim2.new(0, 0, 0, 0),
                    AutomaticCanvasSize = Enum.AutomaticSize.Y
                }, Holder)
                Create("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, List)

                local optionButtons = {}
                local function Refresh()
                    for item, button in pairs(optionButtons) do
                        local active = item == selected
                        button.TextColor3 = active and Color3.new(1, 1, 1) or Theme.Text
                        button.BackgroundColor3 = active and Theme.AccentDark or Theme.Surface3
                    end
                end

                local function Collapse()
                    expanded = false
                    Tween(Holder, { Size = UDim2.new(1, 0, 0, 44) }, 0.2)
                    Tween(List, { Size = UDim2.new(1, -12, 0, 0) }, 0.2)
                    Tween(Arrow, { Rotation = 0 }, 0.2)
                end

                for position, item in ipairs(items) do
                    local OptionButton = Create("TextButton", {
                        Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = "@Surface3",
                        Text = tostring(item), TextColor3 = "@Text", TextSize = 11,
                        Font = Enum.Font.GothamMedium, AutoButtonColor = false, LayoutOrder = position
                    }, List)
                    Corner(OptionButton, 6)
                    optionButtons[item] = OptionButton
                    Bind(OptionButton, "BackgroundColor3", function() return item == selected and Theme.AccentDark or Theme.Surface3 end)
                    Bind(OptionButton, "TextColor3", function() return item == selected and Color3.new(1, 1, 1) or Theme.Text end)
                    Connect(OptionButton.Activated, function()
                        selected = item
                        SelectedLabel.Text = tostring(item)
                        Refresh()
                        Collapse()
                        if options.Callback then options.Callback(selected) end
                    end)
                end
                Refresh()

                Connect(Header.Activated, function()
                    expanded = not expanded
                    if expanded then
                        Tween(Holder, { Size = UDim2.new(1, 0, 0, 44 + listHeight + 10) }, 0.22)
                        Tween(List, { Size = UDim2.new(1, -12, 0, listHeight) }, 0.22)
                        Tween(Arrow, { Rotation = 180 }, 0.2)
                    else
                        Collapse()
                    end
                end)

                local Control = {}
                function Control:Get() return selected end
                function Control:OnChange(callback) options.Callback = callback end
                function Control:Set(newValue, silent)
                    for _, item in ipairs(items) do
                        if item == newValue then
                            selected = newValue
                            SelectedLabel.Text = tostring(newValue)
                            Refresh()
                            if not silent and options.Callback then options.Callback(selected) end
                            return
                        end
                    end
                end
                Register(options, Control, function(candidate)
                    if table.find(items, candidate) then return candidate end
                    return nil
                end)
                return Control
            end

            -- Button ---------------------------------------------------
            function Section:CreateButton(options)
                options = options or {}
                local Action = Create("TextButton", {
                    Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = "@Surface3",
                    Text = (options.Icon and options.Icon .. "  " or "") .. (options.Name or "Button"), TextColor3 = "@Text", TextSize = 12,
                    Font = Enum.Font.GothamBold, AutoButtonColor = false, LayoutOrder = NextOrder()
                }, Card)
                Corner(Action, 8)
                Stroke(Action, "@Border")
                Hover(Action, "Surface3", "AccentDark")
                AddPress(Action)
                Connect(Action.Activated, function()
                    if options.Callback then options.Callback() end
                end)
                return Action
            end

            -- Label ----------------------------------------------------
            function Section:CreateLabel(text)
                local LabelObject = Text(Card, {
                    Size = UDim2.new(1, 0, 0, 20), AutomaticSize = Enum.AutomaticSize.Y, Text = text or "", TextSize = 12,
                    TextColor3 = "@Muted", TextWrapped = true, RichText = false, LayoutOrder = NextOrder()
                })
                local Control = {}
                function Control:Set(newText) LabelObject.Text = newText end
                return Control
            end

            return Section
        end

        return Tab
    end

    -- ------------------------------------------------------------------
    -- HOME (dashboard)
    -- ------------------------------------------------------------------
    local Home = Library:CreateTab("Home")
    local HomeScroll = Home.Scroll
    local homeOrder = 0
    local function HomeNext()
        homeOrder = homeOrder + 1
        return homeOrder
    end

    -- saudacao
    local Greeting = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 72), BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0, LayoutOrder = HomeNext()
    }, HomeScroll)
    Corner(Greeting, 10)
    Stroke(Greeting, "@Border")
    Glow(Greeting, "Accent", 0.42, 8)

    local GreetingAvatar = Create("ImageLabel", {
        Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(48, 48),
        BackgroundColor3 = "@Surface3", BorderSizePixel = 0, Image = ""
    }, Greeting)
    Corner(GreetingAvatar, 24)
    LoadAvatar(GreetingAvatar)

    Text(Greeting, {
        Position = UDim2.fromOffset(72, 14), Size = UDim2.new(1, -84, 0, 22),
        Text = "Olá, " .. LocalPlayer.DisplayName, Font = Enum.Font.GothamBold, TextSize = 16,
        TextTruncate = Enum.TextTruncate.AtEnd
    })
    Text(Greeting, {
        Position = UDim2.fromOffset(72, 38), Size = UDim2.new(1, -84, 0, 18),
        Text = "@" .. LocalPlayer.Name .. "  •  " .. ExecutorName() .. "  •  Sessão ativa",
        TextSize = 10, TextColor3 = "@Muted", TextTruncate = Enum.TextTruncate.AtEnd
    })

    -- linha com duas colunas
    local Row = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 214), BackgroundTransparency = 1, LayoutOrder = HomeNext()
    }, HomeScroll)

    local function InfoCard(parent, position, size, title, description, accent)
        local Card = Create("Frame", {
            Position = position, Size = size, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0
        }, parent)
        Corner(Card, 10)
        Stroke(Card, "@Border")
        Glow(Card, accent or "Accent", 0.46, 120)
        Text(Card, {
            Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 16),
            Text = title, Font = Enum.Font.GothamBold, TextSize = 13
        })
        if description then
            Text(Card, {
                Position = UDim2.fromOffset(12, 24), Size = UDim2.new(1, -24, 0, 12),
                Text = description, TextSize = 10, TextColor3 = "@Muted", TextTruncate = Enum.TextTruncate.AtEnd
            })
        end
        return Card
    end

    local function Tile(parent, title, value, order, height)
        local Box = Create("Frame", {
            BackgroundColor3 = "@Surface2", BackgroundTransparency = 0.15,
            BorderSizePixel = 0, LayoutOrder = order
        }, parent)
        Corner(Box, 8)
        Text(Box, {
            Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -16, 0, 12),
            Text = title, TextSize = 9, TextColor3 = "@Muted", Font = Enum.Font.GothamMedium
        })
        local ValueLabel = Text(Box, {
            Position = UDim2.fromOffset(8, height - 22), Size = UDim2.new(1, -16, 0, 18),
            Text = value, TextSize = 13, Font = Enum.Font.GothamBold, TextTruncate = Enum.TextTruncate.AtEnd
        })
        return ValueLabel, Box
    end

    -- Servidor
    local sessionStart = os.time()
    local ServerCard = InfoCard(Row, UDim2.fromOffset(0, 0), UDim2.new(0.5, -5, 1, 0),
        "Servidor", "Sessão iniciada às " .. os.date("%H:%M", sessionStart))
    local ServerGrid = Create("Frame", {
        Position = UDim2.fromOffset(12, 44), Size = UDim2.new(1, -24, 0, 190), BackgroundTransparency = 1
    }, ServerCard)
    Create("UIGridLayout", {
        CellSize = UDim2.new(0.5, -3, 0, 42), CellPadding = UDim2.fromOffset(6, 6),
        SortOrder = Enum.SortOrder.LayoutOrder
    }, ServerGrid)

    local PlayersValue = Tile(ServerGrid, "Jogadores", "-", 1, 42)
    local MaxValue = Tile(ServerGrid, "Máximo", "-", 2, 42)
    local LatencyValue = Tile(ServerGrid, "Latência", "-", 3, 42)
    local CountryValue = Tile(ServerGrid, "Seu país", "-", 4, 42)
    local SessionValue = Tile(ServerGrid, "Tempo de sessão", "00:00:00", 5, 42)
    local FPSValue = Tile(ServerGrid, "FPS", "Medindo…", 6, 42)
    local DeviceValue = Tile(ServerGrid, "Entrada", UserInputService.TouchEnabled and "Toque" or (UserInputService.KeyboardEnabled and "Teclado" or "—"), 7, 42)

    local JoinButton = Create("TextButton", {
        BackgroundColor3 = "@AccentDark", Text = "Copiar Join Script", TextColor3 = Color3.new(1, 1, 1),
        TextSize = 11, Font = Enum.Font.GothamBold, AutoButtonColor = false, LayoutOrder = 8
    }, ServerGrid)
    Corner(JoinButton, 8)
    Hover(JoinButton, "AccentDark", "Accent")
    AddPress(JoinButton)
    Connect(JoinButton.Activated, function()
        local joinScript = string.format(
            'game:GetService("TeleportService"):TeleportToPlaceInstance(%d, "%s", game.Players.LocalPlayer)',
            game.PlaceId, game.JobId)
        local copy = setclipboard or toclipboard
        local copied = type(copy) == "function" and pcall(copy, joinScript)
        Library:Notify({
            Title = "Join Script",
            Description = copied and "Copiado para a área de transferência." or "A área de transferência está indisponível.",
            Category = copied and "success" or "warning",
        })
    end)

    -- Compatibilidade
    local CompatCard = InfoCard(Row, UDim2.new(0.5, 5, 0, 0), UDim2.new(0.5, -5, 0, 96),
        "Compatibilidade", "Recursos disponíveis no seu executor", "AccentDark")
    local function Status(label, ok)
        return string.format("<font color='%s'>%s %s</font>", "#" .. (ok and Theme.Success or Theme.Danger):ToHex(), label, ok and "OK" or "X")
    end
    local hasDrawing = false
    pcall(function() hasDrawing = Drawing ~= nil and Drawing.new ~= nil end)
    local hasHooks = (hookmetamethod ~= nil) and (getnamecallmethod ~= nil) and (checkcaller ~= nil)
    local hasClipboard = (setclipboard ~= nil) or (toclipboard ~= nil)
    Text(CompatCard, {
        Position = UDim2.fromOffset(12, 42), Size = UDim2.new(1, -24, 0, 14),
        Text = "Executor: " .. ExecutorName(), TextSize = 11, Font = Enum.Font.GothamMedium,
        TextTruncate = Enum.TextTruncate.AtEnd
    })
    local CompatStatus = Text(CompatCard, {
        Position = UDim2.fromOffset(12, 60), Size = UDim2.new(1, -24, 0, 28),
        TextSize = 10, RichText = true, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top
    })
    local function UpdateCompatStatus()
        CompatStatus.Text = Status("Drawing", hasDrawing) .. "   " .. Status("Hooks", hasHooks) .. "\n" .. Status("Clipboard", hasClipboard)
    end
    table.insert(Library.ThemeObservers, UpdateCompatStatus)
    UpdateCompatStatus()

    -- Amigos
    local FriendsCard = InfoCard(Row, UDim2.new(0.5, 5, 0, 106), UDim2.new(0.5, -5, 1, -106),
        "Amigos", nil, "Accent2")
    local FriendsGrid = Create("Frame", {
        Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -24, 0, 70), BackgroundTransparency = 1
    }, FriendsCard)
    Create("UIGridLayout", {
        CellSize = UDim2.new(0.5, -3, 0, 32), CellPadding = UDim2.fromOffset(6, 6),
        SortOrder = Enum.SortOrder.LayoutOrder
    }, FriendsGrid)
    local FriendsServerValue = Tile(FriendsGrid, "No servidor", "-", 1, 32)
    local FriendsOnlineValue = Tile(FriendsGrid, "Online", "-", 2, 32)
    local FriendsOfflineValue = Tile(FriendsGrid, "Offline", "-", 3, 32)
    local FriendsAllValue = Tile(FriendsGrid, "Todos", "-", 4, 32)

    local BrandCard = Create("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
    }, Row)
    Corner(BrandCard, 9)
    Stroke(BrandCard, "@Border")
    Glow(BrandCard, "AccentDark", 0.52, 12)
    local BrandFallback = Text(BrandCard, {
        Size = UDim2.fromScale(1, 1), Text = "VANTA HUB", Font = Enum.Font.GothamBlack,
        TextSize = 17, TextColor3 = "@Focus", TextXAlignment = Enum.TextXAlignment.Center,
    })
    Art(BrandCard, "banner", UDim2.new(1, -12, 1, -6), UDim2.fromOffset(6, 3), BrandFallback, 2)

    updateDashboardLayout = function(narrow, height)
        Row.Size = UDim2.new(1, 0, 0, narrow and 560 or 342)
        local column = narrow and 1 or 0.5
        local inset = narrow and 0 or -5
        ServerCard.Size = UDim2.new(column, inset, 0, 236)
        BrandCard.Position = UDim2.fromOffset(0, narrow and 464 or 246)
        BrandCard.Size = UDim2.new(column, inset, 0, 96)
        CompatCard.Position = narrow and UDim2.fromOffset(0, 246) or UDim2.new(0.5, 5, 0, 0)
        CompatCard.Size = UDim2.new(column, inset, 0, 96)
        FriendsCard.Position = narrow and UDim2.fromOffset(0, 352) or UDim2.new(0.5, 5, 0, 106)
        FriendsCard.Size = UDim2.new(column, inset, 0, narrow and 102 or 236)
        AvatarFrame.Visible = settings.avatar and height >= 378
        Library.NavigationHint.Visible = not narrow
        TitleLabel.Size = UDim2.new(1, narrow and -134 or -238, 1, 0)
    end
    UpdateScale()

    -- dados assincronos (nunca travam o carregamento)
    local FriendIds = {}
    local friendTotal, friendOnline = nil, nil
    local countryCode = nil

    task.spawn(function()
        pcall(function()
            countryCode = LocalizationService:GetCountryRegionForPlayerAsync(LocalPlayer)
        end)
    end)
    task.spawn(function()
        pcall(function()
            local pages = Players:GetFriendsAsync(LocalPlayer.UserId)
            local total = 0
            while not Library.Destroyed do
                for _, item in ipairs(pages:GetCurrentPage()) do
                    total = total + 1
                    FriendIds[item.Id] = true
                end
                if pages.IsFinished then break end
                pages:AdvanceToNextPageAsync()
            end
            friendTotal = total
        end)
        pcall(function() friendOnline = #LocalPlayer:GetFriendsOnline(200) end)
    end)

    local function FormatTime(seconds)
        return string.format("%02d:%02d:%02d", math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), math.floor(seconds % 60))
    end
    local function Latency()
        local ok, value = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
        if ok and type(value) == "number" and value == value and value >= 0 and value < math.huge then return string.format("%d ms", math.floor(value)) end
        return "-"
    end

    local accumulator, frames = 0, 0
    Connect(RunService.PreRender, function(dt)
        if not (visibleState and CurrentTab == Home) then accumulator, frames = 0, 0 return end
        accumulator, frames = accumulator + dt, frames + 1
        if accumulator < math.max(settings.refreshSeconds, settings.lowPower and 3 or 1) then return end
        FPSValue.Text = settings.diagnostics and string.format("%d", math.floor(frames / accumulator + 0.5)) or "—"
        accumulator, frames = 0, 0

        local list = Players:GetPlayers()
        PlayersValue.Text = tostring(#list)
        MaxValue.Text = tostring(Players.MaxPlayers)
        LatencyValue.Text = settings.diagnostics and Latency() or "—"
        CountryValue.Text = countryCode or "—"
        SessionValue.Text = FormatTime(os.time() - sessionStart)

        local inServer = 0
        for _, player in ipairs(list) do
            if player ~= LocalPlayer and FriendIds[player.UserId] then inServer = inServer + 1 end
        end
        FriendsServerValue.Text = tostring(inServer)
        FriendsAllValue.Text = friendTotal and tostring(friendTotal) or "-"
        FriendsOnlineValue.Text = friendOnline and tostring(friendOnline) or "-"
        FriendsOfflineValue.Text = (friendTotal and friendOnline) and tostring(math.max(friendTotal - friendOnline, 0)) or "-"
    end)

    -- ------------------------------------------------------------------
    -- Encerrar
    -- ------------------------------------------------------------------
    local function ApplyAppearance()
        ResolvePalette()
        for object, properties in pairs(bindings) do
            if object.Parent then
                local colors = {}
                for property, resolve in pairs(properties) do
                    local value = resolve()
                    if typeof(value) == "Color3" then
                        if object[property] ~= value then colors[property] = value end
                    else
                        object[property] = value
                    end
                end
                if next(colors) then Tween(object, colors, 0.17) end
            end
        end
        for _, observer in ipairs(Library.ThemeObservers) do observer() end
        AvatarFrame.Visible = settings.avatar
        GreetingAvatar.Visible = settings.avatar
        MainBackground.BackgroundTransparency = settings.transparency / 100
        UpdateLauncherAppearance()
        if appliedFloatSide ~= settings.floatSide then
            appliedFloatSide = settings.floatSide
            local onRight = appliedFloatSide == "Direita"
            FloatButton.AnchorPoint = Vector2.new(onRight and 1 or 0, 0.5)
            FloatButton.Position = UDim2.new(onRight and 1 or 0, onRight and -14 or 14, 0.5, 0)
        end
        UpdateScale()
    end

    local startupAim = {Aimbot = true, SilentAim = true, AimKill = true}
    local function ApplyProfile(profile, startup)
        local safe = profile.values.safeAimStartup
        if safe == nil then safe = defaults.safeAimStartup end
        loading = true
        for key, control in pairs(registered) do
            local value = profile.values[key]
            if value == nil then value = control.Default end
            if key == "autoPlaceProfile" then value = settings.autoPlaceProfile end
            if startup and safe and startupAim[key] then value = false end
            control.Set(value)
        end
        loading = false
        ApplyAppearance()
    end

    function Library:BuildSettings(tab)
        local appearance = tab:CreateSection("Appearance", "Paleta, contraste e dimensões")
        local interface = tab:CreateSection("Interface", "Navegação e feedback")
        local performance = tab:CreateSection("Performance", "Atualizações do painel")
        local configuration = tab:CreateSection("Configuration", "Até 16 perfis · salvamento automático")
        local themeChoice = appearance:CreateDropdown({Name = "Tema · aplicação imediata", Options = themeNames, Default = defaults.theme})
        local swatches = appearance:CreateSwatches()
        local function ShowSwatches()
            swatches({Theme.Accent, Theme.AccentDark, Theme.Accent2})
        end
        ShowSwatches()
        local function Message(message, category)
            self:Notify({Title = "VANTA · Configuração", Description = message, Category = category, Force = true})
        end
        table.insert(Library.ThemeObservers, ShowSwatches)
        local function AppearanceChanged()
            if not loading then ApplyAppearance() end
        end
        local function Option(section, method, key, options)
            options.Key, options.Default = key, defaults[key]
            options.Callback = function(value)
                settings[key] = value
                if key == "reduced" or key == "lowPower" or key == "animations" or key == "aimSize"
                    or key == "aimOpacity" or key == "floatOpacity" then
                    AppearanceChanged()
                    return
                end
                if key ~= "floatSize" and key ~= "floatSide" and key ~= "scale" and key ~= "transparency" and key ~= "avatar" and key ~= "density" then return end
                if not loading then
                    AvatarFrame.Visible = settings.avatar
                    GreetingAvatar.Visible = settings.avatar
                    MainBackground.BackgroundTransparency = settings.transparency / 100
                    UpdateLauncherAppearance()
                    if key == "density" or key == "floatSide" then ApplyAppearance() else UpdateScale() end
                end
            end
            return section[method](section, options)
        end

        local themeControl = {Get = function() return settings.theme end}
        function themeControl:Set(value)
            settings.theme = value
            themeChoice:Set(value, true)
            AppearanceChanged()
        end
        Register({Key = "theme"}, themeControl, function(value) return palette[value] and value end)
        local colorControls = {}
        for index, spec in ipairs({{"primary", "Principal"}, {"secondary", "Secundária"}, {"highlight", "Destaque"}}) do
            local key, title = spec[1], spec[2]
            colorControls[index] = appearance:CreateColorPicker({
                Key = key, Name = title, Default = defaults[key],
                Callback = function(value)
                    settings[key] = value
                    AppearanceChanged()
                end,
            })
        end
        themeChoice:OnChange(function(value)
            loading = true
            settings.theme = value
            for _, control in ipairs(colorControls) do control:Set("") end
            loading = false
            ApplyAppearance()
            Changed()
        end)
        appearance:CreateButton({Name = "Restaurar tema padrão", Icon = "↺", Callback = function()
            loading = true
            themeControl:Set(defaults.theme)
            for _, control in ipairs(colorControls) do control:Set("") end
            loading = false
            ApplyAppearance()
            Changed()
        end})

        Option(appearance, "CreateSlider", "scale", {Name = "Escala (%)", Min = 75, Max = 120, Step = 5})
        Option(appearance, "CreateSlider", "transparency", {Name = "Transparência do fundo (%)", Min = 0, Max = 35, Step = 5})
        Option(appearance, "CreateDropdown", "density", {Name = "Densidade", Options = {"Confortável", "Compacta"}})
        Option(interface, "CreateToggle", "avatar", {Name = "Mostrar avatares"})
        Option(interface, "CreateToggle", "animations", {Name = "Animações"})
        Option(interface, "CreateToggle", "reduced", {Name = "Reduzir efeitos visuais"})
        Option(interface, "CreateToggle", "notifications", {Name = "Notificações"})
        Option(interface, "CreateSlider", "notificationSeconds", {Name = "Duração (0 = original)", Min = 0, Max = 8})
        Option(interface, "CreateSlider", "floatSize", {Name = "Launcher · tamanho", Min = 44, Max = 76, Step = 2})
        Option(interface, "CreateSlider", "floatOpacity", {Name = "Launcher · opacidade (%)", Min = 35, Max = 100, Step = 5})
        Option(interface, "CreateSlider", "aimSize", {Name = "AIM · tamanho", Min = 44, Max = 88, Step = 2})
        Option(interface, "CreateSlider", "aimOpacity", {Name = "AIM · opacidade (%)", Min = 35, Max = 100, Step = 5})
        Option(interface, "CreateDropdown", "floatSide", {Name = "Lado do botão", Options = {"Esquerda", "Direita"}})
        Option(interface, "CreateKeybind", "keybind", {Name = "Atalho para abrir / minimizar"})
        Option(performance, "CreateToggle", "lowPower", {Name = "Modo de baixo consumo"})
        Option(performance, "CreateToggle", "diagnostics", {Name = "Mostrar FPS e ping"})
        Option(performance, "CreateSlider", "refreshSeconds", {Name = "Intervalo do painel (s)", Min = 1, Max = 5})

        Option(configuration, "CreateToggle", "autoPlaceProfile", {Name = "Carregar perfil vinculado ao iniciar"})
        Option(configuration, "CreateToggle", "safeAimStartup", {Name = "Iniciar com funções de mira desligadas"})
        local profileStatus = configuration:CreateLabel("")
        local profileName = configuration:CreateInput({Name = "Nome do perfil", Default = "Padrao"})
        local transfer = configuration:CreateInput({Name = "JSON para importar / copiar", Multiline = true})
        local function Refresh()
            local names = {}
            for name in pairs(profiles) do table.insert(names, name) end
            table.sort(names)
            local linked = placeKey and placeProfiles[placeKey] or "sem vínculo"
            profileStatus:Set("Ativo: " .. activeProfile .. "  |  " .. status .. "\nJogo: " ..
                (placeKey or "indisponível") .. "  |  Perfil: " .. linked .. "\n" .. table.concat(names, " · "))
        end
        self.RefreshProfileStatus = Refresh
        local function Commit()
            Changed()
            Flush()
            Refresh()
        end
        local function Select(name)
            activeProfile = name
            ApplyProfile(profiles[name])
            profileName:Set(name)
            Commit()
        end
        local function Name()
            local name = ProfileName(profileName:Get())
            if not name then Message("Use até 32 letras ASCII, números, espaços, hífen ou sublinhado.", "warning") end
            return name
        end
        local function CanAdd(name, renaming)
            if profiles[name] then Message("Já existe um perfil com esse nome.", "warning") return false end
            local count = 0
            for _ in pairs(profiles) do count = count + 1 end
            if count >= 16 and not renaming then Message("Limite de 16 perfis atingido.", "warning") return false end
            return true
        end

        configuration:CreateButton({Name = "Salvar perfil ativo", Icon = "↓", Callback = Commit})
        configuration:CreateButton({Name = "Vincular perfil ativo a este jogo", Icon = "+", Callback = function()
            if not placeKey then Message("PlaceId indisponível.", "warning") return end
            if not placeProfiles[placeKey] then
                local count = 0
                for _ in pairs(placeProfiles) do count = count + 1 end
                if count >= 64 then Message("Limite de 64 jogos atingido.", "warning") return end
            end
            placeProfiles[placeKey] = activeProfile
            Commit()
        end})
        configuration:CreateButton({Name = "Remover vínculo deste jogo", Icon = "×", Callback = function()
            if not placeKey or not placeProfiles[placeKey] then return end
            placeProfiles[placeKey] = nil
            Commit()
        end})
        configuration:CreateButton({Name = "Criar a partir do perfil ativo", Icon = "+", Callback = function()
            local name = Name()
            if not name or not CanAdd(name) then return end
            profiles[activeProfile] = Snapshot()
            profiles[name] = Snapshot()
            Select(name)
        end})
        configuration:CreateButton({Name = "Carregar pelo nome", Icon = "→", Callback = function()
            local name = Name()
            if not name then return end
            if not profiles[name] then Message("Perfil não encontrado.", "warning") return end
            profiles[activeProfile] = Snapshot()
            Select(name)
        end})
        configuration:CreateButton({Name = "Renomear perfil ativo", Icon = "✎", Callback = function()
            local name = Name()
            if not name or not CanAdd(name, true) then return end
            profiles[name], profiles[activeProfile] = Snapshot(), nil
            for id, linked in pairs(placeProfiles) do
                if linked == activeProfile then placeProfiles[id] = name end
            end
            Select(name)
        end})
        configuration:CreateButton({Name = "Excluir perfil pelo nome", Icon = "×", Callback = function()
            local name = Name()
            if not name then return end
            if not profiles[name] then Message("Perfil não encontrado.", "warning") return end
            self:Confirm("Excluir perfil?", name, "Excluir", function()
                profiles[name] = nil
                for id, linked in pairs(placeProfiles) do
                    if linked == name then placeProfiles[id] = nil end
                end
                if name == activeProfile then
                    local replacement = next(profiles)
                    if not replacement then
                        replacement = "Padrao"
                        profiles[replacement] = {values = {}}
                    end
                    Select(replacement)
                else
                    Commit()
                end
            end)
        end})
        configuration:CreateButton({Name = "Exportar JSON", Icon = "↑", Callback = function()
            local ok, json = pcall(HttpService.JSONEncode, HttpService, {schema = 1, profile = Snapshot()})
            if not ok then Message("Falha ao codificar o perfil.", "warning") return end
            transfer:Set(json)
            local copy = setclipboard or toclipboard
            local copied = type(copy) == "function" and pcall(copy, json)
            Message(copied and "JSON copiado." or "JSON disponível no campo de transferência.", "success")
        end})
        configuration:CreateButton({Name = "Importar como novo perfil", Icon = "↓", Callback = function()
            local name = Name()
            if not name or not CanAdd(name) then return end
            local document = Decode(transfer:Get())
            local profile = document and document.schema == 1 and ValidateProfile(document.profile, true)
            if not profile then Message("JSON inválido ou incompatível.", "warning") return end
            profiles[activeProfile] = Snapshot()
            profiles[name] = profile
            Select(name)
        end})
        configuration:CreateButton({Name = "Restaurar padrão no perfil ativo", Icon = "↺", Callback = function()
            self:Confirm("Restaurar configurações?", "Os valores deste perfil voltarão ao padrão.", "Restaurar", function()
                ApplyProfile({values = {}})
                Commit()
            end)
        end})

        if filesAvailable then
            local first, second = ReadSlot(1), ReadSlot(2)
            local recovered = first
            if second and (not first or second.revision > first.revision) then recovered = second end
            if recovered then
                revision, slot = recovered.revision, recovered == first and 1 or 2
                profiles, placeProfiles = recovered.profiles, recovered.places
                settings.autoPlaceProfile = recovered.autoPlace
                activeProfile = (settings.autoPlaceProfile and placeKey and placeProfiles[placeKey]) or recovered.active
                status = "Perfis recuperados do dispositivo"
                ApplyProfile(profiles[activeProfile], true)
                profileName:Set(activeProfile)
            else
                status = "Nenhum perfil válido no dispositivo · aguardando gravação"
            end
        end
        ApplyAppearance()
        Refresh()
    end

    function Library:Destroy()
        if Library.Destroyed then return end
        Flush()
        Library.Destroyed = true
        for _, running in pairs(table.clone(activeTweens)) do
            for _, tween in pairs(table.clone(running)) do
                pcall(function() tween:Cancel() end)
            end
        end
        table.clear(activeTweens)
        for _, connection in ipairs(Library.Connections) do
            pcall(function() connection:Disconnect() end)
        end
        table.clear(Library.Connections)
        for _, drawing in ipairs(Library.Drawings) do
            pcall(function() drawing:Remove() end)
        end
        table.clear(Library.Drawings)
        if env.VANTA_INSTANCE == Library then env.VANTA_INSTANCE = nil end
        if env.VANTA_UI == Library then env.VANTA_UI = nil end
        table.clear(bindings)
        table.clear(Library.ThemeObservers)
        table.clear(Library.Tabs)
        Library.RefreshProfileStatus = nil
        if ScreenGui then ScreenGui:Destroy() end
    end

    function Library:BindThemeColor(object, property, role)
        Bind(object, property, function() return Theme[role] end)
    end

    Library.TrackDrawing = TrackDrawing
    Library.UntrackDrawing = UntrackDrawing
    env.VANTA_INSTANCE = Library

    Library:SetVisible(true)
    return Library
end)()

-- Exporta a interface para a PARTE 2 (execute a parte 2 logo depois)
local __env = (getgenv and getgenv()) or _G
__env.VANTA_UI = VANTA
-- ============================================================================
-- VANTA 5.0 - PARTE 2 (motor: aimbot, silent aim, aim kill e ESP)
-- Execute a PARTE 1 primeiro, depois esta.
-- ============================================================================

local VANTA = ((getgenv and getgenv()) or _G).VANTA_UI
if not VANTA or VANTA.Destroyed then
    warn("[VANTA] Execute a PARTE 1 antes da PARTE 2.")
    return
end

-- ==========================================
-- MOTORES DE JOGO (AIMBOT, SILENT, KILL & ESP)
-- ==========================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local env = (getgenv and getgenv()) or _G
local ACCENT = Color3.fromRGB(190, 35, 55)
local BLUE = Color3.fromRGB(80, 160, 255)

local VIM
pcall(function() VIM = game:GetService("VirtualInputManager") end)

local function Track(connection)
    table.insert(VANTA.Connections, connection)
    return connection
end

local Config = {
    -- aimbot
    Aimbot = false,
    HoldToAim = false,
    Smoothness = 1,
    FOV = 1000,            -- 1000 ou mais = infinito
    MaxDistance = 5000,
    Prediction = 0,
    Sticky = true,
    TargetPart = "Head",
    Priority = "Crosshair",
    TeamCheck = true,
    IgnoreForceField = true,
    WallCheck = true,
    SmartPart = true,      -- se a parte escolhida estiver atras da parede, tenta outra visivel
    DebugWall = false,
    -- silent aim
    SilentAim = false,
    SilentPart = "Head",
    SilentHeadChance = 70,
    SilentFOV = 200,
    SilentHitChance = 100,
    SilentMinRay = 25,
    SilentRaycast = true,
    SilentFindPart = true,
    SilentMouse = true,
    SilentCameraRay = true,
    SilentMouseLoc = false,
    SilentDot = true,
    -- aim kill
    AimKill = false,
    KillHold = false,
    KillMethod = "Auto",
    FireDelay = 0.1,
    KillAlign = 2,
    KillSwitchDelay = 0,
    AutoEquip = true,
    KillNotify = true,
    -- visuais
    FOVOutline = false,
    ESPOffsetY = 0,
    ESPBox = false,
    ESPTracers = false,
    ESPNames = false,
    ESPHealth = false,
    ESPRefreshMs = 150,
    ESPDistance = false,
}

-- ==========================================
-- BOTÃO AIM (segurar para mirar / arrastar)
-- ==========================================
local holding, rightHeld = false, false
local holdInput, btnDragStart, btnStartPos
local moveMode = false

local AimButton, SetAimState = VANTA:CreateAimButton()

local function RefreshAimInput()
    holding = rightHeld or (holdInput ~= nil and not moveMode)
    SetAimState(moveMode and "move" or holding and "hold" or "idle")
end

local function UpdateAimButton()
    AimButton.Visible = Config.HoldToAim or Config.KillHold
    if not AimButton.Visible then holdInput = nil end
    RefreshAimInput()
end

Track(AimButton.InputBegan:Connect(function(input)
    if holdInput or not AimButton.Visible then return end
    if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    holdInput = input
    btnDragStart, btnStartPos = input.Position, AimButton.Position
    RefreshAimInput()
end))
Track(UserInputService.InputChanged:Connect(function(input)
    if not moveMode or not holdInput then return end
    if input == holdInput or (holdInput.UserInputType == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseMovement) then
        AimButton.Position = VANTA.PositionInside(AimButton, btnStartPos, input.Position - btnDragStart)
    end
end))
Track(UserInputService.InputEnded:Connect(function(input)
    if input == holdInput then
        holdInput = nil
        RefreshAimInput()
    elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
        rightHeld = false
        RefreshAimInput()
    end
end))
Track(UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        rightHeld = true
        RefreshAimInput()
    end
end))

-- ==========================================
-- INTERFACE
-- ==========================================
local Window = VANTA

local TabAimbot = Window:CreateTab("Aimbot")
local TabSilent = Window:CreateTab("Silent Aim")
local TabKill = Window:CreateTab("Aim Kill")
local TabESP = Window:CreateTab("Visuals")
local TabSettings = Window:CreateTab("Settings")

local Controls = {}
local Presets = {
    Rage  = { Smoothness = 1, FOV = 1000, MaxDistance = 5000, Sticky = true },
    Legit = { Smoothness = 6, FOV = 150,  MaxDistance = 1000, Sticky = false },
}
local function ApplyPreset(name)
    for key, value in pairs(Presets[name]) do
        if Controls[key] then Controls[key]:Set(value) else Config[key] = value end
    end
end

-- Aimbot
local Core = TabAimbot:CreateSection("Core de Mira")
Core:CreateToggle({ Key = "Aimbot", Name = "Ativar Aimbot", Default = false, Callback = function(v) Config.Aimbot = v end })
Core:CreateToggle({ Key = "HoldToAim",
    Name = "Segurar para mirar (botão AIM)", Default = false,
    Callback = function(v) Config.HoldToAim = v UpdateAimButton() end
})
Core:CreateToggle({
    Name = "Mover botão AIM (arrastar)", Default = false,
    Callback = function(v) moveMode = v holdInput = nil RefreshAimInput() end
})
Core:CreateDropdown({
    Key = "Preset", Name = "Preset", Options = { "Rage", "Legit" }, Default = "Rage",
    PassiveRestore = true,
    Callback = function(v) ApplyPreset(v) end
})

local Tune = TabAimbot:CreateSection("Ajustes (Aimbot e Aim Kill)")
Controls.Smoothness = Tune:CreateSlider({ Key = "Smoothness",
    Name = "Suavização (1 = instantâneo)", Min = 1, Max = 30, Default = 1, Step = 1,
    Callback = function(v) Config.Smoothness = v end
})
Controls.FOV = Tune:CreateSlider({ Key = "FOV",
    Name = "FOV px (1000 = infinito)", Min = 10, Max = 1000, Default = 1000, Step = 10,
    Callback = function(v) Config.FOV = v end
})
Controls.MaxDistance = Tune:CreateSlider({ Key = "MaxDistance",
    Name = "Distância máxima", Min = 50, Max = 5000, Default = 5000, Step = 50,
    Callback = function(v) Config.MaxDistance = v end
})
Tune:CreateSlider({ Key = "Prediction",
    Name = "Previsão de movimento", Min = 0, Max = 0.3, Default = 0, Step = 0.01,
    Callback = function(v) Config.Prediction = v end
})
Controls.Sticky = Tune:CreateToggle({ Key = "Sticky",
    Name = "Travar no alvo (sticky)", Default = true,
    Callback = function(v) Config.Sticky = v end
})

local Target = TabAimbot:CreateSection("Alvo e Wall Check")
Target:CreateDropdown({ Key = "TargetPart",
    Name = "HitPart", Options = { "Head", "Peito", "Torso" }, Default = "Head",
    Callback = function(v) Config.TargetPart = v end
})
Target:CreateDropdown({ Key = "Priority",
    Name = "Prioridade", Options = { "Crosshair", "Distance", "Health" }, Default = "Crosshair",
    Callback = function(v) Config.Priority = v end
})
Target:CreateToggle({ Key = "TeamCheck", Name = "Team Check", Default = true, Callback = function(v) Config.TeamCheck = v end })
Target:CreateToggle({ Key = "IgnoreForceField", Name = "Ignorar alvos com ForceField", Default = true, Callback = function(v) Config.IgnoreForceField = v end })
Target:CreateToggle({ Key = "WallCheck", Name = "Wall Check", Default = true, Callback = function(v) Config.WallCheck = v end })
Target:CreateToggle({ Key = "SmartPart", Name = "Parte visível automática", Default = true, Callback = function(v) Config.SmartPart = v end })
Target:CreateToggle({ Key = "DebugWall", Name = "Debug Wall Check", Default = false, Callback = function(v) Config.DebugWall = v end })

-- Silent Aim
local SilentSection = TabSilent:CreateSection("Silent Aim")
SilentSection:CreateToggle({ Key = "SilentAim", Name = "Ativar Silent Aim", Default = false, Callback = function(v) Config.SilentAim = v end })
SilentSection:CreateDropdown({ Key = "SilentPart",
    Name = "Parte do Silent", Options = { "Head", "Peito", "Torso", "Aleatorio" }, Default = "Head",
    Callback = function(v) Config.SilentPart = v end
})
SilentSection:CreateSlider({ Key = "SilentHeadChance",
    Name = "Chance de Head (modo Aleatorio)", Min = 0, Max = 100, Default = 70, Step = 5,
    Callback = function(v) Config.SilentHeadChance = v end
})
SilentSection:CreateSlider({ Key = "SilentFOV",
    Name = "Silent FOV px (1000 = infinito)", Min = 10, Max = 1000, Default = 200, Step = 10,
    Callback = function(v) Config.SilentFOV = v end
})
SilentSection:CreateSlider({ Key = "SilentHitChance",
    Name = "Chance de redirecionamento (%)", Min = 1, Max = 100, Default = 100, Step = 1,
    Callback = function(v) Config.SilentHitChance = v end
})
SilentSection:CreateSlider({ Key = "SilentMinRay",
    Name = "Tamanho mínimo do raio (filtro)", Min = 5, Max = 200, Default = 25, Step = 5,
    Callback = function(v) Config.SilentMinRay = v end
})
SilentSection:CreateToggle({ Key = "SilentDot", Name = "Mostrar ponto no alvo", Default = true, Callback = function(v) Config.SilentDot = v end })

local MethodSection = TabSilent:CreateSection("Métodos (ligue o que o jogo usa)")
MethodSection:CreateToggle({ Key = "SilentRaycast", Name = "workspace:Raycast", Default = true, Callback = function(v) Config.SilentRaycast = v end })
MethodSection:CreateToggle({ Key = "SilentFindPart", Name = "workspace:FindPartOnRay*", Default = true, Callback = function(v) Config.SilentFindPart = v end })
MethodSection:CreateToggle({ Key = "SilentMouse", Name = "Mouse.Hit / Target / UnitRay", Default = true, Callback = function(v) Config.SilentMouse = v end })
MethodSection:CreateToggle({ Key = "SilentCameraRay", Name = "Camera:ViewportPointToRay", Default = true, Callback = function(v) Config.SilentCameraRay = v end })
MethodSection:CreateToggle({ Key = "SilentMouseLoc", Name = "UserInputService:GetMouseLocation", Default = false, Callback = function(v) Config.SilentMouseLoc = v end })

-- Aim Kill
local KillSection = TabKill:CreateSection("Aim Kill")
KillSection:CreateToggle({ Key = "AimKill", Name = "Ativar Aim Kill (trava + atira)", Default = false, Callback = function(v) Config.AimKill = v end })
KillSection:CreateToggle({ Key = "KillHold",
    Name = "Só quando segurar o botão AIM", Default = false,
    Callback = function(v) Config.KillHold = v UpdateAimButton() end
})
KillSection:CreateDropdown({ Key = "KillMethod",
    Name = "Método de tiro", Options = { "Auto", "Tool", "Mouse", "VIM" }, Default = "Auto",
    Callback = function(v) Config.KillMethod = v end
})
KillSection:CreateSlider({ Key = "FireDelay",
    Name = "Intervalo (Tool / clique) em segundos", Min = 0.03, Max = 1, Default = 0.1, Step = 0.01,
    Callback = function(v) Config.FireDelay = v end
})
KillSection:CreateSlider({ Key = "KillAlign",
    Name = "Tolerância de mira (graus)", Min = 0.5, Max = 10, Default = 2, Step = 0.5,
    Callback = function(v) Config.KillAlign = v end
})
KillSection:CreateSlider({ Key = "KillSwitchDelay",
    Name = "Atraso após kill (ms)", Min = 0, Max = 1000, Default = 0, Step = 50,
    Callback = function(v) Config.KillSwitchDelay = v end
})
KillSection:CreateToggle({ Key = "AutoEquip", Name = "Equipar arma automaticamente", Default = true, Callback = function(v) Config.AutoEquip = v end })
KillSection:CreateToggle({ Key = "KillNotify", Name = "Avisar ao observar abate", Default = true, Callback = function(v) Config.KillNotify = v end })
local KillLabel = KillSection:CreateLabel("Abates observados: 0")

-- ESP
local ESPSection = TabESP:CreateSection("ESP & Markers")
ESPSection:CreateToggle({ Key = "ESPBox", Name = "ESP Box", Default = false, Callback = function(v) Config.ESPBox = v end })
ESPSection:CreateToggle({ Key = "ESPTracers", Name = "ESP Tracers", Default = false, Callback = function(v) Config.ESPTracers = v end })
ESPSection:CreateToggle({ Key = "ESPNames", Name = "ESP Nomes", Default = false, Callback = function(v) Config.ESPNames = v end })
ESPSection:CreateToggle({ Key = "ESPHealth", Name = "ESP Vida", Default = false, Callback = function(v) Config.ESPHealth = v end })
ESPSection:CreateToggle({ Key = "ESPDistance", Name = "ESP Distância", Default = false, Callback = function(v) Config.ESPDistance = v end })
ESPSection:CreateSlider({ Key = "ESPOffsetY",
    Name = "Ajuste Y do desenho (se estiver deslocado)", Min = -60, Max = 60, Default = 0, Step = 1,
    Callback = function(v) Config.ESPOffsetY = v end
})

ESPSection:CreateSlider({
    Key = "ESPRefreshMs", Name = "Intervalo dos dados ESP (ms)", Min = 50, Max = 500, Default = 150, Step = 25,
    Callback = function(v) Config.ESPRefreshMs = v end,
})

local SettingsSection = TabSettings:CreateSection("Sistema & Extras")
SettingsSection:CreateToggle({ Key = "FOVOutline", Name = "Mostrar círculos de FOV", Default = false, Callback = function(v) Config.FOVOutline = v end })
SettingsSection:CreateButton({Name = "Descarregar Interface", Icon = "×", Callback = function()
    VANTA:Confirm("Descarregar VANTA?", "A sessão será encerrada.", "Descarregar", function() VANTA:Destroy() end)
end})
local DiagnosticsSection = TabSettings:CreateSection("Diagnóstico de combate", "Leituras locais · atualização a cada 250 ms")
local SilentStatus = DiagnosticsSection:CreateLabel("Silent Aim · aguardando")
local KillStatus = DiagnosticsSection:CreateLabel("Aim Kill · aguardando")
local WallStatus = DiagnosticsSection:CreateLabel("Wall Check · aguardando")

Window:BuildSettings(TabSettings)

local diagnostics = {
    silent = "Desligado", kill = "Desligado", methods = {}, redirected = 0, rejected = 0, skipped = 0,
}
local function RecordSilent(method, outcome)
    diagnostics.methods[method] = true
    diagnostics[outcome] = diagnostics[outcome] + 1
end

local diagnosticElapsed = 0
Track(RunService.Heartbeat:Connect(function(dt)
    if not Window:IsTabVisible(TabSettings) then return end
    diagnosticElapsed = diagnosticElapsed + dt
    if diagnosticElapsed < 0.25 then return end
    diagnosticElapsed = 0
    local methods = {}
    for method in pairs(diagnostics.methods) do table.insert(methods, method) end
    table.sort(methods)
    local message = string.format("Silent Aim · %s\nMétodos observados: %s\nRedirecionamentos: %d · raios filtrados: %d · janelas fora da chance: %d",
        diagnostics.silent, #methods > 0 and table.concat(methods, ", ") or "—",
        diagnostics.redirected, diagnostics.rejected, diagnostics.skipped)
    if diagnostics.rejectReason then message = message .. "\nÚltimo filtro: " .. diagnostics.rejectReason end
    if env.VANTA_HOOKS_V2 and not env.VANTA_MOUSE_DIAGNOSTICS then
        message = message .. "\nReinicie o Roblox para contabilizar Mouse.Hit/Target/UnitRay."
    end
    SilentStatus:Set(message)
    KillStatus:Set("Aim Kill · " .. diagnostics.kill)
    local wall = Config.WallCheck and "Nenhum bloqueio recente" or "Desligado"
    if Config.WallCheck and diagnostics.wallAt and os.clock() - diagnostics.wallAt < 3 then
        wall = "Bloqueio observado: " .. diagnostics.wall
    end
    local part = diagnostics.partAt and os.clock() - diagnostics.partAt < 0.5 and diagnostics.part
    WallStatus:Set("Wall Check · " .. wall .. "\nParte selecionada: " .. (part or "—"))
end))
Window:Notify({Title = "VANTA 5.0", Description = "Interface pronta para uso.", Category = "success"})

-- ==========================================
-- WALL CHECK (com cache por frame)
-- ==========================================
local FrameChars = {}
local VisCache = {}

local function BeginFrame()
    table.clear(FrameChars)
    table.clear(VisCache)
    local players = Players:GetPlayers()
    if Config.WallCheck then
        for _, p in ipairs(players) do
            if p ~= LocalPlayer and p.Character then table.insert(FrameChars, p.Character) end
        end
    end
    return players
end

local lastDebug = 0
local function RaycastVisible(character, part)
    local camera = workspace.CurrentCamera
    if not camera then return true end

    local origin = camera.CFrame.Position
    local targetPos = part.Position

    local ignore = { camera }
    if LocalPlayer.Character then table.insert(ignore, LocalPlayer.Character) end
    for _, c in ipairs(FrameChars) do
        if c ~= character then table.insert(ignore, c) end
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true

    for _ = 1, 10 do
        params.FilterDescendantsInstances = ignore
        local result = workspace:Raycast(origin, targetPos - origin, params)
        if not result then return true end

        local hit = result.Instance
        if hit:IsDescendantOf(character) then return true end

        -- atravessa: invisivel, sem colisao ou colado na camera (viewmodel)
        if hit:IsA("BasePart") and (hit.Transparency >= 0.8 or not hit.CanCollide or (result.Position - origin).Magnitude < 3) then
            table.insert(ignore, hit)
        else
            local now = os.clock()
            if not diagnostics.wallAt or now - diagnostics.wallAt >= 0.25 then
                diagnostics.wall, diagnostics.wallAt = hit:GetFullName(), now
            end
            if Config.DebugWall and now - lastDebug > 0.5 then
                lastDebug = os.clock()
                print("[VANTA Wall] bloqueado por:", hit:GetFullName(),
                    "| Transp:", hit.Transparency, "| CanCollide:", tostring(hit.CanCollide))
            end
            return false
        end
    end
    return false
end

local function IsVisible(character, part)
    if not Config.WallCheck then return true end
    local cached = VisCache[part]
    if cached ~= nil then return cached end
    local visible = RaycastVisible(character, part)
    VisCache[part] = visible
    return visible
end

-- ==========================================
-- ESCOLHA DE ALVO
-- ==========================================
local PartLists = {
    Head  = { "Head", "UpperTorso", "Torso", "HumanoidRootPart" },
    Peito = { "UpperTorso", "Torso", "HumanoidRootPart", "Head" },
    Torso = { "HumanoidRootPart", "UpperTorso", "Torso", "Head" },
}

local function FirstPart(character, list)
    for _, name in ipairs(list) do
        local part = character:FindFirstChild(name)
        if part and part:IsA("BasePart") then return part end
    end
    return nil
end

-- devolve a parte preferida; se estiver atras da parede, tenta as outras (SmartPart)
local function PickPart(character, list)
    for index, name in ipairs(list) do
        local part = character:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            if IsVisible(character, part) then return part end
            if not Config.SmartPart then return nil end
        end
    end
    return nil
end

local function AimPosition(part)
    local pos = part.Position
    if Config.Prediction > 0 and part.Parent then
        local root = part.Parent:FindFirstChild("HumanoidRootPart")
        if root then pos = pos + root.AssemblyLinearVelocity * Config.Prediction end
    end
    return pos
end

-- devolve parte, pontuacao (menor = melhor) e humanoid; ou nil
local function Evaluate(player, camera, center, origin, fov, pref)
    if player == LocalPlayer then return nil end
    local character = player.Character
    if not character then return nil end
    if Config.TeamCheck and player.Team ~= nil and player.Team == LocalPlayer.Team then return nil end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return nil end
    if Config.IgnoreForceField and character:FindFirstChildOfClass("ForceField") then return nil end

    local list = PartLists[pref] or PartLists.Head
    local first = FirstPart(character, list)
    if not first then return nil end

    local dist3d = (first.Position - origin).Magnitude
    if dist3d > Config.MaxDistance then return nil end

    local sp = camera:WorldToViewportPoint(first.Position)
    if sp.Z <= 0 then return nil end

    local pixel = (Vector2.new(sp.X, sp.Y) - center).Magnitude
    if fov < 1000 and pixel > fov then return nil end

    local part = PickPart(character, list)
    if not part then return nil end

    if part ~= first then
        local projected = camera:WorldToViewportPoint(part.Position)
        if projected.Z <= 0 then return nil end
        pixel = (Vector2.new(projected.X, projected.Y) - center).Magnitude
        dist3d = (part.Position - origin).Magnitude
        if (fov < 1000 and pixel > fov) or dist3d > Config.MaxDistance then return nil end
    end

    local score = pixel
    if Config.Priority == "Distance" then
        score = dist3d
    elseif Config.Priority == "Health" then
        score = humanoid.Health
    end
    return part, score, humanoid
end

-- devolve jogador, parte, humanoid
local function FindTarget(fov, locked, pref, players)
    local camera = workspace.CurrentCamera
    if not camera then return nil end
    local viewport = camera.ViewportSize
    local center = Vector2.new(viewport.X / 2, viewport.Y / 2)
    local origin = camera.CFrame.Position

    if Config.Sticky and locked and locked.Parent then
        local part, _, humanoid = Evaluate(locked, camera, center, origin, fov, pref)
        if part then return locked, part, humanoid end
    end

    local bestPlayer, bestPart, bestHumanoid, bestScore = nil, nil, nil, math.huge
    for _, p in ipairs(players) do
        local part, score, humanoid = Evaluate(p, camera, center, origin, fov, pref)
        if part and score < bestScore then
            bestPlayer, bestPart, bestHumanoid, bestScore = p, part, humanoid, score
        end
    end
    return bestPlayer, bestPart, bestHumanoid
end

-- ==========================================
-- SILENT AIM
-- Os hooks sao instalados uma vez por sessao e so repassam para
-- Silent.Handler, entao reexecutar/atualizar o script troca a logica.
-- ==========================================
env.VANTA_SILENT = env.VANTA_SILENT or {}
local Silent = env.VANTA_SILENT
Silent.Enabled, Silent.Pos, Silent.Part, Silent.UnitRay, Silent.ScreenPos = false, nil, nil, nil, nil
Silent.Mouse = LocalPlayer:GetMouse()
Silent.UIS = UserInputService
Silent.MouseHook = true

local HooksSupported = type(hookmetamethod) == "function" and type(getnamecallmethod) == "function" and type(checkcaller) == "function"

if HooksSupported and not env.VANTA_HOOKS_V2 then
    local nc = newcclosure or function(f) return f end

    local oldNamecall
    local namecallOk = env.VANTA_NAMECALL_V2 == true
    if not namecallOk then
        namecallOk, oldNamecall = pcall(hookmetamethod, game, "__namecall", nc(function(self, ...)
            local S = env.VANTA_SILENT
            if S and S.Enabled and S.Pos and S.Handler and not checkcaller() then
                local method = getnamecallmethod()
                if self == workspace or self == S.Camera or self == S.UIS then
                    local out = S.Handler(self, method, oldNamecall, ...)
                    if out then return table.unpack(out, 1, out.n) end
                end
            end
            return oldNamecall(self, ...)
        end))
        namecallOk = namecallOk and type(oldNamecall) == "function"
        env.VANTA_NAMECALL_V2 = namecallOk
    end

    local oldIndex
    local indexOk = env.VANTA_INDEX_V2 == true
    if not indexOk then
        indexOk, oldIndex = pcall(hookmetamethod, game, "__index", nc(function(self, key)
            local S = env.VANTA_SILENT
            if S and S.Enabled and S.Pos and S.MouseHook and self == S.Mouse and not checkcaller() then
                local result
                if key == "Hit" then
                    result = CFrame.new(S.Pos)
                elseif key == "Target" then
                    result = S.Part
                elseif key == "UnitRay" then
                    result = S.UnitRay
                end
                if result then
                    if S.Observe then S.Observe("Mouse." .. key, "redirected") end
                    return result
                end
            end
            return oldIndex(self, key)
        end))
        indexOk = indexOk and type(oldIndex) == "function"
        env.VANTA_INDEX_V2 = indexOk
        if indexOk then env.VANTA_MOUSE_DIAGNOSTICS = true end
    end
    HooksSupported = namecallOk and indexOk
    env.VANTA_HOOKS_V2 = HooksSupported
end
if not HooksSupported then
    VANTA:Notify({Title = "Silent Aim", Description = "Hooks indisponíveis ou instalação incompleta.", Category = "warning", Duration = 5})
end

-- decide se um raio parece ser um tiro (e nao ground check, camera, etc.)
local function ShouldRedirect(origin, direction)
    local camera = workspace.CurrentCamera
    if not camera then
        diagnostics.rejectReason = "Câmera indisponível"
    elseif direction.Magnitude < Config.SilentMinRay then
        diagnostics.rejectReason = "Raio abaixo do mínimo"
    elseif (origin - camera.CFrame.Position).Magnitude > 60 then
        diagnostics.rejectReason = "Origem distante da câmera"
    elseif direction.Unit:Dot(camera.CFrame.LookVector) < 0.2 then
        diagnostics.rejectReason = "Raio fora da direção de tiro"
    else
        return true
    end
    return false
end

local function Retarget(origin, direction)
    local toTarget = Silent.Pos - origin
    local distance, range = toTarget.Magnitude, direction.Magnitude
    if distance <= 1e-4 or distance > range then
        diagnostics.rejectReason = distance > range and "Alvo fora do alcance do raio" or "Direção sem comprimento"
        return nil
    end
    return toTarget / distance * range
end

-- devolve uma tabela empacotada (table.pack) quando tratou a chamada
local function Handler(self, method, oldNC, ...)
    if self == workspace then
        if method == "Raycast" then
            if not Config.SilentRaycast then return nil end
            local origin, direction = ...
            if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
                diagnostics.rejectReason = "Argumentos incompatíveis"
            end
            if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" and ShouldRedirect(origin, direction) then
                local redirected = Retarget(origin, direction)
                if redirected then
                    RecordSilent(method, "redirected")
                    return table.pack(oldNC(self, origin, redirected, select(3, ...)))
                end
            end
            RecordSilent(method, "rejected")
        elseif method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist" then
            if not Config.SilentFindPart then return nil end
            local ray = ...
            if typeof(ray) ~= "Ray" then diagnostics.rejectReason = "Argumentos incompatíveis" end
            if typeof(ray) == "Ray" and ShouldRedirect(ray.Origin, ray.Direction) then
                local redirected = Retarget(ray.Origin, ray.Direction)
                if redirected then
                    RecordSilent(method, "redirected")
                    return table.pack(oldNC(self, Ray.new(ray.Origin, redirected), select(2, ...)))
                end
            end
            RecordSilent(method, "rejected")
        end
    elseif self == Silent.Camera then
        if Config.SilentCameraRay and (method == "ViewportPointToRay" or method == "ScreenPointToRay") then
            local ray = oldNC(self, ...)
            local direction = Silent.Pos - ray.Origin
            if direction.Magnitude <= 1e-4 then
                diagnostics.rejectReason = "Direção sem comprimento"
                RecordSilent(method, "rejected")
                return table.pack(ray)
            end
            RecordSilent(method, "redirected")
            return table.pack(Ray.new(ray.Origin, direction.Unit * ray.Direction.Magnitude))
        end
    elseif self == Silent.UIS then
        if Config.SilentMouseLoc and method == "GetMouseLocation" and Silent.ScreenPos then
            RecordSilent(method, "redirected")
            return table.pack(Silent.ScreenPos)
        end
    end
    return nil
end
Silent.Handler, Silent.Observe = Handler, RecordSilent

local function ClearSilent()
    Silent.Enabled, Silent.Pos, Silent.Part, Silent.UnitRay, Silent.ScreenPos = false, nil, nil, nil, nil
end

local silentLocked = nil
local silentNextRoll, silentRollHead = 0, true

local chanceUntil, chancePassed, lastChance = 0, false, nil

local function UpdateSilent(camera, players)
    if not (Config.SilentAim and HooksSupported) then
        diagnostics.silent = Config.SilentAim and "Hooks indisponíveis" or "Desligado"
        ClearSilent()
        silentLocked = nil
        chanceUntil = 0
        return
    end

    local pref = Config.SilentPart
    if pref == "Aleatorio" then
        if os.clock() >= silentNextRoll then
            silentRollHead = math.random(1, 100) <= Config.SilentHeadChance
            silentNextRoll = os.clock() + 0.25
        end
        pref = silentRollHead and "Head" or "Peito"
    end

    local player, part = FindTarget(Config.SilentFOV, silentLocked, pref, players)
    silentLocked = player
    Silent.MouseHook = Config.SilentMouse
    Silent.Camera = camera

    if part then
        local pos = AimPosition(part)
        local origin = camera.CFrame.Position
        local direction = pos - origin
        if direction.Magnitude <= 1e-4 then ClearSilent() return end
        local now = os.clock()
        if now >= chanceUntil or lastChance ~= Config.SilentHitChance then
            chanceUntil, lastChance = now + 0.065, Config.SilentHitChance
            chancePassed = math.random(1, 100) <= lastChance
            if not chancePassed then diagnostics.skipped = diagnostics.skipped + 1 end
        end
        diagnostics.silent = chancePassed and "Alvo adquirido" or "Chance não atingida"
        local sp = camera:WorldToScreenPoint(pos)
        Silent.Pos, Silent.Part = pos, part
        Silent.UnitRay = Ray.new(origin, direction.Unit)
        Silent.ScreenPos = Vector2.new(sp.X, sp.Y)
        Silent.Enabled = chancePassed
        diagnostics.part, diagnostics.partAt = part.Name, now
    else
        diagnostics.silent = "Sem alvo elegível"
        ClearSilent()
    end
end

-- ==========================================
-- AIM KILL (disparo)
-- ==========================================
local Kill = {last = -math.huge, lastEquip = -math.huge, switchUntil = 0, kills = 0}

local function ReleaseFire()
    local release = Kill.release
    Kill.release, Kill.backend = nil, nil
    if release then pcall(release) end
end

local function ResolveTool()
    local character = LocalPlayer.Character
    if not character then return nil end
    local tool = character:FindFirstChildOfClass("Tool")
    if not tool and Config.AutoEquip and os.clock() - Kill.lastEquip > 0.5 then
        Kill.lastEquip = os.clock()
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local candidate = backpack and backpack:FindFirstChildOfClass("Tool")
        if candidate and humanoid then
            pcall(humanoid.EquipTool, humanoid, candidate)
            tool = character:FindFirstChildOfClass("Tool")
        end
    end
    return tool
end

local function Fire(want)
    if not want then ReleaseFire() return false end
    local method = Config.KillMethod
    local tool
    if method == "Auto" or method == "Tool" then
        tool = ResolveTool()
        if method == "Auto" then method = tool and "Tool" or "Mouse" end
    end

    local backend = method == "Tool" and tool or method
    if Kill.backend ~= backend then ReleaseFire() end
    if Kill.release then
        diagnostics.kill = method .. " · gatilho pressionado"
        return true
    end
    if method == "Tool" and not tool then
        diagnostics.kill = "Tool · sem arma equipada"
        return false
    end
    if tool and not tool.Enabled then
        diagnostics.kill = "Tool · arma desabilitada"
        return false
    end

    local now = os.clock()
    if now - Kill.last < Config.FireDelay then
        diagnostics.kill = method .. " · aguardando intervalo"
        return false
    end
    Kill.last = now
    diagnostics.kill = method .. " · acionando"
    if method == "Tool" and tool and tool.Enabled then
        local ok = pcall(tool.Activate, tool)
        if ok then pcall(tool.Deactivate, tool)
        else diagnostics.kill = "Tool · ativação falhou" end
        return ok
    elseif method == "Mouse" then
        if type(mouse1press) == "function" and type(mouse1release) == "function" then
            if pcall(mouse1press) then
                Kill.backend, Kill.release = backend, mouse1release
                return true
            end
        end
        if type(mouse1click) == "function" and pcall(mouse1click) then return true end
    elseif method == "VIM" and VIM then
        local camera = workspace.CurrentCamera
        if not camera then return false end
        local x, y = camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2
        local function Send(down) VIM:SendMouseButtonEvent(x, y, 0, down, game, 0) end
        if pcall(Send, true) then
            Kill.backend = backend
            Kill.release = function() Send(false) end
            return true
        end
    end
    diagnostics.kill = method .. " · método indisponível ou falhou"
    return false
end

-- ==========================================
-- LOOP PRINCIPAL (aimbot + silent + kill)
-- ==========================================
local lockedPlayer = nil

local function AimStep(dt)
    if VANTA.Destroyed then return end

    local aimbotOn = Config.Aimbot and (not Config.HoldToAim or holding)
    local killOn = Config.AimKill and (not Config.KillHold or holding)

    if not killOn then
        diagnostics.kill = Config.AimKill and "Aguardando botão AIM" or "Desligado"
        Fire(false)
        Kill.humanoid = nil
    end
    if not (aimbotOn or killOn or (Config.SilentAim and HooksSupported)) then
        lockedPlayer, silentLocked = nil, nil
        diagnostics.silent = Config.SilentAim and "Hooks indisponíveis" or "Desligado"
        ClearSilent()
        chanceUntil = 0
        return
    end

    local camera = workspace.CurrentCamera
    local character = LocalPlayer.Character
    local localHumanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not camera or not localHumanoid or localHumanoid.Health <= 0 then
        if killOn then diagnostics.kill = "Sem câmera ou personagem ativo" end
        if Config.SilentAim then diagnostics.silent = "Sem câmera ou personagem ativo" end
        Fire(false)
        ClearSilent()
        lockedPlayer, silentLocked, Kill.humanoid = nil, nil, nil
        return
    end

    local players = BeginFrame()
    UpdateSilent(camera, players)

    if not (aimbotOn or killOn) then
        lockedPlayer = nil
        return
    end

    -- contagem de kills + atraso antes do proximo alvo
    local now = os.clock()
    if killOn and Kill.humanoid and Kill.humanoid.Parent and Kill.humanoid.Health <= 0 then
        local targetName = Kill.humanoid.Parent.Name
        Kill.humanoid = nil
        Kill.kills = Kill.kills + 1
        KillLabel:Set("Abates observados: " .. Kill.kills)
        Kill.switchUntil = now + Config.KillSwitchDelay / 1000
        lockedPlayer = nil
        if Config.KillNotify then
            VANTA:Notify({ Title = "Aim Kill", Description = "Alvo abatido #" .. Kill.kills .. " · " .. targetName, Duration = 1.5 })
        end
    end
    if killOn and now < Kill.switchUntil then
        diagnostics.kill = "Aguardando troca de alvo"
        Fire(false)
        return
    end

    local player, part, humanoid = FindTarget(Config.FOV, lockedPlayer, Config.TargetPart, players)
    lockedPlayer = player
    if not part then
        if killOn then diagnostics.kill = "Sem alvo elegível" end
        Fire(false)
        Kill.humanoid = nil
        return
    end

    diagnostics.part, diagnostics.partAt = part.Name, now
    local origin = camera.CFrame.Position
    local pos = AimPosition(part)
    local direction = pos - origin
    if direction.Magnitude <= 1e-4 then Fire(false) return end
    local goal = CFrame.new(origin, pos)

    if Config.Smoothness <= 1 then
        camera.CFrame = goal
    else
        camera.CFrame = camera.CFrame:Lerp(goal, 1 - math.exp(-dt * 60 / Config.Smoothness))
    end

    if killOn then
        if Silent.Enabled and Silent.Part and Silent.Part.Parent ~= humanoid.Parent then
            Silent.Enabled = false
            diagnostics.silent = "Em espera · alvo diferente do Aim Kill"
        end
        if Kill.humanoid and Kill.humanoid ~= humanoid then Kill.humanoid = nil end
        local aligned = Config.Smoothness <= 1
            or camera.CFrame.LookVector:Dot(direction.Unit) >= math.cos(math.rad(Config.KillAlign))
        if aligned then
            if Fire(true) then Kill.humanoid = humanoid end
        else
            diagnostics.kill = "Alinhando mira"
            Fire(false)
        end
    end
end

pcall(function() RunService:UnbindFromRenderStep("VANTA_Aim") end)
RunService:BindToRenderStep("VANTA_Aim", Enum.RenderPriority.Camera.Value + 1, AimStep)
table.insert(VANTA.Connections, {
    Disconnect = function() pcall(function() RunService:UnbindFromRenderStep("VANTA_Aim") end) end
})

-- ao fechar a interface: solta o gatilho e desliga os hooks (ficam em passagem direta)
VANTA.ScreenGui.Destroying:Connect(function()
    Config.Aimbot, Config.AimKill, Config.SilentAim = false, false, false
    pcall(function() Fire(false) end)
    ClearSilent()
    if Silent.Handler == Handler then Silent.Handler, Silent.Observe = nil, nil end
    if env.VANTA_INSTANCE == VANTA then env.VANTA_INSTANCE = nil end
end)

-- ==========================================
-- DRAWINGS: FOV, PONTO DO SILENT E ESP
-- ==========================================
local FOVCircle, SilentCircle, SilentDot
local drawingOk = pcall(function()
    FOVCircle = Drawing.new("Circle")
    VANTA.TrackDrawing(FOVCircle)
    FOVCircle.Visible, FOVCircle.Color, FOVCircle.Thickness, FOVCircle.NumSides, FOVCircle.Filled =
        false, ACCENT, 1.2, 64, false

    SilentCircle = Drawing.new("Circle")
    VANTA.TrackDrawing(SilentCircle)
    SilentCircle.Visible, SilentCircle.Color, SilentCircle.Thickness, SilentCircle.NumSides, SilentCircle.Filled =
        false, BLUE, 1.2, 64, false

    SilentDot = Drawing.new("Circle")
    VANTA.TrackDrawing(SilentDot)
    SilentDot.Visible, SilentDot.Color, SilentDot.Radius, SilentDot.NumSides, SilentDot.Filled =
        false, BLUE, 5, 20, true
end)

if not drawingOk then
    VANTA:Notify({ Title = "Aviso", Description = "Executor sem Drawing: ESP e círculos desativados.", Duration = 5 })
end

local ESP = {}
local espWasOn = false
local healthGreen = Color3.fromRGB(70, 190, 120)

local function NewESP()
    local d = {}
    local ok = pcall(function()
        d.box = Drawing.new("Square")
        d.tracer = Drawing.new("Line")
        d.name = Drawing.new("Text")
        d.hpBg = Drawing.new("Square")
        d.hpFill = Drawing.new("Square")
    end)
    for _, o in pairs(d) do VANTA.TrackDrawing(o) end
    if not ok then
        for _, o in pairs(d) do
            pcall(function() o:Remove() end)
            VANTA.UntrackDrawing(o)
        end
        return false
    end
    d.box.Color, d.box.Thickness, d.box.Filled = ACCENT, 1.2, false
    d.tracer.Color, d.tracer.Thickness = ACCENT, 1
    d.name.Color, d.name.Size, d.name.Center, d.name.Outline = Color3.new(1, 1, 1), 13, true, true
    d.hpBg.Filled, d.hpBg.Color = true, Color3.new(0, 0, 0)
    d.hpFill.Filled = true
    for _, o in pairs(d) do o.Visible = false end
    return d
end

local function HideESP(d)
    d.box.Visible, d.tracer.Visible, d.name.Visible = false, false, false
    d.hpBg.Visible, d.hpFill.Visible = false, false
    d.nextRefresh = 0
end

local function RemoveESP(player)
    local d = ESP[player]
    if d then
        for _, o in ipairs({d.box, d.tracer, d.name, d.hpBg, d.hpFill}) do
            pcall(function() o:Remove() end)
            VANTA.UntrackDrawing(o)
        end
    end
    ESP[player] = nil
end

Track(Players.PlayerRemoving:Connect(RemoveESP))

Track(RunService.RenderStepped:Connect(function()
    if VANTA.Destroyed or not drawingOk then return end
    local camera = workspace.CurrentCamera
    if not camera then return end

    local viewport = camera.ViewportSize
    local oy = Config.ESPOffsetY
    local center = Vector2.new(viewport.X / 2, viewport.Y / 2 + oy)

    -- circulos de FOV e ponto do Silent
    FOVCircle.Visible = Config.FOVOutline and (Config.Aimbot or Config.AimKill) and Config.FOV < 1000
    FOVCircle.Radius = Config.FOV
    FOVCircle.Position = center

    SilentCircle.Visible = Config.FOVOutline and Config.SilentAim and Config.SilentFOV < 1000
    SilentCircle.Radius = Config.SilentFOV
    SilentCircle.Position = center

    if Config.SilentDot and Silent.Enabled and Silent.Pos then
        local sp, onScreen = camera:WorldToViewportPoint(Silent.Pos)
        SilentDot.Visible = onScreen
        SilentDot.Position = Vector2.new(sp.X, sp.Y + oy)
    else
        SilentDot.Visible = false
    end

    -- ESP
    local espOn = Config.ESPBox or Config.ESPTracers or Config.ESPNames or Config.ESPHealth or Config.ESPDistance
    if not espOn then
        if espWasOn then
            for _, d in pairs(ESP) do
                if d then HideESP(d) end
            end
            espWasOn = false
        end
        return
    end
    espWasOn = true
    local now = os.clock()
    local mode = (Config.ESPNames and 1 or 0) + (Config.ESPDistance and 2 or 0) + (Config.ESPHealth and 4 or 0)
    local refresh = Config.ESPRefreshMs / 1000

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local d = ESP[player]
            if d == nil then
                d = NewESP()
                ESP[player] = d
            end
            if d then
                local character = player.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                local root = character and (character.PrimaryPart or character:FindFirstChild("HumanoidRootPart"))

                if not humanoid or not root or humanoid.Health <= 0
                    or (Config.TeamCheck and player.Team ~= nil and player.Team == LocalPlayer.Team) then
                    HideESP(d)
                else
                    local pos, onScreen = camera:WorldToViewportPoint(root.Position)
                    if not onScreen then
                        HideESP(d)
                    else
                        local boxCFrame, boxSize = character:GetBoundingBox()
                        local top = camera:WorldToViewportPoint(boxCFrame.Position + Vector3.new(0, boxSize.Y / 2, 0))
                        local bottom = camera:WorldToViewportPoint(boxCFrame.Position - Vector3.new(0, boxSize.Y / 2, 0))

                        local height = math.abs(top.Y - bottom.Y)
                        local width = height / 1.8
                        local posX = pos.X - width / 2
                        local posY = top.Y + oy

                        d.box.Visible = Config.ESPBox
                        if Config.ESPBox then
                            d.box.Size = Vector2.new(width, height)
                            d.box.Position = Vector2.new(posX, posY)
                        end

                        d.tracer.Visible = Config.ESPTracers
                        if Config.ESPTracers then
                            d.tracer.From = Vector2.new(viewport.X / 2, viewport.Y + oy)
                            d.tracer.To = Vector2.new(pos.X, posY + height)
                        end

                        if d.humanoid ~= humanoid or d.mode ~= mode or d.refresh ~= refresh or now >= d.nextRefresh then
                            d.humanoid, d.mode, d.refresh, d.nextRefresh = humanoid, mode, refresh, now + refresh
                            local text = Config.ESPNames and (player.DisplayName or player.Name) or ""
                            if Config.ESPDistance then
                                text = text .. string.format(" [%dm]", math.floor((root.Position - camera.CFrame.Position).Magnitude))
                            end
                            d.hasText = text ~= ""
                            if d.hasText then d.name.Text = text end
                            d.health = nil
                            if Config.ESPHealth and humanoid.MaxHealth > 0 then
                                d.health = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                                d.hpFill.Color = ACCENT:Lerp(healthGreen, d.health)
                            end
                        end

                        d.name.Visible = d.hasText
                        if d.hasText then d.name.Position = Vector2.new(pos.X, posY - 18) end

                        if d.health then
                            local pct = d.health
                            local inner = height * pct
                            d.hpBg.Visible, d.hpFill.Visible = true, true
                            d.hpBg.Size = Vector2.new(3.5, height + 2)
                            d.hpBg.Position = Vector2.new(posX - 7, posY - 1)
                            d.hpFill.Size = Vector2.new(1.5, inner)
                            d.hpFill.Position = Vector2.new(posX - 6, posY + (height - inner))
                        else
                            d.hpBg.Visible, d.hpFill.Visible = false, false
                        end
                    end
                end
            end
        end
    end
end))
