#!/bin/bash

if [ -z "$PROJECT_ID" ]; then
  read -p "Enter your GCP Project ID: " PROJECT_ID
fi

SA_NAME=upbound-platform-admin
SA="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "=== Adding IAM roles for $SA ==="

roles=(
  "roles/iam.serviceAccountAdmin"           
  "roles/iam.serviceAccountKeyAdmin"        
  "roles/iam.serviceAccountUser"            
  "roles/resourcemanager.projectIamAdmin"   
  "roles/container.admin"                   
  "roles/compute.networkAdmin"             
  "roles/cloudsql.admin"                  
  "roles/storage.admin"                  
)

for role in "${roles[@]}"; do
  echo "Adding role: $role"
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SA" \
    --role="$role"
done

echo "=== Creating new service account key ==="
gcloud iam service-accounts keys create new-gcp-creds.json \
  --project "$PROJECT_ID" \
  --iam-account "$SA"

echo "=== Updating Kubernetes secret ==="
kubectl delete secret gcp-creds --namespace default || true
kubectl create secret generic gcp-creds \
  --namespace default \
  --from-file=creds=./new-gcp-creds.json

echo "=== Updating provider config ==="
cat <<EOF | kubectl apply -f -
apiVersion: gcp.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: example
spec:
  projectID: $PROJECT_ID
  credentials:
    source: Secret
    secretRef:
      namespace: default
      name: gcp-creds
      key: creds
EOF

