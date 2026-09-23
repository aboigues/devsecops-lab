package fr.telemach.bankapi.account;

import java.math.BigDecimal;

public record Account(String iban, String holder, BigDecimal balance) {

    Account credit(BigDecimal amount) {
        return new Account(iban, holder, balance.add(amount));
    }

    Account debit(BigDecimal amount) {
        if (balance.compareTo(amount) < 0) {
            throw new InsufficientFundsException(iban);
        }
        return new Account(iban, holder, balance.subtract(amount));
    }
}
