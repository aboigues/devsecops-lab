package fr.telemach.tp03;

import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

/** Accès JDBC à la table des comptes. */
public class CompteRepository {

	public record Compte(String id, String titulaire, BigDecimal solde) {
	}

	private final Connection connexion;

	public CompteRepository(Connection connexion) {
		this.connexion = connexion;
	}

	/** Recherche des comptes d'un titulaire (paramètre reçu tel quel depuis l'URL). */
	public List<Compte> rechercherParTitulaire(String titulaire) throws SQLException {
		// Requête préparée : la valeur est transmise à part, jamais interprétée comme du SQL.
		try (PreparedStatement ps = connexion.prepareStatement(
				"SELECT id, titulaire, solde FROM compte WHERE titulaire = ?")) {
			ps.setString(1, titulaire);
			try (ResultSet rs = ps.executeQuery()) {
				return lire(rs);
			}
		}
	}

	/** Liste tous les comptes, triés selon la colonne choisie par l'utilisateur (paramètre d'URL). */
	public List<Compte> listerTriesPar(String colonne) throws SQLException {
		// Un identifiant SQL ne se lie pas comme une valeur : liste blanche, chaque requête est une constante.
		String sql = switch (colonne) {
			case "id" -> "SELECT id, titulaire, solde FROM compte ORDER BY id";
			case "titulaire" -> "SELECT id, titulaire, solde FROM compte ORDER BY titulaire";
			case "solde" -> "SELECT id, titulaire, solde FROM compte ORDER BY solde";
			default -> throw new IllegalArgumentException("Colonne de tri non autorisée");
		};
		try (PreparedStatement ps = connexion.prepareStatement(sql);
				ResultSet rs = ps.executeQuery()) {
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
