from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    mongo_uri: str = "mongodb://localhost:27017"
    mongo_db_name: str = "symbiosis"
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    log_level: str = "INFO"
    coordinator_interval_seconds: int = 30

    # Hardware bridge — optional until Arduino is wired up
    arduino_port: str | None = None
    arduino_baud_rate: int = 9600
    tank_capacity_ml: int = 5000
    light_window_minutes: int = 120

    # EKF / Kalman params
    ekf_process_q_moisture: float = 0.5
    ekf_process_q_rate: float = 0.01
    ekf_measure_r: float = 2.0

    # Metaheuristic params
    ga_population_size: int = 20
    ga_generations: int = 20
    ga_early_stop_delta: float = 0.01
    synergy_coefficient: float = 0.001

    # DRL toggle
    use_drl: bool = False

    # Prediction thresholds
    tank_warning_hours: int = 6
    plant_warning_hours: int = 2

    # Nominal consumption estimate used for tank prediction (ml/hour)
    nominal_consumption_ml_per_hour: float = 50.0


settings = Settings()