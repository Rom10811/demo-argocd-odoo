#!/bin/bash
# scripts/create-client.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

CLIENT_NAME=$1
DOMAIN=$2
ODOO_VERSION=${3:-"18-argo"}
MODULES=${4:-"base,sale,crm"}
ENVIRONMENT=${5:-"production"}
POSTGRES_SIZE=${6:-"20Gi"}
FILESTORE_SIZE=${7:-"10Gi"}

# ✅ Fonction d'aide
show_usage() {
    echo "🚀 Script de création de client Odoo"
    echo ""
    echo "Usage: $0 <client-name> <domain> [odoo-version] [modules] [environment] [postgres-size] [filestore-size]"
    echo ""
    echo "Exemples:"
    echo "  $0 automobile automobile.duciel.cloud"
    echo "  $0 rom1 rom1.mokatourisme.dev 18-argo 'base,sale,crm,event' production 30Gi 15Gi"
    echo "  $0 client-test test.example.com 17.0 base development"
    echo ""
    echo "Paramètres:"
    echo "  client-name     : Nom du client (ex: automobile, rom1, client-xyz)"
    echo "  domain          : Domaine d'accès (ex: automobile.duciel.cloud)"
    echo "  odoo-version    : Version Odoo (défaut: 18-argo)"
    echo "  modules         : Modules à installer (défaut: base,sale,crm)"
    echo "  environment     : Environnement (défaut: production)"
    echo "  postgres-size   : Taille stockage PostgreSQL (défaut: 20Gi)"
    echo "  filestore-size  : Taille stockage filestore (défaut: 10Gi)"
}

if [[ -z "$CLIENT_NAME" || -z "$DOMAIN" ]]; then
    show_usage
    exit 1
fi

# ✅ Validation du nom client
if [[ ! "$CLIENT_NAME" =~ ^[a-z0-9-]+$ ]]; then
    echo "❌ Erreur: Le nom du client doit contenir uniquement des lettres minuscules, chiffres et tirets"
    exit 1
fi

# ✅ Configuration des ressources selon l'environnement
if [[ "$ENVIRONMENT" == "development" ]]; then
    POSTGRES_INSTANCES=1
    REPLICA_COUNT=1
    MEMORY_LIMIT="512Mi"
    MEMORY_REQUEST="256Mi"
    CPU_LIMIT="500m"
    CPU_REQUEST="100m"
else
    POSTGRES_INSTANCES=2
    REPLICA_COUNT=2
    MEMORY_LIMIT="1Gi"
    MEMORY_REQUEST="512Mi"
    CPU_LIMIT="1000m"
    CPU_REQUEST="200m"
fi

echo "🚀 Création du client $CLIENT_NAME..."
echo "📍 Domaine: $DOMAIN"
echo "🐳 Version Odoo: $ODOO_VERSION"
echo "📦 Modules: $MODULES"
echo "🌍 Environnement: $ENVIRONMENT"

# ✅ 1. Créer le répertoire client s'il n'existe pas
mkdir -p "environments/clients"
mkdir -p "argocd/applications"

# ✅ 2. Générer un mot de passe aléatoire pour l'admin
ADMIN_PASSWORD=$(openssl rand -base64 12)
ADMIN_PASSWORD_B64=$(echo -n "$ADMIN_PASSWORD" | base64 -w 0)

echo "🔐 Mot de passe admin généré: $ADMIN_PASSWORD"

# ✅ 3. Créer le fichier values optimisé
cat > "environments/clients/${CLIENT_NAME}-values.yaml" << EOF
# ✅ Configuration pour le client ${CLIENT_NAME}
# Généré le $(date)

replicaCount: ${REPLICA_COUNT}

client:
  name: "${CLIENT_NAME}"
  host: "${DOMAIN}"
  namespace: "odoo-${CLIENT_NAME}"
  modules: "${MODULES}"
  language: "fr_FR"

image:
  repository_name: "ghcr.io/moka-tourisme/docker-moka"
  tag: "${ODOO_VERSION}"
  pullPolicy: Always
  registrySecret: |
    {
      "auths": {
        "ghcr.io": {
          "auth": "Um9tMTA4MTE6Z2hwX1pYR2lYV2NPV2RWZERFVG9kSW5BYm9abHd0d1NDTDM0bjV0WQ=="
        }
      }
    }

# ✅ Configuration database (sera remplacée par PostgreSQL CNPG)
database:
  host: "${CLIENT_NAME}-postgres-rw"
  user: "odoo"
  password: "b2RvbzEyMw=="  # odoo123 en base64
  name: "${CLIENT_NAME}"

# ✅ Configuration PostgreSQL CloudNativePG
postgres:
  cluster:
    instances: ${POSTGRES_INSTANCES}
    storage:
      size: "${POSTGRES_SIZE}"
      storageClass: ""  # Utilise la classe par défaut
  resources:
    limits:
      memory: "${MEMORY_LIMIT}"
      cpu: "${CPU_LIMIT}"
    requests:
      cpu: "${CPU_REQUEST}"
      memory: "${MEMORY_REQUEST}"

# ✅ Configuration Odoo
odoo:
  adminPassword: "${ADMIN_PASSWORD_B64}"

# ✅ Configuration Ingress
ingress:
  enabled: true
  className: "traefik"
  host: "${DOMAIN}"
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  tls:
    - secretName: "${CLIENT_NAME}-tls-cert"
      hosts:
        - "${DOMAIN}"

# ✅ Configuration stockage
persistence:
  enabled: true
  size: "${FILESTORE_SIZE}"
  storageClass: ""

# ✅ Configuration service
service:
  type: ClusterIP
  port: 8069

# ✅ Configuration ressources
resources:
  limits:
    memory: "${MEMORY_LIMIT}"
    cpu: "${CPU_LIMIT}"
  requests:
    cpu: "${CPU_REQUEST}"
    memory: "${MEMORY_REQUEST}"
EOF

# ✅ 4. Créer l'application ArgoCD
cat > "argocd/applications/${CLIENT_NAME}-app.yaml" << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: odoo-${CLIENT_NAME}
  namespace: argocd
  labels:
    app.kubernetes.io/part-of: odoo-platform
    client: ${CLIENT_NAME}
    environment: ${ENVIRONMENT}
spec:
  project: default
  source:
    repoURL: https://github.com/Rom10811/demo-argocd-odoo.git
    targetRevision: argo-app-of-apps-cnpg
    path: chart
    helm:
      valueFiles:
        - ../environments/clients/${CLIENT_NAME}-values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: odoo-${CLIENT_NAME}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
    retry:
      limit: 3
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF

# ✅ 5. Créer un README pour le client
cat > "environments/clients/${CLIENT_NAME}-README.md" << EOF
# Client ${CLIENT_NAME}

## 📋 Informations

- **Nom**: ${CLIENT_NAME}
- **Domaine**: ${DOMAIN}
- **Version Odoo**: ${ODOO_VERSION}
- **Modules**: ${MODULES}
- **Environnement**: ${ENVIRONMENT}
- **Créé le**: $(date)

## 🔐 Accès

- **URL**: https://${DOMAIN}
- **Admin**: admin
- **Mot de passe**: ${ADMIN_PASSWORD}

## 🚀 Commandes utiles

\`\`\`bash
# Vérifier le statut
kubectl get all -n odoo-${CLIENT_NAME}

# Voir les logs
kubectl logs -f deployment/${CLIENT_NAME}-odoo -n odoo-${CLIENT_NAME}

# Accéder au pod
kubectl exec -it deployment/${CLIENT_NAME}-odoo -n odoo-${CLIENT_NAME} -- /bin/bash

# Vérifier PostgreSQL
kubectl get cluster ${CLIENT_NAME}-postgres -n odoo-${CLIENT_NAME}
\`\`\`

## 🔧 Maintenance

\`\`\`bash
# Redémarrer Odoo
kubectl rollout restart deployment/${CLIENT_NAME}-odoo -n odoo-${CLIENT_NAME}

# Sauvegarder la base
kubectl exec -it ${CLIENT_NAME}-postgres-1 -n odoo-${CLIENT_NAME} -- pg_dump ${CLIENT_NAME} > backup-${CLIENT_NAME}-\$(date +%Y%m%d).sql

# Restaurer la base
kubectl exec -i ${CLIENT_NAME}-postgres-1 -n odoo-${CLIENT_NAME} -- psql ${CLIENT_NAME} < backup-${CLIENT_NAME}-YYYYMMDD.sql
\`\`\`
EOF

echo ""
echo "✅ Client ${CLIENT_NAME} créé avec succès !"
echo ""
echo "📁 Fichiers générés:"
echo "   - environments/clients/${CLIENT_NAME}-values.yaml"
echo "   - argocd/applications/${CLIENT_NAME}-app.yaml"
echo "   - environments/clients/${CLIENT_NAME}-README.md"
echo ""
echo "🔐 Informations de connexion:"
echo "   - URL: https://${DOMAIN}"
echo "   - Admin: admin"
echo "   - Mot de passe: ${ADMIN_PASSWORD}"
echo ""
echo "🚀 Pour déployer:"
echo "   git add ."
echo "   git commit -m 'Add client ${CLIENT_NAME}'"
echo "   git push"
echo ""
echo "⏱️  Attendre ~5-10 minutes pour que tous les services soient prêts"
echo "🔍 Surveiller le déploiement:"
echo "   kubectl get all -n odoo-${CLIENT_NAME}"
