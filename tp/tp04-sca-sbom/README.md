# TP04 — SCA et SBOM : une gate qui bloque, un inventaire qui répond

> Durée estimée : 1 h 30 · Programme : jour 2, lab 4 · Gate : [Gate 4](../../docs/gates-securite.md#gate-4--sca--log4shell-dans-une-dépendance)
> Prérequis : JDK 25, Maven 3.9, **Trivy 0.74**, `jq` (`tp/scripts/installer-outils.sh`).

## Le contexte

Mercredi matin chez Néobanque Exemple, une alerte tombe : CVE critique dans une bibliothèque de
journalisation. La RSSI, Nadia, pose deux questions :

1. **Sommes-nous concernés, et où ?** Il faut répondre en minutes, pas en jours. C'est le rôle du
   **SBOM** (*Software Bill of Materials*) : l'inventaire de tout ce qui est embarqué, y compris les
   dépendances **transitives** que personne n'a choisies explicitement.
2. **Est-ce que ça peut se reproduire ?** Non, si une **gate SCA** (*Software Composition Analysis*)
   refuse toute dépendance vulnérable avant la fusion.

Le projet `projet/` (un service d'exports qui utilise log4j) est à jour. Votre travail : écrire la gate
et l'outil d'interrogation du SBOM, puis prouver que la gate **bloque** vraiment.

## Objectif vérifiable

`sca.sh` passe sur le projet sain, produit un SBOM CycloneDX qui recense les dépendances transitives,
et **échoue** si log4j-core 2.14.1 (Log4Shell) est introduit ; `concerne.sh` répond « nom version » pour un
composant présent et sort en erreur sinon. `./verify.sh` contrôle tout cela.

---

## Étape 1 — Ce qui est réellement livré

```bash
mvn -B -q -f projet/pom.xml package dependency:copy-dependencies -DincludeScope=runtime
ls projet/target/dependency
```

Le `pom.xml` ne déclare **qu'une** dépendance. Combien de JAR sont livrés ?

> **Question** : pourquoi scanner les JAR construits plutôt que le `pom.xml` ? (Indices : dépendances
> transitives, versions résolues, et le journal du dépôt : `trivy fs` sur un `pom.xml` interroge Maven
> Central et se heurte à des limites de débit, d'où le scan hors ligne `--offline-scan`.)

## Étape 2 — Le SBOM (TODO 1)

Dans `starter/sca.sh`, produisez le SBOM CycloneDX de `target/dependency` avec `trivy rootfs`.

```bash
./starter/sca.sh projet
jq '.components[] | {name, version}' projet/target/sbom.cdx.json
```

> **Question** : le SBOM doit être produit **avant** le scan bloquant. Pourquoi ? Dans quelle situation en
> a-t-on le plus besoin ?

## Étape 3 — La gate (TODO 2)

Tel qu'il est livré, `sca.sh` lance Trivy... et réussit toujours. Une gate qui ne bloque jamais n'est pas
une gate. Complétez la commande : vulnérabilités seulement, HIGH et CRITICAL, uniquement celles qui ont
un correctif, code de sortie non nul si on en trouve.

Puis introduisez la faille **dans une copie** du projet :

```bash
cp -r projet /tmp/vulnerable
sed -i 's|<log4j.version>.*</log4j.version>|<log4j.version>2.14.1</log4j.version>|' /tmp/vulnerable/pom.xml
./starter/sca.sh /tmp/vulnerable; echo "code de sortie : $?"
```

> **Question** : `--ignore-unfixed` écarte les vulnérabilités sans correctif publié. Pourquoi est-ce
> raisonnable pour une gate bloquante ? Que fait-on de ces vulnérabilités-là (voir `.trivyignore` et
> `docs/journal-securite.md`) ?

## Étape 4 — Répondre à Nadia (TODO 3)

Complétez `starter/concerne.sh` : une requête `jq` qui répond « nom version » pour un composant, et sort
en erreur s'il est absent.

```bash
./starter/concerne.sh projet/target/sbom.cdx.json log4j-core
./starter/concerne.sh projet/target/sbom.cdx.json log4j-api
```

> **Question** : Log4Shell touchait `log4j-core`, pas `log4j-api`. Pourquoi une recherche approximative
> (« log4j ») aurait-elle donné une mauvaise réponse à Nadia ? Relisez le « Mercredi » de
> `docs/scenario-entreprise.md`.

## Étape 5 — Validez

```bash
./verify.sh              # votre travail (starter/)
./verify.sh solution     # (option) la solution de référence
```

---

## Indices

<details>
<summary>SBOM CycloneDX avec Trivy</summary>

```bash
trivy rootfs --quiet --offline-scan --format cyclonedx \
  --output "$PROJET/target/sbom.cdx.json" "$PROJET/target/dependency"
```
</details>

<details>
<summary>Une gate qui bloque</summary>

```bash
trivy rootfs --quiet --offline-scan --scanners vuln \
  --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 "$PROJET/target/dependency"
```
</details>

<details>
<summary>Interroger le SBOM</summary>

```bash
jq -r --arg nom "$NOM" '[.components[]? | select(.name == $nom) | "\(.name) \(.version)"] | unique | .[]' "$SBOM"
```

Stockez le résultat dans une variable et sortez en erreur si elle est vide.
</details>

---

## Où chercher (documentation officielle)

- **Trivy, SBOM** : https://trivy.dev/latest/docs/supply-chain/sbom/
- **Trivy, filtrage (`--ignore-unfixed`, `.trivyignore`)** : https://trivy.dev/latest/docs/configuration/filtering/
- **CycloneDX** : https://cyclonedx.org/specification/overview/
- **Log4Shell (CVE-2021-44228)** : https://nvd.nist.gov/vuln/detail/CVE-2021-44228
- **jq** : https://jqlang.org/manual/

---

## Pour aller plus loin

1. **Le vrai SBOM.** Téléchargez celui de `main` : `gh run download <run> -n app-reports`. Combien de
   composants ? `log4j-core` y figure-t-il ? Et `log4j-api` ?
2. **Rescanner sans reconstruire.** `trivy sbom sbom.cdx.json` scanne un SBOM archivé. Pourquoi est-ce
   précieux le jour où une CVE sort pour une version livrée il y a six mois ?
3. **Revue des dépendances.** Sur GitHub, `dependency-review-action` (job du même nom dans
   `.github/workflows/ci.yml`) refuse l'ajout d'une dépendance vulnérable **ou sous licence AGPL**. Pourquoi
   une licence est-elle un risque au même titre qu'une CVE ?
4. **Dependabot peut régresser.** Lisez le cas réel de la PR #2 dans `docs/journal-securite.md` : pourquoi
   la fusion automatique des PR de dépendances est-elle désactivée sur ce dépôt ?

---

<div align="center">

**[Telemach Learning](https://www.telemach-learning.fr)** — Formation DevSecOps

</div>
