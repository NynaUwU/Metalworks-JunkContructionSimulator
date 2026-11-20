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

## Marco 3 — Mais componentes
- Guincho com cabo, mola/dobradiça de torção, propulsor/jato, eletroímã, engate rápido
- Dobradiça com trava

## Marco 4 — Elétrica
- Bateria, fios (ferramenta de fiação), botão, alavanca, relé, luzes
- Sensores e portas lógicas (E/OU/NÃO); componentes elétricos acionando motores e pistões

## Marco 5 — Salvar e polir
- Salvar/carregar o mundo e construções
- Sons (solda, corte, motores), mais efeitos
- Opções (gráficos, FOV, teclas), limpeza de fragmentos

## Futuro
- Multiplayer
