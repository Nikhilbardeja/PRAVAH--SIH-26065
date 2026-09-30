from api.endpoints.fleet import bp as fleet_bp
from api.endpoints.latest import bp as latest_bp
from api.endpoints.history import bp as history_bp
from api.endpoints.comparison import bp as comparison_bp
from api.endpoints.interpretation import bp as interpretation_bp

ALL_BLUEPRINTS = [
    fleet_bp,
    latest_bp,
    history_bp,
    comparison_bp,
    interpretation_bp,
]

__all__ = ["ALL_BLUEPRINTS"]
