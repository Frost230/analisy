
const path = require('path');
const express = require('express');
const rateLimit = require('express-rate-limit');
const helmet = require('helmet');
const xss = require('xss-clean');
const app = express();
const port = process.env.PORT || 3000;

// Middleware de segurança
app.use(helmet()); // Helmet para headers de segurança
app.use(xss()); // Sanitiza entrada para prevenir XSS
app.use(express.json({ limit: '10kb' })); // Limita tamanho do body para prevenir ataques

// Rate Limiting para prevenir DDoS
const apiLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutos
    max: 100, // Limita a 100 requisições por IP por window
    message: 'Muitas requisições! Tente novamente mais tarde.'
});
app.use('/api/', apiLimiter); // Aplica limitação a todas rotas API

// Dados em memória
const history = [];
const MAX_HISTORY = 200;
let currentVote = null;
let idCounter = 0;

// Função para gerar ID único
function generateUniqueId() {
    return Date.now().toString(36) + (++idCounter).toString(36) + Math.random().toString(36).substr(2);
}

// Adiciona evento ao histórico
function addToHistory(event) {
    event.id = generateUniqueId();
    event.timestamp = new Date().toISOString();
    history.unshift(event);
    if (history.length > MAX_HISTORY) {
        history.pop();
    }
}

// Detecta comandos globais no texto
function detectGlobalCommand(text, body) {
    const lower = text.toLowerCase();
    if (/\b(kill(?:\s+global|\s+all|\s+everyone)?|mata(?:r)?\s+(global|todos|todo mundo|everyone))\b/.test(lower)) {
        return { acao: 'kill_global', parametros: {} };
    }
    if (/\b(bring(?:\s+global|\s+all|\s+everyone)?|traz(?:er)?\s+(global|todos|todo mundo))\b/.test(lower)) {
        return {
            acao: 'bring_global',
            parametros: {
                requester: (body && body.player) || null,
                placeId: (body && body.placeId) || null,
                jobId: (body && body.jobId) || null
            }
        };
    }
    if (/\b(heal(?:\s+global|\s+all|\s+everyone)?|cura(?:r)?\s+(global|todos|todo mundo|everyone))\b/.test(lower)) {
        return { acao: 'heal_global', parametros: {} };
    }
    if (/\b(kick(?:\s+global|\s+all|\s+everyone)?|expulsa(?:r)?\s+(global|todos|todo mundo|everyone))\b/.test(lower)) {
        return { acao: 'kick_global', parametros: {} };
    }
    if (/\b(fly(?:\s+global|\s+all|\s+everyone)?|voa(?:r)?\s+(global|todos|todo mundo|everyone))\b/.test(lower)) {
        return { acao: 'fly_global', parametros: {} };
    }
    if (/\b(noclip(?:\s+global|\s+all|\s+everyone)?)\b/.test(lower)) {
        return { acao: 'noclip_global', parametros: {} };
    }
    if (/\b(superjump(?:\s+global|\s+all|\s+everyone)?)\b/.test(lower)) {
        return { acao: 'superjump_global', parametros: {} };
    }
    if (/\b(godmode(?:\s+global|\s+all|\s+everyone)?)\b/.test(lower)) {
        return { acao: 'godmode_global', parametros: {} };
    }
    if (/\b(particles(?:\s+global|\s+all|\s+everyone)?)\b/.test(lower)) {
        return { acao: 'particles_global', parametros: {} };
    }
    if (/\b(rainbow(?:\s+global|\s+all|\s+everyone)?)\b/.test(lower)) {
        return { acao: 'rainbow_global', parametros: {} };
    }
    return null;
}

// Serve frontend
app.use(express.static(path.join(__dirname, 'public')));

// Rota para analisar mensagem/comando
app.post('/api/analisar', (req, res) => {
    const { player, conteudo } = req.body;
    const text = (conteudo || '').toString().trim();

    if (!player || typeof player !== 'string' || !text) {
        return res.status(400).json({
            sucesso: false,
            mensagem: 'Requisição inválida. Envie os campos "player" e "conteudo".'
        });
    }

    const event = {
        tipo: 'chat',
        player: player,
        conteudo: text
    };

    const globalCommand = detectGlobalCommand(text, req.body);
    if (globalCommand) {
        event.tipo = 'comando_global';
        event.acao = globalCommand.acao;
        event.parametros = globalCommand.parametros;
    }

    addToHistory(event);
    return res.status(200).json({ sucesso: true, mensagem: 'Mensagem recebida.', evento: event });
});

// Rota para criar votação
app.post('/api/vote/create', (req, res) => {
    const { player, question, option1, option2 } = req.body;

    if (!player || typeof player !== 'string' || !question) {
        return res.status(400).json({
            sucesso: false,
            mensagem: 'Requisição inválida.'
        });
    }

    if (currentVote) {
        return res.status(400).json({
            sucesso: false,
            mensagem: 'Já há uma votação ativa.'
        });
    }

    currentVote = {
        id: generateUniqueId(),
        creator: player,
        question: question,
        option1: option1 || 'Sim',
        option2: option2 || 'Não',
        votes: {},
        startTime: Date.now(),
        duration: 20000
    };

    const voteEvent = {
        tipo: 'vote_start',
        player: player,
        vote: currentVote
    };

    addToHistory(voteEvent);

    // Timer para encerrar votação
    setTimeout(() => {
        if (currentVote) {
            const totalVotes = Object.keys(currentVote.votes).length;
            const option1Votes = Object.values(currentVote.votes).filter(v => v === 1).length;
            const option2Votes = Object.values(currentVote.votes).filter(v => v === 2).length;

            const resultsEvent = {
                tipo: 'vote_end',
                vote: currentVote,
                results: {
                    total: totalVotes,
                    option1: totalVotes > 0 ? Math.round((option1Votes / totalVotes) * 100) : 0,
                    option2: totalVotes > 0 ? Math.round((option2Votes / totalVotes) * 100) : 0
                }
            };

            addToHistory(resultsEvent);
            currentVote = null;
        }
    }, 20000);

    return res.status(200).json({ sucesso: true, vote: currentVote });
});

// Rota para enviar voto
app.post('/api/vote/submit', (req, res) => {
    const { player, voteId, choice } = req.body;

    if (!player || typeof player !== 'string' || !voteId || !choice) {
        return res.status(400).json({
            sucesso: false,
            mensagem: 'Requisição inválida.'
        });
    }

    if (!currentVote || currentVote.id !== voteId) {
        return res.status(400).json({
            sucesso: false,
            mensagem: 'Votação não está ativa ou já terminou.'
        });
    }

    if (currentVote.votes[player]) {
        return res.status(400).json({
            sucesso: false,
            mensagem: 'Você já votou!'
        });
    }

    currentVote.votes[player] = choice;
    return res.status(200).json({ sucesso: true });
});

// Rota para obter comandos/eventos
app.get('/api/comandos', (req, res) => {
    return res.status(200).json({ sucesso: true, comandos: history });
});

// Rota para obter votação atual
app.get('/api/vote/current', (req, res) => {
    return res.status(200).json({ sucesso: true, vote: currentVote });
});

app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Inicia o servidor
app.listen(port, () => {
    console.log(`Embee Studio Server rodando na porta ${port}`);
    console.log('Segurança ativada: Helmet, XSS-Clean, Rate Limiting');
});
