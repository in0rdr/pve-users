#!/usr/bin/env sh
#
# Delete a Proxmox VE user
# with the Proxmox VE Shell tool (`pvesh`)

# @TODO: sanity checks and input validation
USERNAME="${1}"
# node name, e.g., node01
NODE="${2}"

# pve or pam domain
DOMAIN=pve
# userid concatenates username and domain
USERID="${USERNAME}@${DOMAIN}"

# remove global lvm storage from the private resource pool
pvesh set "pools/${USERNAME}" --storage local-lvm --delete

# get a list of all remaining containers and vms in the private resource pool
# - find the members
# - remove formatting and only keep the json formatted memberlist
# - parse the json with python, extract member (container/vm) id
# - remove python list formatting for further processing in bash
resources=$(pvesh get "pools/${USERNAME}" \
 | grep members \
 | grep -o '\[.*\]' \
 | python3 -c "import sys, json; print([i['id'] for i in json.load(sys.stdin)])" \
 | tr -d "'[],")

# stop and delete all remaining resources in the private resource pool
for i in $resources; do
  echo "> Stopping ${i}"
  pvesh create "nodes/${NODE}/${i}/status/stop";
  echo "> Deleting ${i}"
  pvesh delete "nodes/${NODE}/${i}"
done

# delete private resource pool
pvesh delete "pools/${USERNAME}"

# delete private storage
pvesh delete "storage/${USERNAME}"
echo "Deleted storage/${USERNAME}"
echo "Directory storage /home/${USERNAME} is is not removed"

# delete group and user
pvesh delete "access/groups/${USERNAME}"
pvesh delete "access/users/${USERID}"

# scan for remaining acls
echo "ACL orphans (to remove):"
pvesh get access/acl | grep "${USERNAME}"
echo "#end of ACL orphan list, all good if empty"

#pvesh set access/acl --path /pool/terraform --roles "PVEDatastoreUser" --groups terraform --delete
