from collections import defaultdict
from typing import Any, DefaultDict, Dict, Optional, Set

from fastapi import WebSocket


class ConversationConnectionManager:
    def __init__(self) -> None:
        self._connections: DefaultDict[
            int,
            Dict[int, Set[WebSocket]],
        ] = defaultdict(dict)

    async def connect(
        self,
        conversation_id: int,
        user_id: int,
        websocket: WebSocket,
    ) -> None:

        await websocket.accept()

        conversation_connections = (
            self._connections[conversation_id]
        )

        user_connections = (
            conversation_connections.setdefault(
                user_id,
                set(),
            )
        )

        user_connections.add(websocket)

    def disconnect(
        self,
        conversation_id: int,
        user_id: int,
        websocket: WebSocket,
    ) -> None:

        conversation_connections = (
            self._connections.get(conversation_id)
        )

        if not conversation_connections:
            return

        user_connections = (
            conversation_connections.get(user_id)
        )

        if not user_connections:
            return

        user_connections.discard(websocket)

        if not user_connections:
            conversation_connections.pop(
                user_id,
                None,
            )

        if not conversation_connections:
            self._connections.pop(
                conversation_id,
                None,
            )

    async def broadcast_to_conversation(
        self,
        conversation_id: int,
        payload: Dict[str, Any],
        exclude_user_id: Optional[int] = None,
    ) -> None:

        conversation_connections = (
            self._connections.get(conversation_id)
        )

        if not conversation_connections:
            return

        disconnected_connections = []

        for user_id, sockets in list(
            conversation_connections.items()
        ):
            if (
                exclude_user_id is not None
                and user_id == exclude_user_id
            ):
                continue

            for websocket in list(sockets):
                try:
                    await websocket.send_json(
                        payload
                    )
                except Exception:
                    disconnected_connections.append(
                        (
                            user_id,
                            websocket,
                        )
                    )

        for user_id, websocket in (
            disconnected_connections
        ):
            self.disconnect(
                conversation_id=conversation_id,
                user_id=user_id,
                websocket=websocket,
            )

    async def send_personal_event(
        self,
        conversation_id: int,
        user_id: int,
        payload: Dict[str, Any],
    ) -> None:

        conversation_connections = (
            self._connections.get(conversation_id)
        )

        if not conversation_connections:
            return

        user_connections = (
            conversation_connections.get(user_id)
        )

        if not user_connections:
            return

        disconnected_connections = []

        for websocket in list(user_connections):
            try:
                await websocket.send_json(
                    payload
                )
            except Exception:
                disconnected_connections.append(
                    websocket
                )

        for websocket in disconnected_connections:
            self.disconnect(
                conversation_id=conversation_id,
                user_id=user_id,
                websocket=websocket,
            )

    def get_connection_count(
        self,
        conversation_id: int,
    ) -> int:

        conversation_connections = (
            self._connections.get(conversation_id)
        )

        if not conversation_connections:
            return 0

        return sum(
            len(sockets)
            for sockets
            in conversation_connections.values()
        )


class NotificationConnectionManager:

    def __init__(self) -> None:
        self._connections: DefaultDict[
            int,
            Set[WebSocket],
        ] = defaultdict(set)

    async def connect(
        self,
        user_id: int,
        websocket: WebSocket,
    ) -> None:
        await websocket.accept()

        self._connections[user_id].add(
            websocket
        )

    def disconnect(
        self,
        user_id: int,
        websocket: WebSocket,
    ) -> None:
        user_connections = self._connections.get(
            user_id
        )

        if not user_connections:
            return

        user_connections.discard(
            websocket
        )

        if not user_connections:
            self._connections.pop(
                user_id,
                None,
            )

    async def send_to_user(
        self,
        user_id: int,
        payload: Dict[str, Any],
    ) -> None:
        user_connections = self._connections.get(
            user_id
        )

        if not user_connections:
            return

        disconnected_connections = []

        for websocket in list(user_connections):
            try:
                await websocket.send_json(
                    payload
                )
            except Exception:
                disconnected_connections.append(
                    websocket
                )

        for websocket in disconnected_connections:
            self.disconnect(
                user_id=user_id,
                websocket=websocket,
            )

    def get_connection_count(
        self,
        user_id: int,
    ) -> int:
        user_connections = self._connections.get(
            user_id
        )

        if not user_connections:
            return 0

        return len(user_connections)


conversation_connection_manager = (
    ConversationConnectionManager()
)

notification_connection_manager = (
    NotificationConnectionManager()
)