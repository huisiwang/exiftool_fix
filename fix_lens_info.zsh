#!/bin/zsh
#
# fix_lens_info.zsh
# v1.1.2

# 此腳本用於批量修改 .cr2, .nef, .dng (大小寫兼容) 文件的 EXIF 資訊
# 1. 可透過 --lens_name 指定鏡頭型號，匹配對應資料寫入 EXIF
# 2. 支援從目前目錄 (--current-dir) 或自定目錄 (--dir=PATH) 掃描，或指定特定檔案
# 3. 檢查 exiftool 版本需大於 13
# 4. 支援 --verbose 參數控制是否顯示詳細鏡頭資訊

#set -e

#debug
#trap 'echo "錯誤發生於第 $LINENO 行"; exit 1' ERR

# 初始化變數
lens_name=""
use_current_dir=false
target_dir=""
verbose=false
files=()

# 如果沒有任何參數則顯示用法說明
if [[ $# -eq 0 ]]; then
  echo "用法：$0 [--lens_name=NAME] [--current-dir] [--dir=PATH] [--verbose] [file1 file2 ...]"
  echo "  --lens_name=NAME   指定鏡頭名稱 (必填)"
  echo "  --current-dir       掃描目前目錄中所有支援的檔案"
  echo "  --dir=PATH          指定要處理的目錄"
  echo "  --verbose           顯示詳細處理資訊"
  echo "  file1 file2 ...     可指定個別檔案"
  exit 1
fi

# 解析參數
for arg in "$@"; do
  case $arg in
    --lens_name=*)
      lens_name="${arg#*=}"
      ;;
    --current-dir)
      use_current_dir=true
      ;;
    --dir=*)
      target_dir="${arg#*=}"
      ;;
    --verbose)
      verbose=true
      ;;
    *)
      files+=("$arg")
      ;;
  esac
done

# 驗證 lens_name 是否提供
if [[ -z "$lens_name" ]]; then
  echo "錯誤：請使用 --lens_name=XXXX 指定鏡頭型號"
  exit 1
fi

# 驗證 exiftool 版本
if ! command -v exiftool >/dev/null; then
  echo "錯誤：未安裝 exiftool"
  exit 1
fi

exiftool_version=$(exiftool -ver | cut -d '.' -f1)
if (( exiftool_version < 13 )); then
  echo "錯誤：exiftool 版本需 >= 13"
  exit 1
fi

# 根據 lens_name 決定寫入哪些資訊
case "$lens_name" in
  G21)
    lens="21mm f/2.8"
    lens_info="21mm f/2.8"
    dng_lens_info="21mm f/2.8"
    lens_model="Contax G 21mm f/2.8"
    lens_make="Zeiss"
    ;;
  G28)
    lens="28mm f/2.8"
    lens_info="28mm f/2.8"
    dng_lens_info="28mm f/2.8"
    lens_model="Contax G 28mm f/2.8"
    lens_make="Zeiss"
    ;;
  G35)
    lens="35mm f/2.0"
    lens_info="35mm f/2.0"
    dng_lens_info="35mm f/2.0"
    lens_model="Contax G 35mm f/2.0"
    lens_make="Zeiss"
    ;;
  G45)
    lens="45mm f/2.0"
    lens_info="45mm f/2.0"
    dng_lens_info="45mm f/2.0"
    lens_model="Contax G 45mm f/2.0"
    lens_make="Zeiss"
    ;;
  G90)
    lens="90mm f/2.8"
    lens_info="90mm f/2.8"
    dng_lens_info="90mm f/2.8"
    lens_model="Contax G 90mm f/2.8"
    lens_make="Zeiss"
    ;;
  Summitar)
    lens="50mm f/2.0"
    lens_info="50mm f/2.0"
    dng_lens_info="50mm f/2.0"
    lens_model="Summitar 50mm f/2.0"
    lens_make="Leica"
    ;;
  *40mm*)
    lens="40mm f/2.0"
    lens_info="40mm f/2.0"
    dng_lens_info="40mm f/2.0"
    lens_model="Minolta M-Rokkor 40mm f/2.0"
    lens_make="Minolta"
    ;;
  *50AIS*)
    lens="50mm f/1.8"
    lens_info="50mm f/1.8"
    dng_lens_info="50mm f/1.8"
    lens_model="Nikkor AI-S 50mm f/1.8"
    lens_make="Nikon"
    ;;
  *24AIS*)
    lens="24mm f/2.8"
    lens_info="24mm f/2.8"
    dng_lens_info="24mm f/2.8"
    lens_model="Nikkor AI-S 24mm f/2.8"
    lens_make="Nikon"
    ;;
  *Pentax50M*)
    lens="50mm f/1.7"
    lens_info="50mm f/1.7"
    dng_lens_info="50mm f/1.7"
    lens_model="SMC Pentax-M 50mm f/1.7"
    lens_make="Asahi Opt. Co.,"
    ;;
  *Pentax55K*)
    lens="55mm f/1.8"
    lens_info="55mm f/1.8"
    dng_lens_info="55mm f/1.8"
    lens_model="SMC Pentax 55mm f/1.8"
    lens_make="Asahi Opt. Co.,"
    ;;
  *)
    echo "錯誤：未知的 lens_name 類型：$lens_name"
    exit 1
    ;;
esac

# 收集檔案
if [[ -n "$target_dir" ]]; then
  if [[ ! -d "$target_dir" ]]; then
    echo "錯誤：指定的目錄不存在：$target_dir"
    exit 1
  fi
  files=("$target_dir"/**/*.(cr2|CR2|nef|NEF|dng|DNG)(.N))
elif $use_current_dir; then
  files=(**/*.(cr2|CR2|nef|NEF|dng|DNG)(.N))
fi

# 若沒有檔案，顯示提示
if [[ ${#files[@]} -eq 0 ]]; then
  echo "錯誤：未指定檔案，請提供檔名或使用 --current-dir 或 --dir"
  exit 1
fi

# 執行寫入
success=0
fail=0

for file in "$files[@]"; do
  if $verbose; then
    echo "處理檔案：$file"
    echo "✏️ 將套用以下鏡頭資訊："
    echo "    Lens:           $lens"
    echo "    LensInfo:       $lens_info"
    echo "    DNGLensInfo:    $dng_lens_info"
    echo "    LensModel:      $lens_model"
    echo "    LensMake:       $lens_make"
  else
    echo "處理檔案：$file"
  fi

  args=(
    -overwrite_original
    -Lens="$lens"
    -LensInfo="$lens_info"
    -LensModel="$lens_model"
    -LensMake="$lens_make"
  )

  # 如果是 .dng 副檔名（大小寫兼容），加入 DNGLensInfo
  if [[ "${file:l}" == *.dng ]]; then
    args+=(-DNGLensInfo="$dng_lens_info")
  fi

  if exiftool "${args[@]}" "$file" >/dev/null; then
    ((success++))
  else
    ((fail++))
  fi
done

# 統計結果
echo "處理完成：成功 $success 個，失敗 $fail 個"

