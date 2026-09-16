from time import sleep

from django.core.management.base import BaseCommand
from django.db import connections
from django.db.utils import OperationalError


class Command(BaseCommand):
    help = "Block execution until database is available"

    def handle(self, *args, **options):
        self.stdout.write("Checking database connection...")
        db_conn = None
        while db_conn is None:
            try:
                db_conn = connections["default"]
                db_conn.cursor()
            except OperationalError:
                self.stdout.write(self.style.WARNING("Database unavailable, retrying in 1 second..."))
                sleep(1)

        self.stdout.write(self.style.SUCCESS("Database connection ready."))
