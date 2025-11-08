# PHP Version Pickup

Set a PHP version used in a shell session through a `.php-version` file.

[![Packagist](https://img.shields.io/packagist/v/webit-de/php-version-pickup.svg)](https://packagist.org/packages/webit-de/php-version-pickup/)
[![Made With](https://img.shields.io/badge/$__-bash-black)](https://gitlab.com/webit-de/php-version-pickup#requirements)
[![License](https://img.shields.io/badge/license-gpl--2.0--or--later-blue.svg)](https://spdx.org/licenses/GPL-2.0-or-later.html)

![screenshot](./docs/screenshot.png)

## Vision

This tool is a small shell script to set the version of PHP
used in a shell session, by reading the expected version number
from a `.php-version` file.

This allows to handle multiple PHP versions in a local development environment
and switch the version between projects on the fly.
By pinning the version in a file it also allows team members to use same
PHP version when working on a project.

The script is inspired by [`nvm use`](https://github.com/nvm-sh/nvm#nvmrc) and
[`php-version`](https://github.com/wilmoore/php-version). The former is made for
Node and does a lot more (build & install versions etc.). The letter works
perfectly well with PHP, but does not want to store files nor support PHP
versions installed by the OS package manager.
That's why this script was created.

The script is intentionally lightweight and shell-first:
it makes no global OS changes, doesn’t touch the webserver,
and doesn’t install PHP automatically. Instead, it links existing binaries.
It keeps things conservative and CI-friendly with a simple symlink layout,
clear output, and proper exit codes.

## Key Features

- Set a PHP version for the current shell session only (no system-wide change;
  forgotten in new shells, system defaults remain untouched)
- Pick up the PHP version from nearest `.php-version` file or persist it via `set`
- [Pass the version to subscripts](https://pixelbrackets.de/notes/pass-php-version-to-subscripts-in-cli-calls)
  as well — e.g. run Composer with the selected version,
  which propagates to executed PHP scripts
- List configured and in-use PHP versions
- Show official PHP releases from php.net and compare them to your local linked versions
- Verify a project’s required PHP version for local checks or CI pipelines
- Auto-detect installed PHP binaries and create the expected configuration layout interactively
- Supports PHP versions installed via PPA
- Written in Bash — no extra runtime, no OS or webserver interference

## Requirements

- Bash
- PHP (the script picks up existing PHP versions)

## Installation

- Clone the repository
  ```bash
  cd ~/
  git clone https://github.com/webit-de/php-version-pickup.git .php-version-pickup
  ```
- »Source« the script
  ```bash
  echo 'source $HOME/.php-version-pickup/bin/php-version-pickup.sh' >> $HOME/.bashrc
  ```
  - 💡 You may want to add an optional alias as shortcut command to your `.bashrc` like
    `alias pvm="php-version-pickup"`

- Install multiple PHP versions on your system
  (the script does not install PHP versions itself; you need to have them available)
  - 🏗️ Build manually, use the great
    [PPA by Ondřej Surý](https://launchpad.net/~ondrej/+archive/ubuntu/php),
    or a tool like [php-build](https://github.com/php-build/php-build) or
    [homebrew-php](https://github.com/josegonzalez/homebrew-php)

- The script uses symlinks to point to PHP binaries already available on your system,
  as this depends heavily on how your PHP versions were installed.

  You can set up these symlinks manually **or**, more conveniently,
  use the `php-version-pickup link` command, which guides you interactively
  through linking all detected PHP binaries.
  - The script expects the following structure for configured versions:
    `$HOME/.php/versions/<version>/bin/php -> <path to desired version binary>`

    Example:
    ```bash
    mkdir -p $HOME/.php/versions/8.4/bin && ln -s /usr/bin/php8.4 $HOME/.php/versions/8.4/bin/php
    ```
- Restart your shell or source your `.bashrc` again

## Source

https://github.com/webit-de/php-version-pickup/

## Usage

- **`php-version-pickup set <X.Y>`**  
  Stores the given PHP version `<X.Y>` in a `.php-version` file in the current directory.

  ⚠ Only
  [mayor PHP release numbers](https://www.php.net/supported-versions) are allowed,
  which means something like `8.1` or `8.4` (not a specific version like `8.1.10`).

- **`php-version-pickup use`**  
  Reads `PHP_VERSION` environment variable or nearest `.php-version` file (traversing up),
  validates the major.minor format, and prepends the found version link
  (`~/.php/versions/<X.Y>/bin`) to `PATH` for the current shell session.

- **`php-version-pickup list`**  
  Shows the currently used PHP version, the linked versions and autodetected
  but not linked installed binaries in common locations.
  Useful to get a quick system overview.

- **`php-version-pickup link`**  
  Interactive wizard which scans common PHP binary paths and offers to create
  the expected symlink layout under `~/.php/versions/<X.Y>/bin/php`.

- **`php-version-pickup releases`**
  Displays official active releases from PHP.net and compares them
  to your linked versions.

- **`php-version-pickup check`**
  Verifies if the required version of a project is active in the current shell.
  Returns exit code `0` if requirements are met, non-zero otherwise.

- **`php-version-pickup --help`**  
  Prints brief usage.

- **`php-version-pickup --version`**  
  Prints tool version.

### Examples / Walkthrough

#### Typical project setup

    cd /path/to/project
    php --version                # shows system default PHP version, e.g. PHP 8.4
    php-version-pickup set 8.3
    php-version-pickup link      # auto-detect installed PHP binary and create symlink
    php-version-pickup use
    php --version                # shows PHP 8.3 now

#### Show configured vs installed vs official releases

    php-version-pickup list
    php-version-pickup releases

### Tips

- `php-version-pickup list` is the first stop to inspect what is configured
  and what the system actually provides.
- Use `link` when you installed PHP versions via package manager
  or other tools — it creates the consistent symlink layout the script expects.
- `releases` helps identify EOL versions so you can proactively upgrade projects.
- 🥏 Play around with the version file, open and close shells, run some
  PHP scripts and make yourself comfortable with this simple version picker.

## License

GNU General Public License version 2 or later

The GNU General Public License can be found at http://www.gnu.org/copyleft/gpl.html.

## Author

Dan Kleine ([@pixelbrackets](https://github.com/pixelbrackets))
for webit! Gesellschaft für neue Medien mbH (https://www.webit.de/)

## Changelog

See [CHANGELOG](./CHANGELOG.md)

## Contribution

> TYPO3 - inspiring people to share!

This package is Open Source, so please use, patch, extend or fork it.
