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


settings = Settings()