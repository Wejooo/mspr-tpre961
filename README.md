# MSPR TPRE961 — PoC Infrastructure K3s

Proof of Concept d'une infrastructure Kubernetes en Infrastructure as Code pour le projet scolaire MSPR TPRE961 (EPSI).

Déploiement d'un cluster K3s local sur 3 VMs KVM avec l'ERP Odoo 18 LTS accessible en HTTPS.

## Architecture

```
┌─────────────────────────────────────────────────┐
│  WSL2 Debian Trixie (hôte)                      │
│                                                 │
│  ┌─── libvirt NAT 192.168.100.0/24 ───────────┐│
│  │                                             ││
│  │  control-plane    worker-1      worker-2    ││
│  │  .10 (2c/3G)      .11 (2c/4G)  .12 (2c/4G)││
│  │       K3s server + Traefik v3               ││
│  │       K3s agent         K3s agent           ││
│  │                                             ││
│  │       Odoo 18 LTS (Helm Bitnami)           ││
│  │       PostgreSQL                            ││
│  └─────────────────────────────────────────────┘│
│                                                 │
│  https://odoo.local ──► Traefik Ingress (TLS)  │
└─────────────────────────────────────────────────┘
```

## Stack technologique

| Composant | Version |
|-----------|---------|
| Hyperviseur | KVM/libvirt |
| IaC infrastructure | Terraform v1.15.5 (provider dmacvicar/libvirt) |
| IaC configuration | Ansible Core v2.20.4 |
| Kubernetes | K3s v1.33 |
| Packaging K8s | Helm v4.1.4 |
| Applicatif | Odoo 18 LTS (chart Bitnami) |
| Ingress | Traefik v3 (natif K3s) + certificat TLS autosigné |

## Prérequis système

- **OS** : WSL2 avec Debian Trixie (ou distribution compatible)
- **RAM** : 15 Go minimum (11 Go alloués aux VMs)
- **CPU** : 6 coeurs minimum
- **Virtualisation imbriquée** : activée (`/dev/kvm` disponible)
- **Logiciels** : libvirt, qemu-kvm, terraform, ansible, helm, kubectl, git

### Activation de la virtualisation imbriquée (WSL2)

Ajouter dans `%USERPROFILE%\.wslconfig` :

```ini
[wsl2]
nestedVirtualization=true
memory=15GB
processors=12
```

Puis redémarrer WSL : `wsl --shutdown`

## Déploiement pas-à-pas

### Phase 0 — Préparation

```bash
# Installer les dépendances système
sudo apt update
sudo apt install -y libvirt-daemon-system libvirt-clients qemu-system-x86 \
  virtinst bridge-utils cloud-image-utils genisoimage curl git

# Démarrer libvirtd
sudo systemctl enable --now libvirtd

# Vérifier KVM
virsh list --all

# Télécharger l'image Ubuntu 22.04 cloud
sudo wget -O /var/lib/libvirt/images/jammy-server-cloudimg-amd64.img \
  https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
```

### Phase 1 — Provisionnement des VMs (Terraform)

```bash
cd terraform

# Créer terraform.tfvars avec votre clé SSH
echo 'ssh_public_key = "'$(cat ~/.ssh/id_ed25519.pub)'"' > terraform.tfvars

# Provisionner les VMs
terraform init
terraform apply

# Vérifier les VMs
virsh list --all
ssh debian@192.168.100.10
```

### Phase 2 — Déploiement K3s (Ansible)

```bash
cd ../ansible

# Installer K3s sur le control-plane
ansible-playbook -i inventory.ini k3s-install.yml

# Rejoindre les workers au cluster
ansible-playbook -i inventory.ini k3s-workers.yml

# Vérifier le cluster
kubectl get nodes
```

### Phase 3 — Déploiement Odoo (Helm)

```bash
# Déployer Odoo 18 via Helm
ansible-playbook -i inventory.ini deploy-odoo.yml

# Vérifier les pods
kubectl get pods -A
kubectl get ingress -A

# Accéder à Odoo
curl -k https://odoo.local
```

### Récupération des identifiants Odoo

```bash
# Email par défaut
echo "Email: user@example.com"

# Mot de passe
kubectl get secret odoo -o jsonpath="{.data.odoo-password}" | base64 -d
```

## Destruction de l'infrastructure

```bash
cd terraform
terraform destroy

# Ou supprimer manuellement les VMs
virsh destroy control-plane && virsh undefine control-plane
virsh destroy worker-1 && virsh undefine worker-1
virsh destroy worker-2 && virsh undefine worker-2
```

## Workflow Git

```
main ← dev ← feature/*
```

- `main` : branche stable, uniquement via PR approuvée
- `dev` : branche d'intégration
- `feature/*` : branches de travail (feature/terraform-vms, feature/k3s-install, feature/deploy-odoo)

## Dépannage

### Les VMs ne démarrent pas

- Vérifier que `/dev/kvm` existe et que libvirtd est actif
- Vérifier `nestedVirtualization=true` dans `.wslconfig`

### K3s ne démarre pas

- Vérifier que le swap est désactivé : `sudo swapoff -a`
- Consulter les logs : `sudo journalctl -u k3s`

### Odoo ne se déploie pas (image pull error)

Les images Bitnami ont été déplacées. Utiliser le registre `bitnami` standard ou `bitnamilegacy/*` dans les values Helm.

### Impossible d'accéder à https://odoo.local

- Vérifier `/etc/hosts` : `192.168.100.10 odoo.local`
- Vérifier l'ingress : `kubectl get ingress -A`
- Le certificat est autosigné : accepter l'avertissement du navigateur

## Structure du projet

```
mspr-tpre961/
├── .gitignore
├── README.md
├── terraform/
│   ├── main.tf              # Provisionnement VMs libvirt
│   ├── variables.tf          # Variables Terraform
│   ├── outputs.tf            # Sorties (IPs des VMs)
│   └── cloud-init/
│       ├── control-plane.yml # Cloud-init control-plane
│       ├── worker.yml        # Cloud-init workers
│       └── network-config.yml# Configuration réseau statique
├── ansible/
│   ├── inventory.ini         # Inventaire des VMs
│   ├── group_vars/
│   │   └── all.yml           # Variables globales
│   ├── k3s-install.yml       # Installation K3s server
│   ├── k3s-workers.yml       # Jointure des workers
│   └── deploy-odoo.yml       # Déploiement Odoo + Ingress TLS
└── secrets/                  # EXCLU du Git
```
