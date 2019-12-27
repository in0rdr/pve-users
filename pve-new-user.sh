#!/usr/bin/env sh
#
# Create a new Proxmox VE user
# with the Proxmox VE Shell tool (`pvesh`)
#
# User Roles:        https://pve.proxmox.com/wiki/User_Management#pveum_roles
# Sorage Properties: https://pve.proxmox.com/wiki/Storage#_common_storage_properties

# @TODO: sanity checks and input validation
USERNAME="${1}"
PASSWORD="${2}"

# pve or pam domain
DOMAIN=pve
# userid concatenates username and domain
USERID="${USERNAME}@${DOMAIN}"

#
# authentication
#
# create user
pvesh create /access/users --userid "${USERID}"
# set password
pvesh set access/password --userid "${USERID}" --password "${PASSWORD}"

#
# group
#
# create group for the new user
pvesh create /access/groups --groupid "${USERNAME}"
# add the new user to this group
pvesh set /access/users/"${USERID}" --groups "${USERNAME}"

#
# container templates, backups and iso images
#
# create storage for container templates, backups and iso images
pvesh create storage --storage "${USERNAME}" --type dir --path "/home/${USERNAME}" --shared 0 --maxfiles 1 --content vztmpl,backup,iso
# grant the user to place backups/templates/images on private storage
pvesh set access/acl --path "/storage/${USERNAME}" --roles PVEDatastoreAdmin --groups "${USERNAME}"
# allow the user to access shared storage
# add the new user to the shared storage group
# append the group, to not remove the user from his primary group
pvesh set /access/users/"${USERID}" --groups "shared" --append
# Alternatively, add an acl for the user on shared storage.
# However, this is not needed since the group "shared" already
# has PVEDatastoreAdmin permissions on /storage/shared
#pvesh set access/acl --path /storage/shared --roles PVEDatastoreAdmin --groups "${USERNAME}"

#
# container data and VM images
# in private resource pool
#
# create a private resource pool for the new user
pvesh create pools --poolid "${USERNAME}"
# add the global lvm storage to the private pool
# for container data and VM images
pvesh set "pools/${USERNAME}" --storage local-lvm
# - make the user the pool admin for the private resource pool
# - grant the user to use (PVEDatastoreUser) the global data store (local-lvm)
#   which was added to the private pool in the last step
# - grant to VM admin rights on the private pool
pvesh set access/acl --path "/pool/${USERNAME}" --roles "PVEPoolAdmin,PVEDatastoreUser,PVEVMAdmin" --groups "${USERNAME}"