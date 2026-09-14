# Kịch bản thuyết trình – Buổi 01

**Chủ đề:** Phân tích hoạt động phân phối rượu mạnh tại bang Iowa  
**Thời lượng dự kiến:** 4–5 phút

## Slide 1 – Giới thiệu

Xin chào thầy/cô và các bạn.

Nhóm em xin trình bày đề tài **Phân tích hoạt động phân phối rượu mạnh tại bang Iowa trong năm 2024**.

Trong buổi đầu tiên, nhóm sẽ giới thiệu hai nội dung: vì sao nhóm lựa chọn chủ đề này và bộ dữ liệu được sử dụng có ý nghĩa, cấu trúc như thế nào.

*[Chuyển sang slide 2]*

## Slide 2 – Vì sao chọn chủ đề này?

Điểm đặc biệt của chủ đề nằm ở cơ chế phân phối rượu mạnh tại Iowa.

Bang Iowa quản lý tập trung hoạt động bán buôn rượu mạnh. Cơ quan của bang đóng vai trò nhà bán buôn trung tâm và phân phối sản phẩm đến hơn 2.000 nhà bán lẻ tư nhân. Các nhà bán lẻ này có giấy phép Class E, ví dụ như siêu thị, cửa hàng rượu và cửa hàng tiện lợi.

*[Chỉ vào sơ đồ]*

Chuỗi phân phối bắt đầu từ nhà sản xuất hoặc nhà cung cấp. Sản phẩm đi qua hệ thống phân phối của bang, sau đó đến các nhà bán lẻ Class E và cuối cùng mới đến người tiêu dùng.

Dữ liệu của nhóm nằm ở đoạn từ cơ quan phân phối của bang đến nhà bán lẻ. Vì vậy, đây là dữ liệu bán buôn hoặc phân phối, không phải hóa đơn bán trực tiếp cho người tiêu dùng.

Nhóm chọn chủ đề này vì nó thể hiện một bài toán thực tế ở quy mô toàn bang, đồng thời có ý nghĩa đối với việc quản lý hàng hóa, khu vực phân phối và nhu cầu nhập hàng.

*[Chuyển sang slide 3]*

## Slide 3 – Giá trị phân tích của chủ đề

Nhóm xác định bốn hướng phân tích chính.

Thứ nhất là theo dõi nhu cầu nhập hàng thay đổi theo tháng và quý.

Thứ hai là so sánh hiệu quả phân phối giữa các cửa hàng và khu vực.

Thứ ba là xác định những danh mục, sản phẩm và nhà cung cấp nổi bật.

Cuối cùng, kết quả phân tích có thể hỗ trợ lập kế hoạch hàng hóa, tồn kho và phân bổ sản phẩm theo khu vực.

Mục tiêu chung của đề tài là chuyển dữ liệu đơn hàng thành thông tin có ý nghĩa, phục vụ việc theo dõi và quản lý hoạt động phân phối rượu mạnh tại Iowa.

*[Chuyển sang slide 4]*

## Slide 4 – Tổng quan dữ liệu

Dữ liệu nhóm sử dụng có tên **Iowa Liquor Sales 2024**, được công bố trên cổng dữ liệu chính thức của bang Iowa.

Bộ dữ liệu có **2.590.975 bản ghi**, gồm **23 thuộc tính** và bao phủ đầy đủ 12 tháng của năm 2024. Trong dự án, dữ liệu được chia thành 5 tệp CSV với tổng dung lượng khoảng 552 megabyte.

Mỗi bản ghi mô tả việc một nhà bán lẻ Class E đặt mua một sản phẩm rượu mạnh tại một thời điểm cụ thể.

Dữ liệu do Iowa Department of Revenue công bố và sử dụng giấy phép CC BY. Quy mô hơn 2,5 triệu bản ghi cũng phù hợp để nhóm thực hiện quá trình tích hợp, làm sạch và xây dựng kho dữ liệu.

*[Chuyển sang slide 5]*

## Slide 5 – Một bản ghi có dạng như thế nào?

Hai mươi ba thuộc tính của dữ liệu có thể chia thành năm nhóm.

Nhóm giao dịch gồm mã dòng hóa đơn và ngày đặt hàng.

Nhóm cửa hàng và địa lý gồm tên cửa hàng, địa chỉ, thành phố và quận.

Nhóm sản phẩm gồm tên, danh mục, dung tích và quy cách đóng gói.

Nhóm nhà cung cấp gồm mã và tên nhà cung cấp.

Cuối cùng là nhóm định lượng, gồm số chai, tổng giá trị bằng đô la và thể tích theo lít hoặc gallon.

Đơn vị của một bản ghi là một sản phẩm cụ thể trong đơn đặt hàng của một cửa hàng tại một ngày xác định. Một đơn hàng có thể có nhiều dòng nếu cửa hàng đặt nhiều sản phẩm.

Cần lưu ý rằng `sales_bottles` là số chai cửa hàng đặt mua, còn `sales_dollars` là tổng giá trị của dòng đặt hàng. Đây không phải số lượng và doanh thu bán trực tiếp cho người tiêu dùng cuối.

Tóm lại, chủ đề có nhiều chiều phân tích như thời gian, địa lý, cửa hàng, sản phẩm và nhà cung cấp. Dữ liệu cũng có quy mô và cấu trúc phù hợp để nhóm tiếp tục xây dựng SSIS, kho dữ liệu, SSAS và các báo cáo trực quan.

Phần trình bày của nhóm em đến đây là kết thúc. Cảm ơn thầy/cô và các bạn đã lắng nghe.

## Nguồn tham khảo

- Iowa Data Hub – Iowa Liquor Sales, 2024: <https://data.iowa.gov/catalog/dataset/1261>
- Iowa Department of Revenue – License Classifications: <https://revenue.iowa.gov/permits-licensing/alcohol/license-classifications>
- Iowa Department of Revenue – FY25 Annual Report: <https://revenue.iowa.gov/media/4325/download?inline=>
