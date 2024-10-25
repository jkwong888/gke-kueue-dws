# use DWS and kueue with kuberay

we can use kuberay to create a cluster running Ray on GKE, and create dynamic GPU worker nodes backed by Dynamic Workload Scheduler.

## install kuberay using the kuberay operator via helm chart

```
helm repo add kuberay https://ray-project.github.io/kuberay-helm/

kubectl create namespace kuberay-operator-system

# Install both CRDs and KubeRay operator
helm install kuberay-operator kuberay/kuberay-operator -n kuberay-operator-system
```

since we added the operator to kuberay-operator-system, the cluster role binding for the operator needs to be set on the right namespace

```
kubectl edit clusterrolebinding kuberay-operator
```

-- change the user namespace to `kuberay-operator-system`

## create raycluster using the attached CR

```
kubectl apply -f raycluster.yaml
```

this creates a ray headnode (with 0 resources), a cpu workergroup, and a gpu workergroup backed by a2-highgpu-1g nodegroup that we request via DWS. the head node is served through an internal load balancer.

You can access the dashboard by forwarding port 8265 to yourself and then connecting to `localhost:8265`.

```
kubectl port-forward service/raycluster-complete-head-svc 8265:8265
```

you can use code similar to the below to connect, connecting to the dashboard port on the internal load balancer's IP.  When running a remote ray job, it will spin up a worker node to execute it after installing pytorch.  Via DWS, this may take a little bit longer for the system to call the provisioningrequest. you can take a look at the dashboard to view the task execution state and the cluster state.

```
from ray.runtime_env import RuntimeEnv

runtime_env = RuntimeEnv(
  pip=["torch"],
)

# Initialize connection to the Ray cluster using the internal load balancer.
ray.init(
    address="ray://10.30.0.223:10001",
    runtime_env=runtime_env
)
```

you can run a function on a gpu node using code like this, which will print out if cuda is available on the remote worker node (after it is spun up):

```
@ray.remote(num_returns=1, runtime_env=runtime_env, num_gpus=1)
def hello_world():
  import socket
  import torch

  return_val = f"Hello, World! I am {socket.gethostname()}"
  device = (
    "cuda"
    if torch.cuda.is_available()
    else "mps"
    if torch.backends.mps.is_available()
    else "cpu"
  )
  return_val += f" Using {device} device"

  return return_val



obj_ref = hello_world.remote()
pprint(ray.get(obj_ref))
```