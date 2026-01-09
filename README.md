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

## Custom Download URL

If you need to download buildifier from a custom URL (e.g., an internal
mirror or artifact server), you can use the `--buildifier-base-url`
argument:

```yaml
-   repo: https://github.com/keith/pre-commit-buildifier
    rev: TAG OR SHA
    hooks:
    -   id: buildifier
        args: [--buildifier-base-url=https://my-internal-mirror.example.com/buildifier/v8.2.1]
    -   id: buildifier-lint
        args: [--buildifier-base-url=https://my-internal-mirror.example.com/buildifier/v8.2.1]
```

The script will append the appropriate filename (e.g.,
`buildifier-linux-amd64`) to this base URL.

[buildifier]: https://github.com/bazelbuild/buildtools/tree/master/buildifier
[pc]: https://pre-commit.com
