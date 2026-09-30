"""Environmental event control. Phase 1 uses a fixed event from config;
this helper lets simulation/main.py schedule events over time if desired."""

from simulation.config import EventType


class EventSchedule:
    """Optional: apply a specific event only within a step range.
    schedule = [(start_step, end_step, EventType), ...]
    """

    def __init__(self, schedule=None, default: EventType = EventType.NORMAL):
        self.schedule = schedule or []
        self.default = default

    def event_at(self, step: int) -> EventType:
        for start, end, event in self.schedule:
            if start <= step < end:
                return event
        return self.default
