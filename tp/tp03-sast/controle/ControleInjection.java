import java.lang.reflect.Proxy;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;

import fr.telemach.tp03.CompteRepository;

/**
 * Contrôle fonctionnel du TP03, indépendant de tout outil SAST : une fausse connexion JDBC enregistre
 * le SQL réellement envoyé à la base et les valeurs liées. On appelle le dépôt avec des entrées
 * malveillantes et on regarde ce qui serait parti vers la base.
 *
 * Code de sortie : 0 si tout est correct, 1 sinon (un message par contrôle en échec).
 */
public class ControleInjection {

	static final List<String> SQL_ENVOYE = new ArrayList<>();
	static final List<Object> VALEURS_LIEES = new ArrayList<>();

	public static void main(String[] args) throws Exception {
		CompteRepository depot = new CompteRepository(fausseConnexion());
		List<String> echecs = new ArrayList<>();
		String attaque = "x' OR '1'='1";

		depot.rechercherParTitulaire(attaque);
		if (SQL_ENVOYE.stream().anyMatch(sql -> sql.contains(attaque))) {
			echecs.add("recherche : l'entrée de l'utilisateur est concaténée dans le SQL : " + SQL_ENVOYE);
		}
		if (!VALEURS_LIEES.contains(attaque)) {
			echecs.add("recherche : la valeur n'est pas transmise comme paramètre lié (setString)");
		}

		SQL_ENVOYE.clear();
		depot.listerTriesPar("solde");
		if (SQL_ENVOYE.stream().noneMatch(sql -> sql.replaceAll("\\s+", " ").contains("ORDER BY solde"))) {
			echecs.add("tri : une colonne autorisée (solde) doit toujours fonctionner : " + SQL_ENVOYE);
		}

		for (String colonne : List.of("solde; DROP TABLE compte", "(SELECT 1)", "solde DESC", "")) {
			SQL_ENVOYE.clear();
			try {
				depot.listerTriesPar(colonne);
				echecs.add("tri : la colonne « " + colonne + " » aurait dû être refusée ; SQL envoyé : " + SQL_ENVOYE);
			} catch (IllegalArgumentException attendu) {
				if (!SQL_ENVOYE.isEmpty()) {
					echecs.add("tri : du SQL est parti vers la base avant le refus : " + SQL_ENVOYE);
				}
			}
		}

		echecs.forEach(e -> System.out.println("ECHEC " + e));
		System.exit(echecs.isEmpty() ? 0 : 1);
	}

	/** Connexion JDBC simulée : enregistre tout, renvoie des résultats vides. */
	static Connection fausseConnexion() {
		return proxy(Connection.class, (nom, args) -> switch (nom) {
			case "prepareStatement" -> {
				SQL_ENVOYE.add((String) args[0]);
				yield proxy(PreparedStatement.class, (n, a) -> {
					if (n.startsWith("set") && a != null && a.length == 2) {
						VALEURS_LIEES.add(a[1]);
					}
					return n.equals("executeQuery") ? resultatVide() : null;
				});
			}
			case "createStatement" -> proxy(Statement.class, (n, a) -> {
				if (n.startsWith("execute") && a != null && a.length > 0) {
					SQL_ENVOYE.add((String) a[0]);
				}
				return n.equals("executeQuery") ? resultatVide() : null;
			});
			default -> null;
		});
	}

	static ResultSet resultatVide() {
		return proxy(ResultSet.class, (nom, args) -> nom.equals("next") ? Boolean.FALSE : null);
	}

	interface Comportement {
		Object repondre(String methode, Object[] args);
	}

	@SuppressWarnings("unchecked")
	static <T> T proxy(Class<T> type, Comportement comportement) {
		return (T) Proxy.newProxyInstance(type.getClassLoader(), new Class<?>[] { type }, (p, methode, args) -> {
			Object reponse = comportement.repondre(methode.getName(), args);
			if (reponse == null && methode.getReturnType() == boolean.class) {
				return false;
			}
			if (reponse == null && methode.getReturnType() == int.class) {
				return 0;
			}
			return reponse;
		});
	}
}
