# Administration

## The two streams

| Mount | Format | Content |
|---|---|---|
| `/low.mp3` | MP3, 128 kbps CBR, 48 kHz stereo | low bandwidth, for mobile |
| `/high.ogg` | Ogg FLAC, lossless, up to 24-bit/96 kHz | high resolution |

The URLs are `https://<domain><path>/low.mp3` and
`https://<domain><path>/high.ogg`, with `<path>` being `/icecast` by default.

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
