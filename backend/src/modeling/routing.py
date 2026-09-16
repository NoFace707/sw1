from django.urls import re_path

from .consumers import ProjectConsumer


websocket_urlpatterns = [
    re_path(r"ws/projects/(?P<project_id>[0-9a-f-]+)/$", ProjectConsumer.as_asgi()),
]
