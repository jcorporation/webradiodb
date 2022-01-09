#!/bin/bash
#
#SPDX-License-Identifier: GPL-3.0-or-later
#myMPD (c) 2021-2022 Juergen Mang <mail@jcgames.de>
#https://github.com/jcorporation/radiodb

set -euo pipefail

#print out commands
[ -z "${DEBUG+x}" ] || set -x

PUBLISH_DIR="docs/db"
SOURCES_DIR="sources"
PICS_DIR="${PUBLISH_DIR}/pics"
PLS_DIR="${PUBLISH_DIR}/webradios"

INDEXFILE="${PUBLISH_DIR}/index/webradios.min.json"
INDEXFILE_COMBINED="${PUBLISH_DIR}/index/webradiodb-combined.min.json"
INDEXFILE_JS="${PUBLISH_DIR}/index/webradiodb-combined.min.js"

LANGFILE="${PUBLISH_DIR}/index/languages.min.json"
COUNTRYFILE="${PUBLISH_DIR}/index/countries.min.json"
GENREFILE="${PUBLISH_DIR}/index/genres.min.json"

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
    TO_WIDTH="400"
    TO_HEIGHT="400"
    TO_SIZE="400x400"
    [ -s "$RESIZE_FILE" ] || exit 1
    #get actual size
    CUR_SIZE=$(identify "$RESIZE_FILE" | cut -d' ' -f3)
    CUR_WIDTH=$(cut -dx -f1 <<< "$CUR_SIZE")
    CUR_HEIGHT=$(cut -dx -f2 <<< "$CUR_SIZE")

    if [ "${CUR_SIZE}" != "${TO_SIZE}" ]
    then
        if [ "$CUR_WIDTH" != "$TO_WIDTH" ]
        then
            echo "Resizing $RESIZE_FILE from $CUR_SIZE to $TO_WIDTH width"
            if convert "$RESIZE_FILE" -resize "$TO_WIDTH" "$RESIZE_FILE.resize"
            then
                mv "$RESIZE_FILE.resize" "$RESIZE_FILE"
            else
                echo "Error resizing $RESIZE_FILE"
                rm -f "$RESIZE_FILE.resize"
                return 1
            fi
        fi
        CUR_SIZE=$(identify "$RESIZE_FILE" | cut -d' ' -f3)
        CUR_HEIGHT=$(cut -dx -f2 <<< "$CUR_SIZE")
        if [ "$CUR_HEIGHT" -gt "$TO_HEIGHT" ]
        then
            echo "Croping $RESIZE_FILE to $TO_HEIGHT height"
            if convert "$RESIZE_FILE" -crop "$TO_SIZE+0+0" "$RESIZE_FILE.crop"
            then
                mv "$RESIZE_FILE.crop" "$RESIZE_FILE"
            else
                rm -f "$RESIZE_FILE.crop"
                echo "Error croping $RESIZE_FILE"
                return 1
            fi
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
            elif download_image "${MOODE_IMAGES}${NAME}.jpg" "${MOODE_PICS_DIR}/${PLIST}"
            then
                IMAGE="${PLIST}.webp"
            else
                IMAGE=""
            fi
        elif download_image "${MOODE_IMAGES}${NAME}.jpg" "${MOODE_PICS_DIR}/${PLIST}"
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
$STATION
EOL
    printf "."
    I=$((I+1))
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
    read -r -p "URI: " URI
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
    URI=$(jq -r ".streamuri" < "$INPUT" | head -1 | tr -d '\n')
    NAME=$(jq -r ".name" < "$INPUT" | head -1 | tr -d '\n')
    GENRE=$(jq -r ".genre" < "$INPUT" | head -1 | tr -d '\n' | sed -E -e 's/;\s?/, /g' -e 's/,(\S)/, \1/g')
    IMAGE=$(jq -r ".image" < "$INPUT" | head -1 | tr -d '\n')
    HOMEPAGE=$(jq -r ".homepage" < "$INPUT" | head -1 | tr -d '\n')
    COUNTRY=$(jq -r ".country" < "$INPUT" | head -1 | tr -d '\n')
    LANGUAGE=$(jq -r ".language" < "$INPUT" | head -1 | tr -d '\n')
    DESCRIPTION=$(jq -r ".description" < "$INPUT" | head -1 | tr -d '\n')
    # create the same plist name as myMPD
    PLIST=$(sed -E -e 's/[<>/.:?&$!#\\|]/_/g' <<< "$URI")
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
$URI
EOL
}

modify_radio_from_json() {
    INPUT="$1"
    #Webradio to modify
    MODIFY_URI=$(jq -r ".modifyWebradio" < "$INPUT")
    MODIFY_PLIST=$(sed -E -e 's/[<>/.:?&$!#\\|]/_/g' <<< "$MODIFY_URI")
    if [ ! -f "${MYMPD_PLS_DIR}/${MODIFY_PLIST}.m3u" ]
    then
        if [ -f "${MOODE_PLS_DIR}/${MODIFY_PLIST}.m3u" ]
        then
            echo "Copy webradio from moode to mympd"
            cp "${MOODE_PLS_DIR}/${MODIFY_PLIST}.m3u" "${MYMPD_PLS_DIR}/${MODIFY_PLIST}.m3u"
            [ -f "${MOODE_PICS_DIR}/${MODIFY_PLIST}.webp" ] && \
                cp "${MOODE_PICS_DIR}/${MODIFY_PLIST}.webp" "${MYMPD_PICS_DIR}/${MODIFY_PLIST}.webp"
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
    NEW_PLIST=$(sed -E -e 's/[<>/.:?&$!#\\|]/_/g' <<< "$NEW_URI")
    #Get old values
    OLD_NAME=$(get_m3u_field "${MYMPD_PLS_DIR}/${MODIFY_PLIST}.m3u" "PLAYLIST")
    OLD_GENRE=$(get_m3u_field "${MYMPD_PLS_DIR}/${MODIFY_PLIST}.m3u" "EXTGENRE")
    OLD_IMAGE=$(get_m3u_field "${MYMPD_PLS_DIR}/${MODIFY_PLIST}.m3u" "EXTIMG")
    OLD_HOMEPAGE=$(get_m3u_field "${MYMPD_PLS_DIR}/${MODIFY_PLIST}.m3u" "HOMEPAGE")
    OLD_COUNTRY=$(get_m3u_field "${MYMPD_PLS_DIR}/${MODIFY_PLIST}.m3u" "COUNTRY")
    OLD_LANGUAGE=$(get_m3u_field "${MYMPD_PLS_DIR}/${MODIFY_PLIST}.m3u" "LANGUAGE")
    OLD_DESCRIPTION=$(get_m3u_field "${MYMPD_PLS_DIR}/${MODIFY_PLIST}.m3u" "DESCRIPTION")
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
$NEW_URI
EOL
}

delete_radio_from_json() {
    INPUT="$1"
    URI=$(jq -r ".deleteWebradio" < "$INPUT")
    # create the same plist name as myMPD
    PLIST=$(sed -E -e 's/[<>/.:?&$!#\\|]/_/g' <<< "$URI")
    #only mympd webradios can be deleted
    echo "Deleting webradio ${PLIST}"
    if rm "${MYMPD_PLS_DIR}/${PLIST}.m3u"
    then
        rm -f "${MYMPD_PICS_DIR}/${PLIST}.webp"
    else
        exit 1
    fi
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
        else
            VALUE=$(jq -n --arg value "$VALUE" '$value')
        fi
        printf "\"${m3ufields_map[$KEY]:-}\":%s" "$VALUE"
    else
        VALUE=$(jq -n --arg value "$LINE" '$value')
        printf "\"StreamUri\":%s" "$VALUE"
    fi
}

create() {
    echo "Cleaning up"
    rm -fr "$PLS_DIR"
    mkdir "$PLS_DIR"
    rm -fr "$PICS_DIR"
    mkdir "$PICS_DIR"

    echo "Copy moode webradios"
    cleanup_genres sources/moode-webradios
    cp "${MOODE_PICS_DIR}"/* "${PICS_DIR}"
    cp "${MOODE_PLS_DIR}"/* "${PLS_DIR}"

    echo "Copy myMPD webradios"
    cleanup_genres sources/mympd-webradios
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
        while read -r LINE
        do
            [ "$LINE" = "#EXTM3U" ] && continue
            [ "${LINE%%:*}" = "#EXTINF" ] && continue
            [ "$LINE" = "" ] && continue
            [ "$LINE_COUNT" -gt 0 ] && printf "," >&3
            m3u_to_json "$LINE" >&3
            LINE_COUNT=$((LINE_COUNT+1))
        done < "$F"
        printf "}" >&3
        WEBRADIO_COUNT=$((WEBRADIO_COUNT+1))
        printf "."
    done
    printf "}" >&3
    exec 3>&-
    NEW_CHKSUM=$(md5sum "${INDEXFILE}.tmp" | cut -d" " -f1)
    OLD_CHKSUM=""
    [ -f "${INDEXFILE}" ] && OLD_CHKSUM=$(md5sum "${INDEXFILE}" | cut -d" " -f1)
    echo ""
    if [ "$NEW_CHKSUM" = "$OLD_CHKSUM" ]
    then
        echo "Index not changed."
        rm "${INDEXFILE}.tmp"
        exit 0
    fi
    #validate the json file
    if jq < "${INDEXFILE}.tmp" > /dev/null
    then
        echo "${WEBRADIO_COUNT} webradios in index"
        #create other index files
        jq -r '.[] | .Language' "${INDEXFILE}.tmp" | sort -u | \
            jq -R -s -c 'split("\n") | .[0:-1]' > "$LANGFILE.tmp"
        LANGUAGES_COUNT=$(jq -r '.[] | .Language' "${INDEXFILE}.tmp" | sort -u | wc -l)
        echo "${LANGUAGES_COUNT} languages in index"

        jq -r '.[] | .Country' "${INDEXFILE}.tmp" | sort -u | \
            jq -R -s -c 'split("\n") | .[0:-1]' > "$COUNTRYFILE.tmp"
        COUNTRIES_COUNT=$(jq -r '.[] | .Country' "${INDEXFILE}.tmp" | sort -u | wc -l)
        echo "${COUNTRIES_COUNT} countries in index"

        jq -r '.[] | .Genre | .[]' "${INDEXFILE}.tmp" | sort -u | \
            jq -R -s -c 'split("\n") | .[0:-1]' > "$GENREFILE.tmp"
        GENRES_COUNT=$(jq -r '.[] | .Genre | .[]' "${INDEXFILE}.tmp" | sort -u | wc -l)
        echo "${GENRES_COUNT} genres in index"

        #create combined json
        printf "{\"timestamp\":%s, \"webradios\":" "$(date +%s)" > "${INDEXFILE_COMBINED}.tmp"
        tr -d '\n' < "${INDEXFILE}.tmp" >> "${INDEXFILE_COMBINED}.tmp"
        printf ",\"totalWebradios\":%s," "$WEBRADIO_COUNT" >> "${INDEXFILE_COMBINED}.tmp"

        printf "\"webradioLanguages\":" >> "${INDEXFILE_COMBINED}.tmp"
        tr -d '\n' < "${LANGFILE}.tmp" >> "${INDEXFILE_COMBINED}.tmp"
        printf ",\"totalWebradioLanguages\":%s," "$LANGUAGES_COUNT" >> "${INDEXFILE_COMBINED}.tmp"

        printf "\"webradioCountries\":" >> "${INDEXFILE_COMBINED}.tmp"
        tr -d '\n' < "${COUNTRYFILE}.tmp" >> "${INDEXFILE_COMBINED}.tmp"
        printf ",\"totalwebradioCountries\":%s," "$COUNTRIES_COUNT" >> "${INDEXFILE_COMBINED}.tmp"

        printf "\"webradioGenres\":" >> "${INDEXFILE_COMBINED}.tmp"
        tr -d '\n' < "${GENREFILE}.tmp" >> "${INDEXFILE_COMBINED}.tmp"
        printf ",\"totalWebradioGenres\":%s" "$GENRES_COUNT" >> "${INDEXFILE_COMBINED}.tmp"

        printf "}\n" >> "${INDEXFILE_COMBINED}.tmp"
        #create javascript index
        printf "const webradiodb=" > "${INDEXFILE_JS}.tmp"
        tr -d '\n' < "${INDEXFILE_COMBINED}.tmp" >> "${INDEXFILE_JS}.tmp"
        printf ";\n" >> "${INDEXFILE_JS}.tmp"
        #finished, move all files in place
        mv "$INDEXFILE.tmp" "$INDEXFILE"
        mv "${LANGFILE}.tmp" "$LANGFILE"
        mv "${COUNTRYFILE}.tmp" "$COUNTRYFILE"
        mv "${GENREFILE}.tmp" "$GENREFILE"
        mv "${INDEXFILE_JS}.tmp" "$INDEXFILE_JS"
        mv "${INDEXFILE_COMBINED}.tmp" "$INDEXFILE_COMBINED"
    else
        echo "Error creating index"
        rm "${INDEXFILE}.tmp"
        exit 1
    fi
}

check_images() {
    rc=0
    for F in docs/db/webradios/*.m3u
    do
        G=$(basename "$F" .m3u)
        if [ "$(file --mime-type "docs/db/pics/${G}.webp")" != "docs/db/pics/${G}.webp: image/webp" ]
        then 
            if [ -f "docs/db/pics/${G}.webp" ]
            then
                echo "Invalid image for $G"
                rm -f "docs/db/pics/${G}.webp"
            else
                echo "Missing image for $G"
            fi
            rc=1
        fi
    done
    exit "$rc"
}

#get action
if [ -z "${1+x}" ]
then
  ACTION=""
else
  ACTION="$1"
fi

case "$ACTION" in
    add_radio)
        add_radio
        ;;
    add_radio_from_json)
        add_radio_from_json "$2"
        ;;
    check_images)
        check_images
        ;;
    cleanup_genres)
        cleanup_genres "$2"
        ;;
    create)
        create
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
        echo "  add_radio:"
        echo "    interactively adds a webradio to sources/mympd-webradios"
        echo "  add_radio_from_json <json file>:"
        echo "    add a webradio from json generated by issue parser"
        echo "  check_images:"
        echo "    checks for missing images"
        echo "  cleanup_genres <dir>:"
        echo "    cleanups the genres"
        echo "  create:"
        echo "    copies playlists and images from sources dir and creates an unified index"
        echo "  delete_radio_from_json <json file>:"
        echo "    deletes a webradio from json generated by issue parser"
        echo "  download_image <uri> <dst>:"
        echo "    downloads and converts an image from <uri> to <dst>.webp"
        echo "  modify_radio_from_json <json file>:"
        echo "    modifies a webradio from json generated by issue parser"
        echo "  resize_image <image>:"
        echo "    resizes the image to 400x400 pixels"
        echo "  sync_moode:"
        echo "    syncs the moode audio webradios to sources/moode-webradios, downloads"
        echo "    and converts the images to webp"
        echo ""
        ;;
esac
