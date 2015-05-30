#!/bin/bash

function usage {
    read -r -d "" output << TXT
Usage: neo4j-instance [command]

The commands are as follows:
 help                           outputs this document
 create [option]                create a new database instance
     options:
        -d <db name>            sets the name of the neo4j instance
        -t <neo4j type>         sets the neo4j type (community | enterprise)
        -v <neo4j version>      sets neo4j version (default: $currentVersion)
 rename-db <port> <db name>     renames the db neo4j instance
 start <port>                   starts a neo4j instance
 stop <port>                    stops a neo4j instance
 destroy <port>                 destroys a database instance
 shell <port>                   allows you to enter in shell mode
 list                           list the different databases,
                                with their ports and their statuses
 list plugins [port]            list the available plugins for neo4j

Report bugs to levi@eneservices.com
TXT
    echo "$output";
}

function setup {
    if [ "$username" == 'root' ]; then
        message "script should not be ran as root" "W" "red";
        exit;
    fi

    if [ -d ~/neo4j-instances ]; then
        cd ~/neo4j-instances
    else
        cd ~;
        mkdir neo4j-instances;
        cd ~/neo4j-instances;
    fi

    if [ ! -d ports ]; then
        mkdir ports
    fi
}

function portIsTaken {
    port=$1;
    if (netstat -tulpn 2>&1 | sed -e 's/\s\+/ /g' | cut -d " " -f4 >&1 | grep ":$port$" > /dev/null); then
        return 0;
    fi
    return 1;
}

function databaseExists {
    if grep "^$1\$" ports/*/db-name > /dev/null 2>&1; then
        return 0;
    fi
    return 1;
}

function message {
    message=$1
    tag=$2
    color=$3

    if [ ! -z "$color" ]; then
        color="${colors["$color"]}";
    fi

    if [ ! -z "$tag" ]; then
        tag="*$color$tag${colors["no-color"]}* ";
    fi

    echo -e "$tag$message";
}

function createDatabase {
    dbName="";
    lastShellPort=$startShellPort;
    lastPort=$(ls ports | sort | tail -n1);
    lastSslPort=$((lastPort - 1));

    if [ -z "$lastPort" ] || [ -d "ports/$lastPort" ]; then
        lastPort=$startPort;
        while [ -d "ports/$lastPort" ]; do
            lastShellPort=$(cat ports/$lastPort/shell-port);
            lastPort=$((lastPort + 2));
            if ( ! portIsTaken $((lastShellPort + 1)) ); then
                lastShellPort=$((lastShellPort + 1));
            fi
        done
        lastSslPort=$((lastPort-1));
    fi

    OPTIND=2;
    # set neo4j type and version
    while getopts "d:t:v:" o; do
        case "$o" in
            d) if  databaseExists "$OPTARG"; then
                message "database name is already taken" "E" "red";
                exit;
            fi
            dbName=$OPTARG;
            ;;
        t) type=$OPTARG;
            (( "$type" == "community" || "$type" == "enterprise")) && neo4jType=$type;
            ;;
        v) version=$OPTARG;
            if [[ $version =~ ^[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+$ ]]; then
                currentVersion=$version
            fi
            ;;
        *) usage;
            ;;
        esac
    done

    if [ ! -d "neo4j-skeleton/${neo4jType}-${currentVersion}" ]; then
        mkdir -p "./neo4j-skeleton/${neo4jType}-${currentVersion}";
        if hash curl; then
            curl -# -L "http://neo4j.com/artifact.php?name=neo4j-${neo4jType}-${currentVersion}-unix.tar.gz" | tar xzC "neo4j-skeleton/${neo4jType}-${currentVersion}/" --strip-components 1
        elif hash wget; then
            wget -O- "http://neo4j.com/artifact.php?name=neo4j-${neo4jType}-${currentVersion}-unix.tar.gz" | tar xzC "neo4j-skeleton/${neo4jType}-${currentVersion}/" --strip-components 1
        else
            message "please install curl or wget" "W" "blue";
            exit;
        fi
    fi

    if [ ! -d "ports/$lastPort" ]; then
        message "create database" "X" "green";
        cp -r "neo4j-skeleton/${neo4jType}-${currentVersion}" "ports/$lastPort";
        cat "neo4j-skeleton/${neo4jType}-${currentVersion}/conf/neo4j-server.properties" | sed -e "s/org.neo4j.server.webserver.port=7474/org.neo4j.server.webserver.port=$lastPort/" | sed -e "s/org.neo4j.server.webserver.https.port=7473/org.neo4j.server.webserver.https.port=$lastSslPort/" > ports/$lastPort/conf/neo4j-server.properties
        cat "neo4j-skeleton/${neo4jType}-${currentVersion}/conf/neo4j.properties" | sed -e "s/^#remote_shell_port/remote_shell_port/" | sed -e "s/remote_shell_port=1337/remote_shell_port=$lastShellPort/" > ports/$lastPort/conf/neo4j.properties
        cat "neo4j-skeleton/${neo4jType}-${currentVersion}/conf/neo4j.properties" | sed -e "s/^#remote_shell_port/remote_shell_port/" | sed -e "s/remote_shell_port=1337/remote_shell_port=$lastShellPort/" | sed -e "s/online_backup_enabled=true/online_backup_enabled=false/" > ports/$lastPort/conf/neo4j.properties

        if [ ! -z "$dbName" ]; then
            echo -n "$dbName" > ports/$lastPort/db-name
            echo -n "$neo4jType" > ports/$lastPort/db-type
            echo -n "$currentVersion" > ports/$lastPort/db-version
            echo -n "$lastShellPort" > ports/$lastPort/shell-port
        fi
    fi
}

function renameDatabase {
    if [ -d "ports/$2" ]; then
        if databaseExists "$3"; then
            message "database already exists" "E" "red";
            exit 1;
        else
            echo -n "$3" > "ports/$2/db-name";
            message "database name renamed" "M" "blue";
        fi
    else
        message "port was not given" "E" "red";
    fi
}

function displayList {
    if [ "$2" == "plugins" ]; then
        message "neo4j plugins you can install:" "M" "blue";
    else
        message "neo4j databases:" "M" "blue";
        for x in $(ls ports); do
            dbAddon="";
            if (portIsTaken "$x"); then
                status="${colors["green"]}on ${colors["no-color"]}";
            else
                status="${colors["blue"]}off${colors["no-color"]}";
            fi
            if [ -f "ports/$x/db-name" ]; then
                dbName=$(cat "ports/$x/db-name");
                type=$(cat "ports/$x/db-type");
                version=$(cat "ports/$x/db-version");
                typeInfo=$(printf "%10s" "$type");
            #    dbAddon="- <${colors["grey"]}$typeInfo${colors["no-color"]}:${colors["ecru"]}$version${colors["no-color"]}> - db [${colors["purple"]}$dbName${colors["no-color"]}]";
                dbAddon="- <${colors["grey"]}$typeInfo${colors["no-color"]}:${colors["ecru"]}$version${colors["no-color"]}> - [${colors["purple"]}$dbName${colors["no-color"]}]";
            fi
            # message "    $x - status [$status] $dbAddon";
            message "    $x - [$status] $dbAddon";
        done
    fi
}

function destroyDatabase {
    if [ ! -z "$2" ] && [ -d "ports/$2" ]; then
        if (portIsTaken "$2"); then
            ./ports/"$2"/bin/neo4j stop;
        fi
        rm -r "ports/$2";
        message "database on port [$2] was deleted" "M" "blue";
    else
        if [ ! -d "ports/$2" ]; then
            message "port [$2] does not exist" "W" "red";
        else
            message "was unable to delete port [$2]" "W" "red";
        fi
    fi
}

function check {
    if [ "$1" == "start" ] && (portIsTaken "$2"); then
        message "database already started" "W" "red";
        return 1;
    elif [ "$1" == "stop" ] && (! portIsTaken "$2") && [ -d "ports/$2" ]; then
        message "database was already stopped" "W" "red";
        return 1;
    elif [ ! -d "ports/$2" ]; then
        message "database was never created for that port" "W" "red";
        return 1;
    fi
    return 0;
}

function databaseCommand {
    if (check "${@}"); then
        cd "ports/$2/bin";
        ./neo4j "$1";
    fi
}

function startDatabase {
    databaseCommand "${@}" | grep http;
}

function stopDatabase {
    databaseCommand "${@}";
}

function databaseStatus {
    databaseCommand "${@}";
}

function startShell {
    shellPort=$(cat ./ports/"$2"/shell-port);
    if (portIsTaken "$2"); then
        ./ports/"$2"/bin/neo4j-shell -port $shellPort;
    else
        message "database has not been started" "W" "red";
    fi
}

declare -A colors;
colors=( ["blue"]="\e[1;34m" ["green"]="\e[1;32m" ["no-color"]="\e[0m" ["red"]="\e[1;31m" ["grey"]="\e[1;37m" ["magenta"]="\e[1;95m" ["purple"]="\e[38;5;135m" ["ecru"]="\e[33m" );
username=$(whoami);
startPort=7474;
lastShellPort=1337;
currentVersion="2.2.2";
neo4jType="community";

setup;

case "$1" in
    create)
        createDatabase "${@}";
        ;;
    rename-db)
        renameDatabase "${@}";
        ;;
    start)
        startDatabase "${@}";
        ;;
    stop)
        stopDatabase "${@}";
        ;;
    destroy)
        destroyDatabase "${@}";
        ;;
    shell)
        startShell "${@}";
        ;;
    list)
        displayList "${@}";
        ;;
    *)
        usage;
        ;;
esac