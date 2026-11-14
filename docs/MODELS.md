# Библиотека 3D-реквизита (v2.3)

58 low-poly моделей в `assets/models/*.glb` — **оригинальные**, созданы кодом (`tools/modelkit.py`, `tools/gen_models.py`),
около 12 тыс. треугольников на всю библиотеку, ~760 КБ. Фасетное освещение (плоские нормали), цвета в вершинах,
4 материала: matte / metal / glow / cloth. Контрольные листы: `docs/preview/props_1.png`, `props_2.png`.

Модели: barrel, crate, sack, basket(_veg/_apples/_bread), bottle_green/red/blue/amber/purple, jar_clay, jar_glass, mug, bowl,
plate, jug, candle, flame, lantern, stool, chair, table_round, table_round_cloth, table_long, shelf, bucket, broom, bread,
cheese, ham, steak, tomato, cabbage, pumpkin, carrot_bunch, onion, mushroom(s), fish, herb_bundle, cauldron, cauldron_gold,
ladle, pot_hang, pan, logs, hearth_stone, rock, wreath, picture_a/b, banner, plant, chandelier, door, hearth_arch.

## Как заменить модель на свою (например, из бесплатных паков CC0 — Kenney, Quaternius)
1. Экспортируйте модель в `.glb`, начало координат — у основания, масштаб — метры, Y вверх.
2. Положите в `assets/models/` с тем же именем (например, `barrel.glb`) — файл заменит встроенный.
3. Откройте проект в Godot (импорт произойдёт автоматически). `Props.gd` подхватит модель.
Если у модели есть свои материалы/текстуры — они сохранятся; цвета вершин применяются только если они есть в файле.

## Если модель не найдена
`Props.place()` ставит пурпурный куб-заглушку и пишет предупреждение; при старте игры показывается уведомление
«Не найдено моделей: N». Обычно это значит, что проект ещё не импортирован (откройте его в редакторе).

## Перегенерация
`python3 tools/gen_models.py` (нужны numpy и Pillow) пересоздаёт все `.glb` и листы превью.
