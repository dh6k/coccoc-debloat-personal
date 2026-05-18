# coccoc-debloat-personal

Bộ script cá nhân để cài lại Cốc Cốc theo hướng gọn hơn, gần Chromium hơn, ít tiến trình nền hơn và dễ tùy chỉnh bằng policy registry.

Repo này tập trung vào luồng Windows chạy bằng quyền Administrator. Script có thao tác với `C:\Program Files`, `HKLM\SOFTWARE\Policies`, scheduled task và shortcut hệ thống.

## Chạy nhanh

Mở PowerShell bằng quyền Administrator, rồi chạy:

```powershell
irm https://coccoc.33166099.xyz | iex
```

Luồng này tương ứng với `install-coccoc-online.ps1`.

Nó tải script/phần cấu hình phụ từ fork này:

```text
https://raw.githubusercontent.com/dh6k/coccoc-debloat-personal/refs/heads/main
```

## Chạy từ mã nguồn local

Dùng cách này khi đã clone hoặc tải toàn bộ repo về máy:

```powershell
cd C:\path\to\coccoc-debloat-personal
Set-ExecutionPolicy Bypass -Scope Process -Force
.\install-coccoc.ps1
```

`install-coccoc.ps1` cần các file sau nằm cùng thư mục:

```text
coccoc-restore.reg
coccoc-debloat.reg
mv2.ps1
```

Nếu chạy file local mà chưa có quyền Administrator, script sẽ tự mở lại chính file đó bằng quyền Administrator.

## Các file chính

| File | Vai trò |
| --- | --- |
| `install-coccoc-online.ps1` | Bản online cho lệnh `irm https://coccoc.33166099.xyz \| iex`; tải `mv2.ps1` và `coccoc-debloat.reg` từ GitHub raw. |
| `install-coccoc.ps1` | Bản local/offline theo repo; dùng `mv2.ps1`, `coccoc-restore.reg`, `coccoc-debloat.reg` trong cùng thư mục. |
| `install-coccoc-x86.ps1` | Bản x86 cũ; dùng installer x86 và route `coccoc-x86`. Mở PowerShell bằng Administrator trước khi chạy local để tránh tự chuyển sang endpoint cũ. |
| `mv2.ps1` | Patch `browser.dll` trong thư mục phiên bản Chromium để bật lại các flag liên quan Manifest V2. |
| `coccoc-debloat.reg` | Policy registry chính cho Cốc Cốc. |
| `coccoc-restore.reg` | Xóa nhánh policy Cốc Cốc để khôi phục phần registry policy. |
| `profile.ps1` | Tạo shortcut profile riêng, có thể chọn thư mục chứa dữ liệu profile. |
| `coccoc.bat` | Batch wrapper gọi lệnh online chính. |
| `profile.bat` | Batch wrapper cho script profile online cũ. |

## Quy trình của installer chính

`install-coccoc.ps1` và `install-coccoc-online.ps1` thực hiện các bước chính:

1. Dừng các tiến trình `browser`, `CocCocUpdate`, `CocCocCrashHandler*`.
2. Xóa thư mục cài đặt Cốc Cốc cũ trong `Program Files` và `Program Files (x86)`.
3. Tải installer Cốc Cốc x64 từ:

```text
https://files.coccoc.com/browser/x64/coccoc_standalone_en.exe
https://files2.coccoc.com/browser/x64/coccoc_en_machine.exe
```

4. Cài đặt im lặng bằng tham số `/silent /install`.
5. Tìm `browser.exe`, rồi tìm thư mục phiên bản dạng:

```text
C:\Program Files\CocCoc\Browser\Application\a.b.x.y
```

6. Copy hoặc tải `mv2.ps1` vào thư mục phiên bản đó.
7. Chạy `mv2.ps1` với tham số `-dll "<version-dir>\browser.dll" -NoPause`.
8. Vô hiệu hóa updater và crash handler bằng cách đổi tên file `.exe` sang `.disabled`, sau đó tạo file placeholder read-only/hidden/system.
9. Xóa scheduled task có tên `CocCoc*`.
10. Áp policy registry.
11. Tạo shortcut `Cốc Cốc.lnk` với tham số:

```text
--no-first-run --no-default-browser-check --profile-directory=Default
```

12. Dọn file thừa trong thư mục version `a.b.x.y`:

```text
Installer\browser.7z
Installer\chrmstp.exe
Installer\setup.exe
browser.dll.BAK
Extensions\cashback.crx
Extensions\en2vi.crx
Extensions\cache.crx
Extensions\afaljjbleihmahhpckngondmgohleljb.json
Extensions\gcopfpdkmpdacdmbjonfjmbnccmnjdoi.json
Extensions\gfgbmghkdjckppeomloefmbphdfmokgd.json
```

## Khác nhau giữa bản online và local

| Hạng mục | `install-coccoc-online.ps1` | `install-coccoc.ps1` |
| --- | --- | --- |
| Registry | Tải `coccoc-debloat.reg` từ GitHub raw. | Import `coccoc-restore.reg`, sau đó import `coccoc-debloat.reg` từ thư mục local. |
| MV2 patch | Tải `mv2.ps1` từ GitHub raw rồi copy vào thư mục version. | Copy `mv2.ps1` local vào thư mục version. |
| Tự nâng quyền | Chạy lại bằng `irm https://coccoc.33166099.xyz \| iex`. | Chạy lại chính file local bằng `-File`. |
| Phù hợp khi | Muốn cài nhanh bằng một lệnh. | Muốn kiểm tra/sửa file trước khi chạy. |

## Policy registry đang áp dụng

Các policy chính nằm trong `coccoc-debloat.reg`, gồm:

- Tắt một số tính năng AI, autofill, password manager, feedback, background mode, remote debugging, shopping list và Privacy Sandbox ads.
- Chặn geolocation, notification và motion sensors theo mặc định.
- Bật chặn third-party cookies.
- Bật Safe Browsing mức Standard.
- Bật Memory Saver và chế độ Balanced memory savings.
- Thiết lập DNS-over-HTTPS với Cloudflare.
- Hiển thị full URL trên thanh địa chỉ.
- Giảm rò rỉ IP WebRTC bằng `disable_non_proxied_udp`.
- Đặt `ExtensionManifestV2Availability=2`.
- Block một số extension ID mặc định.
- Force-install các extension được ghi trong file, gồm Material You New Tab, Canvas Blocker, uBlock Origin và Stylus.

Muốn chỉnh policy, sửa `coccoc-debloat.reg`, sau đó chạy lại installer local hoặc import file `.reg` bằng quyền Administrator.

Khôi phục riêng phần policy registry:

```powershell
reg import .\coccoc-restore.reg
```

Repo hiện tại chưa có script khôi phục updater/crash handler về file gốc. Khi installer đã đổi tên file sang `.disabled`, cần xử lý thủ công nếu muốn bật lại.

## Manifest V2 patch

`mv2.ps1` patch trực tiếp `browser.dll`. Installer chính chỉ gọi patch trên `browser.dll` của Cốc Cốc vừa cài, không quét registry để patch Chrome hoặc trình duyệt khác.

Khi chạy riêng, `mv2.ps1` có thể tạo backup:

```text
browser.dll.BAK
```

Nếu đã patch rồi, script sẽ báo trạng thái `Already patched` cho các flag tương ứng.

Trong luồng installer chính, file backup này được xóa lại ở bước dọn dẹp hậu kì.

## Tạo profile riêng

Chạy local:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\profile.ps1
```

Script sẽ:

- Tìm `browser.exe` trong `Program Files` hoặc `Program Files (x86)`.
- Hỏi tên profile, chỉ nhận chữ cái, số và dấu gạch dưới.
- Cho phép chọn thư mục chứa profile riêng, hoặc dùng thư mục mặc định của Cốc Cốc.
- Tạo shortcut trên Desktop.
- Thêm sẵn `--disable-features=CocCocSplitView,SidePanel`.

Có thể tự thêm profile vào shortcut bằng tham số:

```text
--user-data-dir="C:\Private\coccoc_lamviec"
```

Đường dẫn shortcut đã pin thường nằm trong:

```text
%AppData%\Microsoft\Internet Explorer\Quick Launch\User Pinned\ImplicitAppShortcuts
```

## Bật lại Split View hoặc Side Panel

Mở Properties của shortcut, trong ô `Target`, xóa phần:

```text
--disable-features=CocCocSplitView,SidePanel
```

Có thể chỉnh thủ công qua flags:

```text
coccoc://flags/#coccoc-split-view
coccoc://flags/#coccoc-side-panel
```

## Bản x86

`install-coccoc-x86.ps1` vẫn tồn tại trong repo cho máy cần bản 32-bit.

Điểm khác với luồng chính:

- Dùng URL installer x86 `https://files.coccoc.com/browser/coccoc_standalone_en.exe`.
- Registry tweak đang tải từ repo gốc `bibicadotnet/coccoc-debloat`.
- Shortcut thêm `ExtensionManifestV2Unsupported,ExtensionManifestV2Disabled` vào `--disable-features`.
- Không dùng luồng copy/chạy `mv2.ps1` như bản x64 chính.

Nếu dùng bản x86 local, nên mở PowerShell bằng quyền Administrator rồi chạy:

```powershell
.\install-coccoc-x86.ps1
```

## Ghi chú khi cập nhật

Để cập nhật Cốc Cốc theo cấu hình repo này, chạy lại:

```powershell
irm https://coccoc.33166099.xyz | iex
```

Hoặc chạy local:

```powershell
.\install-coccoc.ps1
```

Script cài đặt chính xóa cài đặt Cốc Cốc cũ trước khi cài lại. Nếu có dữ liệu quan trọng ngoài profile mặc định, hãy kiểm tra đường dẫn lưu dữ liệu trước khi chạy.
