package fr.telemach.tp01;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.math.BigDecimal;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullSource;
import org.junit.jupiter.params.provider.ValueSource;

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

	@Test
	void soldeInsuffisantRefuseSansModifierLesSoldes() {
		assertThrows(SoldeInsuffisantException.class,
				() -> service.virer(bruno, alice, new BigDecimal("200.01")));

		assertEquals(new BigDecimal("200.00"), bruno.solde());
		assertEquals(new BigDecimal("1500.00"), alice.solde());
	}

	@Test
	void virerToutLeSoldeEstAutorise() {
		service.virer(bruno, alice, new BigDecimal("200.00"));

		assertEquals(0, bruno.solde().signum());
	}

	@ParameterizedTest
	@NullSource
	@ValueSource(strings = { "0", "-10.00", "10.001", "10000.01" })
	void montantInvalideRefuse(BigDecimal montant) {
		assertThrows(IllegalArgumentException.class, () -> service.virer(alice, bruno, montant));

		assertEquals(new BigDecimal("1500.00"), alice.solde());
	}

	@Test
	void plafondExactAutorise() {
		Compte riche = new Compte("FR76-0003", "Chloé", new BigDecimal("50000.00"));

		service.virer(riche, alice, ServiceVirement.PLAFOND);

		assertEquals(new BigDecimal("11500.00"), alice.solde());
	}

	@Test
	void virementVersLeMemeCompteRefuse() {
		assertThrows(IllegalArgumentException.class,
				() -> service.virer(alice, alice, new BigDecimal("10.00")));
	}
}
