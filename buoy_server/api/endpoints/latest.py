from flask import Blueprint, jsonify
from services import config, payloads

bp = Blueprint('latest', __name__)


@bp.get('/api/buoys/<buoy_id>/latest')
def get_latest(buoy_id: str):
    data = payloads.latest(buoy_id) if buoy_id in config.ACTIVE_IDS else None
    if data is None:
        return jsonify({"error": "not_found", "message": f"No data for buoy {buoy_id}"}), 404
    return jsonify(data)
