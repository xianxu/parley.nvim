# CI compiler pin

The repository owns `.sdlc/weave-compiler-ref`: exactly one lowercase 40-character
Ariadne commit SHA followed by a newline. It is authored configuration outside
`construct/base.manifest`, so weave compile preserves it.

`.github/workflows/merge-check.yml` is generated from the reviewed Ariadne
workflow. It validates the pin before fetching, verifies fetched HEAD, selects
Go from that source’s go.mod, and builds weave into runner-temporary storage.
Binary metadata must show the pinned vcs.revision and vcs.modified=false before
its private directory enters PATH. Bootstrap, repository setup and merge checks
then run in that order. Pin fetch/build/identity failures stop before bootstrap;
there is no fallback to an installed formula or older PATH executable.

To update the compiler, agree an approved immutable Ariadne commit with the
maintainer, change the pin in an issue PR, and refresh generated workflows when
needed. Run the upstream actual-workflow-block conformance and cold ownership
checks, the recorded repository suite, and hosted merge-check. Inspect the
hosted log for the selected Go version and exact clean binary revision. The
operator verifies the local-gates PR and applies `local-gates-verified`; agents
never apply it. Future pin bumps use the same approval path.

For a malformed or unavailable pin, correct its format or select an approved
reachable commit through review, then rerun CI. For a build or provenance
failure, inspect the pinned source, toolchain and metadata; fix the cause before
rerunning. Keep the pin and provenance checks in place during recovery.

The inherited [CI merge-check contract](https://github.com/xianxu/ariadne/blob/63d6bfd86509d97649e10d7a5dd1e9a06db17d21/atlas/workflow/ci-merge-check.md) describes
the shared workflow; this page maps its repository-owned configuration and
operator approval. The workflow and upstream conformance remain the executable
source of truth.
