# 🪟 Guide Windows - Import des données e-commerce

## Prérequis

- ✅ Docker Desktop installé et **démarré** (icône dans la barre des tâches)
- ✅ La stack Docker lancée (`docker compose up -d`)
- ✅ Les fichiers CSV extraits du ZIP

---

## 📁 Structure des dossiers

Avant de commencer, organisez vos fichiers comme ceci :

```
docker-stack/
├── docker-compose.yml
├── import-csv.bat          ← Script Windows CMD
├── import-csv.ps1          ← Script Windows PowerShell
├── csv_data/               ← CRÉER CE DOSSIER
│   ├── data_clients.csv
│   ├── data_produits.csv
│   ├── data_commandes.csv
│   ├── data_lignes_commandes.csv
│   └── dim_calendrier.csv
└── ...
```

---

## 🚀 Méthode 1 : Script automatique (recommandé)

### Option A : Avec CMD (invite de commandes)

1. Ouvrir l'**Explorateur de fichiers**
2. Aller dans le dossier `docker-stack`
3. **Double-cliquer** sur `import-csv.bat`
4. Attendre la fin de l'exécution

### Option B : Avec PowerShell

1. Ouvrir **PowerShell** (clic droit sur le menu Démarrer)
2. Naviguer vers le dossier :
   ```powershell
   cd C:\chemin\vers\docker-stack
   ```
3. Autoriser l'exécution des scripts (une seule fois) :
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
4. Lancer le script :
   ```powershell
   .\import-csv.ps1
   ```

---

## 🚀 Méthode 2 : Commandes manuelles

Ouvrir **CMD** ou **PowerShell** et exécuter ces commandes une par une :

### Étape 1 : Copier les CSV dans le conteneur

```cmd
docker exec postgres-db mkdir -p /tmp/csv

docker cp csv_data\data_clients.csv postgres-db:/tmp/csv/
docker cp csv_data\data_produits.csv postgres-db:/tmp/csv/
docker cp csv_data\data_commandes.csv postgres-db:/tmp/csv/
docker cp csv_data\data_lignes_commandes.csv postgres-db:/tmp/csv/
docker cp csv_data\dim_calendrier.csv postgres-db:/tmp/csv/
```

### Étape 2 : Créer les tables

```cmd
docker exec postgres-db psql -U admin -d app_database -c "DROP TABLE IF EXISTS lignes_commandes CASCADE; DROP TABLE IF EXISTS commandes CASCADE; DROP TABLE IF EXISTS clients CASCADE; DROP TABLE IF EXISTS produits CASCADE; DROP TABLE IF EXISTS calendrier CASCADE;"

docker exec postgres-db psql -U admin -d app_database -c "CREATE TABLE clients (client_id VARCHAR(10) PRIMARY KEY, prenom VARCHAR(50), nom VARCHAR(50), email VARCHAR(100), telephone VARCHAR(20), adresse VARCHAR(200), code_postal VARCHAR(10), ville VARCHAR(100), region VARCHAR(100), date_inscription DATE, segment VARCHAR(50), canal_acquisition VARCHAR(50));"

docker exec postgres-db psql -U admin -d app_database -c "CREATE TABLE produits (produit_id VARCHAR(10) PRIMARY KEY, nom_produit VARCHAR(100), categorie VARCHAR(50), sous_categorie VARCHAR(50), prix_unitaire DECIMAL(10,2), cout_achat DECIMAL(10,2), stock_actuel INTEGER, stock_min INTEGER, fournisseur VARCHAR(50), note_moyenne DECIMAL(3,1), nb_avis INTEGER);"

docker exec postgres-db psql -U admin -d app_database -c "CREATE TABLE commandes (commande_id VARCHAR(12) PRIMARY KEY, client_id VARCHAR(10), date_commande DATE, heure_commande TIME, statut VARCHAR(20), mode_paiement VARCHAR(50), transporteur VARCHAR(50), montant_ht DECIMAL(10,2), tva DECIMAL(10,2), frais_port DECIMAL(10,2), montant_ttc DECIMAL(10,2), code_promo VARCHAR(50));"

docker exec postgres-db psql -U admin -d app_database -c "CREATE TABLE lignes_commandes (ligne_id VARCHAR(12) PRIMARY KEY, commande_id VARCHAR(12), produit_id VARCHAR(10), quantite INTEGER, prix_unitaire DECIMAL(10,2), remise_pourcent DECIMAL(5,2), montant_ligne DECIMAL(10,2));"

docker exec postgres-db psql -U admin -d app_database -c "CREATE TABLE calendrier (date_id VARCHAR(8) PRIMARY KEY, date_complete DATE, annee INTEGER, trimestre VARCHAR(2), mois_numero INTEGER, mois_nom VARCHAR(20), semaine INTEGER, jour_mois INTEGER, jour_semaine VARCHAR(20), est_weekend VARCHAR(3), est_ferie VARCHAR(3));"
```

### Étape 3 : Importer les données

```cmd
docker exec postgres-db psql -U admin -d app_database -c "\COPY clients FROM '/tmp/csv/data_clients.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');"

docker exec postgres-db psql -U admin -d app_database -c "\COPY produits FROM '/tmp/csv/data_produits.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');"

docker exec postgres-db psql -U admin -d app_database -c "\COPY commandes FROM '/tmp/csv/data_commandes.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');"

docker exec postgres-db psql -U admin -d app_database -c "\COPY lignes_commandes FROM '/tmp/csv/data_lignes_commandes.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');"

docker exec postgres-db psql -U admin -d app_database -c "\COPY calendrier FROM '/tmp/csv/dim_calendrier.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8');"
```

### Étape 4 : Vérifier l'import

```cmd
docker exec postgres-db psql -U admin -d app_database -c "SELECT 'clients' as table_name, COUNT(*) FROM clients UNION ALL SELECT 'produits', COUNT(*) FROM produits UNION ALL SELECT 'commandes', COUNT(*) FROM commandes UNION ALL SELECT 'lignes_commandes', COUNT(*) FROM lignes_commandes UNION ALL SELECT 'calendrier', COUNT(*) FROM calendrier;"
```

---

## 🔍 Se connecter à PostgreSQL

### Via ligne de commande

```cmd
docker exec -it postgres-db psql -U admin -d app_database
```

### Commandes SQL utiles

```sql
-- Voir les tables
\dt

-- Voir la structure d'une table
\d clients

-- Requêtes de test
SELECT * FROM clients LIMIT 5;
SELECT categorie, COUNT(*) FROM produits GROUP BY categorie;
SELECT SUM(montant_ttc) as ca_total FROM commandes;

-- Quitter
\q
```

### Via un client graphique (DBeaver, pgAdmin...)

| Paramètre | Valeur |
|-----------|--------|
| Host | `localhost` |
| Port | `5432` |
| Database | `app_database` |
| User | `admin` |
| Password | `SecureP@ssw0rd2024!` |

---

## ❌ Problèmes courants

### "Docker n'est pas reconnu"
→ Docker Desktop n'est pas démarré ou pas installé correctement

### "Le conteneur postgres-db n'existe pas"
→ Lancez d'abord : `docker compose up -d`

### "Permission denied" sur PowerShell
→ Exécutez : `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`

### "Le fichier CSV n'existe pas"
→ Vérifiez que le dossier `csv_data` existe et contient les fichiers

### Caractères spéciaux mal affichés
→ Les CSV sont en UTF-8, vérifiez l'encodage dans votre éditeur

---

## ✅ Résultat attendu

Après l'import, vous devriez avoir :

| Table | Nombre de lignes |
|-------|------------------|
| clients | 500 |
| produits | 100 |
| commandes | 2000 |
| lignes_commandes | ~5900 |
| calendrier | 731 |
