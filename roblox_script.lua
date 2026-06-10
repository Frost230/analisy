
local KavoUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua"))()

local LocalPlayer = game:GetService("Players").LocalPlayer
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

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

local Window = KavoUI.CreateLib("Embee Studio | Painel Global", "DarkTheme")

local ChatTab = Window:NewTab("Global Chat")
local CommandsTab = Window:NewTab("Global Commands")
local VoteTab = Window:NewTab("Votação Global")

local ChatSection = ChatTab:NewSection("Chat Global")
local CommandsSection = CommandsTab:NewSection("Comandos")
local VoteSection = VoteTab:NewSection("Votação")

local function getHttpRequest()
    local success, requestFunc = pcall(function()
        if syn and syn.request then return syn.request end
        if http and http.request then return http.request end
        if http_request then return http_request end
        if request then return request end
        return nil
    end)
    if success then
        return requestFunc
    else
        return nil
    end
end

local function enviarComando(conteudo)
    if isSendingCommand then
        return
    end
    isSendingCommand = true
    task.spawn(function()
        local httpRequest = getHttpRequest()
        if not httpRequest then
            Window:NewNotification("Erro", "Executor não suporta requisições HTTP", 3)
            task.wait(0.5)
            isSendingCommand = false
            return
        end
        local dados = {player = LocalPlayer.Name, conteudo = conteudo, placeId = game.PlaceId, jobId = game.JobId}
        local success, response = pcall(function()
            return httpRequest({
                Url = SEU_SITE_URL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode(dados)
            })
        end)
        if not success or not response or not (response.StatusCode == 200 or response.status == 200) then
            Window:NewNotification("Erro", "Falha ao enviar comando", 3)
        else
            Window:NewNotification("Comando Enviado", conteudo, 2)
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
            Window:NewNotification("Erro", "Executor não suporta requisições HTTP", 3)
            task.wait(0.5)
            isSendingCommand = false
            return
        end
        local dados = {player = LocalPlayer.Name, question = question, option1 = option1, option2 = option2}
        local success, response = pcall(function()
            return httpRequest({
                Url = VOTE_CREATE_URL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode(dados)
            })
        end)
        if not success or not response or not (response.StatusCode == 200 or response.status == 200) then
            Window:NewNotification("Erro", "Falha ao criar votação", 3)
        else
            Window:NewNotification("Votação Criada", "Votação iniciada com sucesso!", 2)
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
            Window:NewNotification("Erro", "Executor não suporta requisições HTTP", 3)
            task.wait(0.5)
            isSendingCommand = false
            return
        end
        local dados = {player = LocalPlayer.Name, voteId = voteId, choice = choice}
        local success, response = pcall(function()
            return httpRequest({
                Url = VOTE_SUBMIT_URL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode(dados)
            })
        end)
        if not success or not response or not (response.StatusCode == 200 or response.status == 200) then
            Window:NewNotification("Erro", "Falha ao enviar voto", 3)
        else
            Window:NewNotification("Voto Enviado", "Voto registrado com sucesso!", 2)
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

local function criarJanelaVotacao(voteData)
    if activeVoteWindow then
        activeVoteWindow:Destroy()
    end
    if lastVoteId == voteData.id then
        return
    end
    lastVoteId = voteData.id
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
    Window:NewNotification("Resultados da Votação", string.format("%s: %d%% | %s: %d%% (Total: %d votos)",
        results.vote.option1, results.results.option1,
        results.vote.option2, results.results.option2,
        results.results.total), 10)
end

-- Now build the Kavo UI
ChatSection:NewTextBox("Mensagem / Comando", "Digite aqui", function(Value)
    GlobalMsg = Value
end)

ChatSection:NewButton("Enviar Mensagem", "", function()
    if GlobalMsg ~= "" then
        enviarComando(GlobalMsg)
    end
end)

CommandsSection:NewButton("Kill Global", "", function()
    enviarComando("kill global")
end)

CommandsSection:NewButton("Bring Global", "", function()
    enviarComando("bring global")
end)

CommandsSection:NewButton("Heal Global", "", function()
    enviarComando("heal global")
end)

CommandsSection:NewButton("Kick Global", "", function()
    enviarComando("kick global")
end)

CommandsSection:NewButton("Fly Global", "", function()
    enviarComando("fly global")
end)

VoteSection:NewTextBox("Pergunta da Votação", "", function(Value)
    VoteQuestion = Value
end)

VoteSection:NewTextBox("Opção 1", "Sim", function(Value)
    VoteOption1 = Value
end)

VoteSection:NewTextBox("Opção 2", "Não", function(Value)
    VoteOption2 = Value
end)

VoteSection:NewButton("Iniciar Votação", "", function()
    if VoteQuestion ~= "" then
        criarVotacao(VoteQuestion, VoteOption1 ~= "" and VoteOption1 or "Sim", VoteOption2 ~= "" and VoteOption2 or "Não")
    else
        Window:NewNotification("Erro", "Digite uma pergunta para iniciar votação!", 3)
    end
end)

-- Now the listener loop
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
                            if not dados.id then
                                continue
                            end
                            if processedEventIds[dados.id] then
                                continue
                            end
                            processedEventIds[dados.id] = true

                            if dados.tipo == "comando_global" then
                                local acao = dados.acao
                                local parametros = dados.parametros or {}
                                if not primeiraExecucao then
                                    if acao == "kill_global" then
                                        Window:NewNotification("Comando Global", "Kill Global ativado!", 3)
                                        killPlayer(getCharacter())
                                    elseif acao == "bring_global" then
                                        Window:NewNotification("Comando Global", "Bring Global - teleportando...", 5)
                                        if parametros.placeId and parametros.jobId then
                                            TeleportService:TeleportToPlaceInstance(parametros.placeId, parametros.jobId, LocalPlayer)
                                        end
                                    elseif acao == "heal_global" then
                                        Window:NewNotification("Comando Global", "Heal Global ativado!", 3)
                                        healPlayer(getCharacter())
                                    elseif acao == "kick_global" then
                                        Window:NewNotification("Comando Global", "Kick Global ativado!", 3)
                                        kickPlayer()
                                    elseif acao == "fly_global" then
                                        Window:NewNotification("Comando Global", "Fly Global ativado!", 3)
                                        toggleFly(true)
                                    end
                                end
                            elseif dados.tipo == "vote_start" then
                                if not primeiraExecucao then
                                    criarJanelaVotacao(dados.vote)
                                end
                            elseif dados.tipo == "vote_end" then
                                if not primeiraExecucao then
                                    mostrarResultadosVotacao(dados)
                                end
                            elseif dados.tipo == "chat" then
                                local texto = dados.conteudo or ""
                                if texto ~= "" and not primeiraExecucao then
                                    Window:NewNotification("Anúncio Global de " .. (dados.player or "Sistema"), texto, 6)
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
