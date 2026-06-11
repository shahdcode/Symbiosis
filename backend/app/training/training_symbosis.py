# ==============================================================================
#  SYMBIOSIS — Training Script for Google Colab
#  Run this entire file in Colab (Runtime > Run all)
# ==============================================================================

# ── Step 1: Mount Drive and clone/upload your repo ────────────────────────────
# If running from Colab, upload your backend/ folder or clone from GitHub.
# Uncomment the relevant block:

# Option A — Upload a zip of your backend folder:
# from google.colab import files
# uploaded = files.upload()   # upload backend.zip
# import zipfile; zipfile.ZipFile('backend.zip').extractall('.')

# Option B — Clone from GitHub (replace with your repo URL):
# !git clone https://github.com/YOUR_USERNAME/symbiosis.git
# %cd symbiosis

# ── Step 2: Install dependencies ─────────────────────────────────────────────
import subprocess, sys

def pip(*args):
    subprocess.check_call([sys.executable, "-m", "pip", "install", "-q", *args])

pip("stable-baselines3[extra]>=2.2.0")
pip("gymnasium>=0.29.1")
pip("numpy>=1.26.0")
pip("pandas")
pip("matplotlib")
pip("torch>=2.0.0")

# ── Step 3: Paste the updated SymbiosisEnv here ───────────────────────────────
# (Copy the full SymbiosisEnv class from Change 5 above)
import math
import numpy as np
import gymnasium as gym
from stable_baselines3 import A2C
from stable_baselines3.common.env_util import make_vec_env
from stable_baselines3.common.callbacks import CheckpointCallback, EvalCallback
from stable_baselines3.common.monitor import Monitor
import os, torch

# --- Paste SymbiosisEnv class here ---
# (copy the full class from Change 5)

# ── Step 4: Generate synthetic data ──────────────────────────────────────────
# (Paste the generate_synthetic_data.py content here, then call:)
# ga_sa_cycles = generate_14_day_dataset(policy="ga_sa")
# write_csv(ga_sa_cycles, "/content/ga_sa_training.csv")

# ── Step 5: Train A2C ─────────────────────────────────────────────────────────

SAVE_DIR = "/content/models"
os.makedirs(SAVE_DIR, exist_ok=True)

N_ENVS = 8          # T4 GPU — 8 parallel envs is optimal
TIMESTEPS = 200_000  # ~25 min on T4; use 50_000 for a quick 5-min test

env = make_vec_env(
    lambda: SymbiosisEnv(n_plants=2, steps_per_episode=48, day_variety=True),
    n_envs=N_ENVS,
)

eval_env = Monitor(SymbiosisEnv(n_plants=2, steps_per_episode=48, day_variety=False))

model = A2C(
    "MlpPolicy",
    env,
    verbose=1,
    learning_rate=7e-4,
    n_steps=48,
    gamma=0.99,
    gae_lambda=0.95,
    ent_coef=0.01,
    vf_coef=0.5,
    max_grad_norm=0.5,
    policy_kwargs={
        "net_arch": [128, 128],
        "activation_fn": torch.nn.Tanh,
    },
    tensorboard_log=f"{SAVE_DIR}/tensorboard",
)

checkpoint_cb = CheckpointCallback(
    save_freq=10_000,
    save_path=SAVE_DIR,
    name_prefix="a2c_symbiosis",
)

eval_cb = EvalCallback(
    eval_env,
    best_model_save_path=f"{SAVE_DIR}/best",
    log_path=f"{SAVE_DIR}/eval_logs",
    eval_freq=5_000,
    n_eval_episodes=10,
    deterministic=True,
    verbose=1,
)

print(f"Training A2C for {TIMESTEPS:,} timesteps with {N_ENVS} envs...")
model.learn(
    total_timesteps=TIMESTEPS,
    callback=[checkpoint_cb, eval_cb],
    progress_bar=True,
)
model.save(f"{SAVE_DIR}/a2c_symbiosis_final")
print(f"Training complete. Model saved to {SAVE_DIR}/a2c_symbiosis_final.zip")

# ── Step 6: Evaluate the trained model ───────────────────────────────────────

from stable_baselines3 import A2C as LoadedA2C
import pandas as pd

model = LoadedA2C.load(f"{SAVE_DIR}/a2c_symbiosis_final")
eval_env_det = SymbiosisEnv(n_plants=2, steps_per_episode=48, day_variety=False)

all_rewards = []
all_basil_moisture = []
all_coleus_moisture = []

for episode in range(14):   # 14 days
    obs, _ = eval_env_det.reset()
    ep_reward = 0
    for step in range(48):
        action, _ = model.predict(obs, deterministic=True)
        obs, reward, terminated, truncated, info = eval_env_det.step(action)
        ep_reward += reward
        all_basil_moisture.append(info["basil_moisture"])
        all_coleus_moisture.append(info["coleus_moisture"])
        if terminated:
            break
    all_rewards.append(ep_reward / 48)  # avg per step

# Print summary matching PDF Table format
print("\n=== A2C Evaluation (14 Days) ===")
for day, r in enumerate(all_rewards, 1):
    improvement = (r - all_rewards[0]) / max(abs(all_rewards[0]), 1e-9) * 100
    print(f"  Day {day:2d}: avg_reward={r:.3f}  improvement={improvement:+.1f}%")

b_arr = np.array(all_basil_moisture)
c_arr = np.array(all_coleus_moisture)
b_in_range = np.mean((b_arr >= 65*0.75) & (b_arr <= 65*1.20)) * 100
c_in_range = np.mean((c_arr >= 45*0.75) & (c_arr <= 45*1.20)) * 100
print(f"\n  Basil in-range:  {b_in_range:.1f}%")
print(f"  Coleus in-range: {c_in_range:.1f}%")

# ── Step 7: GA-SA hyperparameter sweep (find best population/generations) ─────
# Run this to find optimal GA params for your hardware latency target (<300ms)

import time
import matplotlib.pyplot as plt

def run_ga_sa_sweep():
    """Sweep GA population × generations and measure fitness vs latency."""
    from backend.app.algorithms.metaheuristic_optimizer import optimize_water_allocations

    def dummy_utility(w):
        # Mimics the real utility function shape
        return sum(0.5 * math.sqrt(max(0, w[i])) for i in range(2))

    results = []
    configs = [
        (10, 10), (10, 20), (20, 20), (20, 30), (30, 20), (30, 30), (50, 30),
    ]
    for pop, gen in configs:
        times = []
        scores = []
        for trial in range(10):
            t0 = time.monotonic()
            w, score = optimize_water_allocations(
                n_plants=2,
                water_budget=180.0,
                utility_fn=dummy_utility,
                population_size=pop,
                generations=gen,
            )
            elapsed_ms = (time.monotonic() - t0) * 1000
            times.append(elapsed_ms)
            scores.append(score)
        results.append({
            "population": pop, "generations": gen,
            "avg_latency_ms": np.mean(times),
            "avg_fitness": np.mean(scores),
            "std_fitness": np.std(scores),
        })
        print(f"  pop={pop:3d} gen={gen:3d} → latency={np.mean(times):.1f}ms  fitness={np.mean(scores):.4f}±{np.std(scores):.4f}")

    # Plot
    df = pd.DataFrame(results)
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 4))
    for pop in df["population"].unique():
        sub = df[df["population"] == pop]
        ax1.plot(sub["generations"], sub["avg_latency_ms"], marker="o", label=f"pop={pop}")
        ax2.plot(sub["generations"], sub["avg_fitness"],   marker="o", label=f"pop={pop}")
    ax1.axhline(300, color="red", linestyle="--", label="300ms target")
    ax1.set_xlabel("Generations"); ax1.set_ylabel("Latency (ms)"); ax1.legend(); ax1.set_title("Latency")
    ax2.set_xlabel("Generations"); ax2.set_ylabel("Fitness"); ax2.legend(); ax2.set_title("Fitness")
    plt.tight_layout()
    plt.savefig(f"{SAVE_DIR}/ga_sa_sweep.png", dpi=150)
    plt.show()
    print(f"Sweep plot saved → {SAVE_DIR}/ga_sa_sweep.png")
    return results

# Uncomment to run the sweep:
# sweep_results = run_ga_sa_sweep()

# ── Step 8: Download the model ────────────────────────────────────────────────
from google.colab import files

# Zip the models folder
import shutil
shutil.make_archive("/content/symbiosis_models", "zip", SAVE_DIR)
files.download("/content/symbiosis_models.zip")
print("Downloaded symbiosis_models.zip — copy a2c_symbiosis_final.zip to backend/app/ml/models/")