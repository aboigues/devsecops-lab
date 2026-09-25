import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;

/** Micro-service « soldes » de Néobanque Exemple : JDK seul, aucune dépendance. */
public class Main {

	public static void main(String[] args) throws IOException {
		int port = Integer.parseInt(System.getenv().getOrDefault("PORT", "8080"));
		HttpServer serveur = HttpServer.create(new InetSocketAddress(port), 0);
		serveur.createContext("/health", ex -> repondre(ex, 200, "text/plain", "ok"));
		serveur.createContext("/api/comptes", ex -> repondre(ex, 200, "application/json",
				"[{\"id\":\"FR76-0001\",\"titulaire\":\"Alice\",\"solde\":1500.00}]"));
		serveur.createContext("/", ex -> repondre(ex, 404, "text/plain", "introuvable"));
		serveur.start();
		System.out.println("Service soldes démarré sur le port " + port);
	}

	private static void repondre(HttpExchange echange, int statut, String type, String corps) throws IOException {
		byte[] octets = corps.getBytes(StandardCharsets.UTF_8);
		echange.getResponseHeaders().set("Content-Type", type + "; charset=utf-8");
		echange.sendResponseHeaders(statut, octets.length);
		try (OutputStream sortie = echange.getResponseBody()) {
			sortie.write(octets);
		}
	}
}
