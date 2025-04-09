# Customer Manager

Bu repo, çoklu müşteri yönetimi için aşağıdaki işlemleri otomatikleştiren scriptler içerir:
customer-manager/
├── README.md
├── add_customer.sh         # Yeni müşteri ekle: WP, DB container'larını oluşturur ve Nginx konfigürasyonunu yazar
├── archive_customer.sh     # Soft delete: Müşterinin container'larını durdurur, konfigürasyon dosyalarını arşivler
├── delete_customer.sh      # Hard delete: Müşteriyi sistemden kalıcı olarak siler (container, volume, konfigürasyon)
├── backup_customers.sh     # Tüm müşterilerin WP & DB volume'larını yedekler
├── restore_backup.sh       # Belirli bir müşterinin yedeğini geri yükler (volume içerisine restore)
├── download_drive.sh       # Bulut (örneğin, Google Drive) üzerindeki yedek dosyalarını indirir
├── upload_drive.sh         # Yerel yedekleri bulut ortamına yükler (rclone ile)
├── nginx_conf/             # Reverse proxy Nginx konfigürasyon dosyaları burada yer alır
├── archived_customers/     # Soft delete edilen müşterilerin docker-compose ve Nginx conf dosyaları burada saklanır
└── backups/                # Yedek dosyalarının (tar.gz) konulacağı ana dizin

## Kurulum
- Bu repo içindeki scriptleri çalıştırmadan önce Docker, Docker Compose ve (isteğe bağlı) rclone kurulu olmalıdır.
- `nginx_conf`, `archived_customers` ve `backups` dizinlerini repo kökünde saklayın.

## Kullanım
Her bir script interaktif olarak müşteri bilgilerini alır; dokümantasyon için script içeriğine bakılabilir.
