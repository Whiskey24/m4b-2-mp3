I created these scripts to convert audiobooks that I store in m4b format to mp3 chapter files. This is because my Garmin watch cannot skip chapters in m4b files, but can recognize mp3 files belonging to a single audiobook and skip in those (I mostly listen using the audible app, but do not carry my phone with me on runs).

The scripts assume the audiobooks are located in a single directory in m4b format. It searches this directory by filename.
For conversion FFmpeg is used. If available, ExifTool is used to read book details from the m4b file. When configured, updates are send with Telegram when starting and completing a conversion.

Configuration details are kept in config.ini. Copy config.ini.default to config.ini and adapt before first use.

The main script is m4b-2-mp3.sh. This script will search for the audiobook and start the conversion to mp3. It does so by calling the convert_batch.sh script in the background.

My thanks to nitrag from whom I copied the essential ffmpeg instructions (see [nitrag/convert_m4b.sh](https://gist.github.com/nitrag/a188b8969a539ce0f7a64deb56c00277))
