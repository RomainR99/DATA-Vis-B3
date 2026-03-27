#!/bin/bash
# ===========================================
# SCRIPT D'IMPORT DES CSV DANS POSTGRESQL
# ===========================================

# Configuration
CONTAINER_NAME="postgres-db"
DB_NAME="app_database"
DB_USER="admin"
CSV_DIR="./csv_data"  # Dossier contenant les fichiers CSV

# Couleurs pour les messages
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  IMPORT DES DONNÉES E-COMMERCE         ${NC}"
echo -e "${BLUE}=========================================${NC}"

# Vérifier que le conteneur PostgreSQL est en cours d'exécution
if ! docker ps | grep -q $CONTAINER_NAME; then
    echo -e "${RED}❌ Erreur: Le conteneur $CONTAINER_NAME n'est pas en cours d'exécution${NC}"
    echo "Lancez d'abord: docker compose up -d"
    exit 1
fi

# Vérifier que le dossier CSV existe
if [ ! -d "$CSV_DIR" ]; then
    echo -e "${RED}❌ Erreur: Le dossier $CSV_DIR n'existe pas${NC}"
    echo "Créez le dossier et placez-y les fichiers CSV:"
    echo "  - data_clients.csv"
    echo "  - data_produits.csv"
    echo "  - data_commandes.csv"
    echo "  - data_lignes_commandes.csv"
    echo "  - dim_calendrier.csv"
    exit 1
fi

# Créer un dossier temporaire dans le conteneur
echo -e "\n${BLUE}📁 Copie des fichiers CSV dans le conteneur...${NC}"
docker exec $CONTAINER_NAME mkdir -p /tmp/csv_import

# Copier les fichiers CSV dans le conteneur
for file in data_clients.csv data_produits.csv data_commandes.csv data_lignes_commandes.csv dim_calendrier.csv; do
    if [ -f "$CSV_DIR/$file" ]; then
        docker cp "$CSV_DIR/$file" "$CONTAINER_NAME:/tmp/csv_import/$file"
        echo -e "  ✅ $file copié"
    else
        echo -e "  ${RED}⚠️  $file non trouvé${NC}"
    fi
done

# Exécuter le script SQL de création des tables
echo -e "\n${BLUE}🔨 Création des tables...${NC}"
docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME << 'EOSQL'

-- Suppression des tables si elles existent
DROP TABLE IF EXISTS lignes_commandes CASCADE;
DROP TABLE IF EXISTS commandes CASCADE;
DROP TABLE IF EXISTS clients CASCADE;
DROP TABLE IF EXISTS produits CASCADE;
DROP TABLE IF EXISTS calendrier CASCADE;

-- TABLE CLIENTS
CREATE TABLE clients (
    client_id VARCHAR(10) PRIMARY KEY,
    prenom VARCHAR(50),
    nom VARCHAR(50),
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

-- TABLE PRODUITS
CREATE TABLE produits (
    produit_id VARCHAR(10) PRIMARY KEY,
    nom_produit VARCHAR(100),
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

-- TABLE COMMANDES
CREATE TABLE commandes (
    commande_id VARCHAR(12) PRIMARY KEY,
    client_id VARCHAR(10),
    date_commande DATE,
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

-- TABLE LIGNES_COMMANDES
CREATE TABLE lignes_commandes (
    ligne_id VARCHAR(12) PRIMARY KEY,
    commande_id VARCHAR(12),
    produit_id VARCHAR(10),
    quantite INTEGER,
    prix_unitaire DECIMAL(10,2),
    remise_pourcent DECIMAL(5,2),
    montant_ligne DECIMAL(10,2)
);

-- TABLE CALENDRIER
CREATE TABLE calendrier (
    date_id VARCHAR(8) PRIMARY KEY,
    date_complete DATE,
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

EOSQL

echo -e "  ✅ Tables créées"

# Import des données CSV
echo -e "\n${BLUE}📥 Import des données CSV...${NC}"

# Import Clients
echo -n "  Clients... "
docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "\COPY clients FROM '/tmp/csv_import/data_clients.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');" 2>/dev/null
echo "✅"

# Import Produits
echo -n "  Produits... "
docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "\COPY produits FROM '/tmp/csv_import/data_produits.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');" 2>/dev/null
echo "✅"

# Import Commandes
echo -n "  Commandes... "
docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "\COPY commandes FROM '/tmp/csv_import/data_commandes.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');" 2>/dev/null
echo "✅"

# Import Lignes de commandes
echo -n "  Lignes commandes... "
docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "\COPY lignes_commandes FROM '/tmp/csv_import/data_lignes_commandes.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');" 2>/dev/null
echo "✅"

# Import Calendrier
echo -n "  Calendrier... "
docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "\COPY calendrier FROM '/tmp/csv_import/dim_calendrier.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');" 2>/dev/null
echo "✅"

# Ajouter les clés étrangères après l'import
echo -e "\n${BLUE}🔗 Ajout des contraintes et index...${NC}"
docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME << 'EOSQL'

-- Clés étrangères
ALTER TABLE commandes ADD CONSTRAINT fk_commandes_client 
    FOREIGN KEY (client_id) REFERENCES clients(client_id);
    
ALTER TABLE lignes_commandes ADD CONSTRAINT fk_lignes_commande 
    FOREIGN KEY (commande_id) REFERENCES commandes(commande_id);
    
ALTER TABLE lignes_commandes ADD CONSTRAINT fk_lignes_produit 
    FOREIGN KEY (produit_id) REFERENCES produits(produit_id);

-- Index pour les performances
CREATE INDEX idx_commandes_client ON commandes(client_id);
CREATE INDEX idx_commandes_date ON commandes(date_commande);
CREATE INDEX idx_lignes_commande ON lignes_commandes(commande_id);
CREATE INDEX idx_lignes_produit ON lignes_commandes(produit_id);
CREATE INDEX idx_produits_categorie ON produits(categorie);
CREATE INDEX idx_clients_ville ON clients(ville);

EOSQL
echo -e "  ✅ Contraintes et index ajoutés"

# Nettoyage
echo -e "\n${BLUE}🧹 Nettoyage...${NC}"
docker exec $CONTAINER_NAME rm -rf /tmp/csv_import
echo -e "  ✅ Fichiers temporaires supprimés"

# Afficher les statistiques
echo -e "\n${BLUE}📊 Statistiques d'import:${NC}"
docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME << 'EOSQL'
SELECT 'clients' as table_name, COUNT(*) as nb_lignes FROM clients
UNION ALL
SELECT 'produits', COUNT(*) FROM produits
UNION ALL
SELECT 'commandes', COUNT(*) FROM commandes
UNION ALL
SELECT 'lignes_commandes', COUNT(*) FROM lignes_commandes
UNION ALL
SELECT 'calendrier', COUNT(*) FROM calendrier
ORDER BY table_name;
EOSQL

echo -e "\n${GREEN}=========================================${NC}"
echo -e "${GREEN}  ✅ IMPORT TERMINÉ AVEC SUCCÈS!         ${NC}"
echo -e "${GREEN}=========================================${NC}"
echo -e "\nPour vous connecter à la base:"
echo -e "  docker exec -it $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME"
