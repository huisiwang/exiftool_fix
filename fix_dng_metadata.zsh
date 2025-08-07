#!/bin/zsh

# ========================================
# fix_dng_metadata.zsh
# 功能說明：
# 1. 使用 exiftool 修改 DNG (大小寫兼容) 檔案的 EXIF 資訊
# 2. 移除機內自動轉接環校正資料：清空 OpcodeList3
# 3. 可選擇是否同時移除暗角校正（OpcodeList2）
# 4. 根據檔案中原有的 LensSpec，套用鏡頭資訊（lens, lens_info, DNGLensInfo, lens_model）
# 5. 強制設定 lens_make 為 "Zeiss"
# 6. 可指定處理整個目錄，或單獨指定檔案
# 7. 提供 verbose 模式以顯示詳細處理資訊
# 8. 統計成功與失敗的處理結果
# ========================================

# 檢查 exiftool 版本
required_version=13
current_version=$(exiftool -ver | cut -d. -f1)
if (( current_version < required_version )); then
  echo "❌ exiftool 版本過低，請安裝 13 或以上版本。"
  exit 1
fi

# 預設值
REMOVE_OPCODE2=false
PROCESS_CURRENT_DIR=false
VERBOSE=false
LENS_MAKE="Zeiss"
success_count=0
fail_count=0

# 處理參數
args=()
for arg in "$@"; do
  case $arg in
    --remove-vignette)
      REMOVE_OPCODE2=true
      ;;
    --current-dir)
      PROCESS_CURRENT_DIR=true
      ;;
    --verbose)
      VERBOSE=true
      ;;
    *)
      args+=("$arg")
      ;;
  esac
done

# 準備要處理的檔案列表
files=()
if [[ $PROCESS_CURRENT_DIR == true ]]; then
  files=(./*.[dD][nN][gG])
elif (( ${#args} > 0 )); then
  files=("${args[@]}")
else
  echo "⚠️  請指定要處理的檔案，或加上 --current-dir 以處理當前目錄內的 DNG 檔案。"
  exit 1
fi

# 處理每個檔案
for file in $files; do
  if [[ ! -f "$file" ]]; then
    echo "❌ 檔案不存在，略過：$file"
    ((fail_count++))
    continue
  fi

  echo "📷 處理檔案：$file"

  # 取得 LensSpec
  lens_spec=$(exiftool -s3 -LensSpec "$file")

  # 根據 LensSpec 判斷鏡頭資料
  case "$lens_spec" in
    *21mm*)
      lens="21mm f/2.8"
      lens_info="21mm f/2.8"
      dng_lens_info="21mm f/2.8"
      lens_model="Contax G 21mm f/2.8"
      ;;
    *28mm*)
      lens="28mm f/2.8"
      lens_info="28mm f/2.8"
      dng_lens_info="28mm f/2.8"
      lens_model="Contax G 28mm f/2.8"
      ;;
    *35mm*)
      lens="35mm f/2.0"
      lens_info="35mm f/2.0"
      dng_lens_info="35mm f/2.0"
      lens_model="Contax G 35mm f/2.0"
      ;;
    *45mm*)
      lens="45mm f/2.0"
      lens_info="45mm f/2.0"
      dng_lens_info="45mm f/2.0"
      lens_model="Contax G 45mm f/2.0"
      ;;
    *90mm*)
      lens="90mm f/2.8"
      lens_info="90mm f/2.8"
      dng_lens_info="90mm f/2.8"
      lens_model="Contax G 90mm f/2.8"
      ;;
    *)
      echo "⚠️  未支援的 LensSpec，略過：$file"
      ((fail_count++))
      continue
      ;;
  esac

  # 顯示詳細資訊（若啟用 verbose）
  if [[ $VERBOSE == true ]]; then
    echo "🔍 偵測到 LensSpec：$lens_spec"
    echo "✏️ 將套用以下鏡頭資訊："
    echo "    Lens:           $lens"
    echo "    LensInfo:       $lens_info"
    echo "    DNGLensInfo:    $dng_lens_info"
    echo "    LensModel:      $lens_model"
    echo "    LensMake:       $LENS_MAKE"
    echo "    移除 OpcodeList3 ✅"
    if [[ $REMOVE_OPCODE2 == true ]]; then
      echo "    同時移除 OpcodeList2 ✅（暗角校正）"
    else
      echo "    保留 OpcodeList2 ❎"
    fi
  fi

  # 組合 exiftool 命令
  cmd=(exiftool
    -overwrite_original
    "-Lens=$lens"
    "-LensInfo=$lens_info"
    "-DNGLensInfo=$dng_lens_info"
    "-LensModel=$lens_model"
    "-LensMake=$LENS_MAKE"
    "-OpcodeList3=")

  if [[ $REMOVE_OPCODE2 == true ]]; then
    cmd+=("-OpcodeList2=")
  fi

  cmd+=("$file")

  # 執行 exiftool
  if "${cmd[@]}" >/dev/null; then
    ((success_count++))
  else
    echo "❌ 寫入失敗：$file"
    ((fail_count++))
  fi
done

# 統計總結
echo ""
echo "✅ 成功處理：$success_count 個檔案"
echo "❌ 處理失敗或略過：$fail_count 個檔案"

