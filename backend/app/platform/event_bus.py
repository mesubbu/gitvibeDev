from __future__ import annotations

import asyncio
import time
import uuid
from collections import defaultdict, deque
from dataclasses import dataclass, field
from typing import Any, Awaitable, Callable

EventHandler = Callable[["EventEnvelope"], Awaitable[None] | None]


@dataclass(frozen=True)
class EventEnvelope:
    id: str
    topic: str
    source: str
    payload: dict[str, Any]
    version: str = "1.0"
    timestamp: int = field(default_factory=lambda: int(time.time()))

    def as_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "topic": self.topic,
            "source": self.source,
            "payload": self.payload,
            "version": self.version,
            "timestamp": self.timestamp,
        }


class AsyncEventBus:
    """In-memory async event bus with bounded recent-event history."""

    def __init__(self, max_events: int = 1_000) -> None:
        self._handlers: dict[str, list[EventHandler]] = defaultdict(list)
        self._recent_events: deque[EventEnvelope] = deque(maxlen=max(10, max_events))
        self._lock = asyncio.Lock()

    def subscribe(self, topic: str, handler: EventHandler) -> None:
        self._handlers[topic].append(handler)

    def unsubscribe(self, topic: str, handler: EventHandler) -> None:
        handlers = self._handlers.get(topic, [])
        if handler in handlers:
            handlers.remove(handler)

    async def publish(
        self,
        topic: str,
        payload: dict[str, Any] | None = None,
        *,
        source: str = "unknown",
        version: str = "1.0",
    ) -> EventEnvelope:
        envelope = EventEnvelope(
            id=str(uuid.uuid4()),
            topic=topic,
            source=source,
            payload=payload or {},
            version=version,
        )
        async with self._lock:
            self._recent_events.append(envelope)

        handlers = [*self._handlers.get(topic, []), *self._handlers.get("*", [])]
        for handler in handlers:
            maybe_coro = handler(envelope)
            if asyncio.iscoroutine(maybe_coro):
                await maybe_coro
        return envelope

    def list_topics(self) -> list[str]:
        topic_names = set(self._handlers.keys())
        topic_names.update(item.topic for item in self._recent_events)
        return sorted(topic_names)

    def recent_events(self, limit: int = 100) -> list[dict[str, Any]]:
        size = max(1, min(limit, len(self._recent_events)))
        return [item.as_dict() for item in list(self._recent_events)[-size:]]
