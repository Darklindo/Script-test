-- 🌑 DARK HUB v3.9
-- Hub de scripts (interface Rayfield) - Mobile e PC
-- Feito pela Equipe Dark
--
-- Para adicionar um script: acrescente uma linha na tabela HUB abaixo.
-- Campos: name, url (ou run = função local, ou toggle/dropdown), key, warn (aviso curto)

-- Opcional: link RAW deste arquivo, usado pelo botão "Recarregar Hub"
local HUB_URL = "https://raw.githubusercontent.com/Darklindo/Script-test/main/Code.lua"

-- ============================================
-- FERRAMENTAS INTERNAS (sem URL externa)
-- Uma entrada com "run" executa a função e, se ela devolver texto,
-- o texto é copiado para o clipboard.
-- ============================================
-- Pasta do workspace onde ficam os blocos de gelo (esteira local do jogo)
local ICE_FOLDER = "ConveyorLocal"

-- Verifica se "word" aparece como palavra no nome (evita "Device" casar com "ice")
local function hasWord(name, word)
    local lname = name:lower()
    local start = 1
    while true do
        local i, j = lname:find(word, start, true)
        if not i then
            return false
        end
        local before = i > 1 and name:sub(i - 1, i - 1) or ""
        local after = name:sub(j + 1, j + 1)
        local first = name:sub(i, i)
        local beforeOk = (i == 1) or not before:match("%a") or first:match("%u") ~= nil
        local afterOk = (after == "") or not after:match("%l")
            or (after == "s" and not name:sub(j + 2, j + 2):match("%l"))
        if beforeOk and afterOk then
            return true
        end
        start = i + 1
    end
end

local function Say(title, text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 5,
        })
    end)
end

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
    local function attrs(inst)
        local ok, a = pcall(function() return inst:GetAttributes() end)
        if not ok or not a then
            return ""
        end
        local parts = {}
        for k, v in pairs(a) do
            parts[#parts + 1] = tostring(k) .. "=" .. tostring(v)
        end
        table.sort(parts)
        return table.concat(parts, ", ")
    end
    local function describe(inst)
        add(inst.ClassName .. " " .. path(inst))
        local a = attrs(inst)
        if a ~= "" then
            add("  atributos: " .. a)
        end
        local n = 0
        for _, c in ipairs(inst:GetChildren()) do
            n = n + 1
            if n > 15 then
                add("  ... (mais filhos)")
                break
            end
            local line = "  filho: " .. c.ClassName .. " " .. c.Name
            if c:IsA("ValueBase") then
                local ok, val = pcall(function() return c.Value end)
                line = line .. " = " .. tostring(ok and val or "?")
            end
            local ca = attrs(c)
            if ca ~= "" then
                line = line .. " [" .. ca .. "]"
            end
            add(line)
        end
    end

    local function dumpTree(inst, indent, depthLeft, counter)
        if counter.n >= counter.max then
            return
        end
        if inst:IsA("Decal") or inst:IsA("Texture") then
            return
        end
        counter.n = counter.n + 1
        local line = string.rep("  ", indent) .. inst.ClassName .. " " .. inst.Name
        if inst:IsA("ValueBase") then
            local ok, val = pcall(function() return inst.Value end)
            line = line .. " = " .. tostring(ok and val or "?")
        end
        if inst:IsA("TextLabel") or inst:IsA("TextButton") then
            line = line .. " '" .. tostring(inst.Text) .. "'"
        end
        local a = attrs(inst)
        if a ~= "" then
            line = line .. " [" .. a .. "]"
        end
        add(line)
        if depthLeft > 0 then
            for _, c in ipairs(inst:GetChildren()) do
                dumpTree(c, indent + 1, depthLeft - 1, counter)
            end
        end
    end

    add("=== SCAN DO JOGO ===")
    add("PlaceId: " .. tostring(game.PlaceId) .. " | GameId: " .. tostring(game.GameId))

    -- Remotes
    add("")
    add("--- REMOTES (E=Event, F=Function; relativo a ReplicatedStorage) ---")
    local nRemotes = 0
    for _, d in ipairs(RS:GetDescendants()) do
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d.ClassName == "UnreliableRemoteEvent" then
            nRemotes = nRemotes + 1
            if nRemotes <= 600 then
                local tag = d:IsA("RemoteFunction") and "F" or "E"
                local full = path(d):gsub("^ReplicatedStorage%.", "")
                add(tag .. " " .. full)
            end
        end
    end
    add("Total de remotes: " .. nRemotes)

    -- ReplicatedStorage (pastas de dados: peixes, picaretas, mundos, raridades...)
    add("")
    add("--- REPLICATEDSTORAGE (nivel 1 e conteudo) ---")
    local rsN = 0
    for _, c in ipairs(RS:GetChildren()) do
        rsN = rsN + 1
        if rsN > 80 then
            add("... (mais omitidos)")
            break
        end
        local names, k = {}, 0
        for _, cc in ipairs(c:GetChildren()) do
            k = k + 1
            if k > 25 then
                names[#names + 1] = "..."
                break
            end
            names[#names + 1] = cc.Name
        end
        add(c.ClassName .. ": " .. c.Name .. " -> " .. table.concat(names, ", "))
    end

    -- Jogador
    add("")
    add("--- JOGADOR ---")
    local pa = attrs(lp)
    add("Atributos do jogador: " .. (pa ~= "" and pa or "(nenhum)"))
    local ls = lp:FindFirstChild("leaderstats")
    if ls then
        for _, v in ipairs(ls:GetChildren()) do
            local ok, val = pcall(function() return v.Value end)
            add("leaderstat " .. v.ClassName .. " " .. v.Name .. " = " .. tostring(ok and val or "?"))
        end
    else
        add("(sem leaderstats)")
    end
    local containers = { lp:FindFirstChild("Backpack"), lp.Character }
    for ci = 1, 2 do
        local container = containers[ci]
        if container then
            for _, t in ipairs(container:GetChildren()) do
                if t:IsA("Tool") then
                    local ta = attrs(t)
                    add("Tool: " .. t.Name .. " (em " .. container.Name .. ")" .. (ta ~= "" and (" [" .. ta .. "]") or ""))
                end
            end
        end
    end

    add("")
    add("--- FERRAMENTA EM DETALHE (scripts, atributos, remotes dentro dela) ---")
    for ci = 1, 2 do
        local container = containers[ci]
        if container then
            for _, t in ipairs(container:GetChildren()) do
                if t:IsA("Tool") then
                    dumpTree(t, 0, 3, { n = 0, max = 40 })
                    break
                end
            end
        end
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
        add("")
        add("--- BOTOES NA INTERFACE ---")
        local bN = 0
        for _, d in ipairs(pg:GetDescendants()) do
            if d:IsA("TextButton") or d:IsA("ImageButton") then
                local txt = d:IsA("TextButton") and d.Text or ""
                bN = bN + 1
                if bN <= 60 then
                    add(d.ClassName .. " '" .. txt .. "' " .. path(d))
                end
            end
        end
    end

    -- Workspace (nivel superior)
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

    -- Esteira de gelo
    add("")
    add("--- ESTEIRA DE GELO (" .. ICE_FOLDER .. ") ---")
    local conv = workspace:FindFirstChild(ICE_FOLDER)
    if conv then
        local kids = conv:GetChildren()
        add("Blocos agora: " .. #kids .. " | atributos da pasta: " .. attrs(conv))
        for n, blk in ipairs(kids) do
            if n > 3 then
                break
            end
            add("# bloco " .. n)
            dumpTree(blk, 0, 4, { n = 0, max = 60 })
        end
    else
        add("(pasta não encontrada neste mundo)")
    end

    -- Mundos e portais
    add("")
    add("--- MUNDOS E PORTAIS ---")
    for _, nm in ipairs({ "Worlds", "WorldPortals", "TrainingPortals", "BossPortals" }) do
        local f = workspace:FindFirstChild(nm)
        if f then
            local names = {}
            for n, c in ipairs(f:GetChildren()) do
                if n > 25 then
                    names[#names + 1] = "..."
                    break
                end
                names[#names + 1] = c.Name
            end
            add(nm .. ": " .. table.concat(names, ", "))
        end
    end
    local wp = workspace:FindFirstChild("WorldPortals")
    local firstPortal = wp and wp:GetChildren()[1]
    if firstPortal then
        add("# primeiro portal em detalhe")
        dumpTree(firstPortal, 0, 3, { n = 0, max = 40 })
    end
    local pgui = lp:FindFirstChildOfClass("PlayerGui")
    local wpui = pgui and pgui:FindFirstChild("WorldPortalUI")
    if wpui then
        add("# WorldPortalUI em detalhe")
        dumpTree(wpui, 0, 5, { n = 0, max = 90 })
    end

    -- Busca por palavras-chave e ProximityPrompts
    local keywords = {
        "ice", "fish", "pickaxe", "sell", "collect", "aquarium",
        "cash", "river", "world", "portal", "teleport", "rebirth", "unlock",
    }
    local groups, order = {}, {}
    local prompts, pOrder = {}, {}
    local i = 0
    for _, d in ipairs(workspace:GetDescendants()) do
        i = i + 1
        if i % 3000 == 0 then
            task.wait()
        end
        for _, k in ipairs(keywords) do
            if hasWord(d.Name, k) then
                local key = d.ClassName .. ":" .. d.Name
                if not groups[key] then
                    groups[key] = { count = 0, first = path(d), inst = d }
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

    add("")
    add("--- OBJETOS COM NOMES RELEVANTES (agrupados) ---")
    for n, key in ipairs(order) do
        if n > 80 then
            add("... (mais grupos omitidos)")
            break
        end
        add(key .. " x" .. groups[key].count .. "  ex: " .. groups[key].first)
    end

    add("")
    add("--- AMOSTRAS DETALHADAS (atributos e filhos) ---")
    for n, key in ipairs(order) do
        if n > 14 then
            break
        end
        pcall(describe, groups[key].inst)
    end

    add("")
    add("--- PROXIMITY PROMPTS ---")
    for n, key in ipairs(pOrder) do
        if n > 40 then
            add("... (mais omitidos)")
            break
        end
        add(key .. " x" .. prompts[key].count .. "  ex: " .. prompts[key].first)
    end

    add("")
    add("--- RARIDADES VISTAS (cartaz dos blocos + atributo Rarity nas ferramentas) ---")
    local seenR, listR = {}, {}
    local function seeR(r)
        if r and r ~= "" and not seenR[r] then
            seenR[r] = true
            listR[#listR + 1] = r
        end
    end
    if conv then
        for _, blk in ipairs(conv:GetChildren()) do
            local bb = blk:FindFirstChild("PetBillboard", true)
            local lbl = bb and bb:FindFirstChild("Rarity", true)
            if lbl and lbl:IsA("TextLabel") then
                seeR(lbl.Text)
            end
        end
    end
    for ci = 1, 2 do
        local container = containers[ci]
        if container then
            for _, t in ipairs(container:GetChildren()) do
                local r = t:GetAttribute("Rarity")
                if r then
                    seeR(tostring(r))
                end
            end
        end
    end
    add(table.concat(listR, ", "))

    -- Módulos de dados (ordem das raridades, tabelas do gelo e dos mundos)
    local function serv(v, d)
        local t = typeof(v)
        if t == "string" then
            return '"' .. v:sub(1, 30) .. '"'
        elseif t == "number" or t == "boolean" or t == "nil" then
            return tostring(v)
        elseif t == "table" then
            if d >= 3 then
                return "{...}"
            end
            local parts, n = {}, 0
            for k, val in pairs(v) do
                n = n + 1
                if n > 40 then
                    parts[#parts + 1] = "..."
                    break
                end
                parts[#parts + 1] = tostring(k) .. "=" .. serv(val, d + 1)
            end
            return "{" .. table.concat(parts, ", ") .. "}"
        end
        return t
    end
    add("")
    add("--- MODULOS DE DADOS (ReplicatedStorage.Shared) ---")
    local shared = RS:FindFirstChild("Shared")
    local wantedMods, seenMods = {}, {}
    for _, nm in ipairs({ "Quality", "Ice", "World", "Companion" }) do
        wantedMods[#wantedMods + 1] = nm
        seenMods[nm] = true
    end
    if shared then
        for _, c in ipairs(shared:GetChildren()) do
            local ln = c.Name:lower()
            if not seenMods[c.Name] and (ln:find("shop") or ln:find("upgrade") or ln:find("pickaxe")
                or ln:find("rebirth") or ln:find("axe")) then
                wantedMods[#wantedMods + 1] = c.Name
                seenMods[c.Name] = true
            end
        end
    end
    for _, nm in ipairs(wantedMods) do
        local m = shared and shared:FindFirstChild(nm)
        if m then
            add("# Shared." .. nm .. " (" .. m.ClassName .. ")")
            local mods = {}
            if m:IsA("ModuleScript") then
                mods[1] = m
            else
                for _, c in ipairs(m:GetChildren()) do
                    if c:IsA("ModuleScript") and #mods < 4 then
                        mods[#mods + 1] = c
                    end
                end
            end
            for _, mod in ipairs(mods) do
                local okReq, data = pcall(require, mod)
                if okReq then
                    local text = serv(data, 0)
                    add(mod.Name .. " = " .. text:sub(1, 2500))
                else
                    add(mod.Name .. ": require falhou (" .. tostring(data) .. ")")
                end
            end
        end
    end

    -- Mundos (tabela completa) e parkours
    add("")
    add("--- MUNDOS (WorldConfig.Worlds) ---")
    local okW, wcfg = pcall(function() return require(RS.Shared.World.WorldConfig) end)
    if okW and type(wcfg) == "table" and type(wcfg.Worlds) == "table" then
        for _, w in ipairs(wcfg.Worlds) do
            add(tostring(w.Order) .. " " .. tostring(w.Key) .. " | " .. tostring(w.DisplayName)
                .. " | preco=" .. tostring(w.Price) .. " | rebirthGate=" .. tostring(w.RebirthGate)
                .. " | luck=" .. tostring(w.Luck) .. " | obby=" .. serv(w.Obby, 1))
        end
    else
        add("(WorldConfig não pôde ser lido)")
    end

    add("")
    add("--- PARKOURS (Workspace.Obbies) ---")
    local ob = workspace:FindFirstChild("Obbies")
    if ob then
        local names = {}
        for n, c in ipairs(ob:GetChildren()) do
            if n > 20 then
                break
            end
            names[#names + 1] = c.Name
        end
        add("filhos: " .. table.concat(names, ", "))
        local shownO = 0
        for _, d in ipairs(ob:GetDescendants()) do
            if (d.Name == "Start" or d.Name == "Finish") and shownO < 16 then
                shownO = shownO + 1
                local where = d:IsA("BasePart") and tostring(d.Position) or "?"
                add(d.ClassName .. " " .. path(d) .. " pos=" .. where)
            end
        end
        local first = ob:GetChildren()[1]
        if first then
            add("# primeiro parkour em detalhe")
            dumpTree(first, 0, 2, { n = 0, max = 40 })
        end
    else
        add("(Workspace.Obbies não existe)")
    end

    local upUi = pgui and pgui:FindFirstChild("UpgradeShop")
    if upUi then
        add("")
        add("--- UPGRADESHOP (interface) ---")
        dumpTree(upUi, 0, 6, { n = 0, max = 140 })
    end

    local psUi = pgui and pgui:FindFirstChild("PetShop")
    if psUi then
        add("")
        add("--- PETSHOP (interface de pets e ovos) ---")
        dumpTree(psUi, 0, 6, { n = 0, max = 140 })
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
-- GRAVADOR DE REMOTES + HOOK COMPARTILHADO
--   C>S = chamadas FireServer/InvokeServer
--   S>C = dados que o servidor manda para o cliente
-- ============================================
local function serial(v, depth)
    local t = typeof(v)
    if t == "string" then
        return '"' .. v:sub(1, 40) .. '"'
    elseif t == "number" or t == "boolean" or t == "nil" then
        return tostring(v)
    elseif t == "Instance" then
        local ok, p = pcall(function() return v:GetFullName() end)
        return "<" .. (ok and p or v.Name) .. ">"
    elseif t == "table" then
        if depth >= 2 then
            return "{...}"
        end
        local parts, n = {}, 0
        for k, val in pairs(v) do
            n = n + 1
            if n > 10 then
                parts[#parts + 1] = "..."
                break
            end
            parts[#parts + 1] = tostring(k) .. "=" .. serial(val, depth + 1)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return t .. ":" .. tostring(v)
end

-- Caminho do remote lendo só PROPRIEDADES. Chamar métodos (GetFullName etc.)
-- dentro do hook troca o método "FireServer" e a chamada nunca chega ao servidor.
local function remotePath(inst)
    local parts, cur, guard = {}, inst, 0
    while cur and cur ~= game and guard < 12 do
        table.insert(parts, 1, cur.Name)
        cur = cur.Parent
        guard = guard + 1
    end
    return (table.concat(parts, "."):gsub("^ReplicatedStorage%.Remotes%.", ""))
end

local function ensureHook()
    if not (hookmetamethod and getnamecallmethod) then
        return false, "Executor sem hookmetamethod/getnamecallmethod."
    end
    local G = getgenv and getgenv() or _G
    G.DarkHubH3Listeners = G.DarkHubH3Listeners or {}
    if G.DarkHubH3 then
        return true
    end
    G.DarkHubH3 = true

    local old
    local function handler(self, ...)
        local rec = G.DarkHubH3Rec
        local ls = G.DarkHubH3Listeners
        if (rec and rec.active) or (ls and next(ls) ~= nil) then
            local m = getnamecallmethod()
            if (m == "FireServer" or m == "InvokeServer") and typeof(self) == "Instance" then
                local cn = self.ClassName
                if cn == "RemoteEvent" or cn == "RemoteFunction" then
                    local args = table.pack(...)
                    local name = remotePath(self)
                    task.defer(function()
                        if rec and rec.active then
                            pcall(rec.record, "C>S", name, args)
                        end
                        if ls then
                            for _, fn in pairs(ls) do
                                pcall(fn, name, args)
                            end
                        end
                    end)
                end
            end
            if m and setnamecallmethod then
                setnamecallmethod(m)
            end
        end
        return old(self, ...)
    end

    local okHook, res = pcall(function()
        return hookmetamethod(game, "__namecall", newcclosure and newcclosure(handler) or handler)
    end)
    if not okHook then
        G.DarkHubH3 = nil
        return false, "Falha ao instalar o hook: " .. tostring(res)
    end
    old = res
    return true
end

local function RemoteLog(seconds)
    local G = getgenv and getgenv() or _G
    local RS = game:GetService("ReplicatedStorage")

    local state = { active = true, data = {}, order = {} }
    function state.record(dir, name, args)
        local key = dir .. " " .. name
        local rec = state.data[key]
        if not rec then
            if #state.order >= 80 then
                return
            end
            rec = { count = 0, samples = {}, seen = {} }
            state.data[key] = rec
            state.order[#state.order + 1] = key
        end
        rec.count = rec.count + 1
        if #rec.samples < 3 then
            local parts = {}
            for i = 1, args.n do
                parts[i] = serial(args[i], 0)
            end
            local text = "(" .. table.concat(parts, ", ") .. ")"
            if not rec.seen[text] then
                rec.seen[text] = true
                rec.samples[#rec.samples + 1] = text
            end
        end
    end
    G.DarkHubH3Rec = state

    -- Servidor -> cliente: escuta passiva dos grupos que interessam
    local conns = {}
    local remotes = RS:FindFirstChild("Remotes")
    local watch = {
        "Conveyor", "Ice", "Pickaxe", "World", "Travel", "Shop", "Rebirth",
        "Inventory", "Aquarium", "Plot", "Index", "Companion", "FishEgg",
    }
    if remotes then
        for _, folderName in ipairs(watch) do
            local f = remotes:FindFirstChild(folderName)
            if f then
                for _, r in ipairs(f:GetChildren()) do
                    if r:IsA("RemoteEvent") then
                        local label = folderName .. "." .. r.Name
                        conns[#conns + 1] = r.OnClientEvent:Connect(function(...)
                            if state.active then
                                state.record("S>C", label, table.pack(...))
                            end
                        end)
                    end
                end
            end
        end
    end

    local okHook, hookNote = ensureHook()

    Say("Gravando remotes", "Faça as ações à mão por " .. seconds .. "s")
    task.wait(seconds)

    state.active = false
    for _, c in ipairs(conns) do
        pcall(function() c:Disconnect() end)
    end

    local lines = { "=== REMOTES GRAVADOS (" .. seconds .. "s) ===" }
    if not okHook then
        lines[#lines + 1] = tostring(hookNote) .. " Só aparecem as chamadas servidor>cliente (S>C)."
    end
    for _, key in ipairs(state.order) do
        local rec = state.data[key]
        lines[#lines + 1] = key .. " x" .. rec.count .. "  " .. table.concat(rec.samples, " | ")
    end
    if #state.order == 0 then
        lines[#lines + 1] = "Nada foi gravado."
    end
    lines[#lines + 1] = "=== FIM ==="
    return table.concat(lines, "\n")
end

-- ============================================
-- AUTO FARM (EXPERIMENTAL) - Resgate um Peixe
-- Baseado em heurísticas: ajuste CFG depois do scanner.
-- ============================================
local CFG = {
    IceFolder = ICE_FOLDER,                                    -- pasta com os blocos de gelo
    -- Ordem real das raridades (ReplicatedStorage.Shared.World.WorldLadder.Names)
    Rarities = {
        "Common", "Rare", "Epic", "Legendary", "Exotic", "Godly", "Prismatic", "Celestial",
        "Transcendent", "Ethereal", "Genesis", "Mythic", "Eternal", "Sovereign", "Ascendant",
        "Primordial", "Abyssal", "Astral", "Paradox", "Infinite", "Omniscient", "Mythos", "Absolute",
    },
    HitDelay = 0.25,
    ParkHeight = 70,       -- altura do "estacionamento" acima de onde você ligou o auto gelo
    SpawnClear = 30,       -- distância mínima do spawner para engajar um bloco
    HoverY = 4,            -- altura sobre o bloco alvo
    EngageTimeout = 8,     -- tempo máximo batendo no mesmo bloco
    UpgradeDelay = 0.5,
    UpgradeBurst = 8,      -- compras seguidas por rodada
    UpgradeWait = 0.8,     -- espera pela confirmação do servidor
    UpgradeBackoff = 5,    -- espera após falha (sem dinheiro)
    UpgradeMaxFactor = 4,  -- cash >= 4x o último custo e não compra => provável máximo
    UpgradeRetryMax = 120, -- reteste de um upgrade marcado como máximo (s)
    ObbySpeed = 60,        -- velocidade do voo no parkour (studs/s)
    RebirthDelay = 15,
    MergeDelay = 10,
    EquipDelay = 15,
    HatchDelay = 1.5,
    WorldDelay = 8,
}

local Farm = {
    ice = false,
    world = false,
    minRarity = 1,      -- posição mínima em CFG.Rarities
    rank = {},          -- nome (minúsculo) -> posição
    hitUnknown = true,  -- quebrar raridade fora da lista / não detectada
    rebirth = false,
    merge = false,
    equip = false,
    hatch = false,
    hatchArgs = nil,    -- argumentos aprendidos de Companion.Buy
    eggChoice = "Frost",
    eggQty = 1,
    pause = false,       -- true durante viagem de mundo/parkour
    iceRunning = false,
    isolation = 14,      -- distância mínima de outros blocos ao engajar (0 = ignora)
    births = {},
    upgrade = false,
    upSelected = { AxeCount = true, CritLevel = true, AttackSpeed = true },
    cache = {},
    conns = {},
}

for i, r in ipairs(CFG.Rarities) do
    Farm.rank[r:lower()] = i
end

local function lp_()
    return game:GetService("Players").LocalPlayer
end

-- Cada filho da esteira é um bloco; só conta se tiver um "Ice" dentro.
local function iceTargets()
    local list = {}
    local folder = workspace:FindFirstChild(CFG.IceFolder)
    if folder then
        for _, blk in ipairs(folder:GetChildren()) do
            if blk:IsA("Model") and blk:FindFirstChild("Ice", true) then
                list[#list + 1] = blk
            end
        end
    end
    return list
end

-- A raridade fica no cartaz do bloco: Anchor > PetBillboard > Content > Rarity (TextLabel)
local function blockRarity(block)
    local bb = block:FindFirstChild("PetBillboard", true)
    local lbl = bb and bb:FindFirstChild("Rarity", true)
    if lbl and lbl:IsA("TextLabel") then
        local t = lbl.Text:gsub("^%s+", ""):gsub("%s+$", "")
        if t ~= "" then
            return t
        end
    end
    return nil
end

local function rarityOk(block)
    local name = blockRarity(block)
    if not name then
        return Farm.hitUnknown
    end
    local idx = Farm.rank[name:lower()]
    if not idx then
        return Farm.hitUnknown
    end
    return idx >= Farm.minRarity
end

local function getPivotPos(inst)
    local ok, cf = pcall(function() return inst:GetPivot() end)
    if ok then
        return cf
    end
    return nil
end

-- ============================================
-- AUTO GELO (v3.9)
-- Ideia: o jogo tem machados automáticos que batem em QUALQUER bloco perto de
-- você. Por isso o hub fica "estacionado" longe da esteira e só desce quando existe
-- um bloco da raridade escolhida, longe do spawner e sem outros blocos por perto.
-- Quando o alvo quebra, volta para o estacionamento.
-- ============================================
local function findPickaxe(container)
    if not container then
        return nil
    end
    for _, t in ipairs(container:GetChildren()) do
        if t:IsA("Tool") and (t:GetAttribute("PickaxeTool") or t.Name:lower():find("pick", 1, true)) then
            return t
        end
    end
    return nil
end

local function ensurePickaxe(char, hum)
    local tool = findPickaxe(char)
    if tool then
        return tool
    end
    tool = findPickaxe(lp_():FindFirstChild("Backpack"))
    if tool then
        pcall(function() hum:EquipTool(tool) end)
    end
    return tool
end

-- Guarda onde os blocos nascem (média das primeiras posições vistas)
local function watchBirths()
    local folder = workspace:FindFirstChild(CFG.IceFolder)
    if folder == Farm.watched then
        return
    end
    if Farm.birthConn then
        Farm.birthConn:Disconnect()
        Farm.birthConn = nil
    end
    Farm.watched = folder
    Farm.spawnPoint = nil
    Farm.births = {}
    if folder then
        Farm.birthConn = folder.ChildAdded:Connect(function(b)
            task.defer(function()
                local cf = getPivotPos(b)
                if cf and cf.Position.Magnitude > 1 then
                    local list = Farm.births
                    list[#list + 1] = cf.Position
                    if #list > 8 then
                        table.remove(list, 1)
                    end
                    local sum = Vector3.new(0, 0, 0)
                    for _, p in ipairs(list) do
                        sum = sum + p
                    end
                    Farm.spawnPoint = sum / #list
                end
            end)
        end)
    end
end

-- Escolhe o melhor alvo: raridade aceita, longe do spawner e isolado dos outros blocos.
-- Devolve (bloco, bloqueadoPorIsolamento).
local function pickTarget(startedAt)
    local list = {}
    for _, b in ipairs(iceTargets()) do
        local cf = getPivotPos(b)
        if cf then
            list[#list + 1] = { b = b, pos = cf.Position }
        end
    end
    if #list == 0 then
        return nil, false
    end
    -- ainda sem ponto de spawn: espera alguns segundos para aprender onde nascem
    if not Farm.spawnPoint and os.clock() - startedAt < 12 then
        return nil, false
    end
    local best, bestScore
    local isoBlocked = false
    for _, it in ipairs(list) do
        if rarityOk(it.b) then
            local fromSpawn = 0
            local okSpawn = true
            if Farm.spawnPoint then
                fromSpawn = (it.pos - Farm.spawnPoint).Magnitude
                okSpawn = fromSpawn >= CFG.SpawnClear
            end
            if okSpawn then
                local isolated = true
                if Farm.isolation > 0 then
                    for _, o in ipairs(list) do
                        if o ~= it and (o.pos - it.pos).Magnitude < Farm.isolation then
                            isolated = false
                            break
                        end
                    end
                end
                if isolated then
                    local name = blockRarity(it.b)
                    local rank = name and Farm.rank[name:lower()] or 0
                    local score = rank * 1000000 + fromSpawn
                    if not bestScore or score > bestScore then
                        best, bestScore = it.b, score
                    end
                else
                    isoBlocked = true
                end
            end
        end
    end
    return best, (best == nil and isoBlocked)
end

local function parkAt(root)
    if Farm.park then
        root.CFrame = Farm.park
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        root.Anchored = true
    end
end

local function engage(target, root, hum)
    root.Anchored = false
    local tool = ensurePickaxe(root.Parent, hum)
    local t0, lastAct = os.clock(), 0
    while Farm.ice and not Farm.pause and target.Parent and target:FindFirstChild("Ice", true)
        and os.clock() - t0 < CFG.EngageTimeout do
        local cf = getPivotPos(target)
        if not cf then
            break
        end
        root.CFrame = cf + Vector3.new(0, CFG.HoverY, 0)
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        if tool and tool.Parent == root.Parent and os.clock() - lastAct >= CFG.HitDelay then
            lastAct = os.clock()
            pcall(function() tool:Activate() end)
        end
        task.wait(0.08)
    end
end

local function iceLoop()
    Farm.iceRunning = true
    local startedAt = os.clock()
    local rootRef, lastWorld
    local isoSince, lastIsoWarn = nil, -100

    while Farm.ice do
        local lp = lp_()
        local char = lp.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")

        if Farm.pause then
            -- troca de mundo / parkour em andamento: não mexe no personagem
            if root then
                root.Anchored = false
            end
            rootRef = nil
            task.wait(0.3)
        elseif root and hum then
            local worldKey = lp:GetAttribute("World")
            if root ~= rootRef or worldKey ~= lastWorld then
                rootRef, lastWorld = root, worldKey
                root.Anchored = false
                Farm.home = root.CFrame
                Farm.park = root.CFrame + Vector3.new(0, CFG.ParkHeight, 0)
                startedAt = os.clock()
            end
            watchBirths()

            local target, isoBlocked = pickTarget(startedAt)
            if target then
                isoSince = nil
                engage(target, root, hum)
                if Farm.ice and not Farm.pause then
                    parkAt(root)
                end
            else
                if not root.Anchored then
                    parkAt(root)
                end
                if isoBlocked then
                    isoSince = isoSince or os.clock()
                    if os.clock() - isoSince > 30 and os.clock() - lastIsoWarn > 60 then
                        lastIsoWarn = os.clock()
                        Say("Auto gelo", "Os alvos sempre têm vizinhos perto. Diminua o Isolamento.")
                    end
                else
                    isoSince = nil
                end
            end
            task.wait(0.12)
        else
            task.wait(0.5)
        end
    end

    -- limpeza: solta o personagem e volta para onde você estava
    local char = lp_().Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        root.Anchored = false
        if Farm.home then
            root.CFrame = Farm.home
        end
    end
    if Farm.birthConn then
        Farm.birthConn:Disconnect()
        Farm.birthConn = nil
    end
    Farm.watched = nil
    Farm.iceRunning = false
end

-- Escolhe o próximo mundo (menor Order acima do atual) que esteja aberto ou
-- que você já possa comprar (rebirths e cash suficientes).
local function nextWorld(cfg, getAttr)
    local prefix = cfg.StateAttributePrefix or "WorldState"
    local openValue = cfg.Open or "Open"
    local cur = getAttr(cfg.Attribute or "World")
    local rebirths = getAttr("Rebirths") or 0
    local cash = getAttr("Cash") or 0
    local curOrder = 0
    for _, w in ipairs(cfg.Worlds) do
        if w.Key == cur then
            curOrder = w.Order or 0
        end
    end
    local best, bestOpen
    for _, w in ipairs(cfg.Worlds) do
        local order = w.Order or 0
        if order > curOrder and (not best or order < (best.Order or 0)) then
            local isOpen = getAttr(prefix .. tostring(w.Key)) == openValue
            local canBuy = rebirths >= (w.RebirthGate or math.huge) and cash >= (w.Price or math.huge)
            if isOpen or canBuy then
                best, bestOpen = w, isOpen
            end
        end
    end
    return best, bestOpen
end

local function getWorldCfg()
    local ok, cfg = pcall(function()
        return require(game:GetService("ReplicatedStorage").Shared.World.WorldConfig)
    end)
    if ok and type(cfg) == "table" and type(cfg.Worlds) == "table" then
        return cfg
    end
    return nil
end

-- Voa em linha reta até o alvo (CFrame a cada frame) atravessando obstáculos.
local function flyTo(target, speed, timeout)
    local RunService = game:GetService("RunService")
    local char = lp_().Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then
        return false
    end
    local touched = {}
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") and d.CanCollide then
            touched[#touched + 1] = d
            d.CanCollide = false
        end
    end
    local deadline = os.clock() + (timeout or 90)
    local last = os.clock()
    local arrived = false
    local conn = RunService.Heartbeat:Connect(function()
        local now = os.clock()
        local dt = math.min(now - last, 0.1)
        last = now
        local pos = root.Position
        local delta = target - pos
        local dist = delta.Magnitude
        if dist < 2.5 then
            arrived = true
            return
        end
        local step = math.min(dist, speed * dt)
        root.CFrame = CFrame.new(pos + delta.Unit * step) * root.CFrame.Rotation
        root.AssemblyLinearVelocity = Vector3.zero
    end)
    while not arrived and os.clock() < deadline and root.Parent do
        task.wait(0.1)
    end
    conn:Disconnect()
    for _, d in ipairs(touched) do
        pcall(function() d.CanCollide = true end)
    end
    return arrived
end

local function inObby(cfg)
    local lp = lp_()
    if lp:GetAttribute((cfg and cfg.ObbyAttribute) or "Obby") then
        return true
    end
    local char = lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    return root ~= nil and root.Position.Z < -5000
end

-- Procura o "Finish" mais próximo de você (cada mundo tem o parkour num lugar).
local function findObbyFinish(cfg, fromPos)
    local name = (cfg and cfg.ObbyFinishName) or "Finish"
    local scope = workspace:FindFirstChild("Obbies") or workspace
    local best, bestD, bestPos
    for _, d in ipairs(scope:GetDescendants()) do
        if d.Name == name and (d:IsA("BasePart") or d:IsA("Model")) then
            local cf = getPivotPos(d)
            if cf then
                local pos = cf.Position
                if d:IsA("BasePart") then
                    pos = pos + Vector3.new(0, d.Size.Y / 2, 0)
                end
                local dist = (pos - fromPos).Magnitude
                if not bestD or dist < bestD then
                    best, bestD, bestPos = d, dist, pos
                end
            end
        end
    end
    return best, bestPos
end

local function solveObby(cfg)
    local char = lp_().Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then
        return false
    end
    local finish, pos = findObbyFinish(cfg, root.Position)
    if not finish then
        Say("Parkour", "Não achei o Finish")
        return false
    end
    Say("Parkour", "Voando até o Finish")
    -- em pé sobre o Finish: centro do corpo ~3 studs acima da superfície
    local ok = flyTo(pos + Vector3.new(0, 3, 0), CFG.ObbySpeed, 120)
    if not ok then
        Say("Parkour", "Não consegui chegar ao Finish")
    end
    return ok
end

-- Teleporta para o pad do portal de mundos (o servidor só aceita a viagem com você lá)
local function goToPortalPad(cfg)
    local char = lp_().Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then
        return false
    end
    local padName = (cfg and cfg.PortalPadName) or "Pad"
    local portals = {}
    local okTag, tagged = pcall(function()
        return game:GetService("CollectionService"):GetTagged((cfg and cfg.PortalTag) or "WorldPortal")
    end)
    if okTag and tagged then
        for _, p in ipairs(tagged) do
            portals[#portals + 1] = p
        end
    end
    if #portals == 0 then
        local worlds = workspace:FindFirstChild("Worlds")
        if worlds then
            for _, d in ipairs(worlds:GetDescendants()) do
                if d.Name == "WorldPortal" then
                    portals[#portals + 1] = d
                end
            end
        end
    end
    local best, bestD
    for _, portal in ipairs(portals) do
        local pad = portal:FindFirstChild(padName, true)
        if pad and pad:IsA("BasePart") then
            local dist = (pad.Position - root.Position).Magnitude
            if not bestD or dist < bestD then
                best, bestD = pad, dist
            end
        end
    end
    if not best then
        return false
    end
    root.CFrame = best.CFrame + Vector3.new(0, best.Size.Y / 2 + 3, 0)
    return true
end

local function worldLoop()
    local RS = game:GetService("ReplicatedStorage")
    local remotes = RS:FindFirstChild("Remotes")
    local worldRemotes = remotes and remotes:FindFirstChild("World")
    local travel = worldRemotes and worldRemotes:FindFirstChild("Travel")
    local refused = worldRemotes and worldRemotes:FindFirstChild("Refused")
    local prompt = worldRemotes and worldRemotes:FindFirstChild("Prompt")
    local cfg = getWorldCfg()

    if not (travel and cfg) then
        Say("Auto mundo", "Não achei World.Travel ou WorldConfig")
        Farm.world = false
        return
    end

    local promptSeen = false
    local conns = {}
    if refused then
        conns[#conns + 1] = refused.OnClientEvent:Connect(function(...)
            local parts = {}
            for _, v in ipairs({ ... }) do
                parts[#parts + 1] = tostring(v)
            end
            Say("Mundo recusado", table.concat(parts, ", "))
        end)
    end
    if prompt then
        conns[#conns + 1] = prompt.OnClientEvent:Connect(function()
            promptSeen = true
        end)
    end

    local lastTry, buyTries = {}, {}
    local obbyFails = 0
    while Farm.world do
        local lp = lp_()
        if inObby(cfg) then
            -- já está num parkour: termina
            Farm.pause = true
            if solveObby(cfg) then
                obbyFails = 0
            else
                obbyFails = obbyFails + 1
            end
            task.wait(3)
            Farm.pause = false
        else
            local best, isOpen = nextWorld(cfg, function(n)
                return lp:GetAttribute(n)
            end)
            if best then
                local key = best.Key
                local now = os.clock()
                local okTry = (now - (lastTry[key] or -1000)) > 20 and (isOpen or (buyTries[key] or 0) < 3)
                if okTry then
                    lastTry[key] = now
                    if not isOpen then
                        buyTries[key] = (buyTries[key] or 0) + 1
                    end
                    Farm.pause = true
                    promptSeen = false
                    if goToPortalPad(cfg) then
                        local t0 = os.clock()
                        while not promptSeen and os.clock() - t0 < 4 do
                            task.wait(0.1)
                        end
                        task.wait(0.3)
                    end
                    Say("Auto mundo", "Indo para " .. tostring(best.DisplayName or key))
                    pcall(function()
                        travel:FireServer(key)
                    end)
                    task.wait(3)
                    if inObby(cfg) then
                        if solveObby(cfg) then
                            obbyFails = 0
                        else
                            obbyFails = obbyFails + 1
                        end
                    end
                    Farm.pause = false
                end
            end
        end
        if obbyFails >= 3 then
            Say("Auto mundo", "Parkour falhou 3 vezes; desligando")
            Farm.world = false
        end
        task.wait(CFG.WorldDelay)
    end
    for _, c in ipairs(conns) do
        pcall(function() c:Disconnect() end)
    end
end

local function SetAutoIce(on)
    if on == Farm.ice then
        return
    end
    Farm.ice = on
    if on and not Farm.iceRunning then
        task.spawn(iceLoop)
    end
end

local function SetAutoWorld(on)
    if on == Farm.world then
        return
    end
    Farm.world = on
    if on then
        task.spawn(function()
            local ok, err = pcall(worldLoop)
            if not ok then
                warn("[Dark Hub] auto mundo: " .. tostring(err))
            end
            Farm.pause = false
        end)
    end
end

-- ============================================
-- REBIRTH, PETS, OVOS E UTILIDADES
-- ============================================
local function getRemote(group, name)
    local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
    local g = remotes and remotes:FindFirstChild(group)
    return g and g:FindFirstChild(name)
end

-- Aciona os callbacks de um botão da interface (quando não há remote conhecido)
local function clickButton(btn)
    if not (btn and getconnections) then
        return false
    end
    local fired = false
    pcall(function()
        for _, ev in ipairs({ btn.Activated, btn.MouseButton1Click }) do
            local okc, conns = pcall(getconnections, ev)
            if okc and conns then
                for _, c in ipairs(conns) do
                    if pcall(function() c:Fire() end) then
                        fired = true
                    end
                end
            end
        end
    end)
    return fired
end

local function loopWhile(key, delay, fn)
    task.spawn(function()
        while Farm[key] do
            local ok, err = pcall(fn)
            if not ok then
                warn("[Dark Hub] " .. key .. ": " .. tostring(err))
            end
            task.wait(delay)
        end
    end)
end

local function makeToggle(key, delay, fn)
    return function(on)
        if Farm[key] == on then
            return
        end
        Farm[key] = on
        if on then
            loopWhile(key, delay, fn)
        end
    end
end

-- Auto rebirth: o servidor só aceita quando você já pode renascer
local lastRebirths = nil
local SetAutoRebirth = makeToggle("rebirth", CFG.RebirthDelay, function()
    local lp = lp_()
    local before = lp:GetAttribute("Rebirths") or 0
    if lastRebirths == nil then
        lastRebirths = before
    end
    local r = getRemote("Rebirth", "Request")
    if r then
        r:FireServer()
    end
    task.wait(2)
    local after = lp:GetAttribute("Rebirths") or 0
    if after > lastRebirths then
        lastRebirths = after
        Say("Auto rebirth", "Rebirths: " .. tostring(after))
    end
end)

-- Gravado: Companion.MergeAll("Pet") e Companion.EquipBest("Pet")
local SetAutoMerge = makeToggle("merge", CFG.MergeDelay, function()
    local r = getRemote("Companion", "MergeAll")
    if r then
        r:FireServer("Pet")
    end
end)

local SetAutoEquipBest = makeToggle("equip", CFG.EquipDelay, function()
    local r = getRemote("Companion", "EquipBest")
    if r then
        r:FireServer("Pet")
    end
end)

-- Ovos: você abre 1 ovo à mão e o hub repete exatamente aquela chamada
local function LearnHatch(seconds)
    local okHook, note = ensureHook()
    if not okHook then
        return tostring(note)
    end
    local G = getgenv and getgenv() or _G
    local got
    G.DarkHubH3Listeners.learn = function(name, args)
        if name == "Companion.Buy" then
            got = args
        end
    end
    Say("Aprender ovo", "Abra 1 ovo (do tipo e quantidade que quer repetir) em " .. seconds .. "s")
    local t0 = os.clock()
    while not got and os.clock() - t0 < seconds do
        task.wait(0.2)
    end
    G.DarkHubH3Listeners.learn = nil
    if not got then
        return "Nenhum ovo foi aberto nesse tempo. Tente de novo."
    end
    Farm.hatchArgs = got
    local parts = {}
    for i = 1, got.n do
        parts[i] = serial(got[i], 0)
    end
    return "Ovo aprendido: Companion.Buy(" .. table.concat(parts, ", ") .. ")"
end

local function skipHatchUi()
    local pg = lp_():FindFirstChildOfClass("PlayerGui")
    local ui = pg and pg:FindFirstChild("EggHatchUI")
    if ui and ui.Enabled then
        clickButton(ui:FindFirstChild("Skip", true))
        clickButton(ui:FindFirstChild("Continue", true))
    end
end

-- Gravado: Companion.Buy("Wonder", 10, true) e Companion.Buy("Castle", 10, true)
-- Frost = Ovo de Congelamento (deduzido pelos pets do ovo; confirme com "Aprender ovo")
local EGG_OPTIONS = { "Frost", "Castle", "Wonder", "Aprendido" }
local EGG_QTY = { "1", "10" }

local SetAutoHatch = makeToggle("hatch", CFG.HatchDelay, function()
    local r = getRemote("Companion", "Buy")
    if not r then
        Farm.hatch = false
        Say("Auto ovo", "Não achei Companion.Buy")
        return
    end
    if Farm.eggChoice == "Aprendido" then
        local args = Farm.hatchArgs
        if not args then
            Farm.hatch = false
            Say("Auto ovo", "Use 'Aprender ovo' primeiro")
            return
        end
        r:FireServer(table.unpack(args, 1, args.n))
    else
        r:FireServer(Farm.eggChoice, Farm.eggQty, true)
    end
    task.wait(0.6)
    skipHatchUi()
end)

-- ============================================
-- AUTO UPGRADE
-- Compra: Shop.Upgrade("AxeCount" | "CritLevel" | "AttackSpeed")
-- Sucesso: o servidor responde Shop.Transaction("Upgrade").
-- NUNCA usa TopUp.Request (completa com Robux).
-- ============================================
local UPGRADE_KEYS = { "AxeCount", "CritLevel", "AttackSpeed" }
local UPGRADE_NEEDLE = { AxeCount = "axe", CritLevel = "crit", AttackSpeed = "attack" }
local MAX_TEXTS = { max = true, maxed = true, maximum = true, maxlevel = true, maxlvl = true,
    ["máx"] = true, ["mÁx"] = true, ["máximo"] = true, ["mÁximo"] = true }

local upState = {}
local txCount = 0
local txConn

local function ensureTxListener()
    if txConn then
        return
    end
    local r = getRemote("Shop", "Transaction")
    if r then
        txConn = r.OnClientEvent:Connect(function(kind)
            if kind == "Upgrade" then
                txCount = txCount + 1
            end
        end)
    end
end

-- Procura um texto "MAX" na linha do upgrade dentro de UpgradeShop (melhor esforço)
local function upgradeMaxedUi(key)
    local pg = lp_():FindFirstChildOfClass("PlayerGui")
    local ui = pg and pg:FindFirstChild("UpgradeShop")
    local needle = UPGRADE_NEEDLE[key]
    if not (ui and needle) then
        return false
    end
    for _, d in ipairs(ui:GetDescendants()) do
        if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Visible then
            local t = d.Text:gsub("[%s%p]", ""):lower()
            if MAX_TEXTS[t] then
                local anc, depth = d.Parent, 0
                while anc and anc ~= ui and depth < 6 do
                    if anc.Name:lower():find(needle, 1, true) then
                        return true
                    end
                    anc = anc.Parent
                    depth = depth + 1
                end
            end
        end
    end
    return false
end

local function upgradePass()
    ensureTxListener()
    local r = getRemote("Shop", "Upgrade")
    if not r then
        Farm.upgrade = false
        Say("Auto upgrade", "Não achei Shop.Upgrade")
        return
    end
    local lp = lp_()
    for _, key in ipairs(UPGRADE_KEYS) do
        if not Farm.upgrade then
            break
        end
        if Farm.upSelected[key] then
            local st = upState[key]
            if not st then
                st = { fails = 0, bought = 0, maxed = false, nextTry = 0, failCash = nil, lastCost = nil, lastWarn = -100 }
                upState[key] = st
            end
            if os.clock() >= st.nextTry then
                local bought = 0
                for _ = 1, CFG.UpgradeBurst do
                    if not Farm.upgrade then
                        break
                    end
                    local before = txCount
                    local cashBefore = lp:GetAttribute("Cash") or 0
                    r:FireServer(key)
                    local t0 = os.clock()
                    while txCount == before and os.clock() - t0 < CFG.UpgradeWait do
                        task.wait(0.05)
                    end
                    if txCount > before then
                        bought = bought + 1
                        task.wait(0.1) -- deixa o cash atualizar para medir o custo
                        local drop = cashBefore - (lp:GetAttribute("Cash") or cashBefore)
                        if drop > 0 then
                            st.lastCost = drop
                        end
                    else
                        break
                    end
                end

                if bought > 0 then
                    st.bought = st.bought + bought
                    st.fails = 0
                    st.failCash = nil
                    if st.maxed then
                        st.maxed = false
                        Say("Auto upgrade", key .. ": voltou a comprar")
                    end
                else
                    st.fails = st.fails + 1
                    local cash = lp:GetAttribute("Cash") or 0
                    st.failCash = st.failCash or cash

                    -- máximo ou falta de dinheiro?
                    local isMax = false
                    if upgradeMaxedUi(key) then
                        isMax = true
                    elseif st.lastCost and st.fails >= 3 and cash >= st.lastCost * CFG.UpgradeMaxFactor then
                        isMax = true -- tem bem mais que o último custo e mesmo assim não compra
                    elseif not st.lastCost and st.fails >= 6 and cash >= st.failCash * 10 then
                        isMax = true -- sem referência de custo: o cash subiu 10x e não comprou
                    end

                    if isMax then
                        if not st.maxed then
                            st.maxed = true
                            Say("Auto upgrade", key .. ": provável nível máximo (reteste a cada 2 min)")
                        end
                        st.nextTry = os.clock() + CFG.UpgradeRetryMax
                    else
                        st.nextTry = os.clock() + CFG.UpgradeBackoff
                        if os.clock() - st.lastWarn > 60 then
                            st.lastWarn = os.clock()
                            Say("Auto upgrade", key .. ": sem dinheiro, aguardando")
                        end
                    end
                end
            end
        end
    end
end

local setUpgradeLoop = makeToggle("upgrade", CFG.UpgradeDelay, upgradePass)
local function SetAutoUpgrade(on)
    if on then
        upState = {} -- recomeça a detecção de máximo
    end
    setUpgradeLoop(on)
end

local function SellAllNow()
    local r = getRemote("Shop", "SellAll")
    if r then
        r:FireServer()
    end
end

local function SolveObbyNow()
    local cfg = getWorldCfg()
    if not cfg then
        return "WorldConfig não encontrado"
    end
    if not inObby(cfg) then
        return "Você não está num parkour agora"
    end
    return solveObby(cfg) and "Parkour concluído" or "Não consegui concluir o parkour"
end

local RARITY_OPTIONS = CFG.Rarities
local ISO_OPTIONS = { "Nenhum", "Baixo", "Médio", "Alto" }
local ISO_VALUES = { ["Nenhum"] = 0, ["Baixo"] = 8, ["Médio"] = 14, ["Alto"] = 22 }

-- ============================================
-- DADOS
-- ============================================
local HUB = {
    {
        tab = "🐟 Resgate um Peixe",
        sections = {
            {
                title = "Auto Farm",
                scripts = {
                    { name = "Auto quebrar gelo", toggle = SetAutoIce },
                    {
                        name = "Raridade mínima",
                        dropdown = {
                            options = RARITY_OPTIONS,
                            default = "Common",
                            onChange = function(opt)
                                Farm.minRarity = Farm.rank[tostring(opt):lower()] or 1
                            end,
                        },
                    },
                    {
                        name = "Quebrar raridade desconhecida",
                        toggle = function(on) Farm.hitUnknown = on end,
                        default = true,
                    },
                    {
                        name = "Isolamento do alvo (distância de outros blocos)",
                        dropdown = {
                            options = ISO_OPTIONS,
                            default = "Médio",
                            onChange = function(opt) Farm.isolation = ISO_VALUES[tostring(opt)] or 14 end,
                        },
                    },
                },
            },
            {
                title = "Progressão",
                scripts = {
                    { name = "Auto rebirth", toggle = SetAutoRebirth },
                    { name = "Auto upgrade (pára sem dinheiro / no máximo)", toggle = SetAutoUpgrade },
                    {
                        name = "Upgrades a comprar",
                        dropdown = {
                            options = UPGRADE_KEYS,
                            default = UPGRADE_KEYS,
                            multi = true,
                            onChange = function(selected)
                                Farm.upSelected = {}
                                for _, n in ipairs(selected) do
                                    Farm.upSelected[tostring(n)] = true
                                end
                            end,
                        },
                    },
                    { name = "Auto passar de mundo (compra, entra e faz o parkour)", toggle = SetAutoWorld },
                    { name = "Passar o parkour agora (voar até o Finish)", run = SolveObbyNow },
                },
            },
            {
                title = "Pets e ovos",
                scripts = {
                    { name = "Auto mesclar pets", toggle = SetAutoMerge },
                    { name = "Auto equipar o melhor", toggle = SetAutoEquipBest },
                    { name = "Aprender ovo (abra 1 ovo em 25s)", run = function() return LearnHatch(25) end },
                    {
                        name = "Ovo",
                        dropdown = {
                            options = EGG_OPTIONS,
                            default = "Frost",
                            onChange = function(opt) Farm.eggChoice = tostring(opt) end,
                        },
                    },
                    {
                        name = "Quantidade por vez",
                        dropdown = {
                            options = EGG_QTY,
                            default = "1",
                            onChange = function(opt) Farm.eggQty = tonumber(opt) or 1 end,
                        },
                    },
                    { name = "Auto abrir ovo", toggle = SetAutoHatch },
                },
            },
            {
                title = "Diagnóstico",
                scripts = {
                    { name = "Scanner do jogo (copia o resultado)", run = ScanGame },
                    { name = "Gravar remotes por 45s (faça as ações à mão)", run = function() return RemoteLog(45) end },
                },
            },
            {
                title = "Utilidades",
                scripts = {
                    { name = "Vender tudo agora", run = SellAllNow },
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
            if script.toggle then
                Tab:CreateToggle({
                    Name = script.name,
                    CurrentValue = script.default == true,
                    Callback = function(value)
                        local ok, err = pcall(script.toggle, value)
                        if not ok then
                            warn("[Dark Hub] " .. script.name .. ": " .. tostring(err))
                            Notify("Erro ❌", script.name .. " falhou")
                        end
                    end,
                })
            elseif script.dropdown then
                local dd = script.dropdown
                Tab:CreateDropdown({
                    Name = script.name,
                    Options = dd.options,
                    CurrentOption = dd.multi and dd.default or { dd.default },
                    MultipleOptions = dd.multi == true,
                    Callback = function(opt)
                        if dd.multi then
                            pcall(dd.onChange, type(opt) == "table" and opt or { opt })
                        else
                            pcall(dd.onChange, type(opt) == "table" and opt[1] or opt)
                        end
                    end,
                })
            else
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
end

-- ============================================
-- ABA: CONFIGURAÇÕES
-- ============================================
local ConfigTab = Window:CreateTab("⚙️ Configurações", ICON)

ConfigTab:CreateSection("Informações")
ConfigTab:CreateLabel("🌑 Dark Hub v3.9")
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
print("[Dark Hub] v3.9 carregado: " .. totalScripts .. " scripts")
