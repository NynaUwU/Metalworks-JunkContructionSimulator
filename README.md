# Junk Construction Simulator

Jogo de construção física inspirado na ideia de *Metalworks Sandbox Demo* (Roblox, 2014):
pegue sucata espalhada pelo mapa, **corte**, **solde** e monte estruturas e máquinas.
Nome, mapa, visual e código são próprios.

- Engine: **Godot 4.7.2** (física **Jolt**)
- Plataforma: Windows (PC)

## Como jogar

- **Só jogar:** abra `JunkConstructionSimulator.exe` (não precisa instalar nada).
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
| Trocar ferramenta | 1 Mão · 2 Solda · 3 Esmerilhadeira · 4 Fiação |
| Usar (loja, assento, botão, alavanca) | F |
| Modo edição do assento (sentado) | Tab |
| Ajuda / menu / FPS / tela cheia | H / Esc / F3 / F11 |

**Mão (estilo Physics Gun)**
- Clique segurado: pega a peça, que **flutua** e segue a mira.
- Soltar o clique: a peça **continua flutuando** no lugar.
- **E**: devolve a gravidade à peça (pegar outra peça também devolve).
- **Shift + W/S/A/D/Q/E**: gira em passos de 15° (repete se segurar).
- **T**: alinha a peça à grade do mundo (90°).
- Roda do mouse: aproxima ou afasta.

**Solda**
- Segure o clique bem na emenda entre duas peças: cria um **ponto de solda** (bolinha).
  A solda só alcança o que está dentro da bolinha. Arraste segurando para fazer vários pontos.
- Peças soldadas viram um corpo só.
- Soldar uma peça no chão ou numa estrutura do mapa **ancora** a montagem (ela fica parada).

**Esmerilhadeira**
- **Segure** o clique: corta **a face que está na mira**. A linha de corte fica sobre essa face (prévia laranja).
  O corte trava no lugar ao clicar; soltar antes de terminar cancela.
- **R**: gira a linha de corte sobre a face: 0°, 45°, 90°, 135°.
- O corte encaixa numa grade de 5 cm; segure **Ctrl** para cortar livre.
- Prévia **vermelha** = perto demais da borda; mire mais para dentro da face.
- Segure o clique numa bolinha de solda para removê-la.

**Máquinas (motores, servos, pistões...)**
- Componentes: **motor** (gira), **servo** (vai até um ângulo e segura), **pistão** (empurra/puxa 0,5 m),
  **dobradiça** (gira livre), **roda** e **assento**. Ficam no depósito do galpão, espalhados pelo mapa e à venda na loja.
- Solde a base (carcaça) na estrutura e a peça que se mexe (disco, braço, haste) no que ela deve mover.
- **Assento:** F para sentar. Ele controla todos os componentes ligados à mesma máquina.
  **Tab** abre o **modo edição**: escolha até 2 teclas (ou botões do mouse) para cada sentido de cada componente,
  ative "alternar" (liga/desliga) ou "inverter" e ajuste velocidade, força e ângulo.
- **Controles sem teclas:** **botão** (liga enquanto aperta), **alavanca** (liga/desliga) e **alavanca variável**
  (roda do mouse, de -1 a 1). Com a ferramenta **Fiação** (4), clique no controle e depois no componente para ligar um fio.
- Perto de onde você nasce tem um **carrinho de exemplo**: sente e use W/S/A/D.

**Reciclador e loja**
- Para se livrar de peças, jogue-as no **RECICLADOR**. Cada peça vira **pontos**, conforme o peso e o metal (alumínio vale mais por kg, ferro velho vale menos).
- No terminal da **LOJA** (tecla **F**), gaste os pontos em chapas, vigas, blocos e peças pré-cortadas, escolhendo as medidas (com limite). Os itens aparecem na plataforma **ENTREGA**.

## Estrutura do código

```
scripts/
  core/build_manager.gd   regras: soldar, cortar, juntar/separar montagens (autoload "Build")
  core/game_input.gd      mapa de teclas (autoload "GameInput")
  core/economy.gd         pontos (autoload "Economy")
  core/catalog.gd         itens e preços da loja
  core/settings.gd        opções salvas (autoload "Settings")
  parts/convex_geo.gd     geometria: peças são poliedros convexos definidos por planos
  parts/part.gd           peça (forma de colisão + malha)
  parts/assembly.gd       corpo rígido de peças soldadas + controle de "flutuar"
  parts/weld.gd           ponto de solda
  player/player.gd        jogador em 1ª pessoa
  tools/*.gd              Mão, Solda, Esmerilhadeira
  ui/hud.gd               interface
  world/world.gd          mapa: terreno, pátio, estruturas e pilhas de sucata
  world/recycler.gd       reciclador (peças viram pontos)
  world/demo_builds.gd    carrinho de exemplo
  world/wire_renderer.gd  desenho dos fios
  mech/mech_joint.gd      juntas: motor, servo, pistão, dobradiça (controle e reconstrução)
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

**Publicar uma versão:** mude `config/version` no `project.godot` e crie
`release-notes/vX.Y.Z.md`. Ao enviar para o `main`, o GitHub Actions gera o `.exe` e publica o Release.

**Gerar o .exe localmente:**

```bash
godot --headless --path . --export-release "Windows Desktop" build/JunkConstructionSimulator.exe
```
