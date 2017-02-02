## Bug

`AVURLAsset` doesn't contain any tracks when streaming a `.m3u8` stream, so it's not possible to insert a tap or add a mixer.

### Expected behavior

`AVPlayerItem.asset.tracks` should contain a video and audio track when `AVPlayerItem.status == .readyToPlay`. 

### Observed behavior

`AVPlayerItem.asset.tracks` is empty.

### Notes

This is only when streaming `.m3u8`. If the URL is a `.mp4` file, it works fine.