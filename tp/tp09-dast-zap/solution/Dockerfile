# syntax=docker/dockerfile:1
# Étape 1 : compilation (le JDK et les sources ne sont jamais livrés)
FROM eclipse-temurin:25-jdk-noble@sha256:589ff4cc3f71aab462e7048a47a0d10edf57fbccde3fceea2281e610bf5880b4 AS build
WORKDIR /src
COPY Main.java .
RUN javac -d /out Main.java

# Étape 2 : exécution sur le JRE seul, épinglé par tag (lisible) et digest (immuable)
FROM eclipse-temurin:25-jre-noble@sha256:d9a39a23634650173f1e2bbc176227af9728587ecf0f4b62d53e9355cd7a19ab
WORKDIR /app
COPY --from=build /out/ ./
# UID arbitraire non-root, groupe 0 : compatible avec la SCC restricted-v2 d'OpenShift
USER 10001:0
EXPOSE 8080
ENTRYPOINT ["java", "-cp", "/app", "Main"]
