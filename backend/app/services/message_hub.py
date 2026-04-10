from __future__ import annotations

import asyncio
from collections import defaultdict
from collections.abc import Iterable

from fastapi import WebSocket


class MessageHub:
    def __init__(self) -> None:
        self._connections: dict[int, set[WebSocket]] = defaultdict(set)
        self._lock = asyncio.Lock()

    async def connect(self, client_id: int, websocket: WebSocket) -> None:
        await websocket.accept()
        async with self._lock:
            self._connections[client_id].add(websocket)

    async def disconnect(self, client_id: int, websocket: WebSocket) -> None:
        async with self._lock:
            sockets = self._connections.get(client_id)
            if not sockets:
                return
            sockets.discard(websocket)
            if not sockets:
                self._connections.pop(client_id, None)

    async def broadcast(self, client_id: int, payload: dict[str, object]) -> None:
        sockets = await self._snapshot(client_id)
        if not sockets:
            return

        stale: list[WebSocket] = []
        for websocket in sockets:
            try:
                await websocket.send_json(payload)
            except Exception:
                stale.append(websocket)

        for websocket in stale:
            await self.disconnect(client_id, websocket)

    async def _snapshot(self, client_id: int) -> Iterable[WebSocket]:
        async with self._lock:
            return tuple(self._connections.get(client_id, ()))


message_hub = MessageHub()
