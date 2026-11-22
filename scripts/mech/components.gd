class_name Components
extends RefCounted
## Cria componentes mecânicos e controles (peças + juntas + aparência).
##
## Os componentes giram/deslizam no eixo Y local do ponto onde são criados:
##   motor/servo: carcaça embaixo, disco em cima.
##   pistão/servo linear: base embaixo, haste sai para cima.
##   dobradiça/dobradiça de pino: eixo X.
##   junta esférica: base embaixo, placa em cima, inclina para qualquer lado.

const INFO := {
	"motor": {"nome": "Motor", "preco": 40, "desc": "Motor simples (até 800 N·m e 12 rad/s: veículo pessoal). Solde a carcaça na estrutura e a roda no disco."},
	"servo": {"nome": "Servo", "preco": 35, "desc": "Gira até um ângulo e segura. Bom para direção."},
	"pistao": {"nome": "Pistão", "preco": 45, "desc": "Empurra 0,5 m em linha reta. Sem sinal: volta ao início ou fica parado."},
	"servo_linear": {"nome": "Servo linear", "preco": 40, "desc": "Vai até uma posição e segura (sinal -1 = recolhido, 0 = meio, 1 = esticado)."},
	"dobradica": {"nome": "Dobradiça", "preco": 10, "desc": "Duas folhas que giram livres até quase dobrar uma sobre a outra."},
	"pino": {"nome": "Dobradiça de pino", "preco": 8, "desc": "Dois blocos num pino: giram livres, volta inteira (eixo livre)."},
	"pino_oct": {"nome": "Dobradiça de pino octogonal", "preco": 8, "desc": "Dois tambores octogonais num pino: giram livres, volta inteira. 8 faces para soldar."},
	"esferica": {"nome": "Junta esférica", "preco": 12, "desc": "Inclina para qualquer lado e gira em volta do próprio eixo."},
	"trava": {"nome": "Dobradiça com trava", "preco": 18, "desc": "Gira livre; com sinal trava no ângulo em que está (ou o contrário, nos ajustes)."},
	"torcao": {"nome": "Dobradiça de torção", "preco": 15, "desc": "Gira, mas sempre volta sozinha à posição inicial, como uma mola."},
	"mola": {"nome": "Mola", "preco": 20, "desc": "Suspensão: comprime com o peso e volta. Rigidez ajustável."},
	"guincho": {"nome": "Guincho", "preco": 50, "desc": "Cabo entre o corpo e o gancho. Sinal + recolhe o cabo, − solta, sem sinal segura."},
	"propulsor": {"nome": "Propulsor", "preco": 60, "desc": "Empurra na direção da ponta lisa (a chama sai pelo bocal). Sinal negativo empurra ao contrário."},
	"ima": {"nome": "Eletroímã", "preco": 45, "desc": "Ligado, puxa e gruda aço e ferro na face de metal. Alumínio não é atraído."},
	"engate": {"nome": "Engate rápido", "preco": 25, "desc": "Trava no que encostar na face listrada. Liga com E ou com sinal."},
	"roda": {"nome": "Roda", "preco": 0, "desc": "Pneu de borracha. Solde no disco de um motor."},
	"assento": {"nome": "Assento", "preco": 15, "desc": "Sente (E) para controlar a máquina. Tab: modo edição."},
	"botao": {"nome": "Botão", "preco": 4, "desc": "Liga enquanto está apertado. Ligue com a Fiação."},
	"alavanca": {"nome": "Alavanca", "preco": 5, "desc": "Liga e desliga. Ligue com a Fiação."},
	"potenciometro": {"nome": "Alavanca variável", "preco": 8, "desc": "Segure E e mova o mouse para cima/baixo. Na Fiação, botão direito: só positivo ou -1 a 1."},
	"isolador": {"nome": "Isolador", "preco": 0, "desc": "Guia os fios. Criado com a ferramenta de Fiação."},
	"puxador": {"nome": "Puxador", "preco": 2, "desc": "Solde numa porta ou gaveta: segure E mirando nele para puxar (força fraca)."},
	"fpga": {"nome": "FPGA", "preco": 30, "desc": "Chip programável: monte um circuito de portas lógicas dentro dele no editor visual (botão direito com a Fiação). Circuitos podem ser salvos."},
	"memoria": {"nome": "Memória (RAM)", "preco": 10, "desc": "Guarda números em posições (8 a 1024). Gravar escreve Dado no Endereço; Lido mostra o que tem lá."},
	"rom": {"nome": "Memória só de leitura (ROM)", "preco": 8, "desc": "Uma tabela de números escrita nos ajustes. Endereço escolhe qual sai em Lido."},
	"hd": {"nome": "Disco rígido (HD)", "preco": 25, "desc": "Como a RAM (1024 posições), mas guarda num arquivo: os valores ficam mesmo depois de sair do jogo."},
	"radio": {"nome": "Rádio", "preco": 15, "desc": "Manda e recebe sinais sem fio entre máquinas no mesmo canal (A, B, C, D, Vetor e Texto)."},
	"chip": {"nome": "Chip lógico", "preco": 6, "desc": "E, OU, somar, comparar, memória, temporizador... (86 modos). Escolha o modo no botão direito da Fiação."},
	"constante": {"nome": "Valor constante", "preco": 3, "desc": "Sai sempre o mesmo número, vetor ou texto."},
	"teclas": {"nome": "Teclas", "preco": 5, "desc": "Teclas + e − viram um sinal (-1 a 1). Sentado na máquina, ou sempre (a pé)."},
	"teclado": {"nome": "Teclado de senha", "preco": 8, "desc": "E nele para digitar a senha: Certo ou Errado."},
	"indicador": {"nome": "Indicador", "preco": 3, "desc": "Lâmpada que muda de cor conforme o valor."},
	"pixel": {"nome": "Pixel", "preco": 3, "desc": "Mostra uma cor RGB (vetor de 0 a 255)."},
	"mostrador": {"nome": "Mostrador numérico", "preco": 6, "desc": "Mostra um número grande."},
	"tela": {"nome": "Tela de valores", "preco": 8, "desc": "Mostra dois valores com nome."},
	"tela_texto": {"nome": "Tela de texto", "preco": 10, "desc": "Mostra um texto; {A}, {B}, {C}, {D} e {texto} viram os valores."},
	"bateria": {"nome": "Bateria", "preco": 20, "desc": "Guarda energia (média: 50 Wh). Ligue com o fio de energia (Fiação, G). Saídas: Carga e %."},
	"solar": {"nome": "Painel solar", "preco": 25, "desc": "Gera até 25 W de graça, virado para o sol. Carrega as baterias da rede."},
	"recarga": {"nome": "Posto de recarga", "preco": 60, "desc": "Solde no chão e ligue na rede: carrega as baterias (1500 W), pago com pontos (1 a cada 10 Wh)."},
	"luz": {"nome": "Luz", "preco": 6, "desc": "Lâmpada de até 15 W. Cor, brilho e alcance nos ajustes. Entradas: Liga e Cor."},
	"holofote": {"nome": "Holofote", "preco": 12, "desc": "Luz em cone, forte (até 50 W). Ilumina para a frente."},
	"rele": {"nome": "Relé de potência", "preco": 8, "desc": "Um sinal de lógica (Liga) liga e desliga a passagem de energia."},
	"chave": {"nome": "Chave de energia", "preco": 5, "desc": "E liga e desliga a passagem de energia."},
	"medidor": {"nome": "Medidor de energia", "preco": 10, "desc": "Mostra a carga e o consumo da rede e manda como sinal."},
	"ranger": {"nome": "Medidor laser", "preco": 12, "desc": "O laser sai pela face de cima: distância, posição, normal, peça, material e velocidade do que acertar."},
	"velocimetro": {"nome": "Velocímetro", "preco": 8, "desc": "Velocidade (m/s e km/h), velocidade nos eixos dele e giro."},
	"giroscopio": {"nome": "Giroscópio", "preco": 8, "desc": "Inclinação: pitch, yaw e roll em graus (frente = -Z, como o assento)."},
	"gps": {"nome": "GPS", "preco": 8, "desc": "Posição no mundo. Entrada Marcar guarda um ponto e mede a distância até ele."},
	"localizador": {"nome": "Localizador", "preco": 6, "desc": "Um farol que o sensor de localizador encontra (canal nos ajustes)."},
	"sensor_loc": {"nome": "Sensor de localizador", "preco": 12, "desc": "Distância e direção até o localizador mais perto do mesmo canal."},
	"buscador": {"nome": "Buscador de alvos", "preco": 15, "desc": "Procura num raio: jogador, peças, componentes ou localizadores. Dá o mais perto e a lista."},
	"zona": {"nome": "Zona", "preco": 10, "desc": "Detecta o que entra na caixa em cima dele (tamanho nos ajustes): peças, massa e o jogador."},
	"impacto": {"nome": "Detector de impacto", "preco": 8, "desc": "Força da batida (N) e o que bateu."},
	"receptor": {"nome": "Receptor de laser", "preco": 5, "desc": "Acende quando um laser (medidor laser ou a ferramenta Laser) acerta nele."},
	"motor_mono": {"nome": "Motor monocilíndrico", "preco": 30, "desc": "Pequeno e econômico (5 N·m). Gasolina. Ligue tanque → motor → câmbio → cubos com a Transmissão (9)."},
	"motor_4l": {"nome": "Motor 4 em linha", "preco": 60, "desc": "Carro comum (14 N·m). Gasolina. Entradas: Acelerador e Ligado."},
	"motor_v8": {"nome": "Motor V8", "preco": 140, "desc": "Forte (40 N·m). Gasolina. Bom para carros pesados e caminhonetes."},
	"motor_v12": {"nome": "Motor V12", "preco": 220, "desc": "Muito forte e gira alto (60 N·m). Gasolina."},
	"motor_diesel": {"nome": "Motor diesel", "preco": 180, "desc": "Muita força em giro baixo (75 N·m). Diesel. Para caminhões e tratores."},
	"motor_rotativo": {"nome": "Motor rotativo", "preco": 90, "desc": "Leve e gira muito alto (16 N·m). Gasolina."},
	"motor_eletrico": {"nome": "Motor elétrico", "preco": 110, "desc": "Força cheia desde parado (30 N·m). Usa bateria: ligue bateria → motor com a Transmissão."},
	"turbina": {"nome": "Turbina", "preco": 260, "desc": "Gira altíssimo e demora a responder (35 N·m). Diesel."},
	"cambio_manual": {"nome": "Câmbio manual", "preco": 40, "desc": "Marchas pelas entradas Sobe/Desce ou Marcha (-1 = ré, 0 = neutro)."},
	"cambio_auto": {"nome": "Câmbio automático", "preco": 60, "desc": "Troca as marchas sozinho. Entradas: Freio, Ré, Esq/Dir (tanque)."},
	"embreagem_auto": {"nome": "Embreagem automática", "preco": 25, "desc": "Entre o motor e o câmbio: engata sozinha pelo giro (sai patinando na arrancada)."},
	"embreagem_manual": {"nome": "Embreagem manual", "preco": 20, "desc": "Entre o motor e o câmbio: entrada Pedal (1 = pisada, desengata; 0 = engatada)."},
	"cvt": {"nome": "Câmbio CVT", "preco": 70, "desc": "Relação contínua: deixa o motor no giro de mais força."},
	"cubo": {"nome": "Cubo de roda", "preco": 12, "desc": "Eixo livre: solde a base no chassi e a roda no disco. Ajustes: Inverter o giro e Lado."},
	"tanque_gasolina": {"nome": "Tanque de gasolina", "preco": 15, "desc": "Combustível dos motores a gasolina (médio: 40 L)."},
	"tanque_diesel": {"nome": "Tanque de diesel", "preco": 15, "desc": "Combustível do motor diesel e da turbina (médio: 40 L)."},
	"gerador": {"nome": "Gerador", "preco": 50, "desc": "Ligue motor → gerador com a Transmissão e o gerador na rede (fio de energia): até 400 W."},
	"bomba": {"nome": "Bomba de combustível", "preco": 80, "desc": "Solde no chão: E nela enche os tanques a até 5 m (1 ponto a cada 5 L)."},
	"balanca": {"nome": "Balança", "preco": 15, "desc": "Pesa o que está em cima do prato (média até ~200 kg, grande até ~830 kg). Saídas: Peso (kg) e Força (N)."},
}

## Sensores (Marco 4C): tamanho da caixa principal.
const SENSOR_SIZES := {
	"ranger": Vector3(0.12, 0.08, 0.12), "velocimetro": Vector3(0.16, 0.05, 0.12), "giroscopio": Vector3(0.14, 0.05, 0.14),
	"gps": Vector3(0.14, 0.05, 0.1), "localizador": Vector3(0.12, 0.12, 0.12), "sensor_loc": Vector3(0.14, 0.05, 0.14),
	"buscador": Vector3(0.16, 0.08, 0.16), "zona": Vector3(0.2, 0.04, 0.2), "impacto": Vector3(0.14, 0.06, 0.14),
	"receptor": Vector3(0.16, 0.04, 0.16),
}
const SENSOR_COLORS := {
	"ranger": Color(0.85, 0.15, 0.1), "velocimetro": Color(0.2, 0.7, 1.0), "giroscopio": Color(0.6, 0.4, 1.0),
	"gps": Color(0.3, 0.9, 0.4), "localizador": Color(1.0, 0.75, 0.1), "sensor_loc": Color(1.0, 0.75, 0.1),
	"buscador": Color(1.0, 0.35, 0.2), "zona": Color(0.3, 1.0, 0.5), "impacto": Color(1.0, 0.55, 0.1),
	"receptor": Color(1.0, 0.2, 0.15),
}
const SENSOR_TEXT := {
	"velocimetro": "km/h", "giroscopio": "GIRO", "gps": "GPS", "sensor_loc": "→ LOC", "buscador": "ALVO", "impacto": "IMPACTO",
}

## Peças de energia (Marco 4B): tamanho da caixa principal.
const POWER_SIZES := {
	"bateria": Vector3(0.3, 0.2, 0.22), "solar": Vector3(0.6, 0.03, 0.6), "recarga": Vector3(0.35, 1.2, 0.3),
	"luz": Vector3(0.14, 0.05, 0.14), "holofote": Vector3(0.16, 0.06, 0.16), "rele": Vector3(0.16, 0.08, 0.12),
	"chave": Vector3(0.14, 0.06, 0.2), "medidor": Vector3(0.3, 0.05, 0.2),
}
const POWER_KINDS := ["bateria", "solar", "recarga", "luz", "holofote", "rele", "chave", "medidor"]

const INSULATOR_ANCHOR := Vector3(0, 0.0275, 0)  ## onde o fio encosta no isolador (no "pescoço")
const MOTOR_APOTHEM := 0.17
const MOTOR_HALF_H := 0.15
const SERVO_SIZE := Vector3(0.26, 0.28, 0.4)
const SERVO_SHAFT_Z := -0.08                       ## o eixo do servo fica perto de uma ponta


static func wire_anchor(insulator: Part) -> Vector3:
	return insulator.global_transform * INSULATOR_ANCHOR


## Peças mecânicas que vêm em tamanhos (pequeno / médio / grande). O tamanho vai em
## size.x (0 = médio, o padrão de sempre).
const SCALED := ["motor", "servo", "pistao", "servo_linear", "dobradica", "pino", "pino_oct", "esferica", "trava", "torcao", "mola", "guincho", "bateria", "balanca",
	"cubo", "tanque_gasolina", "tanque_diesel"]

## Trem de força (Marco 4D): tamanho da caixa principal.
const DRIVE_SIZES := {
	"motor_mono": Vector3(0.25, 0.3, 0.25), "motor_4l": Vector3(0.3, 0.35, 0.5), "motor_v8": Vector3(0.5, 0.4, 0.6),
	"motor_v12": Vector3(0.55, 0.42, 0.8), "motor_diesel": Vector3(0.45, 0.5, 0.7), "motor_rotativo": Vector3(0.35, 0.3, 0.35),
	"motor_eletrico": Vector3(0.3, 0.3, 0.4), "turbina": Vector3(0.4, 0.4, 0.8),
	"cambio_manual": Vector3(0.3, 0.2, 0.36), "cambio_auto": Vector3(0.3, 0.2, 0.36), "cvt": Vector3(0.3, 0.2, 0.36),
	"embreagem_auto": Vector3(0.26, 0.26, 0.12), "embreagem_manual": Vector3(0.26, 0.26, 0.12),
	"tanque_gasolina": Vector3(0.4, 0.3, 0.5), "tanque_diesel": Vector3(0.4, 0.3, 0.5),
	"gerador": Vector3(0.3, 0.25, 0.3), "bomba": Vector3(0.4, 1.1, 0.3),
}
const DRIVE_KINDS := ["motor_mono", "motor_4l", "motor_v8", "motor_v12", "motor_diesel", "motor_rotativo", "motor_eletrico", "turbina",
	"cambio_manual", "cambio_auto", "cvt", "tanque_gasolina", "tanque_diesel", "embreagem_auto", "embreagem_manual"]
const SIZE_SMALL := 0.6
const SIZE_LARGE := 1.6


static func scale_of(kind: String, size: Vector3) -> float:
	return size.x if kind in SCALED and size.x > 0.0 else 1.0


static func size_name(kind: String, size: Vector3) -> String:
	var k := scale_of(kind, size)
	return "pequeno" if k < 0.8 else ("grande" if k > 1.2 else "médio")


static func price(kind: String, size := Vector3.ZERO) -> int:
	if kind in SCALED:
		return maxi(1, roundi(float(INFO[kind]["preco"]) * pow(scale_of(kind, size), 1.5)))
	if kind == "roda":
		var r := size.x if size.x > 0.0 else 0.35
		var w := size.y if size.y > 0.0 else 0.2
		return 6 + ceili(r * r * w * 120.0)
	return INFO[kind]["preco"]


## Caixa que envolve o componente (coordenadas do ponto de criação), para achar espaço.
static func bounds(kind: String, size := Vector3.ZERO) -> AABB:
	if kind in SCALED and scale_of(kind, size) != 1.0:
		var b := bounds(kind, Vector3.ZERO)
		var k := scale_of(kind, size)
		return AABB(b.position * k, b.size * k)
	match kind:
		"motor":
			var r := MOTOR_APOTHEM / cos(PI / 8.0)
			return AABB(Vector3(-r, -MOTOR_HALF_H, -r), Vector3(r * 2.0, 0.4, r * 2.0))
		"servo":
			return AABB(Vector3(-0.13, -0.14, -0.2), Vector3(0.26, 0.34, 0.4))
		"pistao":
			return AABB(Vector3(-0.13, -0.35, -0.13), Vector3(0.26, 0.75, 0.26))
		"servo_linear":
			return AABB(Vector3(-0.11, -0.3, -0.16), Vector3(0.22, 0.65, 0.32))
		"dobradica":
			return AABB(Vector3(-0.2, -0.03, -0.28), Vector3(0.4, 0.06, 0.56))
		"pino":
			return AABB(Vector3(-0.15, -0.06, -0.1), Vector3(0.3, 0.12, 0.2))
		"pino_oct":
			return AABB(Vector3(-0.15, -0.06, -0.06), Vector3(0.3, 0.12, 0.12))
		"esferica":
			return AABB(Vector3(-0.11, -0.04, -0.11), Vector3(0.22, 0.31, 0.22))
		"trava", "torcao":
			return AABB(Vector3(-0.2, -0.03, -0.28), Vector3(0.4, 0.06, 0.56))
		"mola":
			return AABB(Vector3(-0.14, -0.02, -0.14), Vector3(0.28, 0.34, 0.28))
		"guincho":
			return AABB(Vector3(-0.17, -0.14, -0.2), Vector3(0.67, 0.42, 0.4))
		"propulsor":
			return AABB(Vector3(-0.12, -0.3, -0.12), Vector3(0.24, 0.48, 0.24))
		"ima":
			return AABB(Vector3(-0.22, -0.07, -0.22), Vector3(0.44, 0.17, 0.44))
		"engate":
			return AABB(Vector3(-0.13, -0.04, -0.13), Vector3(0.26, 0.1, 0.26))
		"roda":
			var r := size.x if size.x > 0.0 else 0.35
			var w := size.y if size.y > 0.0 else 0.2
			return AABB(Vector3(-r, -w * 0.5, -r), Vector3(r * 2.0, w, r * 2.0))
		"assento":
			return AABB(Vector3(-0.3, -0.06, -0.3), Vector3(0.6, 0.72, 0.6))
		"botao":
			return AABB(Vector3(-0.12, -0.04, -0.12), Vector3(0.24, 0.13, 0.24))
		"alavanca":
			return AABB(Vector3(-0.1, -0.04, -0.15), Vector3(0.2, 0.38, 0.3))
		"potenciometro":
			return AABB(Vector3(-0.1, -0.04, -0.2), Vector3(0.2, 0.14, 0.4))
		"isolador":
			return AABB(Vector3(-0.035, -0.04, -0.035), Vector3(0.07, 0.09, 0.07))
		"puxador":
			return AABB(Vector3(-0.09, -0.0125, -0.03), Vector3(0.18, 0.09, 0.06))
	if SIGNAL_SIZES.has(kind):
		var s: Vector3 = SIGNAL_SIZES[kind]
		return AABB(-s * 0.5, s + Vector3(0, {"indicador": 0.06, "radio": 0.22}.get(kind, 0.0), 0))
	if SENSOR_SIZES.has(kind):
		var ss: Vector3 = SENSOR_SIZES[kind]
		return AABB(-ss * 0.5, ss + Vector3(0, 0.03 if kind == "ranger" else 0.0, 0))
	if kind == "balanca":
		return AABB(Vector3(-0.2, -0.03, -0.2), Vector3(0.4, 0.135, 0.4))
	if kind == "cubo":
		return AABB(Vector3(-0.1, -0.06, -0.1), Vector3(0.2, 0.18, 0.2))
	if DRIVE_SIZES.has(kind):
		var ds: Vector3 = DRIVE_SIZES[kind]
		return AABB(-ds * 0.5, ds + Vector3(0, 0.06 if kind.begins_with("motor") or kind == "turbina" else 0.02, 0))
	if POWER_SIZES.has(kind):
		var ps: Vector3 = POWER_SIZES[kind]
		var extra := {"luz": 0.07, "holofote": 0.16, "chave": 0.14, "bateria": 0.03}.get(kind, 0.0) as float
		return AABB(-ps * 0.5, ps + Vector3(0, extra, 0))
	return AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)


static var _next_group := 1


## Cria o componente. Retorna as peças criadas (a primeira é a "base").
## Cada peça guarda de que componente veio e a pose em que nasceu (para salvar/carregar).
static func spawn(kind: String, xform: Transform3D, size := Vector3.ZERO) -> Array[Part]:
	var parts := _spawn_kind(kind, xform, size)
	var inv := xform.affine_inverse()
	for i in parts.size():
		var p := parts[i]
		p.comp_kind = kind
		p.comp_index = i
		p.comp_group = _next_group
		p.comp_offset = inv * p.global_transform
		p.comp_size = size
	_next_group += 1
	return parts


static func _spawn_kind(kind: String, xform: Transform3D, size: Vector3) -> Array[Part]:
	match kind:
		"motor":
			return _spawn_motor(xform, scale_of(kind, size))
		"servo":
			return _spawn_servo(xform, scale_of(kind, size))
		"pistao", "servo_linear":
			return _spawn_linear(kind, xform, scale_of(kind, size))
		"dobradica", "trava", "torcao":
			return _spawn_hinge(xform, kind, scale_of(kind, size))
		"mola":
			return _spawn_spring(xform, scale_of(kind, size))
		"guincho":
			return _spawn_winch(xform, scale_of(kind, size))
		"propulsor", "ima", "engate":
			return [_spawn_single(kind, xform)]
		"pino":
			return _spawn_pin(xform, scale_of(kind, size))
		"pino_oct":
			return _spawn_pin_oct(xform, scale_of(kind, size))
		"esferica":
			return _spawn_ball(xform, scale_of(kind, size))
		"roda":
			return [_spawn_wheel(xform, size)]
		"assento":
			return _spawn_seat(xform)
		"botao", "alavanca", "potenciometro":
			return [_spawn_device(kind, xform)]
		"isolador":
			return [_spawn_insulator(xform)]
		"puxador":
			return [_spawn_handle(xform)]
		"chip", "constante", "teclas", "teclado", "indicador", "pixel", "mostrador", "tela", "tela_texto", "fpga", "memoria", "rom", "hd", "radio":
			return [_spawn_signal(kind, xform)]
		"bateria", "solar", "recarga", "luz", "holofote", "rele", "chave", "medidor":
			return [_spawn_power(kind, xform, scale_of(kind, size))]
		"ranger", "velocimetro", "giroscopio", "gps", "localizador", "sensor_loc", "buscador", "zona", "impacto", "receptor":
			return [_spawn_sensor(kind, xform)]
		"balanca":
			return _spawn_scale(xform, scale_of(kind, size))
		"cubo":
			return _spawn_hub(xform, scale_of(kind, size))
		"gerador":
			return [_spawn_generator(xform)]
		"bomba":
			return [_spawn_pump(xform)]
	if kind in DRIVE_KINDS:
		return [_spawn_drive(kind, xform, scale_of(kind, size))]
	return []


# --- Formas ----------------------------------------------------------------------

## Prisma octogonal (eixo Y) — carcaça do motor.
static func octagon_planes(apothem: float, half_h: float) -> Array[Plane]:
	var out: Array[Plane] = [Plane(Vector3.UP, half_h), Plane(Vector3.DOWN, half_h)]
	for k in 8:
		var a := k * PI / 4.0
		out.append(Plane(Vector3(cos(a), 0, sin(a)), apothem))
	return out


# --- Peças básicas -------------------------------------------------------------

static func _box(size: Vector3, mat: String, xform: Transform3D, label: String, kind: String) -> Part:
	var p := Build.spawn_box(size, mat, xform)
	_component(p, label, kind)
	return p


static func _component(p: Part, label: String, kind: String) -> void:
	p.cuttable = false
	p.label = label
	p.kind = kind


static func _cyl(radius: float, height: float, mat: String, xform: Transform3D, label: String, kind: String) -> Part:
	var p := Part.new()
	p.setup_cylinder(radius, height, mat)
	p.label = label
	p.kind = kind
	Build.spawn_part(p, xform)
	return p


## Peça octogonal (o "cilindro" do jogo): eixo = Y local, faces nos eixos X/Z.
static func _oct(apothem: float, height: float, mat: String, xform: Transform3D, label: String, kind: String) -> Part:
	var p := Build.spawn_planes(octagon_planes(apothem, height * 0.5), mat, xform)
	_component(p, label, kind)
	return p


## Planos de um prisma octogonal deslocado para `center`.
static func _oct_planes_at(apothem: float, height: float, center: Vector3) -> Array[Plane]:
	var out: Array[Plane] = []
	for pl in octagon_planes(apothem, height * 0.5):
		out.append(Plane(pl.normal, pl.d + pl.normal.dot(center)))
	return out


static func _deco_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, emission := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = GameTool.glow_material(color, emission) if emission > 0.0 else StationBuilder.mat(color, 0.6, 0.3)
	parent.add_child(mi)
	return mi


## Detalhe "cilíndrico": octogonal (8 lados, faces nos eixos), menos a roda (`sides` alto).
## `radius` = distância do centro até uma face.
static func _deco_cyl(parent: Node3D, radius: float, height: float, xform: Transform3D, color: Color, metal := 0.5, sides := 8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	var r := radius / cos(PI / sides) if sides == 8 else radius
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = height
	cm.radial_segments = sides
	cm.rings = 1
	mi.mesh = cm
	mi.transform = xform * Transform3D(Basis(Vector3.UP, PI / 8.0), Vector3.ZERO) if sides == 8 else xform
	mi.material_override = StationBuilder.mat(color, 0.45, metal)
	parent.add_child(mi)
	return mi


static func _deco_sphere(parent: Node3D, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mi.mesh = sm
	mi.position = pos
	mi.material_override = StationBuilder.mat(color, 0.35, 0.85)
	parent.add_child(mi)
	return mi


static func _light(parent: Node3D, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.022
	sm.height = 0.044
	mi.mesh = sm
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _joint(type: String, a: Part, b: Part, pivot: Vector3, axis: Vector3) -> MechJoint:
	var j := MechJoint.new()
	j.type = type
	j.part_a = a
	j.part_b = b
	j.pivot = pivot
	j.axis = axis
	return j


# --- Componentes ---------------------------------------------------------------

static func _spawn_motor(xform: Transform3D, k := 1.0) -> Array[Part]:
	var stator := Build.spawn_planes(octagon_planes(MOTOR_APOTHEM * k, MOTOR_HALF_H * k), "carcaca", xform)
	_component(stator, "Motor (carcaça)", "motor")
	var rotor := _oct(0.15 * k, 0.06 * k, "aco", xform * Transform3D(Basis(), Vector3(0, (MOTOR_HALF_H + 0.034) * k, 0)), "Motor (disco)", "motor")
	_deco_box(rotor, Vector3(0.2, 0.012, 0.03) * k, Vector3(0, 0.032, 0) * k, Color(0.9, 0.2, 0.15))
	var j := _joint("motor", stator, rotor, Vector3(0, MOTOR_HALF_H * k, 0), Vector3.UP)
	j.size_scale = k
	j.speed = 10.0
	j.strength = 600.0 * k * k * k        # motor simples: limitado (até 800 × tamanho³)
	j.bind_pos = [{"key": KEY_W}]
	j.bind_neg = [{"key": KEY_S}]
	j.capture_rest()
	Build.add_joint(j)
	return [stator, rotor]


static func _spawn_servo(xform: Transform3D, k := 1.0) -> Array[Part]:
	var top := SERVO_SIZE.y * 0.5 * k
	var shaft_z := SERVO_SHAFT_Z * k
	var stator := _box(SERVO_SIZE * k, "carcaca_azul", xform, "Servo (carcaça)", "servo")
	var disc := _oct(0.12 * k, 0.05 * k, "aco", xform * Transform3D(Basis(), Vector3(0, top + 0.029 * k, shaft_z)), "Servo (disco)", "servo")
	_deco_box(disc, Vector3(0.16, 0.012, 0.03) * k, Vector3(0, 0.027, 0) * k, Color(0.95, 0.95, 0.95))
	_deco_cyl(stator, 0.035 * k, 0.012 * k, Transform3D(Basis(), Vector3(0, top + 0.002 * k, shaft_z)), Color(0.2, 0.2, 0.22), 0.6)
	var j := _joint("servo", stator, disc, Vector3(0, top, shaft_z), Vector3.UP)
	j.size_scale = k
	j.speed = 4.0
	j.strength = 2500.0 * k * k * k
	j.bind_pos = [{"key": KEY_A}]
	j.bind_neg = [{"key": KEY_D}]
	j.capture_rest()
	Build.add_joint(j)
	return [stator, disc]


## Pistão e servo linear: a base e a camisa são uma peça só (dá para soldar em qualquer
## lugar dela); a haste corre por dentro (os dois lados nunca colidem entre si).
static func _spawn_linear(kind: String, xform: Transform3D, k := 1.0) -> Array[Part]:
	var linear := kind == "servo_linear"
	var base_size := (Vector3(0.22, 0.1, 0.32) if linear else Vector3(0.26, 0.1, 0.26)) * k
	var base_y := (-0.25 if linear else -0.3) * k
	var sleeve := (Vector3(0.2, 0.45, 0.3) if linear else Vector3(0.24, 0.55, 0.24)) * k
	var rod_size := (Vector3(0.1, 0.5, 0.1) if linear else Vector3(0.14, 0.6, 0.14)) * k
	var rod_y := 0.055 * k
	var color := Color(0.15, 0.35, 0.7) if linear else Color(0.85, 0.6, 0.12)
	var name := "Servo linear" if linear else "Pistão"
	# A peça "base" continua com a origem no centro da base (saves antigos encaixam),
	# mas a forma vai do fundo da base até o topo da camisa.
	var body_h := base_size.y + sleeve.y
	var body_center := Vector3(0, body_h * 0.5 - base_size.y * 0.5, 0)
	var planes: Array[Plane] = []
	if linear:
		for pl in ConvexGeo.box_planes(Vector3(base_size.x, body_h, base_size.z)):
			planes.append(Plane(pl.normal, pl.d + pl.normal.dot(body_center)))
	else:
		planes = _oct_planes_at(base_size.x * 0.5, body_h, body_center)   # pistão: corpo octogonal
	var base := Build.spawn_planes(planes, "carcaca_azul" if linear else "carcaca", xform * Transform3D(Basis(), Vector3(0, base_y, 0)))
	_component(base, name, kind)
	var ring_y := base_size.y * 0.5 + sleeve.y - 0.015 * k
	if linear:
		_deco_box(base, Vector3(base_size.x + 0.02 * k, 0.03 * k, base_size.z + 0.02 * k), Vector3(0, ring_y, 0), color.darkened(0.35))
	else:
		_deco_cyl(base, base_size.x * 0.5 + 0.01 * k, 0.03 * k, Transform3D(Basis(), Vector3(0, ring_y, 0)), color.darkened(0.35), 0.5)
	var rod := _oct(rod_size.x * 0.5, rod_size.y, "aco", xform * Transform3D(Basis(), Vector3(0, rod_y, 0)), name + " (haste)", kind)
	_deco_cyl(rod, rod_size.x * 0.5 + 0.03 * k, 0.04 * k, Transform3D(Basis(), Vector3(0, rod_size.y * 0.5, 0)), Color(0.3, 0.32, 0.35), 0.6)
	var j := _joint(kind, base, rod, Vector3(0, -base_y, 0), Vector3.UP)
	j.size_scale = k
	j.stroke = (0.4 if linear else 0.5) * k
	j.speed = (0.8 if linear else 1.0) * k
	j.strength = (8000.0 if linear else 12000.0) * k * k * k
	j.stiffness = 10000.0 * k * k
	j.damping = 1000.0 * k * k
	j.capture_rest()
	Build.add_joint(j)
	return [base, rod]


const HINGE_KNUCKLE := {"dobradica": Color(0.4, 0.42, 0.45), "trava": Color(0.85, 0.15, 0.1), "torcao": Color(0.2, 0.45, 0.9)}


## Dobradiça (e variações com trava / torção): folhas afastadas 3 cm do eixo.
static func _spawn_hinge(xform: Transform3D, type := "dobradica", k := 1.0) -> Array[Part]:
	var label: String = MechJoint.NAMES[type]
	var leaf := Vector3(0.4, 0.04, 0.25) * k
	var off := 0.155 * k
	var leaf_a := _box(leaf, "aco", xform * Transform3D(Basis(), Vector3(0, 0, -off)), label, type)
	var leaf_b := _box(leaf, "aco", xform * Transform3D(Basis(), Vector3(0, 0, off)), label, type)
	_deco_cyl(leaf_a, 0.025 * k, 0.42 * k, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0, off)), HINGE_KNUCKLE[type], 0.8)
	var j := _joint(type, leaf_a, leaf_b, Vector3(0, 0, off), Vector3.RIGHT)
	j.size_scale = k
	match type:
		"trava":
			j.strength = 3000.0 * k * k * k
			j.indicator = _light(leaf_a, Vector3(0.16, 0.03, 0.0) * k)
		"torcao":
			j.strength = 60.0 * k * k * k * k   # rigidez (N·m por radiano)
			j.speed = 6.0
			_deco_box(leaf_a, Vector3(0.1, 0.02, 0.06) * k, Vector3(0, 0.03, 0.09) * k, Color(0.2, 0.45, 0.9))
	j.capture_rest()
	Build.add_joint(j)
	return [leaf_a, leaf_b]


## Mola (suspensão): duas placas e a espiral entre elas; curso de -0,2 / +0,12 m.
static func _spawn_spring(xform: Transform3D, k := 1.0) -> Array[Part]:
	var a := _box(Vector3(0.28, 0.04, 0.28) * k, "aco", xform, "Mola", "mola")
	var b := _box(Vector3(0.28, 0.04, 0.28) * k, "aco", xform * Transform3D(Basis(), Vector3(0, 0.3 * k, 0)), "Mola", "mola")
	var coil := Node3D.new()
	coil.position = Vector3(0, 0.02 * k, 0)
	a.add_child(coil)
	for i in 6:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.07 * k
		tm.outer_radius = 0.09 * k
		tm.rings = 8               # espiral octogonal, como o resto do jogo
		tm.ring_segments = 6
		ring.mesh = tm
		ring.material_override = StationBuilder.mat(Color(0.9, 0.75, 0.15), 0.4, 0.8)
		ring.position = Vector3(0, (0.022 + i * 0.043) * k, 0)
		ring.rotation.x = deg_to_rad(8.0 if i % 2 == 0 else -8.0)
		coil.add_child(ring)
	var j := _joint("mola", a, b, Vector3.ZERO, Vector3.UP)
	j.size_scale = k
	j.strength = 5000.0 * k * k     # rigidez (N/m)
	j.coil = coil
	j.coil_gap = 0.26 * k
	j.capture_rest()
	Build.add_joint(j)
	return [a, b]


## Guincho: corpo com tambor; o cabo sai por baixo e vai até o gancho.
static func _spawn_winch(xform: Transform3D, k := 1.0) -> Array[Part]:
	var body := _box(Vector3(0.34, 0.28, 0.4) * k, "carcaca", xform, "Guincho", "guincho")
	_deco_cyl(body, 0.1 * k, 0.3 * k, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0.16, 0) * k), Color(0.3, 0.32, 0.35), 0.8)
	_deco_cyl(body, 0.03 * k, 0.02 * k, Transform3D(Basis(), Vector3(0, -0.145, 0) * k), Color(0.15, 0.15, 0.16), 0.5)
	var hook := _box(Vector3(0.12, 0.1, 0.12) * k, "aco", xform * Transform3D(Basis(), Vector3(0.4, -0.09, 0) * k), "Guincho (gancho)", "guincho")
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.025 * k
	tm.outer_radius = 0.045 * k
	ring.mesh = tm
	ring.material_override = StationBuilder.mat(Color(0.75, 0.77, 0.8), 0.35, 0.9)
	ring.rotation.x = PI * 0.5
	ring.position = Vector3(0, 0.08, 0) * k
	hook.add_child(ring)
	var j := _joint("guincho", body, hook, Vector3(0, -0.14, 0) * k, Vector3.DOWN)
	j.size_scale = k
	j.hook_anchor = Vector3(0, 0.1, 0) * k
	j.rope_len = j.rope_start().distance_to(j.rope_end()) + 0.05 * k
	j.speed = 1.0
	j.strength = 5000.0 * k * k * k
	j.max_rope = 20.0
	j.bind_pos = []
	j.bind_neg = []
	j.capture_rest()
	Build.add_joint(j)
	return [body, hook]


## Componentes de uma peça só: propulsor, eletroímã e engate rápido.
static func _spawn_single(kind: String, xform: Transform3D) -> Part:
	var p: Part
	var j := MechJoint.new()
	j.type = kind
	match kind:
		"propulsor":
			p = _oct(0.12, 0.36, "aco", xform, "Propulsor", kind)
			_deco_cyl(p, 0.125, 0.04, Transform3D(Basis(), Vector3(0, 0.1, 0)), Color(0.95, 0.5, 0.1), 0.3)
			var nozzle := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.07 / cos(PI / 8.0)
			cm.bottom_radius = 0.11 / cos(PI / 8.0)
			cm.height = 0.12
			cm.radial_segments = 8
			cm.rings = 1
			nozzle.mesh = cm
			nozzle.material_override = StationBuilder.mat(Color(0.2, 0.2, 0.22), 0.4, 0.8)
			nozzle.position = Vector3(0, -0.24, 0)
			nozzle.rotation.y = PI / 8.0
			p.add_child(nozzle)
			j.fx = _flame(p, Vector3(0, -0.31, 0))
			j.axis = Vector3.UP          # empurra para a ponta lisa
			j.pivot = Vector3.ZERO
			j.strength = 300.0
		"ima":
			p = _oct(0.22, 0.1, "plastico", xform, "Eletroímã", kind)
			var face := MeshInstance3D.new()
			var fm := CylinderMesh.new()
			fm.top_radius = 0.2 / cos(PI / 8.0)
			fm.bottom_radius = 0.2 / cos(PI / 8.0)
			fm.height = 0.012
			fm.radial_segments = 8
			fm.rings = 1
			face.mesh = fm
			face.rotation.y = PI / 8.0
			face.position = Vector3(0, -0.056, 0)
			p.add_child(face)
			j.indicator = face             # a face acende quando liga
			_deco_cyl(p, 0.04, 0.06, Transform3D(Basis(), Vector3(0, 0.08, 0)), Color(0.6, 0.62, 0.66), 0.9)
			j.axis = Vector3.DOWN          # a face de metal fica embaixo
			j.pivot = Vector3(0, -0.05, 0)
			j.strength = 800.0
		"engate":
			p = _box(Vector3(0.26, 0.08, 0.26), "plastico", xform, "Engate rápido", kind)
			for i in 3:
				_deco_box(p, Vector3(0.26, 0.004, 0.04), Vector3(0, 0.041, -0.08 + i * 0.08), Color(0.95, 0.75, 0.1))
			j.indicator = _light(p, Vector3(0.1, 0.045, 0.1))
			j.axis = Vector3.UP            # face listrada em cima
			j.pivot = Vector3(0, 0.04, 0)
			p.interact_kind = "engate"
	p.cuttable = false
	j.part_a = p
	j.part_b = p
	j.capture_rest()
	Build.add_joint(j)
	j.update(0.0)   # acerta a luz/efeito inicial
	return p


static var _flame_mat: StandardMaterial3D


## Chama do propulsor (sai para -Y): bolhas de luz que nascem branco-amareladas
## no bocal e viram laranja/vermelho até sumir.
static func _flame(parent: Node3D, pos: Vector3) -> CPUParticles3D:
	if _flame_mat == null:
		var soft := Gradient.new()
		soft.set_color(0, Color(1, 1, 1, 1))
		soft.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = soft
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		_flame_mat = StandardMaterial3D.new()
		_flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flame_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flame_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_flame_mat.albedo_texture = tex
		_flame_mat.vertex_color_use_as_albedo = true
		_flame_mat.disable_fog = true
	var f := CPUParticles3D.new()
	f.emitting = false
	f.amount = 90
	f.lifetime = 0.22
	f.direction = Vector3.DOWN
	f.spread = 6.0
	f.initial_velocity_min = 4.5
	f.initial_velocity_max = 6.5
	f.gravity = Vector3.ZERO
	f.scale_amount_min = 1.4
	f.scale_amount_max = 2.2
	var shape := Curve.new()
	shape.add_point(Vector2(0, 0.7))
	shape.add_point(Vector2(0.3, 1.0))
	shape.add_point(Vector2(1, 0.3))
	f.scale_amount_curve = shape
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.75, 1.0))
	ramp.set_color(1, Color(0.6, 0.08, 0.02, 0.0))
	ramp.add_point(0.35, Color(1.0, 0.55, 0.12, 0.9))
	f.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(0.13, 0.13)
	f.mesh = quad
	f.material_override = _flame_mat
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	f.position = pos
	f.local_coords = false
	parent.add_child(f)
	return f


static func _spawn_pin(xform: Transform3D, k := 1.0) -> Array[Part]:
	var a := _box(Vector3(0.12, 0.12, 0.2) * k, "aco", xform * Transform3D(Basis(), Vector3(-0.065 * k, 0, 0)), "Dobradiça de pino", "pino")
	var b := _box(Vector3(0.12, 0.12, 0.2) * k, "ferro", xform * Transform3D(Basis(), Vector3(0.065 * k, 0, 0)), "Dobradiça de pino", "pino")
	_deco_cyl(a, 0.025 * k, 0.3 * k, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.065 * k, 0, 0)), Color(0.75, 0.77, 0.8), 0.9)
	var j := _joint("pino", a, b, Vector3(0.065 * k, 0, 0), Vector3.RIGHT)
	j.size_scale = k
	j.capture_rest()
	Build.add_joint(j)
	return [a, b]


## Dobradiça de pino octogonal: dois tambores octogonais no mesmo eixo (X), como a de
## pino, mas com 8 faces para soldar. Usa a mesma junta ("pino").
static func _spawn_pin_oct(xform: Transform3D, k := 1.0) -> Array[Part]:
	var parts: Array[Part] = []
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var p := Build.spawn_planes(_oct_planes_x(0.06 * k, 0.12 * k), "aco" if i == 0 else "ferro",
			xform * Transform3D(Basis(), Vector3(side * 0.065 * k, 0, 0)))
		_component(p, "Dobradiça de pino octogonal", "pino_oct")
		parts.append(p)
	_deco_cyl(parts[0], 0.025 * k, 0.3 * k, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.065 * k, 0, 0)), Color(0.75, 0.77, 0.8), 0.9)
	var j := _joint("pino", parts[0], parts[1], Vector3(0.065 * k, 0, 0), Vector3.RIGHT)
	j.size_scale = k
	j.capture_rest()
	Build.add_joint(j)
	return parts


## Prisma octogonal com o eixo em X (faces nos eixos Y/Z), centrado na origem.
static func _oct_planes_x(apothem: float, length: float) -> Array[Plane]:
	var out: Array[Plane] = [Plane(Vector3.RIGHT, length * 0.5), Plane(Vector3.LEFT, length * 0.5)]
	for k in 8:
		var a := k * PI / 4.0
		out.append(Plane(Vector3(0, cos(a), sin(a)), apothem))
	return out


static func _spawn_ball(xform: Transform3D, k := 1.0) -> Array[Part]:
	var base := _box(Vector3(0.22, 0.08, 0.22) * k, "carcaca", xform, "Junta esférica (base)", "esferica")
	var plate := _box(Vector3(0.22, 0.06, 0.22) * k, "aco", xform * Transform3D(Basis(), Vector3(0, 0.24 * k, 0)), "Junta esférica (placa)", "esferica")
	_deco_cyl(base, 0.065 * k, 0.04 * k, Transform3D(Basis(), Vector3(0, 0.06 * k, 0)), Color(0.3, 0.3, 0.32), 0.7)
	_deco_sphere(base, 0.05 * k, Vector3(0, 0.12 * k, 0), Color(0.75, 0.77, 0.8))
	_deco_cyl(plate, 0.02 * k, 0.09 * k, Transform3D(Basis(), Vector3(0, -0.075 * k, 0)), Color(0.75, 0.77, 0.8), 0.9)
	var j := _joint("esferica", base, plate, Vector3(0, 0.12 * k, 0), Vector3.UP)
	j.size_scale = k
	j.max_angle = deg_to_rad(50.0)
	j.capture_rest()
	Build.add_joint(j)
	return [base, plate]


static func _spawn_wheel(xform: Transform3D, size: Vector3) -> Part:
	var r := clampf(size.x if size.x > 0.0 else 0.35, 0.15, 1.2)
	var w := clampf(size.y if size.y > 0.0 else 0.2, 0.08, 0.6)
	var wheel := _cyl(r, w, "borracha", xform, "Roda", "roda")
	_deco_cyl(wheel, r * 0.6, w + 0.008, Transform3D.IDENTITY, Color(0.62, 0.64, 0.68), 0.85, 28)
	_deco_cyl(wheel, r * 0.18, w + 0.016, Transform3D.IDENTITY, Color(0.25, 0.26, 0.28), 0.6, 20)
	wheel.assembly().recompute()
	return wheel


static func _spawn_seat(xform: Transform3D) -> Array[Part]:
	var base := _box(Vector3(0.6, 0.12, 0.6), "plastico", xform, "Assento", "assento")
	base.interact_kind = "assento"
	var back := _box(Vector3(0.6, 0.6, 0.1), "plastico", xform * Transform3D(Basis(), Vector3(0, 0.36, 0.25)), "Assento (encosto)", "assento")
	back.interact_kind = "assento"
	back.set_meta("seat_base", base)   # mirar no encosto também senta
	_deco_box(base, Vector3(0.5, 0.03, 0.5), Vector3(0, 0.07, -0.02), Color(0.45, 0.12, 0.1))
	_deco_box(base, Vector3(0.12, 0.02, 0.04), Vector3(0, 0.0, -0.31), Color(1.0, 0.75, 0.2), 1.5)
	Build.make_weld(base, back, xform * Vector3(0, 0.06, 0.25), false).internal = true
	var sn := SeatNode.new()
	sn.part = base
	Build.add_node(sn)
	return [base, back]


static func _spawn_device(kind: String, xform: Transform3D) -> Part:
	var dev := ControlDevice.new()
	dev.kind = kind
	var part: Part
	match kind:
		"botao":
			part = _box(Vector3(0.24, 0.08, 0.24), "plastico", xform, "Botão", "botao")
			var cap := Node3D.new()
			part.add_child(cap)
			_deco_cyl(cap, 0.07, 0.04, Transform3D.IDENTITY, Color(0.85, 0.12, 0.1), 0.1)
			dev.setup_visuals(cap, _light(part, Vector3(0.085, 0.045, 0.085)))
		"alavanca":
			part = _box(Vector3(0.2, 0.08, 0.3), "plastico", xform, "Alavanca", "alavanca")
			var arm := Node3D.new()
			arm.position = Vector3(0, 0.04, 0)
			part.add_child(arm)
			_deco_box(arm, Vector3(0.035, 0.28, 0.035), Vector3(0, 0.14, 0), Color(0.6, 0.62, 0.66))
			_deco_box(arm, Vector3(0.07, 0.07, 0.07), Vector3(0, 0.29, 0), Color(0.85, 0.12, 0.1))
			dev.setup_visuals(arm, _light(part, Vector3(0.07, 0.045, 0.12)))
		_:
			part = _box(Vector3(0.2, 0.08, 0.4), "plastico", xform, "Alavanca variável", "potenciometro")
			_deco_box(part, Vector3(0.04, 0.01, 0.32), Vector3(0, 0.041, 0), Color(0.05, 0.05, 0.05))
			var knob := Node3D.new()
			knob.position = Vector3(0, 0.07, 0)
			part.add_child(knob)
			_deco_box(knob, Vector3(0.1, 0.06, 0.05), Vector3.ZERO, Color(0.95, 0.65, 0.1))
			dev.setup_visuals(knob, _light(part, Vector3(0.07, 0.045, 0.17)))
	part.interact_kind = kind
	dev.part = part
	Build.add_device(dev)
	return part


## Puxador: base fina + alça em "U". E segurado puxa (ver Player._update_pull).
static func _spawn_handle(xform: Transform3D) -> Part:
	var p := _box(Vector3(0.18, 0.025, 0.05), "aco", xform, "Puxador", "puxador")
	_handle_visual(p)
	p.interact_kind = "puxador"
	return p


static func _handle_visual(parent: Node3D) -> void:
	var c := Color(0.75, 0.77, 0.8)
	for x: float in [-0.065, 0.065]:
		_deco_box(parent, Vector3(0.018, 0.06, 0.018), Vector3(x, 0.04, 0), c)
	_deco_box(parent, Vector3(0.16, 0.02, 0.022), Vector3(0, 0.07, 0), Color(0.15, 0.15, 0.16))


## Isolador (como os de cerca elétrica): base, "pescoço" onde o fio passa e a tampa.
static func _spawn_insulator(xform: Transform3D) -> Part:
	var p := _oct(0.035, 0.08, "plastico", xform, "Isolador", "isolador")
	p.mesh_instance.visible = false   # a aparência vem das peças abaixo
	_insulator_visual(p)
	p.assembly().recompute()
	return p


static func _insulator_visual(parent: Node3D) -> void:
	var black := Color(0.06, 0.06, 0.065)
	# (metade do tamanho antigo: o isolador era grande demais)
	_deco_cyl(parent, 0.035, 0.04, Transform3D(Basis(), Vector3(0, -0.02, 0)), black, 0.0)
	_deco_cyl(parent, 0.02, 0.03, Transform3D(Basis(), Vector3(0, 0.015, 0)), black, 0.0)
	_deco_cyl(parent, 0.036, 0.01, Transform3D(Basis(), Vector3(0, 0.035, 0)), black, 0.0)
	_deco_cyl(parent, 0.006, 0.002, Transform3D(Basis(), Vector3(0, 0.0405, 0)), Color(0.7, 0.72, 0.75), 0.9)
	_deco_cyl(parent, 0.003, 0.04, Transform3D(Basis(), Vector3(0, -0.06, 0)), Color(0.6, 0.62, 0.66), 0.9)


# --- Lógica e mostradores ----------------------------------------------------------

const SIGNAL_SIZES := {
	"chip": Vector3(0.24, 0.05, 0.18), "constante": Vector3(0.18, 0.06, 0.18),
	"teclas": Vector3(0.22, 0.05, 0.16), "teclado": Vector3(0.18, 0.04, 0.24),
	"indicador": Vector3(0.12, 0.05, 0.12), "pixel": Vector3(0.2, 0.04, 0.2),
	"mostrador": Vector3(0.4, 0.05, 0.16), "tela": Vector3(0.5, 0.04, 0.32),
	"tela_texto": Vector3(0.7, 0.04, 0.45),
	"fpga": Vector3(0.3, 0.05, 0.3), "memoria": Vector3(0.22, 0.04, 0.14), "rom": Vector3(0.22, 0.04, 0.14),
	"hd": Vector3(0.2, 0.06, 0.26), "radio": Vector3(0.14, 0.06, 0.14),
}
const SIGNAL_LABELS := {
	"chip": "Chip lógico", "constante": "Valor constante", "teclas": "Teclas", "teclado": "Teclado de senha",
	"indicador": "Indicador", "pixel": "Pixel", "mostrador": "Mostrador numérico", "tela": "Tela de valores",
	"tela_texto": "Tela de texto", "fpga": "FPGA", "memoria": "Memória (RAM)", "rom": "Memória (ROM)",
	"hd": "Disco rígido (HD)", "radio": "Rádio",
}
const BOARD_DARK := Color(0.07, 0.08, 0.09)
const SCREEN_DARK := Color(0.02, 0.04, 0.06)


static func _spawn_signal(kind: String, xform: Transform3D) -> Part:
	var size: Vector3 = SIGNAL_SIZES[kind]
	var top := size.y * 0.5
	var p := _box(size, "plastico", xform, SIGNAL_LABELS[kind], kind)
	var node: SignalNode
	match kind:
		"chip":
			var c := ChipNode.new()
			c.part = p
			for i in 4:
				for side: float in [-1.0, 1.0]:
					_deco_box(p, Vector3(0.025, 0.012, 0.02), Vector3(-0.09 + i * 0.06, -0.012, side * (size.z * 0.5 + 0.008)), Color(0.85, 0.7, 0.25))
			c.label = _label3d(p, Gates.DEFS[c.mode]["sym"], top, 64, Color(0.95, 0.95, 0.95))
			node = c
		"constante":
			var k := ConstNode.new()
			k.part = p
			_deco_box(p, Vector3(size.x - 0.02, 0.004, size.z - 0.02), Vector3(0, top, 0), Color(0.12, 0.3, 0.7))
			k.label = _label3d(p, "1", top + 0.003, 48, Color.WHITE)
			node = k
		"teclas":
			var t := KeysNode.new()
			t.part = p
			for x: float in [-0.05, 0.05]:
				_deco_box(p, Vector3(0.07, 0.02, 0.07), Vector3(x, top + 0.008, -0.025), Color(0.85, 0.85, 0.88))
			t.label = _label3d(p, t.keys_text(), top + 0.002, 24, Color(1.0, 0.8, 0.3), Vector3(0, 0, 0.055))
			node = t
		"teclado":
			var kp := KeypadNode.new()
			kp.part = p
			for r in 4:
				for col in 3:
					_deco_box(p, Vector3(0.04, 0.012, 0.035), Vector3(-0.05 + col * 0.05, top + 0.004, -0.04 + r * 0.045), Color(0.75, 0.77, 0.8))
			kp.label = _label3d(p, "SENHA", top + 0.002, 26, Color(0.8, 0.85, 0.9), Vector3(0, 0, -0.088))
			p.interact_kind = "teclado"
			node = kp
		"indicador", "pixel", "mostrador", "tela", "tela_texto":
			var d := DisplayNode.new()
			d.part = p
			d.kind = kind
			match kind:
				"indicador":
					d.setup_lamp(_deco_sphere(p, 0.05, Vector3(0, top, 0), Color.WHITE))
				"pixel":
					d.setup_lamp(_deco_box(p, Vector3(size.x - 0.02, 0.006, size.z - 0.02), Vector3(0, top, 0), Color.WHITE))
				"mostrador":
					_deco_box(p, Vector3(size.x - 0.03, 0.004, size.z - 0.03), Vector3(0, top, 0), SCREEN_DARK)
					d.label = _label3d(p, "0.0", top + 0.003, 110, Color(1.0, 0.22, 0.12))
					d.decimals = 1
				"tela":
					_deco_box(p, Vector3(size.x - 0.04, 0.004, size.z - 0.04), Vector3(0, top, 0), SCREEN_DARK)
					d.label = _label3d(p, "A: 0\nB: 0", top + 0.003, 84, Color(0.75, 0.95, 1.0))
				"tela_texto":
					_deco_box(p, Vector3(size.x - 0.04, 0.004, size.z - 0.04), Vector3(0, top, 0), SCREEN_DARK)
					d.label = _label3d(p, "", top + 0.003, 64, Color(0.75, 1.0, 0.8), Vector3.ZERO, size.x - 0.08)
			node = d
		"fpga":
			var f := FpgaNode.new()
			f.part = p
			for i in 6:
				for side: float in [-1.0, 1.0]:
					_deco_box(p, Vector3(0.022, 0.012, 0.02), Vector3(-0.11 + i * 0.044, -0.012, side * (size.z * 0.5 + 0.008)), Color(0.85, 0.7, 0.25))
					_deco_box(p, Vector3(0.02, 0.012, 0.022), Vector3(side * (size.x * 0.5 + 0.008), -0.012, -0.11 + i * 0.044), Color(0.85, 0.7, 0.25))
			_deco_box(p, Vector3(size.x - 0.06, 0.004, size.z - 0.06), Vector3(0, top, 0), Color(0.16, 0.18, 0.22))
			f.label = _label3d(p, "FPGA", top + 0.003, 56, Color(0.55, 0.9, 1.0))
			f.update_label()
			node = f
		"memoria", "rom", "hd":
			var m := MemoryNode.new()
			m.part = p
			if kind == "hd":
				_deco_cyl(p, 0.07, 0.004, Transform3D(Basis(), Vector3(0, top + 0.002, -0.03)), Color(0.75, 0.78, 0.82), 0.9, 16)
				_deco_box(p, Vector3(0.012, 0.006, 0.08), Vector3(0.05, top + 0.006, 0.01), Color(0.3, 0.3, 0.32))
				m.label = _label3d(p, "HD", top + 0.008, 30, Color(0.55, 1.0, 0.6), Vector3(0, 0, 0.09))
			else:
				for i in 4:
					_deco_box(p, Vector3(0.04, 0.012, 0.05), Vector3(-0.075 + i * 0.05, top + 0.004, -0.02), Color(0.1, 0.1, 0.11))
				_deco_box(p, Vector3(size.x - 0.02, 0.012, 0.016), Vector3(0, -0.012, size.z * 0.5 - 0.004), Color(0.85, 0.7, 0.25))
				m.label = _label3d(p, "RAM", top + 0.012, 26, Color(0.55, 0.9, 1.0) if kind == "memoria" else Color(1.0, 0.8, 0.4), Vector3(0, 0, 0.045))
			m.setup(kind)
			node = m
		"radio":
			var r := RadioNode.new()
			r.part = p
			_deco_cyl(p, 0.006, 0.22, Transform3D(Basis(), Vector3(0.045, top + 0.11, -0.045)), Color(0.15, 0.15, 0.16), 0.4)
			_deco_sphere(p, 0.012, Vector3(0.045, top + 0.222, -0.045), Color(0.15, 0.15, 0.16))
			r.light = _deco_box(p, Vector3(0.03, 0.01, 0.03), Vector3(-0.035, top + 0.004, -0.035), Color(0.35, 0.08, 0.06))
			r.label = _label3d(p, "CANAL 1", top + 0.002, 30, Color(0.9, 0.95, 1.0), Vector3(0, 0, 0.035))
			node = r
	Build.add_node(node)
	return p


# --- Energia (Marco 4B) -----------------------------------------------------------

static func _spawn_power(kind: String, xform: Transform3D, k := 1.0) -> Part:
	var size: Vector3 = POWER_SIZES[kind] * (k if kind == "bateria" else 1.0)
	var top := size.y * 0.5
	var mat: String = {"solar": "aluminio", "recarga": "carcaca"}.get(kind, "plastico")
	var p: Part
	if kind == "luz":
		p = Build.spawn_planes(octagon_planes(size.x * 0.5, top), "plastico", xform)
		_component(p, INFO[kind]["nome"], kind)
	else:
		p = _box(size, mat, xform, INFO[kind]["nome"], kind)
	var n := PowerNode.new()
	n.part = p
	n.kind = kind
	n.size_scale = k
	match kind:
		"bateria":
			for x: float in [-0.08, 0.08]:
				_deco_cyl(p, 0.022 * k, 0.03 * k, Transform3D(Basis(), Vector3(x * k, top + 0.012 * k, 0.05 * k)), Color(0.85, 0.15, 0.1) if x > 0 else Color(0.12, 0.12, 0.13), 0.6)
			_deco_box(p, Vector3(size.x + 0.004, 0.03 * k, size.z + 0.004), Vector3(0, top - 0.03 * k, 0), Color(0.95, 0.75, 0.1))
			var w := size.x - 0.06 * k
			n.glow = _deco_box(p, Vector3(w, 0.008, 0.04 * k), Vector3(0, top + 0.004, -0.05 * k), Color.WHITE)
			n.glow.set_meta("x0", 0.0)
			n.glow.set_meta("w", w)
			n.charge = n.capacity() * 0.5          # vem pela metade
		"solar":
			_deco_box(p, Vector3(size.x - 0.03, 0.006, size.z - 0.03), Vector3(0, top + 0.002, 0), Color(0.08, 0.14, 0.32))
			for i in 3:
				_deco_box(p, Vector3(size.x - 0.03, 0.008, 0.008), Vector3(0, top + 0.003, -0.15 + i * 0.15), Color(0.6, 0.65, 0.7))
				_deco_box(p, Vector3(0.008, 0.008, size.z - 0.03), Vector3(-0.15 + i * 0.15, top + 0.003, 0), Color(0.6, 0.65, 0.7))
		"recarga":
			_deco_box(p, Vector3(size.x + 0.02, 0.04, size.z + 0.02), Vector3(0, top - 0.02, 0), Color(0.15, 0.5, 0.25))
			var screen := _deco_box(p, Vector3(0.26, 0.2, 0.01), Vector3(0, 0.25, -size.z * 0.5 - 0.004), SCREEN_DARK)
			screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var l := Label3D.new()
			l.text = "RECARGA"
			l.font_size = 22
			l.pixel_size = 0.0018
			l.outline_size = 4
			l.modulate = Color(0.75, 1.0, 0.8)
			l.position = Vector3(0, 0.25, -size.z * 0.5 - 0.011)
			l.rotation.y = PI
			p.add_child(l)
			n.label = l
			n.glow = _deco_box(p, Vector3(0.06, 0.06, 0.012), Vector3(0, 0.45, -size.z * 0.5 - 0.004), Color.WHITE)
			# Plugue/tomada: onde o fio encosta (topo) e um cabo enrolado de enfeite.
			_deco_cyl(p, 0.05, 0.08, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(size.x * 0.5 + 0.03, 0.0, 0)), Color(0.1, 0.1, 0.1), 0.2)
			n.closed = true
		"luz":
			n.glow = _deco_sphere(p, 0.045, Vector3(0, top + 0.02, 0), Color.WHITE)
			var ol := OmniLight3D.new()
			ol.position = Vector3(0, top + 0.08, 0)
			ol.shadow_enabled = false
			ol.visible = false
			p.add_child(ol)
			n.light = ol
			n.light_range = 8.0
		"holofote":
			var head := Node3D.new()
			head.position = Vector3(0, top + 0.08, 0)
			p.add_child(head)
			_deco_cyl(head, 0.075, 0.14, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), Color(0.2, 0.2, 0.22), 0.6)
			_deco_box(p, Vector3(0.03, 0.06, 0.03), Vector3(0, top + 0.02, 0), Color(0.3, 0.3, 0.32))
			n.glow = _deco_cyl(head, 0.065, 0.01, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.072)), Color.WHITE, 0.0)
			var sl := SpotLight3D.new()
			sl.position = Vector3(0, 0, -0.09)
			sl.spot_angle = 28.0
			sl.shadow_enabled = false
			sl.visible = false
			head.add_child(sl)
			n.light = sl
			n.light_range = 14.0
		"rele":
			_label3d(p, "RELÉ", top + 0.002, 40, Color(0.9, 0.9, 0.95), Vector3(0, 0, 0.02))
			n.glow = _deco_box(p, Vector3(0.03, 0.01, 0.03), Vector3(0.05, top + 0.004, -0.035), Color.WHITE)
		"chave":
			var arm := Node3D.new()
			arm.position = Vector3(0, top, 0.02)
			p.add_child(arm)
			_deco_box(arm, Vector3(0.03, 0.12, 0.03), Vector3(0, 0.06, 0), Color(0.6, 0.62, 0.66))
			_deco_box(arm, Vector3(0.05, 0.03, 0.05), Vector3(0, 0.12, 0), Color(0.95, 0.75, 0.1))
			n.lever = arm
			n.glow = _deco_box(p, Vector3(0.03, 0.01, 0.03), Vector3(0, top + 0.004, -0.07), Color.WHITE)
			p.interact_kind = "chave"
		"medidor":
			_deco_box(p, Vector3(size.x - 0.03, 0.004, size.z - 0.03), Vector3(0, top, 0), SCREEN_DARK)
			n.label = _label3d(p, "", top + 0.003, 40, Color(0.5, 1.0, 0.6))
	Build.add_node(n)
	Power.register(n)
	n.update_visual()
	return p


# --- Sensores (Marco 4C) ---------------------------------------------------------

static func _spawn_sensor(kind: String, xform: Transform3D) -> Part:
	var size: Vector3 = SENSOR_SIZES[kind]
	var top := size.y * 0.5
	var c: Color = SENSOR_COLORS[kind]
	var p: Part
	if kind == "localizador":
		p = Build.spawn_planes(octagon_planes(size.x * 0.5, top), "plastico", xform)
		_component(p, INFO[kind]["nome"], kind)
	else:
		p = _box(size, "plastico", xform, INFO[kind]["nome"], kind)
	var n := SensorNode.new()
	n.part = p
	n.kind = kind
	_deco_box(p, Vector3(size.x - 0.02, 0.004, size.z - 0.02), Vector3(0, top, 0), BOARD_DARK)
	if SENSOR_TEXT.has(kind):
		n.label = _label3d(p, SENSOR_TEXT[kind], top + 0.003, 40, c)
	match kind:
		"ranger":
			_deco_cyl(p, 0.03, 0.03, Transform3D(Basis(), Vector3(0, top + 0.015, 0)), Color(0.2, 0.2, 0.22), 0.6)
			n.glow = _deco_cyl(p, 0.018, 0.006, Transform3D(Basis(), Vector3(0, top + 0.031, 0)), c, 0.0)
			var b := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.003
			cm.bottom_radius = 0.003
			cm.height = 1.0
			cm.radial_segments = 6
			b.mesh = cm
			b.material_override = GameTool.glow_material(Color(1.0, 0.15, 0.1), 3.0)
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			p.add_child(b)
			n.beam = b
		"localizador":
			n.glow = _deco_sphere(p, 0.03, Vector3(0, top + 0.02, 0), c)
			n.label = _label3d(p, "", top + 0.05, 28, c)
			n.label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			n.update_label()
		"sensor_loc":
			n.update_label()
		"buscador":
			_deco_cyl(p, 0.06, 0.012, Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(0, top + 0.03, 0)), Color(0.75, 0.77, 0.8), 0.8)
		"zona":
			n.glow = _deco_box(p, Vector3(0.04, 0.01, 0.04), Vector3(0.06, top + 0.004, -0.06), c)
			var z := MeshInstance3D.new()
			z.mesh = BoxMesh.new()
			var zm := StandardMaterial3D.new()
			zm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			zm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			zm.albedo_color = Color(0.3, 1.0, 0.5, 0.12)
			zm.cull_mode = BaseMaterial3D.CULL_DISABLED
			z.material_override = zm
			z.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			p.add_child(z)
			n.zone_box = z
		"impacto":
			n.glow = _deco_box(p, Vector3(0.05, 0.01, 0.05), Vector3(0, top + 0.004, -0.04), c)
		"receptor":
			for r in 3:
				_deco_cyl(p, 0.07 - r * 0.022, 0.004 + r * 0.002, Transform3D(Basis(), Vector3(0, top + 0.003 + r * 0.002, 0)),
					Color(0.9, 0.9, 0.9) if r % 2 == 0 else Color(0.85, 0.15, 0.1), 0.1)
			n.glow = _deco_sphere(p, 0.018, Vector3(0, top + 0.012, 0), c)
	Build.add_node(n)
	return p


## Balança: base e prato numa mola dura (curso de 4 cm, folga de 4,5 cm). Pesa o que está
## em cima: 100 kg afundam o prato 2 cm (média).
static func _spawn_scale(xform: Transform3D, k := 1.0) -> Array[Part]:
	var base := _box(Vector3(0.4, 0.06, 0.4) * k, "carcaca", xform, "Balança (base)", "balanca")
	var plate := _box(Vector3(0.4, 0.03, 0.4) * k, "aco", xform * Transform3D(Basis(), Vector3(0, 0.09 * k, 0)), "Balança (prato)", "balanca")
	_deco_cyl(plate, 0.05 * k, 0.09 * k, Transform3D(Basis(), Vector3(0, -0.06 * k, 0)), Color(0.3, 0.32, 0.35), 0.7)   # coluna (entra na base)
	_deco_box(base, Vector3(0.14, 0.04, 0.005) * k, Vector3(0, 0, -0.201 * k), SCREEN_DARK)
	var l := Label3D.new()
	l.text = "0.0 kg"
	l.font_size = 24
	l.pixel_size = 0.0014 * k
	l.modulate = Color(0.5, 1.0, 0.6)
	l.position = Vector3(0, 0, -0.205 * k)
	l.rotation.y = PI
	base.add_child(l)
	var j := _joint("balanca", base, plate, Vector3.ZERO, Vector3.UP)
	j.size_scale = k
	j.strength = 50000.0 * k * k       # rigidez (N/m): 100 kg afundam 2 cm (média)
	j.coil = l                          # mostrador do peso
	j.capture_rest()
	Build.add_joint(j)
	return [base, plate]


# --- Trem de força (Marco 4D) -------------------------------------------------------

const ENGINE_COLORS := {
	"motor_mono": Color(0.6, 0.62, 0.66), "motor_4l": Color(0.25, 0.27, 0.3), "motor_v8": Color(0.7, 0.15, 0.12),
	"motor_v12": Color(0.75, 0.6, 0.1), "motor_diesel": Color(0.2, 0.35, 0.2), "motor_rotativo": Color(0.15, 0.3, 0.6),
	"motor_eletrico": Color(0.15, 0.45, 0.75), "turbina": Color(0.55, 0.57, 0.6),
}


static func _spawn_drive(kind: String, xform: Transform3D, k := 1.0) -> Part:
	var size: Vector3 = DRIVE_SIZES[kind] * (k if kind.begins_with("tanque") else 1.0)
	var top := size.y * 0.5
	var n := DriveNode.new()
	n.kind = kind
	n.size_scale = k
	var p: Part
	if kind == "turbina" or kind.begins_with("tanque"):
		# Turbina e tanque: "cilindro" octogonal deitado (eixo Z).
		var planes: Array[Plane] = ConvexGeo.oct_prism_planes(size.x, size.z)
		p = Build.spawn_planes(planes, "carcaca" if kind == "turbina" else "aco", xform)
		_component(p, INFO[kind]["nome"], kind)
	else:
		p = _box(size, "carcaca", xform, INFO[kind]["nome"], kind)
	n.part = p
	if n.is_engine():
		var c: Color = ENGINE_COLORS[kind]
		_deco_box(p, Vector3(size.x + 0.004, size.y * 0.4, size.z + 0.004), Vector3(0, -size.y * 0.1, 0), c)
		var cyl: int = DriveNode.ENGINES[kind]["cyl"]
		if kind == "turbina":
			_deco_cyl(p, size.x * 0.42, 0.04, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -size.z * 0.5 - 0.02)), Color(0.15, 0.15, 0.16), 0.8)
		elif cyl > 0:
			var heads := mini(cyl, 6)
			for h in heads:
				var z := -size.z * 0.35 + size.z * 0.7 * (float(h) / maxf(heads - 1, 1))
				_deco_box(p, Vector3(size.x * 0.7, 0.05, size.z * 0.7 / heads - 0.01), Vector3(0, top + 0.025, z if heads > 1 else 0.0), Color(0.3, 0.32, 0.35))
		else:
			for r in 4:
				_deco_box(p, Vector3(size.x + 0.01, 0.012, 0.02), Vector3(0, top * 0.3, -size.z * 0.3 + r * size.z * 0.2), Color(0.75, 0.77, 0.8))
		n.glow = _deco_box(p, Vector3(0.04, 0.012, 0.04), Vector3(size.x * 0.35, top + 0.006, size.z * 0.4), Color.WHITE)
		n.label = _label3d(p, "", top + 0.055, 28, Color(1.0, 0.85, 0.4))
		n.label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		var snd := AudioStreamPlayer3D.new()
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = 22050.0
		gen.buffer_length = 0.12
		snd.stream = gen
		snd.unit_size = 6.0
		snd.max_distance = 60.0
		snd.volume_db = -10.0
		p.add_child(snd)
		n.sound = snd
	elif n.is_gearbox():
		_deco_box(p, Vector3(size.x - 0.04, 0.004, size.z - 0.04), Vector3(0, top, 0), BOARD_DARK)
		_deco_cyl(p, 0.06, size.z + 0.02, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -0.02, 0)), Color(0.75, 0.77, 0.8), 0.8)
		n.label = _label3d(p, "", top + 0.006, 30, Color(0.9, 0.95, 1.0))
		if kind == "cambio_auto":
			n.gears = 5
		elif kind == "cvt":
			n.gears = 1
			n.first_ratio = 4.0
			n.top_ratio = 0.6
	elif n.is_clutch():
		var cc := Color(0.15, 0.45, 0.75) if kind == "embreagem_auto" else Color(0.85, 0.45, 0.1)
		_deco_cyl(p, 0.11, size.z + 0.01, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), cc, 0.5)
		_deco_cyl(p, 0.03, size.z + 0.06, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), Color(0.75, 0.77, 0.8), 0.9)
		n.glow = _deco_box(p, Vector3(0.04, 0.01, 0.04), Vector3(0.08, top + 0.005, 0.0), Color.WHITE)
		n.label = _label3d(p, "", top + 0.05, 24, Color(1, 1, 1))
		n.label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	else:
		var tc := Color(0.85, 0.15, 0.1) if kind == "tanque_gasolina" else Color(0.15, 0.2, 0.15)
		_deco_cyl(p, size.x * 0.5 + 0.004, size.z * 0.5, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), tc, 0.3)
		_deco_cyl(p, 0.035 * k, 0.04 * k, Transform3D(Basis(), Vector3(size.x * 0.25, size.x * 0.5 + 0.015 * k, size.z * 0.3)), Color(0.15, 0.15, 0.16), 0.6)
		n.label = _label3d(p, "", size.x * 0.5 + 0.04 * k, 26, Color(1, 1, 1))
		n.label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		n.fuel = n.capacity() * 0.5          # vem pela metade
	Build.add_node(n)
	n.update_visual()
	return p


## Cubo de roda: base (solda no chassi) e disco (solda a roda); eixo livre que o câmbio gira.
static func _spawn_hub(xform: Transform3D, k := 1.0) -> Array[Part]:
	var mount := _box(Vector3(0.16, 0.12, 0.16) * k, "carcaca", xform, "Cubo de roda (base)", "cubo")
	_deco_box(mount, Vector3(0.17, 0.03, 0.17) * k, Vector3(0, 0.02, 0) * k, Color(0.85, 0.6, 0.12))
	var disc := _oct(0.1 * k, 0.05 * k, "aco", xform * Transform3D(Basis(), Vector3(0, 0.089 * k, 0)), "Cubo de roda (disco)", "cubo")
	for i in 4:
		var a := i * PI * 0.5
		_deco_cyl(disc, 0.01 * k, 0.02 * k, Transform3D(Basis(), Vector3(cos(a), 0, sin(a)) * 0.06 * k + Vector3(0, 0.03 * k, 0)), Color(0.75, 0.77, 0.8), 0.9)
	var j := _joint("cubo", mount, disc, Vector3(0, 0.06 * k, 0), Vector3.UP)
	j.size_scale = k
	j.strength = 0.0
	j.capture_rest()
	Build.add_joint(j)
	return [mount, disc]


static func _spawn_generator(xform: Transform3D) -> Part:
	var size: Vector3 = DRIVE_SIZES["gerador"]
	var p := _box(size, "carcaca", xform, "Gerador", "gerador")
	_deco_cyl(p, 0.1, size.z + 0.01, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), Color(0.2, 0.45, 0.75), 0.6)
	var n := PowerNode.new()
	n.part = p
	n.kind = "gerador"
	n.glow = _deco_box(p, Vector3(0.04, 0.01, 0.04), Vector3(0.1, size.y * 0.5 + 0.005, -0.1), Color.WHITE)
	Build.add_node(n)
	Power.register(n)
	return p


## Bomba de combustível: soldada no chão, E nela enche os tanques por perto (pago).
static func _spawn_pump(xform: Transform3D) -> Part:
	var size: Vector3 = DRIVE_SIZES["bomba"]
	var p := _box(size, "carcaca", xform, "Bomba de combustível", "bomba")
	_deco_box(p, Vector3(size.x + 0.01, 0.05, size.z + 0.01), Vector3(0, size.y * 0.5 - 0.025, 0), Color(0.85, 0.15, 0.1))
	_deco_box(p, Vector3(0.24, 0.16, 0.01), Vector3(0, 0.2, -size.z * 0.5 - 0.004), SCREEN_DARK)
	var l := Label3D.new()
	l.text = "COMBUSTÍVEL\nE: abastecer\n1 ponto / 5 L"
	l.font_size = 20
	l.pixel_size = 0.0016
	l.outline_size = 4
	l.modulate = Color(1.0, 0.85, 0.4)
	l.position = Vector3(0, 0.2, -size.z * 0.5 - 0.011)
	l.rotation.y = PI
	p.add_child(l)
	_deco_cyl(p, 0.03, 0.25, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(size.x * 0.5 + 0.1, 0.1, 0)), Color(0.1, 0.1, 0.1), 0.2)
	p.interact_kind = "bomba"
	return p


## Texto deitado em cima da peça (lido de quem está na frente, olhando para -Z).
static func _label3d(parent: Node3D, text: String, top_y: float, font_size: int, color: Color, offset := Vector3.ZERO, width := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.pixel_size = 0.0011
	l.modulate = color
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.position = Vector3(0, top_y + 0.002, 0) + offset
	l.rotation.x = -PI * 0.5
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.width = width / l.pixel_size
	parent.add_child(l)
	return l


# --- Aparência para a loja (sem física) ---------------------------------------

static func build_visual(kind: String, size := Vector3.ZERO) -> Node3D:
	var root := Node3D.new()
	var steel := Color(0.6, 0.62, 0.66)
	match kind:
		"motor":
			var octo := MeshInstance3D.new()
			var geo := ConvexGeo.solve(octagon_planes(MOTOR_APOTHEM, MOTOR_HALF_H))
			octo.mesh = ConvexGeo.build_mesh(geo)
			octo.mesh.surface_set_material(0, MetalMaterials.get_material("carcaca"))
			octo.mesh.surface_set_material(1, MetalMaterials.edge_material())
			root.add_child(octo)
			_deco_cyl(root, 0.15, 0.06, Transform3D(Basis(), Vector3(0, MOTOR_HALF_H + 0.034, 0)), steel, 0.85)
			_deco_box(root, Vector3(0.2, 0.012, 0.03), Vector3(0, MOTOR_HALF_H + 0.066, 0), Color(0.9, 0.2, 0.15))
		"servo":
			_deco_box(root, SERVO_SIZE, Vector3.ZERO, Color(0.15, 0.35, 0.7))
			_deco_cyl(root, 0.12, 0.05, Transform3D(Basis(), Vector3(0, SERVO_SIZE.y * 0.5 + 0.029, SERVO_SHAFT_Z)), steel, 0.85)
			_deco_box(root, Vector3(0.16, 0.012, 0.03), Vector3(0, SERVO_SIZE.y * 0.5 + 0.056, SERVO_SHAFT_Z), Color(0.95, 0.95, 0.95))
		"pistao", "servo_linear":
			var linear := kind == "servo_linear"
			var color := Color(0.15, 0.35, 0.7) if linear else Color(0.85, 0.6, 0.12)
			if linear:
				_deco_box(root, Vector3(0.22, 0.1, 0.32), Vector3(0, -0.25, 0), color)
				_deco_box(root, Vector3(0.2, 0.45, 0.3), Vector3(0, 0.025, 0), color)
				_deco_cyl(root, 0.05, 0.5, Transform3D(Basis(), Vector3(0, 0.055, 0)), steel, 0.8)
				_deco_cyl(root, 0.08, 0.04, Transform3D(Basis(), Vector3(0, 0.305, 0)), Color(0.3, 0.32, 0.35))
			else:
				_deco_cyl(root, 0.13, 0.65, Transform3D(Basis(), Vector3(0, -0.025, 0)), color, 0.4)
				_deco_cyl(root, 0.07, 0.6, Transform3D(Basis(), Vector3(0, 0.055, 0)), steel, 0.8)
				_deco_cyl(root, 0.1, 0.04, Transform3D(Basis(), Vector3(0, 0.355, 0)), Color(0.3, 0.32, 0.35))
		"dobradica":
			_deco_box(root, Vector3(0.4, 0.04, 0.25), Vector3(0, 0, -0.155), steel)
			_deco_box(root, Vector3(0.4, 0.04, 0.25), Vector3(0, 0, 0.155), steel)
			_deco_cyl(root, 0.025, 0.42, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO), Color(0.4, 0.42, 0.45))
		"trava", "torcao":
			_deco_box(root, Vector3(0.4, 0.04, 0.25), Vector3(0, 0, -0.155), steel)
			_deco_box(root, Vector3(0.4, 0.04, 0.25), Vector3(0, 0, 0.155), steel)
			_deco_cyl(root, 0.025, 0.42, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO), HINGE_KNUCKLE[kind])
		"mola":
			_deco_box(root, Vector3(0.28, 0.04, 0.28), Vector3.ZERO, steel)
			_deco_box(root, Vector3(0.28, 0.04, 0.28), Vector3(0, 0.3, 0), steel)
			_deco_cyl(root, 0.08, 0.26, Transform3D(Basis(), Vector3(0, 0.15, 0)), Color(0.9, 0.75, 0.15), 0.8)
		"guincho":
			_deco_box(root, Vector3(0.34, 0.28, 0.4), Vector3.ZERO, Color(0.85, 0.6, 0.12))
			_deco_cyl(root, 0.1, 0.3, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0.16, 0)), Color(0.3, 0.32, 0.35))
			_deco_box(root, Vector3(0.12, 0.1, 0.12), Vector3(0.4, -0.09, 0), steel)
		"propulsor":
			_deco_cyl(root, 0.12, 0.36, Transform3D.IDENTITY, steel, 0.8)
			_deco_cyl(root, 0.125, 0.04, Transform3D(Basis(), Vector3(0, 0.1, 0)), Color(0.95, 0.5, 0.1))
			_deco_cyl(root, 0.1, 0.12, Transform3D(Basis(), Vector3(0, -0.24, 0)), Color(0.2, 0.2, 0.22))
		"ima":
			_deco_cyl(root, 0.22, 0.1, Transform3D.IDENTITY, Color(0.16, 0.17, 0.19), 0.2)
			_deco_cyl(root, 0.2, 0.012, Transform3D(Basis(), Vector3(0, -0.056, 0)), steel, 0.9)
			_deco_cyl(root, 0.04, 0.06, Transform3D(Basis(), Vector3(0, 0.08, 0)), steel, 0.9)
		"engate":
			_deco_box(root, Vector3(0.26, 0.08, 0.26), Vector3.ZERO, Color(0.16, 0.17, 0.19))
			for i in 3:
				_deco_box(root, Vector3(0.26, 0.004, 0.04), Vector3(0, 0.041, -0.08 + i * 0.08), Color(0.95, 0.75, 0.1))
		"pino_oct":
			var x_axis := Basis(Vector3.BACK, PI * 0.5)
			_deco_cyl(root, 0.06, 0.12, Transform3D(x_axis, Vector3(-0.065, 0, 0)), steel, 0.6)
			_deco_cyl(root, 0.06, 0.12, Transform3D(x_axis, Vector3(0.065, 0, 0)), Color(0.5, 0.32, 0.2), 0.5)
			_deco_cyl(root, 0.025, 0.3, Transform3D(x_axis, Vector3.ZERO), Color(0.75, 0.77, 0.8))
		"pino":
			_deco_box(root, Vector3(0.12, 0.12, 0.2), Vector3(-0.065, 0, 0), steel)
			_deco_box(root, Vector3(0.12, 0.12, 0.2), Vector3(0.065, 0, 0), Color(0.5, 0.32, 0.2))
			_deco_cyl(root, 0.025, 0.3, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO), Color(0.75, 0.77, 0.8))
		"esferica":
			_deco_box(root, Vector3(0.22, 0.08, 0.22), Vector3.ZERO, Color(0.85, 0.6, 0.12))
			_deco_sphere(root, 0.05, Vector3(0, 0.12, 0), Color(0.75, 0.77, 0.8))
			_deco_cyl(root, 0.02, 0.09, Transform3D(Basis(), Vector3(0, 0.165, 0)), Color(0.75, 0.77, 0.8))
			_deco_box(root, Vector3(0.22, 0.06, 0.22), Vector3(0, 0.24, 0), steel)
		"roda":
			var r := size.x if size.x > 0.0 else 0.35
			var w := size.y if size.y > 0.0 else 0.2
			var tilt := Basis(Vector3.RIGHT, PI * 0.5)
			_deco_cyl(root, r, w, Transform3D(tilt, Vector3.ZERO), Color(0.08, 0.08, 0.085), 0.0, 28)
			_deco_cyl(root, r * 0.6, w + 0.01, Transform3D(tilt, Vector3.ZERO), steel, 0.85, 28)
		"assento":
			_deco_box(root, Vector3(0.6, 0.12, 0.6), Vector3.ZERO, Color(0.16, 0.17, 0.19))
			_deco_box(root, Vector3(0.6, 0.6, 0.1), Vector3(0, 0.36, 0.25), Color(0.16, 0.17, 0.19))
			_deco_box(root, Vector3(0.5, 0.03, 0.5), Vector3(0, 0.07, -0.02), Color(0.45, 0.12, 0.1))
		"botao":
			_deco_box(root, Vector3(0.24, 0.08, 0.24), Vector3.ZERO, Color(0.16, 0.17, 0.19))
			_deco_cyl(root, 0.07, 0.04, Transform3D(Basis(), Vector3(0, 0.055, 0)), Color(0.85, 0.12, 0.1), 0.1)
		"alavanca":
			_deco_box(root, Vector3(0.2, 0.08, 0.3), Vector3.ZERO, Color(0.16, 0.17, 0.19))
			var arm := Node3D.new()
			arm.position = Vector3(0, 0.04, 0)
			arm.rotation.x = deg_to_rad(30)
			root.add_child(arm)
			_deco_box(arm, Vector3(0.035, 0.28, 0.035), Vector3(0, 0.14, 0), steel)
			_deco_box(arm, Vector3(0.07, 0.07, 0.07), Vector3(0, 0.29, 0), Color(0.85, 0.12, 0.1))
		"potenciometro":
			_deco_box(root, Vector3(0.2, 0.08, 0.4), Vector3.ZERO, Color(0.16, 0.17, 0.19))
			_deco_box(root, Vector3(0.1, 0.06, 0.05), Vector3(0, 0.07, -0.07), Color(0.95, 0.65, 0.1))
		"isolador":
			_insulator_visual(root)
		"puxador":
			_deco_box(root, Vector3(0.18, 0.025, 0.05), Vector3.ZERO, steel)
			_handle_visual(root)
		"bateria":
			var bs: Vector3 = POWER_SIZES[kind]
			_deco_box(root, bs, Vector3.ZERO, Color(0.13, 0.14, 0.16))
			_deco_box(root, Vector3(bs.x + 0.004, 0.03, bs.z + 0.004), Vector3(0, bs.y * 0.5 - 0.03, 0), Color(0.95, 0.75, 0.1))
			_deco_box(root, Vector3(bs.x - 0.06, 0.008, 0.04), Vector3(0, bs.y * 0.5 + 0.004, -0.05), Color(0.3, 1.0, 0.4), 1.5)
			for x: float in [-0.08, 0.08]:
				_deco_cyl(root, 0.022, 0.03, Transform3D(Basis(), Vector3(x, bs.y * 0.5 + 0.012, 0.05)), Color(0.85, 0.15, 0.1) if x > 0 else Color(0.12, 0.12, 0.13), 0.6)
		"solar":
			_deco_box(root, POWER_SIZES[kind], Vector3.ZERO, Color(0.6, 0.62, 0.66))
			_deco_box(root, Vector3(0.57, 0.006, 0.57), Vector3(0, 0.017, 0), Color(0.08, 0.14, 0.32))
		"recarga":
			_deco_box(root, POWER_SIZES[kind], Vector3.ZERO, Color(0.3, 0.32, 0.35))
			_deco_box(root, Vector3(0.37, 0.04, 0.32), Vector3(0, 0.58, 0), Color(0.15, 0.5, 0.25))
			_deco_box(root, Vector3(0.26, 0.2, 0.01), Vector3(0, 0.25, -0.155), SCREEN_DARK)
			_deco_box(root, Vector3(0.06, 0.06, 0.012), Vector3(0, 0.45, -0.155), Color(0.3, 1.0, 0.4), 2.0)
		"luz":
			_deco_cyl(root, 0.07, 0.05, Transform3D.IDENTITY, Color(0.16, 0.17, 0.19))
			_deco_box(root, Vector3(0.07, 0.07, 0.07), Vector3(0, 0.045, 0), Color(1.0, 0.9, 0.6), 3.0)
		"holofote":
			_deco_box(root, POWER_SIZES[kind], Vector3.ZERO, Color(0.16, 0.17, 0.19))
			_deco_box(root, Vector3(0.03, 0.06, 0.03), Vector3(0, 0.05, 0), Color(0.3, 0.3, 0.32))
			_deco_cyl(root, 0.075, 0.14, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.11, 0)), Color(0.2, 0.2, 0.22), 0.6)
			_deco_box(root, Vector3(0.1, 0.1, 0.01), Vector3(0, 0.11, -0.075), Color(1.0, 0.95, 0.7), 3.0)
		"ranger", "velocimetro", "giroscopio", "gps", "localizador", "sensor_loc", "buscador", "zona", "impacto", "receptor":
			var ss: Vector3 = SENSOR_SIZES[kind]
			var sc: Color = SENSOR_COLORS[kind]
			_deco_box(root, ss, Vector3.ZERO, BOARD_DARK)
			if SENSOR_TEXT.has(kind):
				_label3d(root, SENSOR_TEXT[kind], ss.y * 0.5 + 0.003, 40, sc)
			match kind:
				"ranger":
					_deco_cyl(root, 0.03, 0.03, Transform3D(Basis(), Vector3(0, ss.y * 0.5 + 0.015, 0)), Color(0.2, 0.2, 0.22))
					_deco_box(root, Vector3(0.006, 0.4, 0.006), Vector3(0, ss.y * 0.5 + 0.23, 0), sc, 3.0)
				"localizador":
					_deco_sphere(root, 0.03, Vector3(0, ss.y * 0.5 + 0.02, 0), sc)
				"zona":
					_deco_box(root, Vector3(0.2, 0.2, 0.2), Vector3(0, 0.12, 0), Color(0.3, 1.0, 0.5), 0.5)
				"receptor":
					_deco_cyl(root, 0.07, 0.006, Transform3D(Basis(), Vector3(0, ss.y * 0.5 + 0.003, 0)), Color(0.9, 0.9, 0.9))
					_deco_cyl(root, 0.035, 0.008, Transform3D(Basis(), Vector3(0, ss.y * 0.5 + 0.004, 0)), sc)
		"cubo":
			_deco_box(root, Vector3(0.16, 0.12, 0.16), Vector3.ZERO, Color(0.3, 0.32, 0.35))
			_deco_cyl(root, 0.1, 0.05, Transform3D(Basis(), Vector3(0, 0.089, 0)), steel, 0.85)
		"gerador":
			_deco_box(root, DRIVE_SIZES[kind], Vector3.ZERO, Color(0.3, 0.32, 0.35))
			_deco_cyl(root, 0.1, 0.31, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), Color(0.2, 0.45, 0.75), 0.6)
		"bomba":
			_deco_box(root, DRIVE_SIZES[kind], Vector3.ZERO, Color(0.85, 0.6, 0.12))
			_deco_box(root, Vector3(0.41, 0.05, 0.31), Vector3(0, 0.525, 0), Color(0.85, 0.15, 0.1))
		"motor_mono", "motor_4l", "motor_v8", "motor_v12", "motor_diesel", "motor_rotativo", "motor_eletrico", "turbina":
			var es: Vector3 = DRIVE_SIZES[kind]
			_deco_box(root, es, Vector3.ZERO, Color(0.3, 0.32, 0.35))
			_deco_box(root, Vector3(es.x + 0.004, es.y * 0.4, es.z + 0.004), Vector3(0, -es.y * 0.1, 0), ENGINE_COLORS[kind])
			_deco_box(root, Vector3(es.x * 0.7, 0.05, es.z * 0.7), Vector3(0, es.y * 0.5 + 0.025, 0), Color(0.3, 0.32, 0.35))
		"cambio_manual", "cambio_auto", "cvt":
			var gs: Vector3 = DRIVE_SIZES[kind]
			_deco_box(root, gs, Vector3.ZERO, Color(0.3, 0.32, 0.35))
			_deco_cyl(root, 0.06, gs.z + 0.02, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -0.02, 0)), Color(0.75, 0.77, 0.8), 0.8)
		"embreagem_auto", "embreagem_manual":
			var cs: Vector3 = DRIVE_SIZES[kind]
			_deco_box(root, cs, Vector3.ZERO, Color(0.3, 0.32, 0.35))
			_deco_cyl(root, 0.11, cs.z + 0.01, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), Color(0.15, 0.45, 0.75) if kind == "embreagem_auto" else Color(0.85, 0.45, 0.1), 0.5)
		"tanque_gasolina", "tanque_diesel":
			var ts: Vector3 = DRIVE_SIZES[kind]
			_deco_cyl(root, ts.x * 0.5, ts.z, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), Color(0.85, 0.15, 0.1) if kind == "tanque_gasolina" else Color(0.15, 0.2, 0.15), 0.3)
		"balanca":
			_deco_box(root, Vector3(0.4, 0.06, 0.4), Vector3.ZERO, Color(0.85, 0.6, 0.12))
			_deco_box(root, Vector3(0.4, 0.03, 0.4), Vector3(0, 0.09, 0), Color(0.6, 0.62, 0.66))
			_deco_cyl(root, 0.05, 0.06, Transform3D(Basis(), Vector3(0, 0.045, 0)), Color(0.3, 0.32, 0.35))
			_deco_box(root, Vector3(0.14, 0.04, 0.005), Vector3(0, 0, -0.201), SCREEN_DARK)
		"rele", "chave", "medidor":
			var rs: Vector3 = POWER_SIZES[kind]
			_deco_box(root, rs, Vector3.ZERO, BOARD_DARK)
			match kind:
				"rele":
					_label3d(root, "RELÉ", rs.y * 0.5 + 0.002, 40, Color(0.9, 0.9, 0.95))
				"chave":
					_deco_box(root, Vector3(0.03, 0.12, 0.03), Vector3(0, 0.09, 0.02), Color(0.6, 0.62, 0.66))
					_deco_box(root, Vector3(0.05, 0.03, 0.05), Vector3(0, 0.15, 0.02), Color(0.95, 0.75, 0.1))
				"medidor":
					_deco_box(root, Vector3(rs.x - 0.03, 0.004, rs.z - 0.03), Vector3(0, rs.y * 0.5, 0), SCREEN_DARK)
					_label3d(root, "75%", rs.y * 0.5 + 0.003, 48, Color(0.5, 1.0, 0.6))
		"chip", "constante", "teclas", "teclado", "indicador", "pixel", "mostrador", "tela", "tela_texto", "fpga", "memoria", "rom", "hd", "radio":
			var ssz: Vector3 = SIGNAL_SIZES[kind]
			_deco_box(root, ssz, Vector3.ZERO, BOARD_DARK)
			var top := ssz.y * 0.5
			match kind:
				"chip":
					_label3d(root, "E", top, 64, Color.WHITE)
					for i in 4:
						for side: float in [-1.0, 1.0]:
							_deco_box(root, Vector3(0.025, 0.012, 0.02), Vector3(-0.09 + i * 0.06, -0.012, side * (ssz.z * 0.5 + 0.008)), Color(0.85, 0.7, 0.25))
				"constante":
					_deco_box(root, Vector3(ssz.x - 0.02, 0.004, ssz.z - 0.02), Vector3(0, top, 0), Color(0.12, 0.3, 0.7))
					_label3d(root, "1", top + 0.003, 48, Color.WHITE)
				"teclas":
					for x: float in [-0.05, 0.05]:
						_deco_box(root, Vector3(0.07, 0.02, 0.07), Vector3(x, top + 0.008, -0.025), Color(0.85, 0.85, 0.88))
				"teclado":
					for r in 4:
						for col in 3:
							_deco_box(root, Vector3(0.04, 0.012, 0.035), Vector3(-0.05 + col * 0.05, top + 0.004, -0.04 + r * 0.045), Color(0.75, 0.77, 0.8))
				"indicador":
					_deco_sphere(root, 0.05, Vector3(0, top, 0), Color(0.2, 1.0, 0.3))
				"pixel":
					_deco_box(root, Vector3(ssz.x - 0.02, 0.006, ssz.z - 0.02), Vector3(0, top, 0), Color(0.9, 0.3, 0.8), 1.0)
				"mostrador":
					_deco_box(root, Vector3(ssz.x - 0.03, 0.004, ssz.z - 0.03), Vector3(0, top, 0), SCREEN_DARK)
					_label3d(root, "12.5", top + 0.003, 110, Color(1.0, 0.22, 0.12))
				"fpga":
					_deco_box(root, Vector3(ssz.x - 0.06, 0.004, ssz.z - 0.06), Vector3(0, top, 0), Color(0.16, 0.18, 0.22))
					_label3d(root, "FPGA", top + 0.003, 56, Color(0.55, 0.9, 1.0))
				"memoria", "rom":
					for i in 4:
						_deco_box(root, Vector3(0.04, 0.012, 0.05), Vector3(-0.075 + i * 0.05, top + 0.004, -0.02), Color(0.1, 0.1, 0.11))
					_label3d(root, "RAM" if kind == "memoria" else "ROM", top + 0.012, 26, Color(0.55, 0.9, 1.0), Vector3(0, 0, 0.045))
				"hd":
					_deco_cyl(root, 0.07, 0.004, Transform3D(Basis(), Vector3(0, top + 0.002, -0.03)), Color(0.75, 0.78, 0.82), 0.9, 16)
					_label3d(root, "HD", top + 0.008, 30, Color(0.55, 1.0, 0.6), Vector3(0, 0, 0.09))
				"radio":
					_deco_cyl(root, 0.006, 0.22, Transform3D(Basis(), Vector3(0.045, top + 0.11, -0.045)), Color(0.15, 0.15, 0.16), 0.4)
					_deco_box(root, Vector3(0.03, 0.01, 0.03), Vector3(-0.035, top + 0.004, -0.035), Color(0.3, 1.0, 0.4), 2.0)
				"tela", "tela_texto":
					_deco_box(root, Vector3(ssz.x - 0.04, 0.004, ssz.z - 0.04), Vector3(0, top, 0), SCREEN_DARK)
					_label3d(root, "A: 1\nB: 0" if kind == "tela" else "Olá!", top + 0.003, 56, Color(0.75, 0.95, 1.0))
	if kind in SCALED:
		root.scale = Vector3.ONE * scale_of(kind, size)
	return root
