from flask import Blueprint, jsonify, request
from services import config, payloads

bp = Blueprint('interpretation', __name__)


@bp.get('/api/interpretation')
def get_interpretation():
    buoy = request.args.get("buoy", "SO-01")
    if buoy not in config.ACTIVE_IDS:
        return jsonify({"error": "not_found", "message": f"Unknown buoy {buoy}"}), 404
    return jsonify(payloads.interpretation(buoy))
