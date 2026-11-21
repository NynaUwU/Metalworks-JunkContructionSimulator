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
| Correr | toque duplo numa tecla de andar (ou Shift) |
| Agachar (mais devagar, alcança mais baixo) | Ctrl |
| Trocar ferramenta | 1 Gravitador · 2 Solda · 3 Esmerilhadeira · 4 Fiação · 5 Depurador |
| Usar (loja, assento, botão, alavanca, engate rápido) | E |
| Modo edição do assento (sentado) | Tab |
| Ajuda / menu / FPS / tela cheia | H / Esc / F3 / F11 |

**Gravitador (no estilo da physics gun do Garry's Mod)**
- Clique segurado: pega a peça, que segue a mira e gira junto com você. Tudo o que está ligado a ela
  por juntas vem junto, como um bloco só (as juntas não são arrancadas).
- Soltar o clique: a peça volta a ter física (dá para arremessar).
- **Botão direito** (segurando): **congela** a peça no lugar.
- **E + mover o mouse**: gira a peça. Com **Shift**, em passos de 15°.
- Roda do mouse: aproxima ou afasta. **T**: alinha à grade do mundo.
- **R** mirando numa peça congelada: descongela (e o que estiver ligado a ela por juntas).
  **R duas vezes**: descongela tudo.

**Solda**
- Segure o clique bem na emenda entre duas peças: cria um **ponto de solda** (bolinha).
  A solda só alcança o que está dentro da bolinha. Arraste segurando para fazer vários pontos.
- Peças soldadas viram um corpo só.
- Soldar uma peça no chão ou numa estrutura do mapa **ancora** a montagem (ela fica parada).

**Esmerilhadeira**
- **Segure** o clique: corta **a face que está na mira**. A linha de corte fica sobre essa face (prévia laranja).
  O corte trava no lugar ao clicar; soltar antes de terminar cancela.
- **R**: gira a linha de corte sobre a face: 0°, 45°, 90°, 135°.
- O corte encaixa numa grade de 5 cm; **G** liga/desliga a grade (corte livre).
- Prévia **vermelha** = perto demais da borda; mire mais para dentro da face.
- Segure o clique numa bolinha de solda para removê-la, ou num isolador para arrancá-lo.

**Máquinas**
- Componentes:
  - **motor** (gira; sem sinal fica rígido ou solto);
  - **servo** (vai até um ângulo e segura);
  - **pistão** (empurra 0,5 m; sem sinal volta ou fica parado);
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
  - **roda** e **assento**.

  Ficam no depósito do galpão, espalhados pelo mapa e à venda na loja.
- Solde a base (carcaça) na estrutura e a peça que se mexe (disco, haste, folha, placa) no que ela deve mover.
  Os dois lados de um componente **colidem** entre si (o que está soldado de um lado bate no outro). Nos ajustes
  há a opção **"Colidir com o que está do outro lado"** para desligar (ex.: roda encostada na carcaça).
  Pistão e servo linear nunca colidem entre os lados (a haste corre por dentro da camisa).
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
  escolhendo a entrada (só aparecem as do mesmo tipo). Escolher a mesma ligação de novo desliga o fio.
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
- No terminal da **LOJA** (tecla **E**), gaste os pontos em chapas, vigas, blocos, componentes e peças pré-cortadas, escolhendo as medidas (com limite). Os itens aparecem na plataforma **ENTREGA**.

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
  tools/debug_tool.gd     Depurador
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

**Publicar uma versão:** mude `config/version` no `project.godot` e crie
`release-notes/vX.Y.Z.md`. Ao enviar para o `main`, o GitHub Actions gera o `.exe` e publica o Release.

**Gerar o .exe localmente:**

```bash
godot --headless --path . --export-release "Windows Desktop" build/JunkConstructionSimulator.exe
```
