package fr.telemach.tp01;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.math.BigDecimal;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class ServiceVirementTest {

	private final ServiceVirement service = new ServiceVirement();
	private Compte alice;
	private Compte bruno;

	@BeforeEach
	void comptes() {
		alice = new Compte("FR76-0001", "Alice", new BigDecimal("1500.00"));
		bruno = new Compte("FR76-0002", "Bruno", new BigDecimal("200.00"));
	}

	@Test
	void virementNominalDebiteEtCredite() {
		service.virer(alice, bruno, new BigDecimal("100.00"));

		assertEquals(new BigDecimal("1400.00"), alice.solde());
		assertEquals(new BigDecimal("300.00"), bruno.solde());
	}

	// TODO 2 : un virement de 200,01 EUR depuis le compte de Bruno (solde 200,00 EUR) est refusé
	//          (SoldeInsuffisantException) ET aucun des deux soldes n'a bougé.

	// TODO 3 : le cas limite : Bruno peut virer exactement tout son solde (200,00 EUR).

	// TODO 4 : les montants invalides sont refusés (IllegalArgumentException) :
	//          nul, zéro, négatif, trois décimales, au-delà du plafond.

	// TODO 5 : un virement d'un compte vers lui-même est refusé.
}
