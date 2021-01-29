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

## How to install the Speech Analysis Framework

1. [Install the Google Cloud SDK](https://cloud.google.com/sdk/install)

2. Create a storage bucket for **Dataflow Staging Files**

``` shell
gsutil mb gs://[BUCKET_NAME]/
```

3. Through the [Google Cloud Console](https://console.cloud.google.com) create a folder named **tmp** in the newly created bucket for the DataFlow staging files

4. Create a storage bucket for **Uploaded Audio Files**

``` shell
gsutil mb gs://[BUCKET_NAME]/
```

5. Create a storage bucket for **DLP Findings**

``` shell
gsutil mb gs://[BUCKET_NAME]/
```

6. Create a storage bucket for **Redacted Audio Files**

``` shell
gsutil mb gs://[BUCKET_NAME]/
```

7. Create Cloud Pub/Sub Topic
``` shell
gcloud pubsub topics create [YOUR_TOPIC_NAME]
```

8. Enable Cloud Dataflow API
``` shell
gcloud services enable dataflow
```

9. Enable Cloud Speech-to-Text API
``` shell
gcloud services enable speech
```

10. Enable DLP
``` shell
gcloud services enable dlp.googleapis.com
```

11. Deploy the **Audio Process** Google Cloud Function
* In the cloned repo, go to the “srf-audio-process-func” directory and deploy the following Cloud Function.
``` shell
gcloud functions deploy srfAudioProcessFunc --region=us-central1 --stage-bucket=[YOUR_UPLOADED_AUDIO_FILES_BUCKET_NAME] --runtime=nodejs10 --trigger-event=google.storage.object.finalize --trigger-resource=[YOUR_UPLOADED_AUDIO_FILES_BUCKET_NAME]
```

> **⚠ NOTE**: On line 29, add your TOPIC_NAME you created in step 7.

> **⚠ NOTE**: If you run into any timeout issues with Cloud Functions, it is recommend to increase the timeout and optionally increase the Cloud Function resources.


12. Deploy the **Redact** Google Cloud Function
* In the cloned repo, go to the “srf-redaction-func” directory and deploy the following Cloud Function.
``` shell
gcloud functions deploy srfRedactionFunc --region=us-central1 --stage-bucket=[YOUR_UPLOADED_AUDIO_FILES_BUCKET_NAME] --runtime=nodejs10 --trigger-event=google.storage.object.finalize --trigger-resource=[YOUR_UPLOADED_AUDIO_FILES_BUCKET_NAME]
```

> **⚠ NOTE**: Before deploying the redact function, on line 19, add your **Redacted Audio Files** bucket name.

> **⚠ NOTE**: For large audio files, it is recommend to change the Cloud Function memory allocation.

13. Deploy the Cloud Dataflow Pipeline
* python3 --version Python 3.7.8
* In the cloned repo, go to “srf-longrun-job-dataflow” directory and deploy the Cloud Dataflow Pipeline. Run the commands below to deploy the dataflow job.
``` shell
# Apple/Linux
python3 -m venv env
source env/bin/activate
pip3 install apache-beam[gcp]
```

* Please wait as it might take a few minutes to complete.
``` shell
python3 srflongrunjobdataflow.py --project=[YOUR_PROJECT_ID] --input_topic=projects/[YOUR_PROJECT_ID]/topics/[YOUR_TOPIC_NAME] --runner=DataflowRunner --temp_location=gs://[YOUR_DATAFLOW_STAGING_BUCKET]/tmp --output=[YOUR_DLP_FINDINGS_BUCKET] --region=[GOOGLE_CLOUD_REGION] --requirements_file="requirements.txt"
```

> **⚠ NOTE**: On line 110 add the DLP InfoTypes you need to identity and redact.

Once the steps are completed above, upload your audio files to the **Uploaded Audio Files** storage bucket. Once the file is processed you will find the DLP findings in the **DLP Findings** storage bucket and the redacted audio files in the **Redacted Audio Files** storage bucket.


**This is not an officially supported Google product**
