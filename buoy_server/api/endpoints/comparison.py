from flask import Blueprint, jsonify
from services import payloads

bp = Blueprint('comparison', __name__)


@bp.get('/api/comparison')
def get_comparison():
    return jsonify(payloads.comparison())
