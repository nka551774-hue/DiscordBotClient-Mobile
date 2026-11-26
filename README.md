# DiscordBotClient Mobile (Android APK & iOS IPA)

參考 [aiko-chan-ai/DiscordBotClient](https://github.com/aiko-chan-ai/DiscordBotClient) 核心功能重新打造的 **原生 AOT 編譯手機版 Discord 機器人客戶端**。捨棄傳統桌面版龐大的 Electron / WebView 與本地 Proxy 架構，改以 Flutter Impeller 原生引擎直連 Discord API v10 與 Zlib 串流壓縮 Gateway，將記憶體與電池耗能壓至極限，同時支援 **120Hz ProMotion 絲滑滾動**。

---

## ✨ 核心特色

### 🔋 極致省電與極速流暢設計
1. **零 WebView / 零本地背景伺服器**：原生 ARM64 機器碼直接發送 `Authorization: Bot <token>` 與連線 WebSocket，無多餘背景行程耗電。
2. **OLED 純黑模式 (`#000000`)**：預設關閉現代手機 OLED 螢幕黑色子像素發光，大幅降低螢幕耗電量。
3. **智慧 Eco 背景自動休眠引擎**：切換至背景或關閉螢幕達設定秒數（預設 25 秒）自動切斷 WebSocket 讓手機無線電進入深層睡眠（背景 0% 耗電），回到前景瞬間透過 `op: 6 RESUME` 無縫重連。
4. **選擇性 Gateway Intents 過濾**：預設關閉最耗電的 `GUILD_PRESENCES` 與 `TYPING` 廣播，在大型伺服器可減少 **80% 以上** 的封包喚醒。
5. **120fps 局部重繪與低解析度材質解碼**：採用 `RepaintBoundary`、`ValueNotifier` 局部狀態更新（心跳與打字狀態絕不重繪整個畫面），圖片自動請求 WebP 縮圖並限制 GPU 解碼尺寸與 35MB 快取上限。

### 🤖 完整機器人專屬功能（致敬 DiscordBotClient）
- **多機器人帳號管理**：支援儲存多個 Bot Token 一鍵快速切換。
- **`4014` 特權 Intent 智慧降級**：若忘記在 Discord Developer Portal 開啟 `MESSAGE_CONTENT` Intent，自動降級為基礎權限完成登入並顯示引導提示，絕不卡死。
- **持久化私人訊息 (DM) 資料庫**：突破機器人無法讀取 `/users/@me/channels` 列表的限制，自動記錄所有收發的私訊，並支援點擊任何成員或輸入 `User ID` 主動開啟私訊。
- **機器人專屬 Rich Embed 產生器**：在手機上直接挑選色票、填寫標題/描述/並排欄位/圖片，一鍵以機器人身分發送精美 Embed！
- **完整訊息互動**：Markdown 語法高亮、程式碼區塊複製、`||劇透||` 點擊展開、圖片預覽縮放、上傳相簿圖片、回覆、編輯、刪除、釘選檢視與 Emoji 反應。
- **伺服器管理與工具箱**：搜尋/踢出/封鎖成員、新增/刪除文字與語音頻道、產生頻道邀請連結、檢視審計日誌 (Audit Logs)、更改機器人線上狀態 (Online/Idle/DND/Invisible + 自訂活動) 以及自動產生 **OAuth2 機器人邀請連結**。

---

## 📲 安裝教學

### Android (`.apk`)
1. 前往本儲存庫 **Releases**（或本機 `releases/` 資料夾）下載：
   - 一般新款手機推薦安裝 **`DiscordBotClient-arm64-v8a.apk`**（體積最輕巧）。
   - 模擬器或舊款設備可安裝 **`DiscordBotClient-universal.apk`**。
2. 點擊 APK 允許安裝即可立即使用。

### iOS (`.ipa`)
由於 iOS 系統限制，未上架 App Store 的 `.ipa` 檔案請透過以下任一免費側載工具安裝 **`DiscordBotClient-ios.ipa`**：
- **Sideloadly**（Windows / macOS）：連接 iPhone，拖入 `DiscordBotClient-ios.ipa`，輸入一般免費 Apple ID 自動簽名安裝。
- **AltStore / SideStore**：將 `.ipa` 傳送至 iPhone「檔案」，在 AltStore / SideStore 點擊 `+` 選擇檔案安裝。
- **TrollStore / Feather / ESign**：本 `.ipa` 已預先完成 Ad-Hoc 偽簽名 (`codesign -s -`)，可直接匯入秒裝！

---

## ⚙️ 使用前準備（重要）
為了讓機器人能讀取頻道內其他人發送的文字內容：
1. 前往 [Discord Developer Portal](https://discord.com/developers/applications) 選擇您的機器人應用。
2. 進入左側 **Bot** 頁面，向下捲動至 **Privileged Gateway Intents**。
3. 開啟 **`MESSAGE CONTENT INTENT`** 並點擊 Save Changes。
