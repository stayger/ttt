# Generated by Django 4.2.3 on 2023-07-04 11:56

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        ("checkbase", "0002_server"),
    ]

    operations = [
        migrations.AddField(
            model_name="base",
            name="server",
            field=models.ForeignKey(
                default=None,
                on_delete=django.db.models.deletion.CASCADE,
                to="checkbase.server",
            ),
            preserve_default=False,
        ),
    ]