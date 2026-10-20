#!/usr/bin/env bash
# One-time GCP landing zone for the jerameyjames.com Cloud Run service.
# Idempotent: safe to re-run. Run with gcloud authenticated as a project owner.
#
# GitHub Actions authenticates through the shared WIF provider
# (pool "github", provider "tolowa-studio-github"); no JSON keys are created.
# Everything here is free or scale-to-zero: no load balancer, no min instances.
# The runtime SA gets no roles: the site is static and reads no secrets.

set -euo pipefail

GCP_PROJECT="${GCP_PROJECT:-tolowa-studio}"
GCP_REGION="${GCP_REGION:-us-west1}"
AR_REPO="${AR_REPO:-jerameyjames-com}"
GITHUB_REPO="${GITHUB_REPO:-tolowa-studio/jerameyjames.com}"
WIF_PROJECT_NUMBER="${WIF_PROJECT_NUMBER:-895468771800}"
DEPLOYER_SA="jerameyjames-com-deployer@${GCP_PROJECT}.iam.gserviceaccount.com"
RUNTIME_SA="jerameyjames-com-runtime@${GCP_PROJECT}.iam.gserviceaccount.com"

SERVICE_NAME="${SERVICE_NAME:-jerameyjames-com}"
PLACEHOLDER_IMAGE="us-docker.pkg.dev/cloudrun/container/hello"

# Assumes the shared provider maps attribute.repository=assertion.repository.
echo "== APIs =="
gcloud services enable run.googleapis.com artifactregistry.googleapis.com \
  iamcredentials.googleapis.com --project="${GCP_PROJECT}"

echo "== Artifact Registry (${AR_REPO}) =="
gcloud artifacts repositories describe "${AR_REPO}" \
  --project="${GCP_PROJECT}" --location="${GCP_REGION}" >/dev/null 2>&1 \
  || gcloud artifacts repositories create "${AR_REPO}" \
    --project="${GCP_PROJECT}" --location="${GCP_REGION}" \
    --repository-format=docker \
    --description="jerameyjames.com container images"

echo "== Service accounts =="
for SA in "${DEPLOYER_SA}" "${RUNTIME_SA}"; do
  gcloud iam service-accounts describe "${SA}" --project="${GCP_PROJECT}" >/dev/null 2>&1 \
    || gcloud iam service-accounts create "${SA%%@*}" \
      --project="${GCP_PROJECT}" --display-name="${SA%%@*}"
done

PRINCIPAL="principalSet://iam.googleapis.com/projects/${WIF_PROJECT_NUMBER}/locations/global/workloadIdentityPools/github/attribute.repository/${GITHUB_REPO}"

echo "== GitHub Actions (${GITHUB_REPO}) may impersonate the deployer =="
gcloud iam service-accounts add-iam-policy-binding "${DEPLOYER_SA}" \
  --project="${GCP_PROJECT}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="${PRINCIPAL}" >/dev/null

echo "== Service (${SERVICE_NAME}): create once with a placeholder image, public =="
# Creating it here lets the deployer hold run.developer on this one service
# instead of run.admin on the shared project. CI replaces the image.
gcloud run services describe "${SERVICE_NAME}" \
  --project="${GCP_PROJECT}" --region="${GCP_REGION}" >/dev/null 2>&1 \
  || gcloud run deploy "${SERVICE_NAME}" \
    --project="${GCP_PROJECT}" --region="${GCP_REGION}" \
    --image="${PLACEHOLDER_IMAGE}" \
    --service-account="${RUNTIME_SA}" \
    --min-instances=0 --max-instances=1 --memory=128Mi \
    --no-allow-unauthenticated --quiet
gcloud run services add-iam-policy-binding "${SERVICE_NAME}" \
  --project="${GCP_PROJECT}" --region="${GCP_REGION}" \
  --member="allUsers" --role="roles/run.invoker" >/dev/null

echo "== Deployer: push images, deploy this service only, act as runtime SA =="
gcloud artifacts repositories add-iam-policy-binding "${AR_REPO}" \
  --project="${GCP_PROJECT}" --location="${GCP_REGION}" \
  --member="serviceAccount:${DEPLOYER_SA}" \
  --role="roles/artifactregistry.writer" >/dev/null
gcloud run services add-iam-policy-binding "${SERVICE_NAME}" \
  --project="${GCP_PROJECT}" --region="${GCP_REGION}" \
  --member="serviceAccount:${DEPLOYER_SA}" \
  --role="roles/run.developer" >/dev/null
# Earlier revisions of this script granted project-wide run.admin; drop it.
gcloud projects remove-iam-policy-binding "${GCP_PROJECT}" \
  --member="serviceAccount:${DEPLOYER_SA}" \
  --role="roles/run.admin" --condition=None >/dev/null 2>&1 || true
gcloud iam service-accounts add-iam-policy-binding "${RUNTIME_SA}" \
  --project="${GCP_PROJECT}" \
  --member="serviceAccount:${DEPLOYER_SA}" \
  --role="roles/iam.serviceAccountUser" >/dev/null

cat <<EOF

Done. GitHub repository variables for ${GITHUB_REPO} (optional; the workflow
defaults to these values):
  GCP_WORKLOAD_IDENTITY_PROVIDER=projects/${WIF_PROJECT_NUMBER}/locations/global/workloadIdentityPools/github/providers/tolowa-studio-github
  GCP_SERVICE_ACCOUNT=${DEPLOYER_SA}
EOF
