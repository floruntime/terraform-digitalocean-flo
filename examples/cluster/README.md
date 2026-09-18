# Example: 3-node Flo cluster

Provisions three droplets in the same region. Node 1 starts the cluster
and leads alone until nodes 2 and 3 join it at its peer port; a reserved
IP per node keeps that address stable from the first apply.

```bash
export TF_VAR_do_token=...
export TF_VAR_ssh_key_name=my-key
terraform init
terraform apply
terraform output endpoints
```

After apply, point your CLI at any node:

```bash
flo -e "$(terraform output -json endpoints | jq -r '."1".listen')" \
  kv set cluster ok
```
