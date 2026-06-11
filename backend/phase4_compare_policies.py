"""
Phase 4: Compare GA-SA vs A2C policy on held-out test days 13-14.
Run from backend/ with:
    python phase4_compare_policies.py
"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))

import math
import time
import numpy as np
import pandas as pd
import torch
import torch.nn as nn
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from pathlib import Path
import csv

# Direct import without going through app/__init__.py
import importlib.util

optimizer_path = Path(__file__).parent / "app" / "algorithms" / "metaheuristic_optimizer.py"
spec = importlib.util.spec_from_file_location("metaheuristic_optimizer", optimizer_path)
metaheuristic_optimizer = importlib.util.module_from_spec(spec)
sys.modules["metaheuristic_optimizer"] = metaheuristic_optimizer
spec.loader.exec_module(metaheuristic_optimizer)
optimize_water_allocations = metaheuristic_optimizer.optimize_water_allocations

DATA_PATH = Path("offline_rl_project/data/ga_sa_demonstrations.csv")
MODEL_DIR = Path("offline_rl_project/models")
MODEL_PATH = MODEL_DIR / "a2c_bc_best.pt"  # Use A2C BC model
RESULTS = Path("offline_rl_project/results")
RESULTS.mkdir(parents=True, exist_ok=True)

STATE_DIM = 8
ACTION_DIM = 2
HIDDEN = [256, 256]
TANK_CAP = 5000.0

SPECIES = [
    {"optimal": 65.0, "m_crit": 30.0, "sigma": 16.25, "gamma": 0.031},
    {"optimal": 45.0, "m_crit": 25.0, "sigma": 11.25, "gamma": 0.024},
]

ET_PROFILE = [
    (0, 0.35), (4, 0.28), (6, 0.38), (8, 0.55),
    (10, 0.72), (12, 0.95), (14, 1.05), (16, 0.90),
    (18, 0.62), (20, 0.45), (22, 0.38), (24, 0.35),
]
ENV_PROFILE = [
    (0, 20.0, 66.0, 80),   (4, 19.0, 68.0, 30),
    (6, 20.5, 66.0, 200),  (8, 23.8, 57.3, 2910),
    (10, 25.1, 54.8, 4120), (12, 27.4, 51.2, 5840),
    (14, 26.9, 52.7, 5310), (16, 24.3, 55.9, 2710),
    (18, 22.9, 60.1, 890),  (20, 21.6, 63.7, 210),
    (22, 20.8, 65.0, 90),   (24, 20.1, 66.0, 50),
]


def _interpolate(profile, hour):
    for i in range(len(profile) - 1):
        h0, *v0 = profile[i]
        h1, *v1 = profile[i + 1]
        if h0 <= hour <= h1:
            f = (hour - h0) / (h1 - h0)
            return tuple(v0[j] + f * (v1[j] - v0[j]) for j in range(len(v0)))
    return tuple(profile[-1][1:])


def gaussian_sat(m, sp):
    return math.exp(-0.5 * ((m - sp["optimal"]) / sp["sigma"]) ** 2)


# ── A2C Policy Network (must match phase3) ───────────────────────────────────
class A2CPolicy(nn.Module):
    def __init__(self, state_dim=STATE_DIM, action_dim=ACTION_DIM, hidden=HIDDEN):
        super().__init__()
        layers = []
        prev = state_dim
        for h in hidden:
            layers.append(nn.Linear(prev, h))
            layers.append(nn.ReLU())
            layers.append(nn.Dropout(0.2))
            prev = h
        layers.append(nn.Linear(prev, action_dim))
        layers.append(nn.Sigmoid())
        self.net = nn.Sequential(*layers)
    
    def forward(self, x):
        return self.net(x)


def load_policy(model_path, model_dir):
    """Load the trained A2C policy with normalization parameters."""
    model = A2CPolicy()
    # Add weights_only=False to fix the unpickling error
    ckpt = torch.load(model_path, map_location="cpu", weights_only=False)
    model.load_state_dict(ckpt['model_state_dict'])
    model.eval()
    
    # Load normalization parameters
    state_mean = np.load(model_dir / "state_mean.npy")
    state_std = np.load(model_dir / "state_std.npy")
    
    return model, state_mean, state_std


def normalize_state(state, mean, std):
    """Normalize state using training statistics."""
    return (state - mean) / (std + 1e-8)


# ── GA-SA evaluation from CSV ─────────────────────────────────────────────────
def eval_gasa(df, test_days=(13, 14)):
    sub = df[df["day"].isin(test_days)]
    rewards = sub["reward"].values
    water_used = sub["total_water_used_ml"].values
    b_in_range = sub["plant_1_in_range"].apply(lambda x: x if isinstance(x, bool) else str(x).lower() == "true").values
    c_in_range = sub["plant_2_in_range"].apply(lambda x: x if isinstance(x, bool) else str(x).lower() == "true").values
    b_emergency = sub["plant_1_emergency"].apply(lambda x: x if isinstance(x, bool) else str(x).lower() == "true").values
    c_emergency = sub["plant_2_emergency"].apply(lambda x: x if isinstance(x, bool) else str(x).lower() == "true").values

    # Measure latency
    latencies = []
    for _ in range(10):
        def dummy(w): return sum(math.sqrt(max(0, w[i])) for i in range(2))
        t0 = time.monotonic()
        optimize_water_allocations(n_plants=2, water_budget=180.0, utility_fn=dummy,
                                   population_size=20, generations=20)
        latencies.append((time.monotonic() - t0) * 1000)

    return {
        "avg_reward": float(np.mean(rewards)),
        "std_reward": float(np.std(rewards)),
        "total_water_l": float(water_used.sum() / 1000),
        "b_in_range_pct": float(b_in_range.mean() * 100),
        "c_in_range_pct": float(c_in_range.mean() * 100),
        "emergencies": int((b_emergency | c_emergency).sum()),
        "avg_latency_ms": float(np.mean(latencies)),
        "b_moisture": sub["plant_1_moisture_ekf"].values,
        "c_moisture": sub["plant_2_moisture_ekf"].values,
        "b_allocs": sub["plant_1_alloc_ml"].values,
        "c_allocs": sub["plant_2_alloc_ml"].values,
    }


# ── A2C policy simulation on test days ───────────────────────────────────────
def eval_a2c(df, policy, state_mean, state_std, test_days=(13, 14)):
    test_df = df[df["day"].isin(test_days)].reset_index(drop=True)
    rewards, b_moisture, c_moisture, b_allocs, c_allocs = [], [], [], [], []
    b_in_range_list, c_in_range_list = [], []
    b_emergency_list, c_emergency_list = [], []
    latencies = []

    for day in test_days:
        day_df = test_df[test_df["day"] == day].reset_index(drop=True)
        row0 = day_df.iloc[0]
        m = [float(row0["plant_1_moisture_ekf"]), float(row0["plant_2_moisture_ekf"])]
        tank_ml = float(row0["tank_ml"])

        for idx in range(len(day_df)):
            row = day_df.iloc[idx]
            hour = float(row["hour"])
            et_mult, = _interpolate(ET_PROFILE, hour)
            temp, humidity, light_lux = _interpolate(ENV_PROFILE, hour)
            env_stress = 1.0 + max(0, (temp - 22.0) / 25.0) + max(0, (65.0 - humidity) / 100.0)

            # Apply depletion
            for i in range(2):
                d = SPECIES[i]["optimal"] * 0.022 * et_mult * env_stress
                m[i] = max(0.0, m[i] - d)

            tank_pct = tank_ml / TANK_CAP * 100.0
            light_norm = light_lux / 10000.0
            deficits = [max(0.0, SPECIES[i]["optimal"] - m[i]) / SPECIES[i]["optimal"] for i in range(2)]

            # Build state vector
            state = np.array([
                m[0], m[1], deficits[0], deficits[1],
                temp, humidity, light_norm, tank_pct
            ], dtype=np.float32)
            
            # Normalize state
            state_norm = normalize_state(state, state_mean, state_std)
            state_tensor = torch.tensor(state_norm, dtype=torch.float32).unsqueeze(0)

            # A2C inference
            t0 = time.monotonic()
            with torch.no_grad():
                action_norm = policy(state_tensor).squeeze().numpy()
            latencies.append((time.monotonic() - t0) * 1000)

            # Denormalize action and apply budget
            budget = 180.0 if tank_pct > 60 else 130.0 if tank_pct > 30 else 80.0 if tank_pct > 10 else 0.0
            alloc = action_norm * 200.0
            total = alloc.sum()
            if total > budget and total > 0:
                alloc = alloc / total * budget

            # Apply irrigation
            for i in range(2):
                gain = alloc[i] * SPECIES[i]["gamma"]
                m[i] = min(95.0, m[i] + gain)
            tank_ml = max(0.0, tank_ml - alloc.sum())

            # Calculate reward
            sats = [gaussian_sat(m[i], SPECIES[i]) for i in range(2)]
            reward = sum(sats) / 2.0

            # Track metrics
            b_in = (m[0] >= SPECIES[0]["optimal"] * 0.75) and (m[0] <= SPECIES[0]["optimal"] * 1.20)
            c_in = (m[1] >= SPECIES[1]["optimal"] * 0.75) and (m[1] <= SPECIES[1]["optimal"] * 1.20)
            b_em = m[0] < SPECIES[0]["m_crit"]
            c_em = m[1] < SPECIES[1]["m_crit"]

            rewards.append(reward)
            b_moisture.append(m[0])
            c_moisture.append(m[1])
            b_allocs.append(alloc[0])
            c_allocs.append(alloc[1])
            b_in_range_list.append(b_in)
            c_in_range_list.append(c_in)
            b_emergency_list.append(b_em)
            c_emergency_list.append(c_em)

    total_water = (np.array(b_allocs) + np.array(c_allocs)).sum() / 1000
    return {
        "avg_reward": float(np.mean(rewards)),
        "std_reward": float(np.std(rewards)),
        "total_water_l": total_water,
        "b_in_range_pct": float(np.mean(b_in_range_list) * 100),
        "c_in_range_pct": float(np.mean(c_in_range_list) * 100),
        "emergencies": int(sum(e1 or e2 for e1, e2 in zip(b_emergency_list, c_emergency_list))),
        "avg_latency_ms": float(np.mean(latencies)),
        "b_moisture": np.array(b_moisture),
        "c_moisture": np.array(c_moisture),
        "b_allocs": np.array(b_allocs),
        "c_allocs": np.array(c_allocs),
    }


def main():
    df = pd.read_csv(DATA_PATH)
    print(f"Loading A2C policy from {MODEL_PATH}")
    
    # Check if model exists
    if not MODEL_PATH.exists():
        print(f"\n❌ ERROR: Model not found at {MODEL_PATH}")
        print("   You need to run Phase 3 first:")
        print("   python phase3_train_offline_rl.py")
        return
    
    policy, state_mean, state_std = load_policy(MODEL_PATH, MODEL_DIR)

    print("Evaluating GA-SA on test days 13-14...")
    gasa = eval_gasa(df)
    print("Evaluating A2C policy on test days 13-14...")
    a2c = eval_a2c(df, policy, state_mean, state_std)

    # ── Comparison table ──────────────────────────────────────────────────────
    print("\n=== Policy Comparison (Test Days 13-14) ===")
    print(f"{'Metric':<30} {'GA-SA':>12} {'A2C (Offline)':>18} {'Difference':>12}")
    print("-" * 75)

    def diff(a, b): return f"{b - a:+.3f}"
    def pct(a, b): return f"{b - a:+.1f}%"

    rows = [
        ("Avg Reward", f"{gasa['avg_reward']:.4f}", f"{a2c['avg_reward']:.4f}", diff(gasa['avg_reward'], a2c['avg_reward'])),
        ("Std Reward", f"{gasa['std_reward']:.4f}", f"{a2c['std_reward']:.4f}", ""),
        ("Total Water (L)", f"{gasa['total_water_l']:.2f}", f"{a2c['total_water_l']:.2f}", f"{a2c['total_water_l']-gasa['total_water_l']:+.2f}L"),
        ("Basil In-Range", f"{gasa['b_in_range_pct']:.1f}%", f"{a2c['b_in_range_pct']:.1f}%", pct(gasa['b_in_range_pct'], a2c['b_in_range_pct'])),
        ("Coleus In-Range", f"{gasa['c_in_range_pct']:.1f}%", f"{a2c['c_in_range_pct']:.1f}%", pct(gasa['c_in_range_pct'], a2c['c_in_range_pct'])),
        ("Emergency Events", str(gasa['emergencies']), str(a2c['emergencies']), str(a2c['emergencies'] - gasa['emergencies'])),
        ("Avg Latency (ms)", f"{gasa['avg_latency_ms']:.1f}", f"{a2c['avg_latency_ms']:.3f}", f"A2C {gasa['avg_latency_ms']/max(a2c['avg_latency_ms'],0.001):.0f}× faster"),
    ]
    for r in rows:
        print(f"  {r[0]:<28} {r[1]:>12} {r[2]:>18} {r[3]:>12}")

    # Save comparison CSV
    comp_path = RESULTS / "comparison_table.csv"
    with open(comp_path, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["Metric", "GA-SA", "A2C_Offline", "Difference"])
        for r in rows:
            writer.writerow(r)
    print(f"\nComparison table saved → {comp_path}")

    # ── Q4.5 Answers ──────────────────────────────────────────────────────────
    reward_ratio = a2c['avg_reward'] / max(gasa['avg_reward'], 1e-9) * 100
    water_diff = a2c['total_water_l'] - gasa['total_water_l']
    speedup = gasa['avg_latency_ms'] / max(a2c['avg_latency_ms'], 0.001)

    report_lines = [
        "=== Phase 4.5 Evaluation Report ===\n",
        f"Q1. Does A2C match GA-SA reward (within 5%)?",
        f"    GA-SA avg reward  : {gasa['avg_reward']:.4f}",
        f"    A2C avg reward    : {a2c['avg_reward']:.4f}",
        f"    A2C/GA-SA ratio   : {reward_ratio:.1f}%",
        f"    Answer            : {'YES ✓' if reward_ratio >= 95 else 'NO — further tuning recommended'}\n",
        f"Q2. Does A2C use less water (more efficient)?",
        f"    GA-SA water       : {gasa['total_water_l']:.2f} L",
        f"    A2C water         : {a2c['total_water_l']:.2f} L",
        f"    Difference        : {water_diff:+.2f} L",
        f"    Answer            : {'YES — A2C is more efficient ✓' if water_diff < 0 else 'No — A2C uses more water'}\n",
        f"Q3. Does A2C have fewer emergencies?",
        f"    GA-SA emergencies : {gasa['emergencies']}",
        f"    A2C emergencies   : {a2c['emergencies']}",
        f"    Answer            : {'YES ✓' if a2c['emergencies'] <= gasa['emergencies'] else 'No — more emergencies'}\n",
        f"Q4. Is the speed improvement worth any performance trade-off?",
        f"    GA-SA latency     : {gasa['avg_latency_ms']:.1f} ms",
        f"    A2C latency       : {a2c['avg_latency_ms']:.3f} ms",
        f"    Speed improvement : {speedup:.0f}×",
        f"    Answer            : A2C is {speedup:.0f}× faster. {'Even with a small reward gap, this is worthwhile for real-time use.' if reward_ratio < 95 else 'With equivalent reward quality, A2C is the clear production choice.'}\n",
        f"\n=== Recommendation ===",
    ]
    if reward_ratio >= 95:
        report_lines.append("USE A2C POLICY in production. Matches GA-SA quality at >50× speed.")
    elif reward_ratio >= 85:
        report_lines.append("HYBRID: Use A2C for routine cycles, fall back to GA-SA for emergency states.")
    else:
        report_lines.append("CONTINUE TRAINING: A2C not yet at 85% of GA-SA. Try more epochs or larger network.")

    report_text = "\n".join(report_lines)
    print("\n" + report_text)
    report_path = RESULTS / "evaluation_report.txt"
    report_path.write_text(report_text, encoding='utf-8')
    print(f"\nReport saved → {report_path}")

    # ── Visualizations ────────────────────────────────────────────────────────
    n = min(len(gasa["b_moisture"]), len(a2c["b_moisture"]))
    fig, axes = plt.subplots(2, 2, figsize=(14, 8))
    fig.suptitle("GA-SA vs A2C Policy — Test Days 13-14", fontsize=13, fontweight="bold")
    cyc = range(n)

    # 1. Basil moisture trajectories
    ax = axes[0, 0]
    ax.plot(cyc, gasa["b_moisture"][:n], color="#2e7d32", lw=1.5, label="GA-SA Basil")
    ax.plot(cyc, a2c["b_moisture"][:n], color="#81c784", lw=1.5, ls="--", label="A2C Basil")
    ax.axhline(65, color="green", lw=0.6, ls=":", alpha=0.5, label="Optimal 65%")
    ax.axhline(30, color="red", lw=0.6, ls=":", alpha=0.5, label="Critical 30%")
    ax.set_title("Basil Moisture Trajectories")
    ax.set_xlabel("Cycle")
    ax.set_ylabel("Moisture %")
    ax.legend(fontsize=8)
    ax.grid(alpha=0.3)

    # 2. Coleus moisture trajectories
    ax = axes[0, 1]
    ax.plot(cyc, gasa["c_moisture"][:n], color="#1565c0", lw=1.5, label="GA-SA Coleus")
    ax.plot(cyc, a2c["c_moisture"][:n], color="#64b5f6", lw=1.5, ls="--", label="A2C Coleus")
    ax.axhline(45, color="blue", lw=0.6, ls=":", alpha=0.5, label="Optimal 45%")
    ax.axhline(25, color="red", lw=0.6, ls=":", alpha=0.5, label="Critical 25%")
    ax.set_title("Coleus Moisture Trajectories")
    ax.set_xlabel("Cycle")
    ax.set_ylabel("Moisture %")
    ax.legend(fontsize=8)
    ax.grid(alpha=0.3)

    # 3. A2C vs GA-SA allocation scatter
    ax = axes[1, 0]
    m2 = min(len(gasa["b_allocs"]), len(a2c["b_allocs"]))
    ax.scatter(gasa["b_allocs"][:m2], a2c["b_allocs"][:m2], alpha=0.3, s=15, color="#2e7d32", label="Basil")
    ax.scatter(gasa["c_allocs"][:m2], a2c["c_allocs"][:m2], alpha=0.3, s=15, color="#1565c0", label="Coleus")
    lim = max(gasa["b_allocs"].max(), gasa["c_allocs"].max(), 1)
    ax.plot([0, lim], [0, lim], "k--", lw=0.8, alpha=0.5, label="Perfect match")
    ax.set_xlabel("GA-SA allocation (ml)")
    ax.set_ylabel("A2C allocation (ml)")
    ax.set_title("A2C vs GA-SA Allocations")
    ax.legend(fontsize=8)
    ax.grid(alpha=0.3)

    # 4. Bar chart — reward comparison
    ax = axes[1, 1]
    metrics_labels = ["Avg Reward", "Basil In-Range %", "Coleus In-Range %"]
    gasa_vals = [gasa["avg_reward"], gasa["b_in_range_pct"] / 100, gasa["c_in_range_pct"] / 100]
    a2c_vals = [a2c["avg_reward"], a2c["b_in_range_pct"] / 100, a2c["c_in_range_pct"] / 100]
    x = np.arange(len(metrics_labels))
    ax.bar(x - 0.2, gasa_vals, 0.35, label="GA-SA", color="#ff7043")
    ax.bar(x + 0.2, a2c_vals, 0.35, label="A2C", color="#42a5f5")
    ax.set_xticks(x)
    ax.set_xticklabels(metrics_labels, fontsize=9)
    ax.set_title("Key Metrics Comparison")
    ax.legend()
    ax.grid(alpha=0.3, axis="y")

    plt.tight_layout()
    plot_path = RESULTS / "a2c_vs_ga_sa_comparison.png"
    plt.savefig(plot_path, dpi=150, bbox_inches="tight")
    print(f"Comparison plots saved → {plot_path}")
    plt.close()


if __name__ == "__main__":
    main()