from flask import Blueprint, jsonify
from services import payloads

bp = Blueprint('fleet', __name__)


@bp.get('/api/fleet')
def get_fleet():
    return jsonify(payloads.fleet())
