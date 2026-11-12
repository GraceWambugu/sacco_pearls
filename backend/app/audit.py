from datetime import date, datetime, timezone

from sqlalchemy import event, inspect
from sqlalchemy.orm import Session

_SENSITIVE_FIELDS = {"password_hash", "token_hash"}


def _json_value(value):
    if isinstance(value, (date, datetime)):
        return value.isoformat()
    return value


def _snapshot(instance):
    mapper = inspect(instance).mapper
    return {
        attribute.key: _json_value(getattr(instance, attribute.key))
        for attribute in mapper.column_attrs
        if attribute.key not in _SENSITIVE_FIELDS
    }


def _entity_key(instance):
    mapper = inspect(instance).mapper
    return {
        column.key: _json_value(getattr(instance, column.key))
        for column in mapper.primary_key
    }


@event.listens_for(Session, "before_flush")
def capture_changes(session, flush_context, instances):
    changes = session.info.setdefault("audit_changes", [])

    for instance in tuple(session.new):
        if instance.__tablename__ == "audit_logs":
            continue
        now = datetime.now(timezone.utc)
        if hasattr(instance, "created_at") and instance.created_at is None:
            instance.created_at = now
        if hasattr(instance, "updated_at"):
            instance.updated_at = now
        changes.append({"instance": instance, "action": "insert", "before": None,
                        "after": _snapshot(instance)})

    for instance in tuple(session.dirty):
        if instance.__tablename__ == "audit_logs" or not session.is_modified(
                instance, include_collections=False):
            continue
        state = inspect(instance)
        before = _snapshot(instance)
        for attribute in state.mapper.column_attrs:
            history = state.attrs[attribute.key].history
            if history.has_changes() and attribute.key not in _SENSITIVE_FIELDS:
                before[attribute.key] = _json_value(history.deleted[0] if history.deleted else None)
        if hasattr(instance, "updated_at"):
            instance.updated_at = datetime.now(timezone.utc)
        changes.append({"instance": instance, "action": "update", "before": before,
                        "after": _snapshot(instance)})

    for instance in tuple(session.deleted):
        if instance.__tablename__ == "audit_logs":
            continue
        changes.append({"instance": instance, "action": "delete", "before": _snapshot(instance),
                        "after": None})


@event.listens_for(Session, "after_flush_postexec")
def write_audit_logs(session, flush_context):
    changes = session.info.pop("audit_changes", [])
    if not changes:
        return

    from .models import AuditLog

    actor_user_id = session.info.get("actor_user_id")
    actor_email = session.info.get("actor_email")
    for change in changes:
        instance = change["instance"]
        session.add(AuditLog(
            entity_type=type(instance).__name__,
            entity_key=_entity_key(instance),
            action=change["action"],
            actor_user_id=actor_user_id,
            actor_email=actor_email,
            before_data=change["before"],
            after_data=change["after"],
        ))