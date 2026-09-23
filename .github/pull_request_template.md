## Objet

<!-- Quoi et pourquoi, en une ou deux phrases. -->

## Vérifications

- [ ] Toutes les gates de la CI sont vertes (aucun seuil abaissé pour y parvenir)
- [ ] Aucun secret, IP personnelle, `*.tfvars`, `backend.hcl` ni state dans le diff
- [ ] Toute nouvelle exception de sécurité est justifiée, datée et consignée dans `docs/journal-securite.md`
- [ ] Aucune ressource Scaleway laissée active si un déploiement a été testé
