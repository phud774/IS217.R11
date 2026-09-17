# Kịch bản thuyết trình – Buổi 01

**Chủ đề:** Phân tích hoạt động phân phối rượu mạnh tại bang Iowa  
**Thời lượng dự kiến:** 4–5 phút

## Slide 1 – Giới thiệu

Xin chào thầy/cô và các bạn.

Nhóm em xin trình bày đề tài **Phân tích hoạt động phân phối rượu mạnh tại bang Iowa trong năm 2024**.

Trong buổi đầu tiên, nhóm sẽ giới thiệu hai nội dung: vì sao nhóm lựa chọn chủ đề này và bộ dữ liệu được sử dụng có ý nghĩa, cấu trúc như thế nào.

*[Chuyển sang slide 2]*

## Slide 2 – Bài toán phân phối tại Iowa

Lý do nhóm chọn chủ đề bắt đầu từ một bài toán thực tế trong hệ thống phân phối rượu mạnh tại Iowa.

Bang Iowa là đầu mối bán buôn, chịu trách nhiệm phân phối sản phẩm đến hơn 2.000 nhà bán lẻ Class E trên toàn bang.

Hệ thống này có nhiều cửa hàng, khu vực, sản phẩm và nhà cung cấp. Đồng thời, nhu cầu nhập hàng không cố định mà thay đổi theo thời gian, địa điểm và từng danh mục sản phẩm.

Điều đó đặt ra một câu hỏi quản lý cụ thể: cần nhập bao nhiêu hàng, phân bổ đến đâu và vào thời điểm nào?

Nếu không hiểu đúng nhu cầu, hệ thống có thể phân bổ hàng chưa phù hợp, thiếu sản phẩm tại nơi có nhu cầu cao hoặc tồn kho nhiều sản phẩm có nhu cầu thấp.

Vì vậy, bài toán cốt lõi mà nhóm quan tâm là làm thế nào để phân phối đúng sản phẩm, đến đúng nơi và vào đúng thời điểm.

*[Chuyển sang slide 3]*

## Slide 3 – Vì sao nhóm chọn chủ đề này?

Từ bài toán trên, nhóm lựa chọn chủ đề để trả lời bốn câu hỏi chính.

Thứ nhất, nhu cầu nhập hàng tăng hoặc giảm vào thời điểm nào?

Thứ hai, khu vực và cửa hàng nào có nhu cầu cao?

Thứ ba, sản phẩm và danh mục nào được đặt mua nhiều?

Cuối cùng, nhà cung cấp nào đóng góp lớn vào hệ thống phân phối?

Kết quả phân tích có thể hỗ trợ theo dõi xu hướng, lập kế hoạch hàng hóa và tồn kho, phân bổ sản phẩm theo khu vực, đồng thời đánh giá sản phẩm và nhà cung cấp.

Đây là lý do cụ thể nhóm chọn chủ đề: biến dữ liệu đơn hàng thành thông tin hỗ trợ quản lý hoạt động phân phối rượu mạnh trên phạm vi toàn bang.

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

*[Mở slide sơ đồ sao riêng nếu cần trình bày tiếp]*

## Slide riêng – Thiết kế Data Warehouse đề xuất

Từ 23 thuộc tính ban đầu, nhóm đề xuất tổ chức kho dữ liệu theo mô hình sao.

Ở trung tâm là bảng FACT_LIQUOR_SALES. Mỗi hàng đại diện cho một sản phẩm trong một hóa đơn, tại một cửa hàng và một ngày đặt hàng. Các thuộc tính trong bảng ghi nhận hóa đơn, thời gian, cửa hàng, sản phẩm, nhà cung cấp, số chai, giá trị và thể tích.

Bốn bảng chiều trả lời bốn nhóm câu hỏi chính: DIM_DATE cho biết giao dịch diễn ra khi nào; DIM_STORE cho biết cửa hàng và khu vực nào; DIM_PRODUCT mô tả sản phẩm và danh mục; DIM_VENDOR cho biết nhà cung cấp.

Cấu trúc này giúp truy vấn doanh thu và sản lượng linh hoạt theo thời gian, cửa hàng, khu vực, sản phẩm, danh mục hoặc nhà cung cấp, đồng thời tránh lặp lại các thuộc tính mô tả trong bảng fact.

Phần trình bày của nhóm em đến đây là kết thúc. Cảm ơn thầy/cô và các bạn đã lắng nghe.

## Nguồn tham khảo

- Iowa Data Hub – Iowa Liquor Sales, 2024: <https://data.iowa.gov/catalog/dataset/1261>
- Iowa Department of Revenue – License Classifications: <https://revenue.iowa.gov/permits-licensing/alcohol/license-classifications>
- Iowa Department of Revenue – FY25 Annual Report: <https://revenue.iowa.gov/media/4325/download?inline=>
