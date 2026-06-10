local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local Window = Fluent:CreateWindow({
    Title = "Embee Studio",
    SubTitle = "Painel Global",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    GlobalChat = Window:AddTab({ Title = "Global Chat", Icon = "message-square" }),
    GlobalCommands = Window:AddTab({ Title = "Global Commands", Icon = "command" }),
    VoteGlobal = Window:AddTab({ Title = "Vote Global", Icon = "check" })
}

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

local function httpRequest(options)
    local success, result = pcall(function()
        return (syn and syn.request) or (http and http.request) or http_request or request or nil
    end)
    if not success or not result then
        return nil
    end
    return result(options)
end

local function enviarComando(conteudo)
    if isSendingCommand then
        return
    end
    isSendingCommand = true
    
    task.spawn(function()
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
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = HttpService:JSONEncode(dados)
            })
        end)
        if not success or not response or not (response.StatusCode == 200 or response.status == 200) then
            Fluent:Notify({ Title = "Erro", Content = "Falha ao enviar para o servidor.", Duration = 3 })
        else
            Fluent:Notify({ Title = "Comando Enviado", Content = conteudo, Duration = 2 })
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
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = HttpService:JSONEncode(dados)
            })
        end)
        if not success or not response or not (response.StatusCode == 200 or response.status == 200) then
            Fluent:Notify({ Title = "Erro", Content = "Falha ao criar votação.", Duration = 3 })
        else
            Fluent:Notify({ Title = "Votação Criada", Content = "Votação iniciada com sucesso!", Duration = 3 })
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
        local dados = {
            player = LocalPlayer.Name,
            voteId = voteId,
            choice = choice
        }
        local success, response = pcall(function()
            return httpRequest({
                Url = VOTE_SUBMIT_URL,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = HttpService:JSONEncode(dados)
            })
        end)
        if not success or not response or not (response.StatusCode == 200 or response.status == 200) then
            Fluent:Notify({ Title = "Erro", Content = "Falha ao enviar voto.", Duration = 3 })
        else
            Fluent:Notify({ Title = "Voto Enviado", Content = "Voto registrado!", Duration = 2 })
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
                    moveDirection = moveDirection + Vector3.new(0, 1, 0)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                    moveDirection = moveDirection - Vector3.new(0, 1, 0)
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
    MainFrame.Size = UDim2.new(0, 450, 0, 320)
    MainFrame.Position = UDim2.new(0.5, -225, 0.5, -160)
    MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 16)
    UICorner.Parent = MainFrame

    local Gradient = Instance.new("UIGradient")
    Gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 20, 40)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 15, 30))
    })
    Gradient.Rotation = 45
    Gradient.Parent = MainFrame

    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(102, 126, 234)
    Stroke.Thickness = 1.5
    Stroke.Parent = MainFrame

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Name = "TitleLabel"
    TitleLabel.Size = UDim2.new(1, 0, 0, 50)
    TitleLabel.Position = UDim2.new(0, 0, 0, 10)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = "🗳️ Votação Global"
    TitleLabel.TextColor3 = Color3.fromRGB(102, 126, 234)
    TitleLabel.TextSize = 26
    TitleLabel.Font = Enum.Font.GothamBlack
    TitleLabel.Parent = MainFrame

    local QuestionLabel = Instance.new("TextLabel")
    QuestionLabel.Name = "QuestionLabel"
    QuestionLabel.Size = UDim2.new(1, -40, 0, 80)
    QuestionLabel.Position = UDim2.new(0, 20, 0, 65)
    QuestionLabel.BackgroundTransparency = 1
    QuestionLabel.Text = voteData.question
    QuestionLabel.TextColor3 = Color3.fromRGB(225, 225, 225)
    QuestionLabel.TextSize = 18
    QuestionLabel.TextWrapped = true
    QuestionLabel.TextYAlignment = Enum.TextYAlignment.Top
    QuestionLabel.Font = Enum.Font.GothamMedium
    QuestionLabel.Parent = MainFrame

    local TimerLabel = Instance.new("TextLabel")
    TimerLabel.Name = "TimerLabel"
    TimerLabel.Size = UDim2.new(1, 0, 0, 30)
    TimerLabel.Position = UDim2.new(0, 0, 0, 145)
    TimerLabel.BackgroundTransparency = 1
    TimerLabel.Text = "⏱️ 20s"
    TimerLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
    TimerLabel.TextSize = 18
    TimerLabel.Font = Enum.Font.GothamBold
    TimerLabel.Parent = MainFrame

    local Option1Button = Instance.new("TextButton")
    Option1Button.Name = "Option1Button"
    Option1Button.Size = UDim2.new(0.42, 0, 0, 55)
    Option1Button.Position = UDim2.new(0.05, 0, 0, 185)
    Option1Button.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
    Option1Button.Text = voteData.option1
    Option1Button.TextColor3 = Color3.fromRGB(255, 255, 255)
    Option1Button.TextSize = 18
    Option1Button.Font = Enum.Font.GothamBold
    Option1Button.AutoButtonColor = false
    Option1Button.Parent = MainFrame

    local Option1Corner = Instance.new("UICorner")
    Option1Corner.CornerRadius = UDim.new(0, 12)
    Option1Corner.Parent = Option1Button

    local Option2Button = Instance.new("TextButton")
    Option2Button.Name = "Option2Button"
    Option2Button.Size = UDim2.new(0.42, 0, 0, 55)
    Option2Button.Position = UDim2.new(0.53, 0, 0, 185)
    Option2Button.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
    Option2Button.Text = voteData.option2
    Option2Button.TextColor3 = Color3.fromRGB(255, 255, 255)
    Option2Button.TextSize = 18
    Option2Button.Font = Enum.Font.GothamBold
    Option2Button.AutoButtonColor = false
    Option2Button.Parent = MainFrame

    local Option2Corner = Instance.new("UICorner")
    Option2Corner.CornerRadius = UDim.new(0, 12)
    Option2Corner.Parent = Option2Button

    local voted = false
    local startTime = tick()
    local timerConnection = nil

    local function updateTimer()
        local elapsed = tick() - startTime
        local remaining = math.max(0, 20 - elapsed)
        TimerLabel.Text = string.format("⏱️ %ds", math.ceil(remaining))

        if remaining <= 0 then
            if timerConnection then
                timerConnection:Disconnect()
            end
            if activeVoteWindow then
                activeVoteWindow:Destroy()
                activeVoteWindow = nil
                activeVote = nil
            end
        end
    end

    timerConnection = RunService.Heartbeat:Connect(updateTimer)

    local function createButtonEffect(button, originalColor)
        button.MouseEnter:Connect(function()
            if not voted then
                button.BackgroundColor3 = Color3.new(
                    math.min(1, originalColor.R + 0.1),
                    math.min(1, originalColor.G + 0.1),
                    math.min(1, originalColor.B + 0.1)
                )
            end
        end)
        button.MouseLeave:Connect(function()
            if not voted then
                button.BackgroundColor3 = originalColor
            end
        end)
    end

    createButtonEffect(Option1Button, Color3.fromRGB(46, 204, 113))
    createButtonEffect(Option2Button, Color3.fromRGB(231, 76, 60))

    local function onVote(button, choice, color)
        button.MouseButton1Click:Connect(function()
            if not voted and activeVote then
                voted = true
                enviarVoto(voteData.id, choice)
                button.BackgroundColor3 = color
                button.Text = "✓ Voto Registrado!"
            end
        end)
    end

    onVote(Option1Button, 1, Color3.fromRGB(30, 130, 70))
    onVote(Option2Button, 2, Color3.fromRGB(150, 50, 40))

    activeVoteWindow = ScreenGui

    task.delay(20, function()
        if timerConnection then
            timerConnection:Disconnect()
        end
        if activeVoteWindow then
            activeVoteWindow:Destroy()
            activeVoteWindow = nil
            activeVote = nil
        end
    end)
end

local function mostrarResultadosVotacao(results)
    Fluent:Notify({
        Title = "📊 Resultados da Votação",
        Content = string.format("%s: %d%% | %s: %d%% (Total: %d votos)",
            results.vote.option1, results.results.option1,
            results.vote.option2, results.results.option2,
            results.results.total),
        Duration = 10
    })
end

local GlobalMsg = ""
Tabs.GlobalChat:AddInput("GlobalInput", {
    Title = "Mensagem / Comando",
    Placeholder = "Digite aqui...",
    Callback = function(Value) GlobalMsg = Value end
})

Tabs.GlobalChat:AddButton({
    Title = "Enviar Mensagem",
    Callback = function()
        if GlobalMsg ~= "" then
            enviarComando(GlobalMsg)
        end
    end
})

Tabs.GlobalCommands:AddButton({
    Title = "Kill Global",
    Callback = function()
        enviarComando("kill global")
    end
})

Tabs.GlobalCommands:AddButton({
    Title = "Bring Global",
    Callback = function()
        enviarComando("bring global")
    end
})

Tabs.GlobalCommands:AddButton({
    Title = "Heal Global",
    Callback = function()
        enviarComando("heal global")
    end
})

Tabs.GlobalCommands:AddButton({
    Title = "Kick Global",
    Callback = function()
        enviarComando("kick global")
    end
})

Tabs.GlobalCommands:AddButton({
    Title = "Fly Global",
    Callback = function()
        enviarComando("fly global")
    end
})

local VoteQuestion = ""
local VoteOption1 = ""
local VoteOption2 = ""

Tabs.VoteGlobal:AddInput("VoteQuestion", {
    Title = "Pergunta da Votação",
    Placeholder = "Digite a pergunta...",
    Callback = function(Value) VoteQuestion = Value end
})

Tabs.VoteGlobal:AddInput("VoteOption1", {
    Title = "Opção 1",
    Placeholder = "Sim (padrão)",
    Callback = function(Value) VoteOption1 = Value end
})

Tabs.VoteGlobal:AddInput("VoteOption2", {
    Title = "Opção 2",
    Placeholder = "Não (padrão)",
    Callback = function(Value) VoteOption2 = Value end
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

task.spawn(function()
    local primeiraExecucao = true

    local function processarItemDoSite(dados)
        if not dados.id then
            return
        end
        if processedEventIds[dados.id] then
            return
        end
        processedEventIds[dados.id] = true

        if dados.tipo == "comando_global" then
            local acao = dados.acao
            local parametros = dados.parametros or {}

            if not primeiraExecucao then
                if acao == "kill_global" then
                    Fluent:Notify({ Title = "Comando Global", Content = "Kill Global ativado!", Duration = 3 })
                    killPlayer(getCharacter())
                elseif acao == "bring_global" then
                    Fluent:Notify({ Title = "Comando Global", Content = "Bring Global - teleportando...", Duration = 5 })
                    if parametros.placeId and parametros.jobId then
                        TeleportService:TeleportToPlaceInstance(parametros.placeId, parametros.jobId, LocalPlayer)
                    end
                elseif acao == "heal_global" then
                    Fluent:Notify({ Title = "Comando Global", Content = "Heal Global ativado!", Duration = 3 })
                    healPlayer(getCharacter())
                elseif acao == "kick_global" then
                    Fluent:Notify({ Title = "Comando Global", Content = "Kick Global ativado!", Duration = 3 })
                    kickPlayer()
                elseif acao == "fly_global" then
                    Fluent:Notify({ Title = "Comando Global", Content = "Fly Global ativado!", Duration = 3 })
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
                Fluent:Notify({
                    Title = "Anúncio Global de " .. (dados.player or "Sistema"),
                    Content = texto,
                    Duration = 6
                })
            end
        end
    end

    while true do
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
                        processarItemDoSite(lista[i])
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
