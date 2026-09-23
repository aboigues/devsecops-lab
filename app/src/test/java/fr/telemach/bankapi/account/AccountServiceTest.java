package fr.telemach.bankapi.account;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.math.BigDecimal;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** Tests unitaires : base de la pyramide, sans contexte Spring, exécution en millisecondes. */
class AccountServiceTest {

    static final String ALICE = "FR7630006000011234567890189";
    static final String BRUNO = "FR7610107001011234567890129";

    AccountService service;

    @BeforeEach
    void setUp() {
        service = new AccountService();
    }

    @Test
    void transferMovesMoneyBetweenAccounts() {
        service.transfer(new TransferRequest(ALICE, BRUNO, new BigDecimal("100.00")));

        assertThat(service.find(ALICE).balance()).isEqualByComparingTo("1400.00");
        assertThat(service.find(BRUNO).balance()).isEqualByComparingTo("300.00");
    }

    @Test
    void transferRejectsInsufficientFunds() {
        assertThatThrownBy(() -> service.transfer(new TransferRequest(BRUNO, ALICE, new BigDecimal("200.01"))))
                .isInstanceOf(InsufficientFundsException.class);
        assertThat(service.find(BRUNO).balance()).isEqualByComparingTo("200.00");
    }

    @Test
    void transferRejectsSameAccount() {
        assertThatThrownBy(() -> service.transfer(new TransferRequest(ALICE, ALICE, BigDecimal.ONE)))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void findUnknownAccountFails() {
        assertThatThrownBy(() -> service.find("FR0000000000000000000000000"))
                .isInstanceOf(AccountNotFoundException.class);
    }

    @Test
    void findAllIsSortedByIban() {
        assertThat(service.findAll()).extracting(Account::iban).containsExactly(BRUNO, ALICE);
    }
}
