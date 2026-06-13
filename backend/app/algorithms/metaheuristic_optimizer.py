"""Hybrid GA + SA optimizer for water allocation.
backend/app/algorithms/metaheuristic_optimizer.py
Allocates water (ml) to N plants subject to a total water budget.
Light is informational only and is NOT allocated here.

Citation: Combinatorial auction + metaheuristic (Parkes & Ungar, 2000).
"""
from typing import Callable, Tuple
import json
import random
import math
from pathlib import Path

import numpy as np


def optimize_water_allocations(
    n_plants: int,
    water_budget: float,
    utility_fn: Callable[[np.ndarray], float],
    population_size: int = 30,
    generations: int = 50,
    max_per_plant: np.ndarray | None = None,
    sa_steps: int = 40,
    sa_t_start: float = 50.0,
    sa_t_end: float = 0.5,
) -> Tuple[np.ndarray, float]:
    """Return (water_allocs, best_fitness).

    utility_fn takes a numpy array of water allocations (length n_plants)
    and returns a scalar fitness value.
    max_per_plant: optional per-plant cap (ml). Defaults to water_budget for each plant.
    """
    if n_plants == 0 or water_budget <= 0:
        return np.zeros(max(n_plants, 1)), 0.0

    caps = max_per_plant if max_per_plant is not None else np.full(n_plants, water_budget)
    caps = np.minimum(caps, water_budget)

    def random_individual() -> np.ndarray:
        ind = np.array([np.random.uniform(0, caps[i]) for i in range(n_plants)])
        total = ind.sum()
        if total > water_budget and total > 0:
            ind = ind / total * water_budget
        return ind
    pop = [random_individual() for _ in range(population_size)]

    def fitness(ind: np.ndarray) -> float:
        return utility_fn(ind)

    best = max(pop, key=fitness)
    best_score = fitness(best)

    no_improve = 0
    prev_best = best_score

    for _g in range(generations):
        # elitism: carry best individual into next generation
        new_pop = [best.copy()]

        while len(new_pop) < population_size:
            # tournament selection (k=2)
            a, b = random.sample(pop, 2)
            parent = a if fitness(a) > fitness(b) else b

            # single-point crossover
            mate = random.choice(pop)
            cut = random.randint(1, n_plants - 1) if n_plants > 1 else 1
            child = np.concatenate([parent[:cut], mate[cut:]])

            # Gaussian mutation on a random gene
            idx = random.randrange(n_plants)
            child[idx] *= (1.0 + random.gauss(0.0, 0.15))

            # repair: clip negatives then re-scale to budget
            child = np.clip(child, 0.0, caps)
            total = child.sum()
            if total > water_budget and total > 0:
                child = child / total * water_budget
            elif total == 0:
                child = random_individual()
            new_pop.append(child)

        pop = new_pop

        # update best
        for ind in pop:
            s = fitness(ind)
            if s > best_score:
                best = ind.copy()
                best_score = s

        # SA local refinement on current best — only accept if improved
        sa_candidate, sa_score = _simulated_annealing_local(
            best,
            best_score,
            fitness,
            water_budget,
            n_plants,
            caps=caps,
            sa_steps=sa_steps,
            t_start=sa_t_start,
            t_decay=(sa_t_end / max(sa_t_start, 1e-6)) ** (1.0 / max(sa_steps, 1)),
        )
        if sa_score > best_score:
            best = sa_candidate
            best_score = sa_score
        # early stopping
        improvement = best_score - prev_best
        if improvement < 1e-6:
            no_improve += 1
        else:
            no_improve = 0
        prev_best = best_score

        if no_improve >= 8:
            break

    return best, best_score


def load_best_params() -> dict:
    """Load optional GA/SA best-parameter snapshot.

    The coordinator uses this as a compatibility shim for previously
    saved sweep results. If no file is present, it safely falls back to
    the default settings in the coordinator.
    """
    candidates = [
        Path(__file__).with_name("best_ga_sa_params.json"),
        Path(__file__).resolve().parent.parent / "data" / "best_ga_sa_params.json",
    ]

    for path in candidates:
        try:
            if path.exists():
                return json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            continue

    return {}


def _simulated_annealing_local(
    individual: np.ndarray,
    score: float,
    fitness_fn: Callable,
    water_budget: float,
    n_plants: int,
    caps: np.ndarray | None = None,
    sa_steps: int = 40,
    t_start: float = 50.0,
    t_decay: float = 0.92,
    t_end: float = None,
) -> Tuple[np.ndarray, float]:
    """SA perturbation loop that respects the water budget and per-plant caps.
    
    If t_end is provided, t_decay is automatically calculated from t_start to t_end.
    """
    if caps is None:
        caps = np.full(n_plants, water_budget)
    ind = individual.copy()
    current_score = score
    
    # Calculate decay from t_start to t_end if t_end provided
    if t_end is not None and t_end > 0 and t_start > t_end and sa_steps > 0:
        t_decay = (t_end / t_start) ** (1.0 / sa_steps)
    
    T = t_start

    for _ in range(sa_steps):
        prop = ind.copy()

        # swap-perturb: shift water from one plant to another
        if n_plants > 1:
            i, j = random.sample(range(n_plants), 2)
            delta = random.uniform(0, prop[i] * 0.3)
            prop[i] -= delta
            prop[j] += delta
        else:
            prop[0] = water_budget

        prop = np.clip(prop, 0.0, caps)
        total = prop.sum()
        if total > water_budget and total > 0:
            prop = prop / total * water_budget

        prop_score = fitness_fn(prop)
        delta_e = prop_score - current_score

        if delta_e > 0 or (T > 0 and math.exp(delta_e / T) > random.random()):
            ind = prop
            current_score = prop_score

        T *= t_decay

    return ind, current_score


# ---------------------------------------------------------------------------
# Backwards-compatible shim so existing imports don't break during transition
# ---------------------------------------------------------------------------
def optimize_bundle_allocations(
    n_plants: int,
    water_budget: float,
    light_budget: float,          # kept for signature compat, ignored
    utility_fn: Callable,         # must accept (w, l) — wrapped internally
    population_size: int = 30,
    generations: int = 50,
    alpha: float = 0.5,
) -> Tuple[np.ndarray, np.ndarray, float]:
    """Legacy shim — light_budget is ignored; l_best is always zeros."""
    def water_only_util(w: np.ndarray) -> float:
        l = np.zeros(n_plants)
        return utility_fn(w, l)

    w_best, best_score = optimize_water_allocations(
        n_plants=n_plants,
        water_budget=water_budget,
        utility_fn=water_only_util,
        population_size=population_size,
        generations=generations,
    )
    l_best = np.zeros(n_plants)
    return w_best, l_best, best_score


# ---------------------------------------------------------------------------
# Hyperparameter sweep — finds best GA-SA params for this hardware
# ---------------------------------------------------------------------------

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

LATENCY_BUDGET_MS = 300.0


def sweep_hyperparameters(
    n_plants: int = 2,
    water_budget: float = 180.0,
    n_trials: int = 8,
    latency_budget_ms: float = LATENCY_BUDGET_MS,
    verbose: bool = True,
) -> Tuple[dict, list]:
    """Sweep GA-SA hyperparameter configs and return the best one.

    Uses a representative irrigation problem (one plant dry, one critical)
    to benchmark each config. Picks highest fitness within latency budget.

    Args:
        n_plants: Number of plants (2 for Basil + Coleus).
        water_budget: Max water available per cycle (ml).
        n_trials: How many times to run each config (averaged).
        latency_budget_ms: Max acceptable avg latency per config.
        verbose: Print sweep table to stdout.

    Returns:
        (best_config_dict, all_results_list)
    """
    import time

    # Representative problem: basil moderately dry, coleus approaching critical
    test_moistures = [45.0, 30.0]
    test_species = [
        {"optimal": 65.0, "m_crit": 30.0, "sigma": 16.25, "gamma": 0.031},
        {"optimal": 45.0, "m_crit": 25.0, "sigma": 11.25, "gamma": 0.024},
    ]

    def _gaussian_sat(m, sp):
        return math.exp(-0.5 * ((m - sp["optimal"]) / sp["sigma"]) ** 2)

    def representative_utility(w: np.ndarray) -> float:
        total = 0.0
        for i, sp in enumerate(test_species):
            gain = w[i] * sp["gamma"]
            new_m = min(95.0, test_moistures[i] + gain)
            sat = _gaussian_sat(new_m, sp)
            deficit = max(0.0, sp["optimal"] - test_moistures[i]) / sp["optimal"]
            # Penalize over-watering slightly
            overwater = max(0.0, new_m - sp["optimal"] * 1.10) * 0.05
            emergency = 1.5 if test_moistures[i] < sp["m_crit"] * 1.2 else 1.0
            total += (sat - overwater) * emergency * (1.0 + deficit)
        return total / len(test_species)

    results = []

    if verbose:
        print("\n" + "=" * 78)
        print("GA-SA HYPERPARAMETER SWEEP")
        print("=" * 78)
        print(f"  Problem: {n_plants} plants | water_budget={water_budget}ml | "
              f"{n_trials} trials per config | latency_budget={latency_budget_ms}ms")
        print(f"{'Cfg':>5} {'pop':>5} {'gen':>5} {'sa':>5} {'t0':>7}  "
              f"{'Fitness':>10} {'±':>8}  {'Latency':>10}  {'Status':>8}")
        print("-" * 78)

    for cfg_idx, cfg in enumerate(SWEEP_CONFIGS):
        fitnesses, latencies = [], []
        for _ in range(n_trials):
            t0 = time.monotonic()
            _, score = optimize_water_allocations(
                n_plants=n_plants,
                water_budget=water_budget,
                utility_fn=representative_utility,
                population_size=cfg["population_size"],
                generations=cfg["generations"],
                max_per_plant=np.full(n_plants, 200.0),
                sa_steps=cfg["sa_steps"],
                sa_t_start=cfg["sa_t_start"],
                sa_t_end=cfg["sa_t_end"],
            )
            latencies.append((time.monotonic() - t0) * 1000)
            fitnesses.append(score)

        avg_fit = float(np.mean(fitnesses))
        std_fit = float(np.std(fitnesses))
        avg_lat = float(np.mean(latencies))
        ok = avg_lat <= latency_budget_ms

        if verbose:
            status = "✓ OK" if ok else "✗ SLOW"
            print(f"  [{cfg_idx+1:2d}]  "
                  f"{cfg['population_size']:>5}  "
                  f"{cfg['generations']:>4}  "
                  f"{cfg['sa_steps']:>4}  "
                  f"{cfg['sa_t_start']:>6.0f}  "
                  f"{avg_fit:>10.4f}  "
                  f"{std_fit:>7.4f}  "
                  f"{avg_lat:>9.1f}ms  "
                  f"{status:>8}")

        results.append({
            "config_idx": cfg_idx + 1,
            "population_size": cfg["population_size"],
            "generations": cfg["generations"],
            "sa_steps": cfg["sa_steps"],
            "sa_t_start": cfg["sa_t_start"],
            "sa_t_end": cfg["sa_t_end"],
            "avg_fitness": round(avg_fit, 6),
            "std_fitness": round(std_fit, 6),
            "avg_latency_ms": round(avg_lat, 2),
            "within_budget": ok,
        })

    valid = [r for r in results if r["within_budget"]]
    best = max(valid, key=lambda r: r["avg_fitness"]) if valid else min(
        results, key=lambda r: r["avg_latency_ms"]
    )
    note = f"highest fitness within {latency_budget_ms}ms" if valid else "fastest (all exceeded budget)"

    if verbose:
        print("-" * 78)
        print(f"\n  ★ BEST: pop={best['population_size']}  gen={best['generations']}  "
              f"sa_steps={best['sa_steps']}  t_start={best['sa_t_start']}")
        print(f"    Fitness={best['avg_fitness']:.4f}±{best['std_fitness']:.4f}  "
              f"Latency={best['avg_latency_ms']:.1f}ms  [{note}]")
        print("=" * 78 + "\n")

    return best, results


def save_best_params(best: dict, path: str = None) -> str:
    """Save the best sweep result to a JSON file for the backend to load."""
    import json
    from pathlib import Path
    if path is None:
        path = str(Path(__file__).parent / "ga_sa_best_params.json")
    params = {
        "population_size": best["population_size"],
        "generations": best["generations"],
        "sa_steps": best["sa_steps"],
        "sa_t_start": best["sa_t_start"],
        "sa_t_end": best["sa_t_end"],
        "avg_fitness": best["avg_fitness"],
        "avg_latency_ms": best["avg_latency_ms"],
    }
    Path(path).write_text(json.dumps(params, indent=2))
    return path


def load_best_params(path: str = None) -> dict:
    """Load previously saved best params, or return safe defaults."""
    import json
    from pathlib import Path
    if path is None:
        path = str(Path(__file__).parent / "ga_sa_best_params.json")
    defaults = {
        "population_size": 20,
        "generations": 20,
        "sa_steps": 60,
        "sa_t_start": 80.0,
        "sa_t_end": 0.5,
    }
    try:
        data = json.loads(Path(path).read_text())
        # Only keep the keys we need for optimize_water_allocations
        return {k: data[k] for k in defaults if k in data}
    except Exception:
        return defaults