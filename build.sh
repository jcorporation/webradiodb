#!/bin/bash
#
#SPDX-License-Identifier: GPL-3.0-or-later
#myMPD (c) 2021-2022 Juergen Mang <mail@jcgames.de>
#https://github.com/jcorporation/radiodb

PUBLISH_DIR="docs/db"
SOURCES_DIR="sources"
PICS_DIR="${PUBLISH_DIR}/pics"
PLS_DIR="${PUBLISH_DIR}/webradios"
INDEXFILE="${PUBLISH_DIR}/index/webradios.min.json"
INDEXFILE_FORMATED="${PUBLISH_DIR}/index/webradios.json"
INDEXFILE_JS="${PUBLISH_DIR}/index/webradios.min.js"
MOODE_PICS_DIR="${SOURCES_DIR}/moode-pics"
MOODE_PLS_DIR="${SOURCES_DIR}/moode-webradios"
MYMPD_PICS_DIR="${SOURCES_DIR}/mympd-pics"
MYMPD_PLS_DIR="${SOURCES_DIR}/mympd-webradios"

sync_moode() {
    echo "Syncing moode audio webradios"
    # fields of cfg_radios are:
    # id, station, name, type, logo, genre, broadcaster, language, country, region, bitrate, format, geo_fenced, home_page, reserved2
    MOODE_DB="https://raw.githubusercontent.com/moode-player/moode/master/var/local/www/db/moode-sqlite3.db.sql"
    MOODE_IMAGES="https://raw.githubusercontent.com/moode-player/moode/master/var/local/www/imagesw/radio-logos/"

    # start with clean output dirs
    rm -fr "$MOODE_PLS_DIR" 
    mkdir "$MOODE_PLS_DIR"
    mv "$MOODE_PICS_DIR" "${MOODE_PICS_DIR}.old"
    mkdir "$MOODE_PICS_DIR"

    # fetch the sql file and grep the webradio stations and convert it to csv
    I=0
    while read -r LINE
    do
        # LINE is a csv: station, name, genre, language, country, homepage

        # create the same plist name as myMPD
        PLIST=$(csvcut -c 1 <<< "$LINE" | \
            sed -E -e 's/[<>/.:?&$!#\\|]/_/g')

        # extract fields
        STATION=$(csvcut -c 1 <<< "$LINE" | sed -e s/\"//g)
        NAME=$(csvcut -c 2 <<< "$LINE" | sed -e s/\"//g)
        IMAGE=$(csvcut -c 3 <<< "$LINE" | sed -e s/\"//g)
        GENRE=$(csvcut -c 4 <<< "$LINE" | sed -e s/\"//g)
        LANGUAGE=$(csvcut -c 5 <<< "$LINE" | sed -e s/\"//g)
        COUNTRY=$(csvcut -c 6 <<< "$LINE" | sed -e s/\"//g)
        HOMEPAGE=$(csvcut -c 7 <<< "$LINE" | sed -e s/\"//g)

        # get images 
        if [ "$IMAGE" = "local" ]
        then
            if [ -s "${MOODE_PICS_DIR}.old/${PLIST}.webp" ]
            then
                cp "${MOODE_PICS_DIR}.old/${PLIST}.webp" "${MOODE_PICS_DIR}/${PLIST}.webp"
                IMAGE="${PLIST}.webp"
            elif wget -q "${MOODE_IMAGES}${NAME}.jpg" \
                -O "${MOODE_PICS_DIR}/${PLIST}.jpg"
            then
                convert "${MOODE_PICS_DIR}/${PLIST}.jpg" "${MOODE_PICS_DIR}/${PLIST}.webp"
                rm "${MOODE_PICS_DIR}/${PLIST}.jpg"
                resize_image "${MOODE_PICS_DIR}/${PLIST}.webp"
                IMAGE="${PLIST}.webp"
            else
                rm -f "${MOODE_PICS_DIR}/${PLIST}.jpg"
                IMAGE=""
            fi
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
$STATION
EOL
    printf "."
    ((I++))
    done < <(wget -q "$MOODE_DB" -O - | \
        grep "INSERT INTO cfg_radio" | \
        awk -F "VALUES " '{print $2}' | \
        sed -e 's/^(//' -e 's/);//' -e "s/', /',/g" -e "s/, '/,'/g"  | \
        csvcut -q \' -c 2,3,5,6,8,9,14 |
        grep -v -E "(OFFLINE|zx reserved 499)")
    rm -fr "${MOODE_PICS_DIR}.old"
    echo "$I webradios synced"
}

add_radio() {
    # get the uri and write out a skeletion file
    read -p "URI: " URI
    # create the same plist name as myMPD
    PLIST=$(sed -E -e 's/[<>/.:?&$!#\\|]/_/g' <<< "$URI")
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
    URI=$(jq -r ".streamuri" < "$INPUT")
    NAME=$(jq -r ".name" < "$INPUT")
    GENRE=$(jq -r ".genre" < "$INPUT")
    IMAGE=$(jq -r ".image" < "$INPUT")
    HOMEPAGE=$(jq -r ".homepage" < "$INPUT")
    COUNTRY=$(jq -r ".country" < "$INPUT")
    LANGUAGE=$(jq -r ".language" < "$INPUT")
    DESCRIPTION=$(jq -r ".description" < "$INPUT")
    # create the same plist name as myMPD
    PLIST=$(sed -E -e 's/[<>/.:?&$!#\\|]/_/g' <<< "$URI")
    if [ -f "${MYMPD_PLS_DIR}/${PLIST}.m3u" ]
    then
        echo "This webradio already exists."
        exit 1
    fi
    if [ -n "$IMAGE" ]
    then
        if wget "$IMAGE" -O "${MYMPD_PICS_DIR}/${PLIST}.image"
        then
            convert "${MYMPD_PICS_DIR}/${PLIST}.image" "${MYMPD_PICS_DIR}/${PLIST}.webp"
            rm -f "${MYMPD_PICS_DIR}/${PLIST}.image"
            if [ -s "${MYMPD_PICS_DIR}/${PLIST}.webp" ]
            then
                IMAGE="${PLIST}.webp"
                resize_image "${MYMPD_PICS_DIR}/${PLIST}.webp"
            else
                IMAGE=""
            fi
        else
            IMAGE=""
        fi
    fi
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
$URI
EOL
}

resize_image() {
    FILE="$1"
    TOWIDTH="400"
    TOHEIGHT="400"
    TOSIZE="400x400"
    [ -s "$FILE" ] || exit 1
    #get actual size
    SIZE=$(identify "$FILE" | cut -d' ' -f3)
    WIDTH=$(cut -dx -f1 <<< "$SIZE")
    HEIGHT=$(cut -dx -f2 <<< "$SIZE")

    if [ "${SIZE}" != "${TOSIZE}" ]
    then
        if [ "$WIDTH" != "$TOWIDTH" ]
        then
            echo "Resizing $FILE from $SIZE to $TOWIDTH width"
            if convert "$FILE" -resize "$TOWIDTH" "$FILE.resize"
            then
                mv "$FILE.resize" "$FILE"
            else
                echo "Error resizing $FILE"
                rm -f "$FILE.resize"
                return
            fi
        fi
        SIZE=$(identify "$FILE" | cut -d' ' -f3)
        HEIGHT=$(cut -dx -f2 <<< $SIZE)
        if [ "$HEIGHT" -gt "$TOHEIGHT" ]
        then
            echo "Croping $FILE to $TOHEIGHT height"
            if convert "$FILE" -crop "$TOSIZE+0+0" "$FILE.crop"
            then
                mv "$FILE.crop" "$FILE"
            else
                rm -f "$FILE.crop"
                echo "Error croping $FILE"
            fi
        fi
    fi
}

parse_m3u() {
    LINE="$1"
    if [ "${LINE:0:1}" = "#" ]
    then
        INFO="${LINE:1}"
        KEY=$(sed -E 's/([^:]+):.*/\1/' <<< "$INFO")
        VALUE=$(sed -E 's/[^:]+:(.*)/\1/' <<< "$INFO")
        KEY=$(jq -n --arg key "$KEY" '$key')
        VALUE=$(jq -n --arg value "$VALUE" '$value')
        printf "%s:%s" "$KEY" "$VALUE"
    else
        VALUE=$(jq -n --arg value "$LINE" '$value')
        printf "\"streamUri\":%s" "$VALUE"
    fi
}

create() {
    echo "Cleaning up"
    rm -fr "$PLS_DIR"
    mkdir "$PLS_DIR"
    rm -fr "$PICS_DIR"
    mkdir "$PICS_DIR"

    echo "Copy moode webradios"
    cp "${MOODE_PICS_DIR}"/* "${PICS_DIR}"
    cp "${MOODE_PLS_DIR}"/* "${PLS_DIR}"

    echo "Copy myMPD webradios"
    cp "${MYMPD_PICS_DIR}"/* "${PICS_DIR}"
    cp "${MYMPD_PLS_DIR}"/* "${PLS_DIR}"

    echo "Creating json index"
    printf "{" > "$INDEXFILE"
    I=0
    for F in "$PLS_DIR"/*.m3u
    do
        FILENAME=$(basename "$F")
        [ "$I" -gt 0 ] && printf "," >> "$INDEXFILE"
        printf "\"%s\":{" "$FILENAME" >> "$INDEXFILE"
        J=0
        while read -r LINE
        do
            [ "$LINE" = "#EXTM3U" ] && continue
            [ "$LINE" = "" ] && continue
            [ "$J" -gt 0 ] && printf "," >> "$INDEXFILE"
            parse_m3u "$LINE" >> "$INDEXFILE"
            ((J++))
        done < $F
        printf "}" >> "$INDEXFILE"
        ((I++))
        printf "."
    done
    printf "}" >> "$INDEXFILE"
    #create formated json file
    jq < "$INDEXFILE" > "$INDEXFILE_FORMATED"
    #create javascript file
    printf "const webradios=" > "$INDEXFILE_JS"
    cat "$INDEXFILE" | tr -d '\n' >> "$INDEXFILE_JS"
    printf ";"  >> "$INDEXFILE_JS"

    echo "$I webradios in index"
}

case "$1" in
    add_radio)
        add_radio
        ;;
    add_radio_from_json)
        add_radio_from_json "$2"
        ;;
    create)
        create
        ;;
    resize_image)
        resize_image "$2"
        ;;
    sync_moode)
        sync_moode
        ;;
    *)
        echo "Usage: $0 <action>"
        echo ""
        echo "Actions:"
        echo "  add_radio:           interactively adds a webradio to sources/mympd-webradios"
        echo "  add_radio_from_json: add a webradio from json generated by issue parser"
        echo "  create:              copies playlists and images from sources dir and creates an unified index"
        echo "  sync_moode:          syncs the moode audio webradios to sources/moode-webradios, downloads"
        echo "                       and converts the images to webp"
        echo "  resize_image:        resizes the image to 400x400 pixels"
        echo ""
        ;;
esac
