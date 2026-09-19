# Báo cáo khám phá dữ liệu

- Nguồn: 5 file CSV; 2,590,975 dòng; 23 cột.
- Khoảng ngày: 2024-01-01 đến 2024-12-31.
- Bảng tần suất: tối đa 100 giá trị phổ biến nhất mỗi cột
- `column_profile.csv`: kiểu, số null, chuỗi trống, NaN, tỷ lệ thiếu, số giá trị phân biệt.
- `numeric_summary.csv`: min, max, trung bình, độ lệch chuẩn, số 0 và số âm.
- `values/<tên cột>.csv`: giá trị, số lần xuất hiện và tỷ lệ trên toàn bộ dòng.
- `key_relationships.csv`: mỗi chiều mã ↔ thuộc tính, số mã có nhiều giá trị và số dòng liên quan.
- `key_relationship_conflicts.csv`: từng cặp giá trị xung đột, số dòng và khoảng ngày xuất hiện.

## Tổng quan từng cột

| Cột | Kiểu | Thiếu | Tỷ lệ thiếu | Khác nhau | 3 giá trị phổ biến |
|---|---|---:|---:|---:|---|
| `invoice_id` | String | 0 | 0.0000% | 2,590,975 | INV-65991300082 (1); INV-66008100010 (1); INV-65960800064 (1) |
| `ordered_on` | String | 0 | 0.0000% | 316 | 2024-12-26 (15,616); 2024-11-29 (13,781); 2024-06-18 (13,627) |
| `store_no` | String | 0 | 0.0000% | 2,162 | 4829 (20,650); 2633 (19,577); 3773 (16,152) |
| `store_name` | String | 0 | 0.0000% | 2,151 | CENTRAL CITY 2 (20,650); HY-VEE #3 / BDI / DES MOINES (19,577); BENZ DISTRIBUTING (16,152) |
| `store_address` | String | 422 | 0.0163% | 2,155 | 3221 SE 14TH ST (25,587); 1501 MICHIGAN AVE (20,650); 501 7TH AVE SE (16,152) |
| `store_city` | String | 422 | 0.0163% | 471 | DES MOINES (209,066); CEDAR RAPIDS (170,724); DAVENPORT (104,063) |
| `store_zip_code` | String | 422 | 0.0163% | 506 | 52404 (55,671); 50613 (54,718); 50010 (53,942) |
| `county_fips_code` | String | 422 | 0.0163% | 99 | 19153 (504,546); 19113 (217,594); 19163 (150,173) |
| `county_name` | String | 422 | 0.0163% | 99 | POLK (504,546); LINN (217,594); SCOTT (150,173) |
| `category_code` | String | 0 | 0.0000% | 48 | 1031100 (403,838); 1012100 (247,039); 1011200 (206,369) |
| `category_name` | String | 0 | 0.0000% | 44 | AMERICAN VODKAS (403,838); CANADIAN WHISKIES (247,039); STRAIGHT BOURBON WHISKIES (206,369) |
| `vendor_number` | String | 0 | 0.0000% | 239 | 421 (471,374); 260 (391,513); 065 (194,626) |
| `vendor_name` | String | 0 | 0.0000% | 239 | SAZERAC COMPANY  INC (471,374); DIAGEO AMERICAS (391,513); JIM BEAM BRANDS (194,626) |
| `item_no` | String | 0 | 0.0000% | 5,211 | 65013 (27,752); 11788 (27,748); 64870 (25,615) |
| `im_desc` | String | 0 | 0.0000% | 4,515 | TITOS HANDMADE VODKA (81,144); FIREBALL CINNAMON WHISKEY (63,084); BLACK VELVET (62,704) |
| `pack` | Float64 | 0 | 0.0000% | 19 | 12.0 (1,258,353); 6.0 (821,190); 24.0 (224,276) |
| `bottle_volume_ml` | Float64 | 0 | 0.0000% | 20 | 750.0 (1,131,239); 1750.0 (456,263); 50.0 (337,745) |
| `state_bottle_cost` | Float64 | 2,590,975 | 100.0000% | 0 | — |
| `state_bottle_retail` | Float64 | 2,590,975 | 100.0000% | 0 | — |
| `sales_bottles` | Float64 | 0 | 0.0000% | 337 | 12.0 (677,487); 6.0 (564,513); 1.0 (340,566) |
| `sales_dollars` | Float64 | 0 | 0.0000% | 10,663 | 72.0 (63,663); 77.4 (53,717); 144.0 (46,915) |
| `sales_liters` | Float64 | 0 | 0.0000% | 659 | 9.0 (514,768); 10.5 (318,442); 4.5 (249,343) |
| `sales_gallons` | Float64 | 0 | 0.0000% | 650 | 2.37 (514,768); 2.77 (318,442); 1.18 (249,343) |

## Kiểm tra mã và thuộc tính

Giá trị null và chuỗi trống không được tính là một tên/địa chỉ khác; số dòng thiếu vẫn được ghi trong `key_relationships.csv`.

| Mã | Thuộc tính | Mã có nhiều giá trị | Dòng liên quan | Thuộc tính dùng cho nhiều mã | Dòng thiếu thuộc tính |
|---|---|---:|---:|---:|---:|
| `store_no` | `store_name` | 13 | 29,047 | 21 | 0 |
| `store_no` | `store_address` | 6 | 5,319 | 13 | 422 |
| `store_no` | `store_city` | 0 | 0 | 277 | 422 |
| `store_no` | `store_zip_code` | 0 | 0 | 313 | 422 |
| `store_no` | `county_fips_code` | 0 | 0 | 99 | 422 |
| `store_no` | `county_name` | 0 | 0 | 99 | 422 |
| `item_no` | `im_desc` | 125 | 16,332 | 519 | 0 |
| `item_no` | `pack` | 22 | 5,350 | 15 | 0 |
| `item_no` | `bottle_volume_ml` | 6 | 994 | 14 | 0 |
| `item_no` | `category_code` | 151 | 42,208 | 47 | 0 |
| `item_no` | `category_name` | 132 | 41,923 | 44 | 0 |
| `item_no` | `vendor_number` | 50 | 13,361 | 198 | 0 |
| `vendor_number` | `vendor_name` | 0 | 0 | 0 | 0 |
| `county_fips_code` | `county_name` | 0 | 0 | 0 | 422 |
| `category_code` | `category_name` | 0 | 0 | 4 | 0 |

- `invoice_id`: duy nhất trên mọi dòng (2,590,975 mã trên 2,590,975 dòng).

## Lưu ý đọc kết quả

- Null, chuỗi trống (kể cả chỉ có khoảng trắng) và NaN được đếm riêng.
- Số giá trị phân biệt được tính chính xác trên toàn bộ dữ liệu; null không được tính.
- Cột có nhiều giá trị chỉ xuất các giá trị phổ biến nhất theo mặc định. Dùng `--all-values` để xuất hết.
- Giá trị âm có thể là giao dịch hoàn trả hoặc điều chỉnh; cần xem nghiệp vụ trước khi loại bỏ.
- Một mã có nhiều thuộc tính có thể do thay đổi theo thời gian; xem ngày trong file xung đột trước khi chuẩn hóa.
- Nhiều mã dùng cùng một tên không tự động là lỗi; cần đối chiếu nghiệp vụ trước khi gộp.
