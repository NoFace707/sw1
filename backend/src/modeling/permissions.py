from rest_framework.exceptions import NotFound, PermissionDenied

from .models import ProjectMembership


def membership_for(user, project):
    try:
        return ProjectMembership.objects.get(project=project, user=user)
    except ProjectMembership.DoesNotExist as exc:
        raise NotFound("Proyecto no encontrado.") from exc


def require_membership(user, project, write=False):
    membership = membership_for(user, project)
    if write and membership.role not in {ProjectMembership.Role.OWNER, ProjectMembership.Role.EDITOR}:
        raise PermissionDenied("No tienes permiso de edición para este proyecto.")
    return membership


def require_owner(user, project):
    membership = require_membership(user, project)
    if membership.role != ProjectMembership.Role.OWNER:
        raise PermissionDenied("Solo el propietario puede realizar esta acción.")
    return membership
