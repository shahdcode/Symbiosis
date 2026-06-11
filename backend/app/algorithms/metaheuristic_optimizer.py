"""Hybrid GA + SA optimizer for water allocation.
backend/app/algorithms/metaheuristic_optimizer.py
Allocates water (ml) to N plants subject to a total water budget.
Light is informational only and is NOT allocated here.

Citation: Combinatorial auction + metaheuristic (Parkes & Ungar, 2000).
"""
from typing import Callable, Tuple
import random
import math
import numpy as np


def optimize_water_allocations(
    n_plants: int,
    water_budget: float,
    utility_fn: Callable[[np.ndarray], float],
    population_size: int = 30,
    generations: int = 50,
    max_per_plant: np.ndarray | None = None,
    sa_steps: int = 60,
    sa_t_start: float = 80.0,
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
# repair: clip to [0, cap] then scale down if over budget
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
            best, best_score, fitness, water_budget, n_plants, caps=caps,
            sa_steps=sa_steps, t_start=sa_t_start, t_end=sa_t_end,
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
) -> Tuple[np.ndarray, float]:
    """SA perturbation loop that respects the water budget and per-plant caps."""
    if caps is None:
        caps = np.full(n_plants, water_budget)
    ind = individual.copy()
    current_score = score
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