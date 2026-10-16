-- 🌑 DARK HUB v3.6
-- Hub de scripts (interface Rayfield) - Mobile e PC
-- Made by Syntax, Dark & Claude
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
    for _, nm in ipairs({ "Quality", "Ice", "World" }) do
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
                    add(mod.Name .. " = " .. text:sub(1, 1800))
                else
                    add(mod.Name .. ": require falhou (" .. tostring(data) .. ")")
                end
            end
        end
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

-- Grava chamadas de remotes por alguns segundos:
--   C>S = o jogo (ou você) chamando FireServer/InvokeServer
--   S>C = o servidor mandando dados para o cliente (ids dos blocos, raridade etc.)
-- Quebre gelo / venda / viaje de mundo à mão durante a gravação.
local function RemoteLog(seconds)
    local G = getgenv and getgenv() or _G
    local RS = game:GetService("ReplicatedStorage")

    local function ser(v, depth)
        local t = typeof(v)
        if t == "string" then
            return '"' .. v:sub(1, 40) .. '"'
        elseif t == "number" or t == "boolean" or t == "nil" then
            return tostring(v)
        elseif t == "Instance" then
            return "<" .. v:GetFullName() .. ">"
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
                parts[#parts + 1] = tostring(k) .. "=" .. ser(val, depth + 1)
            end
            return "{" .. table.concat(parts, ", ") .. "}"
        end
        return t .. ":" .. tostring(v)
    end

    local state = { active = true, data = {}, order = {} }

    -- guarda no máximo 3 exemplos distintos por remote
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
                parts[i] = ser(args[i], 0)
            end
            local text = "(" .. table.concat(parts, ", ") .. ")"
            if not rec.seen[text] then
                rec.seen[text] = true
                rec.samples[#rec.samples + 1] = text
            end
        end
    end

    G.DarkHubRemoteLog = state

    -- Servidor -> cliente: escuta passiva dos grupos que interessam
    local conns = {}
    local remotes = RS:FindFirstChild("Remotes")
    local watch = { "Conveyor", "Ice", "Pickaxe", "World", "Travel", "Shop", "Rebirth", "Inventory", "Aquarium", "Plot", "Index" }
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

    -- Cliente -> servidor: precisa de hookmetamethod
    local hookNote = nil
    if hookmetamethod and getnamecallmethod then
        if not G.DarkHubRemoteHooked then
            G.DarkHubRemoteHooked = true
            local old
            local function handler(self, ...)
                local st = G.DarkHubRemoteLog
                if st and st.active then
                    local m = getnamecallmethod()
                    if (m == "FireServer" or m == "InvokeServer") and typeof(self) == "Instance" then
                        local cn = self.ClassName
                        if cn == "RemoteEvent" or cn == "RemoteFunction" then
                            local args = table.pack(...)
                            pcall(function()
                                local full = self:GetFullName():gsub("^ReplicatedStorage%.Remotes%.", "")
                                st.record("C>S", full, args)
                            end)
                        end
                    end
                end
                return old(self, ...)
            end
            local okHook, res = pcall(function()
                return hookmetamethod(game, "__namecall", newcclosure and newcclosure(handler) or handler)
            end)
            if okHook then
                old = res
            else
                G.DarkHubRemoteHooked = nil
                hookNote = "Falha ao instalar o hook (C>S indisponível): " .. tostring(res)
            end
        end
    else
        hookNote = "Executor sem hookmetamethod: só aparecem as chamadas servidor>cliente (S>C)."
    end

    Say("Gravando remotes", "Quebre gelo, venda e viaje à mão por " .. seconds .. "s")
    task.wait(seconds)

    state.active = false
    for _, c in ipairs(conns) do
        pcall(function() c:Disconnect() end)
    end

    local lines = { "=== REMOTES GRAVADOS (" .. seconds .. "s) ===" }
    if hookNote then
        lines[#lines + 1] = hookNote
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
    Rarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Godly", "Prismatic", "Celestial", "Secret" },
    WorldKeywords = { "next world", "new world", "unlock world", "portal" },
    HitDelay = 0.25,
    WorldDelay = 8,
}

local Farm = {
    ice = false,
    world = false,
    allowed = {},       -- raridades marcadas (minúsculas)
    known = {},         -- raridades da lista (minúsculas)
    hitUnknown = true,  -- quebrar raridade fora da lista / não detectada
    cache = {},
    conns = {},
}

for _, r in ipairs(CFG.Rarities) do
    Farm.allowed[r:lower()] = true
    Farm.known[r:lower()] = true
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
    local key = name:lower()
    if not Farm.known[key] then
        return Farm.hitUnknown
    end
    return Farm.allowed[key] == true
end

local function getPivotPos(inst)
    local ok, cf = pcall(function() return inst:GetPivot() end)
    if ok then
        return cf
    end
    return nil
end

local function hitIce(target)
    local char = lp_().Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not (root and hum) then
        return
    end
    local cf = getPivotPos(target)
    if not cf then
        return
    end
    root.CFrame = cf + Vector3.new(0, 4, 0)

    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then
        local bp = lp_():FindFirstChild("Backpack")
        if bp then
            for _, t in ipairs(bp:GetChildren()) do
                if t:IsA("Tool") and t.Name:lower():find("pick", 1, true) then
                    tool = t
                    break
                end
            end
            tool = tool or bp:FindFirstChildOfClass("Tool")
        end
        if tool then
            pcall(function() hum:EquipTool(tool) end)
        end
    end
    if tool then
        pcall(function() tool:Activate() end)
    end

    for _, d in ipairs(target:GetDescendants()) do
        if d:IsA("ProximityPrompt") and fireproximityprompt then
            pcall(fireproximityprompt, d)
        elseif d:IsA("ClickDetector") and fireclickdetector then
            pcall(fireclickdetector, d)
        end
    end
end

local function iceLoop()
    while Farm.ice do
        local char = lp_().Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            local best, bestDist
            for _, inst in ipairs(iceTargets()) do
                if rarityOk(inst) then
                    local cf = getPivotPos(inst)
                    if cf then
                        local d = (cf.Position - root.Position).Magnitude
                        if not bestDist or d < bestDist then
                            best, bestDist = inst, d
                        end
                    end
                end
            end
            if best then
                hitIce(best)
            end
        end
        task.wait(CFG.HitDelay)
    end
end

local function textMatchesWorld(s)
    s = s:lower()
    for _, k in ipairs(CFG.WorldKeywords) do
        if s:find(k, 1, true) then
            return true
        end
    end
    return false
end

local function worldLoop()
    while Farm.world do
        local char = lp_().Character
        local root = char and char:FindFirstChild("HumanoidRootPart")

        -- Prompts no mundo
        for _, d in ipairs(workspace:GetDescendants()) do
            if not Farm.world then
                break
            end
            if d:IsA("ProximityPrompt") and d.Enabled then
                local label = tostring(d.ActionText) .. " " .. tostring(d.ObjectText) .. " " .. (d.Parent and d.Parent.Name or "")
                if textMatchesWorld(label) and fireproximityprompt then
                    local par = d.Parent
                    if root and par and (par:IsA("BasePart") or par:IsA("Model")) then
                        local cf = getPivotPos(par)
                        if cf then
                            root.CFrame = cf + Vector3.new(0, 3, 0)
                        end
                    end
                    pcall(fireproximityprompt, d)
                    print("[Dark Hub] Prompt de mundo: " .. label)
                end
            end
        end

        -- Botões na interface
        local pg = lp_():FindFirstChildOfClass("PlayerGui")
        if pg and getconnections then
            for _, b in ipairs(pg:GetDescendants()) do
                if b:IsA("TextButton") and b.Visible and textMatchesWorld(b.Text) then
                    for _, ev in ipairs({ b.MouseButton1Click, b.Activated }) do
                        local okc, conns = pcall(getconnections, ev)
                        if okc and conns then
                            for _, c in ipairs(conns) do
                                pcall(function() c:Fire() end)
                            end
                        end
                    end
                    print("[Dark Hub] Botão de mundo: " .. b.Text)
                end
            end
        end

        task.wait(CFG.WorldDelay)
    end
end

local function SetAutoIce(on)
    if on == Farm.ice then
        return
    end
    Farm.ice = on
    if on then
        task.spawn(iceLoop)
    end
end

local function SetAutoWorld(on)
    if on == Farm.world then
        return
    end
    Farm.world = on
    if on then
        task.spawn(worldLoop)
    end
end

local RARITY_OPTIONS = CFG.Rarities

-- ============================================
-- DADOS
-- ============================================
local HUB = {
    {
        tab = "🐟 Resgate um Peixe",
        sections = {
            {
                title = "Diagnóstico (rode primeiro)",
                scripts = {
                    { name = "Scanner do jogo (copia o resultado)", run = ScanGame },
                    { name = "Gravar remotes por 45s (quebre gelo/venda/viaje à mão)", run = function() return RemoteLog(45) end },
                },
            },
            {
                title = "Auto Farm (experimental)",
                scripts = {
                    { name = "Auto quebrar gelo", toggle = SetAutoIce },
                    {
                        name = "Raridades para quebrar",
                        dropdown = {
                            options = RARITY_OPTIONS,
                            default = RARITY_OPTIONS,
                            multi = true,
                            onChange = function(selected)
                                Farm.allowed = {}
                                for _, n in ipairs(selected) do
                                    Farm.allowed[tostring(n):lower()] = true
                                end
                            end,
                        },
                    },
                    {
                        name = "Quebrar raridade fora da lista",
                        toggle = function(on) Farm.hitUnknown = on end,
                        default = true,
                    },
                    { name = "Auto passar de mundo", toggle = SetAutoWorld },
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
ConfigTab:CreateLabel("🌑 Dark Hub v3.6")
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
print("[Dark Hub] v3.6 carregado: " .. totalScripts .. " scripts")
