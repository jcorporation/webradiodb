#!/bin/bash
#
#SPDX-License-Identifier: GPL-3.0-or-later
#myMPD (c) 2021-2022 Juergen Mang <mail@jcgames.de>
#https://github.com/jcorporation/radiodb

set -uo pipefail

#print out commands
[ -z "${DEBUG+x}" ] || set -x

PUBLISH_DIR="docs/db"
SOURCES_DIR="sources"
PICS_DIR="${PUBLISH_DIR}/pics"
PLS_DIR="${PUBLISH_DIR}/webradios"

INDEXFILE="${PUBLISH_DIR}/index/webradios.min.json"
INDEXFILE_COMBINED="${PUBLISH_DIR}/index/webradiodb-combined.min.json"
INDEXFILE_JS="${PUBLISH_DIR}/index/webradiodb-combined.min.js"

STATUSFILE="${PUBLISH_DIR}/index/status.min.json"
LANGFILE="${PUBLISH_DIR}/index/languages.min.json"
COUNTRYFILE="${PUBLISH_DIR}/index/countries.min.json"
GENREFILE="${PUBLISH_DIR}/index/genres.min.json"
CODECFILE="${PUBLISH_DIR}/index/codecs.min.json"
BITRATEFILE="${PUBLISH_DIR}/index/bitrates.min.json"

MOODE_PICS_DIR="${SOURCES_DIR}/moode-pics"
MOODE_PLS_DIR="${SOURCES_DIR}/moode-webradios"
MYMPD_PICS_DIR="${SOURCES_DIR}/mympd-pics"
MYMPD_PLS_DIR="${SOURCES_DIR}/mympd-webradios"

source ./mappings/genre_map.sh
source ./mappings/m3ufields_map.sh

is_uri() {
    CHECK_URI="$1"
    [ "${CHECK_URI:0:7}" = "http://" ] && return 0
    [ "${CHECK_URI:0:8}" = "https://" ] && return 0
    return 1
}

get_m3u_field() {
    M3U_FILE="$1"
    M3U_FIELD="$2"

    LINE=$(grep "^#${M3U_FIELD}:" "$M3U_FILE")
    echo "${LINE#*:}"
}

download_image() {
    DOWNLOAD_URI="$1"
    DOWNLOAD_DST="$2"
    echo "Downloading image: \"$DOWNLOAD_URI\""
    if ! curl -fsSL "$DOWNLOAD_URI" --output "${DOWNLOAD_DST}.image"
    then
        rm -f "${DOWNLOAD_DST}.image"
        return 1
    fi
    if ! convert "${DOWNLOAD_DST}.image" "${DOWNLOAD_DST}.webp"
    then
        rm -f "${DOWNLOAD_DST}.image"
        echo "Converting image to webp failed"
        return 1
    fi
    rm -f "${DOWNLOAD_DST}.image"
    if ! resize_image "${DOWNLOAD_DST}.webp"
    then
        return 1
    fi
    return 0
}

resize_image() {
    RESIZE_FILE="$1"
    TO_SIZE="400x400"
    [ -s "$RESIZE_FILE" ] || exit 1
    #get actual size
    CUR_SIZE=$(identify -format "%wx%h" "$RESIZE_FILE")

    if [ "${CUR_SIZE}" != "${TO_SIZE}" ]
    then
        if convert "$RESIZE_FILE" -resize "$TO_SIZE^" -gravity center -extent "$TO_SIZE" "$RESIZE_FILE.resize"
        then
            mv "$RESIZE_FILE.resize" "$RESIZE_FILE"
        else
            echo "Error resizing $RESIZE_FILE"
            rm -f "$RESIZE_FILE.resize"
            return 1
        fi
    fi
    return 0
}

cleanup_genres() {
    DIR=$1
    for F in "$DIR"/*.m3u
    do
        GENRE_LINE=$(grep "^#EXTGENRE" "$F")
        GENRE_LINE=${GENRE_LINE#*:}
        NEW_GENRE=""
        while read -r -d, GENRE
        do
            [ "$GENRE" = "" ] && continue
            NG="${genre_map[$GENRE]:-}"
            if [ "$NG" != "" ]
            then
                NEW_GENRE="$NEW_GENRE, $NG"
            else
                NEW_GENRE="$NEW_GENRE, $GENRE"
            fi
        done < <(sed 's/, /,/g' <<< "$GENRE_LINE,")
        NEW_GENRE="${NEW_GENRE:2}"
        if [ "$GENRE_LINE" != "$NEW_GENRE" ]
        then
            echo "$F: $GENRE_LINE -> $NEW_GENRE"
            sed -i -e "s/^#EXTGENRE:.*/#EXTGENRE:$NEW_GENRE/" "$F"
        fi
    done
}

sync_moode() {
    echo "Syncing moode audio webradios"
    # fields of cfg_radios are:
    # id, station, name, type, logo, genre, broadcaster, language, country, region, bitrate, codec, geo_fenced, home_page, reserved2
    MOODE_DB="https://raw.githubusercontent.com/moode-player/moode/master/var/local/www/db/moode-sqlite3.db.sql"
    MOODE_IMAGES="https://raw.githubusercontent.com/moode-player/moode/master/var/local/www/imagesw/radio-logos/"

    # start with clean output dirs
    rm -fr "$MOODE_PLS_DIR" 
    mkdir "$MOODE_PLS_DIR"
    mv "$MOODE_PICS_DIR" "${MOODE_PICS_DIR}.old"
    mkdir "$MOODE_PICS_DIR"

    # fetch the sql file and grep the webradio stations and convert it to csv
    I=0
    S=0
    while read -r LINE
    do
        # LINE is a csv: station, name, genre, language, country, bitrate, codec, homepage

        # create the same plist name as myMPD
        PLIST=$(csvcut -c 1 <<< "$LINE" | \
            sed -E -e 's/[<>/.:?&$!#\\|;=]/_/g')

        if grep -q "$PLIST" mappings/moode-ignore
        then
            printf "s"
            S=$((S+1))
            continue
        fi
        # extract fields
        STATION=$(csvcut -c 1 <<< "$LINE" | sed -e s/\"//g)
        NAME=$(csvcut -c 2 <<< "$LINE" | sed -e s/\"//g)
        IMAGE=$(csvcut -c 3 <<< "$LINE" | sed -e s/\"//g)
        GENRE=$(csvcut -c 4 <<< "$LINE" | sed -e s/\"//g)
        LANGUAGE=$(csvcut -c 5 <<< "$LINE" | sed -e s/\"//g)
        COUNTRY=$(csvcut -c 6 <<< "$LINE" | sed -e s/\"//g)
        BITRATE=$(csvcut -c 7 <<< "$LINE" | sed -e s/\"//g)
        CODEC=$(csvcut -c 8 <<< "$LINE" | sed -e s/\"//g)
        HOMEPAGE=$(csvcut -c 9 <<< "$LINE" | sed -e s/\"//g)

        # get images 
        NAME_ENCODED=$(jq -rn --arg x "$NAME" '$x|@uri')
        if [ "$IMAGE" = "local" ]
        then
            if [ -s "${MOODE_PICS_DIR}.old/${PLIST}.webp" ]
            then
                cp "${MOODE_PICS_DIR}.old/${PLIST}.webp" "${MOODE_PICS_DIR}/${PLIST}.webp"
                IMAGE="${PLIST}.webp"
            elif download_image "${MOODE_IMAGES}${NAME_ENCODED}.jpg" "${MOODE_PICS_DIR}/${PLIST}"
            then
                IMAGE="${PLIST}.webp"
            else
                IMAGE=""
            fi
        elif download_image "${MOODE_IMAGES}${NAME_ENCODED}.jpg" "${MOODE_PICS_DIR}/${PLIST}"
        then
            IMAGE="${PLIST}.webp"
        else
            IMAGE=""
        fi

        # write ext m3u with custom myMPD fields
        cat > "${MOODE_PLS_DIR}/${PLIST}.m3u" << EOL
#EXTM3U
#EXTINF:-1,$NAME
#EXTGENRE:$GENRE
#PLAYLIST:$NAME
#EXTIMG:$IMAGE
#HOMEPAGE:$HOMEPAGE
#COUNTRY:$COUNTRY
#LANGUAGE:$LANGUAGE
#DESCRIPTION:
#CODEC:$CODEC
#BITRATE:$BITRATE
$STATION
EOL
        printf "."
        I=$((I+1))
    done < <(wget -q "$MOODE_DB" -O - | \
        grep "INSERT INTO cfg_radio" | \
        awk -F "VALUES " '{print $2}' | \
        sed -e 's/^(//' -e 's/);//' -e "s/', /',/g" -e "s/, '/,'/g"  | \
        csvcut -q \' -c 2,3,5,6,8,9,11,12,14 |
        grep -v -E "(OFFLINE|zx reserved 499)")
    rm -fr "${MOODE_PICS_DIR}.old"
    echo ""
    echo "$I webradios synced"
    echo "$S webradios skipped"
    cleanup_genres "${MOODE_PLS_DIR}"
}

add_radio() {
    # get the uri and write out a skeletion file
    read -r -p "URI: " URI
    # create the same plist name as myMPD
    PLIST=$(sed -E -e 's/[<>/.:?&$!#\\|;=]/_/g' <<< "$URI")
    if [ -f "${MYMPD_PLS_DIR}/${PLIST}.m3u" ]
    then
        echo "This webradio already exists."
        exit 1
    fi
    # write ext m3u with custom myMPD fields
    cat > "${MYMPD_PLS_DIR}/${PLIST}.m3u" << EOL
#EXTM3U
#EXTINF:-1,<name>
#EXTGENRE:<genre>
#PLAYLIST:<name>
#EXTIMG:${PLIST}.webp
#HOMEPAGE:<homepage>
#COUNTRY:<country>
#LANGUAGE:<language>
#DESCRIPTION:<description>
#CODEC:<codec>
#BITRATE:<bitrate>
$URI
EOL
    echo ""
    echo "Playlist file ${MYMPD_PLS_DIR}/$PLIST.m3u created."
    echo "Edit it to add details."
    echo "You shoud add an image with the name $PLIST.webp to the ${MYMPD_PICS_DIR} folder"
    echo "or replace the #EXTIMG tag with an url to the image."
    echo ""
}

add_radio_from_json() {
    INPUT="$1"
    URI=$(jq -r ".streamuri" < "$INPUT" | head -1 | tr -d '\n')
    NAME=$(jq -r ".name" < "$INPUT" | head -1 | tr -d '\n')
    GENRE=$(jq -r ".genre" < "$INPUT" | head -1 | tr -d '\n' | sed -E -e 's/;\s?/, /g' -e 's/,(\S)/, \1/g')
    IMAGE=$(jq -r ".image" < "$INPUT" | head -1 | tr -d '\n')
    HOMEPAGE=$(jq -r ".homepage" < "$INPUT" | head -1 | tr -d '\n')
    COUNTRY=$(jq -r ".country" < "$INPUT" | head -1 | tr -d '\n')
    LANGUAGE=$(jq -r ".language" < "$INPUT" | head -1 | tr -d '\n')
    DESCRIPTION=$(jq -r ".description" < "$INPUT" | head -1 | tr -d '\n')
    CODEC=$(jq -r ".codec" < "$INPUT" | head -1 | tr -d '\n')
    BITRATE=$(jq -r ".bitrate" < "$INPUT" | head -1 | tr -d '\n')
    # create the same plist name as myMPD
    PLIST=$(sed -E -e 's/[<>/.:?&$!#\\|;=]/_/g' <<< "$URI")
    echo "Adding webradio $PLIST"
    if [ -f "${MYMPD_PLS_DIR}/${PLIST}.m3u" ]
    then
        echo "This webradio already exists."
        exit 1
    fi
    if [ -n "$IMAGE" ] && is_uri "$IMAGE"
    then
        if download_image "$IMAGE" "${MYMPD_PICS_DIR}/${PLIST}"
        then
            IMAGE="${PLIST}.webp"
        else
            echo "Download of image has failed"
            exit 1
            IMAGE=""
        fi
    else
        echo "Image is not an uri, skipping download"
        IMAGE=""
    fi
    echo "Writing ${PLIST}.m3u"
    cat > "${MYMPD_PLS_DIR}/${PLIST}.m3u" << EOL
#EXTM3U
#EXTINF:-1,$NAME
#EXTGENRE:$GENRE
#PLAYLIST:$NAME
#EXTIMG:$IMAGE
#HOMEPAGE:$HOMEPAGE
#COUNTRY:$COUNTRY
#LANGUAGE:$LANGUAGE
#DESCRIPTION:$DESCRIPTION
#CODEC:$CODEC
#BITRATE:$BITRATE
$URI
EOL
}

modify_radio_from_json() {
    INPUT="$1"
    #Webradio to modify
    MODIFY_URI=$(jq -r ".modifyWebradio" < "$INPUT")
    MODIFY_PLIST=$(sed -E -e 's/[<>/.:?&$!#\\|;=]/_/g' <<< "$MODIFY_URI")
    if [ ! -f "${MYMPD_PLS_DIR}/${MODIFY_PLIST}.m3u" ]
    then
        if [ -f "${MOODE_PLS_DIR}/${MODIFY_PLIST}.m3u" ]
        then
            echo "Move webradio from moode to mympd"
            mv "${MOODE_PLS_DIR}/${MODIFY_PLIST}.m3u" "${MYMPD_PLS_DIR}/${MODIFY_PLIST}.m3u"
            [ -f "${MOODE_PICS_DIR}/${MODIFY_PLIST}.webp" ] && \
                mv "${MOODE_PICS_DIR}/${MODIFY_PLIST}.webp" "${MYMPD_PICS_DIR}/${MODIFY_PLIST}.webp"
            #add moode radio ignore
            echo "${MODIFY_PLIST}" >> mappings/moode-ignore
        else
            echo "Webradio ${MODIFY_PLIST} not found"
            exit 1
        fi
    fi
    echo "Modifying webradio $MODIFY_PLIST"
    #New values
    NEW_URI=$(jq -r ".streamuri" < "$INPUT" | head -1 | tr -d '\n')
    NEW_NAME=$(jq -r ".name" < "$INPUT" | head -1 | tr -d '\n')
    NEW_GENRE=$(jq -r ".genre" < "$INPUT" | head -1 | tr -d '\n' | sed -E -e 's/;\s?/, /g' -e 's/,(\S)/, \1/g')
    NEW_IMAGE=$(jq -r ".image" < "$INPUT" | head -1 | tr -d '\n')
    NEW_HOMEPAGE=$(jq -r ".homepage" < "$INPUT" | head -1 | tr -d '\n')
    NEW_COUNTRY=$(jq -r ".country" < "$INPUT" | head -1 | tr -d '\n')
    NEW_LANGUAGE=$(jq -r ".language" < "$INPUT" | head -1 | tr -d '\n')
    NEW_DESCRIPTION=$(jq -r ".description" < "$INPUT" | head -1 | tr -d '\n')
    NEW_CODEC=$(jq -r ".codec" < "$INPUT" | head -1 | tr -d '\n')
    NEW_BITRATE=$(jq -r ".bitrate" < "$INPUT" | head -1 | tr -d '\n')
    NEW_PLIST=$(sed -E -e 's/[<>/.:?&$!#\\|;=]/_/g' <<< "$NEW_URI")
    #Get old values
    OLD_NAME=$(get_m3u_field "${MYMPD_PLS_DIR}/${MODIFY_PLIST}.m3u" "PLAYLIST")
    OLD_GENRE=$(get_m3u_field "${MYMPD_PLS_DIR}/${MODIFY_PLIST}.m3u" "EXTGENRE")
    OLD_IMAGE=$(get_m3u_field "${MYMPD_PLS_DIR}/${MODIFY_PLIST}.m3u" "EXTIMG")
    OLD_HOMEPAGE=$(get_m3u_field "${MYMPD_PLS_DIR}/${MODIFY_PLIST}.m3u" "HOMEPAGE")
    OLD_COUNTRY=$(get_m3u_field "${MYMPD_PLS_DIR}/${MODIFY_PLIST}.m3u" "COUNTRY")
    OLD_LANGUAGE=$(get_m3u_field "${MYMPD_PLS_DIR}/${MODIFY_PLIST}.m3u" "LANGUAGE")
    OLD_DESCRIPTION=$(get_m3u_field "${MYMPD_PLS_DIR}/${MODIFY_PLIST}.m3u" "DESCRIPTION")
    OLD_CODEC=$(get_m3u_field "${MYMPD_PLS_DIR}/${MODIFY_PLIST}.m3u" "CODEC")
    OLD_BITRATE=$(get_m3u_field "${MYMPD_PLS_DIR}/${MODIFY_PLIST}.m3u" "BITRATE")
    if [ "$MODIFY_PLIST" != "$NEW_PLIST" ] && [ -f "${MYMPD_PLS_DIR}/${NEW_PLIST}.m3u" ]
    then
        echo "A webradio for the new streamuri already exists."
        exit 1
    fi
    #set new plist name
    [ -z "$NEW_PLIST" ] && NEW_PLIST="$MODIFY_PLIST"
    if [ "$MODIFY_PLIST" != "$NEW_PLIST" ]
    then
        rm "${MYMPD_PLS_DIR}/${MODIFY_PLIST}.m3u"
        mv "${MYMPD_PICS_DIR}/${MODIFY_PLIST}.webp" "${MYMPD_PICS_DIR}/${NEW_PLIST}.webp"
        NEW_IMAGE="${NEW_PLIST}.webp"
        #rename alternative streams
        if [ "$(echo "${MYMPD_PLS_DIR}/$MODIFY_PLIST."*)" != "${MYMPD_PLS_DIR}/$MODIFY_PLIST.*" ]
        then
            for S in "${MYMPD_PLS_DIR}/$MODIFY_PLIST."*
            do
                G=${S//$MODIFY_PLIST/$NEW_PLIST}
                mv -v "$S" "$G"
            done
        fi
    fi
    #get changed image
    if [ "$NEW_IMAGE" != "$OLD_IMAGE" ] && [ -n "$NEW_IMAGE" ]
    then
        echo "Image has changed"
        rm -f "$OLD_IMAGE"
        if is_uri "$NEW_IMAGE"
        then
            if download_image "$NEW_IMAGE" "${MYMPD_PICS_DIR}/${NEW_PLIST}"
            then
                NEW_IMAGE="${NEW_PLIST}.webp"
            else
                echo "Download of image has failed"
                exit 1
                NEW_IMAGE=""
            fi
        else
            echo "Image is not an uri, skipping download"
        fi
    fi
    echo "Setting new values"
    #merge other values
    [ -z "$NEW_URI" ] && NEW_URI="$MODIFY_URI"
    [ -z "$NEW_NAME" ] && NEW_NAME="$OLD_NAME"
    [ -z "$NEW_IMAGE" ] && NEW_IMAGE="$OLD_IMAGE"
    [ -z "$NEW_GENRE" ] && NEW_GENRE="$OLD_GENRE"
    [ -z "$NEW_HOMEPAGE" ] && NEW_HOMEPAGE="$OLD_HOMEPAGE"
    [ -z "$NEW_COUNTRY" ] && NEW_COUNTRY="$OLD_COUNTRY"
    [ -z "$NEW_LANGUAGE" ] && NEW_LANGUAGE="$OLD_LANGUAGE"
    [ -z "$NEW_DESCRIPTION" ] && NEW_DESCRIPTION="$OLD_DESCRIPTION"
    [ -z "$NEW_CODEC" ] && NEW_CODEC="$OLD_CODEC"
    [ -z "$NEW_BITRATE" ] && NEW_BITRATE="$OLD_BITRATE"
    echo "Writing ${NEW_PLIST}.m3u"
    cat > "${MYMPD_PLS_DIR}/${NEW_PLIST}.m3u" << EOL
#EXTM3U
#EXTINF:-1,$NEW_NAME
#EXTGENRE:$NEW_GENRE
#PLAYLIST:$NEW_NAME
#EXTIMG:$NEW_IMAGE
#HOMEPAGE:$NEW_HOMEPAGE
#COUNTRY:$NEW_COUNTRY
#LANGUAGE:$NEW_LANGUAGE
#DESCRIPTION:$NEW_DESCRIPTION
#CODEC:$NEW_CODEC
#BITRATE:$NEW_BITRATE
$NEW_URI
EOL
}

delete_radio_from_json() {
    INPUT="$1"
    URI=$(jq -r ".deleteWebradio" < "$INPUT")
    # create the same plist name as myMPD
    PLIST=$(sed -E -e 's/[<>/.:?&$!#\\|;=]/_/g' <<< "$URI")

    if [ -f "${MYMPD_PLS_DIR}/${PLIST}.m3u" ]
    then
        echo "Deleting webradio ${PLIST}"
        if rm "${MYMPD_PLS_DIR}/${PLIST}.m3u"*
        then
            rm -f "${MYMPD_PICS_DIR}/${PLIST}.webp"
        else
            exit 1
        fi
    fi
    if [ -f "${MOODE_PLS_DIR}/${PLIST}.m3u" ]
    then
        echo "Deleting webradio ${PLIST}"
        if rm "${MOODE_PLS_DIR}/${PLIST}.m3u"
        then
            rm -f "${MOODE_PICS_DIR}/${PLIST}.webp"
        else
            exit 1
        fi
        echo "Adding webradio $PLIST to moode-ignore"
        echo "${PLIST}" >> mappings/moode-ignore
    fi
}

add_alternate_stream_from_json() {
    INPUT="$1"
    WEBRADIO=$(jq -r ".modifyWebradio" < "$INPUT")
    # create the same plist name as myMPD
    PLIST=$(sed -E -e 's/[<>/.:?&$!#\\|;=]/_/g' <<< "$WEBRADIO")

    URI=$(jq -r ".streamuri" < "$INPUT" | head -1 | tr -d '\n')
    CODEC=$(jq -r ".codec" < "$INPUT" | head -1 | tr -d '\n')
    BITRATE=$(jq -r ".bitrate" < "$INPUT" | head -1 | tr -d '\n')

    echo "Writing ${PLIST}.m3u.$CODEC.$BITRATE"
    cat > "${MYMPD_PLS_DIR}/${PLIST}.m3u.$CODEC.$BITRATE" << EOL
#CODEC:$CODEC
#BITRATE:$BITRATE
$URI
EOL
}

delete_alternate_stream_from_json() {
    INPUT="$1"
    TO_DELETE=$(jq -r ".deleteAlternateStream" < "$INPUT")
    rm -f "${MYMPD_PLS_DIR}/${TO_DELETE}"
}

m3u_to_json() {
    LINE="$1"
    if [ "${LINE:0:1}" = "#" ]
    then
        INFO="${LINE:1}"
        KEY=${INFO%%:*}
        VALUE=${INFO#*:}
        if [ "$KEY" = "EXTGENRE" ]
        then
            VALUE=$(jq -c -R 'split(", ")' <<< "$VALUE")
        elif [ "$KEY" = "BITRATE" ]
        then
            #enforce bitrate value
            [ "$VALUE" = "" ] && VALUE="0"
        else
            VALUE=$(jq -n --arg value "$VALUE" '$value')
        fi
        printf "\"${m3ufields_map[$KEY]:-}\":%s" "$VALUE"
    else
        VALUE=$(jq -n --arg value "$LINE" '$value')
        printf "\"StreamUri\":%s" "$VALUE"
    fi
}

parse_alternative_streams() {
    S="$1"
    RADIO="$2"
    CODEC=""
    BITRATE=""
    URI=""
    NAME=""
    while read -r LINE
    do
        if [ "${LINE:0:1}" = "#" ]
        then
            INFO="${LINE:1}"
            KEY=${INFO%%:*}
            VALUE=${INFO#*:}
            case "$KEY" in
                CODEC)
                    CODEC=$(jq -n --arg value "$VALUE" '$value')
                    ALL_CODECS["$VALUE"]="1"
                    ;;
                BITRATE)
                    BITRATE="$VALUE"
                    ALL_BITRATES["$VALUE"]="1"
                    ;;
            esac
        else
            NAME=$(sed -E -e 's/[<>/.:?&$!#\\|;=]/_/g' <<< "$LINE")
            URI=$(jq -n --arg value "$LINE" '$value')
        fi
    done < "$S"
    #print to index
    printf "\"%s\":{\"StreamUri\":%s,\"Codec\":%s,\"Bitrate\":%s}" "$NAME" "$URI" "$CODEC" "$BITRATE"
    #create m3u for alternative stream
    head -9 "$RADIO" > "$PLS_DIR/$NAME.m3u"
    cat "$S" >> "$PLS_DIR/$NAME.m3u"
    rm "$S"
}

move_compress_changed() {
    FILE=$1
    SRC_CHKSUM=$(md5sum "${FILE}.tmp" | cut -d" " -f1)
    if [ -f "$FILE" ]
    then
        DST_CHKSUM=$(md5sum "${FILE}" | cut -d" " -f1)
    else
        DST_CHKSUM=""
    fi
    if [ "$SRC_CHKSUM" != "$DST_CHKSUM" ]
    then
        mv "$FILE.tmp" "$FILE"
        gzip -9 -c "$FILE" > "$FILE".gz
    else
        rm "$FILE.tmp"
    fi
}

create() {
    echo "Cleaning up"
    rm -fr "$PLS_DIR"
    mkdir "$PLS_DIR"
    rm -fr "$PICS_DIR"
    mkdir "$PICS_DIR"

    echo "Copy moode webradios"
    cleanup_genres "${MOODE_PLS_DIR}"
    cp "${MOODE_PICS_DIR}"/* "${PICS_DIR}"
    cp "${MOODE_PLS_DIR}"/* "${PLS_DIR}"

    echo "Copy myMPD webradios"
    cleanup_genres "${MYMPD_PLS_DIR}"
    cp "${MYMPD_PICS_DIR}"/* "${PICS_DIR}"
    cp "${MYMPD_PLS_DIR}"/* "${PLS_DIR}"

    echo "Creating json index"
    rm -f "${INDEXFILE}.tmp"
    exec 3<> "${INDEXFILE}.tmp"
    printf "{" >&3
    WEBRADIO_COUNT=0
    for F in "$PLS_DIR"/*.m3u
    do
        FILENAME=${F##*/}
        [ "$WEBRADIO_COUNT" -gt 0 ] && printf "," >&3
        printf "\"%s\":{" "$FILENAME" >&3
        LINE_COUNT=0
        declare -A ALL_CODECS=()
        declare -A ALL_BITRATES=()
        while read -r LINE
        do
            KEY=${LINE%%:*}
            [ "$LINE" = "#EXTM3U" ] && continue
            [ "$KEY" = "#EXTINF" ] && continue
            [ "$LINE" = "" ] && continue
            [ "$LINE_COUNT" -gt 0 ] && printf "," >&3
            m3u_to_json "$LINE" >&3
            VALUE=${LINE#*:}
            [ "$KEY" = "CODEC" ] && [ "$VALUE" != "" ] && ALL_CODECS["$VALUE"]="1"
            [ "$KEY" = "BITRATE" ] && [ "$VALUE" != "" ] && ALL_BITRATES["$VALUE"]="1"
            LINE_COUNT=$((LINE_COUNT+1))
        done < "$F"
        #alternative streams
        printf ",\"alternativeStreams\":{" >&3
        if [ "$(echo "$F".*)" != "$F.*" ]
        then
            FILE_COUNT=0
            for S in "$F."*
            do
                [ "$FILE_COUNT" -gt 0 ] && printf "," >&3
                parse_alternative_streams "$S" "$F" >&3
                FILE_COUNT=$((FILE_COUNT+1))
            done
        fi
        printf "},\"allCodecs\":[" >&3
        CODEC_COUNT=0
        for C in "${!ALL_CODECS[@]}"
        do
            [ "$CODEC_COUNT" -gt 0 ] && printf "," >&3
            printf "\"%s\"" "$C" >&3
            CODEC_COUNT=$((CODEC_COUNT+1))
        done
        printf "],\"allBitrates\":[" >&3
        BITRATE_COUNT=0
        BITRATE_HIGHEST=0
        for B in "${!ALL_BITRATES[@]}"
        do
            [ "$BITRATE_COUNT" -gt 0 ] && printf "," >&3
            printf "%s" "$B" >&3
            BITRATE_COUNT=$((BITRATE_COUNT+1))
            [ $B -gt $BITRATE_HIGHEST ] && BITRATE_HIGHEST=$B
        done
        printf "],\"highestBitrate\":%s" "$BITRATE_HIGHEST" >&3
        printf "}" >&3
        WEBRADIO_COUNT=$((WEBRADIO_COUNT+1))
        printf "."
    done
    printf "}" >&3
    exec 3>&-
    echo ""
    #validate the json file
    if jq < "${INDEXFILE}.tmp" > /dev/null
    then
        echo "${WEBRADIO_COUNT} webradios in index"
        #create other index files
        jq -r '.[] | .Language' "${INDEXFILE}.tmp" | sort -u | \
            jq -R -s -c 'split("\n") | .[0:-1]' > "$LANGFILE.tmp"
        LANGUAGES_COUNT=$(jq -r '.[]' "$LANGFILE.tmp" | wc -l)
        echo "${LANGUAGES_COUNT} languages in index"

        jq -r '.[] | .Country' "${INDEXFILE}.tmp" | sort -u | \
            jq -R -s -c 'split("\n") | .[0:-1]' > "$COUNTRYFILE.tmp"
        COUNTRIES_COUNT=$(jq -r '.[]' "$COUNTRYFILE.tmp" | wc -l)
        echo "${COUNTRIES_COUNT} countries in index"

        jq -r '.[] | .Genre | .[]' "${INDEXFILE}.tmp" | sort -u | \
            jq -R -s -c 'split("\n") | .[0:-1]' > "$GENREFILE.tmp"
        GENRES_COUNT=$(jq -r '.[]' "$GENREFILE.tmp" | wc -l)
        echo "${GENRES_COUNT} genres in index"

        jq -r '.[] | .Codec' "${INDEXFILE}.tmp" | sort -u | grep -v -P '^\s*$' | \
            jq -R -s -c 'split("\n") | .[0:-1]' > "$CODECFILE.tmp"
        CODECS_COUNT=$(jq -r '.[]' "$CODECFILE.tmp" | wc -l)
        echo "${CODECS_COUNT} codecs in index"

        jq -r '.[] | .Bitrate' "${INDEXFILE}.tmp" | sort -u -g | grep -v -P '^(\s*|0)$' | \
            jq -R -s -c 'split("\n") | .[0:-1]' > "$BITRATEFILE.tmp"
        BITRATES_COUNT=$(jq -r '.[]' "$BITRATEFILE.tmp" | wc -l)
        echo "${BITRATES_COUNT} bitrates in index"

        #create combined json
        printf "{\"timestamp\":%s,\"webradios\":" "$(date +%s)" > "${INDEXFILE_COMBINED}.tmp"
        tr -d '\n' < "${INDEXFILE}.tmp" >> "${INDEXFILE_COMBINED}.tmp"
        printf ",\"totalWebradios\":%s," "$WEBRADIO_COUNT" >> "${INDEXFILE_COMBINED}.tmp"

        printf "\"webradioLanguages\":" >> "${INDEXFILE_COMBINED}.tmp"
        tr -d '\n' < "${LANGFILE}.tmp" >> "${INDEXFILE_COMBINED}.tmp"
        printf ",\"totalWebradioLanguages\":%s," "$LANGUAGES_COUNT" >> "${INDEXFILE_COMBINED}.tmp"

        printf "\"webradioCountries\":" >> "${INDEXFILE_COMBINED}.tmp"
        tr -d '\n' < "${COUNTRYFILE}.tmp" >> "${INDEXFILE_COMBINED}.tmp"
        printf ",\"totalwebradioCountries\":%s," "$COUNTRIES_COUNT" >> "${INDEXFILE_COMBINED}.tmp"

        printf "\"webradioCodecs\":" >> "${INDEXFILE_COMBINED}.tmp"
        tr -d '\n' < "${CODECFILE}.tmp" >> "${INDEXFILE_COMBINED}.tmp"
        printf ",\"totalwebradioCodecs\":%s," "$CODECS_COUNT" >> "${INDEXFILE_COMBINED}.tmp"

        printf "\"webradioBitrates\":" >> "${INDEXFILE_COMBINED}.tmp"
        tr -d '\n' < "${BITRATEFILE}.tmp" >> "${INDEXFILE_COMBINED}.tmp"
        printf ",\"totalwebradioBitrates\":%s," "$BITRATES_COUNT" >> "${INDEXFILE_COMBINED}.tmp"

        printf "\"webradioGenres\":" >> "${INDEXFILE_COMBINED}.tmp"
        tr -d '\n' < "${GENREFILE}.tmp" >> "${INDEXFILE_COMBINED}.tmp"
        printf ",\"totalWebradioGenres\":%s," "$GENRES_COUNT" >> "${INDEXFILE_COMBINED}.tmp"

        printf "\"webradioStatus\":" >> "${INDEXFILE_COMBINED}.tmp"
        tr -d '\n' < "${STATUSFILE}" >> "${INDEXFILE_COMBINED}.tmp"

        printf "}\n" >> "${INDEXFILE_COMBINED}.tmp"
        #create javascript index
        printf "const webradiodb=" > "${INDEXFILE_JS}.tmp"
        tr -d '\n' < "${INDEXFILE_COMBINED}.tmp" >> "${INDEXFILE_JS}.tmp"
        printf ";\n" >> "${INDEXFILE_JS}.tmp"
        #finished, move all files in place
        move_compress_changed "$INDEXFILE"
        move_compress_changed "$LANGFILE"
        move_compress_changed "$COUNTRYFILE"
        move_compress_changed "$GENREFILE"
        move_compress_changed "$CODECFILE"
        move_compress_changed "$BITRATEFILE"
        move_compress_changed "$INDEXFILE_JS"
        move_compress_changed "$INDEXFILE_COMBINED"
    else
        echo "Error creating index"
        rm "${INDEXFILE}.tmp"
        exit 1
    fi
}

check_duplicates() {
    #duplicate uris
    DUP=$(grep -h -v -P '^(#|s+)' docs/db/webradios/* | sort | uniq -d)
    if [ "$DUP" != "" ]
    then
        echo "Duplicate uris found"
        echo "$DUP"
        exit 1
    fi
    #duplicate names
    DUP=$(jq -r '.[] | .Name' docs/db/index/webradios.min.json | sort | uniq -d)
    if [ "$DUP" != "" ]
    then
        echo "Duplicate names found"
        echo "$DUP"
        exit 1
    fi
    for F in sources/moode-webradios/*.m3u
    do
        G=$(basename "$F")
        if [ -f "sources/mympd-webradios/$G.m3u" ]
        then
            echo "Duplicate m3u found"
            echo "$G.m3u"
            exit 1
        fi
    done
    exit 0
}

check_images_all() {
    check_images "$PLS_DIR" "$PICS_DIR"
    check_images "$MOODE_PLS_DIR" "$MOODE_PICS_DIR"
    check_images "$MYMPD_PLS_DIR" "$MYMPD_PICS_DIR"
}

check_images() {
    P_DIR=$1
    I_DIR=$2
    rc=0
    #check images for playlists
    for F in "$P_DIR/"*.m3u
    do
        G=$(grep "#EXTIMG" "$F" | cut -d: -f2)
        if [ "$(file --mime-type "$I_DIR/${G}")" != "$I_DIR/${G}: image/webp" ]
        then 
            if [ -f "$I_DIR/${G}" ]
            then
                echo "Invalid image for $G"
                rm -f "$I_DIR/${G}"
            else
                echo "Missing image for $G"
            fi
            rc=1
        fi
    done
    #check for obsolet images
    for F in "$I_DIR/"*.webp
    do
        G=$(basename "$F" .webp)
        if [ ! -f "$P_DIR/${G}.m3u" ]
        then
            echo "Obsolet image: $F"
            rm -f "$F"
            rc=1
        fi
    done
    return "$rc"
}

update_format() {
    M3U_FILE="$1"
    CUR_BITRATE=$(grep "^#BITRATE:" "$M3U_FILE" | cut -d: -f2)
    CUR_CODEC=$(grep "^#CODEC:" "$M3U_FILE" | cut -d: -f2)
    if [ -n "$CUR_BITRATE" ] && [ -n "$CUR_CODEC" ]
    then
        #only update if no format is defined
        return 0
    fi
    STREAM=$(grep -v "#" "$M3U_FILE" | head -1)
    INFO=$(ffprobe -loglevel quiet -print_format json -show_format "$STREAM")
    rc=$?
    if [ "$rc" != "0" ]
    then
        echo "Error getting streaminfo for \"$M3U_FILE\""
        ffprobe -loglevel error "$STREAM"
        return 1
    fi
    NEW_BITRATE=$(jq -r ".format.tags.\"icy-br\"" <<< "$INFO")
    if [ "$NEW_BITRATE" = "null" ]
    then
        NEW_BITRATE=$(jq -r ".format.bit_rate" <<< "$INFO")
        [ "$NEW_BITRATE" != "null" ] && NEW_BITRATE=${NEW_BITRATE::-3}
    fi
    if [ -z "$NEW_BITRATE" ] || [ "$NEW_BITRATE" = "null" ]
    then
        NEW_BITRATE=0
    fi
    NEW_CODEC=$(jq -r ".format.format_name" <<< "$INFO" | tr '[:lower:]' '[:upper:]')
    if [ -z "$NEW_CODEC" ] || [ "$NEW_CODEC" = "NULL" ]
    then
        echo "Empty codec for \"$M3U_FILE\""
        return 1
    fi
    if [ "$CUR_BITRATE" != "$NEW_BITRATE" ] || [ "$CUR_CODEC" != "$NEW_CODEC" ]
    then
        echo "Codec or bitrate changed, updating \"$M3U_FILE\""
        sed -i -e "s/^#CODEC:.*/#CODEC:$NEW_CODEC/" -e "s/^#BITRATE:.*/#BITRATE:$NEW_BITRATE/" "$M3U_FILE"
    fi
    return 0
}

update_format_all() {
    rc=0
    for F in "$MYMPD_PLS_DIR/"*
    do
        if ! update_format "$F"
        then
            rc=1
        fi
    done
    for F in "$MOODE_PLS_DIR/"*
    do
        if ! update_format "$F"
        then
            rc=1
        fi
    done
    return $rc
}

rename_alternate_streams() {
    for F in "$MYMPD_PLS_DIR/"*.m3u.*
    do
        BITRATE=$(grep "^#BITRATE:" "$F" | cut -d: -f2)
        CODEC=$(grep "^#CODEC:" "$F" | cut -d: -f2)
        BASE=${F%%.m3u*}
        NEW_NAME="$BASE.m3u.$CODEC.$BITRATE"
        if [ "$F" != "$NEW_NAME" ]
        then
            echo "$F -> $NEW_NAME"
        fi
    done
}

check_stream() {
    M3U_FILE="$1"
    STREAM=$(grep -v "#" "$M3U_FILE" | head -1)
    if ! ffprobe -loglevel error -rw_timeout 10000000 "$STREAM"
    then
        echo "Error getting streaminfo for \"$M3U_FILE\""
        return 1
    fi
    return 0
}

check_stream_all_json() {
    printf "Checking all streams"
    rc=0
    exec 3<> "${STATUSFILE}.tmp"
    printf "{" >&3
    ENTRY_COUNT=0
    for F in "$PLS_DIR/"*
    do
        M3U=$(basename "$F")
        if grep -q "$M3U" mappings/check-ignore
        then
            echo "Skipping $M3U"
            continue
        fi
        STREAM=$(grep -v "#" "$F" | head -1)
        RETRY_COUNT=0
        while :
        do
            OUT=$(ffprobe -loglevel error -rw_timeout 10000000 "$STREAM" 2>&1)
            if [ "$?" != "0" ]
            then
                if [ $RETRY_COUNT -eq 5 ]
                then
                    [ "$ENTRY_COUNT" -gt 0 ] && printf "," >&3
                    OUT=$(jq -n --arg value "$OUT" '$value')
                    DATE=$(date +%Y-%m-%d)
                    ERROR_COUNT=$(jq ".\"$M3U\".count" docs/db/index/status.min.json)
                    [ "$ERROR_COUNT" = "null" ] && ERROR_COUNT=0
                    ERROR_COUNT=$((ERROR_COUNT+1))
                    printf "\"%s\":{\"date\":\"%s\",\"count\":%s,\"error\":%s}" "$M3U" "$DATE" "$ERROR_COUNT" "$OUT" >&3
                    echo ""
                    echo "Error getting streaminfo for \"$F\" ($ERROR_COUNT): $OUT"
                    ENTRY_COUNT=$((ENTRY_COUNT+1))
                    break
                else
                    printf "r"
                    sleep 5
                fi
                RETRY_COUNT=$((RETRY_COUNT+1))
            else
                printf "."
                break
            fi
        done
    done
    printf "}" >&3
    exec 3>&-
    move_compress_changed "${STATUSFILE}"
}

#get action
if [ -z "${1+x}" ]
then
  ACTION=""
else
  ACTION="$1"
fi

case "$ACTION" in
    add_alternate_stream_from_json)
        add_alternate_stream_from_json "$2"
        ;;
    add_radio)
        add_radio
        ;;
    add_radio_from_json)
        add_radio_from_json "$2"
        ;;
    check_duplicates)
        check_duplicates
        ;;
    check_images_all)
        check_images_all
        ;;
    check_stream)
        check_stream "$2"
        exit $?
        ;;
    check_stream_all_json)
        check_stream_all_json
        ;;
    cleanup_genres)
        cleanup_genres "$2"
        ;;
    create)
        create
        ;;
    delete_alternate_stream_from_json)
        delete_alternate_stream_from_json "$2"
        ;;
    delete_radio_from_json)
        delete_radio_from_json "$2"
        ;;
    download_image)
        download_image "$2" "$3"
        ;;
    modify_radio_from_json)
        modify_radio_from_json "$2"
        ;;
    rename_alternate_streams)
        rename_alternate_streams
        ;;
    resize_image)
        resize_image "$2"
        ;;
    serve)
        cd docs || exit 1
        bundle exec jekyll serve --livereload --watch
        ;;
    sync_moode)
        sync_moode
        ;;
    update_format)
        update_format "$2"
        exit $?
        ;;
    update_format_all)
        update_format_all
        exit $?
        ;;
    *)
        echo "Usage: $0 <action>"
        echo ""
        echo "Actions:"
        echo "  add_alternate_stream_from_json <json file>:"
        echo "    adds an alternate stream to an existing webradio"
        echo "  add_radio:"
        echo "    interactively adds a webradio to sources/mympd-webradios"
        echo "  add_radio_from_json <json file>:"
        echo "    add a webradio from json generated by issue parser"
        echo "  check_duplicates:"
        echo "    checks for duplicates"
        echo "  check_images_all:"
        echo "    checks for missing images"
        echo "  check_stream <m3u>:"
        echo "    checks the stream from m3u"
        echo "  check_stream_all_json:"
        echo "    creates the status.json file"
        echo "  cleanup_genres <dir>:"
        echo "    cleanups the genres"
        echo "  create:"
        echo "    copies playlists and images from sources dir and creates an unified index"
        echo "  delete_alternate_stream_from_json <json file>:"
        echo "    deletes an alternate stream"
        echo "  delete_radio_from_json <json file>:"
        echo "    deletes a webradio from json generated by issue parser"
        echo "  download_image <uri> <dst>:"
        echo "    downloads and converts an image from <uri> to <dst>.webp"
        echo "  modify_radio_from_json <json file>:"
        echo "    modifies a webradio from json generated by issue parser"
        echo "  rename_alternate_streams:"
        echo "    renames alternative streams to basename.codec.bitrate"
        echo "  resize_image <image>:"
        echo "    resizes the image to 400x400 pixels"
        echo "  serve:"
        echo "    starts the local jekyll webserver"
        echo "  sync_moode:"
        echo "    syncs the moode audio webradios to sources/moode-webradios, downloads"
        echo "    and converts the images to webp"
        echo "  update_format <m3u>:"
        echo "    if codec and bitrate is empty get it by connecting to stream"
        echo "  update_format_all:"
        echo "    calls update_format for all m3u files"
        echo ""
        ;;
esac
