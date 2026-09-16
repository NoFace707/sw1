from django.contrib.auth import authenticate, get_user_model
from django.contrib.auth.models import update_last_login
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken

from .serializers import RegisterSerializer, UserSerializer


def _session_payload(user):
    refresh = RefreshToken.for_user(user)
    return {
        "user": UserSerializer(user).data,
        "access": str(refresh.access_token),
        "refresh": str(refresh),
    }


@api_view(["GET"])
@permission_classes([AllowAny])
def health(request):
    return Response({"status": "ok"})


@api_view(["POST"])
@permission_classes([AllowAny])
def register(request):
    serializer = RegisterSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    user = serializer.save()
    return Response(_session_payload(user), status=status.HTTP_201_CREATED)


@api_view(["POST"])
@permission_classes([AllowAny])
def login(request):
    email = (request.data.get("email") or "").strip().lower()
    password = request.data.get("password") or ""
    target = get_user_model().objects.filter(email__iexact=email).first()
    user = (
        authenticate(request, username=target.username, password=password)
        if target is not None
        else None
    )
    if user is None or not user.is_active:
        return Response(
            {"detail": "Credenciales inválidas."},
            status=status.HTTP_401_UNAUTHORIZED,
        )
    update_last_login(None, user)
    return Response(_session_payload(user))


@api_view(["POST"])
@permission_classes([AllowAny])
def refresh_session(request):
    raw_refresh = request.data.get("refresh")
    if not raw_refresh:
        return Response(
            {"detail": "Token de refresco no proporcionado."},
            status=status.HTTP_400_BAD_REQUEST,
        )
    try:
        refresh = RefreshToken(raw_refresh)
        user = get_user_model().objects.get(pk=refresh["user_id"], is_active=True)
    except (TokenError, KeyError, get_user_model().DoesNotExist):
        return Response(
            {"detail": "Token de refresco inválido o expirado."},
            status=status.HTTP_401_UNAUTHORIZED,
        )
    return Response({"access": str(refresh.access_token)})


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def me(request):
    return Response(UserSerializer(request.user).data)


@api_view(["POST"])
@permission_classes([AllowAny])
def logout(request):
    return Response({"detail": "Sesión cerrada correctamente."})
