from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("modeling", "0002_projectmembership_unique_project_owner")]

    operations = [
        migrations.AlterField(
            model_name="invitecode",
            name="code_hash",
            field=models.CharField(max_length=128, unique=True),
        ),
    ]
