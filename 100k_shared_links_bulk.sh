#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

usage() {
  cat <<EOF

Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] base_folder_id

Create shared links from csv list of folders.

Positional arguments:
  file-path   The file path to your csv file.

Available options:
-h, --help      Print this help and exit
-v, --verbose   Print script debug info

EOF
  exit
}

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
}

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

msg() {
  echo >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1

  msg "$msg"
  exit "$code"
}

parse_params() {
  # default values of variables set from params
  force=0
  param=''

  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -v | --verbose) set -x ;;
    --no-color) NO_COLOR=1 ;;
    # -f | --force) force=1 ;; # example flag
    # -p | --param) # example named parameter
    #   param="${2-}"
    #   shift
    #   ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

  args=("$@")

  # check required params and arguments
#   [[ -z "${param-}" ]] && die "Missing required parameter: param"
  [[ ${#args[@]} -eq 0 ]] && msg "Missing base folder name" && usage

  return 0
}

####################  Helpers  ####################



####################  Main script  ####################

parse_params "$@"
setup_colors

csv_file="${args[0]}"
csv_file_out="${csv_file%.*}_shared_links_tmp.csv"

# Check if csv file exists
if [ ! -f "$csv_file" ]; then
  msg "${RED}Error: ${csv_file} does not exist.${NOFORMAT}"
  die "Please check the file path and try again."
fi

# Set bulk input file name
csv_file_bulk="${csv_file%.*}_bulk_input.csv"

# Create bulk input file with proper first line
echo parent_id,level,itemType,itemID,name > "$csv_file_bulk"

# Add remaining line line of csv file
while IFS=, read -r line; do
  parent_id=$(echo "$line" | cut -d, -f1)
  level=$(echo "$line" | cut -d, -f2)
  type=$(echo "$line" | cut -d, -f3)
  id=$(echo "$line" | cut -d, -f4)
  name=$(echo "$line" | cut -d, -f5)

  if [ "$level" == "1" ]; then
    echo $parent_id,$level,$type,$id,$name >> "$csv_file_bulk"
  fi
  
done < "$csv_file"

# Create shared links from csv file
box shared-links:create -y --bulk-file-path $csv_file_bulk --access open --no-can-download --csv --fields url,effective_access,effective_permission --save-to-file-path $csv_file_out

# Join csv files
paste -d, "$csv_file_bulk" "$csv_file_out" > "${csv_file%.*}_shared_links_joined.csv"

# bulk folders get
# box folders:get --bulk-file-path tree_100k.csv --csv --fields type,id,name,shared_link,parent

# bulk shared-links get
# box shared-links:get --bulk-file-path tree_100k_shared_links_tmp.csv --csv --fields type,id,name,shared_link,parent

# remove shared links
# box shared-links:delete --bulk-file-path tree_100k_bulk_input.csv  -q


# msg "${RED}Read parameters:${NOFORMAT}"
# msg "- force: ${force}"
# msg "- param: ${param}"
# msg "- base folder: ${args[*]-}"
