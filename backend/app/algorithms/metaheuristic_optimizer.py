"""Hybrid GA + SA optimizer for combinatorial bundle allocation.

This module provides a continuous optimisation routine to allocate water (ml)
and light (minutes) to N plants subject to total water and light budgets.

Citation: Combinatorial auction + metaheuristic (Parkes & Ungar, 2000).
"""
from typing import Callable, Tuple
import random
import math
import numpy as np


def optimize_bundle_allocations(
    n_plants: int,
    water_budget: float,
    light_budget: float,
    utility_fn: Callable[[np.ndarray, np.ndarray], float],
    population_size: int = 30,
    generations: int = 50,
    alpha: float = 0.5,
) -> Tuple[np.ndarray, np.ndarray, float]:
    """Return (water_allocs, light_allocs, best_fitness)

    utility_fn takes two numpy arrays (w, l) and returns scalar fitness.
    """
    # initialise population: each individual is concatenated [w1..wn, l1..ln]
    def random_individual():
        # sample proportions then scale to budgets
        w_props = np.random.dirichlet(np.ones(n_plants))
        l_props = np.random.dirichlet(np.ones(n_plants))
        w = w_props * water_budget
        l = l_props * light_budget
        return np.concatenate([w, l])

    pop = [random_individual() for _ in range(population_size)]

    def fitness(ind):
        w = ind[:n_plants]
        l = ind[n_plants:]
        return utility_fn(w, l)

    best = max(pop, key=fitness)
    best_score = fitness(best)

    for g in range(generations):
        # tournament selection
        new_pop = []
        while len(new_pop) < population_size:
            a, b = random.sample(pop, 2)
            parent = a if fitness(a) > fitness(b) else b
            # crossover
            mate = random.choice(pop)
            cut = random.randint(1, 2 * n_plants - 1)
            child = np.concatenate([parent[:cut], mate[cut:]])
            # mutation: perturb one gene and repair
            idx = random.randrange(2 * n_plants)
            child[idx] *= (1.0 + random.uniform(-0.2, 0.2))
            # repair: rescale to budgets
            w = child[:n_plants]
            l = child[n_plants:]
            # avoid negatives
            w = np.clip(w, 0.0, None)
            l = np.clip(l, 0.0, None)
            if w.sum() > 0:
                w = w / w.sum() * water_budget
            else:
                w = np.zeros_like(w)
            if l.sum() > 0:
                l = l / l.sum() * light_budget
            else:
                l = np.zeros_like(l)
            child = np.concatenate([w, l])
            new_pop.append(child)
        pop = new_pop

        # evaluate and keep best
        for ind in pop:
            s = fitness(ind)
            if s > best_score:
                best = ind.copy()
                best_score = s
        # Simulated annealing local refinement on best
        best, best_score = _simulated_annealing_local(best, best_score, fitness)
    w_best = best[:n_plants]
    l_best = best[n_plants:]
    return w_best, l_best, best_score


def _simulated_annealing_local(individual: np.ndarray, score: float, fitness_fn: Callable) -> Tuple[np.ndarray, float]:
    ind = individual.copy()
    current_score = score
    T = 100.0
    for i in range(20):
        # propose small perturbation
        prop = ind.copy()
        idx = random.randrange(len(ind))
        prop[idx] *= (1.0 + random.uniform(-0.3, 0.3))
        # ensure non-negative
        prop = np.clip(prop, 0.0, None)
        # repair proportions separately for water and light
        n = len(ind) // 2
        w = prop[:n]
        l = prop[n:]
        # if sums zero, skip
        if w.sum() > 0:
            w = w / w.sum() * ind[:n].sum()
        if l.sum() > 0:
            l = l / l.sum() * ind[n:].sum()
        prop = np.concatenate([w, l])
        prop_score = fitness_fn(prop)
        if prop_score > current_score or math.exp((prop_score - current_score) / T) > random.random():
            ind = prop
            current_score = prop_score
        T *= 0.95
    return ind, current_score
