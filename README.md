# DiscordBotClient Mobile (Android APK & iOS IPA)

參考 [aiko-chan-ai/DiscordBotClient](https://github.com/aiko-chan-ai/DiscordBotClient) 與 [aiko-chan-ai/VencordDBCPlugin](https://github.com/aiko-chan-ai/VencordDBCPlugin) 原始碼打造的原生級手機版 Discord 機器人客戶端。完整對齊原版 `DiscordBotClient` 的機器人登入機制與最新 Discord 手機版三欄跟手滑動介面，底層採用 Flutter AOT 原生 ARM64 機器碼直連 Discord API v10、Zlib 串流壓縮 Gateway 與 Voice Gateway v4，兼具最低耗能與 120Hz 流暢度。

---

## 核心機制與互動設計

### 原版 Discord 手機版互動體驗
- **三欄 120fps 跟手滑動架構**：
  - **左側導覽欄**：伺服器圓角矩形圖示列、頂部私人訊息入口、圓角頻道面板與底部乾淨懸浮 You Bar（橫滑 You Bar 可快速在伺服器與私訊間切換）。
  - **中間聊天欄**：支援右滑返回頻道列表、訊息左滑彈性回覆、跨日時間分隔線、身分組名稱染色、論壇頻道貼文瀏覽，以及快速回到最新訊息懸浮鈕。
  - **右側詳情與成員欄**：點擊頻道標題或從右側邊緣左滑拉出，依置頂身分組 (`hoist`) 分組並染色顯示成員名單，整合釘選訊息、討論串、邀請連結與頻道設定。
- **語音頻道大廳與即時語音連線**：
  - 點擊語音或舞台頻道會開啟原版語音預覽面板（顯示在線語音成員、預先靜音切換與「加入語音」按鈕），不再誤跳文字聊天室；透過面板內獨立的對話按鈕可隨時開啟語音文字聊天室 (Text-in-Voice)。
  - 支援透過 Gateway Opcode 4 與 Voice Gateway v4 + UDP IP Discovery 加入語音頻道、跨伺服器自動切換語音、靜音 / 拒聽 / 掛斷控制、即時顯示語音延遲 (ms) 與成員說話綠框 (Opcode 5)，並於頻道列表下方縮排顯示連線中成員與頂部綠色語音狀態列。
- **官方三鍵頻道精準排序**：嚴格實作 Discord 官方排序規則（先依文字 / 語音類型分桶 `sortBucket`，再比對 `position`，同順位以 Snowflake ID 升冪決勝），並妥善處理孤立分類頻道與私訊最新訊息排序。
- **精準未讀狀態追蹤**：持久化記錄各頻道 `lastReadMessageId`，僅在收到未讀新訊息時於頻道與伺服器左側顯示白色未讀點，讀取後即時消除。
- **真實帳號與伺服器屬性渲染**：自動依據機器人真實 `public_flags` 與 `application.flags` 渲染官方徽章與 `APP` / 已驗證標記，並依據伺服器真實 `features` 判斷是否為社群或驗證伺服器，不混入任何假裝飾。

### 對齊 DiscordBotClient 原始碼功能
- **原版登入介面**：還原 `AuthBoxTokenLogin` 的 `Welcome back!` / `BOT TOKEN` 登入卡片，以及 `Choose an account` / `< Go back` 多帳號切換。
- **自動偵測特權 Intents 與分片 (Sharding)**：登入時透過 `/applications/@me` 自動讀取機器人已啟用的特權 Intents 旗標並計算建議分片數。
- **新增與編輯 Embed**：輸入框內嵌原版 SVG Embed 按鈕開啟 `Create Embed`，長按機器人自己發送的 Embed 訊息亦可直接開啟 `Edit Embed` 修改。
- **內建斜線指令**：支援原版 `/ping`、`/purge <2-100>`（批次刪除 14 天內訊息）、`/switch shard <id>` 與 `/switch guild <id>`。
- **完整狀態控制**：支援切換線上、閒置、請勿打擾、隱形，以及透過 Gateway `type: 4` 設定自訂狀態文字或活動狀態。

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
