package fr.telemach.bankapi.account;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import java.math.BigDecimal;

/** Validation stricte en entrée : première ligne de défense contre les injections et montants aberrants. */
public record TransferRequest(
        @NotNull @Pattern(regexp = "^FR\\d{2}[0-9A-Z]{23}$") String from,
        @NotNull @Pattern(regexp = "^FR\\d{2}[0-9A-Z]{23}$") String to,
        @NotNull @DecimalMin("0.01") @DecimalMax("100000.00") @Digits(integer = 6, fraction = 2) BigDecimal amount) {
}
