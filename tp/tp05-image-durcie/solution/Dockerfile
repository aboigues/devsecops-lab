# syntax=docker/dockerfile:1
# Étape 1 : compilation (le JDK et les sources ne sont jamais livrés)
FROM eclipse-temurin:25-jdk-noble@sha256:95e350ad1eb738f943e141640f7e3d797e483359a3b33c3864255bfd1ad71f8a AS build
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
