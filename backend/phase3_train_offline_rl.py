"""
Phase 3: Offline A2C Training using GA-SA demonstrations (Behavior Cloning + Fine-tuning)
Run from backend/ with:
    python phase3_train_offline_rl.py
"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))

import numpy as np
import pandas as pd
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
from pathlib import Path
import csv
import gymnasium as gym
from gymnasium import spaces

DATA_PATH = Path("offline_rl_project/data/ga_sa_demonstrations.csv")
MODEL_DIR = Path("offline_rl_project/models")
LOG_PATH = Path("offline_rl_project/logs/training_log.csv")
MODEL_DIR.mkdir(parents=True, exist_ok=True)
LOG_PATH.parent.mkdir(parents=True, exist_ok=True)

STATE_DIM = 8
ACTION_DIM = 2
HIDDEN = [128, 128]
LR = 3e-4
BATCH_SIZE = 32
EPOCHS = 200
EARLY_STOP_PATIENCE = 20
L2_WEIGHT_DECAY = 1e-4

STATE_COLS = [
    'plant_1_moisture_ekf', 'plant_2_moisture_ekf',
    'plant_1_deficit', 'plant_2_deficit',
    'temp_c', 'humidity_pct', 'light_lux', 'tank_level_pct'
]
ACTION_COLS = ['plant_1_alloc_ml', 'plant_2_alloc_ml']


# ============================================
# Step 1: Behavior Cloning Dataset
# ============================================

class BCDataset(Dataset):
    def __init__(self, df, state_mean=None, state_std=None, augment=False):
        self.augment = augment
        self.states_raw = df[STATE_COLS].values.astype(np.float32)
        self.actions = df[ACTION_COLS].values.astype(np.float32) / 200.0

        # Fit normalization on this split (or use provided stats for val)
        if state_mean is None:
            self.state_mean = self.states_raw.mean(axis=0)
            self.state_std = self.states_raw.std(axis=0) + 1e-8
        else:
            self.state_mean = state_mean
            self.state_std = state_std

        self.states = (self.states_raw - self.state_mean) / self.state_std

    def __len__(self):
        return len(self.states)

    def __getitem__(self, idx):
        state = self.states[idx].copy()
        action = self.actions[idx].copy()
        if self.augment:
            # Add small Gaussian noise to states (data augmentation)
            state += np.random.normal(0, 0.03, state.shape).astype(np.float32)
            # Small noise on actions too
            action = np.clip(action + np.random.normal(0, 0.01, action.shape), 0, 1).astype(np.float32)
        return torch.tensor(state), torch.tensor(action)


class A2CPolicy(nn.Module):
    def __init__(self, state_dim=STATE_DIM, action_dim=ACTION_DIM, hidden=HIDDEN):
        super().__init__()
        layers = []
        prev = state_dim
        for h in hidden:
            layers.append(nn.Linear(prev, h))
            layers.append(nn.LayerNorm(h))   # LayerNorm instead of just Dropout
            layers.append(nn.ReLU())
            layers.append(nn.Dropout(0.3))   # Increased dropout
            prev = h
        layers.append(nn.Linear(prev, action_dim))
        layers.append(nn.Sigmoid())

        self.net = nn.Sequential(*layers)
    
    def forward(self, x):
        return self.net(x)
    
    def predict(self, state, denormalize=True):
        """Predict action from state (for inference)."""
        self.eval()
        with torch.no_grad():
            # Normalize state
            if isinstance(state, np.ndarray):
                state = torch.tensor(state, dtype=torch.float32)
            if state.dim() == 1:
                state = state.unsqueeze(0)
            action_norm = self.forward(state)
            action = action_norm * 200.0 if denormalize else action_norm
        return action.squeeze().numpy()


# ============================================
# Step 2: Behavior Cloning Training
# ============================================

def train_behavior_cloning(df):
    """Step 1: Train A2C policy via supervised learning (Behavior Cloning)."""
    
    # Split by day
    train_df = df[df['day'] <= 10].copy()
    val_df = df[(df['day'] == 11) | (df['day'] == 12)].copy()
    
    train_dataset = BCDataset(train_df, augment=True)
    # Val uses train's normalization stats — no augmentation
    val_dataset = BCDataset(val_df,
                            state_mean=train_dataset.state_mean,
                            state_std=train_dataset.state_std,
                            augment=False)
    
    train_loader = DataLoader(train_dataset, batch_size=BATCH_SIZE, shuffle=True)
    val_loader = DataLoader(val_dataset, batch_size=BATCH_SIZE, shuffle=False)
    
    model = A2CPolicy()
    optimizer = optim.Adam(model.parameters(), lr=LR, weight_decay=L2_WEIGHT_DECAY)
    criterion = nn.MSELoss()
    early_stop_counter = 0
    
    print("\n" + "=" * 60)
    print("STEP 1: Behavior Cloning (Supervised Learning)")
    print("=" * 60)
    print(f"Train samples: {len(train_dataset)}")
    print(f"Val samples: {len(val_dataset)}")
    
    best_val_loss = float('inf')
    early_stop_counter = 0
    log_rows = []

    for epoch in range(1, EPOCHS + 1):
        # Training
        model.train()
        train_loss = 0
        for states, actions in train_loader:
            optimizer.zero_grad()
            preds = model(states)
            loss = criterion(preds, actions)
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
            optimizer.step()
            train_loss += loss.item()

        # Validation
        model.eval()
        val_loss = 0
        with torch.no_grad():
            for states, actions in val_loader:
                preds = model(states)
                val_loss += criterion(preds, actions).item()

        train_loss /= len(train_loader)
        val_loss /= len(val_loader)

        log_rows.append({
            'epoch': epoch,
            'train_loss': round(train_loss, 6),
            'val_loss': round(val_loss, 6)
        })

        if epoch % 10 == 0 or epoch == 1:
            print(f"  Epoch {epoch:3d}: train_loss={train_loss:.6f}, val_loss={val_loss:.6f}")

        # Save best model + early stopping
        if val_loss < best_val_loss:
            best_val_loss = val_loss
            early_stop_counter = 0
            torch.save({
                'epoch': epoch,
                'model_state_dict': model.state_dict(),
                'val_loss': val_loss,
                'state_mean': train_dataset.state_mean,
                'state_std': train_dataset.state_std
            }, MODEL_DIR / 'a2c_bc_best.pt')
        else:
            early_stop_counter += 1
            if early_stop_counter >= EARLY_STOP_PATIENCE:
                print(f"\n  Early stopping at epoch {epoch} (no improvement for {EARLY_STOP_PATIENCE} epochs)")
                break
    
    # Save training log
    with open(LOG_PATH, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=['epoch', 'train_loss', 'val_loss'])
        writer.writeheader()
        writer.writerows(log_rows)
    
    print(f"\n✓ Behavior Cloning complete!")
    print(f"  Best val loss: {best_val_loss:.6f}")
    print(f"  Model saved to: {MODEL_DIR}/a2c_bc_best.pt")
    
    return model, train_dataset.state_mean, train_dataset.state_std


# ============================================
# Step 3: Fine-tuning Environment (Optional)
# ============================================

class FineTuneEnv(gym.Env):
    """Environment for fine-tuning A2C with rewards."""
    
    def __init__(self, df, state_mean, state_std):
        super().__init__()
        self.df = df.reset_index(drop=True)
        self.state_mean = state_mean
        self.state_std = state_std
        
        self.observation_space = spaces.Box(
            low=-np.inf, high=np.inf, shape=(STATE_DIM,), dtype=np.float32
        )
        self.action_space = spaces.Box(
            low=0, high=1, shape=(ACTION_DIM,), dtype=np.float32
        )
        
        self.current_idx = 0
    
    def reset(self, seed=None, options=None):
        super().reset(seed=seed)
        # Start at random day
        days = self.df['day'].unique()
        random_day = np.random.choice(days)
        day_df = self.df[self.df['day'] == random_day]
        self.current_idx = day_df.index[0]
        return self._get_state(), {}
    
    def _get_state(self):
        row = self.df.iloc[self.current_idx]
        state = np.array([row[col] for col in STATE_COLS], dtype=np.float32)
        # Normalize
        state = (state - self.state_mean) / self.state_std
        return state
    
    def step(self, action):
        """Return reward from GA-SA demonstration."""
        row = self.df.iloc[self.current_idx]
        
        # Get GA-SA action
        ga_sa_action = np.array([row[col] for col in ACTION_COLS], dtype=np.float32) / 200.0
        
        # Reward: how close is our action to GA-SA's action?
        action_diff = np.mean((action - ga_sa_action) ** 2)
        reward = max(0, 1.0 - action_diff * 2)  # Reward between 0 and 1
        
        # Also use the environment reward
        env_reward = float(row['reward'])
        combined_reward = 0.5 * reward + 0.5 * env_reward
        
        # Move to next
        self.current_idx += 1
        if self.current_idx >= len(self.df):
            self.current_idx = 0
        
        done = self.df.iloc[self.current_idx]['cycle'] == 1
        
        return self._get_state(), combined_reward, done, False, {}


def fine_tune_a2c(model, df, state_mean, state_std, timesteps=20000):
    """Step 2: Fine-tune with A2C (requires stable-baselines3)."""
    try:
        from stable_baselines3 import A2C
        from stable_baselines3.common.env_util import make_vec_env
        
        print("\n" + "=" * 60)
        print("STEP 2: Fine-tuning with A2C (Optional)")
        print("=" * 60)
        
        # Create environment
        env = FineTuneEnv(df, state_mean, state_std)
        
        # Create A2C model
        a2c_model = A2C(
            'MlpPolicy',
            env,
            verbose=1,
            learning_rate=1e-4,
            n_steps=64,
            gamma=0.99,
            policy_kwargs={'net_arch': [256, 256]}
        )
        
        # Train
        a2c_model.learn(total_timesteps=timesteps, progress_bar=True)
        
        # Save
        a2c_model.save(str(MODEL_DIR / "a2c_finetuned"))
        print(f"\n✓ Fine-tuned model saved to {MODEL_DIR}/a2c_finetuned.zip")
        
        return a2c_model
        
    except ImportError:
        print("\n⚠️ stable-baselines3 not installed. Skipping fine-tuning.")
        print("  Install with: pip install stable-baselines3")
        return None


# ============================================
# Main Execution
# ============================================

def main():
    print("=" * 60)
    print("OFFLINE A2C TRAINING FROM GA-SA DEMONSTRATIONS")
    print("=" * 60)
    
    # Load data
    df = pd.read_csv(DATA_PATH)
    print(f"\nLoaded {len(df)} rows from {DATA_PATH}")
    
    # Step 1: Behavior Cloning
    model, state_mean, state_std = train_behavior_cloning(df)
    
    # Save normalization parameters for inference
    np.save(MODEL_DIR / "state_mean.npy", state_mean)
    np.save(MODEL_DIR / "state_std.npy", state_std)
    
    # Step 2: Fine-tuning (optional)
    fine_tune_a2c(model, df, state_mean, state_std, timesteps=10000)
    
    # Save final model in scripted format for production
    model.eval()
    scripted_model = torch.jit.script(model)
    scripted_model.save(str(MODEL_DIR / "a2c_policy_scripted.pt"))
    
    # Also save as pickle for easy loading
    torch.save({
        'model_state_dict': model.state_dict(),
        'state_mean': state_mean,
        'state_std': state_std
    }, MODEL_DIR / "a2c_final.pt")
    
    print("\n" + "=" * 60)
    print("✅ TRAINING COMPLETE!")
    print("=" * 60)
    print(f"  BC Model:      {MODEL_DIR}/a2c_bc_best.pt")
    print(f"  Final Model:   {MODEL_DIR}/a2c_final.pt")
    print(f"  Scripted:      {MODEL_DIR}/a2c_policy_scripted.pt")
    print(f"  Training log:  {LOG_PATH}")


if __name__ == "__main__":
    main()