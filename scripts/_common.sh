#!/bin/bash

#=================================================
# COMMON VARIABLES AND CUSTOM HELPERS
#=================================================

# The formats of the two mounts.  The publisher of the Mopidy app produces
# exactly these, and the fallback streams have to match them: Icecast only
# hands a mount over to its fallback when the content types are the same.
MP3_RATE=48000
OGG_RATE=96000
MP3_BITRATE=128k

_icecast_prepare_mime_types() {
    # Icecast's own mime type table maps .ogg to "audio/ogg", but the
    # publisher announces the Ogg stream as "application/ogg".  Icecast only
    # hands a mount over to a fallback stream when the content types match,
    # so without this the listeners would stay on the fallback instead of
    # getting the live stream.
    local source="/etc/icecast2/mime.types"
    local destination="/etc/icecast2/mime.types.ynh"

    if [ -f "$source" ]; then
        cp -f "$source" "$destination"
    else
        printf 'audio/mpeg mp3 mpga\napplication/ogg oga ogg opus spx\naudio/x-flac flac\n' > "$destination"
    fi

    # Map .ogg to application/ogg
    sed -i 's|^audio/ogg\(.*\)$|application/ogg\1|' "$destination"

    if ! grep -q "^application/ogg" "$destination"; then
        printf 'application/ogg oga ogg opus spx\n' >> "$destination"
    fi

    chmod 644 "$destination"
}

_icecast_make_fallbacks() {
    # The fallback streams are played while Mopidy switches track.  They have
    # to have the same format as the live streams, otherwise the players have
    # to re-initialise their decoder and the stream appears to break.
    local webroot="/usr/share/icecast2/web"

    mkdir -p "$webroot"

    ffmpeg -y -loglevel error -f lavfi -i "anullsrc=r=$MP3_RATE:cl=stereo" \
        -t 30 -c:a libmp3lame -b:a "$MP3_BITRATE" -ac 2 \
        "$webroot/silence.mp3"

    ffmpeg -y -loglevel error -f lavfi -i "anullsrc=r=$OGG_RATE:cl=stereo" \
        -t 30 -c:a flac -ac 2 \
        "$webroot/silence.ogg"

    chmod 644 "$webroot/silence.mp3" "$webroot/silence.ogg"
}

_icecast_disable_debian_service() {
    # The Debian package ships its own icecast2.service, which would fight
    # over the port with ours.  We run the server with our own unit and our
    # own configuration file.
    if systemctl list-unit-files icecast2.service >/dev/null 2>&1; then
        systemctl stop icecast2.service 2>/dev/null || true
        systemctl disable icecast2.service 2>/dev/null || true
    fi
}
