import pytest
from app.agents.plant_agent import PlantAgent, EMERGENCY_MOISTURE_PCT
from app.models.domain import PlantProfile, SensorReading, ResourceType, HealthStatus


@pytest.fixture
def basil_profile():
    return PlantProfile(
        plant_id="plant_1",
        common_name="Basil",
        species="Ocimum basilicum",
        optimal_moisture=60.0,
        light_value=8,
        moisture_value=6,
        dli_requirement=20.0,
        species_weight=1.0,
    )


@pytest.fixture
def agent(basil_profile):
    return PlantAgent(basil_profile)


def make_reading(moisture=50.0, light=3000.0, sensor_ok=True):
    return SensorReading(
        plant_id="plant_1",
        moisture_pct=moisture,
        light_lux=light,
        sensor_ok=sensor_ok,
    )


# ── Health status ─────────────────────────────────────────────────────────────

def test_critical_health_when_moisture_below_threshold(agent):
    reading = make_reading(moisture=EMERGENCY_MOISTURE_PCT - 1)
    assert agent.health_status(reading) == HealthStatus.CRITICAL


def test_low_health_below_50pct_optimal(agent):
    # optimal=60, 50% of that = 30 → moisture 25 should be LOW
    reading = make_reading(moisture=25.0)
    assert agent.health_status(reading) == HealthStatus.LOW


def test_good_health_above_optimal(agent):
    reading = make_reading(moisture=65.0)
    assert agent.health_status(reading) == HealthStatus.GOOD


def test_failed_sensor_returns_normal_health(agent):
    # Should not act on bad data — returns NORMAL as safe default
    reading = make_reading(sensor_ok=False)
    assert agent.health_status(reading) == HealthStatus.NORMAL


# ── Request generation ────────────────────────────────────────────────────────

def test_no_requests_when_sensor_failed(agent):
    reading = make_reading(sensor_ok=False)
    assert agent.generate_requests(reading) == []


def test_water_request_generated_when_dry(agent):
    reading = make_reading(moisture=10.0)
    requests = agent.generate_requests(reading)
    water = [r for r in requests if r.resource == ResourceType.WATER]
    assert len(water) == 1


def test_critical_plant_gets_max_urgency(agent):
    reading = make_reading(moisture=EMERGENCY_MOISTURE_PCT - 1)
    requests = agent.generate_requests(reading)
    water = [r for r in requests if r.resource == ResourceType.WATER]
    assert water[0].urgency == 1.0


def test_no_water_request_when_above_optimal(agent):
    # moisture 65 > optimal 60 → water deficit = 0 → no request
    reading = make_reading(moisture=65.0)
    requests = agent.generate_requests(reading)
    water = [r for r in requests if r.resource == ResourceType.WATER]
    assert len(water) == 0


def test_light_request_generated_when_dark(agent):
    # Very low lux → large light deficit
    reading = make_reading(moisture=65.0, light=100.0)
    requests = agent.generate_requests(reading)
    light = [r for r in requests if r.resource == ResourceType.LIGHT]
    assert len(light) == 1


def test_water_requested_amount_proportional_to_deficit(agent):
    reading = make_reading(moisture=0.0)   # 100% deficit
    requests = agent.generate_requests(reading)
    water = [r for r in requests if r.resource == ResourceType.WATER]
    # deficit=1.0 → requested_amount = 1.0 * 200 = 200ml
    assert water[0].requested_amount == pytest.approx(200.0)


# ── Utility function ──────────────────────────────────────────────────────────

def test_utility_increases_with_deficit(agent):
    low_deficit = agent.compute_utility(0.2)
    high_deficit = agent.compute_utility(0.8)
    assert high_deficit > low_deficit


def test_utility_uses_learned_k_param(basil_profile):
    basil_profile.utility_params = {"k": 3.0}
    agent = PlantAgent(basil_profile)
    # With k=3 utility at deficit=0.5 should be 0.5^3 = 0.125
    assert agent.compute_utility(0.5) == pytest.approx(0.125, rel=1e-3)


# ── DLI / Ellenberg dataset integration ──────────────────────────────────────

def test_light_deficit_reflects_species_light_value(basil_profile):
    """Basil has light_value=8 → target 8000 lux. At 4000 lux deficit should be ~0.5"""
    agent = PlantAgent(basil_profile)
    reading = make_reading(light=4000.0)
    deficit = agent.light_deficit(reading)
    assert 0.45 < deficit < 0.55


def test_fern_lower_light_target():
    """Lady Fern light_value=5 → target 5000 lux. Same lux = lower deficit than Basil."""
    fern = PlantProfile(
        plant_id="plant_2",
        common_name="Lady Fern",
        species="Athyrium filix-femina",
        optimal_moisture=75.0,
        light_value=5,
        moisture_value=7,
        dli_requirement=12.0,
        species_weight=1.0,
    )
    basil = PlantProfile(
        plant_id="plant_1",
        common_name="Basil",
        species="Ocimum basilicum",
        optimal_moisture=60.0,
        light_value=8,
        moisture_value=6,
        dli_requirement=20.0,
        species_weight=1.0,
    )
    lux = 4000.0
    fern_deficit = PlantAgent(fern).light_deficit(make_reading(light=lux))
    basil_deficit = PlantAgent(basil).light_deficit(make_reading(light=lux))
    # Basil needs more light → larger deficit at same lux
    assert basil_deficit > fern_deficit