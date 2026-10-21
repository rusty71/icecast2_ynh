#!/bin/bash

#=================================================
# COMMON VARIABLES AND CUSTOM HELPERS
#=================================================

# The formats of the two mounts.  The publisher of the Mopidy app produces
# exactly these, and the fallback streams have to match them: Icecast only
# hands a mount over to its fallback when the content types are the same.
# The configuration file of Icecast.
icecast_config_file="/etc/icecast2/icecast.xml"

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

_icecast_make_certificate() {
    # Icecast 2.4 reads the private key from the same file as the
    # certificate, so the certificate of the domain and its key are put
    # together here.  The file is only readable by the group ssl-cert, which
    # the service is a member of.
    local certs="/etc/yunohost/certs/$domain"
    local target="/etc/icecast2/icecast.pem"

    if [ ! -f "$certs/crt.pem" ] || [ ! -f "$certs/key.pem" ]; then
        ynh_print_warn "No certificate for $domain, the port stays plain http"
        return 0
    fi

    cat "$certs/crt.pem" "$certs/key.pem" > "$target"
    chown root:ssl-cert "$target"
    chmod 640 "$target"
}

_icecast_deploy_landing_page() {
    # The page with the player.  It is served by Icecast itself, on its
    # port, so the player talks to the streams directly and not through
    # the reverse proxy of the domain.
    local webroot="/usr/share/icecast2/web"

    public_port="${public_port:-$port}"
    mkdir -p "$webroot"
    ynh_config_add --template="landing.html" --destination="$webroot/landing.html"
    chmod 644 "$webroot/landing.html"
}

_icecast_expose_port_enabled() {
    # Whether the streaming port is exposed.  YunoHost passes the answer to a
    # boolean question as "1" or "0", the config panel uses "true" and
    # "false", so all of them are accepted here.
    case "${expose_port:-}" in
        1|true|True|TRUE|yes|on) echo "true" ;;
        *) echo "false" ;;
    esac
}

_icecast_bind_address() {
    # The address Icecast listens on.  With 127.0.0.1 the streams are only
    # reachable through the nginx reverse proxy, with :: the port is open as
    # well and the listeners can connect directly.
    #
    # "::" and not "0.0.0.0": the server has a public IPv6 address and the
    # name of the domain resolves to it, so a client that tries IPv6 first
    # would be refused.  As long as net.ipv6.bindv6only is 0 (the default),
    # a socket on :: takes the IPv4 connections as well.
    if [ "$(_icecast_expose_port_enabled)" = "true" ]; then
        echo "::"
    else
        echo "::1"
    fi
}

_icecast_current_bind_address() {
    # The address the running configuration uses.
    if [ -f "$icecast_config_file" ]; then
        local address
        address="$(sed -n 's|.*<bind-address>\([^<]*\)</bind-address>.*|\1|p' \
            "$icecast_config_file" | head -1)"
        case "$address" in
            "::"|"0.0.0.0") echo "true" ;;
            *) echo "false" ;;
        esac
    else
        echo "false"
    fi
}

_icecast_firewall() {
    # Open the port in the firewall when it is exposed, close it otherwise.
    if [ "$(_icecast_expose_port_enabled)" = "true" ]; then
        ynh_print_info "Opening the port $port in the firewall..."
        ynh_hide_warnings yunohost firewall allow --no-upnp TCP "$port"
    else
        ynh_hide_warnings yunohost firewall disallow TCP "$port" \
            || ynh_print_warn "Could not close the port $port in the firewall"
    fi
}
