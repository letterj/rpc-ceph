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

echo "Gate job started"
echo "+-------------------- START ENV VARS --------------------+"
env
echo "+-------------------- START ENV VARS --------------------+"

export RE_JOB_SCENARIO=${RE_JOB_SCENARIO:-"functional"}
export RPC_MAAS_DIR=${RPC_MAAS_DIR:-/etc/ansible/roles/rpc-maas}
export TEST_RPC_MAAS=${TEST_RPC_MAAS:-True}

# Install python2 for Ubuntu 16.04 and CentOS 7
if which apt-get; then
    sudo apt-get update && sudo apt-get install -y python
fi

if which yum; then
    sudo yum install -y python
fi

# Install pip.
if ! which pip; then
  curl --silent --show-error --retry 5 \
    https://bootstrap.pypa.io/get-pip.py | sudo python2.7
fi

# Install bindep and tox with pip.
sudo pip install bindep tox

# CentOS 7 requires two additional packages:
#   redhat-lsb-core - for bindep profile support
#   epel-release    - required to install python-ndg_httpsclient/python2-pyasn1
if which yum; then
    sudo yum -y install redhat-lsb-core epel-release
fi

export CLONE_DIR="$(pwd)"
export ANSIBLE_INVENTORY="${CLONE_DIR}/tests/inventory"
export ANSIBLE_OVERRIDES="${CLONE_DIR}/tests/test-vars.yml"
export ANSIBLE_BINARY="${ANSIBLE_BINARY:-ceph-ansible-playbook}"
bash scripts/bootstrap-ansible.sh
# Clone the test repos
${ANSIBLE_BINARY} playbooks/git-clone-repos.yml \
                 -i ${ANSIBLE_INVENTORY} \
                 -e role_file=../tests/ansible-role-test-requirements.yml
${ANSIBLE_BINARY} tests/setup-base-aio.yml \
                 -i ${ANSIBLE_INVENTORY} \
                 -e @tests/test-vars.yml
