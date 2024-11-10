use std log

$env.NU_LOG_LEVEL = 'INFO'
$env.MUSIC_SOURCE_DIR = 'source'

def main [url: string, thumbnail: string] {
    let playlist = fetch_playlist $url

    let playlist_base_dir = $playlist.title | str replace '/' '-'
    mkdir $playlist_base_dir
    cd $playlist.title

    mkdir $env.MUSIC_SOURCE_DIR

    $playlist
         | get entries
         | par-each { |entry|
           let output_path = $'($env.MUSIC_SOURCE_DIR)/(map_playlist_entry_to_path $entry)'
           if ($output_path | path exists) {
              log info $'[($entry.title)] already downloaded'
           } else {
             yt-dlp --embed-metadata --embed-thumbnail -x --audio-format mp3 $entry.id -o $output_path out> /dev/null err> /dev/null
             log info $'[($entry.title)] downloaded'
           }
         }
    log info "Playlist audio tracks ready to merge"

    let ffmpeg_tracks_list = 'playlist.txt'
    $playlist
        | get entries
        | each { |entry| $'file ($env.MUSIC_SOURCE_DIR)/(map_playlist_entry_to_path $entry)'}
        | to text
        | save --force $ffmpeg_tracks_list


    log info "Merging playlist audio tracks"
    let playlist_path = $'($playlist.title).mp3'

    if ($playlist_path | path exists) {
      log info "Removing old playlist version"
      rm $playlist_path
    }

    let buf_output_name = 'output_buf.mp3'

    try {
      ffmpeg -f concat -safe 0 -i $ffmpeg_tracks_list -c copy $buf_output_name
      ffmpeg -i $buf_output_name -i $thumbnail -map 0 -map 1 -c copy -id3v2_version 3 -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (Front)" $playlist_path
      log info "Playlist created"
    } catch {
      |err| log error $'Failed to merge playlist with ($err.msg)'
    }

    rm -f $buf_output_name
    rm -f $ffmpeg_tracks_list
    log info "Temp files cleared"
}

def fetch_playlist [url: string] {
    yt-dlp --flat-playlist --dump-single-json $url
        | from json
}

def map_playlist_entry_to_path [$entry: record] {
  echo $'($entry.id).mp3'
}
