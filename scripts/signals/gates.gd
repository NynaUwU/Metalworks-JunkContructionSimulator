class_name Gates
extends RefCounted
## Modos do chip lógico (inspirado nos "gates" do Wiremod).
##
## Cada modo: categoria, nome, símbolo (aparece em cima do chip), entradas, saídas e
## descrição. `run` calcula as saídas a partir das entradas (`wired` diz quais têm fio)
## e de um estado guardado no chip (memórias, temporizadores).
## Verdadeiro = número maior que 0. Tempos em segundos.

const N := SignalNode.NUM
const V := SignalNode.VEC
const S := SignalNode.TXT

const ABCD := [["A", N], ["B", N], ["C", N], ["D", N]]
const AB := [["A", N], ["B", N]]
const OUT := [["Saída", N]]

const CATEGORIES := ["Lógica", "Aritmética", "Comparação", "Memória", "Seleção", "Tempo",
	"Trigonometria", "Bits", "Vetor", "Texto"]

const DEFS := {
	# --- Lógica -----------------------------------------------------------------
	"e": {"cat": "Lógica", "name": "E (AND)", "sym": "E", "ins": ABCD, "outs": OUT, "desc": "1 se todas as entradas ligadas forem verdadeiras."},
	"ou": {"cat": "Lógica", "name": "OU (OR)", "sym": "OU", "ins": ABCD, "outs": OUT, "desc": "1 se alguma entrada for verdadeira."},
	"nao": {"cat": "Lógica", "name": "NÃO (NOT)", "sym": "NÃO", "ins": [["A", N]], "outs": OUT, "desc": "Inverte: 1 se A for falso, 0 se for verdadeiro."},
	"xou": {"cat": "Lógica", "name": "OU exclusivo (XOR)", "sym": "XOU", "ins": ABCD, "outs": OUT, "desc": "1 se um número ímpar de entradas for verdadeiro."},
	"nao_e": {"cat": "Lógica", "name": "NÃO-E (NAND)", "sym": "NE", "ins": ABCD, "outs": OUT, "desc": "0 só se todas as entradas ligadas forem verdadeiras."},
	"nao_ou": {"cat": "Lógica", "name": "NÃO-OU (NOR)", "sym": "NOU", "ins": ABCD, "outs": OUT, "desc": "1 só se nenhuma entrada for verdadeira."},
	"xnou": {"cat": "Lógica", "name": "XNOR", "sym": "XNOU", "ins": ABCD, "outs": OUT, "desc": "1 se um número par de entradas for verdadeiro."},
	# --- Aritmética -------------------------------------------------------------
	"soma": {"cat": "Aritmética", "name": "Somar", "sym": "+", "ins": ABCD, "outs": OUT, "desc": "A + B + C + D."},
	"subtrai": {"cat": "Aritmética", "name": "Subtrair", "sym": "−", "ins": AB, "outs": OUT, "desc": "A − B."},
	"multiplica": {"cat": "Aritmética", "name": "Multiplicar", "sym": "×", "ins": ABCD, "outs": OUT, "desc": "Multiplica as entradas ligadas."},
	"divide": {"cat": "Aritmética", "name": "Dividir", "sym": "÷", "ins": AB, "outs": OUT, "desc": "A ÷ B (dividir por 0 dá 0)."},
	"resto": {"cat": "Aritmética", "name": "Resto (módulo)", "sym": "%", "ins": AB, "outs": OUT, "desc": "Resto de A ÷ B."},
	"potencia": {"cat": "Aritmética", "name": "Potência", "sym": "xʸ", "ins": AB, "outs": OUT, "desc": "A elevado a B."},
	"raiz": {"cat": "Aritmética", "name": "Raiz quadrada", "sym": "√", "ins": [["A", N]], "outs": OUT, "desc": "√A (negativo dá 0)."},
	"absoluto": {"cat": "Aritmética", "name": "Valor absoluto", "sym": "|x|", "ins": [["A", N]], "outs": OUT, "desc": "A sem sinal."},
	"negar": {"cat": "Aritmética", "name": "Negar", "sym": "−x", "ins": [["A", N]], "outs": OUT, "desc": "−A."},
	"inverso": {"cat": "Aritmética", "name": "Inverso", "sym": "1/x", "ins": [["A", N]], "outs": OUT, "desc": "1 ÷ A."},
	"arredonda": {"cat": "Aritmética", "name": "Arredondar", "sym": "≈", "ins": [["A", N], ["Casas", N]], "outs": OUT, "desc": "Arredonda A com o número de casas decimais."},
	"piso": {"cat": "Aritmética", "name": "Arredondar para baixo", "sym": "⌊x⌋", "ins": [["A", N]], "outs": OUT, "desc": "Maior inteiro ≤ A."},
	"teto": {"cat": "Aritmética", "name": "Arredondar para cima", "sym": "⌈x⌉", "ins": [["A", N]], "outs": OUT, "desc": "Menor inteiro ≥ A."},
	"sinal": {"cat": "Aritmética", "name": "Sinal", "sym": "±", "ins": [["A", N]], "outs": OUT, "desc": "−1, 0 ou 1."},
	"minimo": {"cat": "Aritmética", "name": "Mínimo", "sym": "MÍN", "ins": ABCD, "outs": OUT, "desc": "Menor das entradas ligadas."},
	"maximo": {"cat": "Aritmética", "name": "Máximo", "sym": "MÁX", "ins": ABCD, "outs": OUT, "desc": "Maior das entradas ligadas."},
	"media": {"cat": "Aritmética", "name": "Média", "sym": "MÉD", "ins": ABCD, "outs": OUT, "desc": "Média das entradas ligadas."},
	"limita": {"cat": "Aritmética", "name": "Limitar", "sym": "LIM", "ins": [["Valor", N], ["Mín", N], ["Máx", N]], "outs": OUT, "desc": "Mantém o valor entre Mín e Máx."},
	"remapeia": {"cat": "Aritmética", "name": "Converter faixa", "sym": "↦", "ins": [["Valor", N], ["De mín", N], ["De máx", N], ["Para mín", N], ["Para máx", N]], "outs": OUT, "desc": "Leva Valor da faixa De para a faixa Para (ex.: -1..1 → 0..90)."},
	"porcentagem": {"cat": "Aritmética", "name": "Porcentagem", "sym": "%·", "ins": [["Valor", N], ["Máx", N]], "outs": OUT, "desc": "Valor ÷ Máx × 100."},
	"aleatorio": {"cat": "Aritmética", "name": "Aleatório", "sym": "?", "ins": [["Mín", N], ["Máx", N]], "outs": OUT, "desc": "Número aleatório entre Mín e Máx (novo a cada tick)."},
	"log": {"cat": "Aritmética", "name": "Logaritmo natural", "sym": "ln", "ins": [["A", N]], "outs": OUT, "desc": "ln(A)."},
	"exp": {"cat": "Aritmética", "name": "Exponencial", "sym": "eˣ", "ins": [["A", N]], "outs": OUT, "desc": "e elevado a A."},
	"pi": {"cat": "Aritmética", "name": "Pi", "sym": "π", "ins": [], "outs": OUT, "desc": "3,14159…"},
	"delta": {"cat": "Aritmética", "name": "Diferença", "sym": "Δ", "ins": [["A", N]], "outs": OUT, "desc": "Quanto A mudou desde o tick anterior."},
	# --- Comparação -------------------------------------------------------------
	"igual": {"cat": "Comparação", "name": "Igual", "sym": "=", "ins": AB, "outs": OUT, "desc": "1 se A = B."},
	"diferente": {"cat": "Comparação", "name": "Diferente", "sym": "≠", "ins": AB, "outs": OUT, "desc": "1 se A ≠ B."},
	"menor": {"cat": "Comparação", "name": "Menor que", "sym": "<", "ins": AB, "outs": OUT, "desc": "1 se A < B."},
	"maior": {"cat": "Comparação", "name": "Maior que", "sym": ">", "ins": AB, "outs": OUT, "desc": "1 se A > B."},
	"menor_igual": {"cat": "Comparação", "name": "Menor ou igual", "sym": "≤", "ins": AB, "outs": OUT, "desc": "1 se A ≤ B."},
	"maior_igual": {"cat": "Comparação", "name": "Maior ou igual", "sym": "≥", "ins": AB, "outs": OUT, "desc": "1 se A ≥ B."},
	"na_faixa": {"cat": "Comparação", "name": "Está na faixa", "sym": "∈", "ins": [["Valor", N], ["Mín", N], ["Máx", N]], "outs": OUT, "desc": "1 se Mín ≤ Valor ≤ Máx."},
	# --- Memória ----------------------------------------------------------------
	"latch": {"cat": "Memória", "name": "Memória (latch)", "sym": "MEM", "ins": [["Dado", N], ["Clk", N]], "outs": OUT, "desc": "Guarda Dado quando Clk liga (borda de subida) e mantém."},
	"d_latch": {"cat": "Memória", "name": "Memória enquanto ligado (D-latch)", "sym": "D", "ins": [["Dado", N], ["Clk", N]], "outs": OUT, "desc": "Enquanto Clk está ligado, segue Dado; desligado, mantém o último."},
	"sr_latch": {"cat": "Memória", "name": "Liga/desliga (SR)", "sym": "SR", "ins": [["Ligar", N], ["Desligar", N]], "outs": OUT, "desc": "Ligar → 1, Desligar → 0 (Desligar tem prioridade)."},
	"alternador": {"cat": "Memória", "name": "Alternador (toggle)", "sym": "⇄", "ins": [["Clk", N], ["Ligado", N], ["Desligado", N]], "outs": OUT, "desc": "Cada vez que Clk liga, troca entre Ligado (padrão 1) e Desligado (padrão 0)."},
	"contador": {"cat": "Memória", "name": "Contador", "sym": "CONT", "ins": [["Somar", N], ["Subtrair", N], ["Zerar", N]], "outs": [["Valor", N]], "desc": "Soma 1 a cada pulso em Somar, tira 1 em Subtrair; Zerar volta a 0."},
	"ram": {"cat": "Memória", "name": "Memória de 8 posições (RAM)", "sym": "RAM", "ins": [["Ler", N], ["Escrever em", N], ["Dado", N], ["Gravar", N], ["Zerar", N]], "outs": [["Lido", N]], "desc": "8 posições (0 a 7). Com Gravar ligado, guarda Dado em 'Escrever em'. 'Lido' mostra a posição 'Ler'."},
	# --- Seleção ----------------------------------------------------------------
	"se": {"cat": "Seleção", "name": "Se… então… senão", "sym": "SE", "ins": [["Condição", N], ["Então", N], ["Senão", N]], "outs": OUT, "desc": "Condição verdadeira → Então; senão → Senão."},
	"seleciona": {"cat": "Seleção", "name": "Selecionar (multiplexador)", "sym": "MUX", "ins": [["Escolha", N], ["A", N], ["B", N], ["C", N], ["D", N]], "outs": OUT, "desc": "Escolha 1→A, 2→B, 3→C, 4→D (outro valor → 0)."},
	"roteia": {"cat": "Seleção", "name": "Rotear (demultiplexador)", "sym": "DMX", "ins": [["Caminho", N], ["Dado", N]], "outs": [["A", N], ["B", N], ["C", N], ["D", N]], "desc": "Manda Dado para a saída do Caminho (1 a 4); as outras ficam em 0."},
	# --- Tempo ------------------------------------------------------------------
	"temporizador": {"cat": "Tempo", "name": "Cronômetro", "sym": "⏱", "ins": [["Rodar", N], ["Zerar", N]], "outs": [["Tempo", N]], "desc": "Conta os segundos enquanto Rodar está ligado (sem fio = sempre)."},
	"pulsador": {"cat": "Tempo", "name": "Pulsador", "sym": "⏵⏵", "ins": [["Rodar", N], ["Intervalo", N]], "outs": [["Pulso", N]], "desc": "Dá um pulso (1 por um tick) a cada Intervalo segundos (padrão 1 s)."},
	"onda": {"cat": "Tempo", "name": "Pisca (onda quadrada)", "sym": "⊓⊔", "ins": [["Rodar", N], ["Ligado (s)", N], ["Desligado (s)", N]], "outs": OUT, "desc": "Fica ligado e desligado alternando (padrão 0,5 s cada)."},
	"monoestavel": {"cat": "Tempo", "name": "Temporizador (monoestável)", "sym": "⏲", "ins": [["Disparar", N], ["Tempo", N]], "outs": OUT, "desc": "Ao disparar, fica 1 por Tempo segundos (padrão 1 s)."},
	"atraso": {"cat": "Tempo", "name": "Atraso", "sym": "⧗", "ins": [["Entrada", N], ["Tempo", N]], "outs": OUT, "desc": "Repete a Entrada Tempo segundos depois (máx. 10 s)."},
	"derivada": {"cat": "Tempo", "name": "Taxa de variação", "sym": "d/dt", "ins": [["A", N]], "outs": OUT, "desc": "Quanto A muda por segundo."},
	"acumulador": {"cat": "Tempo", "name": "Acumulador", "sym": "∫", "ins": [["Entrada", N], ["Pausar", N], ["Zerar", N]], "outs": OUT, "desc": "Soma Entrada × tempo (ex.: velocidade → distância)."},
	"suaviza": {"cat": "Tempo", "name": "Suavizar", "sym": "~", "ins": [["Entrada", N], ["Taxa", N]], "outs": OUT, "desc": "Vai até a Entrada aos poucos (Taxa por segundo, padrão 1)."},
	# --- Trigonometria (graus) ---------------------------------------------------
	"sen": {"cat": "Trigonometria", "name": "Seno", "sym": "sen", "ins": [["Graus", N]], "outs": OUT, "desc": "Seno do ângulo em graus."},
	"cos": {"cat": "Trigonometria", "name": "Cosseno", "sym": "cos", "ins": [["Graus", N]], "outs": OUT, "desc": "Cosseno do ângulo em graus."},
	"tan": {"cat": "Trigonometria", "name": "Tangente", "sym": "tan", "ins": [["Graus", N]], "outs": OUT, "desc": "Tangente do ângulo em graus."},
	"asen": {"cat": "Trigonometria", "name": "Arco seno", "sym": "asen", "ins": [["A", N]], "outs": OUT, "desc": "Ângulo (graus) cujo seno é A."},
	"acos": {"cat": "Trigonometria", "name": "Arco cosseno", "sym": "acos", "ins": [["A", N]], "outs": OUT, "desc": "Ângulo (graus) cujo cosseno é A."},
	"atan": {"cat": "Trigonometria", "name": "Arco tangente", "sym": "atan", "ins": [["A", N]], "outs": OUT, "desc": "Ângulo (graus) cuja tangente é A."},
	"atan2": {"cat": "Trigonometria", "name": "Ângulo de X, Y", "sym": "atan2", "ins": [["Y", N], ["X", N]], "outs": OUT, "desc": "Ângulo (graus) do ponto (X, Y)."},
	"graus_rad": {"cat": "Trigonometria", "name": "Graus → radianos", "sym": "°→r", "ins": [["A", N]], "outs": OUT, "desc": "Converte graus em radianos."},
	"rad_graus": {"cat": "Trigonometria", "name": "Radianos → graus", "sym": "r→°", "ins": [["A", N]], "outs": OUT, "desc": "Converte radianos em graus."},
	"dif_angulo": {"cat": "Trigonometria", "name": "Diferença de ângulos", "sym": "∠Δ", "ins": AB, "outs": OUT, "desc": "A − B em graus, entre -180 e 180."},
	# --- Bits (inteiros) ----------------------------------------------------------
	"bit_e": {"cat": "Bits", "name": "E bit a bit", "sym": "&", "ins": AB, "outs": OUT, "desc": "A AND B nos bits."},
	"bit_ou": {"cat": "Bits", "name": "OU bit a bit", "sym": "|", "ins": AB, "outs": OUT, "desc": "A OR B nos bits."},
	"bit_xou": {"cat": "Bits", "name": "XOU bit a bit", "sym": "^", "ins": AB, "outs": OUT, "desc": "A XOR B nos bits."},
	"bit_nao": {"cat": "Bits", "name": "NÃO bit a bit", "sym": "~", "ins": [["A", N]], "outs": OUT, "desc": "Inverte os bits de A."},
	"bit_esq": {"cat": "Bits", "name": "Deslocar à esquerda", "sym": "<<", "ins": AB, "outs": OUT, "desc": "A << B."},
	"bit_dir": {"cat": "Bits", "name": "Deslocar à direita", "sym": ">>", "ins": AB, "outs": OUT, "desc": "A >> B."},
	# --- Vetor ------------------------------------------------------------------
	"compor": {"cat": "Vetor", "name": "Montar vetor", "sym": "→V", "ins": [["X", N], ["Y", N], ["Z", N]], "outs": [["Vetor", V]], "desc": "Junta X, Y e Z num vetor."},
	"decompor": {"cat": "Vetor", "name": "Separar vetor", "sym": "V→", "ins": [["Vetor", V]], "outs": [["X", N], ["Y", N], ["Z", N]], "desc": "Separa o vetor em X, Y e Z."},
	"vet_soma": {"cat": "Vetor", "name": "Somar vetores", "sym": "V+", "ins": [["A", V], ["B", V]], "outs": [["Vetor", V]], "desc": "A + B."},
	"vet_sub": {"cat": "Vetor", "name": "Subtrair vetores", "sym": "V−", "ins": [["A", V], ["B", V]], "outs": [["Vetor", V]], "desc": "A − B."},
	"vet_escala": {"cat": "Vetor", "name": "Multiplicar vetor", "sym": "V×", "ins": [["Vetor", V], ["Número", N]], "outs": [["Vetor", V]], "desc": "Vetor × número."},
	"comprimento": {"cat": "Vetor", "name": "Comprimento", "sym": "|V|", "ins": [["Vetor", V]], "outs": OUT, "desc": "Tamanho do vetor."},
	"normalizar": {"cat": "Vetor", "name": "Direção (normalizar)", "sym": "V̂", "ins": [["Vetor", V]], "outs": [["Vetor", V]], "desc": "Mesmo sentido, tamanho 1."},
	"escalar": {"cat": "Vetor", "name": "Produto escalar", "sym": "·", "ins": [["A", V], ["B", V]], "outs": OUT, "desc": "A · B."},
	"vetorial": {"cat": "Vetor", "name": "Produto vetorial", "sym": "⨯", "ins": [["A", V], ["B", V]], "outs": [["Vetor", V]], "desc": "A × B."},
	"distancia": {"cat": "Vetor", "name": "Distância", "sym": "↔", "ins": [["A", V], ["B", V]], "outs": OUT, "desc": "Distância entre os pontos A e B."},
	# --- Texto ------------------------------------------------------------------
	"juntar": {"cat": "Texto", "name": "Juntar textos", "sym": "A+B", "ins": [["A", S], ["B", S], ["C", S], ["D", S]], "outs": [["Texto", S]], "desc": "Junta os textos na ordem."},
	"num_texto": {"cat": "Texto", "name": "Número → texto", "sym": "123→", "ins": [["Número", N], ["Casas", N]], "outs": [["Texto", S]], "desc": "Escreve o número com as casas decimais pedidas."},
	"texto_num": {"cat": "Texto", "name": "Texto → número", "sym": "→123", "ins": [["Texto", S]], "outs": OUT, "desc": "Lê um número escrito no texto."},
	"tamanho": {"cat": "Texto", "name": "Tamanho do texto", "sym": "#", "ins": [["Texto", S]], "outs": OUT, "desc": "Quantas letras o texto tem."},
	"maiusculas": {"cat": "Texto", "name": "Maiúsculas", "sym": "AB", "ins": [["Texto", S]], "outs": [["Texto", S]], "desc": "Passa o texto para maiúsculas."},
	"texto_igual": {"cat": "Texto", "name": "Textos iguais", "sym": "A=B", "ins": [["A", S], ["B", S]], "outs": OUT, "desc": "1 se os textos forem iguais."},
}


static func modes_in(cat: String) -> Array:
	var out: Array = []
	for id: String in DEFS:
		if DEFS[id]["cat"] == cat:
			out.append(id)
	return out


static func _t(x: float) -> bool:
	return x > 0.0


static func _b(cond: bool) -> float:
	return 1.0 if cond else 0.0


## Borda de subida: estava desligado e agora ligou.
static func _rising(state: Dictionary, key: String, v: float) -> bool:
	var prev: float = state.get(key, 0.0)
	state[key] = v
	return prev <= 0.0 and v > 0.0


## Valores das entradas ligadas, na ordem A, B, C, D.
static func _wired_nums(i: Dictionary, wired: Dictionary) -> Array:
	var out: Array = []
	for k in ["A", "B", "C", "D"]:
		if wired.has(k):
			out.append(float(i[k]))
	return out


## Calcula as saídas do modo `id`.
static func run(id: String, i: Dictionary, wired: Dictionary, state: Dictionary, dt: float) -> Dictionary:
	match id:
		# Lógica
		"e", "nao_e":
			var vals := _wired_nums(i, wired)
			var all := not vals.is_empty()
			for x in vals:
				all = all and _t(x)
			return {"Saída": _b(all if id == "e" else not all)}
		"ou", "nao_ou":
			var any := false
			for x in _wired_nums(i, wired):
				any = any or _t(x)
			return {"Saída": _b(any if id == "ou" else not any)}
		"xou", "xnou":
			var count := 0
			for x in _wired_nums(i, wired):
				if _t(x):
					count += 1
			return {"Saída": _b((count % 2 == 1) if id == "xou" else (count % 2 == 0))}
		"nao":
			return {"Saída": _b(not _t(i["A"]))}
		# Aritmética
		"soma":
			return {"Saída": i["A"] + i["B"] + i["C"] + i["D"]}
		"subtrai":
			return {"Saída": i["A"] - i["B"]}
		"multiplica":
			var vals := _wired_nums(i, wired)
			var p := 1.0 if not vals.is_empty() else 0.0
			for x in vals:
				p *= x
			return {"Saída": p}
		"divide":
			return {"Saída": 0.0 if is_zero_approx(i["B"]) else i["A"] / i["B"]}
		"resto":
			return {"Saída": 0.0 if is_zero_approx(i["B"]) else fmod(i["A"], i["B"])}
		"potencia":
			var pw := pow(i["A"], i["B"])
			return {"Saída": pw if is_finite(pw) else 0.0}
		"raiz":
			return {"Saída": sqrt(maxf(i["A"], 0.0))}
		"absoluto":
			return {"Saída": absf(i["A"])}
		"negar":
			return {"Saída": -i["A"]}
		"inverso":
			return {"Saída": 0.0 if is_zero_approx(i["A"]) else 1.0 / i["A"]}
		"arredonda":
			var m := pow(10.0, clampf(roundf(i["Casas"]), 0.0, 10.0))
			return {"Saída": roundf(i["A"] * m) / m}
		"piso":
			return {"Saída": floorf(i["A"])}
		"teto":
			return {"Saída": ceilf(i["A"])}
		"sinal":
			return {"Saída": signf(i["A"])}
		"minimo", "maximo", "media":
			var vals := _wired_nums(i, wired)
			if vals.is_empty():
				return {"Saída": 0.0}
			if id == "minimo":
				return {"Saída": vals.min()}
			if id == "maximo":
				return {"Saída": vals.max()}
			var total := 0.0
			for x in vals:
				total += x
			return {"Saída": total / vals.size()}
		"limita":
			return {"Saída": clampf(i["Valor"], minf(i["Mín"], i["Máx"]), maxf(i["Mín"], i["Máx"]))}
		"remapeia":
			var span: float = i["De máx"] - i["De mín"]
			if is_zero_approx(span):
				return {"Saída": i["Para mín"]}
			return {"Saída": i["Para mín"] + (i["Valor"] - i["De mín"]) / span * (i["Para máx"] - i["Para mín"])}
		"porcentagem":
			return {"Saída": 0.0 if is_zero_approx(i["Máx"]) else i["Valor"] / i["Máx"] * 100.0}
		"aleatorio":
			return {"Saída": randf_range(minf(i["Mín"], i["Máx"]), maxf(i["Mín"], i["Máx"]))}
		"log":
			return {"Saída": log(i["A"]) if i["A"] > 0.0 else 0.0}
		"exp":
			var e := exp(clampf(i["A"], -700.0, 700.0))
			return {"Saída": e if is_finite(e) else 0.0}
		"pi":
			return {"Saída": PI}
		"delta":
			var prev: float = state.get("prev", i["A"])
			state["prev"] = i["A"]
			return {"Saída": i["A"] - prev}
		# Comparação
		"igual":
			return {"Saída": _b(is_equal_approx(i["A"], i["B"]))}
		"diferente":
			return {"Saída": _b(not is_equal_approx(i["A"], i["B"]))}
		"menor":
			return {"Saída": _b(i["A"] < i["B"])}
		"maior":
			return {"Saída": _b(i["A"] > i["B"])}
		"menor_igual":
			return {"Saída": _b(i["A"] <= i["B"])}
		"maior_igual":
			return {"Saída": _b(i["A"] >= i["B"])}
		"na_faixa":
			return {"Saída": _b(i["Valor"] >= i["Mín"] and i["Valor"] <= i["Máx"])}
		# Memória
		"latch":
			if _rising(state, "clk", i["Clk"]):
				state["v"] = i["Dado"]
			return {"Saída": state.get("v", 0.0)}
		"d_latch":
			if _t(i["Clk"]):
				state["v"] = i["Dado"]
			return {"Saída": state.get("v", 0.0)}
		"sr_latch":
			if _t(i["Desligar"]):
				state["v"] = 0.0
			elif _t(i["Ligar"]):
				state["v"] = 1.0
			return {"Saída": state.get("v", 0.0)}
		"alternador":
			if _rising(state, "clk", i["Clk"]):
				state["on"] = not state.get("on", false)
			var on_v: float = i["Ligado"] if wired.has("Ligado") else 1.0
			var off_v: float = i["Desligado"]
			return {"Saída": on_v if state.get("on", false) else off_v}
		"contador":
			var c: float = state.get("v", 0.0)
			if _rising(state, "up", i["Somar"]):
				c += 1.0
			if _rising(state, "down", i["Subtrair"]):
				c -= 1.0
			if _t(i["Zerar"]):
				c = 0.0
			state["v"] = c
			return {"Valor": c}
		"ram":
			var cells: Array = state.get("cells", [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
			if _t(i["Zerar"]):
				cells = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
			elif _t(i["Gravar"]):
				var wa := int(roundf(i["Escrever em"]))
				if wa >= 0 and wa < 8:
					cells[wa] = i["Dado"]
			state["cells"] = cells
			var ra := int(roundf(i["Ler"]))
			return {"Lido": cells[ra] if ra >= 0 and ra < 8 else 0.0}
		# Seleção
		"se":
			return {"Saída": i["Então"] if _t(i["Condição"]) else i["Senão"]}
		"seleciona":
			var k := int(roundf(i["Escolha"]))
			return {"Saída": i[["A", "B", "C", "D"][k - 1]] if k >= 1 and k <= 4 else 0.0}
		"roteia":
			var path := int(roundf(i["Caminho"]))
			var o := {"A": 0.0, "B": 0.0, "C": 0.0, "D": 0.0}
			if path >= 1 and path <= 4:
				o[["A", "B", "C", "D"][path - 1]] = i["Dado"]
			return o
		# Tempo ("Rodar" sem fio = sempre rodando)
		"temporizador":
			var run_t := not wired.has("Rodar") or _t(i["Rodar"])
			var tm: float = state.get("t", 0.0)
			if _t(i["Zerar"]):
				tm = 0.0
			elif run_t:
				tm += dt
			state["t"] = tm
			return {"Tempo": tm}
		"pulsador":
			if wired.has("Rodar") and not _t(i["Rodar"]):
				state["t"] = 0.0
				return {"Pulso": 0.0}
			var interval: float = i["Intervalo"] if wired.has("Intervalo") and i["Intervalo"] > 0.0 else 1.0
			var acc: float = state.get("t", 0.0) + dt
			var pulse := 0.0
			if acc >= interval - 1e-6:
				acc -= interval
				pulse = 1.0
			state["t"] = acc
			return {"Pulso": pulse}
		"onda":
			if wired.has("Rodar") and not _t(i["Rodar"]):
				state["t"] = 0.0
				return {"Saída": 0.0}
			var on_t: float = i["Ligado (s)"] if wired.has("Ligado (s)") and i["Ligado (s)"] > 0.0 else 0.5
			var off_t: float = i["Desligado (s)"] if wired.has("Desligado (s)") and i["Desligado (s)"] > 0.0 else 0.5
			var ph: float = state.get("t", 0.0)
			var nxt := ph + dt
			if nxt >= on_t + off_t - 1e-6:      # virou o ciclo (com margem para arredondamento)
				nxt = maxf(nxt - (on_t + off_t), 0.0)
				if nxt < 1e-6:
					nxt = 0.0
			state["t"] = nxt
			return {"Saída": _b(ph < on_t - 1e-6)}
		"monoestavel":
			var dur: float = i["Tempo"] if wired.has("Tempo") and i["Tempo"] > 0.0 else 1.0
			if _rising(state, "trig", i["Disparar"]):
				state["left"] = dur
			var left: float = state.get("left", 0.0)
			var on_now := left > 1e-6
			state["left"] = maxf(left - dt, 0.0)
			return {"Saída": _b(on_now)}
		"atraso":
			var delay := clampf(i["Tempo"], 0.0, 10.0)
			var buf: Array = state.get("buf", [])
			var now: float = state.get("now", 0.0) + dt
			state["now"] = now
			buf.append([now, i["Entrada"]])
			var outv: float = state.get("out", 0.0)
			while not buf.is_empty() and float(buf[0][0]) <= now - delay + 1e-6:
				outv = float(buf[0][1])
				buf.pop_front()
			state["buf"] = buf
			state["out"] = outv
			return {"Saída": outv}
		"derivada":
			var prev: float = state.get("prev", i["A"])
			state["prev"] = i["A"]
			return {"Saída": (i["A"] - prev) / dt if dt > 0.0 else 0.0}
		"acumulador":
			var acc: float = state.get("v", 0.0)
			if _t(i["Zerar"]):
				acc = 0.0
			elif not _t(i["Pausar"]):
				acc += i["Entrada"] * dt
			state["v"] = acc
			return {"Saída": acc}
		"suaviza":
			var rate: float = i["Taxa"] if wired.has("Taxa") and i["Taxa"] > 0.0 else 1.0
			var cur: float = state.get("v", i["Entrada"])
			cur = move_toward(cur, i["Entrada"], rate * dt)
			state["v"] = cur
			return {"Saída": cur}
		# Trigonometria
		"sen":
			return {"Saída": sin(deg_to_rad(i["Graus"]))}
		"cos":
			return {"Saída": cos(deg_to_rad(i["Graus"]))}
		"tan":
			var tn := tan(deg_to_rad(i["Graus"]))
			return {"Saída": tn if is_finite(tn) else 0.0}
		"asen":
			return {"Saída": rad_to_deg(asin(clampf(i["A"], -1.0, 1.0)))}
		"acos":
			return {"Saída": rad_to_deg(acos(clampf(i["A"], -1.0, 1.0)))}
		"atan":
			return {"Saída": rad_to_deg(atan(i["A"]))}
		"atan2":
			return {"Saída": rad_to_deg(atan2(i["Y"], i["X"]))}
		"graus_rad":
			return {"Saída": deg_to_rad(i["A"])}
		"rad_graus":
			return {"Saída": rad_to_deg(i["A"])}
		"dif_angulo":
			return {"Saída": wrapf(i["A"] - i["B"], -180.0, 180.0)}
		# Bits
		"bit_e":
			return {"Saída": float(int(i["A"]) & int(i["B"]))}
		"bit_ou":
			return {"Saída": float(int(i["A"]) | int(i["B"]))}
		"bit_xou":
			return {"Saída": float(int(i["A"]) ^ int(i["B"]))}
		"bit_nao":
			return {"Saída": float(~int(i["A"]))}
		"bit_esq":
			return {"Saída": float(int(i["A"]) << clampi(int(i["B"]), 0, 62))}
		"bit_dir":
			return {"Saída": float(int(i["A"]) >> clampi(int(i["B"]), 0, 62))}
		# Vetor
		"compor":
			return {"Vetor": Vector3(i["X"], i["Y"], i["Z"])}
		"decompor":
			var vv: Vector3 = i["Vetor"]
			return {"X": vv.x, "Y": vv.y, "Z": vv.z}
		"vet_soma":
			return {"Vetor": (i["A"] as Vector3) + (i["B"] as Vector3)}
		"vet_sub":
			return {"Vetor": (i["A"] as Vector3) - (i["B"] as Vector3)}
		"vet_escala":
			return {"Vetor": (i["Vetor"] as Vector3) * float(i["Número"])}
		"comprimento":
			return {"Saída": (i["Vetor"] as Vector3).length()}
		"normalizar":
			return {"Vetor": (i["Vetor"] as Vector3).normalized()}
		"escalar":
			return {"Saída": (i["A"] as Vector3).dot(i["B"])}
		"vetorial":
			return {"Vetor": (i["A"] as Vector3).cross(i["B"])}
		"distancia":
			return {"Saída": (i["A"] as Vector3).distance_to(i["B"])}
		# Texto
		"juntar":
			return {"Texto": str(i["A"]) + str(i["B"]) + str(i["C"]) + str(i["D"])}
		"num_texto":
			var places := clampi(int(roundf(i["Casas"])), 0, 10)
			return {"Texto": ("%." + str(places) + "f") % i["Número"]}
		"texto_num":
			var txt := str(i["Texto"]).strip_edges().replace(",", ".")
			return {"Saída": txt.to_float() if txt.is_valid_float() else 0.0}
		"tamanho":
			return {"Saída": float(str(i["Texto"]).length())}
		"maiusculas":
			return {"Texto": str(i["Texto"]).to_upper()}
		"texto_igual":
			return {"Saída": _b(str(i["A"]) == str(i["B"]))}
	return {}
