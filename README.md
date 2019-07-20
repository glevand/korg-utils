# korg-utils

Utilities for kernel.org.

## kup-files.sh

Recursively processes files for kup.  Prepares signature files and can either upload files to a kup server or output a kup batchfile.

```
kup-files.sh (korg-utils) - Recursively kup files.
Usage: kup-files.sh [flags] top-dir
Option flags:
  -r --kup-path - kup remote path. Default: ''.
  -d --dry-run  - Do not upload.
  -b --batch    - Output a kup batchfile. Default: ''.
  -h --help     - Show this help and exit.
  -v --verbose  - Verbose execution.
  -g --debug    - Extra verbose execution.
Send bug reports to: Geoff Levand <geoff@infradead.org>.
```

## License

All files in the [korg-utils Project](https://github.com/glevand/korg-utils), unless otherwise noted, are covered by an [MIT Plus License](https://github.com/glevand/korg-utils/mit-plus-license.txt).  The text of the license describes what usage is allowed.
