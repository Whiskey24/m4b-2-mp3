#!/bin/bash
## For first use, copy config.ini.default to config.ini and configure the variables in that file

CONFIG="config.ini"
if [ ! -f "$CONFIG" ]; then
    printf "Cannot find config file %s\n" $CONFIG
	printf "If running for the first time, copy config.ini.default to config.ini and update the configuration in that file\n\n"
    exit
fi

## Source config file
. $CONFIG

checkFiles() {
    ## Test if FFMPEG can be found
    if [ ! -f "$FFMPEG" ]; then
        printf "Cannot find ffmpeg at %s\n\n" $FFMPEG
        exit
    fi

    ## Test if convert function file can be found
    if [ ! -f "$CONVERTFILE" ]; then
        printf "Cannot find file %s with convert functions\n\n" $CONVERTFILE
        exit
    fi

    ## Test if m4b directory can be found
    if [ ! -d "$M4BDIR" ]; then
        printf "Cannot find m4b directory at %s\n\n" $M4BDIR
        exit
    fi

    ## Check if there are any m4b files in the m4b directory
    M4BCOUNT=$(find $M4BDIR -type f -iname "*.m4b" -printf x | wc -c )
    if (( $M4BCOUNT == 0 )); then
        printf "Did not find any m4b files in configured m4b directory %s\n\n" $M4BDIR
        exit
    else
        printf "Found %d m4b files\n" $M4BCOUNT
    fi

    ## Test if mp3 directory can be found, if try not create it
    if [ ! -d "$MP3DIR" ]; then
        printf "Cannot find mp3 directory at %s, creating it\n" $MP3DIR
        mkdir $MP3DIR
        if [ $? -ne 0 ] ; then
            printf "Could not create mp3 directory at %s\n\n" $MP3DIR
            exit
        fi
    fi

    ## Test if ExifTool can be found
    if [ ! -f "$EXIFTOOL" ]; then
        printf "Will not use ExifTool, cannot find it at %s\n\n" $EXIFTOOL
    else
        EXIF=1
    fi
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
        if [ -z "$INPUT" ]; then
            printf "${RED}Choose an option${NCLR}\n"
        elif [[ -n ${INPUT//[0-9]/} ]]; then
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
    printf "Selected book: %s\n\n" "${BOOKLIST[(($INPUT-1))]}"
}

enterTitle(){
    until [ $_GOODINPUT ]; do
        read -p "Enter book title for directory: " BOOKTITLE
        if [ -z "$BOOKTITLE" ]; then
            printf "${RED}Title cannot be left empty${NCLR}\n"
        else
            _GOODINPUT=1
        fi
    done
    # Check if booktitle directory exists
    if [ -d "$MP3DIR/$BOOKTITLE" ]; then
        printf "Directory already exists for this book title: %s\n" "$MP3DIR/$BOOKTITLE"
        printf "Exiting\n\n"
        exit
    fi
    unset _GOODINPUT
}

searchBook() {
    until [ $_GOODINPUT ]; do
        # Ask for search term or blank for all
        read -p "Enter search term or blank for all: " SEARCHTERM

        # Run the command and store results in an array
        readarray -d '' BOOKLIST < <(find $M4BDIR -type f -iname "*$SEARCHTERM*.m4b" -print0 )
        LENGTH=${#BOOKLIST[@]}
        if (( $LENGTH == 0)); then
            printf "${RED}No file found for search term \"%s\", please try again${NCLR}\n" $SEARCHTERM
        else
            _GOODINPUT=1
        fi
    done
    unset _GOODINPUT
}

showExif() {
    if [ $EXIF ]; then
        (${EXIFTOOL} -Title -Artist -Narrator -MediaDuration "${BOOKLIST[(($INPUT-1))]}")
        printf "\n"
    fi
}

COUNT=1

checkFiles

until [ $_DONE ]; do

    until [ $_SELECTED ]; do
        searchBook
        showBookList
        chooseBook
        showExif

        read -p "Continue? y/n: " CONTINUE
        if [ "$CONTINUE" = "y" ]; then
            _SELECTED=1
        fi
    done

    unset _SELECTED

    enterTitle

    if [[ "$HIDEOUTPUT" = true ]]; 
    then
        nohup bash $CONVERTFILE "${CONFIG}" "${BOOKTITLE}" "${BOOKLIST[(($INPUT-1))]}" > /dev/null &
    else
        bash $CONVERTFILE "${CONFIG}" "${BOOKTITLE}" "${BOOKLIST[(($INPUT-1))]}" &
    fi
    

    # Sleep 1 sec to let the nohup message print
    sleep 1

    printf "\n"
    read -p "Convert another file? y/n: " ANOTHER
    if [ "$ANOTHER" != "y" ]; then
        printf "Number of files being converted: %d\n\n" $COUNT
        _DONE=1
    fi
    ((COUNT=COUNT+1))
done