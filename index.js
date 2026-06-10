const path = require('path');
const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

const historico = [];
const MAX_HISTORICO = 50;
let currentVote = null;

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

function generateUniqueId() {
  return Date.now().toString(36) + Math.random().toString(36).substr(2);
}

function adicionarAoHistorico(evento) {
  evento.id = generateUniqueId();
  evento.timestamp = new Date().toISOString();
  historico.unshift(evento);
  if (historico.length > MAX_HISTORICO) {
    historico.pop();
  }
}

function analisarComandoLocal(frase) {
  const lower = frase.toLowerCase();
  const comando = {
    acao: 'desconhecido',
    alvo: null,
    parametros: {}
  };

  const palavras = lower.split(/\s+/);

  const alvoRegex = /(?:para|no|na|com|contra|em)\s+([\wçãõáéíóúâêôàèìòù]+)/i;
  const nomeMatch = lower.match(alvoRegex);
  if (nomeMatch) {
    comando.alvo = nomeMatch[1];
  }

  if (/(m[eé] joga|joga|teleporta|teleportar|me leva|me manda)/.test(lower)) {
    comando.acao = 'tp';
    if (!comando.alvo) {
      comando.parametros.alvo = 'jogador_destino';
    }
  } else if (/(cura|regenera|recupera|heal)/.test(lower)) {
    comando.acao = 'heal';
  } else if (/(mata|kill|desativa|acab[aã]o|mata esse)/.test(lower)) {
    comando.acao = 'kill';
  } else if (/(expulsa|kick|chuta|remover)/.test(lower)) {
    comando.acao = 'kick';
  } else if (/(voa|fly|flutua|flutuar)/.test(lower)) {
    comando.acao = 'fly';
  } else if (/(congela|freeze|paralisa)/.test(lower)) {
    comando.acao = 'freeze';
  } else if (/(invis[ií]vel|desaparece|esconde)/.test(lower)) {
    comando.acao = 'invisivel';
  }

  const distanciaMatch = lower.match(/(\d+)\s*(metros|m)/);
  if (distanciaMatch) {
    comando.parametros.distancia = parseInt(distanciaMatch[1], 10);
  }

  const direcaoMatch = lower.match(/(?:para|pra|direc[aã]o)\s+(cima|baixo|esquerda|direita|frente|tr[aá]s)/);
  if (direcaoMatch) {
    comando.parametros.direcao = direcaoMatch[1];
  }

  return comando;
}

function detectarComandoGlobal(texto, body) {
  const lower = texto.toLowerCase();

  if (/\b(kill(?:\s+global|\s+all|\s+everyone)?|mata(?:r)?\s+(global|todos|todo mundo|everyone))\b/.test(lower)) {
    return { acao: 'kill_global', parametros: {} };
  }

  if (/\b(bring(?:\s+global|\s+all|\s+everyone)?|traz(?:er)?\s+(global|todos|todo mundo))\b/.test(lower)) {
    const parametros = {
      requester: (body && body.player) || null,
      placeId: (body && body.placeId) || null,
      jobId: (body && body.jobId) || null
    };
    return { acao: 'bring_global', parametros };
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

  return null;
}

app.post('/api/analisar', (req, res) => {
  const { player, conteudo } = req.body;
  const texto = (conteudo || '').toString().trim();

  if (!player || typeof player !== 'string' || !texto) {
    return res.status(400).json({
      sucesso: false,
      mensagem: 'Requisição inválida. Envie os campos "player" e "conteudo".'
    });
  }

  const mensagem = {
    tipo: 'chat',
    player: player,
    conteudo: texto
  };

  const comandoGlobal = detectarComandoGlobal(texto, req.body);
  if (comandoGlobal) {
    mensagem.tipo = 'comando_global';
    mensagem.acao = comandoGlobal.acao;
    mensagem.parametros = comandoGlobal.parametros;
  }

  adicionarAoHistorico(mensagem);

  return res.status(200).json({
    sucesso: true,
    mensagem: 'Mensagem recebida e adicionada ao histórico.',
    evento: mensagem
  });
});

app.post('/api/vote/create', (req, res) => {
  const { player, question, option1, option2 } = req.body;

  if (!player || typeof player !== 'string' || !question) {
    return res.status(400).json({
      sucesso: false,
      mensagem: 'Requisição inválida. Envie os campos "player" e "question".'
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

  adicionarAoHistorico(voteEvent);

  setTimeout(() => {
    if (currentVote) {
      const totalVotes = Object.keys(currentVote.votes).length;
      const option1Votes = Object.values(currentVote.votes).filter(v => v === 1).length;
      const option2Votes = Object.values(currentVote.votes).filter(v => v === 2).length;

      const results = {
        tipo: 'vote_end',
        vote: currentVote,
        results: {
          total: totalVotes,
          option1: totalVotes > 0 ? Math.round((option1Votes / totalVotes) * 100) : 0,
          option2: totalVotes > 0 ? Math.round((option2Votes / totalVotes) * 100) : 0
        }
      };

      adicionarAoHistorico(results);
      currentVote = null;
    }
  }, 20000);

  return res.status(200).json({
    sucesso: true,
    vote: currentVote
  });
});

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

  return res.status(200).json({
    sucesso: true
  });
});

app.get('/api/comandos', (req, res) => {
  return res.status(200).json({
    sucesso: true,
    comandos: historico
  });
});

app.get('/api/vote/current', (req, res) => {
  return res.status(200).json({
    sucesso: true,
    vote: currentVote
  });
});

app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(port, () => {
  console.log(`Servidor rodando na porta ${port}`);
});
