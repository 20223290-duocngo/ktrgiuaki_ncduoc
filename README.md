# Ung dung nhac viec Flutter toi gian

Day la ban code toi gian de lam dung de bai:
- Them cong viec
- Luu cong viec vao danh sach
- Xem danh sach cong viec
- Bat/tat nhac viec
- Chon 1 trong 3 hinh thuc nhac viec: chuong, email, thong bao

## Cac file can dung
- `lib/main.dart`
- `pubspec.yaml`

## Cach chay cho chac an trong Android Studio
1. Mo Android Studio.
2. Tao **New Flutter Project** moi, vi du ten `nhac_viec_app`.
3. Sau khi project duoc tao xong, dong app neu dang chay.
4. Chep de **ghi de** 2 file trong goi nay vao project vua tao:
   - `lib/main.dart`
   - `pubspec.yaml`
5. Mo terminal ngay trong Android Studio va chay:
   - `flutter pub get`
6. Bat emulator hoac cam dien thoai that.
7. Bam **Run** trong Android Studio.

## Cach test nhanh phan nhac viec
- Tao 1 cong viec cach thoi diem hien tai 1-2 phut.
- Bat nhac viec.
- Chon hinh thuc nhac viec.
- Giu app mo de thay nhac viec hien trong ung dung.

## Ghi chu quan trong
- De project de chay va de nop, phan "nhac qua email" duoc the hien ngay trong app theo dung lua chon da nhap, khong gui email that.
- Du lieu cong viec duoc luu local bang `shared_preferences`.
- Giao dien duoc can giua tren man hinh rong nen van dung duoc tren dien thoai va may tinh bang.
