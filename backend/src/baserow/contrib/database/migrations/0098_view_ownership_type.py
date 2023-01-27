# Generated by Django 3.2.13 on 2022-12-16 12:28

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("database", "0097_add_ip_address_to_jobs"),
    ]

    operations = [
        migrations.AddField(
            model_name="view",
            name="created_by",
            field=models.ForeignKey(
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                to=settings.AUTH_USER_MODEL,
            ),
        ),
        migrations.AddField(
            model_name="view",
            name="ownership_type",
            field=models.CharField(default="collaborative", max_length=255),
        ),
    ]
