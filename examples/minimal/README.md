# Example: minimal Flo node

Single droplet, public dashboard, public wire port.

```bash
export TF_VAR_do_token=...
export TF_VAR_ssh_key_name=my-key
terraform init
terraform apply
flo --server "$(terraform output -raw listen_endpoint)" kv set hello world
```
