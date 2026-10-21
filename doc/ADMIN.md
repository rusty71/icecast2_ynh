# Administration

## The two streams

| Mount | Format | Content |
|---|---|---|
| `/low.mp3` | MP3, 128 kbps CBR, 48 kHz stereo | low bandwidth, for mobile |
| `/high.ogg` | Ogg FLAC, lossless, up to 24-bit/96 kHz | high resolution |

The URLs are `https://<domain><path>/low.mp3` and
`https://<domain><path>/high.ogg`, with `<path>` being `/icecast` by default.

## The landing page

The domain of the app (`https://<domain>/`) shows a small page with the two
links to the streams.  It is written by the package to
`/etc/icecast2/landing.html` and served by nginx; the status page of
Icecast is still on the port of the server.

## The two ways to listen

The streams are reachable in two ways, and both can be used at the same time:

| | URL |
|---|---|
| **Directly on the port** | `http://<domain>:<port>/low.mp3` |
| Through the nginx reverse proxy | `https://<domain><path>/low.mp3` |

The direct port is the one to use for listening: it goes straight to
Icecast, without the reverse proxy in between.  It is open when the
**expose_port** setting is on (the "Open the streaming port on the
server?" question at install time, or the setting of the config panel).
Icecast then listens on `::` (every interface) instead of `::1`, and the
port is opened in the firewall.

The address is `::` and not `0.0.0.0`, so the server answers on its IPv6
address as well: the name of the domain resolves to it, and a client that
tries IPv6 first would otherwise be refused.  As long as
`net.ipv6.bindv6only` is 0 (the default), the socket takes the IPv4
connections too.

```bash
yunohost firewall list | grep -A 2 "$port"
```

To close it again, turn the setting off: the firewall rule is removed and
Icecast goes back to `127.0.0.1`.

**The publisher always connects directly** to `127.0.0.1:<port>`, never
through nginx - that is what keeps the Icecast session open across the track
changes.

If a player has trouble with the stream through the proxy, open the port and
point it at the direct URL.  If the streams have to be reachable over HTTPS,
keep the proxy.

## The publisher password

The Mopidy app publishes on the mounts as the Icecast user `source`, with the
password that was given at install time.  The same password is used for the
relay and for the admin panel.

If you change it here, change it in the Mopidy app as well, otherwise the
streams stay silent.  The password of the Mopidy app is in its settings:

```bash
yunohost app setting mopidy icecast_password
```

## The fallback streams

Each mount has a silent fallback (`/silence.mp3` and `/silence.ogg`) that is
played while Mopidy changes track.  They are generated at install and upgrade
time and stored in `/usr/share/icecast2/web/`.

They have to keep the same format as the live streams (48 kHz MP3 and 96 kHz
Ogg FLAC), otherwise the players have to re-initialise their decoder and the
stream appears to break.

To regenerate them by hand:

```bash
ffmpeg -y -f lavfi -i anullsrc=r=48000:cl=stereo -t 30 -c:a libmp3lame -b:a 128k \
    /usr/share/icecast2/web/silence.mp3
ffmpeg -y -f lavfi -i anullsrc=r=96000:cl=stereo -t 30 -c:a flac \
    /usr/share/icecast2/web/silence.ogg
```

## The mime types

`/etc/icecast2/mime.types.ynh` is a copy of the system mime types where
`.ogg` is mapped to `application/ogg` instead of `audio/ogg`.  Icecast only
hands a mount over to its fallback when the content types match, and the
publisher announces the Ogg stream as `application/ogg`.

## Logs

```bash
journalctl -u icecast2 -f
tail -f /var/log/icecast2/error.log
```
