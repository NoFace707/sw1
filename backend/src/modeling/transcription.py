import json
import mimetypes
import os
import tempfile
import threading
import uuid
from pathlib import Path
from urllib import error as urllib_error
from urllib import request as urllib_request

from django.conf import settings


ALLOWED_AUDIO_TYPES = {
    "audio/webm",
    "audio/mp4",
    "audio/aac",
    "audio/mp4a-latm",
    "audio/x-m4a",
    "audio/m4a",
    "audio/mpeg",
    "audio/mp3",
    "audio/wav",
    "audio/x-wav",
    "audio/ogg",
}

ALLOWED_AUDIO_EXTENSIONS = {
    ".aac",
    ".m4a",
    ".mp3",
    ".mp4",
    ".ogg",
    ".wav",
    ".webm",
}


class TranscriptionError(Exception):
    pass


_LOCAL_MODEL = None
_LOCAL_MODEL_KEY = None
_LOCAL_MODEL_LOCK = threading.Lock()
_LOCAL_INFERENCE_LOCK = threading.Lock()


def _local_model_config():
    return (
        str(getattr(settings, "AI_TRANSCRIPTION_LOCAL_MODEL", "base") or "base"),
        str(getattr(settings, "AI_TRANSCRIPTION_LOCAL_DEVICE", "cpu") or "cpu"),
        str(
            getattr(settings, "AI_TRANSCRIPTION_LOCAL_COMPUTE_TYPE", "int8")
            or "int8"
        ),
        str(
            getattr(settings, "AI_TRANSCRIPTION_LOCAL_CACHE_DIR", ".whisper-models")
            or ".whisper-models"
        ),
        int(getattr(settings, "AI_TRANSCRIPTION_LOCAL_CPU_THREADS", 4)),
    )


def _get_local_model():
    global _LOCAL_MODEL, _LOCAL_MODEL_KEY
    config = _local_model_config()
    if _LOCAL_MODEL is not None and _LOCAL_MODEL_KEY == config:
        return _LOCAL_MODEL
    with _LOCAL_MODEL_LOCK:
        if _LOCAL_MODEL is not None and _LOCAL_MODEL_KEY == config:
            return _LOCAL_MODEL
        try:
            from faster_whisper import WhisperModel
        except ImportError as exc:
            raise TranscriptionError(
                "Whisper local no está instalado en el backend. Reconstruye el contenedor."
            ) from exc
        model_name, device, compute_type, cache_dir, cpu_threads = config
        Path(cache_dir).mkdir(parents=True, exist_ok=True)
        try:
            _LOCAL_MODEL = WhisperModel(
                model_name,
                device=device,
                compute_type=compute_type,
                download_root=cache_dir,
                cpu_threads=cpu_threads,
                num_workers=1,
            )
        except Exception as exc:
            raise TranscriptionError(
                "No se pudo cargar el modelo Whisper local. Revisa la descarga y los recursos del backend."
            ) from exc
        _LOCAL_MODEL_KEY = config
        return _LOCAL_MODEL


def preload_local_model():
    model = _get_local_model()
    return {
        "backend": "local",
        "model": _local_model_config()[0],
        "ready": model is not None,
    }


def _endpoint(base_url):
    base = str(base_url or "").strip().rstrip("/")
    if not base:
        raise TranscriptionError("La transcripción por voz no está configurada.")
    if base.endswith("/audio/transcriptions"):
        return base
    return f"{base}/audio/transcriptions"


def _multipart(audio_bytes, filename, content_type, model, language):
    boundary = f"----uml-modeler-{uuid.uuid4().hex}"
    chunks = []

    def field(name, value):
        chunks.extend([
            f"--{boundary}\r\n".encode(),
            f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode(),
            str(value).encode(),
            b"\r\n",
        ])

    field("model", model)
    field("response_format", "json")
    if language:
        field("language", language)
    safe_name = str(filename or "audio.webm").replace('"', "")
    chunks.extend([
        f"--{boundary}\r\n".encode(),
        f'Content-Disposition: form-data; name="file"; filename="{safe_name}"\r\n'.encode(),
        f"Content-Type: {content_type}\r\n\r\n".encode(),
        audio_bytes,
        b"\r\n",
        f"--{boundary}--\r\n".encode(),
    ])
    return boundary, b"".join(chunks)


def _validated_audio(uploaded_file):
    max_bytes = int(getattr(settings, "AI_TRANSCRIPTION_MAX_BYTES", 10 * 1024 * 1024))
    if uploaded_file.size > max_bytes:
        raise TranscriptionError("El audio supera el tamaño máximo permitido.")
    supplied_type = (
        str(getattr(uploaded_file, "content_type", "") or "")
        .lower()
        .split(";", 1)[0]
    )
    suffix = Path(str(getattr(uploaded_file, "name", "") or "")).suffix.lower()
    guessed_type = mimetypes.guess_type(uploaded_file.name)[0] or ""
    content_type = (
        guessed_type
        if supplied_type in {"", "application/octet-stream"}
        else supplied_type
    )
    if content_type not in ALLOWED_AUDIO_TYPES and suffix not in ALLOWED_AUDIO_EXTENSIONS:
        raise TranscriptionError("El formato de audio no está permitido.")
    if content_type not in ALLOWED_AUDIO_TYPES:
        content_type = guessed_type or "audio/mp4"
    audio_bytes = uploaded_file.read(max_bytes + 1)
    if not audio_bytes:
        raise TranscriptionError("El audio está vacío.")
    if len(audio_bytes) > max_bytes:
        raise TranscriptionError("El audio supera el tamaño máximo permitido.")
    return audio_bytes, content_type


def _transcribe_local(audio_bytes, filename, language):
    suffix = Path(str(filename or "audio.webm")).suffix.lower()
    if not suffix or len(suffix) > 10:
        suffix = ".webm"
    temporary_path = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="wb", suffix=suffix, prefix="uml-whisper-", delete=False
        ) as temporary:
            temporary.write(audio_bytes)
            temporary_path = temporary.name
        model = _get_local_model()
        with _LOCAL_INFERENCE_LOCK:
            segments, _ = model.transcribe(
                temporary_path,
                language=str(language or "").strip()[:12] or None,
                beam_size=5,
                vad_filter=True,
                condition_on_previous_text=False,
            )
            text = " ".join(
                str(getattr(segment, "text", "")).strip() for segment in segments
            ).strip()
    except TranscriptionError:
        raise
    except Exception as exc:
        raise TranscriptionError(
            "Whisper local no pudo transcribir el audio."
        ) from exc
    finally:
        if temporary_path:
            try:
                os.unlink(temporary_path)
            except FileNotFoundError:
                pass
    if not text:
        raise TranscriptionError("No se detectó texto en el audio.")
    return {"text": text, "model": f"local:{_local_model_config()[0]}"}


def _transcribe_remote(audio_bytes, filename, content_type, language):
    base_url = getattr(settings, "AI_TRANSCRIPTION_BASE_URL", "")
    api_key = str(getattr(settings, "AI_TRANSCRIPTION_API_KEY", "") or "").strip()
    if not api_key:
        raise TranscriptionError("Falta configurar AI_TRANSCRIPTION_API_KEY.")
    model = str(
        getattr(settings, "AI_TRANSCRIPTION_MODEL", "whisper-large-v3-turbo")
        or "whisper-large-v3-turbo"
    )
    boundary, body = _multipart(
        audio_bytes,
        filename,
        content_type,
        model,
        str(language or "").strip()[:12],
    )
    request = urllib_request.Request(
        _endpoint(base_url),
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {api_key}",
            "Accept": "application/json",
            "Content-Type": f"multipart/form-data; boundary={boundary}",
        },
    )
    try:
        with urllib_request.urlopen(
            request,
            timeout=int(getattr(settings, "AI_TRANSCRIPTION_TIMEOUT_SECONDS", 60)),
        ) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib_error.HTTPError as exc:
        try:
            remote = json.loads(exc.read().decode("utf-8"))
            detail = remote.get("error", {}).get("message") or remote.get("detail")
        except (ValueError, AttributeError, UnicodeDecodeError):
            detail = None
        if detail and api_key:
            detail = str(detail).replace(api_key, "[redacted]")
        suffix = f": {detail}" if detail else ""
        raise TranscriptionError(f"El proveedor de voz respondió HTTP {exc.code}{suffix}.") from exc
    except (TimeoutError, urllib_error.URLError, OSError) as exc:
        raise TranscriptionError("No se pudo contactar al proveedor de transcripción.") from exc
    except (ValueError, UnicodeDecodeError) as exc:
        raise TranscriptionError("El proveedor de voz devolvió una respuesta inválida.") from exc
    text = str(payload.get("text", "")).strip() if isinstance(payload, dict) else ""
    if not text:
        raise TranscriptionError("No se detectó texto en el audio.")
    return {"text": text, "model": model}


def transcribe_audio(uploaded_file, language="es"):
    audio_bytes, content_type = _validated_audio(uploaded_file)
    backend = str(
        getattr(settings, "AI_TRANSCRIPTION_BACKEND", "local") or "local"
    ).strip().lower()
    if backend == "local":
        return _transcribe_local(audio_bytes, uploaded_file.name, language)
    if backend == "remote":
        return _transcribe_remote(
            audio_bytes, uploaded_file.name, content_type, language
        )
    raise TranscriptionError(
        "AI_TRANSCRIPTION_BACKEND debe ser 'local' o 'remote'."
    )
