#!/bin/bash

docker pull kindest/node:v${KUBECTL_VER}

kind create cluster --config configs/kind-kong.yml --image kindest/node:v${KUBECTL_VER} --name kind

kubectl create namespace kong

kubectl create secret generic kong-config-secret -n kong \
    --from-literal=portal_session_conf='{"storage":"kong","secret":"super_secret_salt_string","cookie_name":"portal_session","cookie_same_site":"Lax","cookie_secure":false}' \
    --from-literal=admin_gui_session_conf='{"storage":"kong","secret":"super_secret_salt_string","cookie_name":"admin_session","cookie_same_site":"Lax","cookie_secure":false}' \
    --from-literal=pg_host="enterprise-postgresql.kong.svc.cluster.local" \
    --from-literal=kong_admin_password=kong \
    --from-literal=password=kong

kubectl create secret generic kong-enterprise-license --from-literal=license="'{}'" -n kong --dry-run=client -o yaml | kubectl apply -f -

helm repo add jetstack https://charts.jetstack.io ; helm repo update

helm upgrade --install cert-manager jetstack/cert-manager --version v${HELM_CERT_MANAGER_VER} \
    --set installCRDs=true --namespace cert-manager --create-namespace

bash -c "cat <<EOF | kubectl apply -n kong -f -
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: quickstart-kong-selfsigned-issuer-root
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: quickstart-kong-selfsigned-issuer-ca
spec:
  commonName: quickstart-kong-selfsigned-issuer-ca
  duration: 8640h0m0s
  isCA: true
  issuerRef:
    group: cert-manager.io
    kind: Issuer
    name: quickstart-kong-selfsigned-issuer-root
  privateKey:
    algorithm: ECDSA
    size: 256
  renewBefore: 720h0m0s
  secretName: quickstart-kong-selfsigned-issuer-ca
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: quickstart-kong-selfsigned-issuer
spec:
  ca:
    secretName: quickstart-kong-selfsigned-issuer-ca
EOF"

helm repo add kong https://charts.konghq.com ; helm repo update

helm upgrade --install quickstart kong/kong --version ${HELM_KONG_QUICKSTART_VER} --namespace kong --values https://bit.ly/KongGatewayHelmValuesAIO
