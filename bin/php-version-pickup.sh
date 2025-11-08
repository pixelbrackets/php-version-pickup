#! /usr/bin/env bash

# PHP Version Pickup
#
# This script needs to modify the $PATH environment variable,
# and therefore needs to be »sourced« first (run `source php-version-pickup.sh`)

function php-version-pickup {
    function php-version-pickup::main {
        # Routing

        if [[ $1 == "--help" ]]; then
            php-version-pickup::command_help; return 0

        elif [[ $1 == "--version" ]]; then
            php-version-pickup::command_version; return 0

        elif [[ $1 == "set" ]]; then
            php-version-pickup::command_set "$2"; return 0

        elif [[ $1 == "use" ]]; then
            php-version-pickup::command_use; return 0

        elif [[ $1 == "list" ]]; then
            php-version-pickup::command_list; return 0

        elif [[ $1 == "link" ]]; then
            php-version-pickup::command_link; return 0

        elif [[ $1 == "releases" ]]; then
            php-version-pickup::command_releases; return 0

        elif [[ $1 == "check" ]]; then
            php-version-pickup::command_check; return 0

        else
            php-version-pickup::command_help; return 0
        fi
    }

    # Commands

    function php-version-pickup::command_version {
        version="1.3.0"
        echo -e "php-version-pickup (PHP Version Pickup) \033[32m$version\033[0m"
    }

    function php-version-pickup::command_help {
        php-version-pickup::command_version;
        echo "Usage:"
        echo "php-version-pickup set          Store PHP version number in a file"
        echo "php-version-pickup use          Pick up PHP version from environment variable or file"
        echo "php-version-pickup list         List available PHP versions"
        echo "php-version-pickup link         Interactive wizard to link PHP versions"
        echo "php-version-pickup releases     Show PHP release information and EOL status"
        echo "php-version-pickup check        Verify project requirements and PHP version"
        echo "php-version-pickup --help       Show help"
        echo "php-version-pickup --version    Show version"
    }

    function php-version-pickup::command_set {
        local PHP_VERSION_TO_SET=$1
        if [[ -z $PHP_VERSION_TO_SET ]]; then
            read -r -p "Set version to use (schema <Major.Minor>, like <8.1>):" PHP_VERSION_TO_SET
            [ -z "$PHP_VERSION_TO_SET" ] && echo 'Empty version number' && return 1
        fi

        # Store version number in file
        echo $PHP_VERSION_TO_SET > $(pwd)'/.php-version'
        echo "Set version <$PHP_VERSION_TO_SET> in $(pwd)/.php-version"
    }

    function php-version-pickup::command_use {
        local PHP_VERSION_USE=$(php-version-pickup::get_version);
        if [ -z "$PHP_VERSION_USE" ]; then
            echo 'No version found'
            echo 'See `php-version-pickup --help` for more information'
            return 1;
        fi

        # Sanitize version number - only mayor versions like 7.4, 8.0
        if [[ $PHP_VERSION_USE =~ ^[0-9]+\.[0-9]+ ]]; then
            PHP_VERSION_USE=${BASH_REMATCH[0]}
        else
            echo 'Version number is faulty'
            return 1;
        fi

        # Map available binary to version
        local PHP_VERSION_BINARY_PATH="/home/$USER/.php/versions/$PHP_VERSION_USE/bin"

        if [ ! -f "$PHP_VERSION_BINARY_PATH/php" ]; then
            echo "No PHP version binary mapped at <$PHP_VERSION_BINARY_PATH/php>"
            return 1;
        fi

        # Populate binary to $PATH
        export PATH="$PHP_VERSION_BINARY_PATH:$PATH"

        echo "Now using PHP version $PHP_VERSION_USE"
    }

    function php-version-pickup::command_list {
        local PHP_VERSION_USED=$(php -v 2>/dev/null | grep -oP "^PHP \K[0-9]+\.[0-9]+(\.[0-9]+)?")
        local PHP_VERSION_PROJECT=$(php-version-pickup::get_project_version)

        if [ -n "$PHP_VERSION_USED" ]; then
            echo "Currently using PHP version $PHP_VERSION_USED"
        else
            echo 'Error: Unable to detect the currently used PHP version.'
        fi

        if [ -n "$PHP_VERSION_PROJECT" ]; then
            echo -e "Project requires PHP version \033[36m$PHP_VERSION_PROJECT\033[0m (.php-version file found)"
        fi

        echo 'Detecting configured PHP versions…'

        local PHP_VERSION_PATH="/home/$USER/.php/versions"

        if [ -z "$(ls -A "$PHP_VERSION_PATH" 2>/dev/null)" ]; then
            echo 'No PHP versions configured yet'
            echo ''
            echo 'Detecting installed but not linked PHP versions…'
            php-version-pickup::find_installed_versions
            return 0
        fi

        echo '.'

        # Collect subfolders, sorted by number
        local PHP_VERSION_PATH_SUBFOLDERS
        mapfile -t PHP_VERSION_PATH_SUBFOLDERS < <(printf "%s\n" "$PHP_VERSION_PATH"/* | sort -V -r)

        for PHP_VERSION_PATH_SUBFOLDER in "${PHP_VERSION_PATH_SUBFOLDERS[@]}"; do
            local PHP_VERSION_BINARY_PATH="$PHP_VERSION_PATH_SUBFOLDER/bin/php"

            local PHP_VERSION_BINARY_SYMLINK_TARGET=''
            if [ -L "$PHP_VERSION_BINARY_PATH" ]; then
                PHP_VERSION_BINARY_SYMLINK_TARGET=$(readlink "$PHP_VERSION_BINARY_PATH")
            fi

            local PHP_VERSION=$("$PHP_VERSION_BINARY_PATH" -v 2>/dev/null | grep -oP "^PHP \K[0-9]+\.[0-9]+(\.[0-9]+)?")
            local PHP_VERSION_SHORT=$(echo "$PHP_VERSION" | grep -oP "^[0-9]+\.[0-9]+")

            local MARKER="├─"
            if [ "$PHP_VERSION_SHORT" == "$PHP_VERSION_PROJECT" ]; then
                MARKER="├─ \033[36m★\033[0m"
            fi

            echo -e "$MARKER $(basename "$PHP_VERSION_PATH_SUBFOLDER") -> $PHP_VERSION_BINARY_SYMLINK_TARGET (Version $PHP_VERSION)"
        done

        echo ''
        echo 'Detecting installed but not linked PHP versions…'
        php-version-pickup::find_installed_versions
    }

    function php-version-pickup::command_link {
        echo 'PHP Version Link Wizard'
        echo ''

        # Find installed versions
        local -a PHP_VERSIONS=()
        local -a PHP_PATHS=()
        local INDEX=1

        local SEARCH_PATHS=(
            "/usr/bin"
            "/usr/local/bin"
            "/opt/homebrew/bin"
            "/opt/php"
        )

        for SEARCH_PATH in "${SEARCH_PATHS[@]}"; do
            if [ -d "$SEARCH_PATH" ]; then
                for PHP_BIN in "$SEARCH_PATH"/php[0-9]* "$SEARCH_PATH"/php; do
                    if [ -x "$PHP_BIN" ] && [ ! -L "$PHP_BIN" ]; then
                        local VERSION=$("$PHP_BIN" -r "echo PHP_VERSION;" 2>/dev/null)
                        local VERSION_SHORT=$("$PHP_BIN" -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;" 2>/dev/null)

                        if [ -n "$VERSION" ]; then
                            # Check if not already linked
                            if [ ! -f "/home/$USER/.php/versions/$VERSION_SHORT/bin/php" ]; then
                                PHP_VERSIONS+=("$VERSION_SHORT")
                                PHP_PATHS+=("$PHP_BIN")
                                echo "├─ $INDEX) PHP $VERSION ($PHP_BIN)"
                                ((INDEX++))
                            fi
                        fi
                    fi
                done
            fi
        done

        if [ "$INDEX" -eq 1 ]; then
            echo 'No unlinked PHP versions found'
            return 0
        fi

        echo "├─ $INDEX) Custom path"
        echo "├─ 0) Cancel"
        echo ''

        read -r -p "Which version to link? [0-$INDEX]: " SELECTION

        if [ "$SELECTION" == "0" ]; then
            echo 'Cancelled'
            return 0
        fi

        local SELECTED_VERSION=""
        local SELECTED_PATH=""

        if [ "$SELECTION" == "$INDEX" ]; then
            # Custom path
            read -r -p "Enter path to PHP binary: " SELECTED_PATH
            if [ ! -x "$SELECTED_PATH" ]; then
                echo "Error: Not a valid executable: $SELECTED_PATH"
                return 1
            fi
            SELECTED_VERSION=$("$SELECTED_PATH" -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;" 2>/dev/null)
            if [ -z "$SELECTED_VERSION" ]; then
                echo 'Error: Could not determine PHP version from binary'
                return 1
            fi
        elif [ "$SELECTION" -ge 1 ] && [ "$SELECTION" -lt "$INDEX" ]; then
            local ARRAY_INDEX=$((SELECTION - 1))
            SELECTED_VERSION="${PHP_VERSIONS[$ARRAY_INDEX]}"
            SELECTED_PATH="${PHP_PATHS[$ARRAY_INDEX]}"
        else
            echo 'Invalid selection'
            return 1
        fi

        echo ''
        local VERSION_NAME="$SELECTED_VERSION"

        # Validate version name format
        if ! [[ "$VERSION_NAME" =~ ^[0-9]+\.[0-9]+$ ]]; then
            echo 'Error: Invalid version format. Use format: X.Y (e.g., 8.2)'
            return 1
        fi

        local TARGET_DIR="/home/$USER/.php/versions/$VERSION_NAME/bin"
        local TARGET_LINK="$TARGET_DIR/php"

        if [ -e "$TARGET_LINK" ]; then
            read -r -p "Version $VERSION_NAME already exists. Overwrite? [y/N]: " CONFIRM
            if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
                echo 'Cancelled'
                return 0
            fi
            rm -f "$TARGET_LINK"
        fi

        mkdir -p "$TARGET_DIR"
        ln -s "$SELECTED_PATH" "$TARGET_LINK"

        if [ $? -eq 0 ]; then
            echo -e "\033[32m✓\033[0m PHP $VERSION_NAME successfully linked"

            local TEST_OUTPUT=$("$TARGET_LINK" --version 2>/dev/null | head -n 1)
            if [ -n "$TEST_OUTPUT" ]; then
                echo "Verified: $TEST_OUTPUT"
            fi
        else
            echo 'Error: Failed to create symlink'
            return 1
        fi
    }

    function php-version-pickup::command_releases {
        echo 'PHP Release Information'
        echo ''
        echo 'Fetching data from php.net…'
        echo ''

        # Fetch release data from php.net
        local RELEASES_JSON=$(curl -s "https://www.php.net/releases/index.php?json" 2>/dev/null)

        if [ -z "$RELEASES_JSON" ]; then
            echo 'Error: Failed to fetch release information'
            return 1
        fi

        echo 'Active PHP Versions:'
        echo "$RELEASES_JSON" | grep -oP '"[0-9]+\.[0-9]+"' | sort -u -V -r | while read -r VERSION_QUOTED; do
            local VERSION=$(echo "$VERSION_QUOTED" | tr -d '"')

            # Get version details from JSON
            local VERSION_DATA=$(echo "$RELEASES_JSON" | grep -A 10 "\"$VERSION\"")

            if [ -n "$VERSION_DATA" ]; then
                local ANNOUNCEMENT=$(echo "$VERSION_DATA" | grep -oP '"announcement":.*?"date":"([^"]+)"' | head -1 | grep -oP '[0-9]{2} [A-Z][a-z]+ [0-9]{4}')
                echo -e "├─ \033[32m●\033[0m PHP $VERSION"
                if [ -n "$ANNOUNCEMENT" ]; then
                    echo "│  Latest release: $ANNOUNCEMENT"
                fi
            fi
        done

        echo ''
        echo 'Your Linked Versions:'

        local PHP_VERSION_PATH="/home/$USER/.php/versions"
        local FOUND_LINKED=0

        if [ -d "$PHP_VERSION_PATH" ] && [ -n "$(ls -A "$PHP_VERSION_PATH" 2>/dev/null)" ]; then
            for VERSION_DIR in "$PHP_VERSION_PATH"/*; do
                if [ -d "$VERSION_DIR" ]; then
                    local VERSION=$(basename "$VERSION_DIR")
                    local PHP_BIN="$VERSION_DIR/bin/php"

                    if [ -f "$PHP_BIN" ]; then
                        local FULL_VERSION=$("$PHP_BIN" -v 2>/dev/null | grep -oP "^PHP \K[0-9]+\.[0-9]+(\.[0-9]+)?")

                        # Check if version is in active list
                        local IS_ACTIVE=$(echo "$RELEASES_JSON" | grep -c "\"$VERSION\"")

                        if [ "$IS_ACTIVE" -gt 0 ]; then
                            echo -e "├─ \033[32m✓\033[0m PHP $VERSION ($FULL_VERSION) - Active support"
                        else
                            echo -e "├─ \033[33m⚠\033[0m PHP $VERSION ($FULL_VERSION) - End of Life"
                        fi

                        FOUND_LINKED=1
                    fi
                fi
            done
        fi

        if [ "$FOUND_LINKED" -eq 0 ]; then
            echo '├─ No linked versions found'
        fi

        echo ''
        echo 'For more details visit: https://www.php.net/supported-versions.php'
    }

    function php-version-pickup::command_check {
        local PHP_VERSION_PROJECT=$(php-version-pickup::get_project_version)

        if [ -z "$PHP_VERSION_PROJECT" ]; then
            echo 'No .php-version file found in current directory'
            return 1
        fi

        echo "Project requires PHP version $PHP_VERSION_PROJECT"

        local PHP_VERSION_BINARY_PATH="/home/$USER/.php/versions/$PHP_VERSION_PROJECT/bin/php"

        if [ -f "$PHP_VERSION_BINARY_PATH" ]; then
            echo -e "├─ \033[32m✓\033[0m PHP $PHP_VERSION_PROJECT is linked and available"

            local PHP_VERSION_USED=$(php -v 2>/dev/null | grep -oP "^PHP \K[0-9]+\.[0-9]+")
            if [ "$PHP_VERSION_USED" == "$PHP_VERSION_PROJECT" ]; then
                echo -e "├─ \033[32m✓\033[0m PHP $PHP_VERSION_PROJECT is currently active"
            else
                echo -e "├─ \033[33m⚠\033[0m PHP $PHP_VERSION_PROJECT is not active"
                echo "│  Run: php-version-pickup use"
            fi
        else
            echo -e "├─ \033[31m✗\033[0m PHP $PHP_VERSION_PROJECT is not linked"
            echo "│  Run: php-version-pickup link"

            # Check if version is installed but not linked
            local SEARCH_PATHS=(
                "/usr/bin"
                "/usr/local/bin"
                "/opt/homebrew/bin"
            )

            for SEARCH_PATH in "${SEARCH_PATHS[@]}"; do
                for PHP_BIN in "$SEARCH_PATH"/php"$PHP_VERSION_PROJECT" "$SEARCH_PATH"/php; do
                    if [ -x "$PHP_BIN" ]; then
                        local VERSION=$("$PHP_BIN" -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;" 2>/dev/null)
                        if [ "$VERSION" == "$PHP_VERSION_PROJECT" ]; then
                            echo "├─ Found PHP $PHP_VERSION_PROJECT at: $PHP_BIN"
                            break 2
                        fi
                    fi
                done
            done
        fi
    }

    # Helper methods

    function php-version-pickup::get_version {
        # Pick up version from environment variable
        if [[ -n $PHP_VERSION ]]; then
            echo "Found environment variable \$PHP_VERSION" >&2
            echo "$PHP_VERSION" # return version
            return;
        fi

        # Pick up version from file
        # Traverse upwards, starting in working directory
        local SEARCH_DIRECTORY=$(pwd)
        while [ ! -z "$SEARCH_DIRECTORY" ] && [ ! -f "$SEARCH_DIRECTORY/.php-version" ]; do
            SEARCH_DIRECTORY="${SEARCH_DIRECTORY%\/*}"
        done

        local PHP_VERSION_FROM_FILE=`cat $SEARCH_DIRECTORY/.php-version 2>/dev/null`
        if [[ -n $PHP_VERSION_FROM_FILE ]]; then
            echo "Found $SEARCH_DIRECTORY/.php-version with version <$PHP_VERSION_FROM_FILE>" >&2
            echo "$PHP_VERSION_FROM_FILE" # return version
        fi
    }

    function php-version-pickup::get_project_version {
        # Get version from .php-version in current directory only
        if [ -f ".php-version" ]; then
            cat ".php-version" | tr -d '[:space:]'
        fi
    }

    function php-version-pickup::find_installed_versions {
        local SEARCH_PATHS=(
            "/usr/bin"
            "/usr/local/bin"
            "/opt/homebrew/bin"
            "/opt/php"
        )

        local FOUND_ANY=0

        for SEARCH_PATH in "${SEARCH_PATHS[@]}"; do
            if [ -d "$SEARCH_PATH" ]; then
                for PHP_BIN in "$SEARCH_PATH"/php[0-9]* "$SEARCH_PATH"/php; do
                    if [ -x "$PHP_BIN" ] && [ ! -L "$PHP_BIN" ]; then
                        local VERSION=$("$PHP_BIN" -r "echo PHP_VERSION;" 2>/dev/null)
                        local VERSION_SHORT=$("$PHP_BIN" -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;" 2>/dev/null)

                        if [ -n "$VERSION" ]; then
                            # Check if not already linked
                            if [ ! -f "/home/$USER/.php/versions/$VERSION_SHORT/bin/php" ]; then
                                echo "├─ $VERSION_SHORT at $PHP_BIN (not linked)"
                                FOUND_ANY=1
                            fi
                        fi
                    fi
                done
            fi
        done

        if [ "$FOUND_ANY" -eq 0 ]; then
            echo 'No unlinked PHP versions found'
        fi
    }

    php-version-pickup::main "$@"

    # clean up sourced namespaced functions
    unset -f $(compgen -A function php-version-pickup::)
}
