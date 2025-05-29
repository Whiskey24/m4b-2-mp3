## Do not run this file directly, run m4b-2-mp3.sh
##
## copied the essential bits from nitrag/convert_m4b.sh
## https://gist.github.com/nitrag/a188b8969a539ce0f7a64deb56c00277
##

## do not allow running this script on its own
if [[ -z $1 || -z $2 || -z $3 ]]; then
    printf "This script cannot be run on its own, run m4b-2-mp3.sh instead\n"
    exit
fi

# Get start time of script execution
SECONDS=0

## Obtain settings from main script
CONFIG=$1
BOOKTITLE=$2
BOOKFILE=$3

# Source config file
. $CONFIG

# Block until the given file appears or the given timeout is reached.
# Exit status is 0 if the file exists.
# https://superuser.com/questions/878640/unix-script-wait-until-a-file-exists
waitFile() {
    local file="$1"; shift
    local wait_seconds="${1:-10}"; shift # 10 seconds as default timeout
    test $wait_seconds -lt 1 && echo 'At least 1 second is required' && return 1

    until test $((wait_seconds--)) -eq 0 -o -e "$file" ; do sleep 1; done

    test $wait_seconds -ge 0 # equivalent: let ++wait_seconds
}

# Function to get filesize in bytes
getFileSize() {
  local file="$1"
  if [[ -f "$file" ]]; then
    if stat --version &>/dev/null; then
      # GNU stat
      stat -c%s "$file"
    else
      # BSD/macOS stat
      stat -f%z "$file"
    fi
  else
    echo "Error: '$file' is not a file" >&2
    return 1
  fi
}

convertToMp3(){
    OUTDIR="$MP3DIR/$BOOKTITLE"
    mkdir -p "$OUTDIR"
    printf "\nconverting m4b to mp3\n"
    MP3FILE="$OUTDIR/$BOOKTITLE.mp3"
    (${FFMPEG} -i "${BOOKFILE}" -hide_banner -loglevel error -vn -acodec libmp3lame -ar 22050 -ab 64k "$MP3FILE")
    OUTDIR="$MP3DIR/$BOOKTITLE/Chapters"
    mkdir -p "$OUTDIR"
}

splitInChapters(){
    TMPFILE="$MP3DIR/$BOOKTITLE/tmp.txt"
    (${FFMPEG} -i "$MP3FILE") 2> "$TMPFILE"
    waitFile "$TMPFILE" 5 || {
        echo "MP3 info file was not created after waiting for 5 seconds: '$TMPFILE'"
        exit 1
    }
    CHAPTERCOUNT=`grep "Chapter #" "$TMPFILE" | wc -l`
    DIGITS=${#CHAPTERCOUNT}
    TRACK=1
    printf "Found %d chapters\n\n" $CHAPTERCOUNT

    while read -r first _ _ start _ end; do
        if [[ "${first}" = "Chapter" ]]
        then
            read  # discard line with Metadata:
            read _ _ chapter
            chapter=$(sed -re ":r;s/\b[0-9]{1,$((1))}\b/0&/g;tr" <<<$chapter)
            # printf "\n======\nextracted chaptername: %s\n" "${chapter}"

            chapter_file=${chapter//[:]/꞉}  # replace colon with lookalike for Windows
            chapter_file=${chapter_file//[*]/_}  # replace windows non allowed char to _
            chapter_file=${chapter_file//[\/]/_} # replace windows non allowed char to _
            chapter_file=${chapter_file//[\\]/_} # replace windows non allowed char to _
            chapter_file=${chapter_file//[?]/_}  # replace windows non allowed char to _
            chapter_file=${chapter_file//[\"]/_} # replace windows non allowed char to _
            chapter_file=${chapter_file//[<]/_}  # replace windows non allowed char to _
            chapter_file=${chapter_file//[>]/_}  # replace windows non allowed char to _
            chapter_file=${chapter_file//[|]/_}  # replace windows non allowed char to _
            chapter_file=${chapter_file//[\^]/_}  # replace windows non allowed char to _
            chapter_file=${chapter_file//[&]/_}  # replace windows non allowed char to _

            # Get prefix zeros to pad chapter numbering in filenames
            TRACKDIGITS=${#TRACK}
            ZEROS=""
            for (( c=1; c<=$((DIGITS-TRACKDIGITS)); c++ ))
            do
                ZEROS="${ZEROS}0"
            done
            chapter_file="${ZEROS}${TRACK} - ${chapter_file}.mp3"

            printf "\nprocessing %d/%d :: %s\n" "$TRACK" "$CHAPTERCOUNT" "$chapter"
            </dev/null ${FFMPEG} -loglevel error -nostats -i "${MP3FILE}" -ss "${start%?}" -to "${end}" -codec:a copy -metadata title="${chapter}" -metadata track="$TRACK/$CHAPTERCOUNT" -metadata genre="Audiobook" "${OUTDIR}/${chapter_file}"

            TRACK=$((TRACK+1))
        fi
    done <"$TMPFILE"
    rm "$TMPFILE"
    
    if [[ "$DELETEMP3MASTERFILE" = true ]]; 
    then
        rm "$MP3FILE"
        ## move the mp3 chapter files in the root directory and delete the chapter directory
         mv "${OUTDIR}"/* "$MP3DIR/$BOOKTITLE" 
         rmdir "${OUTDIR}"
    fi
}

sendMsg(){
    # only send a message if Telegram has been configured
    if [[ ! -z $TELEGRAM_CHATID && ! -z $TELEGRAM_KEY ]]; then
        # replace space with %20
        TEXT=${1// /%20}
        # replace \n with %0A for newlines
        TEXT="${TEXT//\\n/"%0A"}"
        curl -s --max-time $TELEGRAM_TIMEOUT -d "chat_id=${TELEGRAM_CHATID}&parse_mode=Markdown&text=$TEXT" ${TELEGRAM_URL} > /dev/null
    fi
}

# report exectution time from seconds in hh mm ss format
formattedExecutionTime(){
    local elapsed=$1

    # Convert to hours, minutes, and integer seconds
    local hh=$((echo "$elapsed / 3600"))
    local mm=$((echo "($elapsed % 3600) / 60"))
    local ss=$((echo "$elapsed % 60"))  # Truncate to integer
    printf "%02d:%02d:%02d (hh:mm:ss)" "$hh" "$mm" "$ss"
}

CalculateConversionSpeed() {
  local seconds=$1
  local bytes=$2

  if [[ $seconds -eq 0 ]]; then
    echo "Speed: N/A (duration is zero)"
    return 1
  fi

  # Calculate speeds
  local bytes_per_sec=$(echo "scale=2; $bytes / $seconds" | bc)
  local mb_per_sec=$(echo "scale=2; $bytes_per_sec / 1024 / 1024" | bc)

  echo "$bytes_per_sec B/s ($mb_per_sec MB/s)"
}

# Get filesize in bytes and MB
FILESIZE=$(getFileSize "${BOOKFILE}")
FILESIZEMB=$(( ${FILESIZE} / 1048576 ))

sendMsg "Starting mb4-2-mp3 conversion for ${BOOKTITLE} [${FILESIZEMB} MB]"

convertToMp3

splitInChapters

# Get script execution time in seconds 
ELAPSEDTIME=$SECONDS


# Get formatted execution time and conversion speed
TIMETAKEN=$(formattedExecutionTime "$ELAPSEDTIME")
CONVERSIONSPEED=$(CalculateConversionSpeed "$ELAPSEDTIME" "$FILESIZE")


if [[ "$DELETEMP3MASTERFILE" = true ]]; 
then
    sendMsg "Conversion complete for ${BOOKTITLE}\nFiles have been saved to ${MP3DIR}/${BOOKTITLE}\nTime taken: ${TIMETAKEN}\nConversion speed: ${CONVERSIONSPEED}"
    printf "\n\nMP3 files have been saved to: %s" "${MP3DIR}/${BOOKTITLE}"
else
    sendMsg "Conversion complete for ${BOOKTITLE}\nFiles have been saved to ${MP3DIR}/${BOOKTITLE}\nTime taken: ${TIMETAKEN}\nConversion speed: ${CONVERSIONSPEED}"
    printf "\n\nMP3 files have been saved to: %s" "${OUTDIR}"
fi

printf "${NCLR}\n\n"
