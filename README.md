# pre-commit-buildifier

This is a hook for [pre-commit][pc] and [buildifier][buildifier] that
doesn't require it to be installed ahead of time and easily lets you pin
to a specific version.

## Usage

```yaml
-   repo: https://github.com/keith/pre-commit-buildifier
    rev: TAG OR SHA
    hooks:
    -   id: buildifier
    -   id: buildifier-lint
```

This repo provides multiple hooks because some buildifier rules cannot
be autofixed. The `buildifier` hook fixes everything that can while the
`buildifier-lint` hook prints unfixable warnings. If you use both of
them you should use them in that order so you don't end up in duplicate
warnings.

If you'd like to pass custom flags to buildifier (as well as the default
mode configurations) you can use pre-commit's `args`:

```yaml
    -   id: buildifier
        args: [custom, flags]
```

[buildifier]: https://github.com/bazelbuild/buildtools/tree/master/buildifier
[pc]: https://pre-commit.com
