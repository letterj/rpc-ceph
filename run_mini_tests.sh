#!/usr/bin/env bash
# Copyright 2015, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -xeuo pipefail

# Reset networking for containers
echo 'source /etc/network/interfaces.d/*.cfg' >> /etc/network/interfaces
systemctl restart networking

# Start up containers
lxc-start --name allsvc
lxc-start --name mon1
lxc-start --name mon2
lxc-start --name osd1
lxc-start --name osd2
lxc-start --name rgw1


echo "Gate job started"
echo "+-------------------- START ENV VARS --------------------+"
env
echo "+-------------------- START ENV VARS --------------------+"

export RE_JOB_SCENARIO=${RE_JOB_SCENARIO:-"functional"}
export RPC_MAAS_DIR=${RPC_MAAS_DIR:-/etc/ansible/roles/rpc-maas}
export TEST_RPC_MAAS=${TEST_RPC_MAAS:-True}

if [ "${RE_JOB_SCENARIO}" = "functional" ] || [ "${RE_JOB_SCENARIO}" = "keystone_rgw" ]; then
  export CLONE_DIR="$(pwd)"
  export ANSIBLE_INVENTORY="${CLONE_DIR}/tests/inventory"
  export ANSIBLE_OVERRIDES="${CLONE_DIR}/tests/test-vars.yml"
  export ANSIBLE_BINARY="${ANSIBLE_BINARY:-ceph-ansible-playbook}"

  if [ "${RE_JOB_SCENARIO}" = "keystone_rgw" ]; then
    export ANSIBLE_INVENTORY="${CLONE_DIR}/tests/inventory_rgw -e @tests/test-vars-rgw.yml"
  fi
  if [[ ! -d tests/common ]]; then
    git clone https://github.com/openstack/openstack-ansible-tests -b stable/pike tests/common
  fi
  ${ANSIBLE_BINARY} tests/setup-ceph-only-aio.yml \
                   -i ${ANSIBLE_INVENTORY} \
                   -e @tests/test-vars.yml
  # Use the rpc-maas deploy to test MaaS
  if [ "${TEST_RPC_MAAS}" != "False" ] && [ "${RE_JOB_SCENARIO}" != "keystone_rgw" ]; then
    pushd ${RPC_MAAS_DIR}
      export RE_JOB_SCENARIO="ceph"
      bash tests/test-ansible-functional.sh
    popd
  fi
else
  echo "Implement tox bits if necessary"
fi
