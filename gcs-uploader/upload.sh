#!/bin/bash

set -e

BUCKET_NAME="jkwng-data"

while true; do
  SLEEP_INTERVAL=$(( (RANDOM % 50) + 10 ))
  echo "Sleeping for $SLEEP_INTERVAL seconds..."
  sleep $SLEEP_INTERVAL

  TIMESTAMP=$(date +%s)
  FILE_NAME="test-file-$TIMESTAMP.txt"
  echo "This is a test file generated at $TIMESTAMP" > "$FILE_NAME"

  echo "Uploading $FILE_NAME to gs://$BUCKET_NAME..."
  gcloud storage cp "$FILE_NAME" "gs://$BUCKET_NAME/"

  rm "$FILE_NAME"
done
