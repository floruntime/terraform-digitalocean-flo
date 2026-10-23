# Example: 3-node Flo cluster

Provisions three droplets in one region and one VPC. Node 1 starts the
cluster and leads alone until nodes 2 and 3 join it at its peer port, over
its private address; the peer port accepts only the VPC. A reserved IP per
node gives clients a stable public address. The wire port and the dashboard
open only to `operator_cidrs`.

```bash
export TF_VAR_do_token=...
export TF_VAR_ssh_key_name=my-key
export TF_VAR_operator_cidrs='["203.0.113.0/24"]'  # where your clients connect from
export TF_VAR_cluster_secret="$(flo server secret)"
terraform init
terraform apply
terraform output endpoints
```

After apply, point your CLI at any node:

```bash
flo -e "$(terraform output -json endpoints | jq -r '."1".listen')" \
  kv set cluster ok
```
