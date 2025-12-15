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

from google.cloud import dlp_v2
from google.cloud.dlp_v2 import types
import json
from google.oauth2 import service_account
from collections import OrderedDict
import sys
import argparse

def create_inspect_template (dlp_client, project_id , inspect_name, inspect_config_temp, inspect_description):
    try:
        parent= f"projects/{project_id}"
        inspect_template= types.InspectTemplate(
            inspect_config=inspect_config_temp,
            display_name=f"{inspect_name}",
            description=f"{inspect_description}",            
        )
        response = dlp_client.create_inspect_template(parent=parent, inspect_template=inspect_template)
        print(f"Inspect teplate {response.name} created sucessfully")
    except Exception as e:
        print(f"Failed to create inspect template: {e}")

def create_deidentify_template (dlp_client, project_id, deidentify_name, deidentify_config_temp, deidentify_description):
    try:
        parent = f"projects/{project_id}"
        deidentify_template = types.DeidentifyTemplate(
            deidentify_config = deidentify_config_temp,
            display_name = f"{deidentify_name}",
            description= f"{deidentify_description}"
        )
        response =dlp_client.create_deidentify_template(parent=parent, deidentify_template=deidentify_template)
        print(response.name
              )
    except Exception as e:
        print(f"Failed to load JSON file: {e}")
        return None
    
def load_json(file_path):
    try:
        with open(file_path, 'r') as file:
            return json.load(file)
    except Exception as e:
        print(f"Failed to load JSON file: {e}")
        return None

if __name__ == "__main__":
    # 1. Initialize Parser
    parser = argparse.ArgumentParser(description="Create Google Cloud DLP templates using JSON configurations.")

    # 2. Define Flags
    parser.add_argument("--project_id", required=True, help="The Google Cloud Project ID")
    parser.add_argument("--config", required=True, help="Path to the inspect_config JSON file")

    # 3. Parse Arguments
    args = parser.parse_args()

    dlp_client = dlp_v2.DlpServiceClient()

    inspect_json = load_json(args.config)
    
    if inspect_json:
        inspect_template = inspect_json.get("inspect_template")
        inspect_config_temp = inspect_template.get("inspect_config")
        inspect_config_temp["include_quote"] = True   
        inspect_name = inspect_template.get("display_name")
        inspect_description = inspect_template.get("description")

        create_inspect_template(
            dlp_client, 
            args.project_id, 
            inspect_name, 
            inspect_config_temp, 
            inspect_description
        )