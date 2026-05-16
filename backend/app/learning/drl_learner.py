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
import gym
import numpy as np
import os

MODEL_DIR = os.path.join(os.path.dirname(__file__), "..", "models")


class SymbiosisEnv(gym.Env):
    """Minimal simulated environment for training allocation policies.
    State: concatenated vector of plant moistures, tank level, remaining light.
    Action: continuous allocation vector [water_p1, water_p2, ..., light_p1, ...]
    Reward: sum of health gains minus water/light penalty.
    This environment is intentionally simple and should be replaced with a
    higher-fidelity simulator for production training.
    """
    metadata = {"render.modes": []}

    def __init__(self, n_plants: int = 2, tank_capacity_ml: float = 5000.0, max_light_min: int = 120):
        super().__init__()
        self.n = n_plants
        self.tank = tank_capacity_ml
        self.max_light = max_light_min
        # observation: moistures + tank + light_remaining
        low = np.array([0.0] * (self.n + 2), dtype=np.float32)
        high = np.array([100.0] * self.n + [self.tank, float(self.max_light)], dtype=np.float32)
        self.observation_space = gym.spaces.Box(low=low, high=high, dtype=np.float32)
        # action: continuous allocations water_ml for each plant and light_minutes
        a_low = np.array([0.0] * (2 * self.n), dtype=np.float32)
        a_high = np.array([self.tank] * self.n + [float(self.max_light)] * self.n, dtype=np.float32)
        self.action_space = gym.spaces.Box(low=a_low, high=a_high, dtype=np.float32)
        self.reset()

    def reset(self):
        # random initial moistures
        self.moistures = np.random.uniform(20.0, 70.0, size=(self.n,))
        self.tank_level = self.tank
        self.light_rem = self.max_light
        return self._get_obs()

    def _get_obs(self):
        return np.concatenate([self.moistures, [self.tank_level, self.light_rem]]).astype(np.float32)

    def step(self, action):
        # clip action to available budgets
        w = np.clip(action[: self.n], 0.0, self.tank)
        l = np.clip(action[self.n :], 0.0, self.light_rem)
        # apply actions: water increases moisture, light has small effect in reward
        for i in range(self.n):
            self.moistures[i] = min(100.0, self.moistures[i] + w[i] * 0.02)
        # consume tank and light
        self.tank_level = max(0.0, self.tank_level - w.sum())
        self.light_rem = max(0.0, self.light_rem - l.sum())
        # compute reward: simple health increase minus penalties
        health_gain = np.sum(np.exp(-0.5 * ((self.moistures - 50.0) / 10.0) ** 2))
        penalty = 0.01 * w.sum() + 0.001 * l.sum()
        reward = float(health_gain - penalty)
        done = False
        info = {}
        obs = self._get_obs()
        return obs, reward, done, info


def train_a2c(total_timesteps: int = 10000, n_envs: int = 4):
    env = make_vec_env(lambda: SymbiosisEnv(n_plants=2), n_envs=n_envs)
    model = A2C('MlpPolicy', env, verbose=1, policy_kwargs={"net_arch": [64, 64]})
    cb = CheckpointCallback(save_freq=2000, save_path=MODEL_DIR, name_prefix="a2c_symbiosis")
    model.learn(total_timesteps=total_timesteps, callback=cb)
    os.makedirs(MODEL_DIR, exist_ok=True)
    model.save(os.path.join(MODEL_DIR, "a2c_symbiosis_final"))
    return model


if __name__ == '__main__':
    train_a2c()
