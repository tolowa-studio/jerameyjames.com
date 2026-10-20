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

echo "== Deployer: push images, deploy Cloud Run (run.admin so deploys can keep the service public), act as runtime SA =="
gcloud artifacts repositories add-iam-policy-binding "${AR_REPO}" \
  --project="${GCP_PROJECT}" --location="${GCP_REGION}" \
  --member="serviceAccount:${DEPLOYER_SA}" \
  --role="roles/artifactregistry.writer" >/dev/null
gcloud projects add-iam-policy-binding "${GCP_PROJECT}" \
  --member="serviceAccount:${DEPLOYER_SA}" \
  --role="roles/run.admin" --condition=None >/dev/null
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
