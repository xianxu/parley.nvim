#!/bin/sh
# Refuse a harness scratch root placed where specs would write into a project
# (#422). The rule is tests/arch/scratch_placement_spec.lua's (#202, #338): the
# root is not inside the checkout, and no directory from the root up carries the
# repo marker. That spec checks it inside a running spec process, after other
# specs may already have written into the tree; this checks it once, before
# PREP_TEST_ENV creates anything.
#
# Usage: scripts/test-placement.sh ROOT CHECKOUT MARKER
#
# An inside-checkout `sdlc` review puts TMPDIR in the review clone, which is how
# the zero-config spec once wrote a chat into the clone's workshop/parley.
set -eu
[ "$#" -eq 3 ] || { echo 'usage: test-placement.sh ROOT CHECKOUT MARKER' >&2; exit 2; }
root=$1 marker=$3
checkout=$(cd "$2" && pwd -P)

# The root may not exist yet: resolve its nearest existing ancestor, so links
# (/tmp -> /private/tmp) compare like with like.
dir=$root
while [ ! -d "$dir" ]; do dir=$(dirname "$dir"); done
dir=$(cd "$dir" && pwd -P)

refuse() {
    echo "test-placement: the test scratch root $root $1." >&2
    echo "  Specs would treat that tree as a parley project and write into it (#202, #338, #422)." >&2
    echo "  Point TMPDIR (or TEST_ENV_ROOT) at a directory outside any $marker tree." >&2
    exit 1
}
while :; do
    [ "$dir" = "$checkout" ] && refuse "is inside the checkout $checkout"
    # The product's predicate (repo_mode.detect_root): a readable regular file.
    [ -f "$dir/$marker" ] && [ -r "$dir/$marker" ] && refuse "is under $dir, which carries $marker"
    [ "$dir" = / ] && break
    dir=$(dirname "$dir")
done
