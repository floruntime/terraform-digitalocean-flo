# Example: minimal Flo node

Single droplet with the module defaults: the firewall opens only SSH, and the
dashboard listens on loopback. Reach both over SSH.

```bash
export TF_VAR_do_token=...
export TF_VAR_ssh_key_name=my-key
terraform init
terraform apply
ssh root@$(terraform output -raw ipv4_address) flo kv set hello world

# Dashboard at http://127.0.0.1:9002 while this runs
$(terraform output -raw dashboard_ssh_tunnel)
```

To reach the wire port directly, set `api_allowed_cidrs` to the ranges your
clients connect from.
