
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

// CORS middleware para permitir requisições do Roblox
app.use((req, res, next) => {
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    if (req.method === 'OPTIONS') {
        return res.sendStatus(200);
    }
    next();
});

// Rate Limiting para prevenir DDoS
const apiLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutos
    max: 100, // Limita a 100 requisições por IP por window para write endpoints
    message: 'Muitas requisições! Tente novamente mais tarde.'
});
// Read endpoints get a higher limit (many clients may poll)
const readLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 1000,
    message: 'Muitas requisições! Tente novamente mais tarde.'
});
// Note: do NOT apply a global limiter to all /api/ routes; apply per-route below to avoid blocking frequent GETs (comandos/stream).

// Dados em memória
const history = [];
const MAX_HISTORY = 200;
let currentVote = null;
let idCounter = 0;
// SSE subscribers
const sseSubscribers = new Set();

// Função para gerar ID único
function generateUniqueId() {
    return Date.now().toString(36) + (++idCounter).toString(36) + Math.random().toString(36).substr(2);
}

// Adiciona evento ao histórico
function addToHistory(event) {
    event.id = generateUniqueId();
    event.timestamp = new Date().toISOString();
    event.ts = Date.now(); // numeric timestamp (ms) for efficient filtering
    history.unshift(event);
    if (history.length > MAX_HISTORY) {
        history.pop();
    }
    // Notify SSE subscribers (send new event)
    const payload = `data: ${JSON.stringify(event)}\n\n`;
    for (const res of sseSubscribers) {
        try {
            res.write(payload);
        } catch (err) {
            // ignore individual subscriber errors
        }
    }
}

// Detecta comandos globais no texto
function detectGlobalCommand(text, body) {
    const lower = (text || '').toLowerCase();
    const commandPatterns = [
        { regex: /\b(?:kill|mata|matar)(?:[_\s-]?(?:global|all|everyone|todos|todo mundo))?\b/, acao: 'kill_global' },
        { regex: /\b(?:disconecta|desconecta|disconnect|desconectar)(?:[_\s-]?(?:global|all|everyone|todos|todo mundo))?\b/, acao: 'disconecta_global' },
        { regex: /\b(?:bring|traz|trazer)(?:[_\s-]?(?:global|all|everyone|todos|todo mundo))?\b/, acao: 'bring_global' },
        { regex: /\b(?:heal|cura|curar)(?:[_\s-]?(?:global|all|everyone|todos|todo mundo))?\b/, acao: 'heal_global' },
        { regex: /\b(?:kick|expulsa|expulsar)(?:[_\s-]?(?:global|all|everyone|todos|todo mundo))?\b/, acao: 'kick_global' },
        { regex: /\b(?:fly|voa|voar)(?:[_\s-]?(?:global|all|everyone|todos|todo mundo))?\b/, acao: 'fly_global' },
        { regex: /\b(?:noclip)(?:[_\s-]?(?:global|all|everyone|todos|todo mundo))?\b/, acao: 'noclip_global' },
        { regex: /\b(?:godmode)(?:[_\s-]?(?:global|all|everyone|todos|todo mundo))?\b/, acao: 'godmode_global' },
        { regex: /\b(?:freeze)(?:[_\s-]?(?:global|all|everyone|todos|todo mundo))?\b/, acao: 'freeze_global' },
        { regex: /\b(?:reset|resetar)(?:[_\s-]?(?:global|all|everyone|todos|todo mundo))?\b/, acao: 'reset_global' },
        { regex: /\b(?:clearbackpack|clear backpack)(?:[_\s-]?(?:global|all|everyone|todos|todo mundo))?\b/, acao: 'clearbackpack_global' }
    ];

    for (const item of commandPatterns) {
        if (item.regex.test(lower)) {
            const event = { acao: item.acao, parametros: {} };
            if (item.acao === 'bring_global') {
                event.parametros.requester = (body && body.player) || null;
                event.parametros.placeId = (body && body.placeId) || null;
                event.parametros.jobId = (body && body.jobId) || null;
            }
            return event;
        }
    }

    const walkspeedMatch = text.match(/walkspeed\s+(\d+)\s+global/i);
    if (walkspeedMatch) {
        return { acao: 'walkspeed_global', parametros: { speed: parseInt(walkspeedMatch[1], 10) } };
    }

    const jumppowerMatch = text.match(/jumppower\s+(\d+)\s+global/i);
    if (jumppowerMatch) {
        return { acao: 'jumppower_global', parametros: { power: parseInt(jumppowerMatch[1], 10) } };
    }

    return null;
}

// Serve frontend
app.use(express.static(path.join(__dirname, 'public')));

// Rota para analisar mensagem/comando
app.post('/api/analisar', apiLimiter, (req, res) => {
    try {
        const { player, conteudo, placeId, jobId } = req.body;
        const text = (conteudo || '').toString().trim();

        if (!player || typeof player !== 'string' || !text) {
            return res.status(400).json({
                sucesso: false,
                mensagem: 'Requisição inválida. Envie os campos "player" e "conteudo".'
            });
        }

        // Limita tamanho da mensagem
        if (text.length > 500) {
            return res.status(400).json({
                sucesso: false,
                mensagem: 'Mensagem muito longa (máximo 500 caracteres).'
            });
        }

        const event = {
            tipo: 'chat',
            player: player,
            conteudo: text,
            placeId: placeId || null,
            jobId: jobId || null
        };

        const globalCommand = detectGlobalCommand(text, req.body);
        if (globalCommand) {
            event.tipo = 'comando_global';
            event.acao = globalCommand.acao;
            event.parametros = globalCommand.parametros;
        }

        addToHistory(event);
        return res.status(200).json({ sucesso: true, mensagem: 'Mensagem recebida.', evento: event });
    } catch (error) {
        console.error('Erro em /api/analisar:', error);
        return res.status(500).json({
            sucesso: false,
            mensagem: 'Erro interno do servidor'
        });
    }
});

// Rota para criar votação
app.post('/api/vote/create', apiLimiter, (req, res) => {
    try {
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
            try {
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
            } catch (error) {
                console.error('Erro ao encerrar votação:', error);
                currentVote = null;
            }
        }, 20000);

        return res.status(200).json({ sucesso: true, mensagem: 'Votação criada com sucesso!', vote: currentVote });
    } catch (error) {
        console.error('Erro em /api/vote/create:', error);
        return res.status(500).json({
            sucesso: false,
            mensagem: 'Erro interno do servidor'
        });
    }
});

// Rota para enviar voto
app.post('/api/vote/submit', apiLimiter, (req, res) => {
    try {
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
        return res.status(200).json({ sucesso: true, mensagem: 'Voto registrado com sucesso!' });
    } catch (error) {
        console.error('Erro em /api/vote/submit:', error);
        return res.status(500).json({
            sucesso: false,
            mensagem: 'Erro interno do servidor'
        });
    }
});

// Rota para obter comandos/eventos
app.get('/api/comandos', readLimiter, (req, res) => {
    try {
        const since = req.query.since ? parseInt(req.query.since, 10) : 0;
        if (since && !isNaN(since)) {
            const filtered = history.filter(e => (e.ts || 0) > since);
            return res.status(200).json({ sucesso: true, comandos: filtered });
        }
        return res.status(200).json({ sucesso: true, comandos: history });
    } catch (error) {
        console.error('Erro em /api/comandos:', error);
        return res.status(500).json({
            sucesso: false,
            mensagem: 'Erro ao buscar comandos'
        });
    }
});

// SSE endpoint for real-time updates from server (reduces client polling)
app.get('/api/stream', (req, res) => {
    // Set headers for SSE
    res.set({
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        Connection: 'keep-alive'
    });
    res.flushHeaders && res.flushHeaders();

    // Send a ping to establish connection
    res.write('event: connected\n');
    res.write('data: {"ok":true}\n\n');

    sseSubscribers.add(res);

    req.on('close', () => {
        sseSubscribers.delete(res);
    });
});

// Rota para obter votação atual
app.get('/api/vote/current', (req, res) => {
    try {
        return res.status(200).json({ sucesso: true, vote: currentVote });
    } catch (error) {
        console.error('Erro em /api/vote/current:', error);
        return res.status(500).json({
            sucesso: false,
            mensagem: 'Erro ao buscar votação'
        });
    }
});

app.get('/', (req, res) => {
    try {
        res.sendFile(path.join(__dirname, 'public', 'index.html'));
    } catch (error) {
        console.error('Erro ao servir index.html:', error);
        res.status(500).send('Erro ao carregar página');
    }
});

// Tratamento de erros global
app.use((err, req, res, next) => {
    console.error('Erro não tratado:', err);
    res.status(500).json({
        sucesso: false,
        mensagem: 'Erro interno do servidor'
    });
});

// Rota 404
app.use((req, res) => {
    res.status(404).json({
        sucesso: false,
        mensagem: 'Rota não encontrada'
    });
});

// Inicia o servidor
const server = app.listen(port, () => {
    console.log(`\n✅ Embee Studio Server rodando na porta ${port}`);
    console.log(`🌐 URL: http://localhost:${port}`);
    console.log('🔒 Segurança ativada: Helmet, XSS-Clean, Rate Limiting, CORS');
    console.log('📝 Status: Pronto para receber requisições\n');
});

// Tratamento de erros não capturados
process.on('unhandledRejection', (reason, promise) => {
    console.error('❌ Promise rejection não tratada:', reason);
});

process.on('uncaughtException', (error) => {
    console.error('❌ Exceção não capturada:', error);
    process.exit(1);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('📍 SIGTERM recebido, encerrando servidor...');
    server.close(() => {
        console.log('✅ Servidor encerrado');
        process.exit(0);
    });
});
