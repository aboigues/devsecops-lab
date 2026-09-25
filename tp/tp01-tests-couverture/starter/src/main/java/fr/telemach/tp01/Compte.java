package fr.telemach.tp01;

import java.math.BigDecimal;
import java.util.Objects;

/** Compte bancaire minimal : un identifiant, un titulaire, un solde en euros. */
public final class Compte {

	private final String id;
	private final String titulaire;
	private BigDecimal solde;

	public Compte(String id, String titulaire, BigDecimal soldeInitial) {
		this.id = Objects.requireNonNull(id);
		this.titulaire = Objects.requireNonNull(titulaire);
		this.solde = Objects.requireNonNull(soldeInitial);
	}

	public String id() {
		return id;
	}

	public String titulaire() {
		return titulaire;
	}

	public BigDecimal solde() {
		return solde;
	}

	void debiter(BigDecimal montant) {
		solde = solde.subtract(montant);
	}

	void crediter(BigDecimal montant) {
		solde = solde.add(montant);
	}
}
