#!/bin/sh

# Feel free to change the variables
PROJECT_ID=$DEVSHELL_PROJECT_ID
SERVICE_ACCOUNT_NAME="terraform"

# Set secrets via environment variables
export TF_VAR_sql_username="<username>"
export TF_VAR_sql_password="<password>"

#Create service account name terraform and download service account key as json file
echo "Creating terraform service account"
gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" --role="roles/owner"
gcloud iam service-accounts keys create credential.json --iam-account=$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com

#Enable required APIs
echo "Enabling required APIs"
gcloud services enable compute.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable vpcaccess.googleapis.com
gcloud services enable servicenetworking.googleapis.com
gcloud services enable containerregistry.googleapis.com
gcloud services enable sqladmin.googleapis.com
gcloud services enable run.googleapis.com

echo "Building image with tag: gcr.io/$PROJECT_ID/techchallengeapp"
docker build -t gcr.io/$PROJECT_ID/techchallengeapp .

echo "Pushing image to gcr.io/$PROJECT_ID"
docker push gcr.io/$PROJECT_ID/techchallengeapp

sed -i s/PROJECT_ID/$PROJECT_ID/g terraform.tfvars

echo "Initializing Terrform"
terraform init

# When you run Terraform, it'll pick up the secret automatically
echo "Applying Terraform template"
terraform apply -auto-approve