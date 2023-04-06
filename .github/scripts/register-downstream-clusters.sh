#!/bin/bash

set -euxo pipefail

url="${url-172.18.0.1.omg.howdoi.website}"
cluster_downstream="${cluster_downstream-k3d-downstream}"

# hardcoded token, cluster is ephemeral and private
token="token-ci:zfllcbdr4677rkj4hmlr8rsmljg87l7874882928khlfs2pmmcq7l5"

user=$(kubectl get users -o go-template='{{range .items }}{{.metadata.name}}{{"\n"}}{{end}}' | tail -1)
sed "s/user-zvnsr/$user/" <<'EOF' | kubectl apply -f -
apiVersion: management.cattle.io/v3
kind: Token
authProvider: local
current: false
description: mytoken
expired: false
expiresAt: ""
isDerived: true
lastUpdateTime: ""
metadata:
  generateName: token-
  labels:
    authn.management.cattle.io/token-userId: user-zvnsr
    cattle.io/creator: norman
  name: token-ci
ttl: 0
token: zfllcbdr4677rkj4hmlr8rsmljg87l7874882928khlfs2pmmcq7l5
userId: user-zvnsr
userPrincipal:
  displayName: Default Admin
  loginName: admin
  me: true
  metadata:
    creationTimestamp: null
    name: local://user-zvnsr
  principalType: user
  provider: local
EOF

kubectl apply -f - <<EOF
apiVersion: management.cattle.io/v3
kind: Project
metadata:
  labels:
    cattle.io/creator: norman
  namespace: local
  name: ci-project
spec:
  clusterName: local
  displayName: ci-project
  namespaceDefaultResourceQuota:
    limit:
      configMaps: '10'
  resourceQuota:
    limit:
      configMaps: '1000'
    usedLimit: {}
EOF

echo -e "4\n" | rancher login "https://$url" --token "$token" --skip-verify

rancher clusters create second --import

kubectl config use-context "$cluster_downstream"

rancher cluster import second
rancher cluster import second | grep curl | sh

until rancher cluster list | grep second | grep -q active; do echo waiting for cluster registration; sleep 5; done
