# TP03 — SAST : trouver et corriger une injection SQL

> Durée estimée : 1 h · Programme : jour 1, lab 3 · Gate : [Gate 2](../../docs/gates-securite.md#gate-2--sast--injection-sql)
> Prérequis : JDK 25, **Semgrep 1.178** (`tp/scripts/installer-outils.sh`), accès Internet (règles `p/java`).

## Le contexte

Toujours lundi : Léa doit ajouter la recherche des comptes par titulaire et un tri configurable.
Elle écrit un dépôt JDBC « rapide » par concaténation. Avec `titulaire = x' OR '1'='1`, la requête
renvoie **tous les comptes de la banque** ; avec un tri `solde; DROP TABLE compte`, pire encore.

L'analyse statique (SAST) lit le code sans l'exécuter et signale ces motifs dangereux. Elle a deux
limites que ce TP met en évidence : elle ne comprend pas toujours une protection correcte (**faux
positif**), et une correction qui fait taire l'outil n'est pas forcément une correction. D'où un
second contrôle, fonctionnel, qui regarde **le SQL réellement envoyé à la base**.

## Objectif vérifiable

Semgrep (`p/java`) ne signale plus rien, toute exception `nosemgrep` est ciblée et justifiée, et le
contrôle fonctionnel `controle/ControleInjection.java` confirme qu'aucune entrée malveillante n'atteint
la base sous forme de SQL. `./verify.sh` contrôle tout cela.

---

## Étape 1 — Lancer le SAST

```bash
semgrep scan --config p/java --error --metrics=off starter/src
echo "code de sortie : $?"
```

Deux constats `formatted-sql-string`, lignes à l'appui. L'option `--error` donne un code de sortie non nul
dès qu'il y a un constat : c'est ce qui rend la gate **bloquante** en CI.

> **Question** : sans `--error`, Semgrep affiche les mêmes constats mais sort en 0. Quel serait l'effet
> sur un pipeline ? Retrouvez l'équivalent dans `.gitlab-ci.yml` (job SAST).

## Étape 2 — Voir l'attaque

Le contrôle fonctionnel simule une base : il enregistre le SQL que votre code envoie.

```bash
javac -d /tmp/tp03 starter/src/fr/telemach/tp03/*.java controle/ControleInjection.java
java -cp /tmp/tp03 ControleInjection
```

Lisez les lignes `ECHEC` : on y voit la requête finale, avec l'attaque dedans.

## Étape 3 — Corriger la recherche (TODO 1)

Remplacez la concaténation par une **requête préparée** : le SQL contient un `?`, la valeur est transmise
à part avec `setString`. La base ne l'interprète jamais comme du SQL, quel que soit son contenu.

## Étape 4 — Corriger le tri (TODO 2)

Un nom de colonne **ne peut pas** être un paramètre `?` (seules les valeurs se lient). La défense est une
**liste blanche** : `id`, `titulaire`, `solde`, et rien d'autre.

Essayez d'abord la version la plus naturelle : vérifier que `colonne` est dans la liste, puis
concaténer. Relancez Semgrep.

> **Question** : le contrôle fonctionnel passe, mais Semgrep signale toujours la ligne. Est-ce un vrai ou un
> faux positif ? Deux réponses acceptables : (a) réécrire pour que chaque requête soit une **constante**
> (l'outil n'a plus rien à signaler) ; (b) garder le code et poser une exception **ciblée et justifiée** :
> `// nosemgrep: java.lang.security.audit.formatted-sql-string.formatted-sql-string -- colonne en liste blanche ci-dessus`.
> Laquelle préférez-vous pour un code relu par d'autres dans deux ans ? Pourquoi un `nosemgrep` sans nom de
> règle ni justification est-il refusé par `verify.sh` ?

## Étape 5 — Validez

```bash
./verify.sh              # votre travail (starter/)
./verify.sh solution     # (option) la solution de référence
```

---

## Indices

<details>
<summary>Requête préparée</summary>

```java
try (PreparedStatement ps = connexion.prepareStatement(
		"SELECT id, titulaire, solde FROM compte WHERE titulaire = ?")) {
	ps.setString(1, titulaire);
	try (ResultSet rs = ps.executeQuery()) {
		return lire(rs);
	}
}
```
</details>

<details>
<summary>Liste blanche en requêtes constantes</summary>

```java
String sql = switch (colonne) {
	case "id" -> "SELECT id, titulaire, solde FROM compte ORDER BY id";
	case "titulaire" -> "SELECT id, titulaire, solde FROM compte ORDER BY titulaire";
	case "solde" -> "SELECT id, titulaire, solde FROM compte ORDER BY solde";
	default -> throw new IllegalArgumentException("Colonne de tri non autorisée");
};
```

Le refus doit intervenir **avant** tout envoi à la base.
</details>

---

## Où chercher (documentation officielle)

- **OWASP, prévention des injections SQL** : https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html
- **Semgrep, ignorer un constat** : https://semgrep.dev/docs/ignoring-files-folders-code
- **Règle `formatted-sql-string`** : https://semgrep.dev/r/java.lang.security.audit.formatted-sql-string.formatted-sql-string
- **CodeQL, requête `java/sql-injection`** : https://codeql.github.com/codeql-query-help/java/java-sql-injection/

---

## Pour aller plus loin

1. **Votre propre règle.** Écrivez une règle Semgrep (`regles.yml`) qui interdit `createStatement()` dans
   tout le paquet `fr.telemach`. Lancez-la avec `semgrep scan --config regles.yml`.
2. **Analyse de flux.** CodeQL (workflow `.github/workflows/codeql.yml`) suit la donnée depuis le paramètre
   HTTP jusqu'à la requête. Pourquoi une analyse de flux produit-elle moins de faux positifs sur la liste
   blanche que la recherche de motifs de Semgrep ? Qu'est-ce qu'elle coûte en échange ?
3. **ORM.** Avec Spring Data JPA, `@Query("... where titulaire = :t")` est sûr ; une requête native construite
   par concaténation ne l'est pas. `bank-api` (dossier `app/`) garde ses comptes en mémoire : proposez
   l'ajout d'une base avec Spring Data JPA, puis vérifiez que Semgrep et CodeQL restent muets.
4. **Le jour 1 de l'étude de cas.** Relisez le « Lundi » de `docs/scenario-entreprise.md` : quel autre
   contrôle a arrêté Léa le même jour, et pourquoi le SAST ne l'aurait pas vu ?

---

<div align="center">

**[Telemach Learning](https://www.telemach-learning.fr)** — Formation DevSecOps

</div>
