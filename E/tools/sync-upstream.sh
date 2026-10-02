#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Merge GrapheneOS/Vanadium into this repo. Upstream files are never edited here,
# so this is conflict-free as long as customizations stay under E/.
set -o errexit -o nounset -o pipefail
git remote get-url upstream >/dev/null 2>&1 || git remote add upstream https://github.com/GrapheneOS/Vanadium.git
git fetch upstream
git merge --no-edit upstream/main
