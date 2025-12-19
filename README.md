# Speech Redaction Framework

This repository contains the Speech Redaction Framework, a collection of components and code from Google Cloud that you can use to redact sensitive information from audio files.

It can and:
* Process uploaded audio files to Cloud Storage.
* Write the findings to Google Cloud Storage.
* Redact sensitive information from the **audio file** with Google Cloud Data Loss Prevention API.


![Speech Redaction Framework Architecture](images/srf-diagram-1.png "Speech Redaction Framework Architecture")

![Speech Redaction Framework Components](images/srf-diagram-2.png "Speech Redaction Framework Components")

Speech Redaction Framework Limitations:
* The framework can only process .wav or .flac files. This is a limitation within the Framework code not Cloud Speech-to-Text API.

The process follows:


0. An audio file is uploaded to Cloud Storage.
1. The Cloud Function is triggered on object.create.
2. The Audio Process Cloud Function sends a long running job request to Cloud Speech-to-Text.
3. Speech-to-Text processes audio file.
4. The Cloud Function then sends the job ID from Cloud Speech-to-Text with additional metadata to Cloud Pub/Sub.
5. The Cloud Dataflow job identifies sensitive information and writes the findings to a JSON file on Cloud Storage.
6. A second Cloud Function is triggered on object.create that reads the findings JSON file, redacts sensitive information from the audio file and writes the redacted audio file to Cloud Storage.

## Required IAM Permissions

The service account or user executing these commands requires the following IAM Roles at the GCP Project level:

- Cloud Functions Developer
- Compute Admin
- Compute Network Admin
- Dataflow Developer
- DLP Administrator
- Eventarc Admin
- Logs Viewer
- Project IAM Admin
- Pub/Sub Admin
- Service Account User
- Service Usage Admin
- Storage Admin

Give the user the role to impersonate the service account: 
- Workload Identity User

### Gcloud commands:

``` shell
export PROJECT_ID="your-project-id"
export SA_EMAIL="your-service-account@$PROJECT_ID.iam.gserviceaccount.com"
```

``` shell
ROLES=(
  "roles/cloudfunctions.developer"
  "roles/compute.admin"
  "roles/compute.networkAdmin"
  "roles/dataflow.developer"
  "roles/dlp.admin"
  "roles/eventarc.admin"
  "roles/logging.viewer"
  "roles/resourcemanager.projectIamAdmin"
  "roles/pubsub.admin"
  "roles/iam.serviceAccountUser"
  "roles/serviceusage.serviceUsageAdmin"
  "roles/storage.admin"
)

for ROLE in "${ROLES[@]}"; do
  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="$ROLE" \
    --condition=None
done
```

## APIs

#### Enable the required APIs: 
``` shell
export PROJECT_ID="<PROJECT_ID>" 
```
``` shell
gcloud services enable \
    cloudresourcemanager.googleapis.com \
    eventarc.googleapis.com \
--project=${PROJECT_ID}
```


## Deployment

1. Clone the Github repository

2. Modify the following files to specify the correct values for each variable:

- backend.tf
- terraform.tfvars
- providers.tf (optional in case Service Account usage is needed)

3. Optional: modify **"google_data_loss_prevention_inspect_template" "dlp_template"** resource in **main.tf** to customize DLP inspect template with the required infotypes to be redacted. 

4. Validate that the selected subnet has Private Google Access: On.

5. Initialize and apply terraform changes:

``` shell
terraform init
```

``` shell
terraform plan
```

``` shell
terraform apply
```



**This is not an officially supported Google product**
