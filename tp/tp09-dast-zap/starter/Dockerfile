# syntax=docker/dockerfile:1
# Étape 1 : compilation (le JDK et les sources ne sont jamais livrés)
FROM eclipse-temurin:25-jdk-noble@sha256:589ff4cc3f71aab462e7048a47a0d10edf57fbccde3fceea2281e610bf5880b4 AS build
WORKDIR /src
COPY Main.java .
RUN javac -d /out Main.java

# Étape 2 : exécution sur le JRE seul, épinglé par tag (lisible) et digest (immuable)
FROM eclipse-temurin:25-jre-noble@sha256:a98128a57de944a72bd31fbc79b898edd5a5864d3652071d5bbd2160ab7d7dce
WORKDIR /app
COPY --from=build /out/ ./
# UID arbitraire non-root, groupe 0 : compatible avec la SCC restricted-v2 d'OpenShift
USER 10001:0
EXPOSE 8080
ENTRYPOINT ["java", "-cp", "/app", "Main"]
