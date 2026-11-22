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

### v0.10 — 4C: Sensores
- [ ] Ranger:
  - laser que mede a distância;
  - opcional: posição, normal, velocidade, cor, material e peça atingida;
  - lista de ignorados.
- [ ] Velocímetro: total, km/h, X/Y/Z local e velocidade angular
- [ ] Giroscópio: pitch, yaw, roll
- [ ] GPS: X/Y/Z e memória de pontos
- [ ] Marcador de peça (simples e avançado, com lista)
- [ ] Localizador (beacon) + sensor de beacon (distância e direção até um localizador)
- [ ] Target Finder:
  - procura num raio, com quantidade máxima;
  - filtros: jogador, material, cor, nome, tipo de componente, localizadores.
- [ ] Zona: detecta quando algo entra num volume
- [ ] Detector de impacto: força da batida e quem bateu
- [ ] Receptor de laser + ferramenta laser (ponteiro)
- [ ] Balança: peso apoiado em cima
- [ ] Testes de cada sensor

### v0.11 — 4D: Trem de força estilo ACF
- [ ] Gerador (vindo da 4B): ligado ao motor pela transmissão, carrega as baterias
- [ ] Ferramenta Transmissão:
  - liga tanque → motor, motor → câmbio, câmbio → câmbio e câmbio → cubos de roda;
  - ligações invisíveis (aparecem só com a ferramenta na mão);
  - limite de distância; quebra se esticar 1,5×; sem loops;
  - lado esquerdo/direito automático.
- [ ] Cubo de roda: eixo livre soldado no chassi, onde a roda é soldada
- [ ] Motores:
  - tipos: monocilíndrico, 4 em linha, V8, V12, diesel, rotativo, elétrico (bateria) e turbina, com força
    ajustada às massas do jogo;
  - simulação: RPM com volante de inércia, curva de torque, marcha lenta, corte de giro, partida;
  - sem combustível, desliga;
  - portas: Acelerador e Ligado → RPM, Torque, Potência e Consumo.
- [ ] Câmbios:
  - tipos: manual (até 10 marchas + diferencial final), automático (pontos de troca), CVT, transfer
    (reduzida/alta), diferencial, diferencial duplo (tanque), embreagem avulsa;
  - limite de torque;
  - portas: Marcha, Sobe, Desce, Embreagem, Freio, Esq/Dir e Esterço.
- [ ] Física das rodas:
  - cada roda pede força pela diferença de velocidade e o motor reparte o que tem;
  - reação no chassi, freio, aderência dos pneus.
- [ ] Combustível: tanques de gasolina e diesel em tamanhos e um posto de combustível (pontos)
- [ ] Som do motor seguindo o RPM
- [ ] Motor simples do Marco 2 limitado (pouca força e velocidade: só veículo pessoal)
- [ ] Carro de exemplo novo com motor, câmbio e cubos
- [ ] Testes: aceleração, troca de marcha, esterçamento de tanque, falta de combustível, ligação quebrando

### v0.12 — 4E: Avançado
- [ ] FPGA: chip com editor visual
  - dentro dele, arrasta e liga portas lógicas;
  - entradas e saídas configuráveis;
  - circuitos salvos e carregados.
- [ ] Atuadores: propulsor vetorial, hoverball (mantém altura), forcer (empurra à distância), gimbal
  (aponta para um vetor), peso ajustável, congelador por sinal, "User" (aperta E sozinho)
- [ ] Rádio: canais sem fio entre máquinas
- [ ] Memória: guardar valores, RAM/ROM, HD (guarda mesmo depois de sair)
- [ ] Telas avançadas: console de letras, tela de pixels, osciloscópio, indicador no HUD, câmera externa
- [ ] Pintor: muda a cor de uma peça por sinal

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
