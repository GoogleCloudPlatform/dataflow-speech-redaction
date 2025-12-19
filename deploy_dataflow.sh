#!/bin/bash
set -e  # Exit immediately if any command fails

# Optional: Print commands for debugging
# set -x 

echo "--- Setting up Virtual Environment ---"
# Only create venv if it doesn't exist
cd ./srf-longrun-job-dataflow
if [ ! -d "env" ]; then
  python3 -m venv env
fi

source env/bin/activate

echo "--- Installing Dependencies ---"
pip install apache-beam[gcp] --no-cache-dir --quiet

# Check if requirements.txt exists before trying to install it
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt --quiet
fi

echo "--- Launching Dataflow Job ---"
# "$@" takes all arguments passed to this shell script 
# and passes them directly to the Python script.
python3 srflongrunjobdataflow.py "$@"
