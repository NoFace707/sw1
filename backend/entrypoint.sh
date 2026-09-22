#!/bin/sh
set -e

python manage.py wait_for_db
python manage.py migrate --noinput

case "${AI_TRANSCRIPTION_PRELOAD:-true}" in
  1|true|TRUE|True|yes|YES|Yes) whisper_preload_enabled=true ;;
  *) whisper_preload_enabled=false ;;
esac

if [ "${AI_TRANSCRIPTION_BACKEND:-local}" = "local" ] \
  && [ "$whisper_preload_enabled" = "true" ] \
  && [ "$1" = "python" ] \
  && [ "$2" = "manage.py" ] \
  && [ "$3" = "runserver" ]; then
  echo "Preparing local Whisper model..."
  python manage.py preload_whisper || echo "Whisper preload failed; the backend will retry on the first transcription."
fi

exec "$@"
