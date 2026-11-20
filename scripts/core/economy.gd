extends Node
## Autoload "Economy": pontos ganhos no reciclador e gastos na loja.
##
## Os pontos são guardados com casas decimais, assim cortar uma peça em pedacinhos
## não rende mais do que reciclá-la inteira.

signal points_changed(total: int)

var _points := 0.0


func reset(start := 0.0) -> void:
	_points = start
	points_changed.emit(points())


## Pontos com as casas decimais (para salvar).
func precise_points() -> float:
	return _points


func points() -> int:
	return floori(_points + 1e-6)


func add(amount: float) -> void:
	_points += amount
	points_changed.emit(points())


func can_afford(price: int) -> bool:
	return points() >= price


func spend(price: int) -> bool:
	if not can_afford(price):
		return false
	_points -= price
	points_changed.emit(points())
	return true


## Quanto o reciclador paga por uma peça (pontos, com casas decimais).
static func recycle_value(material_id: String, mass: float) -> float:
	return mass * MetalMaterials.value_per_kg(material_id)
