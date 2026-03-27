-- ===========================================
-- SCRIPT DE CRÉATION DES TABLES E-COMMERCE
-- Pour PostgreSQL
-- ===========================================

-- Suppression des tables si elles existent (dans l'ordre des dépendances)
DROP TABLE IF EXISTS lignes_commandes CASCADE;
DROP TABLE IF EXISTS commandes CASCADE;
DROP TABLE IF EXISTS clients CASCADE;
DROP TABLE IF EXISTS produits CASCADE;
DROP TABLE IF EXISTS calendrier CASCADE;

-- ===========================================
-- TABLE CLIENTS (Dimension)
-- ===========================================
CREATE TABLE clients (
    client_id VARCHAR(10) PRIMARY KEY,
    prenom VARCHAR(50) NOT NULL,
    nom VARCHAR(50) NOT NULL,
    email VARCHAR(100),
    telephone VARCHAR(20),
    adresse VARCHAR(200),
    code_postal VARCHAR(10),
    ville VARCHAR(100),
    region VARCHAR(100),
    date_inscription DATE,
    segment VARCHAR(50),
    canal_acquisition VARCHAR(50)
);

-- ===========================================
-- TABLE PRODUITS (Dimension)
-- ===========================================
CREATE TABLE produits (
    produit_id VARCHAR(10) PRIMARY KEY,
    nom_produit VARCHAR(100) NOT NULL,
    categorie VARCHAR(50),
    sous_categorie VARCHAR(50),
    prix_unitaire DECIMAL(10,2),
    cout_achat DECIMAL(10,2),
    stock_actuel INTEGER,
    stock_min INTEGER,
    fournisseur VARCHAR(50),
    note_moyenne DECIMAL(3,1),
    nb_avis INTEGER
);

-- ===========================================
-- TABLE COMMANDES (Fait - En-tête)
-- ===========================================
CREATE TABLE commandes (
    commande_id VARCHAR(12) PRIMARY KEY,
    client_id VARCHAR(10) REFERENCES clients(client_id),
    date_commande DATE NOT NULL,
    heure_commande TIME,
    statut VARCHAR(20),
    mode_paiement VARCHAR(50),
    transporteur VARCHAR(50),
    montant_ht DECIMAL(10,2),
    tva DECIMAL(10,2),
    frais_port DECIMAL(10,2),
    montant_ttc DECIMAL(10,2),
    code_promo VARCHAR(50)
);

-- ===========================================
-- TABLE LIGNES_COMMANDES (Fait - Détail)
-- ===========================================
CREATE TABLE lignes_commandes (
    ligne_id VARCHAR(12) PRIMARY KEY,
    commande_id VARCHAR(12) REFERENCES commandes(commande_id),
    produit_id VARCHAR(10) REFERENCES produits(produit_id),
    quantite INTEGER NOT NULL,
    prix_unitaire DECIMAL(10,2),
    remise_pourcent DECIMAL(5,2),
    montant_ligne DECIMAL(10,2)
);

-- ===========================================
-- TABLE CALENDRIER (Dimension Temps)
-- ===========================================
CREATE TABLE calendrier (
    date_id VARCHAR(8) PRIMARY KEY,
    date_complete DATE UNIQUE NOT NULL,
    annee INTEGER,
    trimestre VARCHAR(2),
    mois_numero INTEGER,
    mois_nom VARCHAR(20),
    semaine INTEGER,
    jour_mois INTEGER,
    jour_semaine VARCHAR(20),
    est_weekend VARCHAR(3),
    est_ferie VARCHAR(3)
);

-- ===========================================
-- INDEX POUR LES PERFORMANCES
-- ===========================================
CREATE INDEX idx_commandes_client ON commandes(client_id);
CREATE INDEX idx_commandes_date ON commandes(date_commande);
CREATE INDEX idx_commandes_statut ON commandes(statut);
CREATE INDEX idx_lignes_commande ON lignes_commandes(commande_id);
CREATE INDEX idx_lignes_produit ON lignes_commandes(produit_id);
CREATE INDEX idx_produits_categorie ON produits(categorie);
CREATE INDEX idx_clients_ville ON clients(ville);
CREATE INDEX idx_clients_segment ON clients(segment);
CREATE INDEX idx_calendrier_date ON calendrier(date_complete);

-- ===========================================
-- MESSAGE DE CONFIRMATION
-- ===========================================
DO $$
BEGIN
    RAISE NOTICE '✅ Tables créées avec succès!';
    RAISE NOTICE 'Tables: clients, produits, commandes, lignes_commandes, calendrier';
END $$;
