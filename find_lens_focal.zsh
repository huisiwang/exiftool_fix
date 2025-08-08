#!/bin/zsh
# v1.2
# 功能：
#  - 支援命令列參數 --focal=焦距(可多個逗號或空格分隔)，
#    例如 --focal=28mm,50mm 或 --focal="28mm 50mm"
#  - 支援 --all，掃描資料夾所有符合格式的圖片，依完整鏡頭名稱分類統計
#  - 支援 --path=資料夾路徑，預設為當前目錄
#  - 支援 -r 或 --recursive 參數，預設不遞歸搜尋子目錄，指定後遞歸
#  - 日誌寫入 $HOME/Pictures/zero_mm_found.log，格式統一，並含空行分隔
#  - 若未帶任何參數，會輸出簡易操作說明並結束

setopt extended_glob

# 日誌檔案
log_file="$HOME/Pictures/zero_mm_found.log"

# 預設參數
input_path="."
focal_input=""
mode="focal"  # focal or all
recursive=false

# 先判斷是否有參數，沒參數顯示用法並退出
if [[ $# -eq 0 ]] || [[ "$1" == "--help" ]]; then
  echo "Usage:"
  echo "  $0 --path=資料夾路徑 [--focal=焦距1,焦距2,... | --all] [-r|--recursive] [--help]"
  echo "  --path: 指定掃描目錄，預設當前目錄"
  echo "  --focal: 指定焦距，如28mm或28mm,50mm"
  echo "  --all: 掃描所有鏡頭並依完整鏡頭名稱分類"
  echo "  -r, --recursive: 是否遞歸搜尋子目錄，預設否"
  echo "  --help: 顯示此說明"
  exit 0
fi

# 解析參數
for arg in "$@"; do
  case $arg in
    --path=*)
      input_path="${arg#*=}"
      ;;
    --focal=*)
      focal_input="${arg#*=}"
      ;;
    --all)
      mode="all"
      ;;
    -r|--recursive)
      recursive=true
      ;;
  esac
done

# 確認路徑存在
if [[ ! -d "$input_path" ]]; then
  echo "指定的路徑不存在或不是目錄：$input_path"
  exit 1
fi

# 根據是否遞歸決定 find 指令
if $recursive; then
  find_cmd=(find "$input_path" -type f \( -iname "*.nef" -o -iname "*.dng" -o -iname "*.cr2" \))
else
  find_cmd=(find "$input_path" -maxdepth 1 -type f \( -iname "*.nef" -o -iname "*.dng" -o -iname "*.cr2" \))
fi

function set_log() {
  # 初始化日誌檔案（存在則追加空行）
  if [[ -s "$log_file" ]]; then
    echo "" >> "$log_file"
  fi
}

function look_for() {
  echo "Looking for images with [$focal_length] in $(realpath "$input_path") ..."
  found_in_folder=false

  # 先找到檔案，再取不重複的資料夾
  files=($( "${find_cmd[@]}" ))
  if [[ ${#files[@]} -eq 0 ]]; then
    echo "No images found."
    return
  fi
  folders=($(printf "%s\n" "${files[@]}" | xargs -n1 dirname | sort -u))

  for folder in "${folders[@]}"; do
    # 用exiftool找含指定焦距開頭的Lens欄位
    lens_spec=$(exiftool -ext nef -ext dng -ext cr2 -if "\$Lens =~ /^$focal_length/" "$folder" 2>/dev/null | tail -n 1 | awk '{print $1}')
    
    if [[ "$lens_spec" != "0" ]]; then
      abs_path="$(realpath "$folder")"
      echo "$lens_spec images found in	$abs_path" | tee -a "$log_file"
      found_in_folder=true
    fi
  done

  if ! $found_in_folder; then
    echo "No images found." | tee -a "$log_file"
    echo "" >> "$log_file"
  fi
}

function look_for_all() {
  echo "Scanning all images in $(realpath "$input_path") ..."
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  # 找到所有符合條件的資料夾（是否遞歸由 use_recursive 控制）
  if $use_recursive; then
    folders=($(find "$input_path" -type f \( -iname "*.nef" -o -iname "*.dng" -o -iname "*.cr2" \) -exec dirname {} \; | sort -u))
  else
    folders=($(find "$input_path" -maxdepth 1 -type f \( -iname "*.nef" -o -iname "*.dng" -o -iname "*.cr2" \) -exec dirname {} \; | sort -u))
  fi

  # 建立鏡頭 -> 資料夾 -> 張數 的結構
  typeset -A lens_folder_map

  for folder in "${folders[@]}"; do
    while IFS= read -r line; do
      # line 格式："Lens Name" /full/path/to/image.ext
      lens=$(echo "$line" | sed -E 's/^"([^"]+)" .*/\1/')
      [[ -z "$lens" || "$lens" == "Unknown" ]] && continue

      key="$lens|||$folder"
      ((lens_folder_map[$key]++))
    done < <(exiftool -ext nef -ext dng -ext cr2 -Lens -T "$folder" 2>/dev/null)
  done

  if [[ ${#lens_folder_map[@]} -eq 0 ]]; then
    echo "No images found."
    echo "$timestamp No images found in $(realpath "$input_path")" >> "$log_file"
    return
  fi

  echo ""
  echo "掃描結果："
  echo ""

  # 整理出所有鏡頭
  lenses=()
  for key in "${(@k)lens_folder_map}"; do
    lens="${key%%|||*}"
    if [[ -z ${(M)lenses:#$lens} ]]; then
      lenses+=("$lens")
    fi
  done

  for lens in "${lenses[@]}"; do
    echo "鏡頭：$lens"
    echo "$timestamp Looking for images with [$lens] lens in $(realpath "$input_path")" >> "$log_file"
    
    for key in "${(@k)lens_folder_map}"; do
      this_lens="${key%%|||*}"
      folder="${key##*|||}"
      count="${lens_folder_map[$key]}"
      
      if [[ "$this_lens" == "$lens" ]]; then
        echo "  $count images found in\t$folder"
        echo "$count images found in\t$folder" >> "$log_file"
      fi
    done
    echo ""
    echo "" >> "$log_file"
  done
}

# 執行流程
if [[ "$mode" == "all" ]]; then
  look_for_all
else
  if [[ -z "$focal_input" ]]; then
    focal_lengths=("0mm")
  else
    focal_input="${focal_input//,/ }"
    focal_lengths=(${=focal_input})
  fi

  for focal_length in "${focal_lengths[@]}"; do
    set_log
    look_for
  done
fi

