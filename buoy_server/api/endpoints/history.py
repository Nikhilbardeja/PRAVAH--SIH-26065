from flask import Blueprint, jsonify, request
from services import config, payloads

bp = Blueprint('history', __name__)


@bp.get('/api/buoys/<buoy_id>/history')
def get_history(buoy_id: str):
    if buoy_id not in config.ACTIVE_IDS:
        print(f"Unknown buoy {buoy_id}")
        return jsonify({"error": "not_found", "message": f"Unknown buoy {buoy_id}"}), 404
    try:
        days = int(request.args.get("days", 14))
    except (TypeError, ValueError):
        days = 14
    return jsonify(payloads.history(buoy_id, days))
