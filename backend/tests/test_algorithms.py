import math
import numpy as np
from app.agents.plant_agent import PlantAgent
from app.models.domain import PlantProfile, SensorReading
from app.agents.resource_agent import EKFPlantFilter
from app.algorithms.metaheuristic_optimizer import optimize_bundle_allocations


def test_marginal_gain_and_requested_water():
    profile = PlantProfile(
        plant_id="p1",
        common_name="Test",
        species="Testus plantus",
        optimal_moisture=50.0,
        light_value=5.0,
        moisture_value=5.0,
        dli_requirement=5.0,
    )
    agent = PlantAgent(profile)
    # current moisture low -> high marginal gain
    mg1 = agent.marginal_gain(30.0, 10.0)
    mg2 = agent.marginal_gain(45.0, 10.0)
    assert mg1 > mg2
    req = agent.compute_requested_water(0.64)
    assert 0 <= req <= 200.0


def test_ekf_predict_time_to_critical():
    f = EKFPlantFilter(initial_moisture=40.0)
    # set a negative rate so prediction finite
    f.x = np.array([40.0, -2.0])
    t = f.predict_time_to_critical(20.0)
    assert t > 0


def test_optimizer_trivial():
    # two plants, trivial utility: prefer water for plant 0
    def util(w, l):
        return 2.0 * math.sqrt(w[0]) + 1.0 * math.sqrt(w[1]) + 0.0

    w, l, score = optimize_bundle_allocations(2, 100.0, 60.0, util, population_size=10, generations=5)
    assert abs(w.sum() - 100.0) < 1e-3
    assert abs(l.sum() - 60.0) < 1e-3
