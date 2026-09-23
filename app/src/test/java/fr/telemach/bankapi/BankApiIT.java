package fr.telemach.bankapi;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.SpringBootTest.WebEnvironment;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.http.MediaType;
import org.springframework.web.client.RestClient;

/** Test d'intégration : application complète sur un port réel, exécuté par failsafe en phase verify. */
@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
class BankApiIT {

    @LocalServerPort
    int port;

    @Test
    void transferEndToEnd() {
        RestClient client = RestClient.create("http://localhost:" + port);

        client.post().uri("/api/accounts/transfers").contentType(MediaType.APPLICATION_JSON)
                .body("""
                        {"from":"FR7630006000011234567890189","to":"FR7610107001011234567890129","amount":50.00}""")
                .retrieve().toBodilessEntity();

        String bruno = client.get().uri("/api/accounts/FR7610107001011234567890129").retrieve().body(String.class);
        assertThat(bruno).contains("\"balance\":250.0");
    }

    @Test
    void healthProbesAreExposedButNotOtherActuatorEndpoints() {
        RestClient client = RestClient.create("http://localhost:" + port);

        assertThat(client.get().uri("/actuator/health/readiness").retrieve().toBodilessEntity().getStatusCode().value())
                .isEqualTo(200);
        int envStatus = client.get().uri("/actuator/env").exchange((req, res) -> res.getStatusCode().value());
        assertThat(envStatus).isEqualTo(404);
    }

    @Test
    void responsesCarrySecurityHeaders() {
        var headers = RestClient.create("http://localhost:" + port)
                .get().uri("/api/accounts").retrieve().toBodilessEntity().getHeaders();

        assertThat(headers.getFirst("X-Content-Type-Options")).isEqualTo("nosniff");
        assertThat(headers.getFirst("Content-Security-Policy")).contains("frame-ancestors 'none'");
        assertThat(headers.getFirst("Cache-Control")).isEqualTo("no-store");
    }
}
