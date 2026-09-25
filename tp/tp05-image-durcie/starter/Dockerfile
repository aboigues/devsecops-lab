# Image « qui marche » : elle démarre et répond. Elle ne passera pas la revue sécurité.

# TODO 1 : épingler l'image de base : version explicite (25-jdk-noble) ET digest (@sha256:...).
#          Un tag flottant (latest) change sans prévenir sous vos pieds.
FROM eclipse-temurin:latest

WORKDIR /app
# TODO 2 : ne copier que le nécessaire (Main.java), et ajouter un .dockerignore.
COPY . .
RUN javac Main.java

# TODO 3 : multi-stage. Compiler dans une étape « build » (JDK), puis repartir d'une image JRE
#          (eclipse-temurin:25-jre-noble, épinglée elle aussi) qui ne reçoit que les .class compilés.
#          L'image finale ne doit contenir ni compilateur (javac) ni code source.

# TODO 4 : ne pas tourner en root : USER 10001:0 (UID arbitraire, groupe 0 : compatible OpenShift).

EXPOSE 8080
CMD ["java", "Main"]
