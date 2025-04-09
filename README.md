# Customer Manager

Bu repo, çoklu müşteri yönetimi için aşağıdaki işlemleri otomatikleştiren scriptler içerir:
- **add_customer.sh**: Yeni müşteri ekler (WordPress, DB container'ları ve Nginx konfigürasyonu oluşturur).
- **archive_customer.sh**: Müşteriyi soft-delete yöntemiyle arşivler (container'lar durdurulur, konfigürasyonlar arşivlenir).
- **delete_customer.sh**: Müşteriyi sistemden kalıcı siler (container, volume ve konfigürasyonlar kaldırılır).
- **backup_customers.sh**: Tüm müşterilerin WordPress ve DB volume yedeklerini alır.
- **restore_backup.sh**: Belirli bir müşterinin volume yedeklerini geri yükler.
- **upload_drive.sh**: Yerel yedekleri rclone ile bulut ortamına yükler.
- **download_drive.sh**: Bulut ortamındaki yedekleri yerel sisteme indirir.

## Kullanım
- Docker, Docker Compose ve (isteğe bağlı) rclone kurulu olmalıdır.
- Repo yapısındaki `nginx_conf`, `archived_customers` ve `backups` dizinlerinin düzenli saklanması gereklidir.
- Her script interaktif olarak müşteri bilgilerini alır. Script içeriğine bakarak daha fazla detay öğrenebilirsiniz.

## Repository Yapısı
