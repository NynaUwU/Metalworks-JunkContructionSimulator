# Roteiro

## ✅ Marco 1 — Base (v0.1)
- Jogador em 1ª pessoa (andar, correr com toque duplo, pular)
- Mapa: pátio com grade, morros, rampas, bancadas, galpão, muretas
- Sucata espalhada em 14 pilhas (chapas, vigas, barras, blocos), em 3 metais (aço, alumínio, ferro velho)
- Mão estilo Physics Gun: a peça flutua até apertar E ou pegar outra; giro de 15°; alinhar à grade
- Solda com pontos (bolinhas) entre peças próximas; soldar no chão ancora
- Esmerilhadeira: corte reto e a 45° (R), grade de 5 cm, prévia; remove soldas
- Peças soldadas viram um corpo rígido; cortar ou remover solda separa automaticamente

## ✅ v0.2 — Reciclador e loja
- Reciclador: peças jogadas no funil viram pontos (por peso e metal)
- Loja (F no terminal): chapas, vigas, blocos, chapa triangular e cunha; entrega numa plataforma
- Esmerilhadeira corta a face mirada; R gira a linha de corte (0°/45°/90°/135°)
- Tecla Delete removida (só o reciclador some com peças)
- Opções de gráficos (Baixo/Médio/Alto), FOV e sensibilidade; Direct3D 12 no Windows
- Release automático pelo GitHub Actions

## ✅ v0.3 — Ferramentas e loja melhores
- Solda segurando o botão (vários pontos), alcance do tamanho da bolinha, máscara de solda
- Esmerilhadeira: segurar para cortar, corte travado, tempo pelo tamanho, faíscas, remover solda com o mesmo botão
- Loja com ícones, prévia 3D e medidas ajustáveis
- Nome: Junk Construction Simulator

## ✅ v0.4 — Marco 2: Mecânica
- Motor, servo, pistão, dobradiça livre e rodas (raio e largura ajustáveis na loja)
- Assento: sentar com F; controla tudo que está ligado à mesma máquina
- Modo edição do assento (Tab): até 2 teclas/botões do mouse por sentido, alternar, inverter, velocidade, força, ângulo
- Botão, alavanca e alavanca variável ligados por fio (ferramenta Fiação)
- Depósito de componentes no galpão, componentes nas pilhas distantes e na loja
- Carrinho de exemplo perto do início

## ✅ v0.5 — Ajustes do Marco 2
- Gravitador no estilo da physics gun do GMOD (congelar, E+mouse girar, R / R R descongelar)
- Interação na tecla E
- Dobradiça com limite; os dois lados das juntas colidem
- Servo linear, dobradiça de pino, junta esférica
- Motor octogonal, servo retangular com ponta redonda, pistão quase todo recolhido
- Motor rígido/solto sem sinal; pistão volta/fica parado sem sinal
- Alavanca variável com E + mouse, faixa só positiva; ajustes pela Fiação (botão direito)

## ✅ v0.6 — Marco 3: Mais componentes
- Guincho com cabo (recolhe/solta, comprimento máximo ajustável)
- Mola (suspensão) e dobradiça de torção, com rigidez ajustável
- Dobradiça com trava (trava com sinal, ou travada sem sinal)
- Propulsor com chama
- Eletroímã (só aço e ferro) e engate rápido (E ou sinal)
- Depósito do galpão com os componentes novos; tudo na loja

---

# Próximos passos

## Decisões tomadas
- **Lógica é de graça:** sinais não gastam energia, como no Wiremod e no Scrap Mechanic.
- **Fios:** lógica e energia elétrica aparecem. Ligações mecânicas (tanque → motor → câmbio → rodas) são
  invisíveis, como no ACF, e só aparecem com a ferramenta de transmissão na mão.
- **Dois níveis de máquina:**
  - **simples** (componentes dos Marcos 2 e 3): funcionam sem energia, mas com pouca força;
  - **de verdade** (motores e câmbios estilo ACF, luzes, atuadores avançados): fortes, mas precisam de
    combustível ou bateria.
- **Motor simples do Marco 2 continua, mas limitado:** bom só para veículo pessoal, para andar por aí.
- **Programação dentro do jogo:** chip **FPGA** (editor visual de portas lógicas).
- **Parte militar do ACF** (blindagem, canhões, torres...) fica para o Marco 6.
- **O salvamento vem primeiro.**

## ✅ v0.7 — Salvamento
- Formato de save com versão: peças (forma, material, posição), montagens (ancorada, congelada, velocidade),
  soldas, isoladores, componentes com ajustes, teclas e fios, pontos e jogador
- Mundo inteiro: Esc → Salvar / Carregar, com nome, data e miniatura; mundo novo
- Salvamento automático a cada 5 min e ao sair (3 últimos)
- A sucata pega ou reciclada fica salva (o mundo salvo guarda só o que existe)
- Construções individuais: salvar a máquina mirada (soldas, juntas e fios juntos), com miniatura
- Colocar construção com prévia fantasma (distância, girar 15°/90°)
- Preço das construções pronto (preço de loja das peças); por enquanto grátis, para testes
- Botão "Abrir pasta" para trocar arquivos com amigos
- 41 testes de salvar/carregar

## ✅ v0.7.1 — Correções de física
- Gravitador carrega a máquina inteira junto (as juntas não desmontam em movimentos bruscos)
- Juntas mais rígidas (solver do Jolt com mais iterações)
- Mola não voa ao ser carregada; guincho estável com o gancho pendurado
- Pegar de perto não empurra a peça

## ✅ v0.7.2 — Mais correções de física
- Opção "Colidir com o que está do outro lado" nos ajustes de cada componente
- Pistão e servo linear com a camisa sólida (dá para soldar nela)
- Junta refeita sempre na pose certa (uma folga não vira permanente)
- Gravitador: peça presa a algo congelado é puxada sozinha; o gancho do guincho não é carregado junto

## ✅ v0.7.3 — Rodas de carros pesados
- Balanceamento de massa entre os lados das juntas (peso igual): rodas não dobram em carros pesados
- Os dois lados dos componentes voltam a colidir por padrão

## Marco 4 — Lógica, energia, sensores e trem de força
Inspirado no Wiremod e no ACF do Garry's Mod (sem nada de NPCs nem geradores de efeitos).

### ✅ v0.8 — 4A: Sinais
- Portas com tipo (número, vetor, texto, peça, lista); fontes primeiro, depois chips na ordem dos fios
- Componentes com saídas: motor (Ângulo, Giro), servo/dobradiças (Ângulo), pistão (Extensão), mola (Compressão),
  guincho (Cabo), ímã/engate (Grudado)
- Fiação porta → porta com menu de portas; isoladores; cor do fio pelo tipo
- Chip lógico com 86 modos: lógica, aritmética, comparação, memória, seleção, tempo, trigonometria, bits,
  vetor e texto
- Depurador (ferramenta 5) e nomes nas peças
- Assento como controle: W, A, S, D, Espaço, Shift, cliques, Ocupado, Mira
- Entradas: valor constante, Teclas (sentado ou sempre), teclado de senha
- Mostradores: indicador, pixel, mostrador numérico, tela de valores, tela de texto
- Depósito ELETRÔNICA; saves antigos convertidos; 91 testes de lógica

### ✅ v0.8.1 — Ferramentas de precisão
- Chapas finas não se atravessam (detecção contínua nas peças soltas)
- Trena (6): medir, distância até as bordas, marcas; a Esmerilhadeira corta pelas marcas
- Alinhador (7): ponto → ponto, face contra face, giro em esquadro (estilo Precision Alignment)
- Cilindros (aço, alumínio, tambor)
- Tamanhos pequeno/médio/grande dos componentes mecânicos e da roda
- Puxador: alça puxada com E (força fraca), para portas

### ✅ v0.8.2 — Ajustes de veículos e formato
- Cilindros e peças "redondas" octogonais (menos a roda)
- Rodas com aderência: rampa de arrancada no motor e borracha mais aderente
- Pistão com modo amortecedor (suspensão)
- Correr segurando algo com o Gravitador; prévia do Alinhador

### ✅ v0.8.3 — Juntas firmes em suspensões e solda de precisão
- Solver do Jolt com 96/24 iterações: suspensões com dobradiças em cadeia não dobram (Model-T de teste)
- Ponto de solda pequeno/normal/grande (R); solda pega a peça mais próxima; não trava componentes sem querer

### ✅ v0.9 — 4B: Energia elétrica
- Rede elétrica: o que está ligado pelo mesmo fio de energia divide a carga; relé/chave desligados cortam
- Fio de energia na Fiação (G): vermelho, mais grosso, acende quando passa energia
- Bateria P/M/G (10,8 / 50 / 205 Wh) com Carga e %
- Fontes: painel solar (grátis, conforme o sol) e posto de recarga (pago com pontos, soldado no chão)
- Relé de potência (sinal) e chave de energia (E)
- Luz e holofote (cor, brilho, alcance) que gastam energia; ficam fracos sem carga
- Medidor de energia (Carga, Capacidade, %, Consumo, Geração como sinal)
- Testes: carga e descarga, rede dividida, relé, chave, sol, posto, medidor, salvar
- **Gerador ficou para a v0.11:** ligado a um motor de verdade (com combustível) pela transmissão. Com o motor
  simples (que não gasta nada) ele seria energia infinita.
- Junto: dobradiça de pino octogonal; fios mais grossos e retos em distâncias curtas

### ✅ v0.10 — 4C: Sensores
- Medidor laser (ranger): distância, posição, normal, peça, velocidade, material; ignora a própria máquina
- Velocímetro (m/s, km/h, local, giro) e giroscópio (pitch, yaw, roll)
- GPS com ponto marcado e distância até ele
- Localizador (canais) + sensor de localizador (distância e direção)
- Buscador de alvos: raio e filtros (jogador, peças, componentes, localizadores)
- Zona (caixa ajustável), detector de impacto (força e quem bateu), balança (peso de verdade, pela força na junta)
- Receptor de laser + ferramenta Laser (8)
- Troca de ferramenta pela roda do mouse (v0.9.1)
- **Marcador de peça** ficou para a 4E (junto com o FPGA e a memória), que precisa de ferramenta de seleção

### ✅ v0.11 — 4D: Trem de força estilo ACF
- Ferramenta Transmissão (9): tanque → motor, bateria → motor elétrico, motor → câmbio, motor → gerador,
  câmbio → cubos; invisível sem a ferramenta; até 8 m; quebra se esticar 1,5×; lado esquerdo/direito automático
- Cubo de roda (eixo livre acionado pelo câmbio)
- Motores: mono, 4 em linha, V8, V12, diesel, rotativo, elétrico (bateria) e turbina; RPM com volante, curva de
  torque, marcha lenta, corte de giro, partida; sem combustível desliga; som seguindo o RPM
- Câmbios: manual, automático, CVT; diferencial duplo (esterço de tanque); embreagem automática; freio; ré
  (freia antes de engatar)
- Rodas: os cubos recebem a velocidade que o motor quer com torque limitado pela embreagem (implícito no Jolt)
- Combustível: tanques de gasolina e diesel P/M/G e bomba de combustível paga com pontos
- Gerador (vindo da 4B)
- Motor simples limitado (800 N·m, 12 rad/s); carro de exemplo novo
- Testes: aceleração, troca de marcha, freio, esterço de tanque, ré, falta de combustível, ligação quebrando,
  elétrico, gerador, bomba, salvar
- **Ficou para depois:** transfer (reduzida/alta) e diferencial avulso (4E)

### ✅ v0.11.1 — Transmissão livre e embreagens
- Qualquer peça liga em qualquer outra, em qualquer ordem; a simulação acha o caminho do motor até as rodas
  (câmbios multiplicam, embreagens limitam, tanque em qualquer ponto). Câmbio → câmbio funciona.
- Sem seta no câmbio e sem lado automático: os cubos têm **Inverter o giro** e **Lado** (esquerdo/direito)
- Embreagem automática e embreagem manual (entrada Pedal); saídas Engate e Patinação

### ✅ v0.12.0 — 4E (parte 1): Eletrônica avançada
- FPGA com editor visual (GraphEdit): pinos de entrada/saída com nome e tipo, constantes e os 86 modos do chip;
  ligações por tipo, valores ao vivo, ciclos (lê o tick anterior), até 300 peças; circuitos salvos com nome
- Memórias: RAM (8 a 1024), ROM (tabela nos ajustes) e HD (arquivo por nome de disco, fica depois de sair)
- Rádio: canais sem fio, alcance, o mais perto vale; entrada Canal
- Testes: 28 verificações novas (test_eletronica)

### ✅ v0.12.1 — 4E (parte 2): Telas, marcador e pintor
- Console de letras (32 × 12), tela de pixels (32 × 32), osciloscópio (A e B)
- Indicador no HUD (número, barra ou texto; só sentado na máquina ou sempre) e câmera (vê por ela sentado)
- Marcador de peça e de lista (Fiação → Marcar peças); peças marcadas vão no save
- Pintor (Peça, Lista ou o que está na frente do bico); pintura no save e nos pedaços cortados
- Testes: 22 verificações novas (test_telas)

### ✅ v0.12.2 — 4E (parte 3): Atuadores e trem de força
- Atuadores: propulsor vetorial, hoverball (amortece no ponto: flutua nivelada), forcer, gimbal (PID), peso ajustável,
  congelador por sinal e User (aperta E)
- Caixa de transferência (alta/reduzida) e diferencial avulso (aberto/travado; câmbio → câmbio desde a 0.11.1)
- Testes: 15 verificações novas (test_atuadores)
- **Marco 4 completo.**

## Marco 5 — Polimento
- [ ] Sons: solda, corte, impactos, componentes
- [ ] Mais efeitos
- [ ] Teclas remapeáveis e mais opções
- [ ] Limpeza de fragmentos e reposição de sucata (como no original)

## Marco 6 — ACF militar
- [ ] Blindagem: espessura × ângulo, dano por componente
- [ ] Canhões e munição
- [ ] Tripulação
- [ ] Torres: anel, motor de torre, estabilizador
- [ ] Radar/IRST e mísseis

## Futuro
- Multiplayer
