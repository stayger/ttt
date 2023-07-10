from django.db import models
from django.urls import reverse


class Server(models.Model):
    title = models.CharField(max_length=50)
    username = models.CharField("Пользователь", max_length=50)
    password = models.CharField("Пароль", max_length=50)
    use_wa = models.BooleanField("win auth", default=False)

    def __str__(self):
        return self.title

    def get_absolute_url(self):
        return reverse("server_detail", kwargs={"pk": self.pk})


class Base(models.Model):
    title = models.CharField(max_length=50)
    server = models.ForeignKey(Server, on_delete=models.CASCADE)

    def get_absolute_url(self):
        return reverse("base_detail", kwargs={"pk": self.pk})

    def __str__(self) -> str:
        return self.title
