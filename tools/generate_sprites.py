"""PeaceEnd sprite generator — uses ComfyUI API directly on port 8000.

Usage:
  python generate_sprites.py --task all       # Generate all sprites
  python generate_sprites.py --task 1         # Generate task 1 (background)
  python generate_sprites.py --task 1 --seed 42  # Specific seed
  python generate_sprites.py --list           # List all tasks
"""

import argparse
import copy
import json
import os
import shutil
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from datetime import datetime
from pathlib import Path

# === Config ===
COMFYUI_URL = "http://127.0.0.1:8000"
CHECKPOINT = "autismmixSDXL_autismmixConfetti.safetensors"
LORA = "pixel-art-xl-v1.1.safetensors"
LORA_STRENGTH_MODEL = 0.9
LORA_STRENGTH_CLIP = 0.9
SAMPLER = "euler_ancestral"
SCHEDULER = "normal"
STEPS = 35
CFG = 7.5

OUTPUT_DIR = Path(__file__).parent.parent / "assets" / "sprites"
VARIANTS_DIR = Path(__file__).parent / "variants"

# === Base prompts ===
BASE_POSITIVE = "masterpiece, best quality, pixel art, pixel art style, 16-bit, retro game sprite, clean pixels, sharp edges, flat colors, no anti-aliasing, game asset"
BASE_NEGATIVE = "worst quality, low quality, blurry, 3d render, photorealistic, photograph, painting, watercolor, sketch, noise, jpeg artifacts, text, watermark, signature, logo, gradient, smooth shading, anti-aliased, soft edges, nsfw, nude, naked, sexual, breasts, 1girl, 1boy, anime girl, pony, horse, animal"

# === Workflow templates ===
TEMPLATE_TXT2IMG = {
    "checkpoint_loader": {
        "class_type": "CheckpointLoaderSimple",
        "inputs": {"ckpt_name": "PLACEHOLDER"}
    },
    "lora_loader": {
        "class_type": "LoraLoader",
        "inputs": {
            "model": ["checkpoint_loader", 0],
            "clip": ["checkpoint_loader", 1],
            "lora_name": "PLACEHOLDER",
            "strength_model": 0.7,
            "strength_clip": 0.7
        }
    },
    "positive_prompt": {
        "class_type": "CLIPTextEncode",
        "inputs": {"clip": ["lora_loader", 1], "text": "PLACEHOLDER"}
    },
    "negative_prompt": {
        "class_type": "CLIPTextEncode",
        "inputs": {"clip": ["lora_loader", 1], "text": "PLACEHOLDER"}
    },
    "empty_latent": {
        "class_type": "EmptyLatentImage",
        "inputs": {"width": 1024, "height": 1024, "batch_size": 1}
    },
    "sampler": {
        "class_type": "KSampler",
        "inputs": {
            "model": ["lora_loader", 0],
            "positive": ["positive_prompt", 0],
            "negative": ["negative_prompt", 0],
            "latent_image": ["empty_latent", 0],
            "seed": 0, "steps": 35, "cfg": 7.5,
            "sampler_name": "euler_ancestral",
            "scheduler": "normal", "denoise": 1.0
        }
    },
    "vae_decode": {
        "class_type": "VAEDecode",
        "inputs": {"samples": ["sampler", 0], "vae": ["checkpoint_loader", 2]}
    },
    "save_image": {
        "class_type": "SaveImage",
        "inputs": {"images": ["vae_decode", 0], "filename_prefix": "PeaceEnd"}
    }
}

TEMPLATE_TXT2IMG_REMBG = copy.deepcopy(TEMPLATE_TXT2IMG)
TEMPLATE_TXT2IMG_REMBG["rembg"] = {
    "class_type": "Image Remove Background (rembg)",
    "inputs": {"image": ["vae_decode", 0]}
}
TEMPLATE_TXT2IMG_REMBG["save_image"]["inputs"]["images"] = ["rembg", 0]


# === Sprite tasks ===
TASKS = {
    1: {
        "name": "background_battlefield",
        "description": "Battlefield background (landscape)",
        "positive": f"{BASE_POSITIVE}, landscape, scenery, no humans, outdoors, 2D side-scrolling game background, battlefield, war-torn field, trenches, brown dirt, green grass, overcast sky, ruins on horizon, barbed wire, bomb craters, horizontal tiling background, parallax layer, environment art, nobody",
        "negative": f"{BASE_NEGATIVE}, person, character, human, figure, soldier, girl, boy, woman, man, face, body, 1girl, 1boy, breasts, nude, naked",
        "width": 1216, "height": 832,
        "rembg": False,
        "seeds": [42, 123, 777],
    },
    2: {
        "name": "mortar",
        "description": "Military cannon turret (side view)",
        "positive": f"{BASE_POSITIVE}, cannon, artillery turret, war machine, military green cannon on wheels, barrel pointing diagonally up, metal machine, weapon turret, iron sights, no humans, object, game weapon sprite, side view, white background, centered, simple design",
        "negative": f"{BASE_NEGATIVE}, person, character, human, soldier, robot, mech, mecha, legs, arms, face, eyes, multiple objects",
        "width": 832, "height": 832,
        "rembg": True,
        "seeds": [42, 256, 999, 111, 555],
    },
    3: {
        "name": "shell",
        "description": "Missile/rocket projectile",
        "positive": f"{BASE_POSITIVE}, missile, rocket projectile, flying bomb, red and grey warhead, fins, flames from exhaust, trail, weapon projectile in flight, game projectile sprite, horizontal, side view, white background, simple",
        "negative": f"{BASE_NEGATIVE}, person, character, human, gun, scene, landscape, multiple objects",
        "width": 512, "height": 512,
        "rembg": True,
        "seeds": [42, 128, 500, 333, 888],
    },
    4: {
        "name": "explosion",
        "description": "Explosion VFX sprite",
        "positive": f"{BASE_POSITIVE}, explosion sprite, fiery blast, orange and red flames, smoke cloud, shockwave circle, game explosion effect, VFX sprite, single object, white background, centered",
        "negative": f"{BASE_NEGATIVE}, person, character, scene, background, landscape",
        "width": 512, "height": 512,
        "rembg": True,
        "seeds": [42, 200, 600],
    },
    5: {
        "name": "infantry",
        "description": "Soldier walking right (side view)",
        "positive": f"{BASE_POSITIVE}, modern soldier walking right, side view profile, military uniform green camouflage, helmet, assault rifle in hands, combat boots, full body, game character sprite, single character, white background",
        "negative": f"{BASE_NEGATIVE}, multiple characters, face detail, scene, background",
        "width": 832, "height": 832,
        "rembg": True,
        "seeds": [42, 300, 700],
    },
    6: {
        "name": "enemy_trench",
        "description": "Sandbag wall fortification",
        "positive": f"{BASE_POSITIVE}, wooden crate, barrel, sandbags, military supplies, ammunition box, stacked crates and barrels, brown and green colors, no humans, game item sprite, game prop, RPG loot pile, side view, white background, centered",
        "negative": f"{BASE_NEGATIVE}, person, character, human, soldier, face, eyes, arms, legs, robot, mech, building, house, landscape",
        "width": 832, "height": 832,
        "rembg": False,
        "seeds": [42, 150, 800, 444, 666, 123, 321],
    },
    7: {
        "name": "enemy_bunker",
        "description": "Concrete bunker building",
        "positive": f"{BASE_POSITIVE}, concrete bunker, military fortress, grey stone building, small windows, thick walls, reinforced door, flat roof, military architecture, no humans, game building sprite, side view, white background, centered",
        "negative": f"{BASE_NEGATIVE}, person, character, human, soldier, face, eyes, arms, legs, robot, mech, landscape",
        "width": 832, "height": 832,
        "rembg": True,
        "seeds": [42, 350, 900, 222, 777],
    },
    8: {
        "name": "player_base",
        "description": "Green military base building",
        "positive": f"{BASE_POSITIVE}, military headquarters building, green army barracks, small house with antenna, sandbags around, flag on roof, wooden and metal construction, no humans, game building sprite, side view, white background, centered",
        "negative": f"{BASE_NEGATIVE}, person, character, human, soldier, face, eyes, arms, legs, robot, mech",
        "width": 832, "height": 832,
        "rembg": True,
        "seeds": [42, 100, 250],
    },
    9: {
        "name": "enemy_base",
        "description": "Red enemy base building",
        "positive": f"{BASE_POSITIVE}, enemy military base, hostile red headquarters, dark building, red and black colors, iron walls, watchtower, barbed wire fence, menacing fortress, no humans, game building sprite, side view, white background, centered",
        "negative": f"{BASE_NEGATIVE}, person, character, human, soldier, face, eyes, arms, legs, robot, mech",
        "width": 832, "height": 832,
        "rembg": True,
        "seeds": [42, 100, 250],
    },
}


def build_workflow(task: dict, seed: int) -> dict:
    """Build a ComfyUI workflow for a sprite generation task."""
    template = TEMPLATE_TXT2IMG_REMBG if task["rembg"] else TEMPLATE_TXT2IMG
    wf = copy.deepcopy(template)

    wf["checkpoint_loader"]["inputs"]["ckpt_name"] = CHECKPOINT
    wf["lora_loader"]["inputs"]["lora_name"] = LORA
    wf["lora_loader"]["inputs"]["strength_model"] = LORA_STRENGTH_MODEL
    wf["lora_loader"]["inputs"]["strength_clip"] = LORA_STRENGTH_CLIP
    wf["positive_prompt"]["inputs"]["text"] = task["positive"]
    wf["negative_prompt"]["inputs"]["text"] = task["negative"]
    wf["empty_latent"]["inputs"]["width"] = task["width"]
    wf["empty_latent"]["inputs"]["height"] = task["height"]
    wf["sampler"]["inputs"]["seed"] = seed
    wf["sampler"]["inputs"]["steps"] = STEPS
    wf["sampler"]["inputs"]["cfg"] = CFG
    wf["sampler"]["inputs"]["sampler_name"] = SAMPLER
    wf["sampler"]["inputs"]["scheduler"] = SCHEDULER
    wf["save_image"]["inputs"]["filename_prefix"] = f"PeaceEnd_{task['name']}"

    return wf


def submit_workflow(workflow: dict) -> str | None:
    """Submit workflow to ComfyUI. Returns prompt_id."""
    client_id = str(uuid.uuid4())
    payload = json.dumps({"prompt": workflow, "client_id": client_id}).encode()
    req = urllib.request.Request(
        f"{COMFYUI_URL}/prompt",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read())
            return data.get("prompt_id")
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(f"  ERROR: HTTP {e.code}: {body}", file=sys.stderr)
        return None
    except (urllib.error.URLError, OSError) as e:
        print(f"  ERROR: {e}", file=sys.stderr)
        return None


def poll_history(prompt_id: str, timeout: float = 300.0) -> dict | None:
    """Poll /history until generation completes."""
    start = time.time()
    while time.time() - start < timeout:
        try:
            url = f"{COMFYUI_URL}/history/{prompt_id}"
            with urllib.request.urlopen(urllib.request.Request(url), timeout=10) as resp:
                data = json.loads(resp.read())
                if prompt_id in data:
                    return data[prompt_id]
        except (urllib.error.URLError, OSError, TimeoutError):
            pass
        time.sleep(2)
    return None


def download_image(filename: str, subfolder: str = "", img_type: str = "output") -> bytes:
    """Download generated image from ComfyUI."""
    params = urllib.parse.urlencode({"filename": filename, "subfolder": subfolder, "type": img_type})
    url = f"{COMFYUI_URL}/view?{params}"
    with urllib.request.urlopen(urllib.request.Request(url), timeout=30) as resp:
        return resp.read()


def generate_sprite(task_id: int, seed: int) -> str | None:
    """Generate a single sprite variant. Returns local file path or None."""
    task = TASKS[task_id]
    wf = build_workflow(task, seed)

    print(f"  Submitting seed={seed}...", end=" ", flush=True)
    prompt_id = submit_workflow(wf)
    if not prompt_id:
        print("FAILED (submit)")
        return None

    print(f"id={prompt_id[:8]}...", end=" ", flush=True)
    history = poll_history(prompt_id)
    if not history:
        print("FAILED (timeout)")
        return None

    # Download images
    outputs = history.get("outputs", {})
    for node_id, node_output in outputs.items():
        for img_info in node_output.get("images", []):
            img_data = download_image(
                img_info["filename"],
                img_info.get("subfolder", ""),
                img_info.get("type", "output"),
            )
            # Save variant
            VARIANTS_DIR.mkdir(parents=True, exist_ok=True)
            variant_path = VARIANTS_DIR / f"{task['name']}_seed{seed}.png"
            variant_path.write_bytes(img_data)
            size_kb = len(img_data) / 1024
            print(f"OK ({size_kb:.0f}KB) -> {variant_path.name}")
            return str(variant_path)

    print("FAILED (no images in output)")
    return None


def run_task(task_id: int, specific_seed: int | None = None):
    """Run a full sprite generation task with all seed variants."""
    task = TASKS[task_id]
    seeds = [specific_seed] if specific_seed is not None else task["seeds"]

    print(f"\n{'='*60}")
    print(f"Task {task_id}: {task['description']}")
    print(f"  Output: {task['name']}.png ({task['width']}x{task['height']})")
    print(f"  Rembg: {task['rembg']}")
    print(f"  Seeds: {seeds}")
    print(f"{'='*60}")

    generated = []
    for seed in seeds:
        path = generate_sprite(task_id, seed)
        if path:
            generated.append(path)

    if generated:
        # Use first successful variant as default (user can review and swap)
        OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
        dest = OUTPUT_DIR / f"{task['name']}.png"
        shutil.copy2(generated[0], dest)
        print(f"  -> Copied to {dest}")
        print(f"  ({len(generated)} variant(s) in {VARIANTS_DIR})")
    else:
        print(f"  WARNING: No variants generated for task {task_id}!")

    return generated


def check_comfyui() -> bool:
    """Check if ComfyUI API is reachable."""
    try:
        req = urllib.request.Request(f"{COMFYUI_URL}/system_stats")
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read())
            gpu = data.get("devices", [{}])[0].get("name", "unknown")
            print(f"ComfyUI is running on {gpu}")
            return True
    except (urllib.error.URLError, OSError):
        print(f"ComfyUI not reachable at {COMFYUI_URL}")
        return False


def main():
    parser = argparse.ArgumentParser(description="PeaceEnd Sprite Generator")
    parser.add_argument("--task", type=str, help="Task number (1-9) or 'all'")
    parser.add_argument("--seed", type=int, default=None, help="Specific seed (overrides task seeds)")
    parser.add_argument("--list", action="store_true", help="List all tasks")
    args = parser.parse_args()

    if args.list:
        print("Available sprite generation tasks:")
        for tid, task in TASKS.items():
            seeds_str = ", ".join(str(s) for s in task["seeds"])
            rembg_str = " [rembg]" if task["rembg"] else ""
            print(f"  {tid}. {task['description']:40s} {task['width']}x{task['height']}{rembg_str}  seeds: {seeds_str}")
        return

    if not args.task:
        parser.error("--task is required (1-9 or 'all')")

    if not check_comfyui():
        print("Please start ComfyUI first!")
        sys.exit(1)

    start_time = time.time()

    if args.task == "all":
        for task_id in sorted(TASKS.keys()):
            run_task(task_id, args.seed)
    else:
        task_id = int(args.task)
        if task_id not in TASKS:
            print(f"Unknown task {task_id}. Use --list to see available tasks.")
            sys.exit(1)
        run_task(task_id, args.seed)

    elapsed = time.time() - start_time
    print(f"\nDone in {elapsed:.0f}s")
    print(f"Sprites: {OUTPUT_DIR}")
    print(f"Variants: {VARIANTS_DIR}")


if __name__ == "__main__":
    main()
