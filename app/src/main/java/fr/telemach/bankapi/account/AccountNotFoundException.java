package fr.telemach.bankapi.account;

public class AccountNotFoundException extends RuntimeException {

    public AccountNotFoundException(String iban) {
        super("Compte introuvable : " + iban);
    }
}
