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
             download_track $entry.id $output_path
             log info $'[($entry.title)] downloaded'
           }
         }
    log info "Playlist audio tracks ready to merge"

    let ffmpeg_tracks_list = 'playlist.txt'
    map_yt_playlist_to_ffmpeg_track_list $playlist | save --force $ffmpeg_tracks_list

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

def "main timecodes" [url: string] {
  let playlist = fetch_playlist $url

  mut total_duration = 0
  mut result = []

  for entry in ($playlist | get entries) {
    let start = $total_duration
    let end = $total_duration + $entry.duration
    $total_duration = $end
    $result = ($result | append {start: (seconds-to-hms $start), end: (seconds-to-hms $end), title: $entry.title})
  }

  $result | each {|row| $"($row.start) - ($row.end): ($row.title)"} | to text
}

def fetch_playlist [url: string] {
  yt-dlp --flat-playlist --dump-single-json $url
        | from json
}

def download_track [id: string, output: string] {
  yt-dlp --embed-metadata --embed-thumbnail -x --audio-format mp3 $id -o $output out> /dev/null err> /dev/null
}

def map_playlist_entry_to_path [entry: record] {
  echo $'($entry.id).mp3'
}

def map_yt_playlist_to_ffmpeg_track_list [playlist: record] {
    $playlist
        | get entries
        | each { |entry| $'file ($env.MUSIC_SOURCE_DIR)/(map_playlist_entry_to_path $entry)'}
        | to text
}

def seconds-to-hms [seconds: int] {
    let align = {|val| $val | fill --alignment right --character '0' --width 2}

    let hours = $seconds // 3600 | each $align
    let minutes = (($seconds mod 3600) // 60) | each $align
    let seconds = ($seconds mod 60) | each $align

    echo $'($hours):($minutes):($seconds)'
}
