from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers


def _generate_unique_username(email):
    user_model = get_user_model()
    base = (email.split("@", 1)[0] or "usuario").strip().replace(" ", "")[:120]
    candidate = base or "usuario"
    suffix = 1
    while user_model.objects.filter(username=candidate).exists():
        candidate = f"{base}{suffix}"
        suffix += 1
    return candidate


class RegisterSerializer(serializers.ModelSerializer):
    first_name = serializers.CharField(required=True, max_length=150)
    last_name = serializers.CharField(required=True, max_length=150)
    email = serializers.EmailField(required=True)
    password = serializers.CharField(write_only=True, min_length=8)

    class Meta:
        model = get_user_model()
        fields = ("first_name", "last_name", "email", "password")

    def validate_email(self, value):
        normalized = value.strip().lower()
        if get_user_model().objects.filter(email__iexact=normalized).exists():
            raise serializers.ValidationError("Este correo ya está registrado.")
        return normalized

    def validate_password(self, value):
        validate_password(value)
        return value

    def create(self, validated_data):
        validated_data["username"] = _generate_unique_username(validated_data["email"])
        return get_user_model().objects.create_user(is_active=True, **validated_data)


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = get_user_model()
        fields = ("id", "first_name", "last_name", "email")
        read_only_fields = fields
