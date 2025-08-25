# Client rom2

## 📋 Informations

- **Nom**: rom2
- **Domaine**: rom2.duciel.cloud
- **Version Odoo**: 18-argo
- **Modules**: bas
- **Environnement**: production
- **Créé le**: Mon Aug 25 12:59:31 UTC 2025

## 🔐 Accès

- **URL**: https://rom2.duciel.cloud
- **Admin**: admin
- **Mot de passe**: WXkXRo6ALxqn9b+P

## 🚀 Commandes utiles

```bash
# Vérifier le statut
kubectl get all -n odoo-rom2

# Voir les logs
kubectl logs -f deployment/rom2-odoo -n odoo-rom2

# Accéder au pod
kubectl exec -it deployment/rom2-odoo -n odoo-rom2 -- /bin/bash

# Vérifier PostgreSQL
kubectl get cluster rom2-postgres -n odoo-rom2
```

## 🔧 Maintenance

```bash
# Redémarrer Odoo
kubectl rollout restart deployment/rom2-odoo -n odoo-rom2

# Sauvegarder la base
kubectl exec -it rom2-postgres-1 -n odoo-rom2 -- pg_dump rom2 > backup-rom2-$(date +%Y%m%d).sql

# Restaurer la base
kubectl exec -i rom2-postgres-1 -n odoo-rom2 -- psql rom2 < backup-rom2-YYYYMMDD.sql
```
