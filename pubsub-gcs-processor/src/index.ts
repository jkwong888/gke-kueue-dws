import {PubSub, Message} from '@google-cloud/pubsub';
import {Storage} from '@google-cloud/storage';
import * as k8s from '@kubernetes/client-node';
import {GoogleAuth} from 'google-auth-library';
import {handleHandlerUrl} from './http';
import {handleVllmApi, initVllm} from './vllm';

async function main() {
  const auth = new GoogleAuth();
  const pubSubClient = new PubSub();
  const storage = new Storage();

  const kc = new k8s.KubeConfig();
  kc.loadFromDefault();
  const coreV1Api = kc.makeApiClient(k8s.CoreV1Api);

  await initVllm(coreV1Api);

  const projectId = process.env.PROJECT_ID || (await auth.getProjectId());
  const subscriptionName = process.env.SUBSCRIPTION_NAME;
  if (!subscriptionName) {
    console.error('SUBSCRIPTION_NAME environment variable is not set.');
    process.exit(1);
  }

  const vllmApiUrl = process.env.VLLM_API_URL;
  const handlerUrl = process.env.HANDLER_URL;

  if (!vllmApiUrl && !handlerUrl) {
    console.error(
      'HANDLER_URL or VLLM_API_URL must be set.'
    );
    process.exit(1);
  }

  const subscriptionId =
    'projects/' + projectId + '/subscriptions/' + subscriptionName;

  const maxMessages = process.env.MAX_MESSAGES
    ? parseInt(process.env.MAX_MESSAGES, 10)
    : 1;

  const subscription = pubSubClient.subscription(subscriptionId, {
    flowControl: {
      maxMessages: maxMessages,
    },
  });

  console.log(
    `Listening for messages on ${subscriptionName} with max ${maxMessages} concurrent messages.`
  );

  subscription.on('message', async (message: Message) => {
    console.log(`Received message ${message.id}:`);
    try {
      const attributes = message.attributes;

      // Prioritize GCS notifications with VLLM processing
      if ((attributes.bucket || attributes.bucketId) && (attributes.name || attributes.objectId)) {
        await handleVllmApi(message, attributes, storage);
        return;
      }

      // Then, check for handler URL
      if (handlerUrl) {
        const handled = await handleHandlerUrl(message, attributes, handlerUrl);
        if (handled) {
          return;
        }
      }

    } catch (err) {
      console.error('Error processing message:', err);
      message.nack();
    }
  });

  subscription.on('error', error => {
    console.error('Received error:', error);
    process.exit(1);
  });
}

main().catch(console.error);
