# Use Kueue with KNative to request GPUs from DWS for inference

KNative is a serving stack that runs on top of Kubernetes.  It supports scale-up based on requests.

1. install knative

   ```
   KNATIVE_VERSION=v1.19.6
   kubectl apply -f https://github.com/knative/serving/releases/download/knative-${KNATIVE_VERSION}/serving-crds.yaml
   kubectl apply -f https://github.com/knative/serving/releases/download/knative-${KNATIVE_VERSION}/serving-core.yaml
   ```


2. install kourier to use as ingress gateway

   ```
   KOURIER_VERSION=v1.19.5
   kubectl apply -f https://github.com/knative/net-kourier/releases/download/knative-${KOURIER_VERSION}/kourier.yaml
   ```

   configure KNative to use Kourier:

   ```
   kubectl patch configmap/config-network \
    --namespace knative-serving \
    --type merge \
    --patch '{"data":{"ingress-class":"kourier.ingress.networking.knative.dev"}}'
   ```

   note - by default, kourier will create an external load balancer, we don't necessarily need one, so you can convert the service to be a `ClusterIP` later if you don't need your service to be served through a load balancer.


3. in the Knative `config-features` configmap (in namespace `knative-serving`), add the following keys to enable node selectors and tolerations on knative services, as well as enable hostpath volumes to get to model data and nvidia drivers on the worker node:

   ```
   kubernetes.podspec-nodeselector: enabled
   kubernetes.podspec-tolerations: enabled
   kubernetes.podspec-volumes-hostpath: enabled
   ```

   ```bash
   kubectl patch configmap/config-features \
    --namespace knative-serving \
    --type merge \
    --patch '{"data":{"kubernetes.podspec-nodeselector":"enabled","kubernetes.podspec-tolerations":"enabled","kubernetes.podspec-volumes-hostpath":"enabled"}}'
   ```

4. in the Knative `config-deployment` configmap (in namespace `knative-serving`), add the following key `default-affinity-type=none` to remove knative
   default pod anti-affinity.  DWS ensures each pod will result in its own provisioning request.

   Also add the following key `progress-deadline=1200s` to extend the timeout waits for the initial revision to become available.  DWS may take awhile to provision the GPU node, so we allow up to 20 minutes for the deployment to make progress before knative fails the revision.

   ```
   kubectl patch configmap/config-deployment \
    --namespace knative-serving \
    --type merge \
    --patch '{"data":{"default-affinity-type":"none","progress-deadline":"1200s"}}'
   ```

The KNative `service` object creates a Kubernetes `deployment` object which scales up replicas based on the number of requests received by the gateway.


# Use compute class to target a set of nodepools

Use custom compute class to target a set of nodepools.  the first nodepool that provisions a node will have the pod scheduled.  For example we will have this service run on nodepools of class `inference-nodes`.

```
kubectl create llama3-knative-service-cc.yaml
```