from flask import Flask, jsonify

from services import config                    # must be first: sets sys.path + DB path
from services.engine import engine
from api.endpoints import ALL_BLUEPRINTS


def create_app() -> Flask:
    application = Flask(__name__)
    application.json.sort_keys = False          # keep field order (Flutter shows sections/columns in this order)

    # CORS for Flutter Web (open for development; restrict origins in production).
    @application.after_request
    def add_cors(resp):
        resp.headers["Access-Control-Allow-Origin"] = "*"
        resp.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
        resp.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
        return resp

    for bp in ALL_BLUEPRINTS:
        application.register_blueprint(bp)

    @application.get("/api/health")
    def health():
        return jsonify({"status": "ok", "service": "buoy_server", "live": config.LIVE,
                        "tick_seconds": config.TICK_SECONDS, "step_minutes": config.STEP_MINUTES})

    @application.errorhandler(404)
    def not_found(_err):
        return jsonify({"error": "not_found", "message": "Unknown endpoint"}), 404

    @application.errorhandler(500)
    def server_error(err):
        return jsonify({"error": "server_error", "message": str(err)}), 500

    engine.seed_history()                       # 14 days of simulated history (~1-2 s)
    if config.LIVE:
        engine.start_live()                     # then a new reading every TICK_SECONDS
    return application


app = create_app()
