# TP01 — Tests et couverture : la première gate

> Durée estimée : 1 h 30 · Programme : jour 1, lab 1 · Gate : [Gate 1](../../docs/gates-securite.md#gate-1--tests-et-couverture)
> Prérequis : JDK 25 et Maven 3.9 (`java -version`, `mvn -version`).

## Le contexte

Néobanque Exemple, équipe « Comptes ». Le service de virement a une règle simple : **pas de découvert**.
Un développeur pressé a supprimé ce contrôle « pour débloquer un client »... et personne ne s'en est
aperçu, parce que le seul test existant vérifie le cas nominal.

La couverture de code sert ici de **garde-fou** : si quelqu'un supprime des tests, elle baisse et le
build casse. Elle ne prouve **pas** que les tests sont bons : un test sans assertion couvre des lignes
sans rien vérifier. Pour le prouver, on va injecter des défauts volontaires (des **mutants**) et
vérifier que vos tests les attrapent.

## Objectif vérifiable

`mvn verify` réussit avec une couverture de **80 %** (lignes et branches), au moins **8 cas de test**,
et **chacun des 3 mutants** du dossier `mutants/` fait échouer au moins un test.
`./verify.sh` contrôle tout cela.

---

## Étape 1 — Mesurer le point de départ

```bash
cd starter
mvn -B verify
```

Le build échoue sur `jacoco:check`. Ouvrez le rapport pour voir **quelles lignes** ne sont jamais
exécutées par les tests :

```bash
xdg-open target/site/jacoco/index.html   # ou ouvrez le fichier dans un navigateur
```

> **Question** : lisez `pom.xml`. À quelle phase Maven la règle de couverture s'exécute-t-elle ? Que se
> passerait-il si on la déplaçait dans un job CI séparé et facultatif ?

## Étape 2 — Restaurer la règle métier (TODO 1)

Dans `src/main/java/fr/telemach/tp01/ServiceVirement.java`, rétablissez le contrôle : si le solde de la
source est inférieur au montant, levez `SoldeInsuffisantException` **avant** de débiter quoi que ce soit.

> **Question** : pourquoi le contrôle doit-il se trouver **avant** `source.debiter(...)` ? Qu'est-ce qu'un
> client verrait si l'exception était levée après le débit mais avant le crédit ?

## Étape 3 — Écrire les tests (TODO 2 à 5)

Dans `src/test/java/fr/telemach/tp01/ServiceVirementTest.java` :

| TODO | Cas à tester | Ce qui doit être vérifié |
|---|---|---|
| 2 | Bruno (200,00 EUR) vire 200,01 EUR | `SoldeInsuffisantException` **et** les deux soldes inchangés |
| 3 | Bruno vire exactement 200,00 EUR | le virement passe, solde à zéro |
| 4 | montant nul, 0, négatif, 3 décimales, au-delà du plafond | `IllegalArgumentException` |
| 5 | virement d'un compte vers lui-même | `IllegalArgumentException` |

Les cas limites (exactement le solde, exactement le plafond) sont ceux qui attrapent les erreurs de
`<` au lieu de `<=`. Un test paramétré (`@ParameterizedTest`) évite de dupliquer cinq fois le même test.

```bash
mvn -B verify          # doit maintenant passer
```

## Étape 4 — La couverture ne suffit pas : les mutants

Regardez `mutants/` : trois copies du service, chacune avec **un** défaut. `verify.sh` remplace votre
service par chaque mutant et relance vos tests : ils **doivent échouer**. Un mutant qui survit est un
défaut que vos tests laisseraient passer en production.

```bash
cd ..
./verify.sh            # teste VOTRE travail (dossier starter/)
```

> **Question** : écrivez un test qui atteint 100 % de couverture sur `ServiceVirement` sans aucune
> assertion. Combien de mutants survivent ? Qu'en concluez-vous sur un objectif de « 100 % de couverture »
> imposé à une équipe ?

## Étape 5 — Validez

```bash
./verify.sh              # votre travail (starter/)
./verify.sh solution     # (option) la solution de référence
```

---

## Indices

<details>
<summary>Le contrôle de solde</summary>

```java
if (source.solde().compareTo(montant) < 0) {
	throw new SoldeInsuffisantException(source.id(), source.solde(), montant);
}
```

`BigDecimal` se compare avec `compareTo`, jamais avec `equals` (`2.0` et `2.00` ne sont pas `equals`).
</details>

<details>
<summary>Un test d'exception qui vérifie aussi l'absence d'effet de bord</summary>

```java
assertThrows(SoldeInsuffisantException.class,
		() -> service.virer(bruno, alice, new BigDecimal("200.01")));
assertEquals(new BigDecimal("200.00"), bruno.solde());
```
</details>

<details>
<summary>Un test paramétré avec une valeur nulle</summary>

```java
@ParameterizedTest
@NullSource
@ValueSource(strings = { "0", "-10.00", "10.001", "10000.01" })
void montantInvalideRefuse(BigDecimal montant) { ... }
```

JUnit convertit automatiquement la chaîne en `BigDecimal`.
</details>

---

## Où chercher (documentation officielle)

- **JUnit, tests paramétrés** : https://docs.junit.org/current/user-guide/#writing-tests-parameterized-tests
- **JaCoCo, règle `check`** : https://www.jacoco.org/jacoco/trunk/doc/check-mojo.html
- **Compteurs JaCoCo (lignes, branches)** : https://www.jacoco.org/jacoco/trunk/doc/counters.html
- **Tests de mutation avec PIT** : https://pitest.org/

---

## Pour aller plus loin

1. **PIT.** Ajoutez le plugin `pitest-maven` et lancez `mvn org.pitest:pitest-maven:mutationCoverage`.
   Combien de mutants PIT génère-t-il automatiquement ? Lesquels survivent à vos tests ?
2. **Pyramide.** Le vrai `bank-api` (dossier `app/`) a trois niveaux de tests : unitaires,
   `@WebMvcTest`, intégration (`*IT.java`, lancés par Failsafe). Retrouvez chacun et expliquez ce que
   chaque niveau vérifie que les autres ne vérifient pas.
3. **La gate en CI.** Dans `.gitlab-ci.yml` et `.github/workflows/ci.yml`, retrouvez le job qui lance
   `mvn verify`. Comment le rapport de couverture est-il publié dans la merge request ?
4. **Concurrence.** Deux virements simultanés depuis le compte de Bruno peuvent-ils tous deux passer le
   contrôle de solde ? Comment l'écrire en test, et comment le corriger (verrou, transaction) ?

---

<div align="center">

**[Telemach Learning](https://www.telemach-learning.fr)** — Formation DevSecOps

</div>
