# Icecast2 for YunoHost (Mopidy + Qobuz stack)

A fork of the official [YunoHost-Apps/icecast2_ynh](https://github.com/YunoHost-Apps/icecast2_ynh)
package, adapted to the Mopidy + Qobuz stack: it publishes the two streams of
the stack and keeps them alive with silent fallbacks.

This package is meant to be installed together with
[`mopidy_ynh`](https://github.com/rusty71/mopidy_ynh), which is the app that
feeds it.

## What it does

* Serves the two mounts of the stack:
  * `/low.mp3` - MP3, 128 kbps CBR, 48 kHz stereo (low bandwidth)
  * `/high.ogg` - Ogg FLAC, lossless, up to 24-bit/96 kHz (high resolution)
* Generates a silent fallback stream for each mount, in exactly the same
  format.  Icecast only hands a mount over to its fallback when the content
  types match, and a listener must not notice a format change while Mopidy
  switches track - otherwise players have to re-initialise their decoder and
  the stream appears to break.
* Fixes the mime types: Icecast maps `.ogg` to `audio/ogg`, but the publisher
  announces the Ogg stream as `application/ogg`.  Without the fix, Icecast
  refuses to switch the mount from the fallback to the live stream.

## Installation

From the YunoHost admin web interface, or:

```bash
yunohost app install icecast2 \
    --domain="music.example.org" \
    --path="/icecast" \
    --admin="admin" \
    --password="<the icecast password>"
```

That password is used for the source (the Mopidy publisher), the relay and
the admin panel.  **The Mopidy app has to be configured with the same
value**, otherwise the streams stay silent.

## Where to listen

Once the Mopidy app is running and playing:

| Stream | URL |
|---|---|
| Low resolution (MP3) | `https://music.example.org/icecast/low.mp3` |
| High resolution (FLAC) | `https://music.example.org/icecast/high.ogg` |
| Status page | `https://music.example.org/icecast/` |

The admin panel of Icecast is on the status page (the `admin` user and the
password given at install time).

## Notes

* The server listens on `127.0.0.1` only; the streams are published through
  the nginx reverse proxy of YunoHost.
* The Debian `icecast2` service is disabled at install time, the package runs
  its own systemd unit (`icecast2.service`) with its own configuration file
  (`/etc/icecast2/icecast.xml`).
* The fallback streams are regenerated at every install and upgrade, so they
  always match the formats the publisher produces.

## Credits

* Original package: [YunoHost-Apps/icecast2_ynh](https://github.com/YunoHost-Apps/icecast2_ynh),
  by eric-G and the YunoHost community.
* Icecast itself: [icecast.org](https://icecast.org/).
