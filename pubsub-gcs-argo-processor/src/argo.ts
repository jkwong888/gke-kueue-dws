import * as k8s from '@kubernetes/client-node';
import * as yaml from 'js-yaml';
import { Message } from '@google-cloud/pubsub';

const kc = new k8s.KubeConfig();
kc.loadFromDefault();

const customObjectsApi = kc.makeApiClient(k8s.CustomObjectsApi);
const coreV1Api = kc.makeApiClient(k8s.CoreV1Api);

const argoNamespace = process.env.ARGO_WORKFLOW_NAMESPACE || 'workflows';
const workflowConfigMapName =
  process.env.WORKFLOW_CONFIGMAP_NAME || 'workflow-template';
const workflowConfigMapKey = process.env.WORKFLOW_CONFIGMAP_KEY || 'template';

async function getWorkflowTemplateFromConfigMap(): Promise<any> {
  try {
    const res = await coreV1Api.readNamespacedConfigMap(
      workflowConfigMapName,
      argoNamespace
    );
    const template = res.body.data?.[workflowConfigMapKey];
    if (!template) {
      throw new Error(
        `ConfigMap '${workflowConfigMapName}' does not contain key '${workflowConfigMapKey}'`
      );
    }
    return yaml.load(template);
  } catch (err) {
    console.error('Error reading or parsing ConfigMap:', err);
    throw err;
  }
}

async function findWorkflowByMessageId(messageId: string): Promise<k8s.KubernetesObject | undefined> {
  try {
    const labelSelector = `messageId=${messageId}`;
    const res = await customObjectsApi.listNamespacedCustomObject(
      'argoproj.io',
      'v1alpha1',
      argoNamespace,
      'workflows',
      undefined,
      undefined,
      undefined,
      labelSelector
    );
    const workflows = (res.body as any).items;
    if (workflows && workflows.length > 0) {
      console.log(`Found existing workflow for message ${messageId}`);
      return workflows[0];
    }
    return undefined;
  } catch (err) {
    console.error(`Error finding workflow for message ${messageId}:`, err);
    return undefined;
  }
}

export async function createArgoWorkflow(
  messageData: string,
  attributes: {[key: string]: string},
  messageId: string,
): Promise<k8s.KubernetesObject> {
  // Check if a workflow for this message already exists
  const existingWorkflow = await findWorkflowByMessageId(messageId);
  if (existingWorkflow) {
    return existingWorkflow;
  }

  try {
    const workflowTemplate = await getWorkflowTemplateFromConfigMap();
    const workflow = JSON.parse(JSON.stringify(workflowTemplate));

    if (!workflow.metadata) {
      workflow.metadata = {};
    }

    // Add attributes as labels
    if (!workflow.metadata.labels) {
      workflow.metadata.labels = {};
    }
    for (const key in attributes) {
      workflow.metadata.labels[key] = attributes[key];
    }
    // Add messageId as a label
    workflow.metadata.labels['messageId'] = messageId;

    const timestamp = Date.now();

    if (workflow.metadata.name) {
        // if name is present, use it as a prefix for generateName
        workflow.metadata.generateName = `${workflow.metadata.name}-${timestamp}-`;
        delete workflow.metadata.name;
    } else if (workflow.metadata.generateName) {
        workflow.metadata.generateName = `${workflow.metadata.generateName}${timestamp}-`;
    } else {
      workflow.metadata.generateName = `pubsub-workflow-${timestamp}-`;
    }

    // Customize the workflow based on the message
    // For example, pass the message data as an argument to the workflow
    if (workflow.spec.templates[0].container) {
      workflow.spec.templates[0].container.args = [messageData];
    }

    const response = await customObjectsApi.createNamespacedCustomObject(
      'argoproj.io',
      'v1alpha1',
      argoNamespace,
      'workflows',
      workflow
    );
    console.log(`Created Argo workflow for message.`);
    return response.body as k8s.KubernetesObject;
  } catch (err) {
    console.error('Error creating Argo workflow:', err);
    throw err;
  }
}

export async function watchWorkflow(name: string, namespace: string): Promise<string> {
  const watch = new k8s.Watch(kc);

  const path = `/apis/argoproj.io/v1alpha1/namespaces/${namespace}/workflows`;
  const fieldSelector = `metadata.name=${name}`;

  return new Promise<string>((resolve, reject) => {
    const req: any = watch.watch(
      path,
      { fieldSelector },
      (type, apiObj) => {
        if (type === 'MODIFIED') {
          const status = apiObj.status?.phase;
          console.log(`Workflow ${name} status: ${status}`);
          if (status === 'Succeeded' || status === 'Failed' || status === 'Error') {
            req.abort();
            resolve(status);
          }
        }
      },
      (err) => {
        if (err) {
          console.error(`Error watching workflow ${name}:`, err);
          reject(err);
        } else {
          console.log(`Watch for workflow ${name} ended.`);
          reject(new Error('Watch ended without a final status.'));
        }
      }
    );
    console.log(`Watching workflow ${name} in namespace ${namespace}`);
  });
}

export async function handleArgoWorkflow(
  message: Message,
  attributes: {[key: string]: string},
  argoWorkflowNamespace: string
) {
  const messageId = message.id;
  const messageData = message.data.toString();
  console.log(`	Data: ${messageData}`);
  console.log(`	Attributes: ${JSON.stringify(attributes)}`);
  const workflow = (await createArgoWorkflow(
    messageData,
    attributes,
    messageId
  )) as k8s.KubernetesObject;
  if (workflow.metadata?.name) {
    const workflowName = workflow.metadata.name;
    const workflowNamespace =
      workflow.metadata.namespace || argoWorkflowNamespace;

    // Extend the ack deadline periodically
    const interval = setInterval(() => {
      console.log(`Extending ack deadline for message ${message.id}`);
      message.modAck(60); // Extend by 60 seconds
    }, 30000); // Every 30 seconds

    try {
      const status = await watchWorkflow(workflowName, workflowNamespace);
      if (status === 'Succeeded') {
        console.log(`Workflow ${workflowName} succeeded. Acking message.`);
        message.ack();
      } else {
        console.log(
          `Workflow ${workflowName} failed with status: ${status}. Nacking message.`
        );
        message.nack();
      }
    } finally {
      clearInterval(interval);
    }
  } else {
    throw new Error('Created workflow has no name.');
  }
}