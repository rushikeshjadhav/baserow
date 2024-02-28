# Generated by Django 4.0.10 on 2024-02-06 15:29

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models

import baserow.core.user_sources.models
from baserow.contrib.database.db.functions import RandomUUID


def gen_uuid(apps, schema_editor):
    """
    Generates the uid for all user sources.
    """

    UserSource = apps.get_model("core", "usersource")
    UserSource.objects.update(uid=RandomUUID())


class Migration(migrations.Migration):
    dependencies = [
        ("core", "0080_appauthprovider"),
    ]

    operations = [
        migrations.AlterField(
            model_name="blacklistedtoken",
            name="user",
            field=models.ForeignKey(
                null=True,
                on_delete=django.db.models.deletion.CASCADE,
                to=settings.AUTH_USER_MODEL,
            ),
        ),
        migrations.AddField(
            model_name="usersource",
            name="uid",
            field=models.TextField(
                default=baserow.core.user_sources.models.gen_uuid,
                help_text="Unique id for this user source.",
                null=True,
            ),
        ),
        migrations.RunPython(gen_uuid, reverse_code=migrations.RunPython.noop),
        migrations.AlterField(
            model_name="usersource",
            name="uid",
            field=models.TextField(
                default=baserow.core.user_sources.models.gen_uuid,
                editable=False,
                help_text="Unique id for this user source.",
                unique=True,
            ),
        ),
    ]
