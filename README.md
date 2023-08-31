# kind-kong
**K**ubernetes**inD**ocker with Kong

Detailed information on KinD can be found [here](https://kind.sigs.k8s.io/).

Detailed information on Kong in KinD can be found [here](https://docs.konghq.com/gateway/3.4.x/install/kubernetes/helm-quickstart/#kind-kubernetes).

## What has been installed in the Dockerfile
KinD 0.20.0<br>
kubectl 1.27.1<br>
Helm 3.12.2<br>
Terraform 1.5.5<br>
deck 1.25.0<br>
yq 4.35.1<br>
curl<br>
bash<br>
jq<br>
httpie<br>
gettext<br>
coreutils<br>
vim

## Build it
```bash
docker build --no-cache -t kind-kong .
```

## Run it
```bash
docker run --privileged -d -p 80:80 -p 443:443 --name kind-kong kind-kong:latest
```

## Exec into it
```bash
docker exec -it kind-kong bash
```

## Provision KinD and Kong
```bash
./start.sh
```

This will take a minute or two. Wait until all pods are up and migrations have completed before playing around with Kong.

By default, the kind cluster is named `kind`.

> **Note**
> If you're actively watching the pods, you may notice one or two may go into `CrashLoopBackOff`. Don' worry about it, it'll fix itself.

### Admin API
The admin api is accessible within the container.

Using `httpie`, run:
```bash
http --verify=no https://kong.127-0-0-1.nip.io/api/services
```

Using `curl`:
```bash
curl -k https://kong.127-0-0-1.nip.io/api/services | jq
```

### Kong manager
The Kong manager can be accessible outside the container. In your browser, navigate to `https://kong.127-0-0-1.nip.io/`.

"You will receive a 'Your Connection is not Private' warning message due to using selfsigned certs. If you are using Chrome there may not be an “Accept risk and continue” option, to continue type `thisisunsafe` while the tab is in focus to continue."

## Provision sample service, routes, etc
> **Note**
> Because `deck` is hitting Kong locally and selfsigned certs are in use, additional flags have to be passed to it. To make things easier, an alias has been created pointing `deck` to `deck --kong-addr https://kong.127-0-0-1.nip.io/api --tls-skip-verify`.

First, in the container, you need to `dump` the existing Kong config.
> **Warning**
> Trying to sync without first dumping will result in a **_bunch_** of stuff getting deleted. You'll have to start over from the beginning if this happens.

```bash
deck dump -o dump.yml
```

Get the sample flights spec from Kong:
```bash
wget https://github.com/Kong/KongAir/blob/main/flight-data/flights/openapi.yaml
```

Convert `openapi.yaml` to Kong's config:
```bash
deck file openapi2kong -s penapi.yaml -o flights.yml
```

Add tags:
```bash
deck file add-tags -s flights.yml "flights-service" -o flights.yml 
```

Merge it:
```bash
deck file merge dump.yml flights.yml -o all.yml
```

Sync it:
```bash
deck sync -s all.yml
```

In the container, hit the `flights` endpoint.
```bash
http --verify=no :/flights
# or
curl -s localhost/flights | jq
```

Outside the container, in your browser, navigate to `http://localhost/flights`.

## Tear down
Inside the container, simply run:
```bash
./delete.sh # or kind delete cluster

exit # to get out of the container
```

Outside the container, run:
```bash
docker stop kind-kong

docker rm kind-kong

docker volume rm $(docker volume ls -qf "dangling=true")
```