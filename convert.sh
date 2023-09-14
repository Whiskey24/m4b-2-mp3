#!/bin/bash
## copied the essential bits from nitrag/convert_m4b.sh
## https://gist.github.com/nitrag/a188b8969a539ce0f7a64deb56c00277

M4BDIR="/mnt/rapid-store/media/audiobooks"
MP3DIR="/mnt/rapid-store/media/audiobooks/mp3"
FFMPEG="ffmpeg-git-20230313-amd64-static/ffmpeg"

RED='\033[0;31m'
CYAN='\033[0;36m'
LGRN='\033[0;32m'
BLUE='\033[0;34m'
MAGE='\033[0;35m'
YLLW='\033[1;33m'
CYAL='\033[1;36m'

NCLR='\033[0m' # No Color

## Test if FFMPEG can be Found
if [ ! -f "$FFMPEG" ]; then
    echo "Cannot find ffmpeg at $FFMPEG"
	exit
fi

# create MP3DIR if it does not exist
mkdir -p $MP3DIR

# Ask for search term or blank for all
read -p "Enter search term or blank for all: " SEARCHTERM

# Run the command and store results in an array
readarray -d '' BOOKLIST < <(find $M4BDIR -type f -iname "*$SEARCHTERM*.m4b" -print0 )


LENGTH=${#BOOKLIST[@]}

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

# function to show list with options to user
showBookList(){
    for (( j=0; j<$LENGTH; j++ ));
    do
        if [ $((j%2)) -eq 0 ]; then COLOR=$CYAL; else COLOR=$CYAN; fi
        printf "${COLOR}%s\n" "$((j+1)) ${BOOKLIST[$j]}"
    done
}

# function to ask for selection, validate input
chooseBook(){
    until [ $_GOODINPUT ]; do
        printf "${CYAN}Please select a book:${NCLR} "
        read INPUT
        if [[ -n ${INPUT//[0-9]/} ]]; then
            printf "${RED}Choose between 1 and %d, no letters allowed!${NCLR}\n" $LENGTH
        elif (( $INPUT == 0 )); then
            printf "${RED}Choose between 1 and %d, 0 is not an option!${NCLR}\n" $LENGTH
        elif (( $INPUT > $LENGTH )); then
            printf "${RED}Choose between 1 and %d, %d is not an option!${NCLR}\n" $LENGTH
        else
            _GOODINPUT=1
        fi
    done
    unset _GOODINPUT
}

enterTitle(){
        read -p "Enter book title for directory: " BOOKTITLE
}

convertToMp3(){
        OUTDIR="$MP3DIR/$BOOKTITLE"
        mkdir -p "$OUTDIR"
		printf "\nconverting m4b to mp3\n"
        MP3FILE="$OUTDIR/$BOOKTITLE.mp3"
        (${FFMPEG} -i "${BOOKLIST[(($INPUT-1))]}" -hide_banner -vn -acodec libmp3lame -ar 22050 -ab 64k "$MP3FILE")
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
    
	# Get prefix zeros to pad chapter numbering in filenames
	ZEROS=""
	for (( c=1; c<$DIGITS; c++ ))
    do
        ZEROS="${ZEROS}0"
    done

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
            </dev/null ${FFMPEG} -loglevel error -stats -i "${MP3FILE}" -ss "${start%?}" -to "${end}" -codec:a copy -metadata title="${chapter}" -metadata track="$TRACK/$CHAPTERCOUNT" "${OUTDIR}/${chapter_file}"
             
            TRACK=$((TRACK+1))
        fi
    done <"$TMPFILE"
	rm "$TMPFILE"
}

showBookList
chooseBook

printf "Selected book: %s\n\n" "${BOOKLIST[(($INPUT-1))]}"

enterTitle

convertToMp3

splitInChapters

printf "\n\nMP3 files have been saved to: %s" "${OUTDIR}"

printf "${NCLR}\n\n"
            
