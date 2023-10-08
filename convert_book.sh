## Do not run this file directly, run m4b-2-mp3.sh

CONFIG=$1
BOOKTITLE=$2
BOOKFILE=$3

## Source config file
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
            </dev/null ${FFMPEG} -loglevel error -nostats -i "${MP3FILE}" -ss "${start%?}" -to "${end}" -codec:a copy -metadata title="${chapter}" -metadata track="$TRACK/$CHAPTERCOUNT" "${OUTDIR}/${chapter_file}"

            TRACK=$((TRACK+1))
        fi
    done <"$TMPFILE"
    rm "$TMPFILE"
}


#BOOKTITLE=$1
#BOOKFILE=$2

#echo "waiting 10"
#sleep 10

#printf "\n\n$BOOKTITLE"
#echo $BOOKFILE

#exit

convertToMp3

splitInChapters

printf "\n\nMP3 files have been saved to: %s" "${OUTDIR}"

printf "${NCLR}\n\n"