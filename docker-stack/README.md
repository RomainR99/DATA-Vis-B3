# 🐳 Stack Docker - Nginx Reverse Proxy + Web Servers + PostgreSQL

## 📋 Architecture

```
                    ┌─────────────────────────────────────────┐
                    │              INTERNET                   │
                    └───────────────────┬─────────────────────┘
                                        │
                                        ▼ Port 80
                    ┌─────────────────────────────────────────┐
                    │          NGINX REVERSE PROXY            │
                    │            (Load Balancer)              │
                    │           nginx-proxy:80                │
                    └───────────────────┬─────────────────────┘
                                        │
                    ┌───────────────────┼───────────────────┐
                    │                   │                   │
                    ▼                   │                   ▼
        ┌───────────────────┐           │       ┌───────────────────┐
        │   NGINX WEB 1     │           │       │   NGINX WEB 2     │
        │   nginx-web1:80   │           │       │   nginx-web2:80   │
        │   (🔵 Bleu)       │           │       │   (🟢 Vert)       │
        └─────────┬─────────┘           │       └─────────┬─────────┘
                  │                     │                 │
                  └─────────────────────┼─────────────────┘
                                        │
                                        ▼
                    ┌─────────────────────────────────────────┐
                    │            POSTGRESQL                   │
                    │          postgres-db:5432               │
                    └─────────────────────────────────────────┘

        ═══════════════════════════════════════════════════════
        Réseau frontend : nginx-proxy ↔ nginx-web1 ↔ nginx-web2
        Réseau backend  : nginx-web1 ↔ nginx-web2 ↔ postgres
        ═══════════════════════════════════════════════════════
```

## 🚀 Démarrage rapide

### 1. Cloner et démarrer

```bash
cd docker-stack

# Démarrer toute la stack
docker compose up -d

# Voir les logs en temps réel
docker compose logs -f
```

### 2. Tester

```bash
# Accéder à l'application (via le reverse proxy)
curl http://localhost

# Tester le load balancing (rafraîchir plusieurs fois)
# La page alternera entre bleu (web1) et vert (web2)
for i in {1..10}; do curl -s http://localhost | grep "WEB SERVER"; done

# Vérifier les headers de réponse
curl -I http://localhost

# Health check du proxy
curl http://localhost/health

# Health check des backends
curl http://localhost/nginx-status
```

### 3. Connexion PostgreSQL

```bash
# Via docker
docker exec -it postgres-db psql -U admin -d app_database

# Via client externe
psql -h localhost -p 5432 -U admin -d app_database
# Password: SecureP@ssw0rd2024!
```

## 📁 Structure des fichiers

```
docker-stack/
├── docker-compose.yml          # Configuration principale
├── .env                        # Variables d'environnement
├── README.md                   # Ce fichier
│
├── nginx-proxy/
│   └── nginx.conf              # Config reverse proxy + load balancing
│
├── nginx-web1/
│   ├── nginx.conf              # Config serveur web 1
│   └── html/
│       └── index.html          # Page d'accueil (🔵 bleue)
│
├── nginx-web2/
│   ├── nginx.conf              # Config serveur web 2
│   └── html/
│       └── index.html          # Page d'accueil (🟢 verte)
│
└── postgres/
    └── init/
        └── 01-init.sql         # Script d'initialisation BDD
```

## ⚙️ Configuration

### Variables d'environnement (.env)

| Variable | Description | Défaut |
|----------|-------------|--------|
| `POSTGRES_USER` | Utilisateur PostgreSQL | admin |
| `POSTGRES_PASSWORD` | Mot de passe PostgreSQL | SecureP@ssw0rd2024! |
| `POSTGRES_DB` | Nom de la base de données | app_database |

### Ports exposés

| Service | Port interne | Port exposé |
|---------|--------------|-------------|
| nginx-proxy | 80 | **80** |
| nginx-web1 | 80 | - (interne) |
| nginx-web2 | 80 | - (interne) |
| postgres | 5432 | **5432** |

## 🔧 Commandes utiles

```bash
# Démarrer la stack
docker compose up -d

# Arrêter la stack
docker compose down

# Arrêter et supprimer les volumes (reset complet)
docker compose down -v

# Voir les conteneurs
docker compose ps

# Logs d'un service spécifique
docker compose logs -f nginx-proxy
docker compose logs -f nginx-web1
docker compose logs -f postgres

# Redémarrer un service
docker compose restart nginx-proxy

# Reconstruire après modification
docker compose up -d --force-recreate

# Entrer dans un conteneur
docker exec -it nginx-proxy sh
docker exec -it postgres-db bash

# Voir les stats des conteneurs
docker stats
```

## 🔄 Load Balancing

Le reverse proxy utilise l'algorithme **round-robin** par défaut. Pour changer :

```nginx
# Dans nginx-proxy/nginx.conf, section upstream

# Round-robin (défaut) - alternance simple
upstream web_backends {
    server nginx-web1:80;
    server nginx-web2:80;
}

# Least connections - vers le serveur le moins chargé
upstream web_backends {
    least_conn;
    server nginx-web1:80;
    server nginx-web2:80;
}

# IP Hash - sticky sessions (même client → même serveur)
upstream web_backends {
    ip_hash;
    server nginx-web1:80;
    server nginx-web2:80;
}

# Weighted - distribution pondérée
upstream web_backends {
    server nginx-web1:80 weight=3;  # 75% du trafic
    server nginx-web2:80 weight=1;  # 25% du trafic
}
```

## 🩺 Health Checks

```bash
# Status du proxy
curl http://localhost/nginx-status

# Health check global
curl http://localhost/health

# Health check direct des backends (via docker)
docker exec nginx-proxy curl http://nginx-web1/health
docker exec nginx-proxy curl http://nginx-web2/health
```

## 🛠️ Troubleshooting

### Le proxy ne démarre pas
```bash
# Vérifier la syntaxe nginx
docker exec nginx-proxy nginx -t

# Voir les logs
docker compose logs nginx-proxy
```

### PostgreSQL ne se connecte pas
```bash
# Vérifier que le conteneur est healthy
docker compose ps

# Tester la connexion
docker exec postgres-db pg_isready -U admin

# Voir les logs
docker compose logs postgres
```

### Les backends ne répondent pas
```bash
# Vérifier la connectivité réseau
docker exec nginx-proxy ping nginx-web1
docker exec nginx-proxy ping nginx-web2

# Tester depuis le proxy
docker exec nginx-proxy curl http://nginx-web1
docker exec nginx-proxy curl http://nginx-web2
```

## 📊 Monitoring avec les headers

Chaque réponse inclut des headers pour identifier le backend :

```bash
curl -I http://localhost
# X-Served-By: nginx-web1  (ou nginx-web2)
# X-Backend-Server: web1   (ou web2)
```

## 🔒 Sécurité (Production)

Pour un déploiement en production, ajouter :

1. **HTTPS/TLS** - Certificats SSL avec Let's Encrypt
2. **Fail2ban** - Protection contre les attaques bruteforce
3. **Rate limiting** - Limiter les requêtes par IP
4. **Firewall** - Restreindre les ports exposés
5. **Secrets Docker** - Ne pas stocker les mots de passe en clair

---

**Auteur** : Généré pour le cours BI & Datavisualisation avancée  
**Version** : 1.0
