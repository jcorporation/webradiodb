#!/bin/bash
#
#SPDX-License-Identifier: GPL-3.0-or-later
#myMPD (c) 2021 Juergen Mang <mail@jcgames.de>
#https://github.com/jcorporation/mympd

PICS_DIR="pics"
PLS_DIR="webradios"
MOODE_PICS_DIR="sources/moode-pics"
MOODE_PLS_DIR="sources/moode-webradios"
MYMPD_PICS_DIR="sources/mympd-pics"
MYMPD_PLS_DIR="sources/mympd-webradios"

sync_moode() {
    echo "Syncing moode audio webradios"
    # fields of cfg_radios are:
    # id, station, name, type, logo, genre, broadcaster, language, country, region, bitrate, format, geo_fenced, home_page, reserved2
    MOODE_DB="https://raw.githubusercontent.com/moode-player/moode/master/var/local/www/db/moode-sqlite3.db.sql"
    MOODE_IMAGES="https://raw.githubusercontent.com/moode-player/moode/master/var/local/www/imagesw/radio-logos/"

    #start with clean output dirs
    rm -fr "$MOODE_PLS_DIR" 
    mkdir "$MOODE_PLS_DIR"
    rm -fr "$MOODE_PICS_DIR"
    mkdir "$MOODE_PICS_DIR"

    while read -r LINE
    do
        # LINE is: station, name, genre, language, country, homepage

        #create the same plist name as myMPD
        PLIST=$(csvcut -c 1 <<< "$LINE" | \
            sed -E -e 's/[<>/.:?$!#\\|]/_/g')

        #extract fields
        STATION=$(csvcut -c 1 <<< "$LINE" | sed -e s/\"//g)
        NAME=$(csvcut -c 2 <<< "$LINE" | sed -e s/\"//g)
        IMAGE=$(csvcut -c 3 <<< "$LINE" | sed -e s/\"//g)
        GENRE=$(csvcut -c 4 <<< "$LINE" | sed -e s/\"//g)
        LANGUAGE=$(csvcut -c 5 <<< "$LINE" | sed -e s/\"//g)
        COUNTRY=$(csvcut -c 6 <<< "$LINE" | sed -e s/\"//g)
        HOMEPAGE=$(csvcut -c 7 <<< "$LINE" | sed -e s/\"//g)

        #get images 
        if [ "$IMAGE" = "local" ]
        then
            wget -q "${MOODE_IMAGES}${NAME}.jpg" \
                -O "${MOODE_PICS_DIR}/${PLIST}.jpg"
            IMAGE="${PLIST}.jpg"
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
$STATION

EOL

    done < <(wget -q "$MOODE_DB" -O - | \
        grep "INSERT INTO cfg_radio" | \
        awk -F "VALUES " '{print $2}' | \
        sed -e 's/^(//' -e 's/);//' -e "s/', /',/g" -e "s/, '/,'/g"  | \
        csvcut -q \' -c 2,3,5,6,8,9,14 |
        grep -v -E "(OFFLINE|zx reserved 499)")
}

add_radio() {
    read -p "URI: " URI
    PLIST=$(sed -E -e 's/[<>/.:?$!#\\|]/_/g' <<< "$URI")
    # write ext m3u with custom myMPD fields
        cat > "${MYMPD_PLS_DIR}/${PLIST}.m3u" << EOL
#EXTM3U
#EXTINF:-1,webradio name
#EXTGENRE:webradio genre
#PLAYLIST:webradio name
#EXTIMG:${PLIST}.webp
#HOMEPAGE:homepage
#COUNTRY:country
#LANGUAGE:language
$URI

EOL
    echo ""
    echo "Playlist file ${MYMPD_PLS_DIR}/$PLIST.m3u created."
    echo "Edit it to add details."
    echo "You shoud add an image with the name ${MYMPD_PLS_DIR}/$PLIST.webp"
    echo "or replace the #EXTIMG tag with an url to the image."
    echo ""
}

create() {
    echo "Cleaning up"
    rm -fr "$PLS_DIR" 
    mkdir "$PLS_DIR"
    rm -fr "$PICS_DIR"
    mkdir "$PICS_DIR"

    echo "Copy moode webradios"
    cp "${MOODE_PLS_DIR}"/* "${PLS_DIR}"
    #convert jpg to webp for smaller filesize
    for F in "${MOODE_PICS_DIR}"/*.jpg
    do
        NEW_NAME=$(basename $F .jpg)
        convert "$F" "${PICS_DIR}/${NEW_NAME}.webp"
    done

    echo "Copy myMPD webradios"
    cp "${MYMPD_PICS_DIR}"/* "${PICS_DIR}"
    cp "${MYMPD_PLS_DIR}"/* "${PLS_DIR}"
}

case "$1" in
    sync_moode)
        sync_moode
        ;;
    add_radio)
        add_radio
        ;;
    create)
        create
        ;;
    *)
        echo "Usage: $0 <action>"
        echo ""
        echo "Actions:"
        echo "  add_radio:  interactively adds an webradio to sources"
        echo "  create:     copies pls and images from sources dir"
        echo "  sync_moode: syncs the moode audio webradios to sources/moode-webradios"
        echo ""
        ;;
esac
