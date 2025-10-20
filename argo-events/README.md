# create argo workflows resulting from pubsub notifications

GCS upload > pubsub > argo-events > argo workflows

# Install argo workflows

see [../argo-workflows/README.md](../argo-workflows/README.md)

# Install argo-events

install the controller and webhook:

```
kubectl create namespace argo-events
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install.yaml
# Install with a validating admission controller
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install-validating-webhook.yaml
```

# create eventbus

eventbus is like a small NATS cluster that runs inside of your cluster that argo events consumes messages from (it doesn't read directly from pubsub)

```
kubectl apply -n argo-events -f https://raw.githubusercontent.com/argoproj/argo-events/stable/examples/eventbus/native.yaml
```

# create EventSource

create an eventsource that reads from GCP PubSub, converts the events to a CloudEvents type, and publishes it on the EventBus.

```
kubectl apply -n argo-events pubsub-eventsource.yaml
```

# create service account and role binding - this allows the sensor to create Argo Workflows in the `workflows` namespace

```
kubectl apply -n argo-events serviceaccount.yaml role.yaml role-binding.yaml 
```

# create the sensor - this monitors the EventBus for events and creates argo workflows

```
kubectl apply -n argo-events pubsub-sensor-workflow.yaml
```