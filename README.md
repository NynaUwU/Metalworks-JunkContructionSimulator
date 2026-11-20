# Sucata — sandbox de engenharia

Jogo de construção física inspirado na ideia de *Metalworks Sandbox Demo* (Roblox, 2014):
pegue sucata espalhada pelo mapa, **corte**, **solde** e monte estruturas e máquinas.
Nome, mapa, visual e código são próprios.

- Engine: **Godot 4.7.2** (física **Jolt**)
- Plataforma: Windows (PC)

## Como jogar

- **Só jogar:** abra `Sucata.exe` (não precisa instalar nada).
- **Imagem estranha (partes pretas, quadrados)?** No menu (Esc), mude **Gráficos** para
  Médio ou Baixo. Se não resolver, use `Sucata (Vulkan).bat` ou
  `Sucata (modo compatibilidade).bat`, que vêm junto com o `.exe`.
- **Abrir o projeto:** instale o Godot 4.7.2 (versão padrão, não a .NET). Abra o
  `project.godot` e aperte **F5**.

## Controles

| Ação | Tecla |
|---|---|
| Andar / pular | W A S D / Espaço |
| Correr | toque duplo numa tecla de andar (ou Shift) |
| Trocar ferramenta | 1 Mão · 2 Solda · 3 Esmerilhadeira |
| Ajuda / menu / FPS / tela cheia | H / Esc / F3 / F11 |

**Mão (estilo Physics Gun)**
- Clique segurado: pega a peça, que **flutua** e segue a mira.
- Soltar o clique: a peça **continua flutuando** no lugar.
- **E**: devolve a gravidade à peça (pegar outra peça também devolve).
- **Shift + W/S/A/D/Q/E**: gira em passos de 15° (repete se segurar).
- **T**: alinha a peça à grade do mundo (90°).
- Roda do mouse: aproxima ou afasta. **Delete**: apaga a peça mirada.

**Solda**
- Clique na emenda entre duas peças encostadas: cria um **ponto de solda** (bolinha).
- Peças soldadas viram um corpo só.
- Soldar uma peça no chão ou numa estrutura do mapa **ancora** a montagem (ela fica parada).

**Esmerilhadeira**
- Clique: corta no plano laranja.
- **R**: muda o ângulo do corte (reto nos eixos X/Y/Z ou **45°**).
- O corte encaixa numa grade de 5 cm; segure **Ctrl** para cortar livre.
- Prévia **vermelha** = corte inválido naquele ponto (mire numa face lateral ao plano).
- Botão direito: remove a solda mais próxima da mira.

## Estrutura do código

```
scripts/
  core/build_manager.gd   regras: soldar, cortar, juntar/separar montagens (autoload "Build")
  core/game_input.gd      mapa de teclas (autoload "GameInput")
  parts/convex_geo.gd     geometria: peças são poliedros convexos definidos por planos
  parts/part.gd           peça (forma de colisão + malha)
  parts/assembly.gd       corpo rígido de peças soldadas + controle de "flutuar"
  parts/weld.gd           ponto de solda
  player/player.gd        jogador em 1ª pessoa
  tools/*.gd              Mão, Solda, Esmerilhadeira
  ui/hud.gd               interface
  world/world.gd          mapa: terreno, pátio, estruturas e pilhas de sucata
tests/                    testes automáticos e tour de screenshots (não vão no .exe)
```

**Rodar os testes:**

```bash
godot --headless --path . res://tests/test_build.tscn
```

**Gerar o .exe:**

```bash
godot --headless --path . --export-release "Windows Desktop" build/Sucata.exe
```
