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

        elif [[ $1 == "releases" ]]; then
            php-version-pickup::command_releases; return 0

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
        echo "php-version-pickup set          Store version number in a file"
        echo "php-version-pickup use          Pick up version from environment variable or file"
        echo "php-version-pickup list         List configured PHP versions"
        echo "php-version-pickup releases     Show PHP release information and EOL status"
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

         if [ -n "$PHP_VERSION_USED" ]; then
            echo "Currently using PHP version $PHP_VERSION_USED"
        else
            echo 'Error: Unable to detect the currently used PHP version.'
        fi

        echo 'Detecting configured PHP versions…'

        local PHP_VERSION_PATH="/home/$USER/.php/versions"

        if [ -z "$(ls -A "$PHP_VERSION_PATH")" ]; then
            echo 'No PHP versions configured yet'
            return 1
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

            echo "├─ $(basename "$PHP_VERSION_PATH_SUBFOLDER") -> $PHP_VERSION_BINARY_SYMLINK_TARGET (Version $PHP_VERSION)"
        done
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

    php-version-pickup::main "$@"

    # clean up sourced namespaced functions
    unset -f $(compgen -A function php-version-pickup::)
}
