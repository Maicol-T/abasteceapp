# Imagen del backend de AbasteceApp para Render.
#
# Render no tiene runtime nativo de Dart: se compila a un ejecutable AOT y la
# imagen final solo lleva el binario y el panel web ya compilado.

# ---- 1. Compilación ----
FROM dart:stable AS build

WORKDIR /src
COPY pubspec.yaml pubspec.lock ./
RUN dart pub get

COPY bin ./bin
COPY lib ./lib
RUN mkdir -p /out && dart compile exe bin/server.dart -o /out/server

# ---- 2. Runtime mínimo ----
FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN useradd --create-home --uid 10001 app \
    && mkdir -p /app/web /app/data \
    && chown -R app:app /app

COPY --from=build --chown=app:app /out/server /app/server
COPY --chown=app:app web/ /app/web/

USER app

# Render inyecta PORT (10000 por defecto); el servidor lo lee de las variables
# de entorno, así que NO se fija el puerto en el comando.
EXPOSE 10000

CMD ["/app/server", "--data", "/app/data/store.json", "--web", "/app/web"]
