# Journal de sécurité

Constats réels relevés par la chaîne sur ce dépôt, et leur traitement. Sert aussi de cas d'étude en formation.

## 2026-09-23 — Tomcat embarqué vulnérable (SCA)

- **Détection** : `trivy` sur l'artefact `bank-api-0.0.1-SNAPSHOT.jar`, dès la première construction.
- **Constat** : `tomcat-embed-core` 11.0.24, version gérée par Spring Boot 4.1.1 (dernière version
  stable du jour), porte 3 CVE **CRITICAL** corrigées en 11.0.25 : CVE-2026-65182 (contournement de
  contrainte de sécurité), CVE-2026-65905 (rejeu DIGEST), CVE-2026-68525 (contournement FORM).
- **Exposition réelle** : faible pour cette API (ni DIGEST ni FORM, pas de contrainte de sécurité
  déclarative), mais le seuil du pipeline est volontairement indépendant de cette analyse :
  un correctif existe, donc on l'applique.
- **Remédiation** : surcharge de la propriété `tomcat.version` à 11.0.26 dans `app/pom.xml`,
  commentée avec les CVE et la condition de retrait.
- **Vérification** : 13 tests verts, nouveau scan à 0 vulnérabilité HIGH/CRITICAL.
- **Enseignement** : « dernière version du framework » ne veut pas dire « sans vulnérabilité connue ».
  Le scan de dépendances doit tourner à chaque build, pas seulement lors des montées de version.
