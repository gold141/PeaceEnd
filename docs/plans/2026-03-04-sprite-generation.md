# PeaceEnd Sprite Generation Plan (ComfyUI)

> **For Claude:** Этот план предназначен для ОТДЕЛЬНОГО чата. Он генерирует все спрайты через ComfyUI пайплайн из проекта WebGirl. Запуск: прочитай этот файл и выполняй шаги по порядку.

**Goal:** Сгенерировать все пиксель-арт спрайты для минимального прототипа игры PeaceEnd (артиллерийская стратегия, вид сбоку).

**Инструменты:** ComfyUI API через `E:\YandexDisk\Programs\WebGirl\tools\comfyui_bridge.py`

**Модели:**
- Checkpoint: `ponyDiffusionV6XL_v6StartWithThisOne.safetensors`
- LoRA для пиксель-арта: `pixel-art-xl-v1.1.safetensors` (strength: 0.85/0.85)
- Rembg: для удаления фона у юнитов

**Выходная директория:** `E:\YandexDisk\Programs\Games\PeaceEnd\assets\sprites\`

**Python venv:** `C:\Users\HOME\Documents\ComfyUI\.venv\Scripts\python.exe`

---

## Общие параметры генерации

Для ВСЕХ спрайтов используй эти общие настройки:

```
checkpoint: ponyDiffusionV6XL_v6StartWithThisOne.safetensors
lora: pixel-art-xl-v1.1.safetensors (strength_model=0.85, strength_clip=0.85)
sampler: euler_ancestral
scheduler: normal
steps: 35
cfg: 7.5
```

**Базовый negative prompt для всех:**
```
worst quality, low quality, blurry, 3d render, photorealistic, realistic, photograph, painting, watercolor, sketch, noise, jpeg artifacts, text, watermark, signature, logo, gradient, smooth shading, anti-aliased, soft edges
```

**Базовый positive prefix для всех:**
```
score_9, score_8_up, score_7_up, pixel art, pixel art style, 16-bit, retro game sprite, clean pixels, sharp edges, flat colors, no anti-aliasing
```

---

## Предварительный шаг: Проверка ComfyUI

**Step 1: Проверь что ComfyUI запущен**

```bash
cd "E:\YandexDisk\Programs\WebGirl\tools"
"C:\Users\HOME\Documents\ComfyUI\.venv\Scripts\python.exe" comfyui_bridge.py --check
```

Ожидаемый результат: `{"running": true, "gpu": "NVIDIA GeForce RTX 4080 SUPER", ...}`

Если `running: false`:
```bash
"C:\Users\HOME\Documents\ComfyUI\.venv\Scripts\python.exe" comfyui_bridge.py --start --wait
```

**Step 2: Создай выходную директорию**

```bash
mkdir -p "E:\YandexDisk\Programs\Games\PeaceEnd\assets\sprites"
```

---

## Task 1: Фон — поле боя (battlefield background)

Горизонтальный фон с рельефом: холмы, земля, небо. Вид сбоку. Без персонажей.

**Step 1: Сгенерируй фон**

```bash
cd "E:\YandexDisk\Programs\WebGirl\tools"
"C:\Users\HOME\Documents\ComfyUI\.venv\Scripts\python.exe" comfyui_bridge.py --generate \
  --positive "score_9, score_8_up, score_7_up, pixel art, pixel art style, 16-bit, retro game sprite, clean pixels, sharp edges, flat colors, no anti-aliasing, 2D side-scrolling game background, battlefield landscape, modern warfare, rolling hills with trenches, brown earth, green grass patches, cloudy sky, distant city ruins on horizon, barbed wire, craters, side view, horizontal composition, game background layer, no characters, no people" \
  --negative "worst quality, low quality, blurry, 3d render, photorealistic, realistic, photograph, painting, watercolor, sketch, noise, jpeg artifacts, text, watermark, signature, logo, gradient, smooth shading, anti-aliased, soft edges, person, character, human, figure, soldier" \
  --width 1216 --height 832 \
  --seed 42
```

**Step 2: Сгенерируй ещё 2 варианта с другими seed для выбора лучшего**

```bash
"C:\Users\HOME\Documents\ComfyUI\.venv\Scripts\python.exe" comfyui_bridge.py --generate \
  --positive "score_9, score_8_up, score_7_up, pixel art, pixel art style, 16-bit, retro game sprite, clean pixels, sharp edges, flat colors, no anti-aliasing, 2D side-scrolling game background, battlefield landscape, modern warfare, rolling hills with trenches, brown earth, green grass patches, cloudy sky, distant city ruins on horizon, barbed wire, craters, side view, horizontal composition, game background layer, no characters, no people" \
  --negative "worst quality, low quality, blurry, 3d render, photorealistic, realistic, photograph, painting, watercolor, sketch, noise, jpeg artifacts, text, watermark, signature, logo, gradient, smooth shading, anti-aliased, soft edges, person, character, human, figure, soldier" \
  --width 1216 --height 832 \
  --seed 123
```

```bash
"C:\Users\HOME\Documents\ComfyUI\.venv\Scripts\python.exe" comfyui_bridge.py --generate \
  --positive "score_9, score_8_up, score_7_up, pixel art, pixel art style, 16-bit, retro game sprite, clean pixels, sharp edges, flat colors, no anti-aliasing, 2D side-scrolling game background, battlefield landscape, modern warfare, rolling hills with trenches, brown earth, green grass patches, cloudy sky, distant city ruins on horizon, barbed wire, craters, side view, horizontal composition, game background layer, no characters, no people" \
  --negative "worst quality, low quality, blurry, 3d render, photorealistic, realistic, photograph, painting, watercolor, sketch, noise, jpeg artifacts, text, watermark, signature, logo, gradient, smooth shading, anti-aliased, soft edges, person, character, human, figure, soldier" \
  --width 1216 --height 832 \
  --seed 777
```

**Step 3: Скопируй лучший результат**

Выбери лучший из 3 вариантов и скопируй в:
```
E:\YandexDisk\Programs\Games\PeaceEnd\assets\sprites\background_battlefield.png
```

---

## Task 2: Артиллерийское орудие (миномёт)

Миномёт/гаубица, вид сбоку, на прозрачном фоне.

**Step 1: Сгенерируй миномёт**

```bash
cd "E:\YandexDisk\Programs\WebGirl\tools"
"C:\Users\HOME\Documents\ComfyUI\.venv\Scripts\python.exe" comfyui_bridge.py --generate \
  --positive "score_9, score_8_up, score_7_up, pixel art, pixel art style, 16-bit, retro game sprite, clean pixels, sharp edges, flat colors, no anti-aliasing, military mortar weapon, artillery gun, side view, green camouflage color, metal barrel pointing up-right, bipod legs, simple military equipment sprite, single object, game asset, white background, centered" \
  --negative "worst quality, low quality, blurry, 3d render, photorealistic, realistic, photograph, painting, watercolor, sketch, noise, jpeg artifacts, text, watermark, signature, logo, gradient, smooth shading, anti-aliased, soft edges, person, character, human, soldier, multiple objects, scene, background, landscape" \
  --width 832 --height 832 \
  --use-rembg \
  --seed 42
```

**Step 2: Сгенерируй ещё 2 варианта**

```bash
"C:\Users\HOME\Documents\ComfyUI\.venv\Scripts\python.exe" comfyui_bridge.py --generate \
  --positive "score_9, score_8_up, score_7_up, pixel art, pixel art style, 16-bit, retro game sprite, clean pixels, sharp edges, flat colors, no anti-aliasing, military mortar weapon, artillery gun, side view, green camouflage color, metal barrel pointing up-right, bipod legs, simple military equipment sprite, single object, game asset, white background, centered" \
  --negative "worst quality, low quality, blurry, 3d render, photorealistic, realistic, photograph, painting, watercolor, sketch, noise, jpeg artifacts, text, watermark, signature, logo, gradient, smooth shading, anti-aliased, soft edges, person, character, human, soldier, multiple objects, scene, background, landscape" \
  --width 832 --height 832 \
  --use-rembg \
  --seed 256
```

```bash
"C:\Users\HOME\Documents\ComfyUI\.venv\Scripts\python.exe" comfyui_bridge.py --generate \
  --positive "score_9, score_8_up, score_7_up, pixel art, pixel art style, 16-bit, retro game sprite, clean pixels, sharp edges, flat colors, no anti-aliasing, military mortar weapon, artillery gun, side view, green camouflage color, metal barrel pointing up-right, bipod legs, simple military equipment sprite, single object, game asset, white background, centered" \
  --negative "worst quality, low quality, blurry, 3d render, photorealistic, realistic, photograph, painting, watercolor, sketch, noise, jpeg artifacts, text, watermark, signature, logo, gradient, smooth shading, anti-aliased, soft edges, person, character, human, soldier, multiple objects, scene, background, landscape" \
  --width 832 --height 832 \
  --use-rembg \
  --seed 999
```

**Step 3: Скопируй лучший в:**
```
E:\YandexDisk\Programs\Games\PeaceEnd\assets\sprites\mortar.png
```

---

## Task 3: Снаряд (shell/projectile)

Маленький артиллерийский снаряд, вид сбоку.

**Step 1: Сгенерируй снаряд**

```bash
cd "E:\YandexDisk\Programs\WebGirl\tools"
"C:\Users\HOME\Documents\ComfyUI\.venv\Scripts\python.exe" comfyui_bridge.py --generate \
  --positive "score_9, score_8_up, score_7_up, pixel art, pixel art style, 16-bit, retro game sprite, clean pixels, sharp edges, flat colors, no anti-aliasing, artillery shell projectile, mortar round, bullet, small metal cylinder with pointed tip, dark grey metal, single small object, game item sprite, simple, white background, centered, close-up view" \
  --negative "worst quality, low quality, blurry, 3d render, photorealistic, realistic, photograph, painting, watercolor, sketch, noise, jpeg artifacts, text, watermark, signature, logo, gradient, smooth shading, anti-aliased, soft edges, person, character, gun, weapon, scene, background, landscape, large, multiple objects" \
  --width 512 --height 512 \
  --use-rembg \
  --seed 42
```

**Step 2: Ещё 2 варианта (seed 128, 500)**

Аналогично Task 2, меняя --seed.

**Step 3: Скопируй лучший в:**
```
E:\YandexDisk\Programs\Games\PeaceEnd\assets\sprites\shell.png
```

---

## Task 4: Взрыв (explosion)

Спрайт взрыва для момента попадания снаряда.

**Step 1: Сгенерируй взрыв**

```bash
cd "E:\YandexDisk\Programs\WebGirl\tools"
"C:\Users\HOME\Documents\ComfyUI\.venv\Scripts\python.exe" comfyui_bridge.py --generate \
  --positive "score_9, score_8_up, score_7_up, pixel art, pixel art style, 16-bit, retro game sprite, clean pixels, sharp edges, flat colors, no anti-aliasing, explosion sprite, fiery blast, orange and red flames, smoke cloud, shockwave circle, game explosion effect, VFX sprite, single object, white background, centered" \
  --negative "worst quality, low quality, blurry, 3d render, photorealistic, realistic, photograph, painting, watercolor, sketch, noise, jpeg artifacts, text, watermark, signature, logo, gradient, smooth shading, anti-aliased, soft edges, person, character, scene, background, landscape" \
  --width 512 --height 512 \
  --use-rembg \
  --seed 42
```

**Step 2: Ещё 2 варианта (seed 200, 600)**

**Step 3: Скопируй лучший в:**
```
E:\YandexDisk\Programs\Games\PeaceEnd\assets\sprites\explosion.png
```

---

## Task 5: Пехотинец (infantry — walking sprite)

Солдат в форме, вид сбоку, идёт вправо. С автоматом.

**Step 1: Сгенерируй пехотинца**

```bash
cd "E:\YandexDisk\Programs\WebGirl\tools"
"C:\Users\HOME\Documents\ComfyUI\.venv\Scripts\python.exe" comfyui_bridge.py --generate \
  --positive "score_9, score_8_up, score_7_up, pixel art, pixel art style, 16-bit, retro game sprite, clean pixels, sharp edges, flat colors, no anti-aliasing, modern soldier walking right, side view profile, military uniform green camouflage, helmet, assault rifle in hands, combat boots, full body, game character sprite, single character, white background" \
  --negative "worst quality, low quality, blurry, 3d render, photorealistic, realistic, photograph, painting, watercolor, sketch, noise, jpeg artifacts, text, watermark, signature, logo, gradient, smooth shading, anti-aliased, soft edges, multiple characters, face detail, scene, background" \
  --width 832 --height 832 \
  --use-rembg \
  --seed 42
```

**Step 2: Ещё 2 варианта (seed 300, 700)**

**Step 3: Скопируй лучший в:**
```
E:\YandexDisk\Programs\Games\PeaceEnd\assets\sprites\infantry.png
```

---

## Task 6: Вражеский окоп (enemy trench)

Окоп с мешками песка, вид сбоку.

**Step 1: Сгенерируй окоп**

```bash
cd "E:\YandexDisk\Programs\WebGirl\tools"
"C:\Users\HOME\Documents\ComfyUI\.venv\Scripts\python.exe" comfyui_bridge.py --generate \
  --positive "score_9, score_8_up, score_7_up, pixel art, pixel art style, 16-bit, retro game sprite, clean pixels, sharp edges, flat colors, no anti-aliasing, military trench fortification, sandbag wall, dirt dugout, barbed wire on top, side view, game obstacle sprite, defense structure, brown earth tones, single structure, white background" \
  --negative "worst quality, low quality, blurry, 3d render, photorealistic, realistic, photograph, painting, watercolor, sketch, noise, jpeg artifacts, text, watermark, signature, logo, gradient, smooth shading, anti-aliased, soft edges, person, character, soldier, scene, landscape" \
  --width 832 --height 832 \
  --use-rembg \
  --seed 42
```

**Step 2: Ещё 2 варианта (seed 150, 800)**

**Step 3: Скопируй лучший в:**
```
E:\YandexDisk\Programs\Games\PeaceEnd\assets\sprites\enemy_trench.png
```

---

## Task 7: Бункер (enemy bunker)

Бетонный бункер, вид сбоку.

**Step 1: Сгенерируй бункер**

```bash
cd "E:\YandexDisk\Programs\WebGirl\tools"
"C:\Users\HOME\Documents\ComfyUI\.venv\Scripts\python.exe" comfyui_bridge.py --generate \
  --positive "score_9, score_8_up, score_7_up, pixel art, pixel art style, 16-bit, retro game sprite, clean pixels, sharp edges, flat colors, no anti-aliasing, concrete military bunker, fortified pillbox, thick grey walls, small gun slit window, reinforced roof, side view, game building sprite, single structure, white background" \
  --negative "worst quality, low quality, blurry, 3d render, photorealistic, realistic, photograph, painting, watercolor, sketch, noise, jpeg artifacts, text, watermark, signature, logo, gradient, smooth shading, anti-aliased, soft edges, person, character, soldier, scene, landscape, multiple buildings" \
  --width 832 --height 832 \
  --use-rembg \
  --seed 42
```

**Step 2: Ещё 2 варианта (seed 350, 900)**

**Step 3: Скопируй лучший в:**
```
E:\YandexDisk\Programs\Games\PeaceEnd\assets\sprites\enemy_bunker.png
```

---

## Task 8: Базы (player base и enemy base)

**Step 1: База игрока (зелёная/союзная)**

```bash
cd "E:\YandexDisk\Programs\WebGirl\tools"
"C:\Users\HOME\Documents\ComfyUI\.venv\Scripts\python.exe" comfyui_bridge.py --generate \
  --positive "score_9, score_8_up, score_7_up, pixel art, pixel art style, 16-bit, retro game sprite, clean pixels, sharp edges, flat colors, no anti-aliasing, military command post building, green army base, antenna on roof, sandbag perimeter, flag on top, side view, game building sprite, friendly base, single structure, white background" \
  --negative "worst quality, low quality, blurry, 3d render, photorealistic, realistic, photograph, painting, watercolor, sketch, noise, jpeg artifacts, text, watermark, signature, logo, gradient, smooth shading, anti-aliased, soft edges, person, character, soldier, scene, landscape" \
  --width 832 --height 832 \
  --use-rembg \
  --seed 42
```

Скопируй лучший в: `assets/sprites/player_base.png`

**Step 2: База врага (красная/вражеская)**

```bash
"C:\Users\HOME\Documents\ComfyUI\.venv\Scripts\python.exe" comfyui_bridge.py --generate \
  --positive "score_9, score_8_up, score_7_up, pixel art, pixel art style, 16-bit, retro game sprite, clean pixels, sharp edges, flat colors, no anti-aliasing, military enemy headquarters building, red army hostile base, dark colors, antenna on roof, barricades, side view, game building sprite, enemy base, single structure, white background, menacing" \
  --negative "worst quality, low quality, blurry, 3d render, photorealistic, realistic, photograph, painting, watercolor, sketch, noise, jpeg artifacts, text, watermark, signature, logo, gradient, smooth shading, anti-aliased, soft edges, person, character, soldier, scene, landscape" \
  --width 832 --height 832 \
  --use-rembg \
  --seed 42
```

Скопируй лучший в: `assets/sprites/enemy_base.png`

---

## Финальная проверка

После генерации всех спрайтов, проверь что все файлы на месте:

```bash
ls -la "E:\YandexDisk\Programs\Games\PeaceEnd\assets\sprites\"
```

Ожидаемые файлы:
```
background_battlefield.png   — ~1216x832, фон поля боя
mortar.png                   — ~832x832, миномёт (прозрачный фон)
shell.png                    — ~512x512, снаряд (прозрачный фон)
explosion.png                — ~512x512, взрыв (прозрачный фон)
infantry.png                 — ~832x832, пехотинец (прозрачный фон)
enemy_trench.png             — ~832x832, окоп (прозрачный фон)
enemy_bunker.png             — ~832x832, бункер (прозрачный фон)
player_base.png              — ~832x832, база игрока (прозрачный фон)
enemy_base.png               — ~832x832, база врага (прозрачный фон)
```

## Пост-обработка (опционально)

Для более чёткого пиксельного вида можно применить пост-обработку:
1. Уменьшить изображение в 4 раза (LANCZOS)
2. Увеличить обратно в 4 раза (NEAREST NEIGHBOR)

Это сделает пиксели более крупными и чёткими.

Скрипт можно найти в `E:\YandexDisk\Programs\WebGirl\tools\gen_room.py` — там есть аналогичная пост-обработка.
