"""Read side: what the ground station can see (store-and-forward aware)."""
from backend import database as db
from . import config


def visible(buoy_id):
    """Readings that have reached the ground station. Anything after the newest
    'link up' reading is still sitting in the buoy's buffer, so it is hidden."""
    up_to = db.delivered_upto_id(buoy_id)
    return [] if up_to is None else db.get_buoy_observations(buoy_id, up_to)


def link_up(buoy_id):
    last = db.get_last(buoy_id)
    return bool(last and last["transmitted"])


def backlog(buoy_id):
    return db.count_after(buoy_id, db.delivered_upto_id(buoy_id))
