import OpenAI from 'openai';
import { Message } from '@google-cloud/pubsub';
import { Storage } from '@google-cloud/storage';
import * as k8s from '@kubernetes/client-node';

const vllmApiUrl = process.env.VLLM_API_URL || undefined;

let promptTemplate: string | undefined;
let openai: OpenAI | undefined;
let model: string;

export async function initVllm(coreV1Api: k8s.CoreV1Api) {
  const promptTemplateEnv = process.env.PROMPT_TEMPLATE;
  if (promptTemplateEnv) {
    const [namespace, name] = promptTemplateEnv.split('/');
    try {
      const configMap = await coreV1Api.readNamespacedConfigMap(name, namespace);
      promptTemplate = configMap.body.data?.['template'];
      if (promptTemplate) {
        console.log(`Successfully loaded prompt template from ${promptTemplateEnv}`);
      } else {
        console.log(
          `ConfigMap ${name} in namespace ${namespace} does not have a 'template' key.`
        );
      }
    } catch (err) {
      console.error(`Error loading prompt template from ${promptTemplateEnv}:`, err);
    }
  }

  if (vllmApiUrl ) {
    let model_env = process.env.MODEL_ID; // Default model
    openai = new OpenAI({
      baseURL: vllmApiUrl,
      apiKey: '-', // Required but not used by vLLM
    });

    if (model_env) {
      model = model_env;
    } else {
      // model discovery
      const models = await openai.models.list();
      if (models.data.length === 1) {
        model = models.data[0].id;
      } else if (models.data.length > 1) {
        console.log('Multiple models available, using the first one.');
        model = models.data[0].id;
      }
    }
  }

  console.log(`Using model ${model}`);
}

export async function callVllmApi(prompt: string): Promise<string> {
  if (!openai) {
    throw new Error('openai is not initialized');
  }

  const chatCompletion = await openai.chat.completions.create({
    model: model,
    messages: [{role: 'user', content: prompt}],
  });

  return JSON.stringify(chatCompletion.choices);
}

export async function handleVllmApi(
  message: Message,
  attributes: {[key: string]: string},
  storage: Storage
) {

  const bucketName = attributes.bucket || attributes.bucketId;
  const fileName = attributes.name || attributes.objectId;

  if (!bucketName || !fileName) {
    return;
  }


  const file = storage.bucket(bucketName).file(fileName);
  const [metadata] = await file.getMetadata();
  const contentType = metadata.contentType;

  console.log(
    `Processing file gs://${bucketName}/${fileName} mimetype ${contentType} ...`
  );

  if (contentType !== 'text/plain' && contentType !== 'application/json') {
    console.log(
      `Skipping file ${fileName} with unsupported content type: ${contentType}`
    );
    message.ack();
    return;
  }

  const fileContents = await file.download();

  let prompt = fileContents.toString();
  if (promptTemplate) {
    prompt = promptTemplate.replace('{content}', fileContents.toString());
    console.log(`Rendered prompt: ${prompt}`);
  }

  if (vllmApiUrl) {
    const vllmResponse = await callVllmApi(prompt);
    console.log(`VLLM API response: ${vllmResponse}`);
  } else {
    console.log(`Prompt: ${prompt}`);
  }

  message.ack();
  console.log(`Acked message ${message.id} after processing GCS file.`);
}