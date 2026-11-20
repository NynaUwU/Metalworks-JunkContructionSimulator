class_name Layers
extends RefCounted
## Camadas de colisão usadas no jogo.

const WORLD := 1    ## chão, terreno e estruturas fixas do mapa
const PARTS := 2    ## peças de sucata e montagens
const PLAYER := 4   ## jogador

## O que as ferramentas conseguem "mirar".
const AIM := WORLD | PARTS
