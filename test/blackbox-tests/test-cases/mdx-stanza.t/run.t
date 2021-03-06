  $ cat >using-mdx/dune-project <<EOF
  > (lang dune 2.4)
  > EOF

To use the mdx stanza you need to explicitly set (using mdx ..) in the
dune-project

  $ dune build @install --root using-mdx/
  Entering directory 'using-mdx'
  File "dune", line 1, characters 0-5:
  1 | (mdx)
      ^^^^^
  Error: 'mdx' is available only when mdx is enabled in the dune-project file.
  You must enable it using (using mdx 0.1) in your dune-project file.
  [1]

It also requires dune lang 2.4 or higher

  $ dune build @install --root lang-version/
  Entering directory 'lang-version'
  File "dune-project", line 3, characters 11-14:
  3 | (using mdx 0.1)
                 ^^^
  Warning: Version 0.1 of mdx extension to verify code blocks in .md files is
  not supported until version 2.4 of the dune language.
  There are no supported versions of this extension in version 2.3 of the dune
  language.
  
  File "dune", line 1, characters 0-5:
  1 | (mdx)
      ^^^^^
  Error: 'mdx' is only available since version 2.4 of the dune language. Please
  update your dune-project file to have (lang dune 2.4).
  [1]

You can use the mdx stanza to check your documentation in markdown and mli files

  $ dune runtest --root simple/
  Entering directory 'simple'
  File "README.md", line 1, characters 0-0:
  Error: Files _build/default/README.md and
  _build/default/.mdx/README.md.corrected differ.
  [1]

Dune should invoke `ocaml-mdx deps` to figure out the files and directories a markdown
or mli to-be-mdxed file depends upon

  $ dune runtest --root mdx-deps/
  Entering directory 'mdx-deps'

You can make local packages available to mdx by using the `packages` field of
the stanza

  $ dune runtest --root local-package
  Entering directory 'local-package'

Dune does not fail if the `packages` are not available at evaluation time
(regression test fixed by ocaml/dune#3650)

  $ cd local-package-unrelated && dune build -p unrelated-package; cd ../

Dune fails if the `packages` are not available at execution time

  $ cd local-package-unrelated && dune runtest -p unrelated-package; cd ../
  File "dune", line 3, characters 11-14:
  3 |  (packages pkg))
                 ^^^
  Error: Package pkg does not exist

You can set MDX preludes using the preludes field of the stanza

  $ dune runtest --root preludes
  Entering directory 'preludes'

The mdx stanza supports (enabled_if):

  $ dune runtest --root enabled-if
  Entering directory 'enabled-if'
  File "iftrue.md", line 1, characters 0-0:
  Error: Files _build/default/iftrue.md and
  _build/default/.mdx/iftrue.md.corrected differ.
  [1]

(enabled_if) needs a recent (lang dune):

  $ dune runtest --root enabled-if-old-lang-dune
  Entering directory 'enabled-if-old-lang-dune'
  File "dune", line 2, characters 1-18:
  2 |  (enabled_if true))
       ^^^^^^^^^^^^^^^^^
  Error: 'enabled_if' is only available since version 2.9 of the dune language.
  Please update your dune-project file to have (lang dune 2.9).
  [1]

The mdx stanza supports (package):

  $ dune runtest --root package
  Entering directory 'package'
  File "doc-a.md", line 1, characters 0-0:
  Error: Files _build/default/doc-a.md and
  _build/default/.mdx/doc-a.md.corrected differ.
  File "doc-b.md", line 1, characters 0-0:
  Error: Files _build/default/doc-b.md and
  _build/default/.mdx/doc-b.md.corrected differ.
  File "doc-nopkg.md", line 1, characters 0-0:
  Error: Files _build/default/doc-nopkg.md and
  _build/default/.mdx/doc-nopkg.md.corrected differ.
  [1]

  $ dune runtest --root package --only-packages b
  Entering directory 'package'
  File "doc-b.md", line 1, characters 0-0:
  Error: Files _build/default/doc-b.md and
  _build/default/.mdx/doc-b.md.corrected differ.
  File "doc-nopkg.md", line 1, characters 0-0:
  Error: Files _build/default/doc-nopkg.md and
  _build/default/.mdx/doc-nopkg.md.corrected differ.
  [1]

(package) needs a recent (lang dune):

  $ dune runtest --root package-old-lang-dune --only-packages b
  Entering directory 'package-old-lang-dune'
  File "dune", line 3, characters 1-12:
  3 |  (package a))
       ^^^^^^^^^^^
  Error: 'package' is only available since version 2.9 of the dune language.
  Please update your dune-project file to have (lang dune 2.9).
  [1]
