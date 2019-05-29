#!/usr/bin/ruby

# convert-flac-collection
# christoph endr / ce / christoph-ender.de



require 'find'
require 'tmpdir'
require 'fileutils'
require 'open3'
require 'date'

version = "1.0.1"

#fdkaacSettingsAudiobook = "-p 5 -b 40000"
fdkaacSettingsAudiobook = "-p 5 -m 1"

#fdkaacSettingsAudiotheatre = "-p 5 -b 56000"
fdkaacSettingsAudiotheatre = "-p 5 -m 1"

#fdkaacSettingsMusic = "-p 2 -b 128000"
#fdkaacSettingsMusic = "-p 2 -m 4" # is about 128k
fdkaacSettingsMusic = "-p 5 -m 2"

# -p <param>:
#  2   AAC-LC  "AAC Profile" MPEG-2 Low-complexity (LC) combined with
#      MPEG-4 Perceptual Noise Substitution (PNS)
#  5   HE-AAC  AAC LC + SBR (Spectral Band Replication)
# 29   HE-AAC v2       AAC LC + SBR + PS (Parametric Stereo)
# 23   AAC-LD  "Low Delay Profile" used for real-time communication
# 39   AAC-ELD Enhanced Low Delay

# -b <param>: CBR bitrate, default 64000.

# -m <param>: Bitrate mode:
#    0: CBR
#  1-5: VBR

# https://hydrogenaud.io/index.php/topic,102051.0.html
# “SBR becomes a lot less useful above 64kbs, so it definitely does not
#  scale with bitrate.”

# Notes:
#
# (!) In case audiobooks/dramas should be built into one chapter per file,
# CONCAT has to be set to "false" for all files.
#
# Genre=Audio Drama
# http://eyed3.readthedocs.io/en/latest/plugins/genres_plugin.html
# 183: Audiobook
# 184: Audio Theatre

# cd Audiodrama-CD
# find . -name '*.flac' -print0|xargs -0 -n 1 metaflac --with-filename --show-tag GENRE
# find . -name '*.flac' -print0|xargs -0 -n 1 metaflac --remove-tag=GENRE
# find . -name '*.flac' -print0|xargs -0 -n 1 metaflac --set-tag="GENRE=Audio Theatre"
# find . -name '*.flac' -print0|xargs -0 -n 1 metaflac --set-tag="GENRE=Audiobook"
#
# find . -name '*.flac' -print0|xargs -0 -n 1 metaflac --with-filename --show-tag CONCAT
# find . -name '*.flac' -print0|xargs -0 -n 1 metaflac --remove-tag=CONCAT
# find . -name '*.flac' -print0|xargs -0 -n 1 metaflac --set-tag="CONCAT=false"
# find . -name '*.flac' -print0|xargs -0 -n 1 metaflac --set-tag="CONCAT=dir-only"
# find . -name '*.flac' -print0|xargs -0 -n 1 metaflac --set-tag="CONCAT=all-discs"

# Compilations:
# find . -name '*.flac' -print0|xargs -0 -n 1 metaflac --set-tag="COMPILATION=1"

# No longer using tegeditor since it overwrites the cpil-tag from fdkaac,
# it's own mp4-tags also don't seem to work 100% with iTunes.

# git clone https://github.com/mstorsjo/fdk-aac
# git clone https://github.com/nu774/fdkaac

# https://github.com/nu774/fdkaac
# CPPFLAGS=-I$HOME/opt/fdk-aac/include CFLAGS=-I$HOME/opt/fdk-aac/include LIBS=-L$HOME/opt/fdk-aac/lib ./configure --prefix=/home/chrender/opt/fdkaac
# export LD_LIBRARY_PATH=$HOME/opt/fdk-aac/lib

#lame_binary = ENV['HOME']+"/opt/lame-3.100/bin/lame"


# Prefixes to process in Audio directory:
#prefixesToProcess = [ "Audiotheatre-", "Audiobooks-", "Music-" ]

# Process only one to speed things up:
#prefixesToProcess = [ "Audiobooks-" ]
#prefixesToProcess = [ "Audiotheatre-" ]
prefixesToProcess = [ "Music-" ]


def getTimestamp()
  return DateTime.now.strftime "%Y-%m-%d %H:%M:%S"
end

def logEmptyLine()
  puts ""
  $logFile.puts ""
end


def log(text)
  puts "[#{getTimestamp}] #{text}"
  $logFile.puts "[#{getTimestamp}] #{text}"
end


def removeTrailingSlash(text)
  return text.gsub(/\/$/, '')
end

def getParentDir(dir)
  return removeTrailingSlash(File.dirname(removeTrailingSlash(dir)))
end


# Get contents of specified tag from filename.
def get_flac_tag(filename, tagname)
  output=`metaflac --show-tag=#{tagname} "#{filename}"`
  matches = output.match(/#{tagname}=(.*)/i)
  if matches
    return matches.captures[0]
  else
    return nil
  end
end


def ensureDirExists(dir)
  log "Ensuring dir #{dir} exists."
  if not(Dir.exists?(dir)) then
    FileUtils.mkdir_p dir
  end
end


def getCoverFileData(dir)
  # Select cover image file.
  # ! -name '._*' |
  log "Trying to get cover from #{dir}."
  covers = Dir.glob("#{dir}/*.jpg")
  if covers.size >= 1
    return covers[0]
  else
    log "No cover found."
    exit -1
    #return nil
  end
end


def is_number?(object)
  true if Float(object) rescue false
end


def isSourceNewer?(sourceRootDir, coverFile, destFilename)
  log "Testing isSourceNewer for #{sourceRootDir}."
  fileList = Dir.glob("#{sourceRootDir}/**/*.flac").sort
  sourceFileLastChanged = nil
  fileList.each do |filename|
    lastChanged = File.mtime(filename)
    if sourceFileLastChanged == nil || sourceFileLastChanged < lastChanged
      sourceFileLastChanged = lastChanged
      log "Currently newest source file: #{filename} at #{sourceFileLastChanged}."
    end
  end
  coverFileLastChanged = File.mtime(coverFile)
  if File.exist?(destFilename)
    log "Output file already exists."
    destFileLastChanged = File.mtime(destFilename)
    log sourceFileLastChanged
    if destFileLastChanged < sourceFileLastChanged
      log "Destination file is older than source."
      return true
    else
      if not(coverFile.to_s.empty?)
        log coverFileLastChanged
        if destFileLastChanged < coverFileLastChanged then
          return true
        end
      end
    end
  else
    log "Output file #{destFilename} does not exist."
    return true
  end
end


scriptDir = removeTrailingSlash(File.expand_path(File.dirname(__FILE__)))
audioDir = getParentDir scriptDir
audioParentDir = getParentDir audioDir
logDir = "#{audioDir}/logs"
tmpBaseName = "#{audioDir}/tmp"
destname = "#{audioParentDir}/Audio-Dist-aac"


$logFile = open("#{logDir}/convertflaccollection-#{DateTime.now.strftime "%Y-%m-%d-%H-%M-%S"}.txt", "w")
$logFile.sync = true

at_exit do
  if $logFile != nil
    $logFile.close
  end
end


log "Starting convert-flac-collection version #{version}."

# Output is first written to a temporary directory, which is defined
# and created here. It will be automatically removed upon exit.
outputTemp = nil
Dir::Tmpname.create('convert-flac-collection', tmpBaseName) { |path| outputTemp = path }
log "Using temp dir #{outputTemp}."
at_exit do
  log "Removing temp dir."
  FileUtils.rm_rf(outputTemp)
end
Dir.mkdir outputTemp

dest = removeTrailingSlash("#{destname}")

# Create output directory if it does not exist.
if not(Dir.exists?(dest)) then
  Dir.mkdir "#{dest}"
end

alreadyExistingOutputFiles = Dir.glob("#{dest}/**/*.m4[ab]")
log "Number of already exiting files: #{alreadyExistingOutputFiles.size}."

log "Processing #{audioDir}"
iterations = [ "work" ]
#iterations.insert 0, "verify"

totalNumberOfDirs = 0
(Dir.entries(audioDir).select { |entry|
 File.directory? File.join(audioDir,entry) \
    and !(entry =='.' || entry == '..') \
    and entry.start_with?(*prefixesToProcess)} ).sort.each { |topLevelDirectory|
    dirs = Dir["#{audioDir}/#{topLevelDirectory}/**/*/"].sort
    totalNumberOfDirs += dirs.size
  }


totalDirIndex = 0
iterations.each { |workType|
  (Dir.entries(audioDir).select { |entry|
    File.directory? File.join(audioDir,entry) \
     and !(entry =='.' || entry == '..') \
     and entry.start_with?(*prefixesToProcess) }).sort.each {|topLevelDirectory|
    log topLevelDirectory
    log "#{dest}/#{topLevelDirectory}"
    if not(Dir.exists?("#{dest}/#{topLevelDirectory}")) then
      Dir.mkdir "#{dest}/#{topLevelDirectory}"
    end
    currentAllDiscsRootDir = nil
    currentAllDiscsAlreadyProcessed = false
    pid = nil
    fdkaacInputStream = nil
    fdkaacOutputStream = nil
    wait_thr = nil
    coverfile = nil
    tempDestName = nil
    destFilename = nil
    dirs = Dir["#{audioDir}/#{topLevelDirectory}/**/*/"].sort
    dirs.each_with_index { |dir, dirIndex|
      totalDirIndex += 1
      log "Processing dir #{dirIndex+1} of #{dirs.size} / total #{totalDirIndex} of #{totalNumberOfDirs}"
      log "Dir is: #{dir}"
      relativeDir = removeTrailingSlash(dir[audioDir.size+1 .. -1])
      log "Relative dir is: #{relativeDir}"
      log "Output dir is #{dest}."
      baseDirName = relativeDir.gsub(/\/$/, '').split('/').last
      log baseDirName
      if Dir.glob("#{dir}/*.flac").empty?
        log "empty: #{dir}"
      else
        log "not empty: #{dir}"
        audioBookFound = false
        audioTheatreFound = false
        concatFalseFound = false
        concatDirOnlyFound = false
        concatAllDiscsFound = false
        genre = nil
        disctotal = nil
        filesInDir = Dir.glob("#{dir}/*.flac").sort
        filesInDir.each_with_index do |filename, fileIndex|
          next if filename == '.' or filename == '..'
          # do work on real items
          genre = get_flac_tag filename, "GENRE"
          concat = get_flac_tag filename, "CONCAT"
          if fileIndex == 0
            disctotal = get_flac_tag filename, "DISCTOTAL"
          end
          if genre != nil
            if genre.casecmp("Audiobook") == 0
              audioBookFound = true
              genre = "Hörbuch & Gesprochene Inhalte"
            elsif genre.casecmp("Audio Theatre") == 0
              audioTheatreFound = true
              genre = "Hörspiele"
            end
          end
          if concat != nil
            if concat.casecmp("false") == 0
              concatFalseFound = true
            elsif concat.casecmp("dir-only") == 0
              concatDirOnlyFound = true
            elsif concat.casecmp("all-discs") == 0
              concatAllDiscsFound = true
            else
              log "Unknown concat mode #{concat}."
              exit
            end
          end
        end
        log "disctotal: #{disctotal}"
        if (disctotal == nil || disctotal == "1" || disctotal == "") && concatAllDiscsFound == true
          log "concatAllDiscsFound not valid with DISCTOTAL #{disctotal}."
          concatAllDiscsFound = false
          concatDirOnlyFound = true
        end
        # TODO: Not only count disctotal, but also the number of subdirs. In
        # case there are none, "concatDirOnlyFound" may be used.

        if audioBookFound == true
          log "Audiobook genre found."
        end
        if audioTheatreFound == true
          log "Audio Theatre genre found."
        end
        if concatFalseFound == true
          log "concatFalseFound found."
        end
        if concatDirOnlyFound == true
          log "concatDirOnlyFound found."
        end
        if concatAllDiscsFound == true
          log "concatAllDiscsFound found."
        end

        if concatFalseFound == true \
             && (concatDirOnlyFound == true || concatAllDiscsFound == true)
          log "Both concat and non-concat found for single book/drama."
          exit -1
        end

        if audioBookFound == true || audioTheatreFound == true
          if concatFalseFound == false && concatDirOnlyFound == false && concatAllDiscsFound == false
            log "No concat type set for audiobook/theatre."
            exit -1
          end
        else
          if concatDirOnlyFound == true || concatAllDiscsFound == true
            log "Concat of non-audiobook/-dramas not implemented."
            exit -1
          end
        end

        parentDir = getParentDir dir
        relativeParentDir = getParentDir relativeDir

        isFirstDiscForAllDiscConcat = false
        isLastDiscForAllDiscConcat = false

        if concatAllDiscsFound == true and currentAllDiscsRootDir == nil
          log "Starting all-disc-concat for #{parentDir}."
          currentAllDiscsRootDir = parentDir
          isFirstDiscForAllDiscConcat = true
        end

        if concatAllDiscsFound == true
          if isFirstDiscForAllDiscConcat == true
            coverfile = getCoverFileData currentAllDiscsRootDir
          end
        else
          coverfile = getCoverFileData dir
        end

        log "currentAllDiscsRootDir: #{currentAllDiscsRootDir}."

        if currentAllDiscsRootDir != nil
          log "Test end-of-all-dics-concat:"
          log "current parent dir: #{parentDir}."
          log "current relative parent dir: #{relativeParentDir}."
          nextParentDir = nil
          if dirs.size > dirIndex+1
            nextParentDir = getParentDir dirs[dirIndex+1]
            log "next parent dir: #{nextParentDir}."
          end
          if dirs.size == dirIndex+1 || currentAllDiscsRootDir != nextParentDir
            log "Found end of concat-all-discs."
            isLastDiscForAllDiscConcat = true
          end
        end

        if concatAllDiscsFound == true or concatDirOnlyFound == true
          parentsParent = nil
          if isFirstDiscForAllDiscConcat == true
            parentsParent = getParentDir(relativeParentDir)
            destFilename = "#{dest}/#{parentsParent}/#{File.basename(parentDir)}.m4a"
          elsif concatDirOnlyFound == true
            destFilename = "#{dest}/#{relativeParentDir}/#{baseDirName}.m4a"
          end
          log "destfilename will be #{destFilename}."
          alreadyExistingOutputFiles.delete(destFilename)

          if workType == "work"
            log "Processing concat in #{dir}."
            fileList = Dir.glob("#{dir}/*.flac").sort
            # In case we're concattenating, gather all required data
            # before looping though the source files.
            startMainLoop = false
            numberOfChannels = nil
            if concatDirOnlyFound == true || isFirstDiscForAllDiscConcat == true
              log "Reading concat metadata from #{fileList[0]}."
              album = get_flac_tag fileList[0], "ALBUM"
              artist = get_flac_tag fileList[0], "ARTIST"
              composer = get_flac_tag fileList[0], "COMPOSER"
              title = album
              comment = nil
              numberOfChannels = Integer(`metaflac --show-channels "#{fileList[0]}"`, 10)
              bitsPerSample = Integer(`metaflac --show-bps "#{fileList[0]}"`, 10)
              sampleRate = Integer(`metaflac --show-sample-rate "#{fileList[0]}"`, 10)
              log "Number of channels: #{numberOfChannels}."
              if numberOfChannels != 1 && numberOfChannels != 2
                log "Invalid number of channels."
                exit
              end
              if isFirstDiscForAllDiscConcat == true
                startMainLoop = isSourceNewer?(currentAllDiscsRootDir,
                  coverfile, destFilename)
                currentAllDiscsAlreadyProcessed = not(startMainLoop)
                comment = parentsParent
              elsif concatDirOnlyFound == true
                startMainLoop = isSourceNewer?(dir, coverfile, destFilename)
                comment = relativeParentDir
              else
                log "Internal error."
                exit -1
              end
            elsif concatAllDiscsFound == true
              startMainLoop = not(currentAllDiscsAlreadyProcessed)
            end
            log "cover file: #{coverfile}."
            log "startMainLoop: #{startMainLoop}."

            if startMainLoop == true
              if concatAllDiscsFound == true
                if isFirstDiscForAllDiscConcat == true
                  ensureDirExists "#{dest}/#{parentsParent}"
                end
              elsif concatDirOnlyFound == true
                ensureDirExists "#{dest}/#{relativeParentDir}"
              end
               #outputStream, wait_threads = Open3.pipeline_w("sox -t raw -r 44100 -e signed -b 16 -c 2 --endian little - -t raw -r 44100 -e signed -b 16 -c 1 - remix -", "fdkaac --raw --raw-channels 1 --raw-rate 44100 --raw-format S#{bitsPerSample}L -p 2 -b 32000 --title \"#{title}\" --artist \"#{artist}\" --album \"#{album}\" --composer \"#{composer}\" --comment \"#{comment}\" -o \"#{outputTemp}/#{baseDirName}.m4a\" -")

              if (concatAllDiscsFound == true && isFirstDiscForAllDiscConcat == true) || concatDirOnlyFound == true
                tempDestName = "#{outputTemp}/#{baseDirName}.m4a"
                log "Using tempDestName #{tempDestName}."
                command = nil
                if audioBookFound == true
                  command = "fdkaac --raw --raw-channels #{numberOfChannels} --raw-rate #{sampleRate} --raw-format S#{bitsPerSample}L #{fdkaacSettingsAudiobook} --title \"#{title}\" --artist \"#{artist}\" --album \"#{album}\" --composer \"#{composer}\" --comment \"#{comment}\" --genre=\"#{genre}\" -o \"#{tempDestName}\" -"
                else
                  command = "fdkaac --raw --raw-channels #{numberOfChannels} --raw-rate #{sampleRate} --raw-format S#{bitsPerSample}L #{fdkaacSettingsAudiotheatre} --title \"#{title}\" --artist \"#{artist}\" --album \"#{album}\" --composer \"#{composer}\" --comment \"#{comment}\" --genre=\"#{genre}\" -o \"#{tempDestName}\" -"
                end
                log command
                log "Executing Open3.popen2: \"#{command}\""
                fdkaacInputStream, fdkaacOutputStream, wait_thr = Open3.popen2(command)
                log "Status is #{wait_thr.status}."
              end

              #command = "|#{lame_binary} --cbr -b 128 -m s -a -r -s 44.1 --little-endian --signed - \"#{outputTemp}/#{baseDirName}.mp3\""
              #command = "|sox -t raw -r 44100 -e signed -b 16 -c 2 --endian little - \"#{outputTemp}/#{baseDirName}.wav\""

              fileList.each_with_index do |filename, filenameIndex|
                log "#{filenameIndex+1} / #{fileList.size}"
                # Ignore "." and "..".
                next if filename == '.' or filename == '..'
                log filename
                # Get rawStream as IO object.
                rawStream = open("|flac --decode --sign=signed --endian=little --force-raw-format \"#{filename}\" -c", "rb")
                while buffer = rawStream.read(128*1024)
                  fdkaacInputStream.write buffer
                end
                rawStream.close

                if filenameIndex + 1 == fileList.size && ( (concatAllDiscsFound == true && isLastDiscForAllDiscConcat == true) || concatDirOnlyFound == true)

                  log "Finalize concat stream."
                  fdkaacInputStream.close
                  fdkaacOutputStream.close
                  log "Status is #{wait_thr.status}."
                  exit_status = wait_thr.value
                  log "Exit status: #{exit_status}."
                  log "Status is #{wait_thr.status}."
                 #begin
                 #  Process.waitpid(pid, Process::WNOHANG)
                 #rescue Errno::ECHILD
                 #  log "No waiting for output process, no child processes exist."
                 #  # ...
                 #end
                  pid = nil


                 #if audioBookFound == true
                 #  #pid = wait_thr.pid # pid of the started process.
                 #  log "Waiting for childs to finish ..."
                 #  exit_status = wait_threads[0].value # Process::Status object returned.
                 #  exit_status = wait_threads[1].value # Process::Status object returned.
                 #  log "Child processes are done."
                 #end

                 #`tageditor set cover="#{coverfile}" --files "#{tempDestName}"`
                  #`eyeD3 --remove-all --encoding=utf8 --comment=eng::"#{comment}" --to-v2.4 --title="#{title}" --artist="#{artist}" --album="#{album}" --comment="#{comment}" #{comptag} --text-frame="TCOM:#{composer}" --genre="#{genre}" --add-image="#{coverfile}":OTHER:Cover "#{outputTemp}/#{baseDirName}.mp3"`

                  `mp4art --optimize --add "#{coverfile}" "#{tempDestName}"`

                  log "Moving to #{destFilename}."
                  FileUtils.mv "#{tempDestName}", destFilename

                  currentAllDiscsAlreadyProcessed = false
                  coverfile = nil
                  tempDestName = nil
                  destFilename = nil
                end
              end
            end
          end

        else
          fileList = Dir.glob("#{dir}/*.flac").sort
          fileList.each_with_index do |filename, filenameIndex|
            basename = File.basename filename,'.flac'
            numberOfChannels = Integer(`metaflac --show-channels "#{filename}"`, 10)
            bitsPerSample = Integer(`metaflac --show-bps "#{filename}"`, 10)
            sampleRate = Integer(`metaflac --show-sample-rate "#{filename}"`, 10)
            log "Processing \"#{basename}\"."
            log "Number of channels: #{numberOfChannels}."
            if numberOfChannels != 1 && numberOfChannels != 2
              log "Invalid number of channels."
              exit
            end
            log "Bits per sample: #{bitsPerSample}."
            log "Samplerate: #{sampleRate}."
            # In case we're not concattenating we've got to evaluate all
            # relevant information for every single source file.
            suffix = nil
            if audioBookFound == true || audioTheatreFound == true
              suffix = "m4a" # was .m4b
            else
              suffix = "m4a"
            end
            coverfile = getCoverFileData dir
            destFilename = "#{dest}/#{relativeDir}/#{basename}.#{suffix}"
            log "destfilename will be #{destFilename}."
            alreadyExistingOutputFiles.delete(destFilename)

            if workType == "work"
              # non-concat
              log "#{filenameIndex+1} / #{fileList.size}"
              # Ignore "." and "..".
              next if filename == '.' or filename == '..'
              log filename

              sourceFileLastChanged = File.mtime(filename)
              coverFileLastChanged = File.mtime(coverfile)

              # This will stay "false" in case we've got nothing to do (source
              # file older than output file etc).
              processFile = false

              if File.exist?(destFilename)
                log "Output file already exists."
                destFileLastChanged = File.mtime(destFilename)
                log sourceFileLastChanged
                if destFileLastChanged < sourceFileLastChanged
                  log "Dest file is older than source, processing file."
                  processFile = true
                else
                  if not(coverfile.to_s.empty?)
                    log coverFileLastChanged
                    if destFileLastChanged < coverFileLastChanged then
                      log "Destination is older than cover, processing file."
                      processFile = true
                    end
                  end
                end
              else
                log "Output file #{destFilename} does not exist."
                processFile = true
              end

              if processFile then
                if workType == "work"
                  # Create directory in target if it does not yet exist.
                  ensureDirExists "#{dest}/#{relativeDir}"
                end

                album = get_flac_tag filename, "ALBUM"
                artist = get_flac_tag filename, "ARTIST"
                composer = get_flac_tag filename, "COMPOSER"
                title = get_flac_tag filename, "TITLE"
                tracknumber = get_flac_tag filename, "TRACKNUMBER"
                tracktotal = get_flac_tag filename, "TRACKTOTAL"
                discnumber = get_flac_tag filename, "DISCNUMBER"
                disctotal = get_flac_tag filename, "DISCTOTAL"
                compilation = get_flac_tag filename, "COMPILATION"
                comment = "#{relativeDir}"

                if album
                  album = album.gsub(/"/, '\\"')
                end
                if artist
                  artist = artist.gsub(/"/, '\\"')
                end
                if composer
                  composer = composer.gsub(/"/, '\\"')
                end
                if title
                  title = title.gsub(/"/, '\\"')
                end

                #`flac --decode "#{filename}" -o "#{outputTemp}/#{basename}.wav"`
                #`lame -V2 "#{outputTemp}/#{basename}.wav" #{coveropt} "#{coverfile}" "#{outputTemp}/#{basename}.mp3"`

                tcmpParameter = ""
                tageditorExtraParams = ""
                if compilation == "1"
                  # mp3: tcmpParameter = "--tag TCMP:1"
                  tcmpParameter = "--tag cpil:1"
                  #tageditorExtraParams = "mp4:CPIL=1"
                end
                command = nil
                if audioBookFound == true
                  #outputStream, wait_threads = Open3.pipeline("sox -t raw -r 44100 -e signed -b 16 -c 2 --endian little - - remix 1-2", "fdkaac --raw --raw-channels 1 --raw-rate 44100 --raw-format S#{bitsPerSample}L -p 5 -b 32000 --title \"#{title}\" --artist \"#{artist}\" --album \"#{album}\" --composer \"#{composer}\" --comment \"#{comment}\" #{tcmpParameter} --genre=\"#{genre}\" --genre=\"#{genre}\" -o \"#{outputTemp}/#{basename}.#{suffix}\" -")
                  command = "fdkaac --raw --raw-channels #{numberOfChannels}  --raw-rate #{sampleRate} --raw-format S#{bitsPerSample}L #{fdkaacSettingsAudiobook} --title \"#{title}\" --artist \"#{artist}\" --album \"#{album}\" --composer \"#{composer}\" --track \"#{tracknumber}/#{tracktotal}\" --disk \"#{discnumber}/#{disctotal}\" --comment \"#{comment}\" #{tcmpParameter} --genre=\"#{genre}\" -o \"#{outputTemp}/#{basename}.#{suffix}\" -"
                elsif audioTheatreFound == true
                  command = "fdkaac --raw --raw-channels #{numberOfChannels} --raw-rate #{sampleRate} --raw-format S#{bitsPerSample}L #{fdkaacSettingsAudiotheatre} --title \"#{title}\" --artist \"#{artist}\" --album \"#{album}\" --composer \"#{composer}\" --track \"#{tracknumber}/#{tracktotal}\" --disk \"#{discnumber}/#{disctotal}\" --comment \"#{comment}\" #{tcmpParameter} --genre=\"#{genre}\" -o \"#{outputTemp}/#{basename}.#{suffix}\" -"
                else
                  command = "fdkaac --raw --raw-channels #{numberOfChannels} --raw-rate #{sampleRate} --raw-format S#{bitsPerSample}L #{fdkaacSettingsMusic} --title \"#{title}\" --artist \"#{artist}\" --album \"#{album}\" --composer \"#{composer}\" --track \"#{tracknumber}/#{tracktotal}\" --disk \"#{discnumber}/#{disctotal}\" --comment \"#{comment}\" #{tcmpParameter} --genre=\"#{genre}\" -o \"#{outputTemp}/#{basename}.#{suffix}\" -"
                end
                log "Executing Open3.popen2: \"#{command}\""
                fdkaacInputStream, fdkaacOutputStream, wait_thr = Open3.popen2(command)
                log "Status is #{wait_thr.status}."
                log "suffix: #{suffix}"
                log command
                flacCommand = "|flac --decode --sign=signed --endian=little --force-raw-format \"#{filename}\" -c"
                log flacCommand
                rawStream = open flacCommand, "rb"
                while buffer = rawStream.read(128*1024)
                  fdkaacInputStream.write buffer
                end
                rawStream.close
                fdkaacInputStream.close
                fdkaacOutputStream.close
                log "Status is #{wait_thr.status}."
                exit_status = wait_thr.value
                log "Exit status: #{exit_status}."
                log "Status is #{wait_thr.status}."
               #begin
               #  Process.waitpid(pid, Process::WNOHANG)
               #rescue Errno::ECHILD
               #  log "No waiting for output process, no child processes exist."
               #  # ...
               #end
                pid = nil
                #`tageditor set cover="#{coverfile}" #{tageditorExtraParams} --files "#{outputTemp}/#{basename}.#{suffix}"`
                #`tageditor set cover="#{coverfile}" --files "#{outputTemp}/#{basename}.#{suffix}"`
                `mp4art --optimize --add "#{coverfile}" "#{outputTemp}/#{basename}.#{suffix}"`

                FileUtils.mv "#{outputTemp}/#{basename}.#{suffix}", destFilename
               #if compilation == "1"
               #  comptag="--text-frame=TCMP:1"
               #else
               #  comptag=""
               #end
               # todo: Run eyeD3 before File-mv.
               #`eyeD3 --encoding=utf8 --comment=eng::"#{comment}" --to-v2.4 --title="#{title}" --artist="#{artist}" --album="#{album}" --comment="#{comment}" #{comptag} --text-frame="TCOM:#{composer}" --add-image="#{coverfile}":OTHER "#{dest}/#{x}/#{basename}.mp3"`
              else
                log "Destination file is newer than source data, skipping."
              end
            end
          end
        end

        if isLastDiscForAllDiscConcat == true
          currentAllDiscsRootDir = nil
        end

      end
      logEmptyLine
    }
  }
}

logEmptyLine
alreadyExistingOutputFiles.each do |filename|
  log "Superfluous file: #{filename}."
end

exit 0

