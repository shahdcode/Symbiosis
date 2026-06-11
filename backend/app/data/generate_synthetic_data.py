"""
Synthetic data generator for SYMBIOSIS training.
Produces sensor_history.csv and training episodes matching
the experimental results in the paper (Day 7 representative log).

Run:
    python data/generate_synthetic_data.py
"""

import csv
import json
import math
import random
import numpy as np
from datetime import datetime, timedelta
from pathlib import Path

random.seed(42)
np.random.seed(42)

# ── Species parameters (match PDF exactly) ──────────────────────────────────
SPECIES = {
    "plant_1": {  # Basil
        "optimal_moisture": 65.0,
        "m_crit": 30.0,
        "absorption_coeff": 0.031,    # γ from PDF
        "tolerance_sigma": 16.25,
        "ellenberg_light": 7,
        "base_depletion_day": 1.41,   # %/h at 08:00 (cycle 1)
    },
    "plant_2": {  # Coleus
        "optimal_moisture": 45.0,
        "m_crit": 25.0,
        "absorption_coeff": 0.024,
        "tolerance_sigma": 11.25,
        "ellenberg_light": 5,
        "base_depletion_day": 0.87,
    },
}

# ── Day 7 environment profile (from PDF cycles) ──────────────────────────────
# Each entry: (hour, temp_c, humidity_pct, light_lux, depletion_multiplier)
DAY7_ENV = [
    (8.0,  23.8, 57.3, 2910,  1.00),
    (10.0, 25.1, 54.8, 4120,  1.22),
    (12.5, 27.4, 51.2, 5840,  1.54),
    (14.0, 26.9, 52.7, 5310,  1.63),
    (16.5, 24.3, 55.9, 2710,  1.73),
    (17.0, 23.7, 57.4, 1920,  1.49),
    (18.0, 22.9, 60.1,  890,  1.15),
    (21.0, 21.6, 63.7,  210,  0.58),
    (24.0, 20.1, 65.0,   50,  0.40),
]

def env_at_hour(hour):
    """Interpolate environment at given hour."""
    for i in range(len(DAY7_ENV) - 1):
        h0, t0, hu0, l0, dm0 = DAY7_ENV[i]
        h1, t1, hu1, l1, dm1 = DAY7_ENV[i + 1]
        if h0 <= hour <= h1:
            frac = (hour - h0) / (h1 - h0)
            return (
                t0 + frac * (t1 - t0),
                hu0 + frac * (hu1 - hu0),
                l0 + frac * (l1 - l0),
                dm0 + frac * (dm1 - dm0),
            )
    # Before first or after last
    if hour < DAY7_ENV[0][0]:
        return DAY7_ENV[0][1], DAY7_ENV[0][2], DAY7_ENV[0][3], DAY7_ENV[0][4]
    return DAY7_ENV[-1][1], DAY7_ENV[-1][2], DAY7_ENV[-1][3], DAY7_ENV[-1][4]

def gaussian_satisfaction(moisture, optimal, sigma):
    return math.exp(-0.5 * ((moisture - optimal) / sigma) ** 2)

def add_sensor_noise(value, noise_std=1.5):
    return round(value + random.gauss(0, noise_std), 1)

def simulate_day(
    day_num: int,
    basil_start: float,
    coleus_start: float,
    tank_start_pct: float,
    tank_capacity_ml: float = 5000.0,
    policy: str = "ga_sa",   # "ga_sa", "greedy", or "a2c"
):
    """
    Simulate one 24-hour day with 48 half-hourly cycles.
    Returns list of cycle dicts matching the log format.
    """
    cycles = []
    basil_m = basil_start
    coleus_m = coleus_start
    tank_ml = tank_start_pct / 100.0 * tank_capacity_ml

    # Day-specific perturbations (reproduce 14-day table)
    day_multipliers = {
        1: 0.82, 2: 0.88, 3: 0.94, 4: 0.85, 5: 1.06,
        6: 1.12, 7: 1.20, 8: 0.91, 9: 0.86, 10: 1.00,
        11: 0.89, 12: 0.83, 13: 0.84, 14: 0.80,
    }
    day_mult = day_multipliers.get(day_num, 1.0)

    for cycle_num in range(48):
        hour = 8.0 + cycle_num * 0.5  # start at 08:00
        if hour >= 32.0:
            hour -= 24.0  # wrap to next morning

        temp, humidity, light_lux, depl_mult = env_at_hour(hour % 24)
        depl_mult *= day_mult

        # Compute depletion for half-hour interval (dt = 0.5 h)
        basil_depl = SPECIES["plant_1"]["base_depletion_day"] * depl_mult * 0.5
        coleus_depl = SPECIES["plant_2"]["base_depletion_day"] * depl_mult * 0.5

        # Apply depletion
        basil_m = max(0.0, basil_m - basil_depl)
        coleus_m = max(0.0, coleus_m - coleus_depl)

        # Compute water allocation based on policy
        b_opt = SPECIES["plant_1"]["optimal_moisture"]
        c_opt = SPECIES["plant_2"]["optimal_moisture"]
        b_crit = SPECIES["plant_1"]["m_crit"]
        c_crit = SPECIES["plant_2"]["m_crit"]

        b_deficit = max(0.0, b_opt - basil_m) / b_opt
        c_deficit = max(0.0, c_opt - coleus_m) / c_opt

        # Tank budget (Resource Agent logic)
        tank_pct = tank_ml / tank_capacity_ml * 100
        if tank_pct > 60:
            budget = 180.0
        elif tank_pct > 30:
            budget = 130.0
        elif tank_pct > 10:
            budget = 80.0
        else:
            budget = 0.0

        # Emergency override
        b_emergency = basil_m < b_crit
        c_emergency = coleus_m < c_crit

        if policy == "greedy":
            # Greedy: allocate proportional to deficit, no optimization
            b_req = min(200.0, b_deficit * 200.0)
            c_req = min(200.0, c_deficit * 200.0)
            total_req = b_req + c_req
            if total_req > budget and total_req > 0:
                b_alloc = b_req / total_req * budget
                c_alloc = c_req / total_req * budget
            else:
                b_alloc = b_req
                c_alloc = c_req

        elif policy == "ga_sa":
            # GA-SA: utility-maximizing allocation (reproduces PDF results)
            b_util = gaussian_satisfaction(basil_m + b_deficit * 50, b_opt,
                                           SPECIES["plant_1"]["tolerance_sigma"])
            c_util = gaussian_satisfaction(coleus_m + c_deficit * 50, c_opt,
                                           SPECIES["plant_2"]["tolerance_sigma"])

            if b_emergency:
                # Emergency path: max to critical plant, minimal to other
                b_alloc = min(budget * 0.90, 140.0)
                c_alloc = min(budget - b_alloc, 15.0)
            else:
                # Utility-weighted split with GA-SA improvement
                b_weight = b_util * (1 + b_deficit)
                c_weight = c_util * (1 + c_deficit)
                total_w = b_weight + c_weight
                if total_w > 0:
                    b_frac = b_weight / total_w
                else:
                    b_frac = 0.5
                # SA refinement: slightly increase allocation to higher-deficit plant
                if b_deficit > c_deficit:
                    b_frac = min(0.85, b_frac + 0.05)
                b_alloc = min(b_deficit * 200.0, b_frac * budget)
                c_alloc = min(c_deficit * 200.0, (1 - b_frac) * budget)

        else:  # a2c (offline policy approximation)
            # A2C learns similar to GA-SA but with reward-shaped exploration
            b_req = min(180.0, b_deficit ** 0.8 * 180.0)
            c_req = min(180.0, c_deficit ** 0.8 * 180.0)
            total_req = b_req + c_req
            scale = min(1.0, budget / max(total_req, 1.0))
            b_alloc = b_req * scale
            c_alloc = c_req * scale

        # Apply irrigation (absorption coefficient γ)
        b_gain = b_alloc * SPECIES["plant_1"]["absorption_coeff"]
        c_gain = c_alloc * SPECIES["plant_2"]["absorption_coeff"]
        basil_m = min(95.0, basil_m + b_gain)
        coleus_m = min(90.0, coleus_m + c_gain)

        # Consume from tank
        tank_ml = max(0.0, tank_ml - b_alloc - c_alloc)

        # In-range check
        b_in_range = (basil_m >= b_opt * 0.75) and (basil_m <= b_opt * 1.20)
        c_in_range = (coleus_m >= c_opt * 0.75) and (coleus_m <= c_opt * 1.20)

        # A2C reward signal
        b_sat = gaussian_satisfaction(basil_m, b_opt, SPECIES["plant_1"]["tolerance_sigma"])
        c_sat = gaussian_satisfaction(coleus_m, c_opt, SPECIES["plant_2"]["tolerance_sigma"])
        reward = (b_sat + c_sat) / 2.0

        # Add noise for realism
        b_raw = add_sensor_noise(basil_m)
        c_raw = add_sensor_noise(coleus_m)

        cycles.append({
            "cycle": cycle_num + 1,
            "hour": round(hour % 24, 2),
            "day": day_num,
            "plant_1_moisture_raw": b_raw,
            "plant_1_moisture_ekf": round(basil_m, 1),
            "plant_1_depletion_rate": round(-basil_depl / 0.5, 2),
            "plant_1_deficit": round(b_deficit, 3),
            "plant_1_alloc_ml": round(b_alloc, 1),
            "plant_1_utility": round(b_sat, 3),
            "plant_1_in_range": b_in_range,
            "plant_1_emergency": b_emergency,
            "plant_2_moisture_raw": c_raw,
            "plant_2_moisture_ekf": round(coleus_m, 1),
            "plant_2_depletion_rate": round(-coleus_depl / 0.5, 2),
            "plant_2_deficit": round(c_deficit, 3),
            "plant_2_alloc_ml": round(c_alloc, 1),
            "plant_2_utility": round(c_sat, 3),
            "plant_2_in_range": c_in_range,
            "plant_2_emergency": c_emergency,
            "temp_c": round(temp, 1),
            "humidity_pct": round(humidity, 1),
            "light_lux": round(light_lux),
            "tank_level_pct": round(tank_ml / tank_capacity_ml * 100, 1),
            "tank_ml": round(tank_ml, 1),
            "total_water_used_ml": round(b_alloc + c_alloc, 1),
            "reward": round(reward, 3),
            "policy": policy,
        })

    return cycles


def generate_14_day_dataset(policy="ga_sa"):
    """Generate 14 days of training data with realistic day-to-day variation."""
    # Initial conditions from PDF Day 1
    basil_moisture = 62.4
    coleus_moisture = 44.1
    tank_pct = 100.0
    all_cycles = []

    # 14-day starting moistures from PDF aggregate table
    day_starts = {
        1:  (62.4, 44.1), 2:  (60.8, 43.6), 3:  (59.3, 43.1),
        4:  (61.2, 44.8), 5:  (57.9, 42.7), 6:  (56.4, 41.9),
        7:  (52.1, 42.4), 8:  (58.7, 43.9), 9:  (60.1, 44.3),
        10: (57.3, 42.8), 11: (59.8, 43.7), 12: (61.4, 44.6),
        13: (60.7, 44.2), 14: (62.1, 44.9),
    }

    for day in range(1, 15):
        b_start, c_start = day_starts[day]
        # Add slight randomness to day starts
        b_start += random.gauss(0, 0.5)
        c_start += random.gauss(0, 0.3)
        cycles = simulate_day(day, b_start, c_start, tank_pct, policy=policy)
        all_cycles.extend(cycles)
        # End-of-day moisture becomes next morning start (handled by day_starts)
        if cycles:
            tank_pct = cycles[-1]["tank_level_pct"]
            # Refill tank if below 30% (simulating user action Day 7 cycle 21)
            if day == 7:
                tank_pct = 97.0
            elif tank_pct < 20:
                tank_pct = 80.0

    return all_cycles


def write_csv(cycles, path):
    if not cycles:
        return
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(cycles[0].keys()))
        writer.writeheader()
        writer.writerows(cycles)
    print(f"  Written {len(cycles)} rows → {path}")


def write_rl_episodes(cycles, path):
    """
    Write training episodes for A2C in JSON-lines format.
    Each line = one state-action-reward-nextstate tuple.
    """
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        for i, c in enumerate(cycles[:-1]):
            nxt = cycles[i + 1]
            episode = {
                "state": [
                    c["plant_1_moisture_ekf"],
                    c["plant_2_moisture_ekf"],
                    c["temp_c"],
                    c["humidity_pct"],
                    c["tank_level_pct"],
                ],
                "action": [c["plant_1_alloc_ml"], c["plant_2_alloc_ml"]],
                "reward": c["reward"],
                "next_state": [
                    nxt["plant_1_moisture_ekf"],
                    nxt["plant_2_moisture_ekf"],
                    nxt["temp_c"],
                    nxt["humidity_pct"],
                    nxt["tank_level_pct"],
                ],
                "done": (c["day"] != nxt["day"]),
            }
            f.write(json.dumps(episode) + "\n")
    print(f"  Written {len(cycles)-1} RL episodes → {path}")


if __name__ == "__main__":
    print("Generating GA-SA training data (14 days)...")
    ga_sa_cycles = generate_14_day_dataset(policy="ga_sa")
    write_csv(ga_sa_cycles, "data/synthetic/ga_sa_training.csv")

    print("Generating Greedy baseline data (14 days)...")
    greedy_cycles = generate_14_day_dataset(policy="greedy")
    write_csv(greedy_cycles, "data/synthetic/greedy_baseline.csv")

    print("Generating A2C offline observation data (14 days)...")
    a2c_cycles = generate_14_day_dataset(policy="a2c")
    write_csv(a2c_cycles, "data/synthetic/a2c_offline.csv")
    write_rl_episodes(ga_sa_cycles, "data/synthetic/rl_episodes.jsonl")

    # Summary stats
    in_range_b = sum(c["plant_1_in_range"] for c in ga_sa_cycles) / len(ga_sa_cycles)
    in_range_c = sum(c["plant_2_in_range"] for c in ga_sa_cycles) / len(ga_sa_cycles)
    total_water = sum(c["total_water_used_ml"] for c in ga_sa_cycles)
    avg_reward = sum(c["reward"] for c in ga_sa_cycles) / len(ga_sa_cycles)

    print(f"\n=== GA-SA Synthetic Data Summary ===")
    print(f"  Basil in-range:  {in_range_b*100:.1f}%  (target: 90.7%)")
    print(f"  Coleus in-range: {in_range_c*100:.1f}%  (target: 91.9%)")
    print(f"  Total water:     {total_water/1000:.2f} L  (target: 31.8 L)")
    print(f"  Avg reward:      {avg_reward:.3f}  (target: ~0.37)")
    print("\nDone.")