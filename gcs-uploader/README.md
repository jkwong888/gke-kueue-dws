# GCS Uploader

This script uploads a new file to the GCS bucket `jkwng-data` at random intervals between 10 and 60 seconds.

## Prerequisites

- Google Cloud SDK (`gcloud`) must be installed and authenticated.
- You must have permissions to write to the `jkwng-data` GCS bucket.

## Usage

To start the uploader, run the following command:

```bash
./upload.sh
```
