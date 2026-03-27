# ===========================================
# SCRIPT D'IMPORT DES CSV DANS POSTGRESQL
# Pour Windows PowerShell
# ===========================================

# Configuration
$CONTAINER_NAME = "postgres-db"
$DB_NAME = "app_database"
$DB_USER = "admin"
$CSV_DIR = ".\csv_data"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  IMPORT DES DONNEES E-COMMERCE         " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Verifier que Docker est en cours d'execution
$dockerRunning = docker ps 2>$null
if (-not $?) {
    Write-Host "❌ Erreur: Docker n'est pas en cours d'execution" -ForegroundColor Red
    Write-Host "Lancez Docker Desktop et reessayez."
    exit 1
}

# Verifier que le conteneur PostgreSQL est lance
$containerRunning = docker ps --filter "name=$CONTAINER_NAME" --format "{{.Names}}"
if ($containerRunning -ne $CONTAINER_NAME) {
    Write-Host "❌ Erreur: Le conteneur $CONTAINER_NAME n'est pas lance" -ForegroundColor Red
    Write-Host "Lancez d'abord: docker compose up -d"
    exit 1
}

# Verifier que le dossier CSV existe
if (-not (Test-Path $CSV_DIR)) {
    Write-Host "❌ Erreur: Le dossier $CSV_DIR n'existe pas" -ForegroundColor Red
    Write-Host "Creez le dossier et placez-y les fichiers CSV:"
    Write-Host "  - data_clients.csv"
    Write-Host "  - data_produits.csv"
    Write-Host "  - data_commandes.csv"
    Write-Host "  - data_lignes_commandes.csv"
    Write-Host "  - dim_calendrier.csv"
    exit 1
}

# Creer un dossier temporaire dans le conteneur
Write-Host "`n📁 Copie des fichiers CSV dans le conteneur..." -ForegroundColor Cyan
docker exec $CONTAINER_NAME mkdir -p /tmp/csv_import

# Copier les fichiers CSV
$files = @("data_clients.csv", "data_produits.csv", "data_commandes.csv", "data_lignes_commandes.csv", "dim_calendrier.csv")
foreach ($file in $files) {
    $filepath = Join-Path $CSV_DIR $file
    if (Test-Path $filepath) {
        docker cp $filepath "${CONTAINER_NAME}:/tmp/csv_import/$file"
        Write-Host "  ✅ $file copie" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  $file non trouve" -ForegroundColor Yellow
    }
}

# Creation des tables
Write-Host "`n🔨 Creation des tables..." -ForegroundColor Cyan

$createTablesSQL = @"
DROP TABLE IF EXISTS lignes_commandes CASCADE;
DROP TABLE IF EXISTS commandes CASCADE;
DROP TABLE IF EXISTS clients CASCADE;
DROP TABLE IF EXISTS produits CASCADE;
DROP TABLE IF EXISTS calendrier CASCADE;

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

CREATE TABLE lignes_commandes (
    ligne_id VARCHAR(12) PRIMARY KEY,
    commande_id VARCHAR(12),
    produit_id VARCHAR(10),
    quantite INTEGER,
    prix_unitaire DECIMAL(10,2),
    remise_pourcent DECIMAL(5,2),
    montant_ligne DECIMAL(10,2)
);

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
"@

$createTablesSQL | docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME 2>$null
Write-Host "  ✅ Tables creees" -ForegroundColor Green

# Import des donnees
Write-Host "`n📥 Import des donnees CSV..." -ForegroundColor Cyan

Write-Host -NoNewline "  Clients... "
docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "\COPY clients FROM '/tmp/csv_import/data_clients.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');" 2>$null
Write-Host "✅" -ForegroundColor Green

Write-Host -NoNewline "  Produits... "
docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "\COPY produits FROM '/tmp/csv_import/data_produits.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');" 2>$null
Write-Host "✅" -ForegroundColor Green

Write-Host -NoNewline "  Commandes... "
docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "\COPY commandes FROM '/tmp/csv_import/data_commandes.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');" 2>$null
Write-Host "✅" -ForegroundColor Green

Write-Host -NoNewline "  Lignes commandes... "
docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "\COPY lignes_commandes FROM '/tmp/csv_import/data_lignes_commandes.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');" 2>$null
Write-Host "✅" -ForegroundColor Green

Write-Host -NoNewline "  Calendrier... "
docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "\COPY calendrier FROM '/tmp/csv_import/dim_calendrier.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');" 2>$null
Write-Host "✅" -ForegroundColor Green

# Ajout des contraintes
Write-Host "`n🔗 Ajout des contraintes..." -ForegroundColor Cyan

$constraintsSQL = @"
ALTER TABLE commandes ADD CONSTRAINT fk_commandes_client FOREIGN KEY (client_id) REFERENCES clients(client_id);
ALTER TABLE lignes_commandes ADD CONSTRAINT fk_lignes_commande FOREIGN KEY (commande_id) REFERENCES commandes(commande_id);
ALTER TABLE lignes_commandes ADD CONSTRAINT fk_lignes_produit FOREIGN KEY (produit_id) REFERENCES produits(produit_id);
CREATE INDEX idx_commandes_client ON commandes(client_id);
CREATE INDEX idx_commandes_date ON commandes(date_commande);
CREATE INDEX idx_lignes_commande ON lignes_commandes(commande_id);
CREATE INDEX idx_lignes_produit ON lignes_commandes(produit_id);
"@

$constraintsSQL | docker exec -i $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME 2>$null
Write-Host "  ✅ Contraintes ajoutees" -ForegroundColor Green

# Nettoyage
Write-Host "`n🧹 Nettoyage..." -ForegroundColor Cyan
docker exec $CONTAINER_NAME rm -rf /tmp/csv_import
Write-Host "  ✅ Fichiers temporaires supprimes" -ForegroundColor Green

# Statistiques
Write-Host "`n📊 Statistiques d'import:" -ForegroundColor Cyan
docker exec $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -c "SELECT 'clients' as table_name, COUNT(*) as nb_lignes FROM clients UNION ALL SELECT 'produits', COUNT(*) FROM produits UNION ALL SELECT 'commandes', COUNT(*) FROM commandes UNION ALL SELECT 'lignes_commandes', COUNT(*) FROM lignes_commandes UNION ALL SELECT 'calendrier', COUNT(*) FROM calendrier ORDER BY table_name;"

Write-Host "`n=========================================" -ForegroundColor Green
Write-Host "  ✅ IMPORT TERMINE AVEC SUCCES!         " -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host "`nPour vous connecter a la base:"
Write-Host "  docker exec -it $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME" -ForegroundColor Yellow
