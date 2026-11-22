# Junk Construction Simulator

Jogo de construção física inspirado na ideia de *Metalworks Sandbox Demo* (Roblox, 2014):
pegue sucata espalhada pelo mapa, **corte**, **solde** e monte estruturas e máquinas.
Nome, mapa, visual e código são próprios.

- Engine: **Godot 4.7.2** (física **Jolt**)
- Plataforma: Windows (PC)

## Como jogar

- **Só jogar:** abra `JunkConstructionSimulator.exe` (não precisa instalar nada).
- **Atualizar:** rode o `Atualizar.bat` (vem dentro da pasta do jogo e também fica avulso em cada Release).
  Ele baixa a versão mais recente e extrai na pasta `JunkConstructionSimulator`.
- **Imagem estranha (partes pretas, quadrados)?** No menu (Esc), mude **Gráficos** para
  Médio ou Baixo. Se não resolver, use `Abrir com Vulkan.bat` ou
  `Abrir em modo compatibilidade.bat`, que vêm junto com o `.exe`.
- **Abrir o projeto:** instale o Godot 4.7.2 (versão padrão, não a .NET). Abra o
  `project.godot` e aperte **F5**.

## Controles

| Ação | Tecla |
|---|---|
| Andar / pular | W A S D / Espaço |
| Correr | toque duplo numa tecla de andar (ou Shift), também segurando algo com o Gravitador |
| Agachar (mais devagar, alcança mais baixo) | Ctrl |
| Trocar ferramenta | 1 Gravitador · 2 Solda · 3 Esmerilhadeira · 4 Fiação · 5 Depurador · 6 Trena · 7 Alinhador · 8 Laser · 9 Transmissão |
| Trocar ferramenta (estilo Garry's Mod) | roda do mouse escolhe, clique confirma, botão direito cancela |
| Usar (loja, assento, botão, alavanca, engate rápido) | E |
| Puxar um puxador (portas, tampas...) | E segurado |
| Modo edição do assento (sentado) | Tab |
| Ajuda / menu / FPS / tela cheia | H / Esc / F3 / F11 |

**Gravitador (no estilo da physics gun do Garry's Mod)**
- Clique segurado: pega a peça, que segue a mira e gira junto com você. Tudo o que está ligado a ela
  por juntas vem junto, como um bloco só (as juntas não são arrancadas).
- Soltar o clique: a peça volta a ter física (dá para arremessar).
- **Botão direito** (segurando): **congela** a peça no lugar.
- **E + mover o mouse**: gira a peça. Com **Shift**, em passos de 15°.
- Roda do mouse (segurando): aproxima ou afasta. Sem segurar nada, a roda escolhe a ferramenta. **T**: alinha à grade do mundo.
- **R** mirando numa peça congelada: descongela (e o que estiver ligado a ela por juntas).
  **R duas vezes**: descongela tudo.

**Solda**
- Segure o clique bem na emenda entre duas peças: cria um **ponto de solda** (bolinha).
  A solda só alcança o que está dentro da bolinha. Arraste segurando para fazer vários pontos.
- **R** troca o tamanho do ponto: **pequeno** (5 cm, só alcança o que está encostado; ex.: roda no disco do motor
  sem pegar a carcaça), **normal** (10 cm) e **grande** (16 cm).
- A solda pega a peça **mais próxima** do ponto. Se ela uniria os dois lados de um componente (travando ele, ex.: disco
  na carcaça do motor), não solda e avisa; **Shift + clique** solda mesmo assim.
- Peças soldadas viram um corpo só.
- Soldar uma peça no chão ou numa estrutura do mapa **ancora** a montagem (ela fica parada).

**Esmerilhadeira**
- **Segure** o clique: corta **a face que está na mira**. A linha de corte fica sobre essa face (prévia laranja).
  O corte trava no lugar ao clicar; soltar antes de terminar cancela.
- **R**: gira a linha de corte sobre a face: 0°, 45°, 90°, 135°.
- O corte encaixa numa grade de 5 cm; **G** liga/desliga a grade (corte livre).
- Prévia **vermelha** = perto demais da borda; mire mais para dentro da face.
- O corte passa pela **marca da Trena** mais próxima (cruz vermelha), antes da grade.
- Segure o clique numa bolinha de solda para removê-la, ou num isolador para arrancá-lo.

**Trena (6)** — medir e marcar
- Clique: ponto **A**. A distância até a mira aparece no meio da linha e embaixo, separada nos eixos
  da peça (x, y, z). Outro clique fixa o ponto **B** (os pontos acompanham a peça se ela se mexer).
- Mirando numa peça sem medida: mostra a distância do ponto até as bordas.
- **Botão direito**: põe ou tira uma **marca** (cruz vermelha) na peça. A Esmerilhadeira corta pela marca.
  As marcas vão junto quando a peça é cortada e ficam salvas no mundo.
- Os pontos encaixam na grade de 5 cm da peça (a mesma do corte). **G** liga/desliga. **R** limpa a medida.

**Alinhador (7)** — no estilo do *Precision Alignment* do Garry's Mod
- 1º clique: um ponto na peça que vai **se mover** (grade de 5 cm ou uma marca).
- 2º clique: o ponto de **destino**, em outra peça ou no chão.
- A peça vai até lá: os dois pontos se encontram, as faces ficam encostadas uma na outra e o giro fica em
  esquadro (90°) com a peça de destino. O que estiver preso a ela por juntas vai junto.
- Depois do 1º clique, uma **prévia transparente** mostra onde ela vai ficar (com ou sem Shift).
- Ela fica **congelada** no lugar, pronta para soldar. **R** com o Gravitador solta.
  Dá para realinhar algo congelado; só o que está soldado no chão prende.
- **Shift** no 2º clique: só move (não gira). Botão direito cancela.

**Máquinas**
- Componentes:
  - **motor** (simples: gira; sem sinal fica rígido ou solto). **Limitado** (até 800 N·m e 12 rad/s): bom só para
    veículo pessoal. Para força e velocidade de verdade, use o **trem de força** (abaixo). A velocidade sobe e
    desce em rampa (**Arrancada**, 1 s por padrão): as rodas não patinam ao sair nem derrapam ao parar;
  - **servo** (vai até um ângulo e segura);
  - **pistão** (empurra 0,5 m; sem sinal volta ou fica parado). Nos ajustes, o modo **amortecedor** vira
    suspensão: mola + amortecimento com **rigidez**, **amortecimento** e **altura sem carga** ajustáveis;
    teclas/sinal sobem e descem a altura (suspensão hidráulica);
  - **servo linear** (vai até uma posição e segura);
  - **dobradiça** (gira livre até quase dobrar);
  - **dobradiça de pino** (eixo livre, volta inteira);
  - **junta esférica** (inclina para qualquer lado);
  - **dobradiça com trava** (gira livre; com sinal trava no ângulo em que está, ou o contrário);
  - **dobradiça de torção** (gira, mas sempre volta sozinha, como uma mola);
  - **mola** (suspensão: comprime com o peso e volta; rigidez ajustável);
  - **guincho** (cabo entre o corpo e o gancho: sinal + recolhe, − solta, sem sinal segura);
  - **propulsor** (empurra para o lado da ponta lisa; a chama sai pelo bocal);
  - **eletroímã** (ligado, puxa e gruda aço e ferro na face de metal; alumínio não);
  - **engate rápido** (trava no que encostar na face listrada; liga com **E** ou com sinal);
  - **dobradiça de pino octogonal** (como a de pino, com dois tambores octogonais: 8 faces para soldar);
  - **roda**, **assento** e **puxador** (alça: segure **E** nela e mova a mira para puxar com força fraca,
    bom para portas e tampas; afastar demais solta).
- **Formato:** tudo o que é "cilíndrico" é **octogonal** (pistão, hastes, discos, propulsor, ímã, isolador,
  cilindros da loja), menos a roda, que continua redonda.
- **Tamanhos:** os componentes mecânicos (motor, servo, pistão, servo linear, todas as dobradiças, junta esférica,
  mola e guincho) vêm em **pequeno** (0,6×), **médio** (o de antes) e **grande** (1,6×).
  A força cresce com o tamanho ao cubo (o grande tem ~4× a força do médio), o curso e a velocidade dos pistões
  crescem junto. A **roda** também: pequena (a de antes), média e grande, e o raio/largura continuam ajustáveis.
  Na loja, escolha o tamanho; na frente do depósito do galpão há grandes, pequenos e rodas média/grande.

  Ficam no depósito do galpão, espalhados pelo mapa e à venda na loja.
- Solde a base (carcaça) na estrutura e a peça que se mexe (disco, haste, folha, placa) no que ela deve mover.
  Os dois lados de um componente **colidem** entre si (o que está soldado de um lado bate no outro). Nos ajustes
  há a opção **"Colidir com o que está do outro lado"** para desligar (ex.: roda encostada na carcaça).
  Pistão e servo linear nunca colidem entre os lados (a haste corre por dentro da camisa).
- Peças soltas usam detecção contínua de colisão: chapas finas (5 cm) não atravessam umas às outras mesmo
  arremessadas. Exceção: duas chapas finas vindo rápido **uma contra a outra** (mais de ~30 m/s somadas) ainda
  podem passar; por isso o arremesso do Gravitador vai até 40 m/s.
- A física resolve as juntas com mais precisão (96 iterações de velocidade / 24 de posição por tick): suspensões
  com várias dobradiças em cadeia (ex.: dianteira estilo Model-T) não dobram ao acelerar e frear.
- Peças muito leves ligadas por juntas a peças muito pesadas (roda de 15 kg num carro de 2 t) ganham "massa de
  inércia" só para a física, com o peso igual. Assim as juntas não cedem sob carga.
- **Assento:** E para sentar. Ele controla todos os componentes ligados à mesma máquina.
  **Tab** abre o **modo edição**: os componentes configuráveis ficam destacados (através de tudo) e o mouse fica livre.
  Clique num componente para escolher até 2 teclas (ou botões do mouse) por sentido, "alternar", "inverter",
  velocidade, força, ângulo e as opções de cada um. Botão direito + arrastar gira a câmera.
- **Controles sem teclas:**
  - **botão** (liga enquanto aperta);
  - **alavanca** (liga/desliga);
  - **alavanca variável** (segure **E** e mova o mouse para cima/baixo).
- **Fiação (4):** clique no controle, depois nas superfícies por onde o fio deve passar (cada clique cria um
  **isolador**, opcional) e por fim no componente. **Botão direito**:
  - num isolador: remove;
  - numa alavanca variável: alterna entre -1 a 1 e só positivo;
  - num componente: abre os ajustes dele (mola, torção, dobradiças e junta esférica não usam teclas, mas têm ajustes).
- Perto de onde você nasce tem um **carrinho de exemplo**: sente e use W/S/A/D.

**Lógica e sinais** (estilo Wiremod)
- Toda peça com sinais tem **entradas** e **saídas** com tipo: número, vetor (X, Y, Z), texto, peça ou lista.
  Controles, componentes (o motor dá Ângulo e Giro, o pistão dá Extensão...), chips, teclas, assento e telas.
  Lógica é de graça: sinais não gastam energia.
- **Fiação (4):** clique na peça de origem e escolha a saída, passe pelos isoladores (opcional) e clique no destino
  escolhendo a entrada (só aparecem as do mesmo tipo). O menu aparece sempre, mesmo com uma porta só.
  As pontas do fio ficam presas onde você clicou na peça. Escolher a mesma ligação de novo desliga o fio.
  Vários fios numa entrada de número somam. Cor do fio = tipo; aceso quando tem sinal.
- **Chip lógico:** uma peça só com 86 modos (botão direito com a Fiação para escolher):
  - lógica (E, OU, NÃO, XOU...) e comparação;
  - aritmética (somar, dividir, limitar, converter faixa...);
  - memória (latch, liga/desliga, alternador, contador, RAM) e seleção (se/então, multiplexador, roteador);
  - tempo (cronômetro, pulsador, pisca, temporizador, atraso, acumulador, suavizar);
  - trigonometria em graus, bits, vetores e textos.
- **Entradas:** valor constante (número, vetor ou texto), **Teclas** (+/−, sentado na máquina ou sempre),
  **Teclado de senha** (E nele), e o **assento**, que dá W, A, S, D, Espaço, Shift, cliques, Ocupado e Mira.
- **Mostradores:** indicador (cor pelo valor), pixel (cor RGB), mostrador numérico, tela de valores e tela de texto
  (modelo com {A}, {B}, {C}, {D} e {texto}).
- **Depurador (5):** mire numa peça para ver todas as entradas e saídas ao vivo; botão direito dá nome e ajustes.
- Tudo isso fica no depósito **ELETRÔNICA** (ao lado do galpão) e na loja.

**Energia elétrica** (Marco 4B)
- **Fio de energia:** na Fiação (4), aperte **G** para trocar para o fio de energia (vermelho, mais grosso). Clique numa
  peça de energia, nos isoladores (opcional) e na outra peça. Clicar de novo no mesmo par remove o fio.
- **Rede:** tudo o que está ligado pelos fios de energia divide a mesma carga (as baterias enchem e esvaziam juntas).
  Relé e chave desligados cortam a rede naquele ponto.
- **Peças** (depósito ELETRÔNICA e loja, categoria Energia):
  - **bateria** pequena / média / grande (10,8 / 50 / 205 Wh); saídas Carga e %;
  - **painel solar:** até 25 W de graça, virado para o sol;
  - **posto de recarga:** 1500 W pagos com pontos (1 ponto a cada 10 Wh); só funciona **soldado no chão**. Tem um
    ao lado do depósito ELETRÔNICA (placa RECARGA);
  - **luz** (até 15 W) e **holofote** (até 50 W): cor, brilho e alcance nos ajustes (botão direito com a Fiação);
    entradas Liga (0 a 1) e Cor (vetor 0 a 255);
  - **relé de potência** (entrada Liga) e **chave de energia** (E): ligam e desligam a passagem;
  - **medidor:** mostra e manda como sinal a Carga, Capacidade, %, Consumo e Geração da rede.
- A cada instante: o sol alimenta as luzes; o que faltar vem do posto (se houver) e depois das baterias. Sem carga,
  as luzes ficam mais fracas na proporção. Sobrando, as baterias carregam.
- Lógica continua de graça. Os componentes simples (motor, servo, pistão...) não gastam energia.

**Trem de força** (Marco 4D, estilo ACF; depósito MOTORES e loja: Motores, Câmbios, Combustível)
- Ligue as peças com a ferramenta **Transmissão (9)**: clique numa peça e depois na outra. **Qualquer peça liga em
  qualquer outra, em qualquer ordem** (tanque, bateria, motor, embreagem, câmbio, gerador, cubo de roda). A
  simulação acha sozinha o caminho de cada motor até as rodas: os câmbios do caminho multiplicam as relações,
  as embreagens do caminho limitam o torque e o tanque pode estar ligado em qualquer ponto da rede. O que não faz
  sentido (diesel num motor a gasolina, por exemplo) fica ligado, só não faz nada; a dica da ferramenta avisa.
  As ligações são invisíveis (só aparecem com a ferramenta na mão) e **quebram se esticarem 1,5×**. Botão direito
  numa peça desfaz as ligações dela.
- **Cubo de roda:** eixo livre. Solde a base no chassi (com o eixo para fora) e a roda no disco. Ajustes (botão
  direito com a Fiação): **Inverter o giro** (marque nos cubos de um dos lados, cujo eixo aponta para o outro lado)
  e **Lado** esquerdo/direito (usado pelo esterço de tanque).
- **Embreagens:** **automática** (sai patinando no giro de arrancada, como um carro de verdade) e **manual**
  (entrada Pedal: 1 = pedal no fundo, solta o motor das rodas). Saídas Engate e Patinação. Sem embreagem no
  caminho, o motor fica preso às rodas.
- **Motores** (8): monocilíndrico, 4 em linha, V8, V12, diesel, rotativo, elétrico (usa bateria: bateria → motor)
  e turbina. RPM com volante, curva de torque, marcha lenta, corte de giro e partida; sem combustível, desliga.
  Entradas Acelerador (0 a 1) e Ligado (sem fio, liga sozinho). Saídas RPM, Torque, Potência, Consumo e Ligado.
  Som que segue o giro.
- **Câmbios:** manual (Sobe/Desce ou Marcha), automático (troca sozinho) e CVT. Entradas Freio, Ré (com o carro
  andando para a frente, freia antes de engatar) e, com **esterço de tanque** (diferencial duplo), Esq/Dir/Esterço
  (gira no lugar). Dá para ligar câmbio em câmbio: as relações multiplicam.
- **Gerador:** motor → gerador (Transmissão) e o gerador na rede (fio de energia): até 400 W.
- **Combustível:** tanques de gasolina e diesel (P/M/G; médio 40 L). Abasteça na **bomba de combustível** (E nela,
  1 ponto a cada 5 L; só soldada no chão). Tem uma ao lado do posto RECARGA.
- **Carro de exemplo novo** perto do antigo (tanque, motor, embreagem automática, câmbio e 4 cubos): W acelera,
  S dá ré, A/D viram (tanque), Espaço freia.

**Sensores** (Marco 4C, depósito ELETRÔNICA e loja, categoria Sensores)
- Todos mandam o que medem como sinal (ligue com a Fiação). Ajustes: botão direito com a Fiação.
  - **Medidor laser:** o laser sai pela face de cima; Distância, Acertou, Posição, Normal, Peça, Velocidade e Material do
    que acertar. Alcance até 200 m, laser visível ou não, ignora a própria máquina.
  - **Velocímetro:** Velocidade (m/s), km/h, Local (X/Y/Z nos eixos dele) e Giro.
  - **Giroscópio:** Pitch, Yaw e Roll em graus (frente = -Z).
  - **GPS:** Posição e X/Y/Z; a entrada **Marcar** guarda o ponto e a saída Distância mede até ele.
  - **Localizador** + **sensor de localizador:** distância e direção até o localizador mais perto do mesmo canal.
  - **Buscador de alvos:** procura num raio (jogador, peças, componentes ou localizadores): Quantidade, Alvo,
    Posição, Distância e a lista.
  - **Zona:** caixa em cima dele (tamanho ajustável): quantas peças estão dentro, a massa e se o jogador está dentro.
  - **Detector de impacto:** Força da batida (N), Bateu e a Peça em que bateu.
  - **Balança:** pesa o que está no prato (média até ~200 kg, grande até ~830 kg): Peso (kg) e Força (N).
  - **Receptor de laser:** acende (Atingido) quando um laser acerta nele: o do medidor laser ou o da ferramenta
    **Laser (8)**, um ponteiro (segure o clique).

**Eletrônica avançada** (Marco 4E, depósito ELETRÔNICA e loja, categoria Lógica)
- **FPGA:** um chip com um circuito dentro. Botão direito com a Fiação abre o **editor visual** (tela cheia):
  - à esquerda, a lista: pinos de **Entrada** e **Saída**, **Constante** e os 86 modos do chip lógico (com busca).
    Clique duas vezes ou arraste para o circuito;
  - ligue arrastando da bolinha de saída (direita) até a de entrada (esquerda); a cor é o tipo e só liga tipo igual;
    arraste a ponta de uma ligação para fora para desligar; **Delete** apaga o selecionado;
  - os pinos de Entrada/Saída viram as portas do FPGA (de cima para baixo), com nome e tipo editáveis;
  - as saídas mostram o valor ao vivo; tudo roda no mesmo tick. Pode ligar uma porta nela mesma (acumulador);
  - **circuitos salvos:** dê um nome, **Salvar**, e carregue em outro FPGA (ficam em `circuitos`, na pasta do jogo).
  - Até 300 peças por FPGA. O circuito e as memórias internas vão junto no save do mundo e das construções.
- **Memória (RAM):** 8 a 1024 posições. **Gravar** ligado escreve **Dado** no **Endereço**; **Lido** mostra o que tem
  lá; **Zerar** apaga tudo. Vai junto no save.
- **ROM:** uma tabela de números escrita nos ajustes; o Endereço escolhe qual sai.
- **Disco rígido (HD):** como a RAM (1024 posições), mas guarda num arquivo com o **nome do disco**: os valores ficam
  mesmo depois de sair do jogo ou trocar de mundo. Dois HDs com o mesmo disco veem os mesmos dados.
- **Rádio:** sinais sem fio entre máquinas. Manda o que chega em A, B, C, D, Vetor e Texto (com fio) e recebe dos
  outros rádios do **mesmo canal** (vale o mais perto em cada porta). Canal e alcance nos ajustes; a entrada Canal
  troca o canal por sinal. Saída Rádios = quantos estão ouvindo.
- **Console de letras:** 32 × 12 letras. **Escrever** (pulso) põe o **Texto** na **Linha** e **Coluna** (sem fio em
  Escrever, escreve todo tick); `\n` pula de linha; **Limpar** apaga; **Cor** muda a cor das letras.
- **Tela de pixels:** 32 × 32. Com **Desenhar** ligado, pinta o pixel **X, Y** com a **Cor** (0 a 255). **Preencher** e
  **Limpar**. Os pixels vão junto no save.
- **Osciloscópio:** desenha **A** (verde) e **B** (amarelo) ao longo do tempo; **Escala** e **Tempo** ajustáveis.
- **Indicador no HUD:** mostra um valor à direita da tela de quem está **sentado na máquina** (ou sempre): número,
  barra (Valor ÷ Máx) ou texto, com título e cor.
- **Câmera:** com **Ligar** ligado, quem está sentado na máquina vê pela câmera (olha para o lado da lente). Zoom em graus.
- **Marcador de peça** (uma) e **marcador de lista** (até 64): botão direito com a Fiação → **Marcar peças** e clique
  nelas (clicar de novo desmarca; botão direito termina). Saídas: Peça, Lista, Quantidade, Posição, Distância, Massa.
- **Pintor:** pinta com a **Cor** (0 a 255) a peça da entrada **Peça**, as da **Lista** ou, sem fio nelas, a que está
  na frente do bico. **Limpar** volta a cor do metal. A pintura vai junto no save e nos pedaços cortados.

**Salvar e carregar** (Esc → **Salvar / Carregar**)
- **Mundos:** salve o mundo inteiro com um nome (peças, soldas, componentes com seus ajustes e teclas,
  fios, pontos e onde você está). Carregue, apague ou comece um **mundo novo**.
  - Salvamento automático a cada 5 minutos e ao sair. Guarda os 3 últimos.
- **Construções:**
  - Para salvar uma máquina: mire nela (ou sente no assento dela) e aperte Esc.
    Vai tudo o que está ligado a ela: soldas, juntas e fios.
  - **Colocar** mostra uma prévia azul na mira: clique para colocar, roda do mouse para a distância,
    **R** gira 15° (com Shift, 90°), botão direito cancela.
  - Colocar uma construção vai custar os pontos das peças. Por enquanto está **grátis** (modo de teste).
- Os arquivos ficam na pasta do jogo em `%APPDATA%\Godot\app_userdata\Junk Construction Simulator\saves`
  (botão **Abrir pasta**). São arquivos `.json` com miniatura: dá para trocar construções com amigos.

**Reciclador e loja**
- Para se livrar de peças, jogue-as no **RECICLADOR**. Cada peça vira **pontos**, conforme o peso e o metal (alumínio vale mais por kg, ferro velho vale menos).
- No terminal da **LOJA** (tecla **E**), gaste os pontos em chapas, vigas, blocos, **cilindros** (octogonais),
  componentes e peças pré-cortadas, escolhendo as medidas (com limite) e o tamanho dos componentes.
  Os itens aparecem na plataforma **ENTREGA**.

## Estrutura do código

```
scripts/
  core/build_manager.gd   regras: soldar, cortar, juntar/separar montagens (autoload "Build")
  core/game_input.gd      mapa de teclas (autoload "GameInput")
  core/economy.gd         pontos (autoload "Economy")
  core/catalog.gd         itens e preços da loja
  core/settings.gd        opções salvas (autoload "Settings")
  core/saves.gd           salvar/carregar mundos e construções (autoload "Saves")
  signals/signals.gd      nós de sinal e fios porta a porta (autoload "Signals")
  signals/gates.gd        os 86 modos do chip lógico
  signals/*_node.gd       chip, constante, teclas, teclado de senha, mostradores, assento
  power/power.gd          fios de energia e redes elétricas (autoload "Power")
  power/power_node.gd     bateria, painel solar, posto de recarga, luz, holofote, relé, chave, medidor
  sensors/sensor_node.gd  sensores: laser, velocímetro, giroscópio, GPS, localizador, buscador, zona, impacto, receptor
  tools/laser_tool.gd     ferramenta Laser (ponteiro)
  drive/drive.gd          ligações de transmissão e simulação do trem de força (autoload "Drive")
  drive/drive_node.gd     motores, câmbios e tanques
  tools/transmission_tool.gd  ferramenta Transmissão
  tools/debug_tool.gd     Depurador
  tools/snap.gd           ponto mirado encaixado na grade de 5 cm da peça (ou numa marca)
  tools/measure_tool.gd   Trena (medir e marcar)
  tools/align_tool.gd     Alinhador (ponto → ponto, face contra face)
  ui/port_menu.gd         menu de escolher porta (Fiação)
  ui/node_config_ui.gd    ajustes de chips, telas, constantes...
  ui/save_menu.gd         tela de salvar/carregar
  tools/build_placer.gd   colocar uma construção salva (prévia fantasma)
  parts/convex_geo.gd     geometria: peças são poliedros convexos definidos por planos
  parts/part.gd           peça (forma de colisão + malha)
  parts/assembly.gd       corpo rígido de peças soldadas (congelar, ancorar)
  parts/carrier.gd        Gravitador: leva a peça até a mira e carrega a máquina inteira junto
  parts/weld.gd           ponto de solda
  player/player.gd        jogador em 1ª pessoa
  tools/*.gd              Gravitador, Solda, Esmerilhadeira, Fiação
  ui/hud.gd               interface
  world/world.gd          mapa: terreno, pátio, estruturas e pilhas de sucata
  world/recycler.gd       reciclador (peças viram pontos)
  world/demo_builds.gd    carrinho de exemplo
  world/wire_renderer.gd  desenho dos fios e dos cabos dos guinchos
  mech/mech_joint.gd      juntas: motor, servo, pistão, servo linear, dobradiças, esférica,
                          mola, guincho, propulsor, eletroímã, engate rápido
  mech/components.gd      cria componentes e controles
  mech/control_device.gd  botão, alavanca e alavanca variável
  tools/wire_tool.gd      ferramenta de fiação
  ui/seat_ui.gd           modo edição do assento
  world/shop_station.gd   terminal da loja + plataforma de entrega
  ui/shop_ui.gd           tela da loja (ícones, prévia 3D, medidas)
  ui/part_preview.gd      mini cena 3D para ícones e prévias
tests/                    testes automáticos e tour de screenshots (não vão no .exe)
```

**Rodar os testes:**

```bash
godot --headless --path . res://tests/test_build.tscn
```

```bash
godot --headless --path . res://tests/test_mech.tscn
```

```bash
godot --headless --path . res://tests/test_save.tscn
```

```bash
godot --headless --path . res://tests/test_rigid.tscn
```

```bash
godot --headless --path . res://tests/test_logic.tscn
```

```bash
godot --headless --path . res://tests/test_precision.tscn
```

```bash
godot --headless --path . res://tests/test_vehicle.tscn
```

```bash
godot --headless --path . res://tests/test_power.tscn
```

```bash
godot --headless --path . res://tests/test_sensors.tscn
```

```bash
godot --headless --path . res://tests/test_drive.tscn
```

**Publicar uma versão:** mude `config/version` no `project.godot` e crie
`release-notes/vX.Y.Z.md`. Ao enviar para o `main`, o GitHub Actions gera o `.exe` e publica o Release.

**Gerar o .exe localmente:**

```bash
godot --headless --path . --export-release "Windows Desktop" build/JunkConstructionSimulator.exe
```
