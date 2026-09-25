package fr.telemach.tp01;

import java.math.BigDecimal;

public class SoldeInsuffisantException extends RuntimeException {

	public SoldeInsuffisantException(String compteId, BigDecimal solde, BigDecimal montant) {
		super("Solde insuffisant sur " + compteId + " : " + solde + " EUR pour un virement de " + montant + " EUR");
	}
}
