# ДЗ 2. Климов И. А., БИСТ-23-ПО-2, вариант 01.
# Компилятор и заголовки остаются только на этапе build.
FROM python:3.12-alpine AS build
RUN apk add --no-cache build-base postgresql-dev mariadb-connector-c-dev pkgconf
WORKDIR /app
RUN python -m venv /venv
COPY requirements.txt .
RUN /venv/bin/pip install --no-cache-dir -r requirements.txt

FROM python:3.12-alpine
RUN apk add --no-cache libpq mariadb-connector-c
WORKDIR /app
COPY --from=build /venv /venv
ENV PATH="/venv/bin:${PATH}"
ENV PYTHONDONTWRITEBYTECODE=1
COPY app.py .

ARG VERSION=5.0
RUN echo "$VERSION" > /app/VERSION
STOPSIGNAL SIGINT
CMD ["python", "app.py"]
