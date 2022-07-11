# Prj-GenussFold

This repository provides a convenient way to build the current setup of "GenussFold" for RNA
pseudoknot grammars.

## Building this project

There are two options on how to build this project. Both provide a full build environment. Building
via ``nix`` has the advantage of providing a known-good set of ``ghc``, ``llvm``, and all
dependencies (even standard ``C`` libraries).

### Building via ``cabal``

Run ``cabal build exe:GenussFold`` in the top-level directory.

Run a test like so:
``
zcat ADPfusion/runtimes/0100.input.gz | head -n 1 | head -c 50 | dist-newstyle/build/x86_64-linux/ghc-9.0.2/GenussFold-0.0.0.3/x/GenussFold/build/GenussFold/GenussFold +RTS -s -RTS
``
- An input of 50 nucleotides (from the set of testing sequences)
- with activated @+RTS -s@ runtime information, which will print the running time

### Building via the ``nix`` build environment

If you have ``nix`` installed with ``flakes``, then call in the top-level directory:
``
nix develop
``

Once you are in a shell, you can build the project thusly:
``
buildcabal GenussFold/src/GenussFold.hs
``

an then run the same test as above:
``
zcat ADPfusion/runtimes/0100.input.gz | head -n 1 | head -c 50 | ./GenussFold/src/GenussFold +RTS -s -RTS
``

