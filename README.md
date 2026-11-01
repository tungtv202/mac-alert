# mac-alert

Popup thông báo viết bằng Swift/AppKit cho macOS. Theme **Beacon** có icon,
tiêu đề, nội dung và dòng chi tiết. Popup nổi trên cửa sổ đang làm việc nhưng
không giành focus bàn phím. Gọi từ Codex hoặc bất kỳ ứng dụng/script nào.

## Cài trên Mac mới

Yêu cầu macOS 13 trở lên và Xcode Command Line Tools có Swift 5.7 trở lên.
Không cần Homebrew hay thư viện bên ngoài. Build dùng kiến trúc máy hiện tại
(Apple Silicon hoặc Intel); nên build lại trên từng máy.

```bash
# Chạy một lần nếu chưa có công cụ build:
xcode-select --install

# Clone repo của bạn, sau đó:
cd mac-alert
./scripts/install.sh
```

Mặc định cài binary tại `~/.codex/bin/mac-alert`. Script không sửa hook,
config hay dữ liệu Codex. Có thể chọn thư mục khác:

```bash
./scripts/install.sh "$HOME/.local/bin"
```

Chỉ build: `./scripts/build.sh`; kết quả tại `.build/mac-alert`.
Cập nhật từ GitHub: `git pull` rồi chạy lại `./scripts/install.sh`.

## Dùng thử

```bash
"$HOME/.codex/bin/mac-alert" \
  --no-event \
  --title "My Supporter" \
  --message "Stocks Summary" \
  --subtitle "FPT, VCB" \
  --symbol chart.bar.fill \
  --duration 10s \
  --position bottom-right
```

Thay `--symbol` bằng `--icon "/path/to/icon.png"` để dùng icon riêng.
Hỗ trợ PNG, JPEG, ICNS và icon của một bundle `.app`, giữ nguyên tỉ lệ ảnh.
Icon hoặc SF Symbol không hợp lệ sẽ báo lỗi.

| Tùy chọn | Ý nghĩa |
| --- | --- |
| `--theme beacon\|classic` | Beacon mặc định; classic là bong bóng cũ |
| `--title`, `--message`, `--subtitle` | Ba dòng nội dung độc lập |
| `--subtitle ""` | Bỏ dòng phụ; nếu không truyền, mặc định là giờ thông báo |
| `--result-layout` | Nội dung chính có thể chiếm hai dòng |
| `--no-event` | Dùng nguyên nội dung đã truyền, bỏ qua stdin |
| `--icon PATH` | Ảnh hoặc `.app` trên máy |
| `--symbol NAME` | SF Symbol, mặc định `bolt.fill` |
| `--color COLOR` | green, red, yellow, purple, blue, orange hoặc `#RRGGBB` |
| `--duration DURATION` | Ví dụ `500ms`, `2s`, `1m`; mặc định 10 giây |
| `--position POSITION` | center, bottom-right, bottom-left, top-right, top-left |
| `--width`, `--height`, `--margin` | Kích thước và khoảng cách tới mép |

Click popup để đóng sớm. Escape không bị chặn vì bàn phím vẫn thuộc ứng dụng
đang làm việc. Beacon thích ứng giao diện sáng/tối; mặc định 364×118.
Giờ mặc định của thông báo thủ công dùng múi giờ Việt Nam.

## Tích hợp Codex

Mẫu tại `examples/codex-hooks.example.json` mô tả Stop hook đang dùng với helper
này. Thêm phần tương ứng vào `~/.codex/hooks.json`; giữ các hook đã có của bạn.
Không chép đè file cấu hình hiện tại. Trên máy mới, bật/duyệt hook theo yêu cầu
của phiên bản Codex đang dùng.

Khi nhận JSON Stop trên stdin, helper dùng:

- Tiêu đề: Codex và tên project từ `cwd`.
- Nội dung chính: dòng có nghĩa đầu tiên của `last_assistant_message`, bỏ Markdown
  và giới hạn 95 ký tự. Không có nội dung có nghĩa thì bỏ qua thông báo.
- Dòng phụ: tên thread từ `session_id`/`thread_id`, ưu tiên tên đã đổi trong app.
  Không tìm thấy tên thì dùng ID rút gọn.

Helper cũng hiểu sự kiện `agent-turn-complete`. Việc tìm tên thread chỉ đọc
SQLite/index trong `CODEX_HOME` (mặc định `~/.codex`), không gọi API hay đọc
transcript. Tên bảng/cột dựa trên cấu trúc Codex hiện tại; nếu cấu trúc thay đổi,
ID rút gọn vẫn là phương án dự phòng. Stop hook trả `{}` nhanh và mở popup bằng
process riêng, để thời gian hiển thị không giữ hook chờ. Nội dung được truyền
như đối số, không được thực thi qua shell.

Nội dung trống, chỉ có khoảng trắng/Markdown, hoặc JSON chỉ chứa giá trị rỗng
(`{}`, `[]`, `null`, chuỗi rỗng và các cấu trúc lồng nhau tương tự) không mở
popup. Quy tắc JSON cũng áp dụng trong code fence. Giá trị `0`, `false` và JSON
có dữ liệu vẫn được giữ. Hook bị bỏ qua vẫn trả `{}` thành công, không tạo
process popup. Khi gọi thủ công hoặc từ My Supporter, nội dung rỗng cũng bị bỏ
qua; tiêu đề và dòng phụ không thay thế nội dung chính.

### Tên và icon theo project

```bash
# Chỉ tạo mẫu khi chưa có cấu hình:
mkdir -p "$HOME/.codex"
if [ ! -e "$HOME/.codex/mac-alert-projects.json" ]; then
  cp examples/mac-alert-projects.example.json "$HOME/.codex/mac-alert-projects.json"
fi
```

Sửa đường dẫn trong file theo vị trí project trên máy mới. Hỗ trợ tiền tố `~`.
Project có đường dẫn khớp dài nhất được chọn cho thư mục con. Project chưa khai
báo dùng tên thư mục và symbol mặc định. Icon trong mapping bị thiếu/hỏng sẽ dùng
symbol; `--icon` truyền trực tiếp luôn được ưu tiên.

File cấu hình cá nhân không cần đưa vào repo; repo chỉ chứa bản `.example.json`.

## Gọi từ My Supporter hoặc ứng dụng khác

```bash
"$HOME/.codex/bin/mac-alert" \
  --no-event --result-layout \
  --title "My Supporter" \
  --message "YouTube Summary" \
  --subtitle "Tên video vừa được xử lý" \
  --icon "$HOME/workplace/my-supporter/static/favicon.png" \
  --duration 10s --position bottom-right
```

My Supporter truyền tên tác vụ làm nội dung chính, tên video/repo/PR/mã cổ phiếu
hoặc chi tiết lỗi làm dòng phụ. Thiếu chi tiết thì truyền `--subtitle ""`.
Trên máy mới, đặt `notifications.mac_alert_path` của My Supporter thành
`~/.codex/bin/mac-alert` nếu cần. Icon nằm trong project My Supporter, không được
đóng gói trong repo này.

## Lưu lên GitHub cá nhân

Tạo một repo GitHub **trống**, rồi chạy trong thư mục này:

```bash
git remote add origin git@github.com:YOUR_USERNAME/mac-alert.git
git push -u origin main
```

Nếu dùng HTTPS, thay URL bằng `https://github.com/YOUR_USERNAME/mac-alert.git`.
Repo bỏ qua binary, build output, `.env` và cấu hình project cá nhân. Chỉ cần
clone mã nguồn, build lại và chỉnh mapping đường dẫn để dùng trên Mac khác.

## Ghi chú phát triển

Chạy `python3 tests/test_mac_alert.py` để build và kiểm tra bộ lọc nội dung cùng
đường gọi hook của binary thật. Các bài kiểm tra không mở popup.

Giữ `NSPanel`, `.nonactivatingPanel`, `canBecomeKey = false`,
`canBecomeMain = false`, `.prohibited`, `hidesOnDeactivate = false`,
`.screenSaver` và `orderFrontRegardless()` để popup vừa nhìn thấy vừa không
giành focus. Không gọi `activate(ignoringOtherApps:)` hoặc `makeKeyAndOrderFront`.
