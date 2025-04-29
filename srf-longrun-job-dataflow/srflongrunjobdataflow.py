# Copyright 2021 Google LLC.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# [START SRF pubsub_to_cloud_storage]
import argparse
import logging
import json
import time
import apache_beam as beam
import google.cloud.dlp
import uuid

from apache_beam.io import filesystems
from apache_beam.options.pipeline_options import PipelineOptions
from apache_beam.options.pipeline_options import SetupOptions
from apache_beam.options.pipeline_options import StandardOptions
from apache_beam.options.pipeline_options import GoogleCloudOptions
from google.cloud.dlp import DlpServiceClient

class WriteToSeparateFiles(beam.DoFn):
    def __init__(self, outdir):
        self.outdir = outdir
    def process(self, element):
        x = uuid.uuid4()
        record = json.loads(element)
        file_name = record['filename'].split("/")
        writer = filesystems.FileSystems.create(self.outdir + file_name[-1] + "_" + str(x)[:8] + ".json")
        writer.write(json.dumps(record).encode("utf8"))
        writer.close()

# function to get STT data from long audio file using asynchronous speech recognition
def stt_output_response(data):
    from oauth2client.client import GoogleCredentials
    from googleapiclient import discovery
    credentials = GoogleCredentials.get_application_default()
    pub_sub_data = json.loads(data)
    speech_service = discovery.build('speech', 'v1p1beta1', credentials=credentials)
    get_operation = speech_service.operations().get(name=pub_sub_data['sttnameid'])
    response = get_operation.execute()

    # handle polling of STT
    if pub_sub_data['duration'] != 'NA':
        sleep_duration = round(int(float(pub_sub_data['duration'])) / 2)
    else:
        sleep_duration = 5
    logging.info('Sleeping for: %s', sleep_duration)
    time.sleep(sleep_duration)

    retry_count = 10
    while retry_count > 0 and not response.get('done', False):
        retry_count -= 1
        time.sleep(120)
        response = get_operation.execute()

    # return response to include STT data and agent search word
    response_list = [response, 
                     pub_sub_data['filename']
                    ]

    return response_list

# function to get enrich stt_output function response
def stt_parse_response(stt_data):

    parse_stt_output_response = {
        'filename': stt_data[1],
        'transcript': None,
        'words': [],
        'dlp': [],
    }
    string_transcript = ''

    # get transcript from stt_data
    for i in stt_data[0]['response']['results']:
        if 'transcript' in i['alternatives'][0]:
            string_transcript += str(i['alternatives'][0]['transcript']) + ' '
    parse_stt_output_response['transcript'] = string_transcript[:-1]  # remove the ending whitespace

    for element in stt_data[0]['response']['results']:     
        for word in element['alternatives'][0]['words']:
            parse_stt_output_response['words'].append(
                {'word': word['word'], 'startsecs': word['startTime'].strip('s'),
                    'endsecs': word['endTime'].strip('s')})

    return parse_stt_output_response

def destination(element):
    return json.loads(element)["filename"]

# function to redact sensitive data from audio file
def redact_text(data, project, template_id):
    #logging.info(data)
    dlp = google.cloud.dlp_v2.DlpServiceClient()
    parent = dlp.common_project_path(project)
    request = google.cloud.dlp_v2.ListInfoTypesRequest()
    response = dlp.list_info_types(request=request)
    inspect_template_name = f"{parent}/inspectTemplates/{template_id}"
    #logging.info(data['transcript'])
    item = {"value": data['transcript']}

    request = google.cloud.dlp_v2.InspectContentRequest(
            parent=parent,
            inspect_template_name=inspect_template_name,
            item=item,)
    response = dlp.inspect_content(request=request)
    #logging.info(response)
    if response.result.findings:
        for finding in response.result.findings:
            try:
                if finding.quote:
                    #logging.info("Quote: {}".format(finding.quote))
                    data['dlp'].append(finding.quote)
            except AttributeError:
                pass
        else:
            logging.info("No findings.")
    return data

def run(argv=None, save_main_session=True):
    """Build and run the pipeline."""
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument(
        '--input_topic',
        help=('Input PubSub topic of the form '
              '"projects/<PROJECT>/topics/<TOPIC>".'))
    group.add_argument(
        '--input_subscription',
        help=('Input PubSub subscription of the form '
              '"projects/<PROJECT>/subscriptions/<SUBSCRIPTION>."'))
    parser.add_argument('--inspect_template', required=True,
        help='Input ID for dlp inspect template'
              '"ID TEMPLATE"')
    parser.add_argument('--output', required=True,
                        help='Output BQ table to write results to '
                             '"PROJECT_ID:DATASET.TABLE"')
    known_args, pipeline_args = parser.parse_known_args(argv)

    pipeline_options = PipelineOptions(pipeline_args)
    project_id = pipeline_options.view_as(GoogleCloudOptions).project

    pipeline_options.view_as(SetupOptions).save_main_session = save_main_session
    pipeline_options.view_as(StandardOptions).streaming = True
    
    p = beam.Pipeline(options=pipeline_options)
    
    # Read from PubSub into a PCollection.
    if known_args.input_subscription:
        messages = (p
                    | beam.io.ReadFromPubSub(
                    subscription=known_args.input_subscription)
                    .with_output_types(bytes))
    else:
        messages = (p
                    | beam.io.ReadFromPubSub(topic=known_args.input_topic)
                    .with_output_types(bytes))

    decode_messages = messages | 'DecodePubSubMessages' >> beam.Map(lambda x: x.decode('utf-8'))

    # Get STT data from function for long audio file using asynchronous speech recognition
    stt_output = decode_messages | 'SpeechToTextOutput' >> beam.Map(stt_output_response)

    # Parse and enrich stt_output response
    parse_stt_output = stt_output | 'ParseSpeechToText' >> beam.Map(stt_parse_response)

    # Google Cloud DLP redaction for all info types
    dlp_output = parse_stt_output | 'FindDLP' >> beam.Map(lambda j: redact_text(j, project_id, template_id=known_args.inspect_template))

    # Convert to JSON
    json_output = dlp_output | 'JSONDumps' >> beam.Map(json.dumps)

    # Write findings to Cloud Storage
    json_output | 'WriteFindings' >> beam.ParDo(WriteToSeparateFiles(known_args.output + '/'))

    p.run()

if __name__ == '__main__':
    logging.getLogger().setLevel(logging.DEBUG)
    run()

# [END SRF pubsub_to_cloud_storage]