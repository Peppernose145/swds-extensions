# Steam Workshop Downloader Script Extension for Starbound
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
    if [[ -e $SWDS_CACHEDIR/gamename/$1 ]]; then
        echo -n "$(< $SWDS_CACHEDIR/gamename/$1)"
        debug "Found cache file: $SWDS_CACHEDIR/gamename/$1"
    else
        debug "Fetching store page"
        local appid=$1
        local pattern='(?<=data-appname="&quot;).*(?=&quot;")'
        local html=$(curl 2>/dev/null -f "https://store.steampowered.com/app/$appid" | grep -oP "$pattern")
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
    if [[ -e "$SWDS_CACHEDIR/wsitemname/$1" ]]; then
        echo -n $(< "$SWDS_CACHEDIR/wsitemname/$1")
    else
        local wsid=$1
        local pattern='(?<=\<div class="workshopItemTitle"\>).*(?=\<\/div\>)'
        local html=$(curl 2>/dev/null -f "https://steamcommunity.com/sharedfiles/filedetails/?id=$wsid" | grep -oP "$pattern")
        local EC=$?
        if [[ $EC -gt 0 ]]; then
            debug "getworkshopname: Workshop ID input was $wsid, and grep exited with code $EC"
            return 404
        else
            echo -n "$html"
            echo -n "$html" > $SWDS_CACHEDIR/wsitemname/$wsid
        fi
    fi
    return
}

echo "Starbound extension is active"

#filename_convert - Converts the input string to a format that is safe for filenames.
function filename_convert() {
    local input="$*"
    debug "Converting filename: $input"
    local output=
    for (( counter=0 ; counter < ${#input} ; counter++ )); do
        #debug "${input:$counter:1}"
        char="${input:$counter:1}"
        if [[ $char =~ [a-zA-Z0-9._] ]]; then
            output="$output$char"
        elif [[ $char =~ [-] ]]; then
            output="$output$char"
        elif [[ $char =~ [()] ]]; then
            output="$output$char"
        elif [[ $char =~ [-] ]]; then
            output="$output$char"
        elif [[ $char =~ []] ]]; then
            output="$output$char"
        elif [[ $char =~ [[] ]]; then
            output="$output$char"
        elif [[ $char =~ [+] ]]; then
            output="${output}plus"
        elif [[ $char =~ [=] ]]; then
            output="${output}equals"
        elif [[ $char =~ [\&] ]]; then
            output="${output}and"
        elif [[ $char =~ [,?\!] ]]; then
            output="$output"
        else
            output="${output}_"
        fi
    done
    echo -n "$output"
}
# Code to execute each loop when iterating through workshop items
function EXTENSION_WSITEM_LOOP() {
    local DEBUG=$1
    local WORKSHOPID=$2
    local SUSER="$3"
    local WSITEMS="$4"
    #shift 4
    debug "Ran EXTENSION_LOOP $DEBUG $WORKSHOPID '$SUSER' '$WSITEMS'"
}

# Code to execute before running SteamCMD
function EXTENSION_BEFORE() {
    local DEBUG=$1
    local SUSER="$2"
    local WSITEMS="$3"
    #shift 3 # Clear args so we can use $1, $2, and so on for extra data
    debug "Ran EXTENSION_BEFORE $DEBUG '$SUSER' '$WSITEMS'"
    # There's nothing to see here
}

# Code to execute after running SteamCMD
function EXTENSION_AFTER() {
    local DEBUG=$1
    local SUSER="$2"
    local WSITEMS="$3"
    #shift 3 # Clear args so we can use $1, $2, and so on for extra data
    debug "Ran EXTENSION_AFTER $DEBUG '$SUSER' '$WSITEMS'"
    local DL_RT="$HOME/Downloads/SteamWorkshop/Appid-211820"
    local DL_DIR="$DL_RT/steamapps/workshop/content/211820"
    local DEST_DIR="$HOME/Downloads/SteamWorkshop/Starbound/mods"
    mkdir -p "$DEST_DIR"
    EC=$?
    if [[ $EC -gt 0 ]]; then
        echo >&2 "Could not create directory!"
        return 1
    fi
    for i in ${WSITEMS[@]}; do
        debug "Processing $i"
        local c="$DL_DIR/$i"
        local n=$(getworkshopname $i)
        local nn=$(filename_convert "$n")
        local cf="$DL_DIR/$i/contents.pak"
        debug "New name: $nn.pak"
        mv "$cf" "$DEST_DIR/$nn.pak" || return 1
    done
    rm -rf "$DL_RT"
}
