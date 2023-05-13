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

# create MP3DIR if it does not exist
mkdir -p $MP3DIR

# Ask for search term or blank for all
read -p "Enter search term or blank for all: " SEARCHTERM

# Run the command and store results in an array
readarray -d '' BOOKLIST < <(find $M4BDIR -type f -iname "*$SEARCHTERM*.m4b" -print0 )


LENGTH=${#BOOKLIST[@]}

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
        MP3FILE="$OUTDIR/$BOOKTITLE.mp3"
        (${FFMPEG} -i "${BOOKLIST[(($INPUT-1))]}" -hide_banner -vn -acodec libmp3lame -ar 22050 -ab 64k "$MP3FILE")
        OUTDIR="$MP3DIR/$BOOKTITLE/Chapters"
        mkdir -p "$OUTDIR"
}

splitInChapters(){
    (${FFMPEG} -i "$MP3FILE") 2> tmp.txt
    CHAPTERCOUNT=`grep "Chapter #" tmp.txt | wc -l`
    DIGITS=${#CHAPTERCOUNT}
    TRACK=1
    printf "Found %d chapters\n\n" $CHAPTERCOUNT
    while read -r first _ _ start _ end; do
        if [[ "${first}" = "Chapter" ]]
        then
            read  # discard line with Metadata:
            read _ _ chapter
            chapter=$(sed -re ":r;s/\b[0-9]{1,$((1))}\b/0&/g;tr" <<<$chapter)
            chapter_file=`printf "%0${DIGITS}d - ${chapter}.mp3" $TRACK`
            chapter_file=${chapter_file//[:]/꞉}  # replace colon with lookalike for Windows
            printf "\nprocessing $TRACK/$CHAPTERCOUNT :: $chapter\n"
            </dev/null ${FFMPEG} -loglevel error -stats -i "${MP3FILE}" -ss "${start%?}" -to "${end}" -codec:a copy -metadata title="${chapter}" -metadata track="$TRACK/$CHAPTERCOUNT" "${OUTDIR}/${chapter_file}"
            TRACK=$((TRACK+1))
        fi
    done <tmp.txt
}

showBookList
chooseBook

printf "Selected book: %s\n\n" "${BOOKLIST[(($INPUT-1))]}"

enterTitle

#MP3FILE="/mnt/rapid-store/media/audiobooks/mp3/Fear the Future/Fear the Future.mp3"
#OUTDIR="/mnt/rapid-store/media/audiobooks/mp3/Fear the Future/Chapters"
convertToMp3

splitInChapters

rm tmp.txt

echo "\n\nMP3 files have been saved to ${OUTDIR}"

printf "${NCLR}\n\n"
            
