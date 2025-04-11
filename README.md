🚀 Customer Manager – Çoklu WordPress Müşteri Yönetim Sistemi
Bu repo, birden fazla müşteriye ait WordPress + MySQL kurulumlarını izole, otomatik ve güvenli şekilde yönetmek için geliştirilmiş bash script tabanlı bir yönetim aracıdır.

🔧 Yapı tamamen Docker ve Docker Compose üzerine kurulmuştur. SSL desteği olarak Let's Encrypt (otomatik) ve manuel sertifika desteği mevcuttur. Yedekleme, geri yükleme ve arşivleme gibi işlemler tam otomatikleştirilmiştir.

📂 Script Listesi ve Görevleri
Script Adı	Açıklama
add_customer.sh	Yeni müşteri ekler. WordPress + DB container'ı başlatır, otomatik SSL ya da manuel sertifika seçeneği sunar.
archive_customer.sh	Müşteri hizmet dışı bırakılır. Container durdurulur, konfigürasyon ve compose dosyaları arşive taşınır.
delete_customer.sh	Müşteriyi sistemden kalıcı olarak siler. İlgili volume'lar da istenirse kaldırılır.
backup_customers.sh	Tüm müşterilerin WordPress ve DB volume’larını .tar.gz formatında yedekler.
restore_backup.sh	Belirli bir müşterinin yedeğini geri yükler. Volume’lar üzerine açar.
upload_drive.sh	rclone aracılığıyla tüm yedekleri bulut ortamına (Google Drive, Dropbox vs.) yükler.
download_drive.sh	Bulut yedeklerini tekrar yerel sunucuya indirir.

🔌 Gereksinimler
Docker ve Docker Compose (v2 önerilir)

rclone (opsiyonel – Google Drive entegrasyonu için)

Ubuntu 22.04 veya türevi bir Linux dağıtımı

Dış dünyaya açık, DNS çözümlemesi yapılmış bir domain (Let's Encrypt için gereklidir)

📁 Klasör Yapısı

kohesoft/
│
├── nginx/
│   ├── certs/                 # SSL dosyaları (otomatik veya manuel yerleştirilenler)
│   ├── conf.d/                # Nginx yapılandırmaları (otomatik oluşturuluyor)
│   ├── html/                  # Default site dosyaları (zorunlu değil)
│   └── vhost.d/               # Site bazlı özel yapılandırmalar (varsa)
│
├── backups/                  # Yedeklerin tutulduğu klasör
├── archived_customers/      # Soft-delete işlemi sonrası dosyaların saklandığı yer
├── docker-compose-*.yml     # Her müşteriye özel compose dosyaları
├── *.sh                      # Tüm script dosyaları burada


🛠️ Kurulum
bash
Kopyala
Düzenle
# Docker ve Docker Compose kurulumu
sudo apt update && sudo apt install -y docker.io
sudo apt install docker-compose-plugin

# Bu repoyu klonla
git clone https://github.com/beratksz/kohesoft.git
cd kohesoft

# Gerekli ağ kontrolü
bash add_customer.sh  # otomatik oluşturur (ilk kullanımda)

📌 Notlar
Let's Encrypt kullanılacaksa 80 ve 443 portlarının kullanılabilir ve açık olması gerekir.

Manuel SSL kurulumu için 3 dosya gereklidir: .crt, .key, ca-bundle.crt.

Her işlem sonrası log veya bilgilendirme terminale yazdırılır. restore_backup.sh içinde ayrıca log dosyası da üretilmektedir.

🧠 Geliştirici Notu
Bu sistem bir SaaS altyapısı olarak yapılandırılabilir. İleride müşteri alanlarını subdomain bazlı ayırmak, monitoring/log sistemi entegre etmek veya admin paneli geliştirmek mümkündür. Kodlar temiz, modüler ve shell script ile devops sürecine uygundur.
