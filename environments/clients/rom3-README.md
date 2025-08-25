# Client rom3

## 📋 Informations

- **Nom**: rom3
- **Domaine**: rom3.duciel.cloud
- **Version Odoo**: 18-argo
- **Modules**: base
- **Environnement**: production
- **Créé le**: Mon Aug 25 14:04:44 UTC 2025

## 🔐 Accès

- **URL**: https://rom3.duciel.cloud
- **Admin**: admin
- **Mot de passe**: RpKuCz02icGlaExf

## 🚀 Commandes utiles

```bash
# Vérifier le statut
kubectl get all -n odoo-rom3

# Voir les logs
kubectl logs -f deployment/rom3-odoo -n odoo-rom3

# Accéder au pod
kubectl exec -it deployment/rom3-odoo -n odoo-rom3 -- /bin/bash

# Vérifier PostgreSQL
kubectl get cluster rom3-postgres -n odoo-rom3
```

## 🔧 Maintenance

```bash
# Redémarrer Odoo
kubectl rollout restart deployment/rom3-odoo -n odoo-rom3

# Sauvegarder la base
kubectl exec -it rom3-postgres-1 -n odoo-rom3 -- pg_dump rom3 > backup-rom3-$(date +%Y%m%d).sql

# Restaurer la base
kubectl exec -i rom3-postgres-1 -n odoo-rom3 -- psql rom3 < backup-rom3-YYYYMMDD.sql
```
