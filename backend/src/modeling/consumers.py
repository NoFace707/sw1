from urllib.parse import parse_qs

from channels.generic.websocket import AsyncJsonWebsocketConsumer
from channels.db import database_sync_to_async
from django.core.cache import cache

from .models import ProjectMembership


class ProjectConsumer(AsyncJsonWebsocketConsumer):
    async def connect(self):
        self.project_id = self.scope["url_route"]["kwargs"]["project_id"]
        token = parse_qs(self.scope["query_string"].decode()).get("ticket", [""])[0]
        ticket = cache.get(f"ws-ticket:{token}") if token else None
        if ticket:
            cache.delete(f"ws-ticket:{token}")
        user_id = ticket.get("user_id") if ticket else None
        if not user_id or str(ticket.get("project_id")) != self.project_id:
            await self.close(code=4401)
            return
        try:
            membership = await ProjectMembership.objects.select_related("user").aget(project_id=self.project_id, user_id=user_id)
        except ProjectMembership.DoesNotExist:
            await self.close(code=4403)
            return
        self.user = membership.user
        self.role = membership.role
        self.group_name = f"project-{self.project_id}"
        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()
        await self.channel_layer.group_send(self.group_name, {"type": "project.event", "event": "presence.joined", "user_id": str(self.user.id), "role": self.role})

    async def disconnect(self, close_code):
        if hasattr(self, "group_name"):
            await self.channel_layer.group_discard(self.group_name, self.channel_name)
            await self.channel_layer.group_send(self.group_name, {"type": "project.event", "event": "presence.left", "user_id": str(self.user.id)})

    async def receive_json(self, content, **kwargs):
        if not await self._membership_exists():
            await self.send_json({"event": "error", "detail": "Tu membresía ya no está activa."})
            await self.close(code=4403)
            return
        if content.get("event") == "operation":
            detail = "No tienes permiso de edición." if self.role == ProjectMembership.Role.VIEWER else "Las operaciones deben confirmarse mediante el API HTTP."
            await self.send_json({"event": "error", "detail": detail})
            return
        event_name = content.get("event", "message")
        if event_name not in {"presence.focus", "presence.heartbeat"}:
            await self.send_json({"event": "error", "detail": "Evento en tiempo real no soportado."})
            return
        await self.channel_layer.group_send(self.group_name, {"type": "project.event", "event": event_name, "payload": content.get("payload", {}), "user_id": str(self.user.id), "role": self.role})

    @database_sync_to_async
    def _membership_exists(self):
        return ProjectMembership.objects.filter(project_id=self.project_id, user_id=self.user.id).exists()

    async def project_event(self, event):
        payload = {key: value for key, value in event.items() if key not in {"type"}}
        if hasattr(self, "user") and payload.get("user_id") == str(self.user.id):
            return
        await self.send_json(payload)
