# Steam Workshop Downloader Script Extension template
# Input format for both callback functions: <Debug - 0|1> <WorkshopID> <SteamUser> <WorkshopItemList> <ExtraData1> <ExtraData2> <and so on...>

# debug - Function that outputs given string if DEBUG == 1
# Do not modify this function
function debug() {
    if [[ $DEBUG == "1" ]]; then
        echo >&2 "DEBUG: $*"
    fi 
}

# getgamename - Function that extracts the name of a game from the Steam Store page or from cache given an AppID
function getgamename() {
    if [[ -e $HOME/.cache/steam-ws-download/gamename/$1 ]]; then
        echo -n "$(< $home/.cache/steam-ws-download/gamename/$1)"
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
            echo -n "$html" > $HOME/.cache/steam-ws-download/gamename/$appid
        fi
    fi
    return
}

# getworkshopname - Function that extracts the name of a Workshop item from the Steam Workshop page or from cache given a Workshop ID
function getworkshopname() {
    if [[ -e $HOME/.cache/steam-ws-download/wsitemname/$1 ]]; then
        echo -n $(< $HOME/.cache/steam-ws-download/wsitemname/$1
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
            echo -n "$html" > $HOME/.cache/steam-ws-download/$wsid
        fi
    fi
    return
}

# Code to execute before running SteamCMD
function EXTENSION_BEFORE() {
    local DEBUG=$1
    local WORKSHOPID=$2
    local SUSER=$3
    local WSITEMS=$4
    shift 4 # Clear args so we can use $1, $2, and so on for extra data
    # Put code here
}

# Code to execute after running SteamCMD
function EXTENSION_AFTER() {
    local DEBUG=$1
    local WORKSHOPID=$2
    local SUSER=$3
    local WSITEMS=$4
    shift 4 # Clear args so we can use $1, $2, and so on for extra data
    # Put code here
}
