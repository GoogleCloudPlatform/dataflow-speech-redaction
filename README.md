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

The service account or user executing these commands requires the following IAM Roles at the GCP Project level. These are grouped by their functional domain:

*Compute & Orchestration*
- Cloud Functions Developer: To deploy and manage function-based logic.

- Compute Admin: Full control over GCE resources (VMs, disks).

- Dataflow Developer: To execute and monitor data processing pipelines.

*Networking*
- Compute Network Admin: To create and modify VPC resources.

- Compute Network User: Allows the execution account to utilize existing network resources. 

*Data & Security*
- DLP Administrator: Full access to Cloud Data Loss Prevention features.

- Storage Admin: Full control over GCS buckets and objects.

- Pub/Sub Admin: To manage messaging topics and subscriptions.

*Identity & Access Management (IAM)*
- Project IAM Admin: To manage access control for the project.

- Service Account User: Allows the executor to "act as" a service account to run jobs.

- Service Usage Admin: To enable or disable APIs required by the script.

*Logging & Monitoring*
- Logging Admin: To manage log sinks and configurations.

- Logs Viewer: To audit and troubleshoot execution via logs.

## APIs

#### Enable the required APIs: 
``` shell
export PROJECT_ID="<PROJECT_ID>" 
```
``` shell
gcloud services enable \
    cloudbuild.googleapis.com \
    compute.googleapis.com \
    dataflow.googleapis.com \
    run.googleapis.com \
    speech.googleapis.com \
    dlp.googleapis.com \
    cloudfunctions.googleapis.com \
    eventarc.googleapis.com \
--project=${PROJECT_ID}
```

## Roles needed

Grant the necessary IAM roles either through the Google Cloud Console or by using the ```gcloud``` commands provided below.

#### 1. Add the following roles to Compute Engine default service account (PROJECT_NUMBER-compute@developer.gserviceaccount.com):

- Eventarc Event Receiver role
- Cloud Speech-to-Text Service Agent
- DLP User
- DLP Administrator
- Pub/Sub Admin
- Pub/Sub Subscriber
- Pub/Sub Viewer
- Dataflow Worker
- Cloud Run Invoker

```gcloud``` commands:

```shell
export PROJECT_ID="<PROJECT_ID>" 
```

```shell
export GCE_SERVICE_ACCOUNT="$(gcloud projects describe ${PROJECT_ID} --format='value(projectNumber)')-compute@developer.gserviceaccount.com"

gcloud projects add-iam-policy-binding ${PROJECT_ID} --member="serviceAccount:${GCE_SERVICE_ACCOUNT}" --role="roles/eventarc.eventReceiver" 

gcloud projects add-iam-policy-binding ${PROJECT_ID} --member="serviceAccount:${GCE_SERVICE_ACCOUNT}" --role="roles/speech.serviceAgent" 

gcloud projects add-iam-policy-binding ${PROJECT_ID} --member="serviceAccount:${GCE_SERVICE_ACCOUNT}" --role="roles/dlp.user" 

gcloud projects add-iam-policy-binding ${PROJECT_ID} --member="serviceAccount:${GCE_SERVICE_ACCOUNT}" --role="roles/dlp.admin" 

gcloud projects add-iam-policy-binding ${PROJECT_ID} --member="serviceAccount:${GCE_SERVICE_ACCOUNT}" --role="roles/pubsub.admin" 

gcloud projects add-iam-policy-binding ${PROJECT_ID} --member="serviceAccount:${GCE_SERVICE_ACCOUNT}" --role="roles/pubsub.subscriber" 

gcloud projects add-iam-policy-binding ${PROJECT_ID} --member="serviceAccount:${GCE_SERVICE_ACCOUNT}" --role="roles/pubsub.viewer" 

gcloud projects add-iam-policy-binding ${PROJECT_ID} --member="serviceAccount:${GCE_SERVICE_ACCOUNT}" --role="roles/dataflow.worker" 

gcloud projects add-iam-policy-binding ${PROJECT_ID} --member="serviceAccount:${GCE_SERVICE_ACCOUNT}" --role="roles/run.invoker"

gcloud projects add-iam-policy-binding ${PROJECT_ID} --member="serviceAccount:${GCE_SERVICE_ACCOUNT}" --role="roles/cloudbuild.builds.builder"
```

#### 2. Add **roles/pubsub.publisher** to GCS Service account (Google Storage Service Agent)

```gcloud``` commands:

```shell
GCS_SERVICE_ACCOUNT="$(gcloud storage service-agent --project=${PROJECT_ID})"

gcloud projects add-iam-policy-binding ${PROJECT_ID} --member="serviceAccount:${GCS_SERVICE_ACCOUNT}" --role='roles/pubsub.publisher'
```

## How to install the Speech Analysis Framework

#### 1. [Install the Google Cloud SDK](https://cloud.google.com/sdk/install)

#### 2. Create a storage bucket for **Dataflow Staging Files**

```shell
gcloud storage buckets create gs://<BUCKET_NAME> -l <REGION>
```

#### 3. Through the [Google Cloud Console](https://console.cloud.google.com) create a folder named **tmp** in the newly created bucket for the DataFlow staging files

#### 4. Create a storage bucket for **Cloud Functions deployment (Stage bucket)**. 

``` shell
gcloud storage buckets create gs://<BUCKET_NAME> -l <REGION>
```

#### 5. Create a storage bucket for **Uploaded Audio Files**. 

``` shell
gcloud storage buckets create gs://<BUCKET_NAME> -l <REGION>
```

#### 6. Create a storage bucket for **DLP Findings**.  

``` shell
gcloud storage buckets create gs://<BUCKET_NAME> -l <REGION>
```

#### 7. Create a storage bucket for **Redacted Audio Files**

``` shell
gcloud storage buckets create gs://<BUCKET_NAME> -l <REGION>
```

#### 8. Create Cloud Pub/Sub Topic
``` shell
gcloud pubsub topics create [YOUR_TOPIC_NAME]
```

#### 9. Clone the github repo

#### 10. Deploy the **Audio Process** Google Cloud Function

In the cloned repo, go to the `srf-audio-process-func` directory and deploy the following Cloud Function.

> **⚠ NOTE**: On line 29 of the `index.js` file, add your TOPIC_NAME you created in step 7.

> **⚠ NOTE**: the trigger location must be the same as the Uploaded Audio Files bucket.

``` shell
gcloud functions deploy srfAudioProcessFunc \
    --region=<REGION> \
    --trigger-location=[AUDIO_FILES_BUCKET_LOCATION] \
    --stage-bucket=[STAGE_BUCKET_NAME] \
    --runtime=nodejs20 \
    --trigger-bucket=[YOUR_UPLOADED_AUDIO_FILES_BUCKET_NAME] \
    --ingress-settings=internal-only
```
> **⚠ NOTE**: If you run into any timeout issues with Cloud Functions, it is recommend to increase the timeout and optionally increase the Cloud Function resources.

#### 11. Deploy the **Redact** Google Cloud Function

In the cloned repo, go to the `srf-redaction-func` directory and deploy the following Cloud Function.

> **⚠ NOTE**: Before deploying the redact function, on line 19 of the `index.js` file, add your **Redacted Audio Files** bucket name.
> **⚠ NOTE**: the trigger location must be the same as the DLP Findings bucket.

``` shell
gcloud functions deploy srfRedactionFunc \
    --region=<REGION> \
    --stage-bucket=[STAGE_BUCKET_NAME] \
    --runtime=nodejs20 \
    --trigger-bucket=[YOUR_DLP_BUCKET_BUCKET_NAME] \
    --trigger-location=[DLP_FINDINGS_BUCKET_LOCATION] \
    --ingress-settings=internal-only
```

> **⚠ NOTE**: For large audio files, it is recommend to change the Cloud Function memory allocation.

#### 12. Deploy the Cloud Dataflow Job

In the cloned repo, go to `srf-longrun-job-dataflow` directory and deploy the Cloud Dataflow Job. Run the commands below to deploy the dataflow job:
``` shell
# MacOS/Linux
# python3 --version Python 3.7.8

python3 -m venv env
source env/bin/activate
pip3 install apache-beam[gcp]
```

Please wait as it might take a few minutes to complete.

You can provide an existing [INSPECT_TEMPLATE_ID] if you already have an DLP Inspection template created or refer to section [Optional: DLP inspection template creation](#dlp-inspection-template-creation) to create a new one.

``` shell
python3 srflongrunjobdataflow.py \
    --project=[YOUR_PROJECT_ID] \
    --input_topic=projects/[YOUR_PROJECT_ID]/topics/[YOUR_TOPIC_NAME] \
    --runner=DataflowRunner \
    --temp_location=gs://[YOUR_DATAFLOW_STAGING_BUCKET]/tmp \
    --output=gs://[YOUR_DLP_FINDINGS_BUCKET] \
    --region=[GOOGLE_CLOUD_REGION] \
    --requirements_file="requirements.txt" \
    --inspect_template=[DLP_TEMPLATE_ID] \
    --subnetwork=https://www.googleapis.com/compute/v1/projects/[PROJECT_ID]/regions/[REGION]/subnetworks/[SUBNET_NAME] 
```

Once the steps are completed above, upload your audio files to the **Uploaded Audio Files** storage bucket. Once the file is processed you will find the DLP findings in the **DLP Findings** storage bucket and the redacted audio files in the **Redacted Audio Files** storage bucket.

## DLP inspection template creation

To create a DLP Inspection template, you can utilize the `create_template.py` Python script.

Before running the script, modify `inspect_template_congig.json` file to specify [built-in infoTypes](https://cloud.google.com/sensitive-data-protection/docs/infotypes-reference) and [custom infoTypes](https://cloud.google.com/sensitive-data-protection/docs/creating-custom-infotypes-dictionary) accordingly to your business needs. 

#### Run the script with the following command:

In the cloned repo, go to `dlp_templates` directory

```shell
pip install google-cloud-dlp
python3 create_template.py --project_id=[PROJECT_ID] --config=inspect_template_config.json 
```

This command will output the template ID that you will need to pass as part of the parameters to configure the dataflow job.

**This is not an officially supported Google product**
