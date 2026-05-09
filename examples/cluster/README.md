# Example: 3-node Flo cluster

Provisions three droplets in the same region, wired together via
reserved IPs (so the gossip seed list is stable from the first
apply).

```bash
export TF_VAR_do_token=...
export TF_VAR_ssh_key_name=my-key
terraform init
terraform apply
terraform output endpoints
```

After apply, point your CLI at any node:

```bash
flo --server "$(terraform output -json endpoints | jq -r '."1".listen')" \
  kv set cluster ok
```
