# syntax=docker/dockerfile:1
# Images de base épinglées par tag (lisible) ET digest (immuable). Dependabot ne propose que le
# rafraîchissement du digest (même version, correctifs OS) ; les montées de JDK/Maven sont manuelles.
# Étape 1 : build Maven (jamais embarquée dans l'image finale)
FROM docker.io/library/maven:3.9.16-eclipse-temurin-25@sha256:dd8e01b3be719853578c07b57ff8d9bbbbfe746f802226f05b19689420815221 AS build
WORKDIR /src
COPY pom.xml .
RUN --mount=type=cache,target=/root/.m2 mvn -B -q dependency:go-offline
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn -B -q package -DskipTests \
 && java -Djarmode=tools -jar target/bank-api-*.jar extract --layers --launcher --destination /extracted

# Étape 2 : image d'exécution minimale (JRE seul, pas de shell de build ni de Maven)
FROM docker.io/library/eclipse-temurin:25-jre-noble@sha256:b573af9e331196fbc42e246da4df24df9b6c556c73e7efddfde0511f1c9508c5
WORKDIR /app
# Couches séparées : les dépendances changent rarement, le code souvent -> cache efficace
COPY --from=build /extracted/dependencies/ ./
COPY --from=build /extracted/spring-boot-loader/ ./
COPY --from=build /extracted/snapshot-dependencies/ ./
COPY --from=build /extracted/application/ ./
# Compatible OpenShift (restricted-v2) : UID arbitraire, membre du groupe 0,
# fichiers lisibles par le groupe, aucun droit d'écriture requis
RUN chgrp -R 0 /app && chmod -R g=u /app
USER 10001:0
EXPOSE 8080
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75 -XX:+ExitOnOutOfMemoryError"
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
