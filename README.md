# DiscordBotClient Mobile (Android APK & iOS IPA)

參考 [aiko-chan-ai/DiscordBotClient](https://github.com/aiko-chan-ai/DiscordBotClient) 打造的手機版 Discord 機器人客戶端。完整還原原版 `DiscordBotClient` 的機器人 Token 登入介面（`Welcome back!` / `BOT TOKEN`）以及官方 Discord 手機版四大分頁介面（`Servers`、`Messages`、`Notifications`、`You`），底層採用 Flutter AOT 原生 ARM64 機器碼直連 Discord API v10 與 Zlib 壓縮 Gateway，在維持原汁原味操作體驗的同時將耗能壓至最低並支援 120Hz 流暢滾動。

---

## 介面與功能說明

### 原版介面還原
- **登入介面**：與 `aiko-chan-ai/DiscordBotClient` 完全一致的星夜漸層背景、`Welcome back!` 登入卡片、`BOT TOKEN` 密碼輸入框，以及多帳號切換 (`Choose an account` / `< Go back`)。
- **官方 Discord 手機版佈局**：
  - **Servers**：左側垂直伺服器圖示列與圓角頻道列表（支援分類摺疊與未讀提示）。
  - **Messages**：私人訊息列表、搜尋列，以及與 `VencordDBCPlugin` 一致的 `New Message`（透過 User ID 開啟私訊）對話框。
  - **Notifications**：集中顯示機器人收到的提及、回覆與私訊通知。
  - **You**：機器人個人檔案頁、上線狀態切換（Online / Idle / Do Not Disturb / Invisible 與活動狀態）、帳號切換，以及 `Settings`（支援切換 Discord `Dark` 與 `Midnight` 純黑模式）。
- **原版聊天室體驗**：全螢幕滑入式聊天頁（支援手機返回手勢）、左滑訊息快速回覆、長按圓形快速表情反應列、釘選訊息檢視、成員名單抽屜，以及輸入框內嵌原版 `Create Embed` 按鈕。

### 底層低耗能與流暢度最佳化
1. **零 WebView / 零本地背景伺服器**：原生 ARM64 機器碼直接連線 Discord 官方端點，閒置時零背景重繪。
2. **背景自動休眠與快速恢復**：切換至背景自動休眠 WebSocket 降低無線電耗電，返回前景即時透過 `RESUME` 恢復連線。
3. **120fps 局部更新與縮圖快取限制**：採用 `RepaintBoundary`、`ValueNotifier` 局部更新與 WebP 縮圖解碼限制，iOS 已啟用 `CADisableMinimumFrameDurationOnPhone` 支援 120Hz ProMotion。

---

## 安裝教學

### Android (`.apk`)
1. 前往本儲存庫 **Releases**（或本機 `releases/` 資料夾）下載：
   - 一般新款手機推薦安裝 **`DiscordBotClient-arm64-v8a.apk`**。
   - 模擬器或舊款設備可安裝 **`DiscordBotClient-universal.apk`**。
2. 點擊 APK 安裝即可使用。

### iOS (`.ipa`)
請透過以下任一側載工具安裝 **`DiscordBotClient-ios.ipa`**：
- **Sideloadly**（Windows / macOS）：連接 iPhone，拖入 `DiscordBotClient-ios.ipa`，輸入 Apple ID 自動簽名安裝。
- **AltStore / SideStore**：將 `.ipa` 傳送至 iPhone「檔案」，於 AltStore / SideStore 點擊 `+` 安裝。
- **TrollStore / Feather / ESign**：本 `.ipa` 已預先完成 Ad-Hoc 偽簽名 (`codesign -s -`)，可直接匯入安裝。

---

## 使用前準備
為了讓機器人能讀取頻道內其他人發送的文字內容：
1. 前往 [Discord Developer Portal](https://discord.com/developers/applications) 選擇您的應用程式。
2. 進入 **Bot** 頁面，向下捲動至 **Privileged Gateway Intents**。
3. 開啟 **`MESSAGE CONTENT INTENT`** 並點擊 Save Changes。
