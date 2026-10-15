-- 🌑 DARK HUB v3.2
-- Hub de scripts (interface Rayfield) - Mobile e PC
-- Made by Syntax, Dark & Claude
--
-- Para adicionar um script: acrescente uma linha na tabela HUB abaixo.
-- Campos: name, url (ou run = função local), key (true = precisa de key), warn (aviso curto)

-- Opcional: link RAW deste arquivo, usado pelo botão "Recarregar Hub"
local HUB_URL = "https://raw.githubusercontent.com/Darklindo/Script-test/main/Code.lua"

-- ============================================
-- FERRAMENTAS INTERNAS (sem URL externa)
-- Uma entrada com "run" executa a função e, se ela devolver texto,
-- o texto é copiado para o clipboard.
-- ============================================
local function ScanGame()
    local Players = game:GetService("Players")
    local RS = game:GetService("ReplicatedStorage")
    local lp = Players.LocalPlayer
    local out = {}
    local function add(line) out[#out + 1] = line end
    local function path(inst)
        local ok, p = pcall(function() return inst:GetFullName() end)
        return ok and p or tostring(inst)
    end

    add("=== SCAN DO JOGO ===")
    add("PlaceId: " .. tostring(game.PlaceId) .. " | GameId: " .. tostring(game.GameId))

    -- Remotes
    add("")
    add("--- REMOTES (ReplicatedStorage) ---")
    local nRemotes = 0
    for _, d in ipairs(RS:GetDescendants()) do
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d.ClassName == "UnreliableRemoteEvent" then
            nRemotes = nRemotes + 1
            if nRemotes <= 150 then
                add(d.ClassName .. ": " .. path(d))
            end
        end
    end
    add("Total de remotes: " .. nRemotes)

    -- Ferramentas (picareta etc.)
    add("")
    add("--- FERRAMENTAS ---")
    local containers = { lp:FindFirstChild("Backpack"), lp.Character }
    for ci = 1, 2 do
        local container = containers[ci]
        if container then
            for _, t in ipairs(container:GetChildren()) do
                if t:IsA("Tool") then
                    add("Tool: " .. t.Name .. " (em " .. container.Name .. ")")
                end
            end
        end
    end

    -- Stats do jogador
    add("")
    add("--- LEADERSTATS ---")
    local ls = lp:FindFirstChild("leaderstats")
    if ls then
        for _, v in ipairs(ls:GetChildren()) do
            local ok, val = pcall(function() return v.Value end)
            add(v.ClassName .. " " .. v.Name .. " = " .. tostring(ok and val or "?"))
        end
    else
        add("(sem leaderstats)")
    end

    -- Interface
    add("")
    add("--- INTERFACE (PlayerGui) ---")
    local pg = lp:FindFirstChildOfClass("PlayerGui")
    if pg then
        for _, g in ipairs(pg:GetChildren()) do
            local en = g:IsA("ScreenGui") and tostring(g.Enabled) or "-"
            add(g.ClassName .. ": " .. g.Name .. " (Enabled=" .. en .. ")")
        end
    end

    -- Workspace (nível superior)
    add("")
    add("--- WORKSPACE (nivel superior) ---")
    local shown = 0
    for _, c in ipairs(workspace:GetChildren()) do
        shown = shown + 1
        if shown <= 60 then
            add(c.ClassName .. ": " .. c.Name)
        end
    end
    add("Total no nivel superior: " .. shown)

    -- Busca por palavras-chave + ProximityPrompts
    add("")
    add("--- OBJETOS COM NOMES RELEVANTES (agrupados) ---")
    local keywords = { "ice", "fish", "pickaxe", "sell", "collect", "aquarium", "cash", "river" }
    local groups, order = {}, {}
    local prompts, pOrder = {}, {}
    local i = 0
    for _, d in ipairs(workspace:GetDescendants()) do
        i = i + 1
        if i % 3000 == 0 then task.wait() end

        local lname = d.Name:lower()
        for _, k in ipairs(keywords) do
            if lname:find(k, 1, true) then
                local key = d.ClassName .. ":" .. d.Name
                if not groups[key] then
                    groups[key] = { count = 0, first = path(d) }
                    order[#order + 1] = key
                end
                groups[key].count = groups[key].count + 1
                break
            end
        end

        if d:IsA("ProximityPrompt") then
            local key = tostring(d.ActionText) .. " | " .. tostring(d.ObjectText) .. " | pai: " .. (d.Parent and d.Parent.Name or "?")
            if not prompts[key] then
                prompts[key] = { count = 0, first = path(d) }
                pOrder[#pOrder + 1] = key
            end
            prompts[key].count = prompts[key].count + 1
        end
    end
    for n, key in ipairs(order) do
        if n > 80 then add("... (mais grupos omitidos)") break end
        add(key .. " x" .. groups[key].count .. "  ex: " .. groups[key].first)
    end

    add("")
    add("--- PROXIMITY PROMPTS ---")
    for n, key in ipairs(pOrder) do
        if n > 40 then add("... (mais omitidos)") break end
        add(key .. " x" .. prompts[key].count .. "  ex: " .. prompts[key].first)
    end

    add("")
    add("=== FIM DO SCAN ===")
    return table.concat(out, "\n")
end

local function AntiAFK()
    if getgenv and getgenv().DarkHubAntiAFK then
        return
    end
    if getgenv then
        getgenv().DarkHubAntiAFK = true
    end
    local VU = game:GetService("VirtualUser")
    game:GetService("Players").LocalPlayer.Idled:Connect(function()
        VU:CaptureController()
        VU:ClickButton2(Vector2.new())
    end)
end

-- ============================================
-- DADOS
-- ============================================
local HUB = {
    {
        tab = "🐟 Resgate um Peixe",
        sections = {
            {
                title = "Diagnóstico",
                scripts = {
                    { name = "Scanner do jogo (copia o resultado)", run = ScanGame },
                },
            },
            {
                title = "Utilidades",
                scripts = {
                    { name = "Anti-AFK", run = AntiAFK },
                },
            },
        },
    },
    {
        tab = "🌍 Universal",
        sections = {
            {
                title = "Administração & Comandos",
                scripts = {
                    { name = "Infinite Yield", url = "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source" },
                    { name = "CMD-X", url = "https://raw.githubusercontent.com/CMD-X/CMD-X/master/Source" },
                    { name = "Nameless Admin", url = "https://raw.githubusercontent.com/FilteringEnabled/NamelessAdmin/main/Source" },
                },
            },
            {
                title = "Visual & ESP",
                scripts = {
                    { name = "Universal ESP", url = "https://raw.githubusercontent.com/ic3w0lf22/Unnamed-ESP/master/UnnamedESP.lua" },
                    { name = "AirHub V2 (Aimbot & ESP)", url = "https://raw.githubusercontent.com/Exunys/AirHub-V2/main/src/Main.lua" },
                },
            },
            {
                title = "Movimento",
                scripts = {
                    { name = "Fly GUI V3", url = "https://raw.githubusercontent.com/XNEOFF/FlyGuiV3/main/FlyGuiV3.txt" },
                    { name = "Noclip", url = "https://pastebin.com/raw/XHqcNhEX", warn = "link não verificado" },
                },
            },
            {
                title = "Ferramentas",
                scripts = {
                    { name = "Remote Spy (SimpleSpy V3)", url = "https://raw.githubusercontent.com/infyiff/backup/main/SimpleSpyV3/main.lua" },
                    { name = "Dex Explorer", url = "https://raw.githubusercontent.com/infyiff/backup/main/dex.lua" },
                    { name = "Dark Dex V3", url = "https://raw.githubusercontent.com/Babyhamsta/RBLX_Scripts/main/Universal/BypassedDarkDexV3.lua" },
                    { name = "FPS Unlocker", url = "https://pastebin.com/raw/q4ezfNQF", warn = "link não verificado" },
                },
            },
        },
    },
    {
        tab = "🍎 Blox Fruits",
        sections = {
            {
                title = "Hubs",
                scripts = {
                    { name = "Hoho Hub", url = "https://raw.githubusercontent.com/acsu123/HOHO_H/main/Loading_UI", key = true },
                    { name = "Redz Hub", url = "https://raw.githubusercontent.com/tlredz/Scripts/refs/heads/main/main.luau" },
                    { name = "Speed Hub X", url = "https://raw.githubusercontent.com/AhmadV99/Speed-Hub-X/main/Speed%20Hub%20X.lua" },
                    { name = "Zen Hub", url = "https://raw.githubusercontent.com/Kaizenofficiall/ZenHub/main/Loader" },
                    { name = "Mukuro Hub", url = "https://raw.githubusercontent.com/xQuartyx/DonateMe/main/ScriptLoader", warn = "carrega código de outro servidor" },
                },
            },
        },
    },
    {
        tab = "🔫 Arsenal",
        sections = {
            {
                title = "Hubs",
                scripts = {
                    { name = "Owl Hub", url = "https://raw.githubusercontent.com/CriShoux/OwlHub/master/OwlHub.txt" },
                },
            },
        },
    },
    {
        tab = "🏙️ Da Hood",
        sections = {
            {
                title = "Hubs",
                scripts = {
                    { name = "MTriet Hub", url = "https://raw.githubusercontent.com/Minhtriettt/Free-Script/main/MTriet-Hub.lua" },
                    { name = "SwagMode", url = "https://raw.githubusercontent.com/lerkermer/lua-projects/master/SwagModeV002", key = true, warn = "código ofuscado" },
                },
            },
        },
    },
    {
        tab = "🚓 Jailbreak",
        sections = {
            {
                title = "Hubs",
                scripts = {
                    { name = "V.G Hub", url = "https://raw.githubusercontent.com/1201for/V.G-Hub/main/V.Ghub" },
                    { name = "Nexus", url = "https://raw.githubusercontent.com/s-o-a-b/nexus/main/loadstring", warn = "carrega código de outro repositório" },
                },
            },
        },
    },
    {
        tab = "⚽ Blade Ball",
        sections = {
            {
                title = "Auto Parry",
                scripts = {
                    { name = "Auto Parry + Visualizer", url = "https://raw.githubusercontent.com/Akash1al/Blade-Ball-Updated-Script/refs/heads/main/Blade-Ball-Script", warn = "não revisado por completo" },
                },
            },
        },
    },
    {
        tab = "🎮 Outros Jogos",
        sections = {
            {
                title = "Murder Mystery 2",
                scripts = {
                    { name = "Eclipse Hub", url = "https://raw.githubusercontent.com/Ethanoj1/EclipseMM2/master/Script", warn = "copia texto para o clipboard" },
                },
            },
        },
    },
}

-- ============================================
-- CARREGAR RAYFIELD (derruba instância antiga)
-- ============================================
if getgenv then
    local old = getgenv().DarkHub
    if old then
        pcall(function() old:Destroy() end)
    end
end

local okRay, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)

if not okRay or not Rayfield then
    warn("[Dark Hub] Falha ao carregar o Rayfield: " .. tostring(Rayfield))
    return
end

if getgenv then
    getgenv().DarkHub = Rayfield
end

local ICON = 4483362458

local function Notify(title, content, duration)
    pcall(function()
        Rayfield:Notify({
            Title = title,
            Content = content,
            Duration = duration or 3,
            Image = ICON,
        })
    end)
end

-- ============================================
-- EXECUTOR DE SCRIPTS (baixa, compila e roda com tratamento de erro)
-- ============================================
local running = {}

local function Run(script)
    local key = script.url or script.name
    if running[key] then
        Notify("Aguarde", script.name .. " já está rodando")
        return
    end
    running[key] = true
    Notify("Carregando...", script.name)

    task.spawn(function()
        -- Ferramentas internas (função local)
        if script.run then
            local okRun, result = pcall(script.run)
            running[key] = nil
            if not okRun then
                warn("[Dark Hub] " .. script.name .. ": " .. tostring(result))
                Notify("Erro ❌", script.name .. " falhou")
                return
            end
            if type(result) == "string" and #result > 0 then
                print(result)
                local copied = false
                if setclipboard then
                    copied = pcall(setclipboard, result)
                end
                if copied then
                    Notify("Copiado ✅", "Resultado no clipboard. Cole no chat com o Claude.", 5)
                else
                    Notify("Sem clipboard", "Resultado impresso no console (F9)", 5)
                end
            else
                Notify("Executado ✅", script.name)
            end
            return
        end

        -- Scripts remotos (URL)
        local okGet, src = pcall(function()
            return game:HttpGet(script.url)
        end)

        if not okGet or type(src) ~= "string" or #src == 0 then
            running[key] = nil
            Notify("Erro ❌", "Não consegui baixar " .. script.name)
            return
        end

        local fn = loadstring(src)
        if not fn then
            running[key] = nil
            Notify("Erro ❌", script.name .. ": link morto ou conteúdo inválido")
            return
        end

        local okRun, err = pcall(fn)
        running[key] = nil

        if okRun then
            Notify("Executado ✅", script.name)
        else
            warn("[Dark Hub] " .. script.name .. ": " .. tostring(err))
            Notify("Erro ❌", script.name .. " falhou ao executar")
        end
    end)
end

local function Label(script)
    local text = script.name
    if script.key then
        text = "🔑 " .. text .. " (KEY)"
    else
        text = "⭐ " .. text
    end
    if script.warn then
        text = text .. " ⚠️"
    end
    return text
end

-- ============================================
-- JANELA
-- ============================================
local Window = Rayfield:CreateWindow({
    Name = "🌑 Dark Hub",
    LoadingTitle = "Dark Hub - Loading",
    LoadingSubtitle = "Made by Syntax, Dark & Claude",
    ConfigurationSaving = { Enabled = false },
    Discord = { Enabled = false },
    KeySystem = false,
})

-- Abas geradas a partir da tabela HUB
local totalScripts = 0

for _, game_ in ipairs(HUB) do
    local Tab = Window:CreateTab(game_.tab, ICON)

    for _, section in ipairs(game_.sections) do
        Tab:CreateSection(section.title)

        for _, script in ipairs(section.scripts) do
            totalScripts = totalScripts + 1
            Tab:CreateButton({
                Name = Label(script),
                Callback = function()
                    if script.warn then
                        Notify("Atenção ⚠️", script.name .. ": " .. script.warn, 4)
                    end
                    Run(script)
                end,
            })
        end
    end
end

-- ============================================
-- ABA: CONFIGURAÇÕES
-- ============================================
local ConfigTab = Window:CreateTab("⚙️ Configurações", ICON)

ConfigTab:CreateSection("Informações")
ConfigTab:CreateLabel("🌑 Dark Hub v3.2")
ConfigTab:CreateLabel("👥 By: Syntax, Dark & Claude")
ConfigTab:CreateLabel("🎮 Abas de jogos: " .. #HUB)
ConfigTab:CreateLabel("📜 Scripts: " .. totalScripts)

ConfigTab:CreateSection("Legenda")
ConfigTab:CreateParagraph({
    Title = "🔑 KEY",
    Content = "O script pede uma chave, normalmente obtida no Discord do criador.",
})
ConfigTab:CreateParagraph({
    Title = "⭐ Sem key",
    Content = "Não precisa de chave, é só executar.",
})
ConfigTab:CreateParagraph({
    Title = "⚠️ Aviso",
    Content = "O script tem uma observação (link não verificado, código ofuscado ou carrega código de outro servidor). Um aviso aparece ao clicar.",
})

ConfigTab:CreateSection("Ações")

ConfigTab:CreateButton({
    Name = "🔄 Recarregar Hub",
    Callback = function()
        if not HUB_URL then
            Notify("Sem link", "Defina HUB_URL no topo do script para usar o recarregar", 4)
            return
        end
        pcall(function() Rayfield:Destroy() end)
        task.wait(0.5)
        loadstring(game:HttpGet(HUB_URL))()
    end,
})

ConfigTab:CreateButton({
    Name = "❌ Fechar Hub",
    Callback = function()
        pcall(function() Rayfield:Destroy() end)
    end,
})

ConfigTab:CreateSection("Suporte")
ConfigTab:CreateParagraph({
    Title = "💡 Como usar",
    Content = "1. Escolha a aba do jogo\n2. Clique no script\n3. Aguarde carregar",
})
ConfigTab:CreateParagraph({
    Title = "⚠️ Risco",
    Content = "Cada botão executa código de terceiros. Isso pode causar ban ou comprometer sua conta. Use conta alternativa e só execute links em que você confia.",
})

Notify("Dark Hub carregado 🌑", totalScripts .. " scripts em " .. #HUB .. " abas", 5)
print("[Dark Hub] v3.2 carregado: " .. totalScripts .. " scripts")
