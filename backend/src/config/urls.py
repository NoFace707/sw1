from django.urls import include, path


urlpatterns = [
    path("api/", include("core.urls")),
    path("api/modeling/", include("modeling.urls")),
]
