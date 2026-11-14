class_name WalletService
extends RefCounted
## Состояние кошелька игрока (чистая модель без сцен и UI).


var coins: int = 20


func add(amount: int) -> void:
	coins = maxi(0, coins + amount)


func spend(amount: int) -> bool:
	if coins >= amount:
		coins -= amount
		return true
	return false


func has(amount: int) -> bool:
	return coins >= amount
