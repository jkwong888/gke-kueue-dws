# Pub/Sub GCS Processor

This application listens for GCS object finalization messages on a Google Cloud Pub/Sub subscription and calls downstream APIs to process the objects.

## Prerequisites

*   Node.js (v18 or later)
*   `gcloud` CLI authenticated to your Google Cloud project.
*   `kubectl` configured to connect to your Kubernetes cluster with Argo Workflows installed.

## Installation

1.  Install the dependencies:

    ```bash
    npm install
    ```

## Configuration

This application is configured via environment variables. The following variables are available:

*   `PROJECT_ID`: The Google Cloud project ID.
*   `SUBSCRIPTION_NAME`: The name of your Pub/Sub subscription.
*   `MAX_MESSAGES`: The maximum number of messages to process concurrently.
*   `VLLM_API_URL`: The URL of the vLLM API - this can be local inside of kubernetes.
*   `PROMPT_TEMPLATE`: The prompt template to use with VLLM, format is `namespace`/`configmapname`, will look for the `template` key and replace the content in `{content}` with the contents of the object written to GCS.
*   `HANDLER_URL`: The URL of the an API handler to call.
*   `ARGO_WORKFLOW_NAMESPACE`: The Kubernetes namespace where your Argo workflows should be created.
*   `WORKFLOW_CONFIGMAP_NAME`: The name of the workflow configmap.
*   `WORKFLOW_CONFIGMAP_KEY`: The key of the workflow configmap (default template) - this will be a yaml file with the argo workflow to create.

## Running the application

1.  Compile the TypeScript code:

    ```bash
    npm run compile
    ```

2.  Run the application:

    ```bash
    node build/src/index.js
    ```


## GCP Permissions

The KSA will need `storage.objectReader` role on the bucket and `pubsub.subscriber` role on the subscription, check the `terraform` directory for example using workflow identity federation.

## Kubernetes

you can use the sample resources in the `deployment` directory as a guide