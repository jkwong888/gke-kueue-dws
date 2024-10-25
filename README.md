# Use Kueue and ProvisioningRequest integration to request GPUs via DWS

Create a GCP project and GKE cluster using the terraform in the [terraform](./terraform) directory

Note the following differences when creating nodepool:
- added queued provisioning to the nodepool resoruce
- added a taint to allow only pods with `kueue` tolerations
- set the nodepool to consume no reservations and disable autorepair following the [docs](https://cloud.google.com/kubernetes-engine/docs/how-to/provisioningrequest#node-pools)

Install Kueue following directions in the [kueue](./kueue) directory

```
VERSION=v0.8.1
kubectl apply --server-side -f https://github.com/kubernetes-sigs/kueue/releases/download/$VERSION/manifests.yaml
```

Install the base resources in the [kueue-resources](./kueue-resources) directory:
- create an admissioncheck integration with DWS
- create a `default` ClusterQueue (scale up a non-gpu nodepool based on pending pods in a queue)
- create an A100 80GB LocalQueue (scale up a gpu nodepool using DWS based on pending pods)

Note that the node selectors match the nodepool names in the Resource Flavors .. you might want to do this if you want to have different workloads run on different nodepools.

You can try my sample workloads:
- [kueue-workload-jobs](./kueue-workload-jobs/) runs kubernetes batch/jobs api on nodes provisioned by DWS
- [kueue-knative](./kueue-knative) use kueue to request resources through DWS for inference
- [kueue-ray](./kueue-ray) for kuberay worker nodes requested through kueue


The Kueue / DWS integration roughly works like this, if you need to debug it:

`pod` > `workload` > `provisioningrequest` > resize request in GCE > node

By using "Optimize Utilization" cluster autoscaler mode in GKE, we can aggressively reap nodes when node utilization goes low, which allows us to scale GPU nodes to zero when there's nothing to do (batch workloads), or to a minimum (inference workloads).
