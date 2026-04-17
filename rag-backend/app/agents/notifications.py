"""In-process notification hub.

Maintains a map of user_id -> set of active WebSocket connections and provides
a publish() method that delivers JSON events to all connections for a given
user. Used by the agentic loop to push brief-ready and other events to the
Flutter client in real time.
"""

from __future__ import annotations

import asyncio
from typing import Any

from fastapi import WebSocket


class NotificationHub:
    def __init__(self) -> None:
        self._connections: dict[str, set[WebSocket]] = {}
        self._lock = asyncio.Lock()

    async def connect(self, user_id: str, websocket: WebSocket) -> None:
        await websocket.accept()
        async with self._lock:
            self._connections.setdefault(user_id, set()).add(websocket)

    async def disconnect(self, user_id: str, websocket: WebSocket) -> None:
        async with self._lock:
            conns = self._connections.get(user_id)
            if conns and websocket in conns:
                conns.discard(websocket)
                if not conns:
                    self._connections.pop(user_id, None)

    async def publish(self, user_id: str, event: dict[str, Any]) -> int:
        """Send an event to every active connection for the given user.

        Returns the number of connections the event was delivered to.
        Stale connections that raise on send are silently removed.
        """
        async with self._lock:
            conns = list(self._connections.get(user_id, set()))

        delivered = 0
        dead: list[WebSocket] = []
        for ws in conns:
            try:
                await ws.send_json(event)
                delivered += 1
            except Exception:
                dead.append(ws)

        if dead:
            async with self._lock:
                current = self._connections.get(user_id)
                if current:
                    for ws in dead:
                        current.discard(ws)
                    if not current:
                        self._connections.pop(user_id, None)

        return delivered


# Module-level singleton used by both the router (WS endpoint) and the
# agent runner (publishing side).
hub = NotificationHub()
