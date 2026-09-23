package fr.telemach.bankapi.account;

public class InsufficientFundsException extends RuntimeException {

    public InsufficientFundsException(String iban) {
        super("Solde insuffisant sur le compte " + iban);
    }
}
