
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local Window = Fluent:CreateWindow({
    Title = "Embee Studio",
    SubTitle = "Painel Global",
    TabWidth = 160,
    Size = UDim2.new(0, 600, 0, 550),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    GlobalMenssagem = Window:AddTab({ Title = "Global Menssagem", Icon = "message-square" }),
    Conf = Window:AddTab({ Title = "Conf", Icon = "settings" }),
    VoteGlobal = Window:AddTab({ Title = "Vote Global", Icon = "check" })
}

local LocalPlayer = game:GetService("Players").LocalPlayer
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BASE_URL = "https://analisy-omega.vercel.app"
local SEU_SITE_URL = BASE_URL .. "/api/analisar"
local COMANDOS_URL = BASE_URL .. "/api/comandos"
local VOTE_CREATE_URL = BASE_URL .. "/api/vote/create"
local VOTE_SUBMIT_URL = BASE_URL .. "/api/vote/submit"

local processedEventIds = {}
local activeVoteWindow = nil
local activeVote = nil
local lastVoteId = nil
local isSendingCommand = false
local VoteQuestion = ""
local VoteOption1 = ""
local VoteOption2 = ""
local GlobalMsg = ""

local function getHttpRequest()
    local success, req = pcall(function()
        return (syn and syn.request) or (http and http.request) or http_request or request
    end)
    return success and req
end

local function getHttpResponseStatus(response)
    if not response then
        return nil
    end
    if type(response) == "number" then
        return response
    end
    local status = response.StatusCode or response.status or response.statusCode or response.Status
    if type(status) == "string" then
        status = tonumber(status)
    end
    return status
end

local function isSuccessResponse(response)
    local status = getHttpResponseStatus(response)
    return status == 200 or status == 201 or status == 204
end

local function getResponseMessage(response)
    if not response then
        return nil
    end
    local body = response.Body or response.body or response.data
    if type(body) == "string" then
        local ok, parsed = pcall(function() return HttpService:JSONDecode(body) end)
        if ok and type(parsed) == "table" and parsed.mensagem then
            return tostring(parsed.mensagem)
        end
        return body
    end
    if type(body) == "table" and body.mensagem then
        return tostring(body.mensagem)
    end
    return nil
end

local function getEventId(dados)
    if dados.id then
        return tostring(dados.id)
    end
    local key = dados.tipo or ""
    if dados.player then
        key = key .. "|" .. tostring(dados.player)
    end
    if dados.acao then
        key = key .. "|" .. tostring(dados.acao)
    end
    if dados.conteudo then
        key = key .. "|" .. tostring(dados.conteudo)
    end
    if dados.question then
        key = key .. "|" .. tostring(dados.question)
    end
    return key
end

local function normalizeAction(acao)
    if not acao then
        return nil
    end
    return tostring(acao):gsub("%s+", "_"):lower()
end

local function executeGlobalAction(acao, parametros)
    local action = normalizeAction(acao)
    if not action then
        return false
    end

    if action == "kill_global" then
        Fluent:Notify({ Title = "Comando Global", Content = "Kill Global!", Duration = 3 })
        killPlayer(getCharacter())
        return true
    elseif action == "bring_global" then
        Fluent:Notify({ Title = "Comando Global", Content = "Bring Global - teleportando...", Duration = 5 })
        if parametros.placeId and parametros.jobId then
            TeleportService:TeleportToPlaceInstance(parametros.placeId, parametros.jobId, LocalPlayer)
        end
        return true
    elseif action == "heal_global" then
        Fluent:Notify({ Title = "Comando Global", Content = "Heal Global!", Duration = 3 })
        healPlayer(getCharacter())
        return true
    elseif action == "kick_global" then
        Fluent:Notify({ Title = "Comando Global", Content = "Kick Global!", Duration = 3 })
        kickPlayer()
        return true
    elseif action == "fly_global" then
        Fluent:Notify({ Title = "Comando Global", Content = "Fly Global!", Duration = 3 })
        toggleFly(true)
        return true
    elseif action == "noclip_global" then
        Fluent:Notify({ Title = "Comando Global", Content = "Noclip Global!", Duration = 3 })
        noclipPlayer(true)
        return true
    elseif action == "godmode_global" then
        Fluent:Notify({ Title = "Comando Global", Content = "God Mode Global!", Duration = 3 })
        godMode(getCharacter())
        return true
    elseif action == "freeze_global" then
        Fluent:Notify({ Title = "Comando Global", Content = "Freeze Global (5s)!", Duration = 3 })
        freezePlayer(getCharacter())
        return true
    elseif action == "reset_global" or action == "reset" then
        Fluent:Notify({ Title = "Comando Global", Content = "Reset Character Global!", Duration = 3 })
        resetCharacter()
        return true
    elseif action == "clearbackpack_global" then
        Fluent:Notify({ Title = "Comando Global", Content = "Clear Backpack Global!", Duration = 3 })
        clearBackpack()
        return true
    elseif action == "walkspeed_global" then
        local speed = parametros.speed or 50
        Fluent:Notify({ Title = "Comando Global", Content = "WalkSpeed Global: " .. speed, Duration = 3 })
        changeWalkSpeed(getCharacter(), speed)
        return true
    elseif action == "jumppower_global" then
        local power = parametros.power or 100
        Fluent:Notify({ Title = "Comando Global", Content = "JumpPower Global: " .. power, Duration = 3 })
        changeJumpPower(getCharacter(), power)
        return true
    elseif action == "disconecta_global" or action == "disconecta" then
        Fluent:Notify({ Title = "Comando Global", Content = "Disconecta Global!", Duration = 3 })
        kickPlayer()
        return true
    end

    return false
end

local function enviarComando(conteudo)
    if isSendingCommand then
        return
    end
    isSendingCommand = true
    task.spawn(function()
        local httpRequest = getHttpRequest()
        if not httpRequest then
            Fluent:Notify({ Title = "Erro", Content = "Executor não suporta HTTP!", Duration = 3 })
            task.wait(0.5)
            isSendingCommand = false
            return
        end
        local dados = {
            player = LocalPlayer.Name,
            conteudo = conteudo,
            placeId = game.PlaceId,
            jobId = game.JobId
        }
        local success, response = pcall(function()
            return httpRequest({
                Url = SEU_SITE_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json", Accept = "application/json" },
                Body = HttpService:JSONEncode(dados)
            })
        end)
        if not success or not isSuccessResponse(response) then
            Fluent:Notify({ Title = "Erro", Content = getResponseMessage(response) or "Falha ao enviar comando!", Duration = 4 })
        else
            Fluent:Notify({ Title = "Sucesso", Content = getResponseMessage(response) or "Comando enviado!", Duration = 2 })
        end
        task.wait(0.5)
        isSendingCommand = false
    end)
end

local function criarVotacao(question, option1, option2)
    if isSendingCommand then
        return
    end
    isSendingCommand = true
    task.spawn(function()
        local httpRequest = getHttpRequest()
        if not httpRequest then
            Fluent:Notify({ Title = "Erro", Content = "Executor não suporta HTTP!", Duration = 3 })
            task.wait(0.5)
            isSendingCommand = false
            return
        end
        local dados = {
            player = LocalPlayer.Name,
            question = question,
            option1 = option1,
            option2 = option2
        }
        local success, response = pcall(function()
            return httpRequest({
                Url = VOTE_CREATE_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json", Accept = "application/json" },
                Body = HttpService:JSONEncode(dados)
            })
        end)
        if not success or not isSuccessResponse(response) then
            Fluent:Notify({ Title = "Erro", Content = getResponseMessage(response) or "Falha ao criar votação!", Duration = 4 })
        else
            Fluent:Notify({ Title = "Sucesso", Content = getResponseMessage(response) or "Votação iniciada!", Duration = 2 })
        end
        task.wait(0.5)
        isSendingCommand = false
    end)
end

local function enviarVoto(voteId, choice)
    if isSendingCommand then
        return
    end
    isSendingCommand = true
    task.spawn(function()
        local httpRequest = getHttpRequest()
        if not httpRequest then
            Fluent:Notify({ Title = "Erro", Content = "Executor não suporta HTTP!", Duration = 3 })
            task.wait(0.5)
            isSendingCommand = false
            return
        end
        local dados = {
            player = LocalPlayer.Name,
            voteId = voteId,
            choice = choice
        }
        local success, response = pcall(function()
            return httpRequest({
                Url = VOTE_SUBMIT_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json", Accept = "application/json" },
                Body = HttpService:JSONEncode(dados)
            })
        end)
        if not success or not isSuccessResponse(response) then
            Fluent:Notify({ Title = "Erro", Content = getResponseMessage(response) or "Falha ao enviar voto!", Duration = 4 })
        else
            Fluent:Notify({ Title = "Sucesso", Content = getResponseMessage(response) or "Voto registrado!", Duration = 2 })
        end
        task.wait(0.5)
        isSendingCommand = false
    end)
end

local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function killPlayer(character)
    if character and character:FindFirstChild("Humanoid") then
        character.Humanoid.Health = 0
    end
end

local function healPlayer(character)
    if character and character:FindFirstChild("Humanoid") then
        character.Humanoid.Health = character.Humanoid.MaxHealth
    end
end

local function kickPlayer()
    LocalPlayer:Kick("Comando global executado")
end

local flyEnabled = false
local flyConnection = nil
local function toggleFly(enable)
    flyEnabled = enable
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end
    if enable then
        flyConnection = RunService.Heartbeat:Connect(function()
            local character = getCharacter()
            local humanoid = character:FindFirstChild("Humanoid")
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if character and humanoid and hrp then
                humanoid.FloorMaterial = Enum.Material.Air
                local camera = workspace.CurrentCamera
                local speed = 50
                local moveDirection = Vector3.new()
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                    moveDirection = moveDirection + camera.CFrame.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                    moveDirection = moveDirection - camera.CFrame.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                    moveDirection = moveDirection - camera.CFrame.RightVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                    moveDirection = moveDirection + camera.CFrame.RightVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    moveDirection = moveDirection + Vector3.new(0,1,0)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                    moveDirection = moveDirection - Vector3.new(0,1,0)
                end
                hrp.Velocity = moveDirection * speed
            end
        end)
    end
end

local function noclipPlayer(enable)
    local character = getCharacter()
    if not character then return end
    for _, v in pairs(character:GetDescendants()) do
        if v:IsA("BasePart") and v.CanCollide then
            v.CanCollide = not enable
        end
    end
end

local function godMode(character)
    if character and character:FindFirstChild("Humanoid") then
        character.Humanoid.MaxHealth = math.huge
        character.Humanoid.Health = math.huge
    end
end

local function freezePlayer(character)
    if character and character:FindFirstChild("HumanoidRootPart") then
        local hrp = character.HumanoidRootPart
        hrp.Anchored = true
        task.wait(5)
        hrp.Anchored = false
    end
end

local function changeWalkSpeed(character, speed)
    if character and character:FindFirstChild("Humanoid") then
        character.Humanoid.WalkSpeed = speed
    end
end

local function changeJumpPower(character, power)
    if character and character:FindFirstChild("Humanoid") then
        character.Humanoid.JumpPower = power
    end
end

local function clearBackpack()
    if LocalPlayer.Backpack then
        for _, item in ipairs(LocalPlayer.Backpack:GetChildren()) do
            item:Destroy()
        end
    end
    local character = getCharacter()
    if character then
        for _, item in ipairs(character:GetChildren()) do
            if item:IsA("Tool") then
                item:Destroy()
            end
        end
    end
end

local function resetCharacter()
    LocalPlayer:LoadCharacter()
end

local function createJanelaVotacao(voteData)
    local voteKey = voteData.id or (voteData.question .. "|" .. tostring(voteData.option1) .. "|" .. tostring(voteData.option2))
    if lastVoteId == voteKey then
        return
    end
    if activeVoteWindow then
        activeVoteWindow:Destroy()
        activeVoteWindow = nil
    end
    lastVoteId = voteKey
    activeVote = voteData

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "EmbeeVote"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = game:GetService("CoreGui")

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 400, 0, 280)
    MainFrame.Position = UDim2.new(0.5, -200, 0.5, -140)
    MainFrame.BackgroundColor3 = Color3.fromRGB(20,20,35)
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0,10)
    UICorner.Parent = MainFrame

    local Title = Instance.new("TextLabel")
    Title.Name = "Title"
    Title.Size = UDim2.new(1,0,0,50)
    Title.Position = UDim2.new(0,0,0,10)
    Title.BackgroundTransparency = 1
    Title.Text = "Votação Global"
    Title.TextColor3 = Color3.fromRGB(102,126,234)
    Title.TextSize = 22
    Title.Font = Enum.Font.GothamBold
    Title.Parent = MainFrame

    local QuestionText = Instance.new("TextLabel")
    QuestionText.Name = "Question"
    QuestionText.Size = UDim2.new(1,-40,0,70)
    QuestionText.Position = UDim2.new(0,20,0,60)
    QuestionText.BackgroundTransparency = 1
    QuestionText.Text = voteData.question
    QuestionText.TextColor3 = Color3.fromRGB(225,225,225)
    QuestionText.TextSize = 16
    QuestionText.TextWrapped = true
    QuestionText.TextYAlignment = Enum.TextYAlignment.Top
    QuestionText.Font = Enum.Font.Gotham
    QuestionText.Parent = MainFrame

    local TimerLabel = Instance.new("TextLabel")
    TimerLabel.Name = "Timer"
    TimerLabel.Size = UDim2.new(1,0,0,30)
    TimerLabel.Position = UDim2.new(0,0,0,135)
    TimerLabel.BackgroundTransparency = 1
    TimerLabel.Text = "20 segundos restantes"
    TimerLabel.TextColor3 = Color3.fromRGB(255,200,100)
    TimerLabel.TextSize = 14
    TimerLabel.Font = Enum.Font.GothamSemibold
    TimerLabel.Parent = MainFrame

    local ButtonContainer = Instance.new("Frame")
    ButtonContainer.Name = "Buttons"
    ButtonContainer.Size = UDim2.new(1,-40,0,55)
    ButtonContainer.Position = UDim2.new(0,20,0,175)
    ButtonContainer.BackgroundTransparency = 1
    ButtonContainer.Parent = MainFrame

    local Button1 = Instance.new("TextButton")
    Button1.Name = "Option1"
    Button1.Size = UDim2.new(0.48,0,1,0)
    Button1.Position = UDim2.new(0,0,0,0)
    Button1.BackgroundColor3 = Color3.fromRGB(46,204,113)
    Button1.Text = voteData.option1
    Button1.TextColor3 = Color3.fromRGB(255,255,255)
    Button1.TextSize = 16
    Button1.Font = Enum.Font.GothamBold
    Button1.AutoButtonColor = false
    Button1.Parent = ButtonContainer

    local B1Corner = Instance.new("UICorner")
    B1Corner.CornerRadius = UDim.new(0,8)
    B1Corner.Parent = Button1

    local Button2 = Instance.new("TextButton")
    Button2.Name = "Option2"
    Button2.Size = UDim2.new(0.48,0,1,0)
    Button2.Position = UDim2.new(0.52,0,0,0)
    Button2.BackgroundColor3 = Color3.fromRGB(231,76,60)
    Button2.Text = voteData.option2
    Button2.TextColor3 = Color3.fromRGB(255,255,255)
    Button2.TextSize = 16
    Button2.Font = Enum.Font.GothamBold
    Button2.AutoButtonColor = false
    Button2.Parent = ButtonContainer

    local B2Corner = Instance.new("UICorner")
    B2Corner.CornerRadius = UDim.new(0,8)
    B2Corner.Parent = Button2

    local voted = false
    local startTime = tick()
    local timerConnection

    local function updateTimer()
        local elapsed = tick() - startTime
        local remaining = math.max(0, 20 - elapsed)
        TimerLabel.Text = string.format("%d segundos restantes", math.ceil(remaining))
        if remaining <= 0 then
            if timerConnection then timerConnection:Disconnect() end
            if activeVoteWindow then
                activeVoteWindow:Destroy()
                activeVoteWindow = nil
                activeVote = nil
            end
        end
    end

    timerConnection = RunService.Heartbeat:Connect(updateTimer)

    Button1.MouseEnter:Connect(function() if not voted then Button1.BackgroundColor3 = Color3.fromRGB(50,220,120) end end)
    Button1.MouseLeave:Connect(function() if not voted then Button1.BackgroundColor3 = Color3.fromRGB(46,204,113) end end)
    Button2.MouseEnter:Connect(function() if not voted then Button2.BackgroundColor3 = Color3.fromRGB(245,85,70) end end)
    Button2.MouseLeave:Connect(function() if not voted then Button2.BackgroundColor3 = Color3.fromRGB(231,76,60) end end)

    Button1.MouseButton1Click:Connect(function()
        if not voted and activeVote then
            voted = true
            enviarVoto(voteData.id, 1)
            Button1.BackgroundColor3 = Color3.fromRGB(30,130,70)
            Button1.Text = "Voto Registrado"
        end
    end)

    Button2.MouseButton1Click:Connect(function()
        if not voted and activeVote then
            voted = true
            enviarVoto(voteData.id, 2)
            Button2.BackgroundColor3 = Color3.fromRGB(150,50,40)
            Button2.Text = "Voto Registrado"
        end
    end)

    activeVoteWindow = ScreenGui

    task.delay(20, function()
        if timerConnection then timerConnection:Disconnect() end
        if activeVoteWindow then
            activeVoteWindow:Destroy()
            activeVoteWindow = nil
            activeVote = nil
        end
    end)
end

local function mostrarResultadosVotacao(results)
    Fluent:Notify({
        Title = "Resultados da Votação",
        Content = string.format("%s: %d%% | %s: %d%% (Total: %d votos)",
            results.vote.option1, results.results.option1,
            results.vote.option2, results.results.option2,
            results.results.total),
        Duration = 10
    })
end

-- Build UI
Tabs.GlobalMenssagem:AddInput("GlobalInput", {
    Title = "Mensagem / Comando",
    Placeholder = "Digite aqui...",
    Callback = function(Value)
        GlobalMsg = Value
    end
})

Tabs.GlobalMenssagem:AddButton({
    Title = "Enviar Mensagem",
    Callback = function()
        if GlobalMsg ~= "" then
            enviarComando(GlobalMsg)
        else
            Fluent:Notify({ Title = "Erro", Content = "Digite algo antes de enviar.", Duration = 3 })
        end
    end
})

Tabs.Conf:AddButton({
    Title = "Disconecta Global",
    Callback = function()
        enviarComando("disconecta global")
    end
})

Tabs.Conf:AddButton({
    Title = "Reset Global",
    Callback = function()
        enviarComando("reset global")
    end
})

Tabs.Conf:AddButton({
    Title = "Bring Global",
    Callback = function()
        enviarComando("bring global")
    end
})

-- Vote Tab
Tabs.VoteGlobal:AddInput("VoteQuestion", {
    Title = "Pergunta da Votação",
    Placeholder = "Digite a pergunta...",
    Callback = function(Value)
        VoteQuestion = Value
    end
})

Tabs.VoteGlobal:AddInput("VoteOption1", {
    Title = "Opção 1",
    Placeholder = "Sim (padrão)",
    Callback = function(Value)
        VoteOption1 = Value
    end
})

Tabs.VoteGlobal:AddInput("VoteOption2", {
    Title = "Opção 2",
    Placeholder = "Não (padrão)",
    Callback = function(Value)
        VoteOption2 = Value
    end
})

Tabs.VoteGlobal:AddButton({
    Title = "Iniciar Votação",
    Callback = function()
        if VoteQuestion ~= "" then
            criarVotacao(VoteQuestion, VoteOption1 ~= "" and VoteOption1 or "Sim", VoteOption2 ~= "" and VoteOption2 or "Não")
        else
            Fluent:Notify({ Title = "Erro", Content = "Digite uma pergunta!", Duration = 3 })
        end
    end
})

Window:SelectTab(1)

-- Listener loop
task.spawn(function()
    local primeiraExecucao = true
    while true do
        local httpRequest = getHttpRequest()
        if httpRequest then
            local success, response = pcall(function()
                return httpRequest({
                    Url = COMANDOS_URL,
                    Method = "GET"
                })
            end)
            if success and response and (response.StatusCode == 200 or response.status == 200) and response.Body then
                local decodeSuccess, decoded = pcall(function()
                    return HttpService:JSONDecode(response.Body)
                end)
                if decodeSuccess and type(decoded) == "table" then
                    local lista = decoded.comandos or decoded
                    if type(lista) == "table" then
                        for i = #lista, 1, -1 do
                            local dados = lista[i]
                            local eventId = getEventId(dados)
                            if not processedEventIds[eventId] then
                                processedEventIds[eventId] = true

                                local tipoNormalizado = normalizeAction(dados.tipo)
                                local acao = dados.acao or dados.conteudo
                                local isCommandEvent = tipoNormalizado == "comando_global" or tipoNormalizado == "comando" or tipoNormalizado == "command_global" or tipoNormalizado == "global_command" or (not dados.tipo and acao ~= nil)

                                if isCommandEvent then
                                    local parametros = dados.parametros or {}
                                    if dados.player ~= LocalPlayer.Name and not primeiraExecucao then
                                        pcall(function()
                                            executeGlobalAction(acao, parametros)
                                        end)
                                    end
                                elseif tipoNormalizado == "vote_start" then
                                    if not primeiraExecucao then
                                        createJanelaVotacao(dados.vote)
                                    end
                                elseif tipoNormalizado == "vote_end" then
                                    if not primeiraExecucao then
                                        mostrarResultadosVotacao(dados)
                                    end
                                elseif tipoNormalizado == "chat" then
                                    local texto = dados.conteudo or ""
                                    if texto ~= "" and not primeiraExecucao then
                                        Fluent:Notify({
                                            Title = "Anúncio de " .. (dados.player or "Sistema"),
                                            Content = texto,
                                            Duration = 6
                                        })
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        if primeiraExecucao then
            primeiraExecucao = false
        end
        task.wait(1.5)
    end
end)
