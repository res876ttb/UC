#!/bin/bash

# Check dependencies
dependencies=(
  "basename"
  "echo"
  "printf"
)

# Global variables.
# We use environment variables as global variables because it is very hard for
# bash to modify the global variable inside a function. If a global variable
# is a constant, then please use global variable directly.
export UC_DEBUG="false"
export UC_VERBOSE="false"
export UC_MODE=""
export UC_FILES=""

# We should check the longer file extension first,
# or we my extract the extension of a.tar.gz as .gz file instead of .tar.gz file
# Format: extension required_tools compress_command decompress_command
ext_cmd_list=(
  '.tar.bz2' 'tar bzip2' 'tar -I lbzip2 -cf $args $target $source' 'tar jx $args -f $source'
  '.tar.tgz' 'tar gzip'  'tar zc $args -f $target $source'         'tar zx $args -f $source'
  '.tar.zst' 'tar zstd'  'tar -I zstd -c $args -f $target $source' 'tar -I zstd -x $args -f $source'
  '.tar.gz'  'tar gzip'  'tar zc $args -f $target $source'         'tar xz $args -f $source'
  '.tar.xz'  'tar xz'    'tar Jc $args -f $target $source'         'tar Jx $args -f $source'
  '.tar'     'tar'       'tar c $args -f $target $source'          'tar x $args -f $source'
  '.gz'      'gzip'      'gzip $args $source'                      'gzip -d $args $source'
  '.bz2'     'bzip2'     'bzip2 -z $args $source'                  'bzip2 -d $args $source'
  '.xz'      'xz'        'xz -z $args $source'                     'xz -d $args $source'
  '.tgz'     'tar gzip'  'tar zcf $args $target $source'           'tar zx $args -f $source'
  '.7z'      '7z'        '7z a $args $target $source'              '7z x $args $source'
  '.zip'     'zip unzip' 'zip -r $args $target $source'            'unzip $args $source'
  '.rar'     'rar'       'rar a $args $target $source'             'rar e $args $source'
  '.zst'     'zstd'      'zstd $args $source -o $target'           'zstd -d $args $source'
)
ext_cmd_list_len=${#ext_cmd_list[@]}
ext_cmd_list_row_len=4

supported_file_type_list=()
for ((i = 0; i < "${#ext_cmd_list[@]}"; i += $ext_cmd_list_row_len)); do
  supported_file_type_list+=(${ext_cmd_list[i]})
done

# Functions
function Eecho() {
  # echo to stderr
  >&2 echo $@
}

function Debug() {
  if [[ "$UC_DEBUG" == "true" ]]; then
    >&2 echo $@
  fi
}

function FirstChar() {
  printf %.1s "$@"
}

function PrintHelp() {
cat << EOF
Usage: uc <mode> [<arguments for each mode>]
Description: Unified Cmopression Tool Wraper

Availaile mode: [c, d, help]
  c     Compress mode.
        Usage: uc c [<args>] <files to compress> ... <compressed file name>
        For .gz/.bz2/.xz, please use additional options: -gz/-bz2/-xz
        Ex. uc c -gz test.txt test2.txt
  d     Decompress mode.
        Usage: uc d [<args>] <files to decompressed> ...
  help  print this help message

Common arguments for [c/d] mode:
  -p    Preview the given compressed file if supported.
  -v    Show which file is been compressed/decompressed.
  -vvv  Show verbose log of uc.

Arguments for [d] mode:
  -d    Create directories for each individual file to decompressed, move
        them into the directory, then perform decompression
        Ex. uc d -d test.tar.gz will generate a directory called test, then
        put all the decompressed files into it.
EOF
}

function CheckFileDirectoryExist() {
  for i in $@; do
    if [[ ! -e $i ]]; then
      Eecho "File or directory $i does not exist!"
      return
    fi
  done

  echo "check pass"
}

function CheckFilesExist() {
  for i in $@; do
    if [[ ! -f $i ]]; then
      Eecho "File $i does not exist!"
      return
    fi
  done

  echo "check pass"
}

function GetFileType() {
  # Pass: return file type
  # Fail: return "unknown type"
  for supported_file_type in ${supported_file_type_list[@]}; do
    filename=$(basename $1 $supported_file_type)
    if [[ "$filename" != "$1" || "$filename" == "$supported_file_type" ]]; then
      echo $supported_file_type
      return
    fi
  done

  echo "unknown type"
}

function CheckFilesType() {
  # Check pass: return "check pass"
  # Check fail: return "check fail"
  if [[ "$UC_MODE" == "c" ]]; then
    # For compress mode, file type checking for gz/bz2/xz
    if [[ "$UC_COMP_MODE_GZ" == "true" || "$UC_COMP_MODE_BZ2" == "true" || "$UC_COMP_MODE_XZ" == "true" ]]; then
      echo "check pass"
      return
    fi
  fi

  check_pass=true
  for i in $@; do
    file_type="$(GetFileType $i)"

    if [[ "$file_type" == "unknown type" ]]; then
      Eecho "Unsupported: $i"
      check_pass=false
    fi
  done

  if [[ "$check_pass" == "true" ]]; then
    echo "check pass"
  else
    echo "check fail"
  fi
}

function GetDecompressCommand() {
  if [[ $# -ne 1 ]]; then
    Eecho "Invalid argument for DecompressFile: $@"
    echo "fail"
    return
  fi

  file_type=$1

  for ((i = 0; i < $ext_cmd_list_len; i += $ext_cmd_list_row_len)); do
    if [[ "$file_type" == "${ext_cmd_list[$i]}" ]]; then
      echo "${ext_cmd_list[$((i + 3))]}"
      return
    fi
  done

  echo "fail"
}

function GetCompressCommand() {
  if [[ $# -ne 1 ]]; then
    Eecho "Invalid argument for CompressFile: $@"
    echo "fail"
    return
  fi

  file_type=$1

  for ((i = 0; i < $ext_cmd_list_len; i += $ext_cmd_list_row_len)); do
    if [[ "$file_type" == "${ext_cmd_list[$i]}" ]]; then
      echo "${ext_cmd_list[$((i + 2))]}"
      return
    fi
  done

  echo "fail"
}

function GetDecompressArgs() {
  file_type=$1
  args=""

  if [[ "$UC_VERBOSE" == "true" ]]; then
    case $file_type in
      '.tar.bz2' | \
      '.tar.tgz' | \
      '.tar.zst' | \
      '.tar.gz' | \
      '.tar.xz' | \
      '.tar' | \
      '.gz' | \
      '.tgz' | \
      '.bz2' | \
      '.xz' | \
      '.zip' )
        args="-v"
      ;;

      '.7z' )
        args="-bb3"
      ;;

      '.zst' )
        args="-vvv"
      ;;

      '.rar' )
        Eecho "[WARN] No verbose option supported for .rar. Skipped."
        args=""
      ;;

      *)
        Eecho Unsupported type $file_type!
      ;;
    esac
  fi
  echo $args
}

function GetCompressArgs() {
  file_type=$1
  args=""

  if [[ "$UC_VERBOSE" == "true" ]]; then
    case $file_type in
      '.tar.bz2' | \
      '.tar.tgz' | \
      '.tar.zst' | \
      '.tar.gz' | \
      '.tar.xz' | \
      '.tar' | \
      '.gz' | \
      '.tgz' | \
      '.bz2' | \
      '.xz' | \
      '.zip' )
        args="-v"
      ;;

      '.7z' )
        args="-bb3"
      ;;

      '.zst' )
        args="-vvv"
      ;;

      '.rar' )
        Eecho "[WARN] No verbose option supported for .rar. Skipped."
        args=""
      ;;

      *)
        Eecho Unsupported type $file_type!
      ;;
    esac
  fi
  echo $args
}

function CreateDecompressDirectory() {
  filename=$1
  file_type=$2
  rev_file_type=$(echo "$file_type" | rev)
  rev_filename=$(echo "$filename" | rev)
  directory_to_create=$(echo "$rev_filename" | sed "s/$rev_file_type//1g" | rev)

  if [[ -d "$directory_to_create" ]]; then
    Eecho "[ERROR] Target directory exists!"
    exit 1
  else
    mkdir -p "$directory_to_create"
    cd "$directory_to_create"
  fi
}

function DecompressFile() {
  if [[ $# -ne 1 ]]; then
    Eecho "Invalid argument for DecompressFile: $@"
    echo "fail"
    return
  fi

  filename=$1
  file_type="$(GetFileType $1)"
  decompress_cmd="$(GetDecompressCommand $file_type)"
  args="$(GetDecompressArgs $file_type)"
  Debug "Decompressing file: $filename, file_type: $file_type, args: $args"

  if [[ "$decompress_cmd" == "fail" ]]; then
    echo "fail"
    return
  fi

  if [[ "$args" != "" ]]; then
    export args
  else
    unset args
  fi

  if [[ "$UC_DECOMP_NEW_DIR" != "" ]]; then
    # Create target directory and cd into it
    CreateDecompressDirectory $filename $file_type

    # Update filename if the filename is a relative path
    case $filename in
      /*) ;;
      *)  filename=../$filename ;;
    esac
  fi

  export source="$filename"

  run_command=$(eval echo $decompress_cmd)
  Debug Command: $run_command
  >&2 $run_command

  if [[ "$?" != "0" ]]; then
    Debug Failed to run decompression command: $run_command
    echo "fail"
    return
  fi
}

function CompressFile() {
  filename=""
  if [[ "$UC_COMP_MODE_GZ" == "true" ]]; then
    filename="fake.gz"
  elif [[ "$UC_COMP_MODE_BZ2" == "true" ]]; then
    filename="fake.bz2"
  elif [[ "$UC_COMP_MODE_XZ" == "true" ]]; then
    filename="fake.xz"
  else
    filename=$1
    shift
  fi
  files_to_compress=$@
  file_type=""

  file_type="$(GetFileType $filename)"
  compress_cmd="$(GetCompressCommand $file_type)"
  args="$(GetCompressArgs $file_type)"
  Debug "Compressing files: [$files_to_compress], creating: $filename, file_type: $file_type, args: $args"

  if [[ "$compress_cmd" == "fail" ]]; then
    echo "fail"
    return
  fi

  if [[ "$args" != "" ]]; then
    export args
  else
    unset args
  fi

  export target=$filename
  export source="$files_to_compress"

  run_command=$(eval echo $compress_cmd)
  Debug Command: $run_command
  >&2 $run_command

  if [[ "$?" != "0" ]]; then
    Debug Failed to run compression command: $run_command
    echo "fail"
    return
  fi
}

function Decompress() {
  # Check whether file exists
  if [[ "$(CheckFilesExist $@)" != "check pass" ]]; then
    Eecho "Some files do not exist. Aborted."
    return
  fi

  # Check whether file type is supported
  if [[ "$(CheckFilesType $@)" == "check fail" ]]; then
    Eecho "Some files are not supported. Aborted."
    return
  fi

  # Decompress all the files
  for file in $@; do
    if [[ "$(DecompressFile $file)" == "fail" ]]; then
      Eecho "Failed to decompress $file. Aborted."
    fi
  done
}

function Compress() {
  # Get all the files to be compressed
  files_to_compress=""
  compressed_file=""
  while [[ $# -gt 1 ]]; do
    files_to_compress+=" $1"
    shift
  done
  compressed_file="$1"

  # Check whether file exists
  if [[ "$(CheckFilesExist $files_to_compress)" != "check pass" ]]; then
    Eecho "Some files do not exist. Aborted."
    return
  fi

  # Check whether file type is supported
  if [[ "$(CheckFilesType $compressed_file)" == "check fail" ]]; then
    Eecho "Some files are not supported. Aborted."
    return
  fi

  # Compress all the files
  if [[ "$(CompressFile $compressed_file $files_to_compress)" == "fail" ]]; then
    Eecho "Failed to compress $file. Aborted."
  fi
}

function ParseArgs() {
  # Check whether we have enough number of arguments
  if [[ $# -lt 2 ]]; then
    export UC_MODE="help"
    return
  fi

  # Check whether there is debug flag set
  while [[ $# -gt 0 ]]; do
    if [[ "$(FirstChar $1)" != "-" && "$UC_MODE" != "" ]]; then
      UC_FILES="$@"
      break
    fi

    case "$1" in
      "d" )     export UC_MODE="d" ;;
      "c" )     export UC_MODE="c" ;;
      "help" )  export UC_MODE="help" ;;
      "-v" )    export UC_VERBOSE="true" ;;
      "-vvv" )  export UC_DEBUG="true" ;;
      "-gz" )   export UC_COMP_MODE_GZ="true" ;;
      "-bz2" )  export UC_COMP_MODE_BZ2="true" ;;
      "-xz" )   export UC_COMP_MODE_XZ="true" ;;
      "-d" )    export UC_DECOMP_NEW_DIR="ture" ;;
    esac

    shift
  done
}

function Main() {
  ParseArgs $@

  Debug UC_MODE = $UC_MODE
  Debug UC_FILES = $UC_FILES
  if [[ "$UC_MODE" == "d" ]]; then
    shift
    Decompress $UC_FILES
  elif [[ "$UC_MODE" == "c" ]]; then
    shift
    Compress $UC_FILES
  elif [[ "$UC_MODE" == "help" ]]; then
    PrintHelp
  else
    if [[ "$UC_MODE" == "" ]]; then
      Eecho "Mode is not specified."
    else
      Eecho "Unknown mode: $UC_MODE"
    fi
    Eecho ""
    PrintHelp
  fi
}

Main $@
