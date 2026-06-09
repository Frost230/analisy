const path = require('path');
const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

const comandosPendentes = [];
const comandosHistorico = [];
const comandosAtendidos = [];
const inicializacoes = [];

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

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

app.post('/api/analisar', (req, res) => {
  const { player, texto, conteudo } = req.body;
  const frase = (texto || conteudo || '').toString().trim();

  if (!player || !frase) {
    return res.status(400).json({
      sucesso: false,
      mensagem: 'Requisição inválida. Envie os campos "player" e "texto" (ou "conteudo").'
    });
  }

  const comando = analisarComandoLocal(frase);
  comando.player = player;
  comando.textoOriginal = frase;

  comandosPendentes.push(comando);
  comandosHistorico.push(comando);

  return res.status(200).json({
    sucesso: true,
    mensagem: 'Comando interpretado localmente e armazenado.',
    comando: comando
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
    data: new Date().toISOString()
  };

  console.log(`[LOG] O script MANUS HUB foi executado pelo jogador: ${player}`);
  inicializacoes.push(evento);

  return res.status(200).json({
    sucesso: true,
    mensagem: `Script MANUS HUB inicializado por ${player}.`,
    evento: evento
  });
});

app.get('/api/comandos/historico', (req, res) => {
  return res.status(200).json({
    sucesso: true,
    pedidos: comandosHistorico,
    atendidos: comandosAtendidos,
    inicializacoes: inicializacoes
  });
});

app.get('/api/comandos', (req, res) => {
  const comandos = [...comandosPendentes];

  comandosAtendidos.push(...comandos);
  comandosPendentes.length = 0;

  return res.status(200).json({
    sucesso: true,
    comandos: comandos
  });
});

app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(port, () => {
  console.log(`Servidor rodando na porta ${port}`);
});
