import http from 'http';
import https from 'https';
import { Message } from '@google-cloud/pubsub';

export function getRegionFromMetadata(): Promise<string | undefined> {
  return new Promise(resolve => {
    const options = {
      hostname: 'metadata.google.internal',
      path: '/computeMetadata/v1/instance/zone',
      headers: {
        'Metadata-Flavor': 'Google',
      },
    };

    const req = http.get(options, res => {
      if (res.statusCode !== 200) {
        resolve(undefined);
        return;
      }
      let data = '';
      res.on('data', chunk => {
        data += chunk;
      });
      res.on('end', () => {
        // The response is in the format projects/PROJECT_NUMBER/zones/ZONE
        const parts = data.split('/');
        const zone = parts[parts.length - 1];
        // a zone is in the format of REGION-LETTER, so we can extract the region
        const region = zone.substring(0, zone.length - 2);
        resolve(region);
      });
    });

    req.on('error', () => {
      resolve(undefined);
    });

    req.end();
  });
}

export function postToHandler(handlerUrl: string, payload: any): Promise<void> {
  return new Promise((resolve, reject) => {
    const url = new URL(handlerUrl);
    const protocol = url.protocol === 'https:' ? https : http;

    const options = {
      method: 'POST',
      hostname: url.hostname,
      port: url.port,
      path: url.pathname,
      headers: {
        'Content-Type': 'application/json',
      },
      timeout: 5000, // 5-second timeout
    };

    const req = protocol.request(options, res => {
      let data = '';
      res.on('data', chunk => {
        data += chunk;
      });
      res.on('end', () => {
        if (res.statusCode && res.statusCode >= 200 && res.statusCode < 300) {
          console.log(`Successfully posted to handler: ${data}`);
          resolve();
        } else {
          console.error(
            `Failed to post to handler. Status: ${res.statusCode}, Body: ${data}`
          );
          reject(
            new Error(`Failed to post to handler. Status: ${res.statusCode}`)
          );
        }
      });
    });

    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Request to handler timed out.'));
    });

    req.on('error', e => {
      console.error(`Error posting to handler: ${e.message}`);
      reject(e);
    });

    req.write(JSON.stringify(payload));
    req.end();
  });
}

export async function handleHandlerUrl(message: Message, attributes: {[key: string]: string}, handlerUrl: string): Promise<boolean> {
  const eventTime = attributes.eventTime
    ? new Date(attributes.eventTime).getTime()
    : undefined;
  const bucketId = attributes.bucketId;
  const objectId = attributes.objectId;

  if (eventTime && bucketId && objectId) {
    const payload = {
      eventTime,
      bucketId,
      objectId,
    };
    await postToHandler(handlerUrl, payload);
    message.ack();
    console.log(`Acked message ${message.id} after posting to handler.`);
    return true; // Stop processing further
  } else {
    console.log(
      'Message does not have all required attributes (eventTime, bucketId, objectId) for handler post. Proceeding with Argo workflow.'
    );
    return false;
  }
}