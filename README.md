# DiscordBotClient Mobile (Android APK & iOS IPA)

參考 [aiko-chan-ai/DiscordBotClient](https://github.com/aiko-chan-ai/DiscordBotClient)、[aiko-chan-ai/VencordDBCPlugin](https://github.com/aiko-chan-ai/VencordDBCPlugin) 與 [Vendicated/Vencord](https://github.com/Vendicated/Vencord) 原始碼打造的原生級手機版 Discord 機器人客戶端。完整對齊原版 `DiscordBotClient` 的機器人登入機制、Vencord 插件生態與最新 Discord 手機版三欄跟手滑動介面，底層採用 Flutter AOT 原生 ARM64 機器碼直連 Discord API v10、Zlib 串流壓縮 Gateway 與 Voice Gateway v8，兼具最低耗能與 120Hz 流暢度。

---

## 核心機制與互動設計

### 原版 Discord 手機版互動體驗
- **三欄 120fps 跟手滑動架構**：
  - **左側導覽欄**：伺服器圓角矩形圖示列、頂部私人訊息入口、圓角頻道面板與官方底部導覽列「首頁 / 通知 / 你」（長按「你」切換帳號）。
  - **中間聊天欄**：支援右滑返回頻道列表、訊息左滑彈性回覆、官方分組長按選單（含複製訊息連結）、「+」附件與工具面板、提及金色高亮、跨日時間分隔線、身分組名稱染色、論壇頻道貼文瀏覽，以及快速回到最新訊息懸浮鈕。
  - **右側詳情與成員欄**：點擊頻道標題或從右側邊緣左滑拉出，依置頂身分組 (`hoist`) 分組並染色顯示成員名單，整合釘選訊息、討論串、邀請連結、頻道設定與權限檢視。
- **原版個人資料彈出面板**：
  - 在伺服器頻道、私人訊息、回覆列、`@提及`、成員名單或語音房間內點擊任何成員或機器人的頭像與名稱，皆會彈出原版個人資料面板（即時載入並快取個人橫幅、主題色、官方徽章、Discord 註冊日期、伺服器加入時間與染色身分組標籤，並可由面板內點擊「傳送訊息」進入私訊）。
- **語音頻道大廳、Voice Gateway v8 與音效板 (Soundboard)**：
  - 點擊語音或舞台頻道會開啟原版語音預覽面板（顯示在線語音成員、預先靜音切換與「加入語音」按鈕），透過獨立對話按鈕可開啟語音文字聊天室 (Text-in-Voice)。
  - 採用最新 Discord Voice Gateway v8 (`seq_ack` 心跳協定) 與 Gateway Opcode 4 同步連線狀態，進入語音頻道後立即轉為綠色「語音已連線」與即時延遲 (ms)，並內建官方 **音效板 (Soundboard)** 面板，支援搜尋與播放當前伺服器自訂音效、其他伺服器音效與 Discord 預設音效。
- **官方三鍵頻道精準排序**：嚴格實作 Discord 官方排序規則（先依文字 / 語音類型分桶 `sortBucket`，再比對 `position`，同順位以 Snowflake ID 升冪決勝），並妥善處理孤立分類頻道與私訊最新訊息排序。
- **精準未讀狀態追蹤**：持久化記錄各頻道 `lastReadMessageId`，僅在收到未讀新訊息時於頻道與伺服器左側顯示白色未讀點，讀取後即時消除。
- **真實帳號與伺服器屬性渲染**：自動依據機器人真實 `public_flags` 與 `application.flags` 渲染官方徽章與 `APP` / 已驗證標記，並依據伺服器真實 `features` 判斷是否為社群或驗證伺服器，不混入任何假裝飾。

### Vencord 插件與主題完整相容 (`設定 -> Vencord`)
- **內建 19 款官方 Vencord 插件與 `VencordDBCPlugin` (`BotClient`)**：
  - **`BotClient` (核心必備) 與全伺服器表情支援**：完整移植 `VencordDBCPlugin` 所有設定與功能，包含全伺服器自訂表情選擇器（整合 `GET /guilds/{id}/emojis` 跨服同步、伺服器分組跳轉列、關鍵字搜尋，於伺服器頻道與私人訊息皆可使用所有伺服器表情）、聊天輸入框 `:表情名稱` 即時自動補全與自動轉換、機器人專屬 **Application Emojis** (`/applications/{id}/emojis` 5 分鐘快取)、**Advanced Message Editor**（支援 Discord Components V2 `IS_COMPONENTS_V2 = 32768` 與 Discohook / Raw JSON 結構發送及編輯），以及 `/ping`、`/purge <2-100>`、`/switch shard <id>`、`/switch guild <id>`、`/override bitrate <6-5000>` 指令。
  - **`FakeNitro`**：當目標頻道關閉 `Use External Emojis` 權限或表情所屬伺服器失去加成時，自動改以高畫質 CDN 超連結發送表情，並於聊天室內自動還原渲染為行內或放大表情圖示。
  - **`MessageLogger`**：即時記錄頻道內遭刪除的訊息（支援紅字或紅色背景覆蓋樣式）與編輯前後的完整歷史紀錄。
  - **`ShowHiddenChannels`**：於頻道列表顯示機器人無檢視權限的隱藏頻道，點擊可檢視頻道主題、建立日期與允許檢視的身分組清單。
  - **`NoReplyMention` & `SilentMessageToggle` & `SilentTyping`**：支援回覆訊息時預設關閉 `@提及`（附帶使用者 ID 例外清單與回覆列即時切換膠囊）、聊天輸入列 `@silent` 無聲訊息開關，以及隱藏輸入中狀態。
  - **`ViewRaw` & `ViewIcons` & `PermissionsViewer` & `WhoReacted`**：支援檢視訊息、使用者、頻道與伺服器的原始 JSON 資料；點擊頭像、個人橫幅與伺服器圖示檢視高畫質原圖；檢視成員與頻道完整權限位元表；長按任何表情反應膠囊檢視所有按讚成員名單。
  - **`Translate` & `SendTimestamps` & `TextReplace` & `AnonymiseFileNames`**：支援訊息行內即時翻譯與發送前自動翻譯、動態時間戳記選擇器與反引號時間轉換、發送前關鍵字 / Regex 自動取代規則，以及上傳附件檔名自動匿名化。
  - **`RoleColorEverywhere` & `RevealAllSpoilers` & `AlwaysAnimate` & `MessageLatency`**：於聊天 `@提及`、語音連線成員與身分組標題套用身分組色彩，支援自動展開劇透內容、強制播放動態表情與訊息延遲標記。
- **安裝自訂 Vencord Userplugin**：
  - 支援貼上 GitHub Vencord 插件網址（`.ts` / `.tsx` / `.js` 或插件資料夾連結）或直接貼上 `definePlugin({...})` 程式碼與 JSON 描述檔，自動解析插件選項、自訂斜線指令、發送前文字處理規則與內嵌 CSS 變數。
- **Vencord Online Themes、QuickCSS 與跨端備份同步**：
  - 支援輸入線上 `.theme.css` 網址 (`themeLinks`) 與自訂 `QuickCSS` (`:root` 變數如 `--background-primary`、`--background-secondary`、`--brand-experiment` 等) 即時重繪全局配色。
  - 100% 相容電腦版 Vencord / DiscordBotClient 的 `vencord-settings-backup.json` 設定備份格式，可一鍵匯出與匯入所有插件開關、參數與主題設定。

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
