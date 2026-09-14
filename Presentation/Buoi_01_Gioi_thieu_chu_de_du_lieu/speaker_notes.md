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

## Slide 5 – Một hàng dữ liệu có dạng như thế nào?

Để hiểu rõ hơn về dữ liệu, nhóm lấy một hàng thực tế làm ví dụ.

Ngày 1 tháng 1 năm 2024, cửa hàng Keokuk Spirits tại thành phố Keokuk, thuộc Lee County, đặt mua sản phẩm Lunazul Reposado. Đây là sản phẩm thuộc danh mục 100% Agave Tequila và do Heaven Hill Brands cung cấp.

Cửa hàng đặt 12 chai, mỗi chai có dung tích 1.750 mililít. Tổng thể tích là 21 lít và tổng giá trị của dòng đặt hàng là 432 đô la.

Như vậy, mỗi hàng trong dữ liệu đại diện cho một sản phẩm cụ thể nằm trong đơn đặt hàng của một cửa hàng tại một ngày xác định. Nếu một đơn hàng có nhiều sản phẩm thì đơn hàng đó sẽ có nhiều hàng dữ liệu.

Cần lưu ý đây là dữ liệu phân phối đến nhà bán lẻ, không phải hóa đơn bán trực tiếp cho người tiêu dùng cuối.

Tóm lại, bộ dữ liệu cho biết cửa hàng nào đã đặt sản phẩm gì, tại đâu, vào thời điểm nào, với số lượng và tổng giá trị bao nhiêu. Đây sẽ là dữ liệu đầu vào để nhóm tiếp tục thực hiện các phần sau của đồ án.

Phần trình bày của nhóm em đến đây là kết thúc. Cảm ơn thầy/cô và các bạn đã lắng nghe.

## Nguồn tham khảo

- Iowa Data Hub – Iowa Liquor Sales, 2024: <https://data.iowa.gov/catalog/dataset/1261>
- Iowa Department of Revenue – License Classifications: <https://revenue.iowa.gov/permits-licensing/alcohol/license-classifications>
- Iowa Department of Revenue – FY25 Annual Report: <https://revenue.iowa.gov/media/4325/download?inline=>
