#!/bin/bash
# scripts/create-client.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

CLIENT_NAME=$1
DB_NAME=$2
ODOO_VERSION=$3
MODULES=$4
ENVIRONMENT=${5:-"production"}

if [[ -z "$CLIENT_NAME" || -z "$DB_NAME" || -z "$ODOO_VERSION" ]]; then
    echo "Usage: $0 <client-name> <db-name> <odoo-version> <modules> [environment]"
    echo "Example: $0 rom1 rom1_mokatourisme_dev 18.0 'base,sale,crm' production"
    exit 1
fi

echo "🚀 Création du client $CLIENT_NAME..."

# 1. Créer le fichier values
cat > environments/clients/${CLIENT_NAME}-values.yaml << EOF
# Valeurs pour le client $CLIENT_NAME
replicaCount: 1

client:
  name: "$CLIENT_NAME"
  host: "$CLIENT_NAME.mokatourisme.dev"
  namespace: "odoo-$CLIENT_NAME"
  modules: "$MODULES"
  language: "fr_FR"

image:
  repository_name: odoo
  tag: "$ODOO_VERSION"
  pullPolicy: Always

database:
  host: postgresql-service
  user: admin
  password: cm9vdA==
  name: "$DB_NAME"

odoo:
  adminPassword: "YWRtaW4xMjM="

ingress:
  enabled: true
  className: "traefik"
  host: "$CLIENT_NAME.mokatourisme.dev"
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    cert-manager.io/cluster-issuer: "$CLIENT_NAME--letsencrypt-prod"
  tls:
    - secretName: odoo-tls-cert
      hosts:
        - "$CLIENT_NAME.mokatourisme.dev"

persistence:
  enabled: true
  size: 10Gi
  storageClass: ""
EOF

# 2. Créer l'application ArgoCD
cat > argocd/applications/${CLIENT_NAME}-app.yaml << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: odoo-$CLIENT_NAME
  namespace: argocd
  labels:
    app.kubernetes.io/part-of: odoo-platform
spec:
  project: default
  source:
    repoURL: https://github.com/votre-org/odoo-platform.git
    targetRevision: HEAD
    path: chart
    helm:
      valueFiles:
        - ../environments/clients/${CLIENT_NAME}-values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: odoo-$CLIENT_NAME
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

echo "✅ Client $CLIENT_NAME créé !"
echo "📁 Values: environments/clients/${CLIENT_NAME}-values.yaml"
echo "📁 App: argocd/applications/${CLIENT_NAME}-app.yaml"
echo ""
echo "🔄 Pour déployer :"
echo "git add . && git commit -m 'Add client $CLIENT_NAME' && git push"
