# syntax=docker/dockerfile:1
# Étape 1 : compilation (le JDK et les sources ne sont jamais livrés)
FROM eclipse-temurin:25-jdk-noble@sha256:2feab631bffce6236d8bb5261a4abe19a8d6f85bad1c01166f74686c983d011f AS build
WORKDIR /src
COPY Main.java .
RUN javac -d /out Main.java

# Étape 2 : exécution sur le JRE seul, épinglé par tag (lisible) et digest (immuable)
FROM eclipse-temurin:25-jre-noble@sha256:b573af9e331196fbc42e246da4df24df9b6c556c73e7efddfde0511f1c9508c5
WORKDIR /app
COPY --from=build /out/ ./
# UID arbitraire non-root, groupe 0 : compatible avec la SCC restricted-v2 d'OpenShift
USER 10001:0
EXPOSE 8080
ENTRYPOINT ["java", "-cp", "/app", "Main"]
