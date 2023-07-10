from django.contrib import admin
from .models import Base, Server


@admin.register(Server)
class ServerAdmin(admin.ModelAdmin):
    list_display = ["title"]


@admin.register(Base)
class BaseAdmin(admin.ModelAdmin):
    list_display = ["title"]
