-- ============================================================================
-- VANTA 4.1 Crimson Obsidian Edition (interface estilo Ronix)
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

    local function Tween(object, properties, duration, style, direction)
        local tween = TweenService:Create(
            object,
            TweenInfo.new(duration or 0.2, style or Enum.EasingStyle.Quart, direction or Enum.EasingDirection.Out),
            properties
        )
        tween:Play()
        return tween
    end

    local function Create(className, properties, parent)
        local object = Instance.new(className)
        for property, value in pairs(properties or {}) do
            object[property] = value
        end
        object.Parent = parent
        return object
    end

    local function Corner(parent, radius)
        return Create("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, parent)
    end

    local function Stroke(parent, color, transparency, thickness)
        return Create("UIStroke", {
            Color = color or Theme.Border,
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
        return Create("UIGradient", {
            Color = ColorSequence.new(color0, color1),
            Rotation = rotation or 90
        }, parent)
    end

    local function Text(parent, properties)
        properties.BackgroundTransparency = 1
        properties.Font = properties.Font or Enum.Font.Gotham
        properties.TextSize = properties.TextSize or 12
        properties.TextColor3 = properties.TextColor3 or Theme.Text
        properties.TextXAlignment = properties.TextXAlignment or Enum.TextXAlignment.Left
        return Create("TextLabel", properties, parent)
    end

    -- efeito de clique (encolhe levemente)
    local function AddPress(button)
        local scale = Create("UIScale", { Scale = 1 }, button)
        Connect(button.MouseButton1Down, function() Tween(scale, { Scale = 0.96 }, 0.08) end)
        Connect(button.MouseButton1Up, function() Tween(scale, { Scale = 1 }, 0.18, Enum.EasingStyle.Back) end)
        Connect(button.MouseLeave, function() Tween(scale, { Scale = 1 }, 0.12) end)
    end

    local function Hover(button, normal, hovered)
        Connect(button.MouseEnter, function() Tween(button, { BackgroundColor3 = hovered }, 0.15) end)
        Connect(button.MouseLeave, function() Tween(button, { BackgroundColor3 = normal }, 0.15) end)
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

    -- Root (escala adaptativa + borda animada) e Main (CanvasGroup para fade)
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
    local StrokeGradient = Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.Accent2),
            ColorSequenceKeypoint.new(0.5, Theme.Border),
            ColorSequenceKeypoint.new(1, Theme.Accent)
        })
    }, RootStroke)

    local Main = Create("CanvasGroup", {
        Name = "Main",
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
        ZIndex = 0
    }, Main)
    Gradient(MainBackground, Color3.fromRGB(21, 21, 28), Color3.fromRGB(11, 11, 15), 90)
    local IntroScale = Create("UIScale", { Scale = 0.94 }, Main)
    Library.Main = Main

    -- escala adaptativa a tela (rebind quando a camera mudar)
    local viewportConnection
    local function UpdateScale()
        local camera = workspace.CurrentCamera
        if not camera then return end
        local viewport = camera.ViewportSize
        FitScale.Scale = math.clamp(math.min(viewport.X / 700, viewport.Y / 430), 0.55, 1)
    end
    local function BindCamera()
        if viewportConnection then viewportConnection:Disconnect() viewportConnection = nil end
        local camera = workspace.CurrentCamera
        if camera then
            viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateScale)
        end
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
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = Theme.Surface,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0
    }, Main)
    Create("Frame", {
        Position = UDim2.new(0, 0, 1, -1),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme.Border,
        BorderSizePixel = 0
    }, Topbar)

    local Logo = Create("Frame", {
        Position = UDim2.fromOffset(12, 8),
        Size = UDim2.fromOffset(26, 26),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0
    }, Topbar)
    Corner(Logo, 8)
    Gradient(Logo, Theme.Accent2, Theme.AccentDark, 45)
    Text(Logo, {
        Size = UDim2.fromScale(1, 1), Text = "V", Font = Enum.Font.GothamBlack,
        TextSize = 15, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center
    })

    local TitleLabel = Text(Topbar, {
        Position = UDim2.fromOffset(48, 0),
        Size = UDim2.new(1, -150, 1, 0),
        RichText = true,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = "VANTA  <font color='#87879a'>v4.1</font>"
    })

    task.spawn(function()
        local ok, info = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
        if ok and info and info.Name and TitleLabel.Parent then
            local safe = string.gsub(tostring(info.Name), "[<>&]", "")
            TitleLabel.Text = "VANTA  <font color='#87879a'>" .. safe .. "</font>"
        end
    end)

    local function TopButton(glyph, xOffset)
        local button = Create("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, xOffset, 0.5, 0),
            Size = UDim2.fromOffset(28, 28),
            BackgroundColor3 = Theme.Surface2,
            Text = glyph,
            TextColor3 = Theme.Text,
            TextSize = 16,
            Font = Enum.Font.GothamBold,
            AutoButtonColor = false
        }, Topbar)
        Corner(button, 8)
        Hover(button, Theme.Surface2, Theme.Surface3)
        AddPress(button)
        return button
    end
    local MinButton = TopButton("–", -46)
    local CloseButton = TopButton("×", -12)
    Hover(CloseButton, Theme.Surface2, Theme.AccentDark)

    -- arrastar a janela (corrigido para UIScale)
    local dragging = false
    local dragStart, startPosition
    Connect(Topbar.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = Root.Position
        end
    end)
    Connect(UserInputService.InputChanged, function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            local camera = workspace.CurrentCamera
            local viewport = camera and camera.ViewportSize or Vector2.new(800, 400)
            local x = math.clamp(startPosition.X.Offset + delta.X, -viewport.X / 2 + 60, viewport.X / 2 - 60)
            local y = math.clamp(startPosition.Y.Offset + delta.Y, -viewport.Y / 2 + 40, viewport.Y / 2 - 40)
            Root.Position = UDim2.new(startPosition.X.Scale, x, startPosition.Y.Scale, y)
        end
    end)
    Connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
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
        BackgroundColor3 = Theme.Surface,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0
    }, Main)
    Create("Frame", {
        Position = UDim2.new(1, -1, 0, 0),
        Size = UDim2.new(0, 1, 1, 0),
        BackgroundColor3 = Theme.Border,
        BorderSizePixel = 0
    }, Sidebar)

    local Indicator = Create("Frame", {
        Position = UDim2.fromOffset(8, 10),
        Size = UDim2.fromOffset(36, 36),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 2
    }, Sidebar)
    Corner(Indicator, 10)
    Gradient(Indicator, Theme.Accent, Theme.AccentDark, 45)

    local AvatarFrame = Create("ImageLabel", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 10, 1, -10),
        Size = UDim2.fromOffset(32, 32),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        Image = "",
        ZIndex = 3
    }, Sidebar)
    Corner(AvatarFrame, 16)
    Stroke(AvatarFrame, Theme.Accent, 0.2, 1.5)
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
        local duration = options.Duration or 3
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
            BackgroundColor3 = Theme.Surface,
            BorderSizePixel = 0,
            ZIndex = 102
        }, Wrapper)
        Corner(Card, 10)
        Stroke(Card, Theme.Border)

        local Bar = Create("Frame", {
            Size = UDim2.fromOffset(3, 64),
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0,
            ZIndex = 103
        }, Card)
        Corner(Bar, 2)

        Text(Card, {
            Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -22, 0, 18),
            Text = options.Title or "VANTA", Font = Enum.Font.GothamBold, TextSize = 12, ZIndex = 103
        })
        Text(Card, {
            Position = UDim2.fromOffset(14, 26), Size = UDim2.new(1, -22, 0, 26),
            Text = options.Description or "", TextSize = 10, TextColor3 = Theme.Muted,
            TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 103
        })

        local Progress = Create("Frame", {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 0, 1, 0),
            Size = UDim2.new(1, 0, 0, 2),
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0,
            ZIndex = 103
        }, Card)

        Tween(Card, { Position = UDim2.fromOffset(0, 0) }, 0.35, Enum.EasingStyle.Back)
        Tween(Progress, { Size = UDim2.new(0, 0, 0, 2) }, duration, Enum.EasingStyle.Linear)

        task.delay(duration, function()
            if Wrapper and Wrapper.Parent then
                Tween(Card, { Position = UDim2.fromOffset(270, 0) }, 0.25)
                task.wait(0.28)
                if Wrapper and Wrapper.Parent then Wrapper:Destroy() end
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
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        ZIndex = 51
    }, Overlay)
    Corner(ConfirmCard, 12)
    Stroke(ConfirmCard, Theme.Border)
    local ConfirmScale = Create("UIScale", { Scale = 0.9 }, ConfirmCard)

    local ConfirmTitle = Text(ConfirmCard, {
        Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 20),
        Text = "Descarregar VANTA?", Font = Enum.Font.GothamBold, TextSize = 14, ZIndex = 52
    })
    local ConfirmMessage = Text(ConfirmCard, {
        Position = UDim2.fromOffset(16, 36), Size = UDim2.new(1, -32, 0, 34),
        Text = "A interface e todas as funções serão encerradas.", TextSize = 11,
        TextColor3 = Theme.Muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 52
    })

    local ConfirmYes = Create("TextButton", {
        Position = UDim2.new(0, 16, 1, -42), Size = UDim2.new(0.5, -22, 0, 30),
        BackgroundColor3 = Theme.Accent, Text = "Descarregar", TextColor3 = Color3.new(1, 1, 1),
        TextSize = 12, Font = Enum.Font.GothamBold, AutoButtonColor = false, ZIndex = 52
    }, ConfirmCard)
    Corner(ConfirmYes, 8)
    Hover(ConfirmYes, Theme.Accent, Theme.Accent2)
    AddPress(ConfirmYes)

    local ConfirmNo = Create("TextButton", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 1, -42), Size = UDim2.new(0.5, -22, 0, 30),
        BackgroundColor3 = Theme.Surface3, Text = "Cancelar", TextColor3 = Theme.Text,
        TextSize = 12, Font = Enum.Font.GothamBold, AutoButtonColor = false, ZIndex = 52
    }, ConfirmCard)
    Corner(ConfirmNo, 8)
    Hover(ConfirmNo, Theme.Surface3, Theme.Border)
    AddPress(ConfirmNo)

    local confirmCallback = nil
    local function HideConfirm()
        Tween(Overlay, { BackgroundTransparency = 1 }, 0.15)
        Tween(ConfirmScale, { Scale = 0.9 }, 0.15)
        task.delay(0.16, function() if Overlay.Parent then Overlay.Visible = false end end)
    end

    function Library:Confirm(title, message, yesText, callback)
        ConfirmTitle.Text = title or "Confirmar"
        ConfirmMessage.Text = message or ""
        ConfirmYes.Text = yesText or "Confirmar"
        confirmCallback = callback
        Overlay.Visible = true
        Tween(Overlay, { BackgroundTransparency = 0.45 }, 0.18)
        Tween(ConfirmScale, { Scale = 1 }, 0.25, Enum.EasingStyle.Back)
    end

    Connect(ConfirmYes.MouseButton1Click, function()
        local callback = confirmCallback
        confirmCallback = nil
        HideConfirm()
        if callback then callback() end
    end)
    Connect(ConfirmNo.MouseButton1Click, function()
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
    Corner(FloatButton, 22)
    Gradient(FloatButton, Theme.Accent2, Theme.AccentDark, 45)
    Text(FloatButton, {
        Size = UDim2.fromScale(1, 1), Text = "V", Font = Enum.Font.GothamBlack, TextSize = 20,
        TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 201
    })
    Stroke(FloatButton, Theme.Border, 0.3)

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
            floatDragging, floatMoved = true, 0
            floatStart, floatStartPos = input.Position, FloatButton.Position
        end
    end)
    Connect(UserInputService.InputChanged, function(input)
        if floatDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - floatStart
            floatMoved = math.max(floatMoved, delta.Magnitude)
            FloatButton.Position = UDim2.new(floatStartPos.X.Scale, floatStartPos.X.Offset + delta.X, floatStartPos.Y.Scale, floatStartPos.Y.Offset + delta.Y)
        end
    end)
    Connect(UserInputService.InputEnded, function(input)
        if floatDragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            floatDragging = false
            if floatMoved < 8 then Library:SetVisible(true) end
        end
    end)

    Connect(MinButton.MouseButton1Click, function() Library:SetVisible(false) end)
    Connect(CloseButton.MouseButton1Click, function()
        Library:Confirm("Descarregar VANTA?", "A interface e todas as funções serão encerradas.", "Descarregar", function()
            Library:Destroy()
        end)
    end)
    Connect(UserInputService.InputBegan, function(input, processed)
        if not processed and input.KeyCode == Enum.KeyCode.RightShift then
            Library:SetVisible(not visibleState)
        end
    end)

    -- borda animada
    Connect(RunService.Heartbeat, function(dt)
        if visibleState then
            StrokeGradient.Rotation = (StrokeGradient.Rotation + dt * 45) % 360
        end
    end)

    -- ------------------------------------------------------------------
    -- Abas e secoes
    -- ------------------------------------------------------------------
    local tabSwitchToken = 0

    function Library:CreateTab(name, icon)
        local index = #Library.Tabs + 1
        local y = 10 + (index - 1) * 42

        local NavButton = Create("TextButton", {
            Name = name,
            Position = UDim2.fromOffset(8, y),
            Size = UDim2.fromOffset(36, 36),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 3
        }, Sidebar)
        AddPress(NavButton)

        local IconLabel = Text(NavButton, {
            Size = UDim2.fromScale(1, 1), Text = icon or "•", TextSize = 17,
            Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center,
            TextTransparency = 0.45, ZIndex = 4
        })

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
            ScrollBarImageColor3 = Theme.Accent,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y
        }, PageGroup)
        Padding(Scroll, 2, 8, 2, 8)
        Create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, Scroll)

        local Tab = { Group = PageGroup, Scroll = Scroll, Icon = IconLabel, Y = y }

        local function SelectTab()
            if CurrentTab == Tab then return end
            local previous = CurrentTab
            CurrentTab = Tab
            tabSwitchToken = tabSwitchToken + 1

            if previous then
                previous.Group.Visible = false
                previous.Group.GroupTransparency = 1
                Tween(previous.Icon, { TextTransparency = 0.45 }, 0.15)
            end

            PageGroup.Position = UDim2.fromOffset(0, 12)
            PageGroup.GroupTransparency = 1
            PageGroup.Visible = true
            Tween(PageGroup, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, 0.25)
            Tween(IconLabel, { TextTransparency = 0 }, 0.15)

            Indicator.Visible = true
            Tween(Indicator, { Position = UDim2.fromOffset(8, y) }, 0.28, Enum.EasingStyle.Quart)
        end

        Tab.Select = SelectTab
        Connect(NavButton.MouseButton1Click, SelectTab)
        table.insert(Library.Tabs, Tab)

        if index == 1 then
            Indicator.Position = UDim2.fromOffset(8, y)
            SelectTab()
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
            Corner(Card, 10)
            Stroke(Card, Theme.Border)
            Gradient(Card, Color3.fromRGB(27, 27, 35), Color3.fromRGB(19, 19, 25), 90)
            Padding(Card, 12, 12, 10, 12)
            Create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, Card)

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
                    Text = description, TextSize = 10, TextColor3 = Theme.Muted
                })
            end

            local Section = {}

            -- Toggle ---------------------------------------------------
            function Section:CreateToggle(options)
                options = options or {}
                local value = options.Default == true

                local Row = Create("Frame", {
                    Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Theme.Surface2,
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
                function Control:Set(newValue)
                    value = newValue == true
                    Tween(Track, { BackgroundColor3 = value and Theme.Accent or Theme.Surface3 }, 0.18)
                    Tween(Knob, { Position = value and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }, 0.22, Enum.EasingStyle.Back)
                    if options.Callback then options.Callback(value) end
                end
                function Control:Get() return value end

                Connect(Hit.MouseButton1Click, function() Control:Set(not value) end)
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
                    Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = Theme.Surface2,
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
                    Text = tostring(value), TextColor3 = Theme.Accent2, Font = Enum.Font.GothamBold,
                    TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right
                })

                local Bar = Create("Frame", {
                    Position = UDim2.fromOffset(12, 36), Size = UDim2.new(1, -24, 0, 6),
                    BackgroundColor3 = Theme.Surface3, BorderSizePixel = 0
                }, Row)
                Corner(Bar, 3)

                local normalized0 = (value - minimum) / math.max(maximum - minimum, 1e-6)
                local Fill = Create("Frame", {
                    Size = UDim2.new(normalized0, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0
                }, Bar)
                Corner(Fill, 3)
                Gradient(Fill, Theme.AccentDark, Theme.Accent2, 0)

                local Knob = Create("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(normalized0, 0, 0.5, 0),
                    Size = UDim2.fromOffset(14, 14), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0
                }, Bar)
                Corner(Knob, 7)

                local Hit = Create("TextButton", {
                    Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 30),
                    BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 5
                }, Row)

                local draggingSlider = false
                local Control = {}

                local function Apply(newValue, silent)
                    value = math.clamp(math.floor((newValue - minimum) / step + 0.5) * step + minimum, minimum, maximum)
                    value = tonumber(string.format("%.3f", value))
                    local normalized = (value - minimum) / math.max(maximum - minimum, 1e-6)
                    Tween(Fill, { Size = UDim2.new(normalized, 0, 1, 0) }, 0.06, Enum.EasingStyle.Linear)
                    Tween(Knob, { Position = UDim2.new(normalized, 0, 0.5, 0) }, 0.06, Enum.EasingStyle.Linear)
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

                Connect(Hit.InputBegan, function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        draggingSlider = true
                        Scroll.ScrollingEnabled = false
                        Tween(Knob, { Size = UDim2.fromOffset(18, 18) }, 0.12, Enum.EasingStyle.Back)
                        FromInput(input)
                    end
                end)
                Connect(UserInputService.InputChanged, function(input)
                    if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                        FromInput(input)
                    end
                end)
                Connect(UserInputService.InputEnded, function(input)
                    if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                        draggingSlider = false
                        Scroll.ScrollingEnabled = true
                        Tween(Knob, { Size = UDim2.fromOffset(14, 14) }, 0.12)
                    end
                end)

                return Control
            end

            -- Dropdown -------------------------------------------------
            function Section:CreateDropdown(options)
                options = options or {}
                local items = options.Options or {}
                local selected = options.Default or items[1] or "None"
                local expanded = false
                local listHeight = math.min(#items * 29 + 2, 150)

                local Holder = Create("Frame", {
                    Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Theme.Surface2,
                    BorderSizePixel = 0, ClipsDescendants = true, LayoutOrder = NextOrder()
                }, Card)
                Corner(Holder, 8)

                local Header = Create("TextButton", {
                    Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Text = "",
                    AutoButtonColor = false, ZIndex = 5
                }, Holder)

                Text(Holder, {
                    Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.5, -12, 0, 36),
                    Text = options.Name or "Dropdown", Font = Enum.Font.GothamMedium,
                    TextTruncate = Enum.TextTruncate.AtEnd
                })
                local SelectedLabel = Text(Holder, {
                    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -30, 0, 0), Size = UDim2.new(0.4, 0, 0, 36),
                    Text = tostring(selected), TextColor3 = Theme.Accent2, Font = Enum.Font.GothamBold,
                    TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd
                })
                local Arrow = Text(Holder, {
                    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0), Size = UDim2.fromOffset(16, 36),
                    Text = "v", TextColor3 = Theme.Muted, Font = Enum.Font.GothamBold,
                    TextXAlignment = Enum.TextXAlignment.Center
                })

                local List = Create("ScrollingFrame", {
                    Position = UDim2.fromOffset(6, 40), Size = UDim2.new(1, -12, 0, 0),
                    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
                    ScrollBarImageColor3 = Theme.Accent, CanvasSize = UDim2.new(0, 0, 0, 0),
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
                    Tween(Holder, { Size = UDim2.new(1, 0, 0, 36) }, 0.2)
                    Tween(List, { Size = UDim2.new(1, -12, 0, 0) }, 0.2)
                    Tween(Arrow, { Rotation = 0 }, 0.2)
                end

                for position, item in ipairs(items) do
                    local OptionButton = Create("TextButton", {
                        Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = Theme.Surface3,
                        Text = tostring(item), TextColor3 = Theme.Text, TextSize = 11,
                        Font = Enum.Font.GothamMedium, AutoButtonColor = false, LayoutOrder = position
                    }, List)
                    Corner(OptionButton, 6)
                    optionButtons[item] = OptionButton
                    Connect(OptionButton.MouseButton1Click, function()
                        selected = item
                        SelectedLabel.Text = tostring(item)
                        Refresh()
                        Collapse()
                        if options.Callback then options.Callback(selected) end
                    end)
                end
                Refresh()

                Connect(Header.MouseButton1Click, function()
                    expanded = not expanded
                    if expanded then
                        Tween(Holder, { Size = UDim2.new(1, 0, 0, 36 + listHeight + 10) }, 0.22)
                        Tween(List, { Size = UDim2.new(1, -12, 0, listHeight) }, 0.22)
                        Tween(Arrow, { Rotation = 180 }, 0.2)
                    else
                        Collapse()
                    end
                end)

                local Control = {}
                function Control:Get() return selected end
                function Control:Set(newValue)
                    for _, item in ipairs(items) do
                        if item == newValue then
                            selected = newValue
                            SelectedLabel.Text = tostring(newValue)
                            Refresh()
                            if options.Callback then options.Callback(selected) end
                            return
                        end
                    end
                end
                return Control
            end

            -- Button ---------------------------------------------------
            function Section:CreateButton(options)
                options = options or {}
                local Action = Create("TextButton", {
                    Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = Theme.Surface3,
                    Text = options.Name or "Button", TextColor3 = Theme.Text, TextSize = 12,
                    Font = Enum.Font.GothamBold, AutoButtonColor = false, LayoutOrder = NextOrder()
                }, Card)
                Corner(Action, 8)
                Stroke(Action, Theme.Border)
                Hover(Action, Theme.Surface3, Theme.AccentDark)
                AddPress(Action)
                Connect(Action.MouseButton1Click, function()
                    if options.Callback then options.Callback() end
                end)
                return Action
            end

            -- Label ----------------------------------------------------
            function Section:CreateLabel(text)
                local LabelObject = Text(Card, {
                    Size = UDim2.new(1, 0, 0, 20), Text = text or "", TextSize = 11,
                    TextColor3 = Theme.Muted, TextWrapped = true, RichText = true, LayoutOrder = NextOrder()
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
    Stroke(Greeting, Theme.Border)
    Gradient(Greeting, Color3.fromRGB(38, 24, 30), Color3.fromRGB(20, 20, 26), 0)

    local GreetingAvatar = Create("ImageLabel", {
        Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(48, 48),
        BackgroundColor3 = Theme.Surface3, BorderSizePixel = 0, Image = ""
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
        Text = "@" .. LocalPlayer.Name .. "  •  " .. ExecutorName() .. "  •  RightShift mostra/oculta",
        TextSize = 10, TextColor3 = Theme.Muted, TextTruncate = Enum.TextTruncate.AtEnd
    })

    -- linha com duas colunas
    local Row = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 214), BackgroundTransparency = 1, LayoutOrder = HomeNext()
    }, HomeScroll)

    local function InfoCard(parent, position, size, color0, color1, title, description)
        local Card = Create("Frame", {
            Position = position, Size = size, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0
        }, parent)
        Corner(Card, 10)
        Stroke(Card, Theme.Border)
        Gradient(Card, color0, color1, 45)
        Text(Card, {
            Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 16),
            Text = title, Font = Enum.Font.GothamBold, TextSize = 13
        })
        if description then
            Text(Card, {
                Position = UDim2.fromOffset(12, 24), Size = UDim2.new(1, -24, 0, 12),
                Text = description, TextSize = 9, TextColor3 = Theme.Muted
            })
        end
        return Card
    end

    local function Tile(parent, title, value, order, height)
        local Box = Create("Frame", {
            BackgroundColor3 = Theme.Surface2, BackgroundTransparency = 0.15,
            BorderSizePixel = 0, LayoutOrder = order
        }, parent)
        Corner(Box, 8)
        Text(Box, {
            Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -16, 0, 12),
            Text = title, TextSize = 9, TextColor3 = Theme.Muted, Font = Enum.Font.GothamMedium
        })
        local ValueLabel = Text(Box, {
            Position = UDim2.fromOffset(8, height - 22), Size = UDim2.new(1, -16, 0, 18),
            Text = value, TextSize = 13, Font = Enum.Font.GothamBold, TextTruncate = Enum.TextTruncate.AtEnd
        })
        return ValueLabel, Box
    end

    -- Servidor
    local ServerCard = InfoCard(Row, UDim2.fromOffset(0, 0), UDim2.new(0.5, -5, 1, 0),
        Color3.fromRGB(36, 24, 30), Color3.fromRGB(19, 19, 25), "Servidor", "Informações da sessão atual")
    local ServerGrid = Create("Frame", {
        Position = UDim2.fromOffset(12, 44), Size = UDim2.new(1, -24, 0, 138), BackgroundTransparency = 1
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

    local JoinButton = Create("TextButton", {
        BackgroundColor3 = Theme.AccentDark, Text = "Copiar Join Script", TextColor3 = Color3.new(1, 1, 1),
        TextSize = 11, Font = Enum.Font.GothamBold, AutoButtonColor = false, LayoutOrder = 6
    }, ServerGrid)
    Corner(JoinButton, 8)
    Hover(JoinButton, Theme.AccentDark, Theme.Accent)
    AddPress(JoinButton)
    Connect(JoinButton.MouseButton1Click, function()
        local joinScript = string.format(
            'game:GetService("TeleportService"):TeleportToPlaceInstance(%d, "%s", game.Players.LocalPlayer)',
            game.PlaceId, game.JobId)
        local copy = setclipboard or toclipboard
        if copy then
            pcall(copy, joinScript)
            Library:Notify({ Title = "Join Script", Description = "Copiado para a área de transferência.", Duration = 2 })
        else
            Library:Notify({ Title = "Join Script", Description = "Seu executor não suporta copiar.", Duration = 3 })
        end
    end)

    -- Compatibilidade
    local CompatCard = InfoCard(Row, UDim2.new(0.5, 5, 0, 0), UDim2.new(0.5, -5, 0, 96),
        Color3.fromRGB(120, 24, 40), Color3.fromRGB(34, 16, 24), "Compatibilidade", "Recursos disponíveis no seu executor")
    local function Status(label, ok)
        return string.format("<font color='%s'>%s %s</font>", ok and "#46be78" or "#eb505a", label, ok and "OK" or "X")
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
    Text(CompatCard, {
        Position = UDim2.fromOffset(12, 60), Size = UDim2.new(1, -24, 0, 28),
        Text = Status("Drawing", hasDrawing) .. "   " .. Status("Hooks", hasHooks) .. "\n" .. Status("Clipboard", hasClipboard),
        TextSize = 10, RichText = true, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top
    })

    -- Amigos
    local FriendsCard = InfoCard(Row, UDim2.new(0.5, 5, 0, 106), UDim2.new(0.5, -5, 1, -106),
        Color3.fromRGB(30, 26, 34), Color3.fromRGB(19, 19, 25), "Amigos", nil)
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
            while true do
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

    local sessionStart = os.time()
    local function FormatTime(seconds)
        return string.format("%02d:%02d:%02d", math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), math.floor(seconds % 60))
    end
    local function Latency()
        local ok, value = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
        if ok and value then return string.format("%d ms", math.floor(value)) end
        return "-"
    end

    local accumulator = 1
    Connect(RunService.Heartbeat, function(dt)
        accumulator = accumulator + dt
        if accumulator < 1 then return end
        accumulator = 0
        if not (visibleState and CurrentTab == Home) then return end

        local list = Players:GetPlayers()
        PlayersValue.Text = tostring(#list)
        MaxValue.Text = tostring(Players.MaxPlayers)
        LatencyValue.Text = Latency()
        CountryValue.Text = countryCode or "-"
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
    function Library:Destroy()
        if Library.Destroyed then return end
        Library.Destroyed = true
        for _, connection in ipairs(Library.Connections) do
            pcall(function() connection:Disconnect() end)
        end
        table.clear(Library.Connections)
        for _, drawing in ipairs(Library.Drawings) do
            pcall(function() drawing:Remove() end)
        end
        table.clear(Library.Drawings)
        if env.VANTA_INSTANCE == Library then env.VANTA_INSTANCE = nil end
        if ScreenGui then ScreenGui:Destroy() end
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
-- VANTA 4.1 - PARTE 2 (motor: aimbot, silent aim, aim kill e ESP)
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
local GuiService = game:GetService("GuiService")
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
Window:Notify({ Title = "VANTA 4.1", Description = "Crimson Obsidian carregado com sucesso.", Duration = 3 })

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
Core:CreateToggle({ Name = "Ativar Aimbot", Default = false, Callback = function(v) Config.Aimbot = v end })
Core:CreateToggle({
    Name = "Segurar para mirar (botão AIM)", Default = false,
    Callback = function(v) Config.HoldToAim = v UpdateAimButton() end
})
Core:CreateToggle({
    Name = "Mover botão AIM (arrastar)", Default = false,
    Callback = function(v) moveMode = v end
})
Core:CreateDropdown({
    Name = "Preset", Options = { "Rage", "Legit" }, Default = "Rage",
    Callback = function(v) ApplyPreset(v) end
})

local Tune = TabAimbot:CreateSection("Ajustes (Aimbot e Aim Kill)")
Controls.Smoothness = Tune:CreateSlider({
    Name = "Suavização (1 = instantâneo)", Min = 1, Max = 30, Default = 1, Step = 1,
    Callback = function(v) Config.Smoothness = v end
})
Controls.FOV = Tune:CreateSlider({
    Name = "FOV px (1000 = infinito)", Min = 10, Max = 1000, Default = 1000, Step = 10,
    Callback = function(v) Config.FOV = v end
})
Controls.MaxDistance = Tune:CreateSlider({
    Name = "Distância máxima", Min = 50, Max = 5000, Default = 5000, Step = 50,
    Callback = function(v) Config.MaxDistance = v end
})
Tune:CreateSlider({
    Name = "Previsão de movimento", Min = 0, Max = 0.3, Default = 0, Step = 0.01,
    Callback = function(v) Config.Prediction = v end
})
Controls.Sticky = Tune:CreateToggle({
    Name = "Travar no alvo (sticky)", Default = true,
    Callback = function(v) Config.Sticky = v end
})

local Target = TabAimbot:CreateSection("Alvo e Wall Check")
Target:CreateDropdown({
    Name = "HitPart", Options = { "Head", "Peito", "Torso" }, Default = "Head",
    Callback = function(v) Config.TargetPart = v end
})
Target:CreateDropdown({
    Name = "Prioridade", Options = { "Crosshair", "Distance", "Health" }, Default = "Crosshair",
    Callback = function(v) Config.Priority = v end
})
Target:CreateToggle({ Name = "Team Check", Default = true, Callback = function(v) Config.TeamCheck = v end })
Target:CreateToggle({ Name = "Ignorar alvos com ForceField", Default = true, Callback = function(v) Config.IgnoreForceField = v end })
Target:CreateToggle({ Name = "Wall Check", Default = true, Callback = function(v) Config.WallCheck = v end })
Target:CreateToggle({ Name = "Parte visível automática", Default = true, Callback = function(v) Config.SmartPart = v end })
Target:CreateToggle({ Name = "Debug Wall Check", Default = false, Callback = function(v) Config.DebugWall = v end })

-- Silent Aim
local SilentSection = TabSilent:CreateSection("Silent Aim")
SilentSection:CreateToggle({ Name = "Ativar Silent Aim", Default = false, Callback = function(v) Config.SilentAim = v end })
SilentSection:CreateDropdown({
    Name = "Parte do Silent", Options = { "Head", "Peito", "Torso", "Aleatorio" }, Default = "Head",
    Callback = function(v) Config.SilentPart = v end
})
SilentSection:CreateSlider({
    Name = "Chance de Head (modo Aleatorio)", Min = 0, Max = 100, Default = 70, Step = 5,
    Callback = function(v) Config.SilentHeadChance = v end
})
SilentSection:CreateSlider({
    Name = "Silent FOV px (1000 = infinito)", Min = 10, Max = 1000, Default = 200, Step = 10,
    Callback = function(v) Config.SilentFOV = v end
})
SilentSection:CreateSlider({
    Name = "Hit Chance %", Min = 1, Max = 100, Default = 100, Step = 1,
    Callback = function(v) Config.SilentHitChance = v end
})
SilentSection:CreateSlider({
    Name = "Tamanho mínimo do raio (filtro)", Min = 5, Max = 200, Default = 25, Step = 5,
    Callback = function(v) Config.SilentMinRay = v end
})
SilentSection:CreateToggle({ Name = "Mostrar ponto no alvo", Default = true, Callback = function(v) Config.SilentDot = v end })

local MethodSection = TabSilent:CreateSection("Métodos (ligue o que o jogo usa)")
MethodSection:CreateToggle({ Name = "workspace:Raycast", Default = true, Callback = function(v) Config.SilentRaycast = v end })
MethodSection:CreateToggle({ Name = "workspace:FindPartOnRay*", Default = true, Callback = function(v) Config.SilentFindPart = v end })
MethodSection:CreateToggle({ Name = "Mouse.Hit / Target / UnitRay", Default = true, Callback = function(v) Config.SilentMouse = v end })
MethodSection:CreateToggle({ Name = "Camera:ViewportPointToRay", Default = true, Callback = function(v) Config.SilentCameraRay = v end })
MethodSection:CreateToggle({ Name = "UserInputService:GetMouseLocation", Default = false, Callback = function(v) Config.SilentMouseLoc = v end })

-- Aim Kill
local KillSection = TabKill:CreateSection("Aim Kill")
KillSection:CreateToggle({ Name = "Ativar Aim Kill (trava + atira)", Default = false, Callback = function(v) Config.AimKill = v end })
KillSection:CreateToggle({
    Name = "Só quando segurar o botão AIM", Default = false,
    Callback = function(v) Config.KillHold = v UpdateAimButton() end
})
KillSection:CreateDropdown({
    Name = "Método de tiro", Options = { "Auto", "Tool", "Mouse", "VIM" }, Default = "Auto",
    Callback = function(v) Config.KillMethod = v end
})
KillSection:CreateSlider({
    Name = "Intervalo entre tiros (s) [Tool]", Min = 0.03, Max = 1, Default = 0.1, Step = 0.01,
    Callback = function(v) Config.FireDelay = v end
})
KillSection:CreateSlider({
    Name = "Tolerância de mira (graus)", Min = 0.5, Max = 10, Default = 2, Step = 0.5,
    Callback = function(v) Config.KillAlign = v end
})
KillSection:CreateSlider({
    Name = "Atraso após kill (ms)", Min = 0, Max = 1000, Default = 0, Step = 50,
    Callback = function(v) Config.KillSwitchDelay = v end
})
KillSection:CreateToggle({ Name = "Equipar arma automaticamente", Default = true, Callback = function(v) Config.AutoEquip = v end })
KillSection:CreateToggle({ Name = "Avisar a cada kill", Default = true, Callback = function(v) Config.KillNotify = v end })
local KillLabel = KillSection:CreateLabel("Kills nesta sessão: 0")

-- ESP
local ESPSection = TabESP:CreateSection("ESP & Markers")
ESPSection:CreateToggle({ Name = "ESP Box", Default = false, Callback = function(v) Config.ESPBox = v end })
ESPSection:CreateToggle({ Name = "ESP Tracers", Default = false, Callback = function(v) Config.ESPTracers = v end })
ESPSection:CreateToggle({ Name = "ESP Nomes", Default = false, Callback = function(v) Config.ESPNames = v end })
ESPSection:CreateToggle({ Name = "ESP Vida", Default = false, Callback = function(v) Config.ESPHealth = v end })
ESPSection:CreateToggle({ Name = "ESP Distância", Default = false, Callback = function(v) Config.ESPDistance = v end })
ESPSection:CreateSlider({
    Name = "Ajuste Y do desenho (se estiver deslocado)", Min = -60, Max = 60, Default = 0, Step = 1,
    Callback = function(v) Config.ESPOffsetY = v end
})

local SettingsSection = TabSettings:CreateSection("Sistema & Extras")
SettingsSection:CreateToggle({ Name = "Mostrar círculos de FOV", Default = false, Callback = function(v) Config.FOVOutline = v end })
SettingsSection:CreateButton({ Name = "Descarregar Interface", Callback = function() VANTA:Destroy() end })

-- ==========================================
-- WALL CHECK (com cache por frame)
-- ==========================================
local FrameChars = {}
local VisCache = {}

local function BeginFrame()
    table.clear(FrameChars)
    table.clear(VisCache)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then table.insert(FrameChars, p.Character) end
    end
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
        if hit.Transparency >= 0.8 or not hit.CanCollide or (result.Position - origin).Magnitude < 3 then
            table.insert(ignore, hit)
        else
            if Config.DebugWall and os.clock() - lastDebug > 0.5 then
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

    local score = pixel
    if Config.Priority == "Distance" then
        score = dist3d
    elseif Config.Priority == "Health" then
        score = humanoid.Health
    end
    return part, score, humanoid
end

-- devolve jogador, parte, humanoid
local function FindTarget(fov, locked, pref)
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
    for _, p in ipairs(Players:GetPlayers()) do
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

local HooksSupported = (hookmetamethod ~= nil) and (getnamecallmethod ~= nil) and (checkcaller ~= nil)

if HooksSupported and not env.VANTA_HOOKS_V2 then
    env.VANTA_HOOKS_V2 = true
    local nc = newcclosure or function(f) return f end

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", nc(function(self, ...)
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

    local oldIndex
    oldIndex = hookmetamethod(game, "__index", nc(function(self, key)
        local S = env.VANTA_SILENT
        if S and S.Enabled and S.Pos and S.MouseHook and self == S.Mouse and not checkcaller() then
            if key == "Hit" then
                return CFrame.new(S.Pos)
            elseif key == "Target" then
                return S.Part
            elseif key == "UnitRay" and S.UnitRay then
                return S.UnitRay
            end
        end
        return oldIndex(self, key)
    end))
elseif not HooksSupported then
    VANTA:Notify({ Title = "Silent Aim", Description = "Executor sem hookmetamethod: Silent Aim indisponível.", Duration = 5 })
end

-- decide se um raio parece ser um tiro (e nao ground check, camera, etc.)
local function ShouldRedirect(origin, direction)
    local camera = workspace.CurrentCamera
    if not camera then return false end
    if direction.Magnitude < Config.SilentMinRay then return false end
    if (origin - camera.CFrame.Position).Magnitude > 60 then return false end
    if direction.Unit:Dot(camera.CFrame.LookVector) < 0.2 then return false end
    return math.random(1, 100) <= Config.SilentHitChance
end

local function Retarget(origin, direction)
    local toTarget = Silent.Pos - origin
    local length = math.max(direction.Magnitude, toTarget.Magnitude * 1.05 + 1)
    return toTarget.Unit * length
end

-- devolve uma tabela empacotada (table.pack) quando tratou a chamada
local function Handler(self, method, oldNC, ...)
    if self == workspace then
        if method == "Raycast" then
            if not Config.SilentRaycast then return nil end
            local origin, direction = ...
            if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" and ShouldRedirect(origin, direction) then
                return table.pack(oldNC(self, origin, Retarget(origin, direction), select(3, ...)))
            end
        elseif method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist" then
            if not Config.SilentFindPart then return nil end
            local ray = ...
            if typeof(ray) == "Ray" and ShouldRedirect(ray.Origin, ray.Direction) then
                local newRay = Ray.new(ray.Origin, Retarget(ray.Origin, ray.Direction))
                return table.pack(oldNC(self, newRay, select(2, ...)))
            end
        end
    elseif self == Silent.Camera then
        if Config.SilentCameraRay and (method == "ViewportPointToRay" or method == "ScreenPointToRay") then
            if math.random(1, 100) <= Config.SilentHitChance then
                local ray = oldNC(self, ...)
                local origin = ray.Origin
                return table.pack(Ray.new(origin, (Silent.Pos - origin).Unit * ray.Direction.Magnitude))
            end
        end
    elseif self == Silent.UIS then
        if Config.SilentMouseLoc and method == "GetMouseLocation" and Silent.ScreenPos then
            return table.pack(Silent.ScreenPos)
        end
    end
    return nil
end
Silent.Handler = Handler

local function ClearSilent()
    Silent.Enabled, Silent.Pos, Silent.Part, Silent.UnitRay, Silent.ScreenPos = false, nil, nil, nil, nil
end

local silentLocked = nil
local silentNextRoll, silentRollHead = 0, true

local function UpdateSilent(camera)
    if not (Config.SilentAim and HooksSupported) then
        ClearSilent()
        silentLocked = nil
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

    local player, part = FindTarget(Config.SilentFOV, silentLocked, pref)
    silentLocked = player
    Silent.MouseHook = Config.SilentMouse
    Silent.Camera = camera

    if part then
        local pos = AimPosition(part)
        local origin = camera.CFrame.Position
        local sp = camera:WorldToViewportPoint(pos)
        Silent.Pos, Silent.Part = pos, part
        Silent.UnitRay = Ray.new(origin, (pos - origin).Unit)
        Silent.ScreenPos = Vector2.new(sp.X, sp.Y + GuiService:GetGuiInset().Y)
        Silent.Enabled = true
    else
        ClearSilent()
    end
end

-- ==========================================
-- AIM KILL (disparo)
-- ==========================================
local Kill = { last = 0, down = false, humanoid = nil, counted = false, switchUntil = 0, kills = 0, lastEquip = 0 }

local function PressMouse(down)
    if down then
        if mouse1press then pcall(mouse1press) elseif mouse1click then pcall(mouse1click) end
    elseif mouse1release then
        pcall(mouse1release)
    end
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
        if candidate and humanoid then pcall(function() humanoid:EquipTool(candidate) end) end
    end
    return tool
end

local function Fire(want)
    local method = Config.KillMethod
    local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
    if method == "Auto" then method = tool and "Tool" or "Mouse" end

    if method == "Tool" then
        if want and tool and os.clock() - Kill.last >= Config.FireDelay then
            Kill.last = os.clock()
            pcall(function() tool:Activate() end)
        end
        return
    end

    -- Mouse / VIM: mantem o botao pressionado enquanto houver alvo
    if Kill.down == want then return end
    Kill.down = want
    if method == "VIM" and VIM then
        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(400, 300)
        pcall(function() VIM:SendMouseButtonEvent(viewport.X / 2, viewport.Y / 2, 0, want, game, 0) end)
    else
        PressMouse(want)
    end
end

-- ==========================================
-- LOOP PRINCIPAL (aimbot + silent + kill)
-- ==========================================
local lockedPlayer = nil

local function AimStep(dt)
    if VANTA.Destroyed then return end

    local aimbotOn = Config.Aimbot and (not Config.HoldToAim or holding)
    local killOn = Config.AimKill and (not Config.KillHold or holding)

    if not (aimbotOn or killOn or Config.SilentAim) then
        lockedPlayer, silentLocked = nil, nil
        ClearSilent()
        Fire(false)
        return
    end

    local camera = workspace.CurrentCamera
    if not camera then return end

    BeginFrame()
    UpdateSilent(camera)

    if not (aimbotOn or killOn) then
        lockedPlayer = nil
        Fire(false)
        return
    end

    -- contagem de kills + atraso antes do proximo alvo
    local now = os.clock()
    if killOn and Kill.humanoid and Kill.humanoid.Parent and Kill.humanoid.Health <= 0 and not Kill.counted then
        Kill.counted = true
        Kill.kills = Kill.kills + 1
        KillLabel:Set("Kills nesta sessão: " .. Kill.kills)
        Kill.switchUntil = now + Config.KillSwitchDelay / 1000
        lockedPlayer = nil
        if Config.KillNotify then
            VANTA:Notify({ Title = "Aim Kill", Description = "Kill #" .. Kill.kills .. " - " .. tostring(Kill.humanoid.Parent.Name), Duration = 1.5 })
        end
    end
    if killOn and now < Kill.switchUntil then
        Fire(false)
        return
    end

    local player, part, humanoid = FindTarget(Config.FOV, lockedPlayer, Config.TargetPart)
    lockedPlayer = player
    if not part then
        if killOn then Fire(false) end
        return
    end

    local origin = camera.CFrame.Position
    local pos = AimPosition(part)
    local goal = CFrame.new(origin, pos)

    if Config.Smoothness <= 1 then
        camera.CFrame = goal
    else
        camera.CFrame = camera.CFrame:Lerp(goal, 1 - math.exp(-dt * 60 / Config.Smoothness))
    end

    if killOn then
        if humanoid ~= Kill.humanoid then
            Kill.humanoid, Kill.counted = humanoid, false
        end
        local aligned = Config.Smoothness <= 1
            or camera.CFrame.LookVector:Dot((pos - origin).Unit) >= math.cos(math.rad(Config.KillAlign))
        if aligned then
            ResolveTool()
            Fire(true)
        else
            Fire(false)
        end
    else
        Fire(false)
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
    if Silent.Handler == Handler then Silent.Handler = nil end
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
        for _, o in pairs(d) do pcall(function() o:Remove() end) end
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
    for _, o in pairs(d) do o.Visible = false end
end

local function RemoveESP(player)
    local d = ESP[player]
    if d then
        for _, o in pairs(d) do
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

                        local text = ""
                        if Config.ESPNames then text = player.DisplayName or player.Name end
                        if Config.ESPDistance then
                            text = text .. string.format(" [%dm]", math.floor((root.Position - camera.CFrame.Position).Magnitude))
                        end
                        d.name.Visible = text ~= ""
                        if text ~= "" then
                            d.name.Text = text
                            d.name.Position = Vector2.new(pos.X, posY - 18)
                        end

                        if Config.ESPHealth and humanoid.MaxHealth > 0 then
                            local pct = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                            local inner = height * pct
                            d.hpBg.Visible, d.hpFill.Visible = true, true
                            d.hpBg.Size = Vector2.new(3.5, height + 2)
                            d.hpBg.Position = Vector2.new(posX - 7, posY - 1)
                            d.hpFill.Size = Vector2.new(1.5, inner)
                            d.hpFill.Position = Vector2.new(posX - 6, posY + (height - inner))
                            d.hpFill.Color = ACCENT:Lerp(Color3.fromRGB(70, 190, 120), pct)
                        else
                            d.hpBg.Visible, d.hpFill.Visible = false, false
                        end
                    end
                end
            end
        end
    end
end))
