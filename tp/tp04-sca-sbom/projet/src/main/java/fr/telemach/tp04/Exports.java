package fr.telemach.tp04;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

/** Service d'exports : journalise chaque export demandé. */
public final class Exports {

	private static final Logger LOG = LogManager.getLogger(Exports.class);

	private Exports() {
	}

	public static void main(String[] args) {
		LOG.info("Export demandé pour {} compte(s)", args.length);
	}
}
