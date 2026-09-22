from django.core.management.base import BaseCommand, CommandError

from modeling.transcription import TranscriptionError, preload_local_model


class Command(BaseCommand):
    help = "Descarga y precarga el modelo Whisper local configurado."

    def handle(self, *args, **options):
        try:
            result = preload_local_model()
        except TranscriptionError as exc:
            raise CommandError(str(exc)) from exc
        self.stdout.write(
            self.style.SUCCESS(
                f"Whisper local listo: {result['model']} ({result['backend']})."
            )
        )
