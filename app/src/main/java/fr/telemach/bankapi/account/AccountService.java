package fr.telemach.bankapi.account;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.stereotype.Service;

/** Stockage en mémoire : l'objet du lab est la chaîne DevSecOps, pas la persistance. */
@Service
public class AccountService {

    private final Map<String, Account> accounts = new ConcurrentHashMap<>();

    public AccountService() {
        save(new Account("FR7630006000011234567890189", "Alice Martin", new BigDecimal("1500.00")));
        save(new Account("FR7610107001011234567890129", "Bruno Petit", new BigDecimal("200.00")));
    }

    public List<Account> findAll() {
        return accounts.values().stream().sorted((a, b) -> a.iban().compareTo(b.iban())).toList();
    }

    public Account find(String iban) {
        Account account = accounts.get(iban);
        if (account == null) {
            throw new AccountNotFoundException(iban);
        }
        return account;
    }

    /** Verrou global : garantit l'atomicité débit/crédit (suffisant pour un lab mono-instance). */
    public synchronized void transfer(TransferRequest request) {
        if (request.from().equals(request.to())) {
            throw new IllegalArgumentException("Comptes source et destination identiques");
        }
        Account from = find(request.from());
        Account to = find(request.to());
        save(from.debit(request.amount()));
        save(to.credit(request.amount()));
    }

    void save(Account account) {
        accounts.put(account.iban(), account);
    }
}
