# TP09 — DAST : attaquer l'application démarrée avec ZAP

> Durée estimée : 1 h · Programme : jour 3, lab 10 · Gate : [Gate 8](../../docs/gates-securite.md#gate-8--dast--lapplication-attaquée-en-boîte-noire) · Port utilisé : `8089`
> Prérequis : Docker, `curl`. ZAP est lancé en conteneur (image épinglée, la même que la CI du dépôt).

## Le contexte

Jeudi, mise en production du micro-service « soldes ». Les analyses statiques (SAST, SCA, IaC) lisent le
code et la configuration ; aucune ne regarde ce que l'application **répond réellement** sur le réseau.
C'est le rôle du **DAST** (*Dynamic Application Security Testing*) : on démarre l'application, et un
outil l'analyse en boîte noire, comme le ferait un attaquant, sans voir le code.

ZAP baseline explore l'API et vérifie, entre autres, les en-têtes de sécurité. Une réponse JSON sans
`X-Content-Type-Options` peut être interprétée comme du HTML par un navigateur ; un solde bancaire sans
`Cache-Control: no-store` peut rester dans le cache d'un poste partagé ou d'un proxy.

## Objectif vérifiable

L'application, démarrée durcie (non-root, lecture seule, aucune capacité), renvoie les quatre en-têtes
attendus, et ZAP baseline se termine **sans aucune alerte WARN ni FAIL**, avec au plus deux règles
rétrogradées en INFO, chacune justifiée. `./verify.sh` contrôle tout cela et dépose le rapport HTML de
ZAP dans votre dossier (`zap-report.html`).

---

## Étape 1 — Première attaque

```bash
./verify.sh
```

Le script construit l'image, la démarre et lance ZAP. Sortie réelle sur le starter (ZAP 2.17.0) :

```
WARN-NEW: X-Content-Type-Options Header Missing [10021] x 1
WARN-NEW: Storable and Cacheable Content [10049] x 4
WARN-NEW: Cross-Origin-Resource-Policy Header Missing or Invalid [90004] x 1
FAIL-NEW: 0	FAIL-INPROG: 0	WARN-NEW: 3	WARN-INPROG: 0	INFO: 0	IGNORE: 0	PASS: 64
```

Ouvrez `starter/zap-report.html` : pour chaque alerte, ZAP donne l'URL, la preuve et la correction proposée.

> **Question** : ZAP sort avec le code 2 dès qu'il y a un WARN. Pourquoi est-ce le bon choix pour une gate
> (voir le job `container` de `.github/workflows/ci.yml`, sans option `-I`) ?

## Étape 2 — Corriger la cause (TODO 1)

Dans `starter/Main.java`, méthode `repondre`, ajoutez les en-têtes :

| En-tête | Valeur | Protège contre |
|---|---|---|
| `X-Content-Type-Options` | `nosniff` | Un navigateur qui « devine » du HTML dans du JSON |
| `Cache-Control` | `no-store` | Des soldes conservés par un cache (ASVS V8.2.1) |
| `Content-Security-Policy` | `default-src 'none'; frame-ancestors 'none'` | Scripts, styles, cadres : une API n'en sert pas |
| `Cross-Origin-Resource-Policy` | `same-origin` | La lecture de la réponse par un autre site |

Comparez avec `app/src/main/java/fr/telemach/bankapi/SecurityHeadersFilter.java` à la racine du dépôt.

## Étape 3 — Trier ce qui reste (TODO 2)

Relancez `./verify.sh`. Selon l'exploration de ZAP, une nouvelle alerte peut apparaître :

```
WARN-NEW: Non-Storable Content [10049] x 3
```

ZAP avertit maintenant que les réponses **ne peuvent pas** être mises en cache... ce que vous venez de
demander. Vrai ou faux positif **dans ce contexte** ? Si vous concluez au faux positif, rétrogradez
**cette règle seule** en `INFO` (jamais `IGNORE` : elle doit rester visible dans le rapport), avec un
commentaire daté qui justifie la décision, dans `starter/baseline.conf` (séparateur : tabulation).

C'est le cas réel de ce dépôt : la toute première exécution de ZAP sur `bank-api` a échoué sur cette
règle. Lisez sa justification dans `.zap/baseline.conf` et dans `docs/journal-securite.md`.

> **Question** : pourquoi ne pas simplement ajouter l'option `-I` (ignorer tous les avertissements) ? Quelle
> alerte **réelle** passerait alors inaperçue le jour où quelqu'un retire un en-tête ?

## Étape 4 — Validez

```bash
./verify.sh              # votre travail (starter/)
./verify.sh solution     # (option) la solution de référence
```

---

## Indices

<details>
<summary>Poser des en-têtes avec le serveur HTTP du JDK</summary>

```java
Headers entetes = echange.getResponseHeaders();
entetes.set("X-Content-Type-Options", "nosniff");
entetes.set("Cache-Control", "no-store");
```

Import : `com.sun.net.httpserver.Headers`. Les en-têtes doivent être posés **avant** `sendResponseHeaders`.
</details>

<details>
<summary>Une exception ZAP tracée</summary>

```
# 10049 Non-Storable Content - AAAA-MM-JJ : pourquoi c'est voulu ici, et quand le revoir.
10049	INFO	(Non-Storable Content)
```

`zap-baseline.py -g gen.conf` génère un fichier avec toutes les règles et leur niveau par défaut.
</details>

---

## Où chercher (documentation officielle)

- **ZAP baseline scan** : https://www.zaproxy.org/docs/docker/baseline-scan/
- **Règles passives de ZAP** : https://www.zaproxy.org/docs/alerts/
- **OWASP Secure Headers Project** : https://owasp.org/www-project-secure-headers/
- **OWASP ASVS** : https://owasp.org/www-project-application-security-verification-standard/

---

## Pour aller plus loin

1. **Scan actif.** `zap-full-scan.py` envoie de vraies attaques (injections, traversées de chemin). Pourquoi
   ne le lance-t-on jamais sur un environnement partagé ou de production sans autorisation écrite ?
2. **API décrite.** `zap-api-scan.py` explore une API à partir de sa description OpenAPI. Quelle couverture
   gagne-t-on par rapport à l'exploration « à l'aveugle » de la baseline ?
3. **Ce que le DAST ne voit pas.** Relisez le « Vendredi » de `docs/scenario-entreprise.md` : l'API de la
   banque n'a aucune authentification, et aucune gate ne l'a signalé. Pourquoi ZAP baseline ne pouvait-il pas
   le voir ? Quel type de test l'aurait détecté ?
4. **Dans le pipeline.** Retrouvez le job DAST dans `.gitlab-ci.yml` : comment l'application est-elle
   démarrée avant le scan, et comment le rapport est-il publié ?

---

<div align="center">

**[Telemach Learning](https://www.telemach-learning.fr)** — Formation DevSecOps

</div>
