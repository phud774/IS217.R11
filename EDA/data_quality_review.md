# Các cặp dữ liệu cần kiểm tra

| Cặp quan hệ | Số lượng cần kiểm tra | Ghi chú |
|---|---:|---|
| `store_no -> store_name` | 13 mã / 29.047 dòng | Kiểm tra khác format, đổi tên cửa hàng hoặc mã bị tái sử dụng. Có thể xử lý bằng SCD Type 2. |
| `store_no -> store_address` | 6 mã / 5.319 dòng | Chuẩn hóa địa chỉ trước; nếu đổi địa chỉ thật thì dùng SCD Type 2, không ghi đè lịch sử. |
| `item_no -> im_desc` | 125 mã / 16.332 dòng | Kiểm tra một mã có bị dùng cho nhiều sản phẩm hoặc chỉ khác cách ghi tên. |
| `item_no -> pack` | 22 mã / 5.350 dòng | Kiểm tra thay đổi quy cách đóng gói hoặc lỗi mã sản phẩm. |
| `item_no -> bottle_volume_ml` | 6 mã / 994 dòng | Ưu tiên cao; cùng mã nhưng khác dung tích thường là bất thường. |
| `item_no -> category_code` | 151 mã / 42.208 dòng | Kiểm tra sản phẩm được phân loại lại hay mapping sai. |
| `item_no -> category_name` | 132 mã / 41.923 dòng | Đối chiếu với `category_code` và tên danh mục chuẩn. |
| `item_no -> vendor_number` | 50 mã / 13.361 dòng | Kiểm tra vendor thay đổi theo thời gian hay dữ liệu bị gán sai. |
| `category_name -> category_code` | 4 trường hợp / 184.738 dòng | Xác minh một tên danh mục có hợp lệ khi dùng cho nhiều mã hay không. |
| Thiếu vị trí cửa hàng | 422 dòng | Kiểm tra các cột `store_address`, `store_city`, `store_zip_code`, `county_fips_code`, `county_name`; giữ giao dịch và dùng `NULL`/`Unknown location` nếu chưa bổ sung được. |
