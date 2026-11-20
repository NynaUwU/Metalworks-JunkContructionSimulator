class_name Weld
extends RefCounted
## Ponto de solda entre duas peças (ou entre uma peça e o chão, se part_b == null).
## A bolinha visual fica presa à part_a.

var part_a: Part
var part_b: Part              ## null = soldado no chão/estrutura fixa do mapa
var local_pos := Vector3.ZERO ## posição na part_a (coordenadas locais)
var ball: MeshInstance3D


func world_pos() -> Vector3:
	return part_a.global_transform * local_pos


func is_ground() -> bool:
	return part_b == null


func other(p: Part) -> Part:
	return part_b if p == part_a else part_a
