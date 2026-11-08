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
        ["Midnight Blue"] = {0x0C1220, 0x3460A0, 0x283F68, 0x8FB9FF},
        Emerald = {0x0C1815, 0x217C61, 0x26594D, 0x78E4BB},
        Amethyst = {0x100C19, 0x8849CD, 0x51277D, 0xC898FF},
        Cyberpunk = {0x0C141D, 0x147D8C, 0x73396A, 0xF69CDB},
        ["Pure Black"] = {0x000000, 0x53535F, 0x32323A, 0xD1D1DB},
        Arctic = {0x17222B, 0x426C86, 0x3C5566, 0xABE2FF},
    }
    local themeNames = {"Crimson Obsidian", "Midnight Blue", "Emerald", "Amethyst", "Cyberpunk", "Pure Black", "Arctic"}
    local defaults = {
        theme = "Amethyst", primary = "", secondary = "", highlight = "",
        scale = 100, transparency = 0, density = "Confortável", animations = true,
        reduced = false, lowPower = false, diagnostics = true, avatar = true,
        notifications = true, notificationSeconds = 0, floatSize = 48, floatSide = "Esquerda",
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
        Theme.Border = background:Lerp(white, 0.17)
        Theme.Accent = Color(tonumber(settings.primary, 16) or values[2])
        Theme.AccentDark = Color(tonumber(settings.secondary, 16) or values[3])
        Theme.Accent2 = Color(tonumber(settings.highlight, 16) or values[4])
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
    -- Atlas incorporado das artes Vanta Hub. A cópia local é compartilhada por todos os ícones.
    local atlasRegions = {
        home = {0, 0, 64, 48}, player = {64, 0, 64, 48}, scripts = {128, 0, 64, 48},
        visuals = {192, 0, 64, 48}, settings = {256, 0, 64, 48}, close = {320, 0, 64, 48},
        utils = {384, 0, 64, 48}, logo = {448, 0, 64, 64}, banner = {0, 64, 320, 118},
    }
    local function LoadAtlas()
        local customAsset = type(getcustomasset) == "function" and getcustomasset or getsynasset
        if type(customAsset) ~= "function" then return nil end
        local path = "VantaHub-ui-atlas-v1.png"
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
    local LogoFallback = Text(Logo, {
        Size = UDim2.fromScale(1, 1), Text = "VH", Font = Enum.Font.GothamBlack,
        TextSize = 11, TextColor3 = "@Accent2", TextXAlignment = Enum.TextXAlignment.Center,
    })
    Art(Logo, "logo", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), LogoFallback)

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
    local CloseFallback = Text(CloseButton, {
        Size = UDim2.fromScale(1, 1), Text = "×", TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    Art(CloseButton, "close", UDim2.fromOffset(26, 24), UDim2.fromOffset(1, 2), CloseFallback)


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
    Corner(FloatButton, 24)
    Glow(FloatButton, "AccentDark", 0.75, 40)
    local FloatFallback = Text(FloatButton, {
        Size = UDim2.fromScale(1, 1), Text = "VANTA HUB", Font = Enum.Font.GothamBlack, TextSize = 15,
        TextColor3 = "@Accent2", TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 201,
    })
    Art(FloatButton, "banner", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), FloatFallback, 202)
    local FloatEdge = Stroke(FloatButton, "@Accent2", 0.24, 1.5)
    AddPress(FloatButton)
    Connect(FloatButton.MouseEnter, function() Tween(FloatEdge, {Transparency = 0}, 0.18) end)
    Connect(FloatButton.MouseLeave, function() Tween(FloatEdge, {Transparency = 0.24}, 0.18) end)

    local appliedFloatSide
    local function UpdateFloatSize()
        FloatButton.Size = UDim2.fromOffset(math.round(settings.floatSize * 2.7), settings.floatSize)
    end

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
            local size = ScreenGui.AbsoluteSize
            local buttonSize = FloatButton.AbsoluteSize
            local anchor = FloatButton.AnchorPoint
            local x = math.clamp(floatStartPos.X.Scale * size.X + floatStartPos.X.Offset + delta.X,
                anchor.X * buttonSize.X, math.max(anchor.X * buttonSize.X, size.X - (1 - anchor.X) * buttonSize.X))
            local y = math.clamp(floatStartPos.Y.Scale * size.Y + floatStartPos.Y.Offset + delta.Y,
                buttonSize.Y / 2, math.max(buttonSize.Y / 2, size.Y - buttonSize.Y / 2))
            FloatButton.Position = UDim2.fromOffset(x, y)
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

    local tabArt = {Home = "home", Aimbot = "player", ["Silent Aim"] = "scripts", ["Aim Kill"] = "utils", Visuals = "visuals", Settings = "settings"}
    local icons = {Home = "▦", Aimbot = "◎", ["Silent Aim"] = "◈", ["Aim Kill"] = "◆", Visuals = "◇", Settings = "⚙"}
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

    function Library:CreateTab(name, icon)
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

        local IconLabel = Text(NavButton, {
            Size = UDim2.new(1, 0, 0, 28), Text = icons[name] or icon or "•", TextSize = 17,
            Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center,
            TextTransparency = 0.45, ZIndex = 4
        })

        local IconArt = Art(NavButton, tabArt[name], UDim2.fromOffset(34, 27), UDim2.fromOffset(4, 1), IconLabel, 5)
        if IconArt then IconArt.ImageTransparency = 0.25 end
        Text(NavButton, {
            Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 12),
            Text = navLabels[name] or name, TextSize = 8, Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = "@Text", ZIndex = 4,
        })

        local function SetIconActive(active)
            Tween(IconLabel, {TextTransparency = active and 0 or 0.45}, 0.15)
            if IconArt then Tween(IconArt, {ImageTransparency = active and 0 or 0.25}, 0.15) end
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
                    Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = "@Surface2",
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
                    Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 30),
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
                local listHeight = math.min(#items * 39 + 2, 150)

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
                        Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = "@Surface3",
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
    local Home = Library:CreateTab("Home", "🏠")
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

    local BrandCard = InfoCard(Row, UDim2.fromOffset(0, 246), UDim2.new(0.5, -5, 0, 62),
        "VANTA HUB", "Interface 5.0 · Sessão ativa", "AccentDark")
    local BrandMark = Art(BrandCard, "logo", UDim2.fromOffset(42, 42), UDim2.new(1, -52, 0, 10))
    if BrandMark then BrandMark.ImageTransparency = 0.15 end

    updateDashboardLayout = function(narrow, height)
        Row.Size = UDim2.new(1, 0, 0, narrow and 526 or 308)
        local column = narrow and 1 or 0.5
        local inset = narrow and 0 or -5
        ServerCard.Size = UDim2.new(column, inset, 0, 236)
        BrandCard.Position = UDim2.fromOffset(0, narrow and 464 or 246)
        BrandCard.Size = UDim2.new(column, inset, 0, 62)
        CompatCard.Position = narrow and UDim2.fromOffset(0, 246) or UDim2.new(0.5, 5, 0, 0)
        CompatCard.Size = UDim2.new(column, inset, 0, 96)
        FriendsCard.Position = narrow and UDim2.fromOffset(0, 352) or UDim2.new(0.5, 5, 0, 106)
        FriendsCard.Size = UDim2.new(column, inset, 0, narrow and 102 or 202)
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
        UpdateFloatSize()
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
                if key == "reduced" or key == "lowPower" or key == "animations" then
                    AppearanceChanged()
                    return
                end
                if key ~= "floatSize" and key ~= "floatSide" and key ~= "scale" and key ~= "transparency" and key ~= "avatar" and key ~= "density" then return end
                if not loading then
                    AvatarFrame.Visible = settings.avatar
                    GreetingAvatar.Visible = settings.avatar
                    MainBackground.BackgroundTransparency = settings.transparency / 100
                    UpdateFloatSize()
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
        Option(interface, "CreateSlider", "floatSize", {Name = "Tamanho do botão flutuante", Min = 44, Max = 68, Step = 2})
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
local holding = false
local holdInput = nil
local moveMode = false
local btnDragging, btnDragStart, btnStartPos = false, nil, nil

local AimButton = Instance.new("TextButton")
AimButton.Name = "VANTA_AimButton"
AimButton.AnchorPoint = Vector2.new(1, 0.5)
AimButton.Position = UDim2.new(1, -20, 0.6, 0)
AimButton.Size = UDim2.fromOffset(60, 60)
AimButton.BackgroundColor3 = ACCENT
AimButton.Text = "AIM"
AimButton.TextColor3 = Color3.new(1, 1, 1)
AimButton.TextSize = 14
AimButton.Font = Enum.Font.GothamBold
AimButton.Visible = false
AimButton.Parent = VANTA.ScreenGui
VANTA:BindThemeColor(AimButton, "BackgroundColor3", "Accent")
Instance.new("UICorner", AimButton).CornerRadius = UDim.new(1, 0)

local function UpdateAimButton()
    AimButton.Visible = Config.HoldToAim or Config.KillHold
end

local function IsPress(input)
    return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
end

Track(AimButton.InputBegan:Connect(function(input)
    if not IsPress(input) then return end
    holdInput = input
    if moveMode then
        btnDragging = true
        btnDragStart = input.Position
        btnStartPos = AimButton.Position
    else
        holding = true
    end
end))
Track(AimButton.InputEnded:Connect(function(input)
    if IsPress(input) and (input == holdInput or input.UserInputType == Enum.UserInputType.MouseButton1) then
        holding, btnDragging, holdInput = false, false, nil
    end
end))
Track(UserInputService.InputChanged:Connect(function(input)
    if btnDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - btnDragStart
        AimButton.Position = UDim2.new(btnStartPos.X.Scale, btnStartPos.X.Offset + d.X, btnStartPos.Y.Scale, btnStartPos.Y.Offset + d.Y)
    end
end))
Track(UserInputService.InputEnded:Connect(function(input)
    if holdInput and input == holdInput then
        holding, btnDragging, holdInput = false, false, nil
    end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then holding = false end
end))
Track(UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then holding = true end
end))

-- ==========================================
-- INTERFACE
-- ==========================================
local Window = VANTA

local TabAimbot = Window:CreateTab("Aimbot", "🎯")
local TabSilent = Window:CreateTab("Silent Aim", "🤫")
local TabKill = Window:CreateTab("Aim Kill", "💀")
local TabESP = Window:CreateTab("Visuals", "👁")
local TabSettings = Window:CreateTab("Settings", "⚙")

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
    Callback = function(v) moveMode = v end
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
