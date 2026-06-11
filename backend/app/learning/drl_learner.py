"""DRL Learner (A2C) scaffold for Symbiosis.

This module provides a training harness using Advantage Actor-Critic (A2C)
from stable-baselines3. Training runs on the backend in a simulated
environment. The saved policy (small network) can be loaded by the
Coordinator for fast action selection.

Citation: Advantage Actor-Critic has been applied to irrigation scheduling
(Alibabaei et al., 2022).
"""
from stable_baselines3 import A2C
from stable_baselines3.common.env_util import make_vec_env
from stable_baselines3.common.callbacks import CheckpointCallback
import gymnasium as gym
import numpy as np
import os

MODEL_DIR = os.path.join(os.path.dirname(__file__), "..", "models")


class SymbiosisEnv(gym.Env):
    """Calibrated simulation environment for SYMBIOSIS A2C training.

    Matches the species parameters and day/night ET profile from the
    experimental results (Basil optimal=65%, Coleus optimal=45%).

    State (5-dim):
        [basil_moisture, coleus_moisture, temperature_c, humidity_pct, tank_pct]
    Action (2-dim continuous):
        [basil_water_ml, coleus_water_ml]  (clipped to budget)
    Reward:
        Gaussian satisfaction for both plants, penalised for water waste
        and large negative penalty if either plant goes critical.
    """
    metadata = {"render_modes": []}

    # Species parameters matching PDF Table 1
    SPECIES = [
        {"optimal": 65.0, "m_crit": 30.0, "sigma": 16.25, "gamma": 0.031},  # Basil
        {"optimal": 45.0, "m_crit": 25.0, "sigma": 11.25, "gamma": 0.024},  # Coleus
    ]

    # Diurnal ET profile: (hour, depletion_rate_per_30min_per_plant) × base
    ET_PROFILE = [
        (0,  0.35), (4,  0.28), (6,  0.38), (8,  0.55),
        (10, 0.72), (12, 0.95), (14, 1.05), (16, 0.90),
        (18, 0.62), (20, 0.45), (22, 0.38), (24, 0.35),
    ]

    def __init__(
        self,
        n_plants: int = 2,
        tank_capacity_ml: float = 5000.0,
        steps_per_episode: int = 48,   # one full day = 48 half-hourly cycles
        day_variety: bool = True,       # randomise starting conditions
    ):
        super().__init__()
        self.n = n_plants
        self.tank_capacity = tank_capacity_ml
        self.steps_per_episode = steps_per_episode
        self.day_variety = day_variety

        # Observation: [m1, m2, temp, humidity, tank_pct]
        obs_low  = np.array([0.0,  0.0,  15.0, 20.0, 0.0],   dtype=np.float32)
        obs_high = np.array([100.0, 100.0, 40.0, 90.0, 100.0], dtype=np.float32)
        self.observation_space = gym.spaces.Box(obs_low, obs_high, dtype=np.float32)

        # Action: water_ml for each plant, normalised to [0, 1] × max_alloc
        self.max_alloc_per_plant = 200.0
        act_low  = np.zeros(self.n, dtype=np.float32)
        act_high = np.ones(self.n,  dtype=np.float32)
        self.action_space = gym.spaces.Box(act_low, act_high, dtype=np.float32)

        self._step = 0
        self.moistures = np.zeros(self.n)
        self.tank_level = tank_capacity_ml
        self.reset()

    def _et_rate(self, hour: float) -> float:
        """Interpolate evapotranspiration rate at given hour of day."""
        profile = self.ET_PROFILE
        for i in range(len(profile) - 1):
            h0, r0 = profile[i]
            h1, r1 = profile[i + 1]
            if h0 <= hour <= h1:
                return r0 + (r1 - r0) * (hour - h0) / (h1 - h0)
        return profile[-1][1]

    def _env_obs(self, hour: float):
        """Simulated temperature and humidity based on hour."""
        temp = 22.0 + 5.0 * math.sin(math.pi * (hour - 6) / 12)
        humidity = 65.0 - 10.0 * math.sin(math.pi * (hour - 6) / 12)
        return round(temp, 1), round(humidity, 1)

    def reset(self, seed=None, options=None):
        if seed is not None:
            np.random.seed(seed)
        self._step = 0
        if self.day_variety:
            # Sample from the realistic range seen across 14 days
            self.moistures = np.array([
                np.random.uniform(45.0, 68.0),  # Basil
                np.random.uniform(38.0, 48.0),  # Coleus
            ], dtype=np.float64)
            tank_pct = np.random.uniform(50.0, 100.0)
        else:
            self.moistures = np.array([62.4, 44.1], dtype=np.float64)
            tank_pct = 100.0
        self.tank_level = tank_pct / 100.0 * self.tank_capacity
        obs = self._get_obs()
        return obs, {}

    def _get_obs(self):
        hour = (8.0 + self._step * 0.5) % 24
        temp, humidity = self._env_obs(hour)
        return np.array([
            self.moistures[0],
            self.moistures[1],
            temp,
            humidity,
            self.tank_level / self.tank_capacity * 100.0,
        ], dtype=np.float32)

    def step(self, action):
        hour = (8.0 + self._step * 0.5) % 24
        temp, humidity = self._env_obs(hour)
        et_mult = self._et_rate(hour)

        # Stress multipliers (temperature and humidity)
        temp_stress = 1.0 + max(0.0, (temp - 22.0) / 25.0)
        hum_stress  = 1.0 + max(0.0, (65.0 - humidity) / 100.0)
        env_stress  = temp_stress * hum_stress

        # Apply evapotranspiration depletion
        depletion = np.array([
            self.SPECIES[i]["optimal"] * 0.022 * et_mult * env_stress
            for i in range(self.n)
        ])
        self.moistures -= depletion
        self.moistures = np.maximum(0.0, self.moistures)

        # Convert normalised action [0,1] to ml, clipped to budget
        tank_pct = self.tank_level / self.tank_capacity * 100.0
        if tank_pct > 60:
            budget = 180.0
        elif tank_pct > 30:
            budget = 130.0
        elif tank_pct > 10:
            budget = 80.0
        else:
            budget = 0.0

        water_ml = np.clip(action, 0.0, 1.0) * self.max_alloc_per_plant
        total_req = water_ml.sum()
        if total_req > budget and total_req > 0:
            water_ml = water_ml / total_req * budget

        # Apply irrigation
        for i in range(self.n):
            gain = water_ml[i] * self.SPECIES[i]["gamma"]
            self.moistures[i] = min(95.0, self.moistures[i] + gain)
        self.tank_level = max(0.0, self.tank_level - water_ml.sum())

        # Reward computation
        reward = 0.0
        critical_penalty = 0.0
        for i in range(self.n):
            sp = self.SPECIES[i]
            sat = math.exp(-0.5 * ((self.moistures[i] - sp["optimal"]) / sp["sigma"]) ** 2)
            reward += sat

            # Large penalty for going critical
            if self.moistures[i] < sp["m_crit"]:
                critical_penalty += 2.0
            # Smaller penalty for going below 70% of optimal
            elif self.moistures[i] < sp["optimal"] * 0.70:
                critical_penalty += 0.3

        reward = (reward / self.n) - critical_penalty

        # Water efficiency penalty (discourage over-watering)
        total_water = water_ml.sum()
        efficiency_penalty = max(0.0, total_water - 150.0) * 0.001
        reward -= efficiency_penalty

        self._step += 1
        terminated = self._step >= self.steps_per_episode
        truncated = False
        obs = self._get_obs()
        info = {
            "basil_moisture": self.moistures[0],
            "coleus_moisture": self.moistures[1],
            "water_used_ml": total_water,
            "tank_pct": self.tank_level / self.tank_capacity * 100.0,
        }
        return obs, reward, terminated, truncated, info


def train_a2c(
    total_timesteps: int = 200_000,
    n_envs: int = 8,
    learning_rate: float = 7e-4,
    save_dir: str = None,
):
    """Train A2C with calibrated hyperparameters.

    Hyperparameter targets (from PDF Day 1→14 reward table):
      - Reward improves from ~0.218 → ~0.414 (+89.9%) over 14 simulated days
      - Each "day" ≈ 48 steps × n_envs = ~384 transitions
      - total_timesteps=200k gives ~520 episodes ≈ enough for convergence

    Args:
        total_timesteps: Training steps. 200k for paper results; use 50k for quick test.
        n_envs: Parallel environments. 8 is good for Colab T4.
        learning_rate: A2C step size. 7e-4 is the SB3 default; keep unless reward flat.
        save_dir: Where to save checkpoints. Defaults to app/ml/models/.
    """
    if save_dir is None:
        save_dir = MODEL_DIR
    os.makedirs(save_dir, exist_ok=True)

    env = make_vec_env(
        lambda: SymbiosisEnv(n_plants=2, steps_per_episode=48, day_variety=True),
        n_envs=n_envs,
    )

    model = A2C(
        "MlpPolicy",
        env,
        verbose=1,
        learning_rate=learning_rate,
        n_steps=48,            # one full day per rollout
        gamma=0.99,
        gae_lambda=0.95,
        ent_coef=0.01,         # entropy bonus encourages exploration
        vf_coef=0.5,
        max_grad_norm=0.5,
        policy_kwargs={
            "net_arch": [128, 128],   # wider than original 64,64
            "activation_fn": __import__("torch").nn.Tanh,
        },
        tensorboard_log=os.path.join(save_dir, "tensorboard"),
    )

    cb = CheckpointCallback(
        save_freq=10_000,
        save_path=save_dir,
        name_prefix="a2c_symbiosis",
    )
    model.learn(total_timesteps=total_timesteps, callback=cb, progress_bar=True)
    model.save(os.path.join(save_dir, "a2c_symbiosis_final"))
    print(f"Model saved → {save_dir}/a2c_symbiosis_final.zip")
    return model


if __name__ == '__main__':
    train_a2c()
