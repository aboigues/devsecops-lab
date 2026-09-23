package fr.telemach.bankapi.account;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.math.BigDecimal;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

/** Tests de la couche web : contrat HTTP et validation des entrées, service simulé. */
@WebMvcTest(AccountController.class)
class AccountControllerTest {

    static final String ALICE = "FR7630006000011234567890189";

    @Autowired
    MockMvc mvc;

    @MockitoBean
    AccountService service;

    @Test
    void getReturnsAccount() throws Exception {
        when(service.find(ALICE)).thenReturn(new Account(ALICE, "Alice Martin", new BigDecimal("10.00")));

        mvc.perform(get("/api/accounts/" + ALICE))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.holder").value("Alice Martin"));
    }

    @Test
    void unknownAccountReturns404() throws Exception {
        when(service.find(any())).thenThrow(new AccountNotFoundException("X"));

        mvc.perform(get("/api/accounts/X")).andExpect(status().isNotFound());
    }

    @Test
    void insufficientFundsReturns422() throws Exception {
        doThrow(new InsufficientFundsException(ALICE)).when(service).transfer(any());

        mvc.perform(post("/api/accounts/transfers").contentType(MediaType.APPLICATION_JSON)
                        .content(transfer(ALICE, "FR7610107001011234567890129", "1.00")))
                .andExpect(status().isUnprocessableContent());
    }

    @Test
    void invalidIbanIsRejectedBeforeReachingService() throws Exception {
        mvc.perform(post("/api/accounts/transfers").contentType(MediaType.APPLICATION_JSON)
                        .content(transfer("' OR 1=1 --", ALICE, "1.00")))
                .andExpect(status().isBadRequest());
        verify(service, never()).transfer(any());
    }

    @Test
    void negativeAmountIsRejected() throws Exception {
        mvc.perform(post("/api/accounts/transfers").contentType(MediaType.APPLICATION_JSON)
                        .content(transfer(ALICE, "FR7610107001011234567890129", "-5.00")))
                .andExpect(status().isBadRequest());
    }

    static String transfer(String from, String to, String amount) {
        return """
                {"from":"%s","to":"%s","amount":%s}""".formatted(from, to, amount);
    }
}
