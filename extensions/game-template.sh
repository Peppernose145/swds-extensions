#!/usr/bin/bash
VERSION=2.1.1
function debug() {
    if [[ $DEBUG == "1" ]]; then
        echo >&2 "DEBUG: $*"
    fi 
}
SWDS_CACHEDIR="$HOME/.cache/steam-ws-download"
SWDS_CONFDIR="$HOME/.local/share/steam-ws-download"
# Create cache folder if necessary
if [[ -d "$SWDS_CACHEDIR" ]]; then
    :
else
    mkdir "$SWDS_CACHEDIR"
    mkdir "$SWDS_CACHEDIR/gamename"
    mkdir "$SWDS_CACHEDIR/wsitemname"
fi
# Scan for dependencies
#  steamcmd
which >/dev/null steamcmd
EC=$?
if [[ $EC -gt 0 ]]; then
    echo >&2 "SteamCMD was not found or doesn't work! Make sure steamcmd exists in PATH"
    exit 2
fi
#  zenity
which >/dev/null zenity
EC=$?
if [[ $EC -gt 0 ]]; then
    echo >&2 "Zenity was not found or doesn't work! Make sure zenity exists in PATH"
    exit 2
fi

# getgamename - Function that extracts the name of a game from the Steam Store page or from cache given an AppID
function getgamename() {
    if [[ -e $SWDS_CACHEDIR/gamename/$1 ]]; then
        echo -n "$(< $SWDS_CACHEDIR/gamename/$1)"
    else
        local appid=$1
        local pattern='(?<=data-appname="&quot;).*(?=&quot;")'
        local html=$(curl 2>/dev/null "https://store.steampowered.com/app/$appid" | grep -oP "$pattern")
        local EC=$?
        if [[ $EC -gt 0 ]]; then
            debug "getgamename: AppID input was $appid, and grep exited with code $EC"
            return 404
        else
            echo -n "$html" 
            echo -n "$html" > $SWDS_CACHEDIR/gamename/$appid
        fi
    fi
    return
}

# getworkshopname - Function that extracts the name of a Workshop item from the Steam Workshop page or from cache given a Workshop ID
function getworkshopname() {
    if [[ -e $SWDS_CACHEDIR/wsitemname/$1 ]]; then
        echo -n $(< $SWDS_CACHEDIR/wsitemname/$1)
    else
        local wsid=$1
        local pattern='(?<=\<div class="workshopItemTitle"\>).*(?=\<\/div\>)'
        local html=$(curl 2>/dev/null "https://steamcommunity.com/sharedfiles/filedetails/?id=$wsid" | grep -oP "$pattern")
        local EC=$?
        if [[ $EC -gt 0 ]]; then
            debug "getworkshopname: Workshop ID input was $wsid, and grep exited with code $EC"
            return 404
        else
            echo -n "$html"
            echo -n "$html" > $SWDS_CACHEDIR/$wsid
        fi
    fi
    return
}

# Scan command-line arguments
#   Variables:
#     C_USER - true|false - Whether to use command-line arg for user instead of prompting
#     C_PASS - true|false - Whether to use command-line arg for password instead of prompting
#     C_GAME - true|false - Whether to use command-line arg for AppID instead of prompting
#     C_WSITEMS - true|false - Whether to use command-line arg for Workshop items instead of prompting
#     C_UCMD - true|false - Whether there are command-line args being used for the login
debug "Command-line: $@"
function prthelp() {
    cat <<EOF
Steam Workshop Downloader Script v$VERSION
Usage: steam-ws-download [Options]
    -h|-?|--help                                          Show this help message and exit.
    -a|--anon|--anonymous                                 Login anonymously, equivalent to '--user anon'
    -u|--user <name>                                      Login with this username
    -p|--password <password>                              Use this password when logging in. You must use --user BEFORE --password. Does not work with anonymous user.
    -g|--game <AppID>                                     Use this AppID.
    -w|--workshop-items|--wsitems <Workshop item list>    String list of Workshop IDs from the command-line
    -f|--file                                             Path to a file containing a list of Workshop IDs
    -v|--debug                                            Print debug output
    --clear-cache                                         Clear SWDS cache, if any
EOF
}
for a in $@; do
    case $1 in
        -v|--debug) DEBUG=1; debug "Debug output enabled" ;;
        --clear-cache)
            rm -rf $SWDS_CACHEDIR && echo "Cleared cache"
            exit
        ;;
        -h|-?|--help) prthelp; exit ;;
        -a|--anon|--anonymous) C_USER=true; LOGINENTRY="anonymous"; debug "Anonymous user selected" ;;
        -u|--user) C_UCMD=true; C_USER=true; LOGINUENTRY="$2"; LOGINENTRY="$LOGINUENTRY"; shift; debug "User selected: $LOGINENTRY" ;;
        -p|--password)
            C_UCMD=true
            if [[ C_USER == "true" ]]; then
                if [[ $LOGINENTRY =~ "anon" ]]; then
                    echo >&2 "Can't use --password with anonymous login"
                    exit 2
                else
                    C_PASS=true
                    LOGINENTRY="$LOGINUENTRY|$2"
                    shift
                fi
            else
                echo >&2 "Please enter --user <name> BEFORE --password"
                exit 2
            fi
        ;;
        -g|--game) C_GAME=true; GIDENTRYRAW="$2"; shift; debug "AppID entered: $GIDENTRY" ;;
        -w|--workshop-items|--wsitems) C_WSITEMS=true; WSENTRYRAW="$2"; shift; debug "Workshop items entered: $WSENTRYRAW" ;;
        -f|--file) 
            C_WSITEMS=true; 
            if [[ -e "$2" ]]; then 
                WSENTRYRAW="$(cat "$2")" #" <-- this is because GEdit does not factor quotes in subshells correctly in syntax highlighting
            else
                echo >&2 "$2: No such file, or is a directory"
            fi
        ;;
        -*) echo >&2 "Unknown option: $1"; prthelp; exit 2 ;;
        *) debug "Discarded non-option arg $1"; shift ;;
    esac
    shift
done

echo "Steam Workshop Downloader Script v$VERSION"
#DEBUG=1 # now controlled by the --debug option

# Set values
if [[ $C_USER == "true" ]]; then
    debug "Using command-line arg for user"
else
    LOGINENTRY=$(zenity --forms --text="Steam login required to use SteamCMD\nEnter \"anon\" for anonymous login\nLeave password blank to use cached account" --add-entry="Username" --add-password="Password")
    EC=$?
    if [[ $EC -gt 0 ]]; then
        echo "User cancelled"
        exit 1
    fi
fi
vrx='anon|anonymous'
grep -qiP "$vrx" <<EOF
$LOGINENTRY
EOF
MATCH=$?
if [[ $MATCH -eq 0 ]]; then
    ANON=1
    debug "Anonymous"
else
    ANON=0
    debug "Not anonymous"
fi
OLDIFS="$IFS"
IFS="|"
# Steam Login
CRD=( ${LOGINENTRY[@]} )
IFS=$OLDIFS
SUSER=${CRD[0]}
PASS=${CRD[1]}
# Game ID
GIDPROMPT="Enter game AppID"
if [[ -d "$SWDS_CONFDIR" ]]; then
    if [[ -e "$SWDS_CONFDIR/last_appid" ]]; then
        GAMEID=$(cat 2>/dev/null "$SWDS_CONFDIR/last_appid")
        GIDPROMPT="Enter game AppID (Last: $GAMEID)"
    fi
else
    mkdir "$SWDS_CONFDIR"
fi
while true; do
    if [[ $C_GAME == "true" ]]; then
        debug "Using command-line arg for AppID"
    else
        GIDENTRYRAW=$(zenity --title "$GIDPROMPT" --entry --entry-text "$GAMEID")
    fi
    EC=$?
    GIDENTRY=$(echo -n "$GIDENTRYRAW" | tr -d "\n")
    if [[ $EC -gt 0 ]]; then
        echo "User cancelled"
        exit 1
    fi
    debug "'$GIDENTRY'"
    if [[ "$GIDENTRY" =~ ^[0-9]+$ ]]; then
        break
    else
        if [[ $C_GAME == "true" ]]; then
            echo >&2 "Invalid AppID - You must only use the number corresponding to the Steam AppID, for example, 620 for Portal 2"
            exit 1
        else
            zenity --error --title "Invalid entry" --text "You must only put the number corresponding to the Steam AppID"
        fi
    fi
done
GAME=$GIDENTRY

# Scan for any extentions for this AppID
curl -o "$SWDS_CONFDIR/extensions/game-$GAME.sh" "https://raw.githubusercontent.com/Peppernose145/swds-extensions/main/extensions/game-$GAME.sh"
EC=$?
if [[ $EC -gt 0 ]]; then
    debug "Could not download extension for $GAME from GitHub"
else
    echo "Downloaded extension for $(getgamename $GAME) ($GAME)"
fi
if [[ -e "$SWDS_CONFDIR/extensions/game-$GAME.sh" ]]; then
    source "$SWDS_CONFDIR/extensions/game-$GAME.sh"
else
    debug "No extension for $GAME was found in $SWDW_CONFDIR/extensions"
fi



echo -n "$GAME" > "$SWDS_CONFDIR/last_appid"
# Workshop IDs
if [[ -e "$SWDS_CONFDIR/last_wsitems" ]]; then
    WSITEMS=$(cat 2>/dev/null "$SWDS_CONFDIR/last_wsitems")
fi
while true; do
    if [[ $C_WSITEMS == "true" ]]; then
        debug "Using command-line arg for Workshop Item List"
    else
        WSENTRYRAW=$(zenity --title "Enter one workshop ID per line" --text-info --editable <<< "$WSITEMS")
        EC=$?
        if [[ $EC -gt 0 ]]; then
            echo "User cancelled"
            exit 1
        fi
    fi
    WSENTRY=$(echo -n "$WSENTRYRAW" | awk '{$1=$1};1' | tr '\n' ' ')
    if [[ $DEBUG == "1" ]]; then
        debug "==== Workshop Entries ===="
        for e in ${WSENTRY[@]}; do
            debug "$e"
        done
        debug "=========================="
    fi
    vrx='[^0-9\s]+'
    grep -qiP "$vrx" <<EOF
$WSENTRY
EOF
    MATCH=$?
    if [[ $MATCH -eq 1 ]]; then
        break
    else
        debug $(echo "$WSENTRY" | grep -oiP "$vrx")
        if [[ $C_WSITEMS == "true" ]]; then
            echo >&2 "Invalid entry - You must only enter Workshop ID numbers delimited by whitespace, for example: 12345678 87654321 12344321"
            exit 1
        else
            zenity --error --title "Invalid entry" --text "You must only enter numbers corresponding to workshop IDs, one per line."
        fi
    fi
done
rm "$SWDS_CONFDIR/last_wsitems"
if [[ $PASS != "" ]]; then
    if [[ $C_UCMD == "true" ]]; then
        read -p "Enter Steam Guard code (If none, leave blank): " GCODE
    else
        GCODE=$(zenity --title "Enter Steam Guard code\nIf none, leave blank" --entry)
    fi
fi
echo "force_install_dir $HOME/Downloads/SteamWorkshop/Appid-$GAME" > /tmp/steam-ws-download.scmd
echo "Setting up downloads for $(getgamename $GAME) (AppID $GAME)"
for w in ${WSENTRY[@]}; do
    cmd="workshop_download_item $GAME $w"
    echo "$w" >> "$SWDS_CONFDIR/last_wsitems"
    echo "$(getworkshopname $w) ($w)"
    echo "$cmd" >> /tmp/steam-ws-download.scmd
done
echo "quit" >> /tmp/steam-ws-download.scmd
debug "login $SUSER [redacted]"
#echo ${SC_DL_CMDS[@]}
#cat /tmp/steam-ws-download.scmd
if [[ $ANON -eq 0 ]]; then
    steamcmd +login $SUSER $PASS $GCODE +runscript /tmp/steam-ws-download.scmd
else
    debug "Running SteamCMD as $SUSER"
    steamcmd +login anonymous +runscript /tmp/steam-ws-download.scmd
fi
#debug "SteamCMD status: $?"
