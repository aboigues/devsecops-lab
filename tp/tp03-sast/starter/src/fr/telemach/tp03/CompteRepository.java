package fr.telemach.tp03;

import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;

/** Accès JDBC à la table des comptes, écrit « rapidement » pour une démonstration. */
public class CompteRepository {

	public record Compte(String id, String titulaire, BigDecimal solde) {
	}

	private final Connection connexion;

	public CompteRepository(Connection connexion) {
		this.connexion = connexion;
	}

	/** Recherche des comptes d'un titulaire (paramètre reçu tel quel depuis l'URL). */
	public List<Compte> rechercherParTitulaire(String titulaire) throws SQLException {
		// TODO 1 : cette concaténation permet une injection SQL. Utiliser une requête préparée.
		try (Statement st = connexion.createStatement();
				ResultSet rs = st.executeQuery(
						"SELECT id, titulaire, solde FROM compte WHERE titulaire = '" + titulaire + "'")) {
			return lire(rs);
		}
	}

	/** Liste tous les comptes, triés selon la colonne choisie par l'utilisateur (paramètre d'URL). */
	public List<Compte> listerTriesPar(String colonne) throws SQLException {
		// TODO 2 : un nom de colonne ne peut PAS être un paramètre de requête préparée.
		//          N'accepter que les colonnes autorisées (id, titulaire, solde) ; refuser le reste
		//          par une IllegalArgumentException.
		try (Statement st = connexion.createStatement();
				ResultSet rs = st.executeQuery("SELECT id, titulaire, solde FROM compte ORDER BY " + colonne)) {
			return lire(rs);
		}
	}

	private static List<Compte> lire(ResultSet rs) throws SQLException {
		List<Compte> comptes = new ArrayList<>();
		while (rs.next()) {
			comptes.add(new Compte(rs.getString("id"), rs.getString("titulaire"), rs.getBigDecimal("solde")));
		}
		return comptes;
	}
}
