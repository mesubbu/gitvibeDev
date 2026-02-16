from __future__ import annotations

import pytest

from app.platform.event_bus import AsyncEventBus


pytestmark = [pytest.mark.unit, pytest.mark.asyncio]


async def test_publish_calls_topic_and_wildcard_handlers() -> None:
    bus = AsyncEventBus(max_events=20)
    seen: list[tuple[str, str]] = []

    async def topic_handler(event):
        seen.append(("topic", event.topic))

    def wildcard_handler(event):
        seen.append(("*", event.topic))

    bus.subscribe("demo.topic", topic_handler)
    bus.subscribe("*", wildcard_handler)

    envelope = await bus.publish("demo.topic", {"ok": True}, source="test")

    assert envelope.topic == "demo.topic"
    assert seen == [("topic", "demo.topic"), ("*", "demo.topic")]
    assert bus.list_topics() == ["*", "demo.topic"]


async def test_recent_events_respects_limit() -> None:
    bus = AsyncEventBus(max_events=3)
    for index in range(5):
        await bus.publish(f"topic.{index}", {"index": index}, source="test")

    events = bus.recent_events(limit=10)

    assert len(events) == 3
    assert events[0]["topic"] == "topic.2"
    assert events[-1]["topic"] == "topic.4"
