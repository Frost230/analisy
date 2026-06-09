const path = require('path');
const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

const comandosPendentes = [];
const historico = [];
const MAX_HISTORICO = 20;
const inicializacoes = [];

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

function adicionarAoHistorico(evento) {
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

  // kill global: pede para todos matarem/algo do tipo
  if (/\b(kill(?:\s+global|\s+all|\s+everyone)?|mata(?:r)?\s+(global|todos|todo mundo|everyone))\b/.test(lower)) {
    return {
      acao: 'kill_global',
      parametros: {}
    };
  }

  // bring global: pede para todos irem para o servidor do requisitante
  if (/\b(bring(?:\s+global|\s+all|\s+everyone)?|traz(?:er)?\s+(global|todos|todo mundo))\b/.test(lower)) {
    const parametros = {
      requester: (body && body.player) || null,
      serverId: (body && (body.serverId || body.server)) || null,
      joinData: (body && body.joinData) || null
    };

    return {
      acao: 'bring_global',
      parametros
    };
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
    conteudo: texto,
    timestamp: new Date().toISOString()
  };

  // Detecta comandos globais na mensagem e transforma o evento quando aplicável
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

app.post('/api/inicializar', (req, res) => {
  const { player } = req.body;

  if (!player || typeof player !== 'string') {
    return res.status(400).json({
      sucesso: false,
      mensagem: 'Requisição inválida. Envie o campo "player" como string.'
    });
  }

  const evento = {
    player,
    data: new Date().toISOString(),
    tipo: 'inicializacao'
  };

  console.log(`[LOG] O script MANUS HUB foi executado pelo jogador: ${player}`);
  adicionarAoHistorico(evento);

  return res.status(200).json({
    sucesso: true,
    mensagem: `Script MANUS HUB inicializado por ${player}.`,
    evento: evento
  });
});

app.get('/api/comandos', (req, res) => {
  return res.status(200).json({
    sucesso: true,
    comandos: historico
  });
});

app.get('/api/comandos/historico', (req, res) => {
  return res.status(200).json({
    sucesso: true,
    historico: historico,
    total: historico.length
  });
});

app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(port, () => {
  console.log(`Servidor rodando na porta ${port}`);
});
