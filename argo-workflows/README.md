# Using queued provisioning to search for GPUs as part of argo workflows

Due to provision a node via DWS using `ProvisioningRequest` before executing a workflow job on it - note that all steps in the workflow can use the same queued provisioning request by setting the annotation. This lets us avoid using kueue (which provisions one node for every task in the workflow)

## install argo workflows


```
ARGO_WORKFLOWS_VERSION="v3.6.5"
kubectl create namespace argo
kubectl apply -n argo -f "https://github.com/argoproj/argo-workflows/releases/download/${ARGO_WORKFLOWS_VERSION}/quick-start-postgres.yaml"
```

## add the service account and roles for the executor

```
kubectl apply -f serviceaccount-executor.yaml role-executor.yaml rolebinding-executor.yaml
```

## create the workflow

```
kubectl create -f workflow-helloworld-qp.yaml
```


## custom compute classes

We can also have the workflow target a specific compute class - for example here we target the `training-nodes` compute class which is implemented by two spot nodepools.

```
kubectl create -f workflow-helloworld-cc.yaml
```

## workflow executor permissions

make sure workflows run as `workflow-executor` in the `workflows` namespace - this will have permission to create the `WorkflowTaskResults` CR steps during the workflow execution.