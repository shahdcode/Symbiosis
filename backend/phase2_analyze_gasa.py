"""
Phase 2: Analyze GA-SA demonstration data.
Run from backend/ with:
    python phase2_analyze_gasa.py
"""
import pandas as pd
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from pathlib import Path

DATA_PATH   = Path("offline_rl_project/data/ga_sa_demonstrations.csv")
OUTPUT_DIR  = Path("offline_rl_project/results")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


def main():
    df = pd.read_csv(DATA_PATH)
    print(f"Loaded {len(df)} cycles from {DATA_PATH}\n")

    # ── Overall metrics ──────────────────────────────────────────────────────
    total_water_l  = df["total_water_used_ml"].sum() / 1000
    avg_reward     = df["reward"].mean()
    b_in_range_pct = df["plant_1_in_range"].apply(lambda x: x if isinstance(x, bool) else str(x).lower() == "true").mean() * 100
    c_in_range_pct = df["plant_2_in_range"].apply(lambda x: x if isinstance(x, bool) else str(x).lower() == "true").mean() * 100
    b_emergency    = df["plant_1_emergency"].apply(lambda x: x if isinstance(x, bool) else str(x).lower() == "true").sum()
    c_emergency    = df["plant_2_emergency"].apply(lambda x: x if isinstance(x, bool) else str(x).lower() == "true").sum()

    print("=== Overall GA-SA Metrics (14 days) ===")
    print(f"  Total water used : {total_water_l:.2f} L")
    print(f"  Average reward   : {avg_reward:.4f}")
    print(f"  Basil in-range   : {b_in_range_pct:.1f}%")
    print(f"  Coleus in-range  : {c_in_range_pct:.1f}%")
    print(f"  Basil emergencies: {int(b_emergency)}")
    print(f"  Coleus emergencies:{int(c_emergency)}")

    # ── Daily breakdown ──────────────────────────────────────────────────────
    print("\n=== Daily Breakdown ===")
    for day in range(1, 15):
        d = df[df["day"] == day]
        avg_r   = d["reward"].mean()
        water   = d["total_water_used_ml"].sum()
        b_final = d["plant_1_moisture_ekf"].iloc[-1]
        c_final = d["plant_2_moisture_ekf"].iloc[-1]
        print(f"  Day {day:2d} | reward={avg_r:.3f} | water={water:.0f}ml | basil_final={b_final:.1f}% | coleus_final={c_final:.1f}%")

    # ── Failure patterns ─────────────────────────────────────────────────────
    over_water = (df["total_water_used_ml"] > 150).mean() * 100
    print(f"\n  Over-watering (>150ml/cycle): {over_water:.1f}% of cycles")

    # ── Plots ────────────────────────────────────────────────────────────────
    fig, axes = plt.subplots(2, 2, figsize=(14, 8))
    fig.suptitle("GA-SA Performance Analysis (14 Days)", fontsize=14, fontweight="bold")

    global_cycle = range(len(df))

    # 1. Moisture levels
    ax = axes[0, 0]
    ax.plot(global_cycle, df["plant_1_moisture_ekf"], color="#2e7d32", lw=1.2, label="Basil (opt=65%)")
    ax.plot(global_cycle, df["plant_2_moisture_ekf"], color="#1565c0", lw=1.2, label="Coleus (opt=45%)")
    ax.axhline(65, color="#2e7d32", lw=0.6, ls="--", alpha=0.5)
    ax.axhline(45, color="#1565c0", lw=0.6, ls="--", alpha=0.5)
    ax.axhline(30, color="red", lw=0.8, ls=":", alpha=0.7, label="Basil critical (30%)")
    ax.axhline(25, color="orange", lw=0.8, ls=":", alpha=0.7, label="Coleus critical (25%)")
    ax.set_xlabel("Cycle"); ax.set_ylabel("Moisture (%)"); ax.set_title("Moisture Levels vs Time")
    ax.legend(fontsize=8); ax.grid(alpha=0.3)

    # 2. Reward
    ax = axes[0, 1]
    ax.plot(global_cycle, df["reward"], color="#6a1b9a", lw=0.8, alpha=0.7, label="Per-cycle reward")
    rolling_avg = df["reward"].rolling(48).mean()
    ax.plot(global_cycle, rolling_avg, color="#e65100", lw=2, label="48-cycle rolling avg")
    ax.set_xlabel("Cycle"); ax.set_ylabel("Reward"); ax.set_title("Reward vs Cycle")
    ax.legend(fontsize=8); ax.grid(alpha=0.3)

    # 3. Allocation histogram
    ax = axes[1, 0]
    ax.hist(df["plant_1_alloc_ml"], bins=30, color="#2e7d32", alpha=0.6, label="Basil")
    ax.hist(df["plant_2_alloc_ml"], bins=30, color="#1565c0", alpha=0.6, label="Coleus")
    ax.set_xlabel("Water allocated (ml)"); ax.set_ylabel("Frequency")
    ax.set_title("Water Allocation Distribution"); ax.legend(); ax.grid(alpha=0.3)

    # 4. Daily water usage
    ax = axes[1, 1]
    daily_water = df.groupby("day")["total_water_used_ml"].sum() / 1000
    ax.bar(daily_water.index, daily_water.values, color="#0277bd", edgecolor="white")
    ax.set_xlabel("Day"); ax.set_ylabel("Total water (L)"); ax.set_title("Daily Water Usage")
    ax.grid(alpha=0.3, axis="y")

    plt.tight_layout()
    out = OUTPUT_DIR / "ga_sa_analysis.png"
    plt.savefig(out, dpi=150, bbox_inches="tight")
    print(f"\nPlot saved → {out}")
    plt.close()


if __name__ == "__main__":
    main()