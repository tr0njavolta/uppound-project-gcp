#!/bin/bash

if [ -z "$PROJECT_ID" ]; then
  read -p "Enter your GCP Project ID: " PROJECT_ID
fi

if [ -z "$SA_NAME" ]; then
  read -p "Enter Service Account name (default: upbound-platform-admin): " SA_NAME
  SA_NAME=${SA_NAME:-upbound-platform-admin}
fi

SA="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "# Creating service account $SA_NAME in project $PROJECT_ID #"
gcloud iam service-accounts create $SA_NAME --project $PROJECT_ID

echo "# Adding IAM roles for $SA #"
roles=(
  "roles/resourcemanager.projectIamAdmin"
  "roles/iam.serviceAccountAdmin"
  "roles/iam.serviceAccountKeyAdmin"
  "roles/iam.serviceAccountUser"
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

echo "# Creating new service account key #"
gcloud iam service-accounts keys create gcp-creds.json \
  --project "$PROJECT_ID" \
  --iam-account "$SA"

echo "# Service account key saved to gcp-creds.json #"

echo "# Updating Kubernetes secret #"
kubectl delete secret gcp-creds --namespace default || true
kubectl create secret generic gcp-creds \
  --namespace default \
  --from-file=creds=./gcp-creds.json

echo "# Updating provider config #"
cat <<EOF > gcp-provider-config.yaml
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
kubectl apply -f gcp-provider-config.yaml

echo "# Setup complete #"
