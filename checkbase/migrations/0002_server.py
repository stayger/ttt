# Generated by Django 4.2.3 on 2023-07-04 11:48

from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("checkbase", "0001_initial"),
    ]

    operations = [
        migrations.CreateModel(
            name="Server",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                ("title", models.CharField(max_length=50)),
                ("username", models.CharField(max_length=50)),
                ("password", models.CharField(max_length=50)),
            ],
        ),
    ]
