#!/usr/bin/env bash

set -e

# This script downloads the Flux OpenAPI schemas, then it validates the
# Flux custom resources and the kustomize overlays using kubeconform.
# This script is meant to be run locally and in CI before the changes
# are merged on the main branch that's synced by Flux.

# Copyright 2020 The Flux authors. All rights reserved.
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

# This script is meant to be run locally and in CI to validate the Kubernetes
# manifests (including Flux custom resources) before changes are merged into
# the branch synced by Flux in-cluster.

# Prerequisites
# - yq 
# - kustomize 
# - kubeconform

# This script is modified - the original script can be found here:
# https://raw.githubusercontent.com/fluxcd/flux2-multi-tenancy/main/scripts/validate.sh

set -o errexit

CHECK_PATH=$@

echo "INFO - Downloading Flux OpenAPI schemas"
mkdir -p /tmp/flux-crd-schemas/master-standalone-strict
curl -sL https://github.com/fluxcd/flux2/releases/latest/download/crd-schemas.tar.gz | tar zxf - -C /tmp/flux-crd-schemas/master-standalone-strict

kubeconform_config=( "-strict" "-ignore-missing-schemas" "-schema-location" "default" "-schema-location" "/tmp/flux-crd-schemas" "-verbose")

# mirror kustomize-controller build options
kustomize_flags=("--load-restrictor=LoadRestrictionsNone")
kustomize_config="kustomization.yaml"

echo "INFO - Validating kustomize overlays"
find $CHECK_PATH -type f -name $kustomize_config -print0 | while IFS= read -r -d $'\0' file;
  do
    if yq e '(.kind|downcase) != "kustomization"' ${file} -e > /dev/null 2>&1; then
      # Do only check kustomizations not components
      echo "INFO - Skip because it is not a kustomization ${file/%$kustomize_config}"
      continue
    fi
    echo "INFO - Validating kustomization ${file/%$kustomize_config}"
    kustomize build "${file/%$kustomize_config}" "${kustomize_flags[@]}" | \
      yq "del(.sops)" | \
      kubeconform "${kubeconform_config[@]}"
    if [[ ${PIPESTATUS[0]} != 0 ]]; then
      exit 1
    fi
done
