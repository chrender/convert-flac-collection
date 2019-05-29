
# convert-flac-collection

Made by  
_christoph ender / ce / [christoph-ender.de](christoph-ender.de) _

## Description
 This will convert an entire collection of flac files into AAC-Files in
 a `.m4a` container. The purpose is to have a set of original files permanently
 stored in flac-format and to create/update a collection of corresponding
 m4a files for use in iTunes and/or usage on iOS from iTunes-Sync.

 It was build/tested using the following components:
 
- ruby 2.0.0p648 (2015-12-16 revision 53162)
- fdk-aac v1.5 - [https://github.com/mstorsjo/fdk-aac](https://github.com/mstorsjo/fdk-aac)
- fdkaac v0.6.3 - [https://github.com/nu774/fdkaac](https://github.com/nu774/fdkaac)
- mp4v2-utils 2.0.0\~dfsg0-5 - [https://code.google.com/archive/p/mp4v2/](https://code.google.com/archive/p/mp4v2/)

 Debian and derivates: `apt-get install mp4v2-utils`

 You'll need to have an UTF-8 locale active to make tagging work
 correctly, by doing "export LC_ALL="en_US.utf8" or similar (mp3-only?).
 
## Changelog
| Version | Date | Author | Description  |
|---------|------|--------|--------------|
| v0.9.0  | 2017-12-04 | (ce) | First usable prototype.
| v0.9.1  | 2017-12-04 | (ce) | Dest now using absolute path, fix comment-dirs.
| v0.9.2  | 2017-12-05 | (ce) | Fix absolute path in comments.
| v0.9.3  | 2017-12-06 | (ce) | Don't create superfluous directory any longer.
| v0.9.4  | 2017-12-06 | (ce) | Use sync-mode for file logging.
| v0.9.5  | 2017-12-06 | (ce) | Use “dir-only” concat in case no disctotal is set. Fix end-of-concat-detection at dir-array end.
| v0.9.6  | 2017-12-09 | (ce) | Close “rawStream” pipes to avoid \<defunct\> processes.
| v0.9.7  | 2017-12-11 | (ce) | Fix non Audiotheatre-genre detection.
| v0.9.8  | 2017-12-12 | (ce) | Fix compilation-tagging, replace tageditor with mp4art, fix “waitpid”-calls, fix sourcefile date evaluation to avoid unnecessary rebuilds.
| v0.9.9  | 2017-12-13 | (ce) | Fix only-last-disc in concat-files.
| v0.9.10 | 2017-12-14 | (ce) | Hotfix for parameter quotes.
| v0.9.11 | 2017-12-17 | (ce) | Make mono source files work, fix corrupt output files by waiting correctly for fdkaac to finished before running ap4art.
| v0.9.12 | 2018-01-03 | (ce) | Un-use .m4b, add missing genres for audiobooks and audiotheatre, implement variable sample rate, add m4a-optimization, set output-dir and tmp-dir automatically, verify-step now optional.
| v0.9.13 | 2018-01-06 | (ce) | Use VBR instead of CBR by default.
| v0.9.14 | 2018-01-17 | (ce) | Add warning when concatAllDiscsFound is overridden due to DiscTotal setting.
| v0.9.15 | 2018-01-28 | (ce) | Adapted "prefixToProcess" into array.
| v0.9.16 | 2018-02-06 | (ce) | Fixed missing sample rate evaluation.
| v1.0.0  | 2018-09-11 | (ce) | Renamed “process-audio” to “convert-flac-collection”.
| v1.0.1  | 2019-05-27 | (ce) | Fix wrong bitsize or sample rate in non-concatted files.
 
 
 
## fdkaac parameter settings


| Object Type ID| Audio Object Type| Recommended for|
|:--------:|:--------------------------------|------------|
|        2 | MPEG-4 AAC LC (default)         |            |
|        5 | MPEG-4 HE-AAC (SBR)             |32–80 kbit/s|
|       29 | MPEG-4 HE-AAC v2 (SBR+PS)       |16–40 kbit/s|
|       23 | MPEG-4 AAC LD                   |Low Latency |
|       39 | MPEG-4 AAC ELD                  |            |


## fdkaac pre-sets in “convert-flac-collection”

```
#fdkaacSettingsAudiobook = "-p 5 -b 40000"
fdkaacSettingsAudiobook = "-p 5 -m 1"

#fdkaacSettingsAudiotheatre = "-p 5 -b 56000"
fdkaacSettingsAudiotheatre = "-p 5 -m 1"

#fdkaacSettingsMusic = "-p 2 -b 128000"
#fdkaacSettingsMusic = "-p 2 -m 4" # is about 128k
fdkaacSettingsMusic = "-p 5 -m 2"
```

## fdkaac quality impressions

 _“SBR becomes a lot less useful above 64kbs, so it definitely does not scale with bitrate.”_  
 — [Hydrogenaudio, “Topic: Bang for the byte and quality of HE-AAC / LC vs MP3”](https://hydrogenaud.io/index.php/topic,102051.0.html)

_HE-AAC 48 kbps equals about LC-AAC 64 kbps equals about MP3 96 kbps._  
 — [Hydrogenaudio, “Topic: Bang for the byte and quality of HE-AAC / LC vs MP3”](https://hydrogenaud.io/index.php/topic,102051.0.html)

_… With that premise, HE-AAC is an extension of LC-AAC which roughly requires half the bitrate. So 64kbps HE-AAC (v1) would roughly be similar to 128kbps LC-AAC, and 48kbps HE-AAC (v1) would roughly be silimar to LC-AAC 96kbps which is roughly similar to 128kbps MP3._  
 — [Hydrogenaudio, “Topic: Bang for the byte and quality of HE-AAC / LC vs MP3”](https://hydrogenaud.io/index.php/topic,102051.0.html)

## (fdk)aac References:
- Hydrogenaudio: [Fraunhofer FDK AAC](https://wiki.hydrogenaud.io/index.php?title=Fraunhofer_FDK_AAC)
- Github: [nu774/fdkaac](https://github.com/nu774/fdkaac)
- Wikipedia: [MPEG-4 High Efficiency Advanced Audio Coding](https://de.wikipedia.org/wiki/MPEG-4_High_Efficiency_Advanced_Audio_Coding)
- Wikipedia: [Advanced Audio Coding](https://de.wikipedia.org/wiki/Advanced_Audio_Coding)


## ToDos
- Detect non-ASCII filesames.
- Eliminate `--composer ""`.
- flac-code: Test whether output is really S16little at 44100Hz.
- Quote commandline-" quotes everywhere, see title-gsub.
- Avoid `._filename.flac` files. "dot-unerscore"-Files are created automatically by macOS: [“Why are dot underscore files created, and how can I avoid them?”](https://apple.stackexchange.com/questions/14980/why-are-dot-underscore-files-created-and-how-can-i-avoid-them)
- Test whether cover exists at all.