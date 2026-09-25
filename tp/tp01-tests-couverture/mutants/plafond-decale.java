// Mutant « plafond-decale » : copie de la solution avec UN défaut volontaire.
// verify.sh remplace ServiceVirement.java par ce fichier : vos tests doivent alors échouer.
package fr.telemach.tp01;

import java.math.BigDecimal;
import java.util.Objects;

/** Règles métier d'un virement entre deux comptes de la banque. */
public class ServiceVirement {

	/** Au-delà, un virement exige une validation renforcée (hors périmètre du TP). */
	public static final BigDecimal PLAFOND = new BigDecimal("10000.00");

	public void virer(Compte source, Compte cible, BigDecimal montant) {
		Objects.requireNonNull(source, "compte source");
		Objects.requireNonNull(cible, "compte cible");
		if (montant == null || montant.signum() <= 0) {
			throw new IllegalArgumentException("Le montant doit être strictement positif");
		}
		if (montant.scale() > 2) {
			throw new IllegalArgumentException("Le montant a au plus deux décimales");
		}
		if (montant.compareTo(PLAFOND) >= 0) {
			throw new IllegalArgumentException("Montant supérieur au plafond de " + PLAFOND + " EUR");
		}
		if (source.id().equals(cible.id())) {
			throw new IllegalArgumentException("Virement vers le même compte");
		}
		if (source.solde().compareTo(montant) < 0) {
			throw new SoldeInsuffisantException(source.id(), source.solde(), montant);
		}
		source.debiter(montant);
		cible.crediter(montant);
	}
}
