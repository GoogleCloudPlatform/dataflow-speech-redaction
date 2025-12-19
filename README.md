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

**Use the following code snippet to grant necessary IAM permissions using gcloud:**


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

1. Clone the GitHub repository:
```shell
git clone https://github.com/GoogleCloudPlatform/dataflow-speech-redaction.git
cd dataflow-speech-redaction
```

2. Modify the following files to specify the correct values for each variable:
    - `backend.tf`
    - `terraform.tfvars`
    - `providers.tf` (optional in case Service Account usage is needed)

3. **Optional**: Modify the **"google_data_loss_prevention_inspect_template" "dlp_template"** resource in `main.tf` to customize the DLP inspect template with the required infoTypes to be redacted.

4. Validate that the subnet specified in your `terraform.tfvars` has Private Google Access enabled. The target subnet must have Private Google Access enabled and must reside in the region specified by `var.region`.

5. Initialize, review, and apply the Terraform configuration:
```shell
terraform init
terraform plan
terraform apply
```
## Usage

To trigger the pipeline, upload an audio file (.wav or .flac) to the input bucket defined in your configuration (variable: `audio_files_bucket_name` in `terraform.tfvars`).

Once processing is complete, the redacted audio file will appear in the output bucket (variable: `redacted_audio_bucket_name` in `terraform.tfvars`).

## Scalability

This architecture uses Cloud Functions, which are powered by Cloud Run. They automatically scale up based on incoming traffic (uploaded audio files) and scale down to zero when idle.

To control costs and prevent downstream systems from being overwhelmed, the functions are currently capped at **10 concurrent instances**.

### How to Scale the Functions

To increase the processing throughput or allow more concurrent executions, you must modify the Terraform configuration in `main.tf`.

1.  Locate the `google_cloudfunctions2_function` resources (specifically `audio_process_func` and `redaction_func`).
2.  Inside the `service_config` block, update the `max_instance_count` value.

```hcl
resource "google_cloudfunctions2_function" "audio_process_func" {
  # ...
  service_config {
    max_instance_count = 50   # <--- Update this value (Default: 10)
    # ...
  }
}
```
3. Save the file and apply the changes:
```shell
terraform plan
terraform apply
```



**This is not an officially supported Google product**
