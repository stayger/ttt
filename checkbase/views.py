from typing import Any, Dict
from .models import Base, Server
from django.views.generic import ListView, DetailView
import pyodbc
import os


class ServerList(ListView):
    model = Server
    context_object_name = "servers"


class ServerDetail(DetailView):
    model = Server
    context_object_name = "server"
    # extra_context = Server.objects.all()

    def get_context_data(self, **kwargs: Any) -> Dict[str, Any]:
        context = super().get_context_data(**kwargs)
        context["bases"] = Base.objects.filter(server=self.kwargs.get("pk", None))
        context["servers"] = Server.objects.all()
        tmp = []
        conn_str = f"Driver={{SQL Server}};Server={self.object.title};Database=master;UID={self.object.username};PWD={self.object.password};"
        try:
            cnxn = pyodbc.connect(conn_str,timeout=1)
            cursor = cnxn.cursor()
            sql_query = ""
            with open("checkbase\sql\with.sql", "r", encoding="utf8") as inp:
                for line in inp:
                    sql_query = sql_query + line
            cursor.execute(sql_query)
            cursor.execute("select dbname, status from #CheckDatabaseFiles")
            rows = cursor.fetchall()
            for row in rows:
                str = "неопределено"
                if row[1] == 5:
                    str = "Бэкапов ещё не было"
                if row[1] == 1:
                    str = "Ошибки файлов"
                if row[1] == 0:
                    str = " OK "
                tmp.append([row[0], str])
            cursor.close()
        except Exception as e:
            tmp.append([self.object.title,'Ошибка подключения'])
        context["bases2"] = tmp
        return context


class BaseDetail(DetailView):
    model = Base
    context_object_name = "base"

    def get_context_data(self, **kwargs: Any) -> Dict[str, Any]:
        context = super().get_context_data(**kwargs)
        context["bases"] = Base.objects.filter(server=self.kwargs.get("pk", None))
        context["servers"] = Server.objects.all()
        return context
