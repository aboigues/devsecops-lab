# TP05 — Image durcie : multi-stage, non-root, épinglée, scannée

> Durée estimée : 1 h 30 · Programme : jour 2, lab 5 · Gates : [Gate 6](../../docs/gates-securite.md#gate-6--iac--un-pod-privilégié-un-dockerfile-root) et [Gate 7](../../docs/gates-securite.md#gate-7--scan-de-limage) · Port utilisé : `8085`
> Prérequis : Docker, **Trivy 0.74** (`tp/scripts/installer-outils.sh`), `curl`.

## Le contexte

L'équipe « Comptes » livre un micro-service de consultation des soldes. Son Dockerfile « marche » :
l'image démarre et répond. Mais elle part en production dans un cluster partagé, et Théo (équipe
plateforme) la refuse en revue :

- elle tourne en **root** : une faille applicative donne root dans le conteneur, à un pas du nœud ;
- elle embarque le **JDK complet** (compilateur compris) et les **sources** : autant d'outils offerts à
  un attaquant et de paquets à maintenir ;
- elle part de `latest` : l'image change sans prévenir, et on ne sait plus ce qui a été scanné.

## Objectif vérifiable

`trivy config` ne trouve aucun défaut MEDIUM ou plus, chaque `FROM` est épinglé par digest, l'image est
multi-stage, sans `javac` ni sources, tourne en non-root, n'a aucune vulnérabilité HIGH/CRITICAL
corrigeable, et répond sur `/health` avec un système de fichiers en **lecture seule** et **aucune
capacité Linux**. `./verify.sh` contrôle tout cela.

---

## Étape 1 — Mesurer le problème

```bash
cd starter
trivy config --severity MEDIUM,HIGH,CRITICAL .
docker build -t soldes:naive .
docker run --rm --entrypoint id soldes:naive          # uid=0(root)
docker run --rm --entrypoint javac soldes:naive -version
docker images soldes:naive
```

Sortie réelle de `trivy config` sur ce Dockerfile (Trivy 0.74.0) :

```
Failures: 2 (MEDIUM: 1, HIGH: 1, CRITICAL: 0)
DS-0001 (MEDIUM): Specify a tag in the 'FROM' statement for image 'eclipse-temurin'
DS-0002 (HIGH): Specify at least 1 USER command in Dockerfile with non-root user as argument
```

> **Question** : le jour de l'écriture de ce TP, `trivy image` ne trouvait **aucune** vulnérabilité
> HIGH/CRITICAL dans cette image naïve. Est-ce que cela la rend acceptable ? Qu'est-ce qu'un scan de
> vulnérabilités ne voit pas (root, compilateur, tag flottant) ?

## Étape 2 — Épingler (TODO 1)

Remplacez `latest` par une version explicite **et** un digest :

```bash
docker buildx imagetools inspect eclipse-temurin:25-jdk-noble --format '{{json .Manifest.Digest}}'
```

```dockerfile
FROM eclipse-temurin:25-jdk-noble@sha256:<digest> AS build
```

> **Question** : le tag est lisible par un humain, le digest est immuable. Pourquoi garder les deux ?
> Qui met à jour le digest quand Ubuntu publie un correctif (voir `.github/dependabot.yml`) ?

## Étape 3 — Multi-stage et contexte minimal (TODO 2 et 3)

- **Étape `build`** : JDK, `COPY Main.java .`, `RUN javac -d /out Main.java`.
- **Étape finale** : `eclipse-temurin:25-jre-noble` (épinglée), `COPY --from=build /out/ ./`, et un
  `ENTRYPOINT ["java", "-cp", "/app", "Main"]`.
- Un `.dockerignore` qui exclut tout sauf `Main.java` : rien d'autre ne doit entrer dans le contexte de build.

> **Question** : pourquoi `java Main.java` (lancement direct d'un fichier source) ne fonctionne-t-il plus
> sur l'image JRE ? Qu'est-ce que cela dit de ce qu'on a retiré ?

## Étape 4 — Non-root (TODO 4)

```dockerfile
USER 10001:0
```

Un UID numérique arbitraire, groupe 0 : c'est ce qu'exige OpenShift (SCC `restricted-v2`), qui lance le
conteneur avec un UID aléatoire. Comparez avec `app/Dockerfile` à la racine du dépôt.

## Étape 5 — Tester sous contraintes

```bash
docker build -t soldes:durcie .
docker run --rm -d --name soldes --read-only --tmpfs /tmp --cap-drop ALL \
  --security-opt no-new-privileges -p 8085:8080 soldes:durcie
curl -s http://localhost:8085/health
docker rm -f soldes
trivy image --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 soldes:durcie
```

Ces options reproduisent le `securityContext` du Deployment (`gitops/base/deployment.yaml`) : ce qui marche
ici marchera dans le namespace en Pod Security Admission `restricted`.

## Étape 6 — Validez

```bash
cd ..
./verify.sh              # votre travail (starter/)
./verify.sh solution     # (option) la solution de référence
```

Mesure du 25/09/2026 : image naïve environ 585 Mo, image durcie environ 430 Mo.

---

## Indices

<details>
<summary>Squelette du Dockerfile multi-stage</summary>

```dockerfile
# syntax=docker/dockerfile:1
FROM eclipse-temurin:25-jdk-noble@sha256:<digest> AS build
WORKDIR /src
COPY Main.java .
RUN javac -d /out Main.java

FROM eclipse-temurin:25-jre-noble@sha256:<digest>
WORKDIR /app
COPY --from=build /out/ ./
USER 10001:0
EXPOSE 8080
ENTRYPOINT ["java", "-cp", "/app", "Main"]
```
</details>

<details>
<summary>Un .dockerignore en liste blanche</summary>

```
*
!Main.java
```
</details>

---

## Où chercher (documentation officielle)

- **Builds multi-stage** : https://docs.docker.com/build/building/multi-stage/
- **Bonnes pratiques Dockerfile** : https://docs.docker.com/build/building/best-practices/
- **Trivy, scan de configuration** : https://trivy.dev/latest/docs/scanner/misconfiguration/
- **Images Eclipse Temurin** : https://hub.docker.com/_/eclipse-temurin
- **OpenShift, UID arbitraires** : https://docs.redhat.com/en/documentation/openshift_container_platform/latest/html/images/creating-images#use-uid_create-images

---

## Pour aller plus loin

1. **jlink.** Construisez un runtime Java réduit aux seuls modules utilisés (`jdeps` pour les trouver,
   `jlink --add-modules ...`) et livrez-le sur une base minimale. Quelle taille atteignez-vous ?
2. **Distroless.** Essayez `gcr.io/distroless/java25-debian13:nonroot` si elle existe au moment où vous
   lisez ces lignes (vérifiez). Plus de shell : comment déboguer un conteneur sans shell (`kubectl debug`) ?
3. **Construction sans privilège.** Le runner GitLab du lab construit les images avec **Buildah rootless**,
   sans Docker-in-Docker. Lisez `.gitlab-ci.yml` : pourquoi un runner privilégié est-il dangereux ?
4. **Signature.** Signez l'image avec `cosign` et vérifiez la signature. Pourquoi la provenance d'une
   image compte-t-elle autant que son contenu ?

---

<div align="center">

**[Telemach Learning](https://www.telemach-learning.fr)** — Formation DevSecOps

</div>
