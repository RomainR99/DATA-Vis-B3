@echo off
chcp 65001 >nul
REM ===========================================
REM SCRIPT D'IMPORT DES CSV DANS POSTGRESQL
REM Pour Windows CMD
REM ===========================================

set CONTAINER_NAME=postgres-db
set DB_NAME=app_database
set DB_USER=admin
set CSV_DIR=csv_data

echo =========================================
echo   IMPORT DES DONNEES E-COMMERCE
echo =========================================

REM Verifier que Docker est lance
docker ps >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERREUR] Docker n'est pas en cours d'execution
    echo Lancez Docker Desktop et reessayez.
    pause
    exit /b 1
)

REM Verifier que le conteneur est lance
docker ps --filter "name=%CONTAINER_NAME%" --format "{{.Names}}" | findstr %CONTAINER_NAME% >nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERREUR] Le conteneur %CONTAINER_NAME% n'est pas lance
    echo Lancez d'abord: docker compose up -d
    pause
    exit /b 1
)

REM Verifier que le dossier CSV existe
if not exist "%CSV_DIR%" (
    echo [ERREUR] Le dossier %CSV_DIR% n'existe pas
    echo Creez le dossier et placez-y les fichiers CSV
    pause
    exit /b 1
)

echo.
echo [1/5] Copie des fichiers CSV dans le conteneur...
docker exec %CONTAINER_NAME% mkdir -p /tmp/csv_import

if exist "%CSV_DIR%\data_clients.csv" (
    docker cp "%CSV_DIR%\data_clients.csv" %CONTAINER_NAME%:/tmp/csv_import/
    echo   - data_clients.csv OK
)
if exist "%CSV_DIR%\data_produits.csv" (
    docker cp "%CSV_DIR%\data_produits.csv" %CONTAINER_NAME%:/tmp/csv_import/
    echo   - data_produits.csv OK
)
if exist "%CSV_DIR%\data_commandes.csv" (
    docker cp "%CSV_DIR%\data_commandes.csv" %CONTAINER_NAME%:/tmp/csv_import/
    echo   - data_commandes.csv OK
)
if exist "%CSV_DIR%\data_lignes_commandes.csv" (
    docker cp "%CSV_DIR%\data_lignes_commandes.csv" %CONTAINER_NAME%:/tmp/csv_import/
    echo   - data_lignes_commandes.csv OK
)
if exist "%CSV_DIR%\dim_calendrier.csv" (
    docker cp "%CSV_DIR%\dim_calendrier.csv" %CONTAINER_NAME%:/tmp/csv_import/
    echo   - dim_calendrier.csv OK
)

echo.
echo [2/5] Creation des tables...
docker exec %CONTAINER_NAME% psql -U %DB_USER% -d %DB_NAME% -c "DROP TABLE IF EXISTS lignes_commandes CASCADE; DROP TABLE IF EXISTS commandes CASCADE; DROP TABLE IF EXISTS clients CASCADE; DROP TABLE IF EXISTS produits CASCADE; DROP TABLE IF EXISTS calendrier CASCADE;"

docker exec %CONTAINER_NAME% psql -U %DB_USER% -d %DB_NAME% -c "CREATE TABLE clients (client_id VARCHAR(10) PRIMARY KEY, prenom VARCHAR(50), nom VARCHAR(50), email VARCHAR(100), telephone VARCHAR(20), adresse VARCHAR(200), code_postal VARCHAR(10), ville VARCHAR(100), region VARCHAR(100), date_inscription DATE, segment VARCHAR(50), canal_acquisition VARCHAR(50));"

docker exec %CONTAINER_NAME% psql -U %DB_USER% -d %DB_NAME% -c "CREATE TABLE produits (produit_id VARCHAR(10) PRIMARY KEY, nom_produit VARCHAR(100), categorie VARCHAR(50), sous_categorie VARCHAR(50), prix_unitaire DECIMAL(10,2), cout_achat DECIMAL(10,2), stock_actuel INTEGER, stock_min INTEGER, fournisseur VARCHAR(50), note_moyenne DECIMAL(3,1), nb_avis INTEGER);"

docker exec %CONTAINER_NAME% psql -U %DB_USER% -d %DB_NAME% -c "CREATE TABLE commandes (commande_id VARCHAR(12) PRIMARY KEY, client_id VARCHAR(10), date_commande DATE, heure_commande TIME, statut VARCHAR(20), mode_paiement VARCHAR(50), transporteur VARCHAR(50), montant_ht DECIMAL(10,2), tva DECIMAL(10,2), frais_port DECIMAL(10,2), montant_ttc DECIMAL(10,2), code_promo VARCHAR(50));"

docker exec %CONTAINER_NAME% psql -U %DB_USER% -d %DB_NAME% -c "CREATE TABLE lignes_commandes (ligne_id VARCHAR(12) PRIMARY KEY, commande_id VARCHAR(12), produit_id VARCHAR(10), quantite INTEGER, prix_unitaire DECIMAL(10,2), remise_pourcent DECIMAL(5,2), montant_ligne DECIMAL(10,2));"

docker exec %CONTAINER_NAME% psql -U %DB_USER% -d %DB_NAME% -c "CREATE TABLE calendrier (date_id VARCHAR(8) PRIMARY KEY, date_complete DATE, annee INTEGER, trimestre VARCHAR(2), mois_numero INTEGER, mois_nom VARCHAR(20), semaine INTEGER, jour_mois INTEGER, jour_semaine VARCHAR(20), est_weekend VARCHAR(3), est_ferie VARCHAR(3));"

echo   Tables creees OK

echo.
echo [3/5] Import des donnees CSV...
echo   - Import clients...
docker exec %CONTAINER_NAME% psql -U %DB_USER% -d %DB_NAME% -c "\COPY clients FROM '/tmp/csv_import/data_clients.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');"

echo   - Import produits...
docker exec %CONTAINER_NAME% psql -U %DB_USER% -d %DB_NAME% -c "\COPY produits FROM '/tmp/csv_import/data_produits.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');"

echo   - Import commandes...
docker exec %CONTAINER_NAME% psql -U %DB_USER% -d %DB_NAME% -c "\COPY commandes FROM '/tmp/csv_import/data_commandes.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');"

echo   - Import lignes_commandes...
docker exec %CONTAINER_NAME% psql -U %DB_USER% -d %DB_NAME% -c "\COPY lignes_commandes FROM '/tmp/csv_import/data_lignes_commandes.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');"

echo   - Import calendrier...
docker exec %CONTAINER_NAME% psql -U %DB_USER% -d %DB_NAME% -c "\COPY calendrier FROM '/tmp/csv_import/dim_calendrier.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');"

echo.
echo [4/5] Ajout des contraintes et index...
docker exec %CONTAINER_NAME% psql -U %DB_USER% -d %DB_NAME% -c "ALTER TABLE commandes ADD CONSTRAINT fk_commandes_client FOREIGN KEY (client_id) REFERENCES clients(client_id); ALTER TABLE lignes_commandes ADD CONSTRAINT fk_lignes_commande FOREIGN KEY (commande_id) REFERENCES commandes(commande_id); ALTER TABLE lignes_commandes ADD CONSTRAINT fk_lignes_produit FOREIGN KEY (produit_id) REFERENCES produits(produit_id);"

docker exec %CONTAINER_NAME% psql -U %DB_USER% -d %DB_NAME% -c "CREATE INDEX idx_commandes_client ON commandes(client_id); CREATE INDEX idx_commandes_date ON commandes(date_commande); CREATE INDEX idx_lignes_commande ON lignes_commandes(commande_id); CREATE INDEX idx_lignes_produit ON lignes_commandes(produit_id);"

echo   Contraintes OK

echo.
echo [5/5] Nettoyage...
docker exec %CONTAINER_NAME% rm -rf /tmp/csv_import
echo   Fichiers temporaires supprimes

echo.
echo =========================================
echo   STATISTIQUES D'IMPORT
echo =========================================
docker exec %CONTAINER_NAME% psql -U %DB_USER% -d %DB_NAME% -c "SELECT 'clients' as table_name, COUNT(*) as nb_lignes FROM clients UNION ALL SELECT 'produits', COUNT(*) FROM produits UNION ALL SELECT 'commandes', COUNT(*) FROM commandes UNION ALL SELECT 'lignes_commandes', COUNT(*) FROM lignes_commandes UNION ALL SELECT 'calendrier', COUNT(*) FROM calendrier ORDER BY table_name;"

echo.
echo =========================================
echo   IMPORT TERMINE AVEC SUCCES !
echo =========================================
echo.
echo Pour vous connecter a la base:
echo   docker exec -it %CONTAINER_NAME% psql -U %DB_USER% -d %DB_NAME%
echo.
pause
