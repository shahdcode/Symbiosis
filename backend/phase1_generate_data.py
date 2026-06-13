"""
Phase 1: Generate GA-SA demonstration data.
Run from backend/ with:
    python phase1_generate_data.py
"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))

import csv
import math
import random
import numpy as np
from pathlib import Path

random.seed(42)
np.random.seed(42)

# ── Import the real optimizer ────────────────────────────────────────────────
# Direct import without going through app/__init__.py
import importlib.util
import sys
from pathlib import Path

# Get the absolute path to metaheuristic_optimizer.py
optimizer_path = Path(__file__).parent / "app" / "algorithms" / "metaheuristic_optimizer.py"

# Load the module directly
spec = importlib.util.spec_from_file_location("metaheuristic_optimizer", optimizer_path)
metaheuristic_optimizer = importlib.util.module_from_spec(spec)
sys.modules["metaheuristic_optimizer"] = metaheuristic_optimizer
spec.loader.exec_module(metaheuristic_optimizer)

# Now import the function
optimize_water_allocations = metaheuristic_optimizer.optimize_water_allocations
sweep_hyperparameters = metaheuristic_optimizer.sweep_hyperparameters
# ── Species parameters ───────────────────────────────────────────────────────
SPECIES = [
    {   # Plant 1 — Basil
        "name": "plant_1",
        "optimal": 65.0,
        "m_crit": 30.0,
        "sigma": 16.25,
        "gamma": 0.031,
        "base_depl_per_30min": 0.705,   # avg across day
    },
    {   # Plant 2 — Coleus
        "name": "plant_2",
        "optimal": 45.0,
        "m_crit": 25.0,
        "sigma": 11.25,
        "gamma": 0.024,
        "base_depl_per_30min": 0.435,
    },
]

# ── Diurnal ET profile (hour → depletion multiplier) ────────────────────────
ET_PROFILE = [
    (0, 0.35), (4, 0.28), (6, 0.38), (8, 0.55),
    (10, 0.72), (12, 0.95), (14, 1.05), (16, 0.90),
    (18, 0.62), (20, 0.45), (22, 0.38), (24, 0.35),
]

ENV_PROFILE = [
    (0,  20.0, 66.0,   80),
    (4,  19.0, 68.0,   30),
    (6,  20.5, 66.0,  200),
    (8,  23.8, 57.3, 2910),
    (10, 25.1, 54.8, 4120),
    (12, 27.4, 51.2, 5840),
    (14, 26.9, 52.7, 5310),
    (16, 24.3, 55.9, 2710),
    (18, 22.9, 60.1,  890),
    (20, 21.6, 63.7,  210),
    (22, 20.8, 65.0,   90),
    (24, 20.1, 66.0,   50),
]


def _interpolate(profile, hour):
    for i in range(len(profile) - 1):
        h0, *v0 = profile[i]
        h1, *v1 = profile[i + 1]
        if h0 <= hour <= h1:
            f = (hour - h0) / (h1 - h0)
            return tuple(v0[j] + f * (v1[j] - v0[j]) for j in range(len(v0)))
    if hour < profile[0][0]:
        return tuple(profile[0][1:])
    return tuple(profile[-1][1:])


def gaussian_sat(moisture, sp):
    return math.exp(-0.5 * ((moisture - sp["optimal"]) / sp["sigma"]) ** 2)


def build_utility_fn(moistures, species, budget):
    """Returns a closure over current moisture state for the optimizer.
    
    Rewards moving plants toward optimal moisture, but penalizes water waste
    when tank is low to encourage efficient use.
    """
    def utility_fn(w):
        total = 0.0
        for i, sp in enumerate(species):
            gain = w[i] * sp["gamma"]
            new_m = min(95.0, moistures[i] + gain)
            # Gaussian satisfaction — peaks at optimal, falls off on both sides
            sat = gaussian_sat(new_m, sp)
            
            # Penalize over-watering (above 110% of optimal)
            overwater_penalty = max(0.0, new_m - sp["optimal"] * 1.10) * 0.1
            
            # Penalize giving water when already above optimal
            if moistures[i] > sp["optimal"]:
                waste_penalty = (w[i] / 200.0) * 0.15
            else:
                waste_penalty = 0.0
            
            # NEW: Penalize using water when tank is critically low
            tank_pct = budget / 180.0 * 100  # Approximate tank %
            if tank_pct < 30 and w[i] > 20:
                low_tank_penalty = 0.2 * (1.0 - tank_pct / 30.0)
            else:
                low_tank_penalty = 0.0
            
            # Emergency bonus - higher when plant is truly critical
            if moistures[i] < sp["m_crit"]:
                emergency_boost = 2.0  # Stronger emergency response
            elif moistures[i] < sp["optimal"] * 0.6:
                emergency_boost = 1.3
            else:
                emergency_boost = 1.0
            
            total += (sat - overwater_penalty - waste_penalty - low_tank_penalty) * emergency_boost
        
        return total / len(species)
    return utility_fn


# ── GA-SA Hyperparameter Sweep ───────────────────────────────────────────────
# Sweeps different population/generation combos and picks the best
# based on fitness score vs latency tradeoff.

SWEEP_CONFIGS = [
    {"population_size": 10, "generations": 10, "sa_steps": 30, "sa_t_start": 50.0, "sa_t_end": 0.5},
    {"population_size": 10, "generations": 20, "sa_steps": 40, "sa_t_start": 60.0, "sa_t_end": 0.5},
    {"population_size": 20, "generations": 10, "sa_steps": 40, "sa_t_start": 60.0, "sa_t_end": 0.5},
    {"population_size": 20, "generations": 20, "sa_steps": 60, "sa_t_start": 80.0, "sa_t_end": 0.5},
    {"population_size": 20, "generations": 30, "sa_steps": 60, "sa_t_start": 80.0, "sa_t_end": 0.5},
    {"population_size": 30, "generations": 20, "sa_steps": 60, "sa_t_start": 80.0, "sa_t_end": 0.5},
    {"population_size": 30, "generations": 30, "sa_steps": 80, "sa_t_start": 100.0, "sa_t_end": 0.5},
    {"population_size": 50, "generations": 30, "sa_steps": 80, "sa_t_start": 100.0, "sa_t_end": 0.5},
]

# Target latency budget per cycle (ms) — must stay under this for real-time use
LATENCY_BUDGET_MS = 300.0


DAY_MULTIPLIERS = {
    1: 0.82, 2: 0.88, 3: 0.94, 4: 0.85,  5: 1.06,
    6: 1.12, 7: 1.20, 8: 0.91, 9: 0.86, 10: 1.00,
    11: 0.89, 12: 0.83, 13: 0.84, 14: 0.80,
}

DAY_STARTS = {
    # Format: (Basil_start, Coleus_start)
    # Create a mix of healthy, moderate, and stressed conditions
    
    # Week 1: Progressive stress then recovery
    1:  (65.0, 45.0),   # Day 1: Perfect start
    2:  (58.0, 40.0),   # Day 2: Slightly stressed
    3:  (48.0, 34.0),   # Day 3: Moderate stress
    4:  (38.0, 28.0),   # Day 4: High stress (emergency territory)
    5:  (45.0, 32.0),   # Day 5: Recovering
    6:  (55.0, 38.0),   # Day 6: Improving
    7:  (62.0, 43.0),   # Day 7: Almost recovered
    
    # Week 2: Different patterns
    8:  (35.0, 26.0),   # Day 8: Severe emergency start
    9:  (50.0, 35.0),   # Day 9: Moderate stress
    10: (60.0, 42.0),   # Day 10: Near healthy
    11: (42.0, 30.0),   # Day 11: Back to stress
    12: (52.0, 36.0),   # Day 12: Recovering
    13: (40.0, 29.0),   # Day 13: Stressed before test
    14: (48.0, 34.0),   # Day 14: Moderate before test
}

TANK_CAPACITY = 5000.0
CSV_FIELDS = [
    "cycle", "hour", "day",
    "plant_1_moisture_raw", "plant_1_moisture_ekf", "plant_1_depletion_rate", "plant_1_deficit",
    "plant_1_alloc_ml", "plant_1_utility", "plant_1_in_range", "plant_1_emergency",
    "plant_2_moisture_raw", "plant_2_moisture_ekf", "plant_2_depletion_rate", "plant_2_deficit",
    "plant_2_alloc_ml", "plant_2_utility", "plant_2_in_range", "plant_2_emergency",
    "temp_c", "humidity_pct", "light_lux", "tank_level_pct", "tank_ml",
    "total_water_used_ml", "reward", "policy",
]


def simulate_day(day_num, b_start, c_start, tank_ml):
    rows = []
    moistures = [b_start + random.gauss(0, 0.3), c_start + random.gauss(0, 0.2)]
    day_mult = DAY_MULTIPLIERS.get(day_num, 1.0)

    for cycle in range(48):
        hour = (8.0 + cycle * 0.5) % 24
        et_mult, = _interpolate(ET_PROFILE, hour)
        temp, humidity, light_lux = _interpolate(ENV_PROFILE, hour)
        temp += random.gauss(0, 0.3)
        humidity += random.gauss(0, 0.5)
        light_lux = max(0, light_lux + random.gauss(0, 50))

        # Environmental depletion
        env_stress = 1.0 + max(0.0, (temp - 22.0) / 25.0) + max(0.0, (65.0 - humidity) / 100.0)
        depletions = []
        for sp in SPECIES:
            d = sp["base_depl_per_30min"] * et_mult * day_mult * env_stress
            depletions.append(d)
        for i in range(2):
            moistures[i] = max(0.0, moistures[i] - depletions[i])

        # Tank budget
        tank_pct = tank_ml / TANK_CAPACITY * 100.0
        if tank_pct > 60:
            budget = 180.0
        elif tank_pct > 30:
            budget = 130.0
        elif tank_pct > 10:
            budget = 80.0
        else:
            budget = 0.0

        # Caps: allow some over-allocation occasionally to create diversity
        # 20% of cycles: use loose caps (GA-SA can choose to over-water slightly)
        # 80% of cycles: standard caps capped at 1.3× what's needed
        if random.random() < 0.20:
            caps = np.full(2, 200.0)
        else:
            caps = np.array([
                max(0.0, (SPECIES[i]["optimal"] - moistures[i]) / max(SPECIES[i]["gamma"], 1e-6)) * 1.3
                for i in range(2)
            ])
            caps = np.clip(caps, 0.0, 200.0)
        
        # 10% of cycles: simulate missed watering (budget = 0) for recovery examples
        if random.random() < 0.10:
            budget = 0.0

        # ── ACTUAL GA-SA CALL ────────────────────────────────────────
        allocs = np.zeros(2)
        if budget > 0 and caps.sum() > 0:
            util_fn = build_utility_fn(moistures, SPECIES, budget)
            allocs, _ = optimize_water_allocations(
                n_plants=2,
                water_budget=budget,
                utility_fn=util_fn,
                population_size=BEST_GA_PARAMS["population_size"],
                generations=BEST_GA_PARAMS["generations"],
                max_per_plant=caps,
                sa_steps=BEST_GA_PARAMS["sa_steps"],
                sa_t_start=BEST_GA_PARAMS["sa_t_start"],
                sa_t_end=BEST_GA_PARAMS["sa_t_end"],
            )

        # Apply irrigation
        new_moistures = []
        for i in range(2):
            gain = allocs[i] * SPECIES[i]["gamma"]
            new_moistures.append(min(95.0, moistures[i] + gain))

        tank_ml = max(0.0, tank_ml - allocs.sum())

        # Reward
        sats = [gaussian_sat(new_moistures[i], SPECIES[i]) for i in range(2)]
        reward = sum(sats) / 2.0

        # In-range / emergency
        in_ranges = [
            (new_moistures[i] >= SPECIES[i]["optimal"] * 0.75) and
            (new_moistures[i] <= SPECIES[i]["optimal"] * 1.20)
            for i in range(2)
        ]
        emergencies = [new_moistures[i] < SPECIES[i]["m_crit"] for i in range(2)]
        deficits = [
            max(0.0, SPECIES[i]["optimal"] - moistures[i]) / SPECIES[i]["optimal"]
            for i in range(2)
        ]

        rows.append({
            "cycle": cycle + 1,
            "hour": round(hour, 2),
            "day": day_num,
            "plant_1_moisture_raw": round(new_moistures[0] + random.gauss(0, 1.5), 1),
            "plant_1_moisture_ekf": round(new_moistures[0], 2),
            "plant_1_depletion_rate": round(-depletions[0] / 0.5, 3),
            "plant_1_deficit": round(deficits[0], 4),
            "plant_1_alloc_ml": round(float(allocs[0]), 2),
            "plant_1_utility": round(sats[0], 4),
            "plant_1_in_range": in_ranges[0],
            "plant_1_emergency": emergencies[0],
            "plant_2_moisture_raw": round(new_moistures[1] + random.gauss(0, 1.5), 1),
            "plant_2_moisture_ekf": round(new_moistures[1], 2),
            "plant_2_depletion_rate": round(-depletions[1] / 0.5, 3),
            "plant_2_deficit": round(deficits[1], 4),
            "plant_2_alloc_ml": round(float(allocs[1]), 2),
            "plant_2_utility": round(sats[1], 4),
            "plant_2_in_range": in_ranges[1],
            "plant_2_emergency": emergencies[1],
            "temp_c": round(temp, 1),
            "humidity_pct": round(humidity, 1),
            "light_lux": round(light_lux),
            "tank_level_pct": round(tank_ml / TANK_CAPACITY * 100, 2),
            "tank_ml": round(tank_ml, 1),
            "total_water_used_ml": round(float(allocs.sum()), 2),
            "reward": round(reward, 4),
            "policy": "ga_sa",
        })
        moistures = new_moistures

    return rows, tank_ml


# Module-level best params — set by sweep before simulate_day is called
BEST_GA_PARAMS = {
    "population_size": 20,
    "generations": 20,
    "sa_steps": 60,
    "sa_t_start": 80.0,
    "sa_t_end": 0.5,
}


def main():
    global BEST_GA_PARAMS

    out_dir = Path("offline_rl_project/data")
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / "ga_sa_demonstrations.csv"
    sweep_log_path = out_dir / "ga_sa_sweep_results.csv"

    # ── Step 0: Hyperparameter sweep ────────────────────────────────────────
    print("Running GA-SA hyperparameter sweep (this takes ~30 seconds)...")
    best_cfg, sweep_results = sweep_hyperparameters(
        n_plants=2,
        water_budget=180.0,
        n_trials=8,
        latency_budget_ms=300.0,
        verbose=True,
    )

    # Update global best params
    BEST_GA_PARAMS = {
        "population_size": best_cfg["population_size"],
        "generations": best_cfg["generations"],
        "sa_steps": best_cfg["sa_steps"],
        "sa_t_start": best_cfg["sa_t_start"],
        "sa_t_end": best_cfg["sa_t_end"],
    }

    # Save sweep log
    sweep_fields = ["config_idx", "population_size", "generations", "sa_steps",
                    "sa_t_start", "sa_t_end", "avg_fitness", "std_fitness",
                    "avg_latency_ms", "within_budget"]
    with open(sweep_log_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=sweep_fields)
        writer.writeheader()
        writer.writerows(sweep_results)
    print(f"Sweep results saved → {sweep_log_path}")
    print(f"Using params: pop={BEST_GA_PARAMS['population_size']} "
          f"gen={BEST_GA_PARAMS['generations']} "
          f"sa_steps={BEST_GA_PARAMS['sa_steps']}\n")

    # Save best params to backend JSON so coordinator auto-loads them
    try:
        from app.algorithms.metaheuristic_optimizer import save_best_params
        saved_path = save_best_params(best_cfg)
        print(f"Best params saved to backend → {saved_path}")
        print("  (coordinator will use these on next server restart)\n")
    except Exception as _e:
        print(f"  Could not save params to backend ({_e}) — sweep result still used for phases\n")

    # ── Override with backend .env settings if they differ from defaults ────
    # This lets the user pin specific params via GA_POPULATION_SIZE /
    # GA_GENERATIONS in .env rather than relying on the sweep result.
    try:
        from app.core.config import settings as _settings
        env_pop = _settings.ga_population_size
        env_gen = _settings.ga_generations
        # Only override if the .env values differ from the default (20/20)
        # — a sign the user intentionally set them
        if env_pop != 20 or env_gen != 20:
            print(f"  [.env override] GA_POPULATION_SIZE={env_pop}  "
                  f"GA_GENERATIONS={env_gen}  (overrides sweep result)")
            BEST_GA_PARAMS["population_size"] = env_pop
            BEST_GA_PARAMS["generations"] = env_gen
        else:
            print(f"  [.env] GA_POPULATION_SIZE and GA_GENERATIONS are at defaults — "
                  f"keeping sweep result (pop={BEST_GA_PARAMS['population_size']}, "
                  f"gen={BEST_GA_PARAMS['generations']})")
    except Exception as _e:
        print(f"  [.env] Could not load backend settings ({_e}) — using sweep result")

    all_rows = []
    tank_ml = TANK_CAPACITY

    for day in range(1, 15):
        b_start, c_start = DAY_STARTS[day]
        print(f"  Day {day:2d}: basil_start={b_start:.1f}%  coleus_start={c_start:.1f}%  tank={tank_ml/TANK_CAPACITY*100:.0f}%")
        rows, tank_ml = simulate_day(day, b_start, c_start, tank_ml)
        all_rows.extend(rows)
        if day == 7:
            tank_ml = 0.97 * TANK_CAPACITY   # Day 7 refill event
        elif tank_ml / TANK_CAPACITY < 0.20:
            tank_ml = 0.80 * TANK_CAPACITY

    with open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=CSV_FIELDS)
        writer.writeheader()
        writer.writerows(all_rows)

    print(f"\nWritten {len(all_rows)} rows → {out_path}")

    # Summary
    total_water = sum(r["total_water_used_ml"] for r in all_rows) / 1000
    avg_reward  = sum(r["reward"] for r in all_rows) / len(all_rows)
    b_in_range  = sum(r["plant_1_in_range"] for r in all_rows) / len(all_rows) * 100
    c_in_range  = sum(r["plant_2_in_range"] for r in all_rows) / len(all_rows) * 100
    emergencies = sum(r["plant_1_emergency"] or r["plant_2_emergency"] for r in all_rows)
    print(f"\n=== GA-SA Summary ===")
    print(f"  --- Winning GA-SA config ---")
    print(f"  population_size : {BEST_GA_PARAMS['population_size']}")
    print(f"  generations     : {BEST_GA_PARAMS['generations']}")
    print(f"  sa_steps        : {BEST_GA_PARAMS['sa_steps']}")
    print(f"  sa_t_start      : {BEST_GA_PARAMS['sa_t_start']}")
    print(f"  sa_t_end        : {BEST_GA_PARAMS['sa_t_end']}")
    print(f"  ---")
    print(f"  Total water    : {total_water:.2f} L")
    print(f"  Avg reward     : {avg_reward:.4f}")
    print(f"  Basil in-range : {b_in_range:.1f}%")
    print(f"  Coleus in-range: {c_in_range:.1f}%")
    print(f"  Emergencies    : {emergencies}")
    print(f"\n  Sweep log      : offline_rl_project/data/ga_sa_sweep_results.csv")


if __name__ == "__main__":
    main()