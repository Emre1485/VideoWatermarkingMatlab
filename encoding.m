% Step 1: videoyu oku
videoFile = 'video.avi'; % Replace with your video file name
videoObj = VideoReader(videoFile);
numFrames = floor(videoObj.Duration * videoObj.FrameRate); % toplam çerçeve sayısı

% Step 2: ilk kareyi elde et (N x M matrix)
firstFrame = read(videoObj, 1); % ilk frame oku
[M, N, ~] = size(firstFrame); % boyutları al (M: satır, N: sütun)

% Step 3: mavi kanalı elde et
blueChannel = firstFrame(:, :, 3); % Blue channel çıkarma
redChannel = firstFrame(:, :, 1);
greenChannel = firstFrame(:, :, 2);
imshow(blueChannel); % Display the blue channel for verification
title('Blue Channel of the First Frame');

% Step 4: mavi kanalı 4 eş parçaya böl
P_n = N;            % frame'deki sütun sayısı
P_m = floor(M / 4); % her parçadakı satır sayısı (floored eş parçalar için)

% Mavi kanalı dört parçaya böl
blueParts = cell(1, 4); % Parçaları saklamak için hücre dizisi
for i = 1:4
    rowStart = (i-1)*P_m + 1;
    rowEnd = min(i*P_m, M); % Sınırları kontrol et
    blueParts{i} = blueChannel(rowStart:rowEnd, :);
end

% Kalan satırları son parçaya ekle (eğer varsa)
if mod(M, 4) ~= 0
    blueParts{end} = blueChannel((3*P_m+1):M, :);
end

% Step 5: İlk parçayı seç
firstPart = blueParts{1};

% Step 6:  LSN ile Her pixel'in byte matrixini oluştur 
% Çıkar: Least Significant Nibble (LSN)
LSN_matrix = bitand(firstPart, 15); % LSN en düşük 4 bit (bitand with 15)

% Pair neighboring LSNs to form bytes
P_nf = floor(P_n / 2);  % Divide the width by 2 for byte matrix formation
P_mf = size(firstPart, 1); % Height remains the same as P_m

byteMatrix = zeros(P_mf, P_nf, 'uint8'); % byte matrix oluştur
for row = 1:P_mf
    colIndex = 1;
    for col = 1:2:(2*P_nf)
        byteMatrix(row, colIndex) = bitor(bitshift(LSN_matrix(row, col), 4), LSN_matrix(row, col+1));
        colIndex = colIndex + 1;
    end
end

% byte matrixi göster (Çalışıyor mu?)
imshow(byteMatrix, []);
title('Byte Matrix Formed from First Part');

% Step 7: Form edilen byte'lar bilgisayarda tutulacak
% Bu adım, önceki kodda oluşturulan `byteMatrix` kullanılarak tamamlandı.
% FPGA'ya göndermek yerine işlem bilgisayarda devam edecek. Makalede FPGA
% cihaz kullanılıyor ancak ben bilgisayarda halletmeye çalışıyorum

% Step 8: Watermark resmini binary formata çevir ayrıca siyah beyaz
% formatta olmalıymış
watermarkImage = imbinarize(rgb2gray(imread('watermark.png')));

% watermark boyutlarını kontrol et
[wmHeight, wmWidth] = size(watermarkImage);
fprintf('Watermark dimensions: %d x %d\n', wmHeight, wmWidth);
fprintf('Expected watermark dimensions: %d x %d\n', P_m, P_n);

% watermark size is compatible with frame size?
if wmHeight ~= P_m || wmWidth ~= P_n
    % Resize the watermark to match frame dimensions
    watermarkImage = imresize(watermarkImage, [P_m, P_n], 'nearest');
    fprintf('Watermark resized to: %d x %d\n', size(watermarkImage));
end

% watermark eşit parçalara bölünmüş mü kontrol et
WP_m = floor(P_m / 4);  % watermark boyunu 4 ile böl
WP_n = P_n;  % Watermark genişliği aynı kalıyor

% watermark'ı 4 e böl
watermarkParts = cell(1, 4);
for i = 1:4
    rowStart = (i-1)*WP_m + 1;
    rowEnd = min(i*WP_m, P_m);  % yüksekliği aşmamalı dikkat et bi ara geri gel buraya.
    watermarkParts{i} = watermarkImage(rowStart:rowEnd, :);
end

% Step 9: Watermarkı byte matrixine ayır
% WP_m 4 le bölünmeli
if mod(P_m, 4) ~= 0
    error('Watermark height (P_m) must be divisible by 4.');
end

% byte matrix sütun sayısı doğru mu
P_nf = floor(WP_n / 2);  % Sütun sayısını ayarla (byte formasyonu için 2 ile böl Burayı GPT'ye sor tam anlamadım)
P_mf = WP_m;      % satır sayısı aynı kalıyor

% byte matrix doğru formatta mı oluşturuldu GENE GPT'ye sor buraları
byteMatrix = zeros(P_mf, P_nf, 'uint8');

% watermark parçasını sürekli dön ve LSN elde et
LSN_matrix = bitand(watermarkParts{1}, 15);  % LSN elde et (lower 4 bits)

for row = 1:P_mf
    colIndex = 1;
    for col = 1:2:(2*P_nf)
        byteMatrix(row, colIndex) = bitor(bitshift(LSN_matrix(row, col), 4), LSN_matrix(row, col+1));
        colIndex = colIndex + 1;
    end
end

% Display the byte matrix for verification
imshow(byteMatrix, []);
title('Byte Matrix from Watermark Part');


% Adım 10: Watermark'ın ilk parçasını seç
firstWatermarkPart = watermarkParts{1}; % İlk parça seçiliyor

% Adım 11: Çerçeve parçasını bloklara böl
% Burada P_nf ve P_mf önceki adımlarda hesaplanan çerçeve boyutlarıdır
[frameRows, frameCols] = size(byteMatrix); % Çerçeve parçası boyutları (P_mf x P_nf)
[WPm, WPn] = size(firstWatermarkPart);    % İlk watermark parçasının boyutları

% Eğer watermark boyutları çerçeve boyutları ile uyumsuzsa yeniden ölçeklendir
if mod(frameCols, WPn) ~= 0 || mod(frameRows, WPm) ~= 0
    % Watermark'ı çerçeveye uyacak şekilde yeniden ölçeklendir
    firstWatermarkPart = imresize(firstWatermarkPart, [frameRows, frameCols], 'nearest');
    [WPm, WPn] = size(firstWatermarkPart); % Yeni boyutları güncelle
    fprintf('Watermark yeniden boyutlandırıldı: %d x %d\\n', WPm, WPn);
end

% Adım 12: Blok boyutlarını hesapla
Bn = frameCols / WPn; % Her blokta sütun başına düşen piksel sayısı
Bm = frameRows / WPm; % Her blokta satır başına düşen piksel sayısı

% Bloklar düzgün bölünmezse hata at
if mod(frameCols, WPn) ~= 0 || mod(frameRows, WPm) ~= 0
    error('Çerçeve boyutları (P_nf, P_mf), watermark blok boyutlarıyla uyumsuz.');
end


% Adım 13: İlk watermark bitini al
firstWatermarkBit = firstWatermarkPart(1, 1); % İlk watermark biti

% Adım 14: İlk blok seç
blockRowStart = 1;          % İlk blok için başlangıç satırı
blockRowEnd = Bm;           % İlk blok için bitiş satırı
blockColStart = 1;          % İlk blok için başlangıç sütunu
blockColEnd = Bn;           % İlk blok için bitiş sütunu
firstBlock = byteMatrix(blockRowStart:blockRowEnd, blockColStart:blockColEnd);

% Adım 15: İlk bloğun ilk pikselini seç
firstPixel = firstBlock(1, 1); % İlk piksel

% Adım 16: LSN ve MSN paritesini hesapla
% Piksel değerlerini binary'ye çevir
binaryPixel = dec2bin(firstPixel, 8); % 8-bit binary temsil

% MSN (En Anlamlı Nibble) ve LSN (En Az Anlamlı Nibble) ayrımı
MSN = binaryPixel(1:4); % İlk 4 bit (MSN)
LSN = binaryPixel(5:8); % Son 4 bit (LSN)

% Parite hesaplama
parityMSN = mod(sum(MSN == '1'), 2); % MSN paritesi (1'lerin toplamının mod 2'si)
parityLSN = mod(sum(LSN == '1'), 2); % LSN paritesi (1'lerin toplamının mod 2'si)

% Sonuçları yazdır
fprintf('Piksel: %d\n', firstPixel);
fprintf('MSN: %s, Parite: %d\n', MSN, parityMSN);
fprintf('LSN: %s, Parite: %d\n', LSN, parityLSN);


% Adım 17-20: Watermarking algoritması
% Piksel ve blok işlemleri için döngüleri kur
for blockRow = 1:WPm
    for blockCol = 1:WPn
        % Mevcut blok koordinatlarını belirle
        rowStart = (blockRow - 1) * Bm + 1;
        rowEnd = blockRow * Bm;
        colStart = (blockCol - 1) * Bn + 1;
        colEnd = blockCol * Bn;
        
        % Mevcut bloğu seç
        currentBlock = byteMatrix(rowStart:rowEnd, colStart:colEnd);
        
        % Mevcut watermark bitini al
        watermarkBit = firstWatermarkPart(blockRow, blockCol);
        
        % Bloğun her pikseli için işlemleri gerçekleştir
        for pixelRow = 1:size(currentBlock, 1)
            for pixelCol = 1:size(currentBlock, 2)
                % Pikseli al
                pixel = currentBlock(pixelRow, pixelCol);
                
                % Pikseli binary forma çevir
                binaryPixel = dec2bin(pixel, 8);
                
                % MSN (D5) ve LSN (D1) ayrıştır
                MSN = binaryPixel(1:4); % İlk 4 bit (MSN)
                LSN = binaryPixel(5:8); % Son 4 bit (LSN)
                
                % Pariteleri hesapla
                parityMSN = mod(sum(MSN == '1'), 2); % MSN paritesi
                parityLSN = mod(sum(LSN == '1'), 2); % LSN paritesi
                
                % Adım 17: LSN paritesi watermark bitine eşit değilse D1'i değiştir
                if parityLSN ~= watermarkBit
                    LSN(2) = num2str(~(LSN(2) - '0')); % D1 bitini tamamla
                end
                
                % MSN paritesi watermark bitine eşit değilse D5'i değiştir
                if parityMSN ~= watermarkBit
                    MSN(2) = num2str(~(MSN(2) - '0')); % D5 bitini tamamla
                end
                
                % MSN ve LSN'i birleştir ve pikseli güncelle
                binaryPixel(1:4) = MSN;
                binaryPixel(5:8) = LSN;
                currentBlock(pixelRow, pixelCol) = bin2dec(binaryPixel);
            end
        end
        
        % Güncellenmiş bloğu ana matrise geri yaz
        byteMatrix(rowStart:rowEnd, colStart:colEnd) = currentBlock;
    end
end

% Adım 20: Watermark'lı parçayı PC'ye gönder
% Bu örnek için 'watermarkedByteMatrix' olarak adlandıralım
watermarkedByteMatrix = byteMatrix;

% Sonuçları göster
disp('Watermarking işlemi tamamlandı.');
imshow(watermarkedByteMatrix, []); % Görselleştirmek için normalize edilmiş gösterim


% Adım 21-24: Su işaretli piksel yeniden oluşturma ve birleştirme

% Su işaretli byte'ları yeniden bölerek LSN'leri elde et
watermarkedLSNs = mod(watermarkedByteMatrix, 16); % LSN'ler (son 4 bit)
watermarkedMSNs = floor(watermarkedByteMatrix / 16); % MSN'ler (ilk 4 bit)

% Su işaretli pikselleri yeniden oluştur
reconstructedPixels = (watermarkedMSNs * 16) + watermarkedLSNs;

% Su işaretli pikselleri orijinal çerçeveye geri yerleştir
% Burada, önceki işlemlerden alınan `rowStart`, `rowEnd`, `colStart`, `colEnd`
% gibi değişkenler çerçeve parçalarının sınırlarını temsil eder.
for blockRow = 1:WPm
    for blockCol = 1:WPn
        % Mevcut blok koordinatlarını belirle
        rowStart = (blockRow - 1) * Bm + 1;
        rowEnd = blockRow * Bm;
        colStart = (blockCol - 1) * Bn + 1;
        colEnd = blockCol * Bn;
        
        % Yeniden oluşturulan pikselleri bloğa yaz
        reconstructedBlock = reconstructedPixels(rowStart:rowEnd, colStart:colEnd);
        byteMatrix(rowStart:rowEnd, colStart:colEnd) = reconstructedBlock;
    end
end

% Su işaretli çerçeveyi oluştur
watermarkedFrame = byteMatrix;

% Çerçevenin su işaretli versiyonunu göster
disp('Su işareti uygulanmış çerçeve oluşturuldu.');
imshow(watermarkedFrame, []); % Normalleştirilmiş görsel gösterim

% Adım 24: Sonraki parça ve watermark kısmını işlemek için kontroller
for partIndex = 1:4
    % Sonraki watermark kısmını yükle
    if partIndex < 4
        nextWatermarkPart = watermarkParts{partIndex + 1}; % 4 parçaya bölündü
        % Çerçeve parçası için tekrar işleme geç
        % Burada işleme döngü ve yukarıdaki algoritma yeniden çalışır
    else
        disp('Tüm parçalar işlenmiş durumda.');
    end
end


% Adım 25-29: Su işaretli kısmı çerçeveye entegre et ve video oluştur

% Video dosyasını oluştur
outputVideo = VideoWriter('watermarked_video.avi'); % Su işaretli video
outputVideo.FrameRate = videoObj.FrameRate; % Giriş videosunun kare hızı
open(outputVideo);

% Mavi kanala su işareti uygulamak için hazırlık
if ~exist('watermarkedBlueChannel', 'var') || isempty(watermarkedBlueChannel)
    fprintf('watermarkedBlueChannel değişkeni tanımlanmamış. Varsayılan olarak blueChannel temel alınacak.\n');
    watermarkedBlueChannel = blueChannel; % Başlangıç olarak mavi kanalı kopyala
end

% Watermark uygulanacak bölgeyi tanımla
[watermarkRows, watermarkCols] = size(watermarkedBlueChannel);
fprintf('watermarkedBlueChannel boyutları: %d x %d\n', watermarkRows, watermarkCols);

% Orijinal çerçeve bölgeleri
originalQuadrantRows = 1:watermarkRows; % Satır aralığı
originalQuadrantCols = 1:watermarkCols; % Sütun aralığı

% Watermark parçalarını mavi kanala uygulayın
for partIndex = 1:4
    % Watermark parçasını alın
    watermarkPart = watermarkParts{partIndex};
    
    % Watermark'ın mavi kanaldaki ilgili bölgesini belirleyin
    rowStart = (partIndex - 1) * WP_m + 1;
    rowEnd = min(partIndex * WP_m, M); % Satır sınırı kontrolü
    if rowEnd > size(watermarkedBlueChannel, 1)
        error('Watermark parçası mavi kanalın sınırlarını aşıyor.');
    end
    
    % Su işaretini mavi kanala yerleştirin
    watermarkedBlueChannel(rowStart:rowEnd, :) = watermarkPart;
end

fprintf('Watermark başarıyla mavi kanala uygulandı.\n');



% Çerçeve işleme döngüsü
for frameIndex = 1:numFrames
    % Mevcut çerçeveyi işle
    originalFrame = read(videoObj, frameIndex); % RGB çerçeveyi oku
    
    % Adım 25: Su işaretli kısmı orijinal mavi kanalın yerine entegre et
    % Orijinal mavi kanalın yerine watermark'ı entegre et
    blueChannel(originalQuadrantRows, originalQuadrantCols) = watermarkedBlueChannel;

    % Adım 26: RGB kanalları birleştirerek su işaretli çerçeveyi oluştur
    watermarkedFrameRGB = cat(3, redChannel, greenChannel, watermarkedBlueChannel);

    % Adım 27: Su işaretli çerçeveyi video dizisine entegre et
    writeVideo(outputVideo, uint8(watermarkedFrameRGB)); % Çerçeveyi su işaretli videoya ekle

    % Çerçeve işleminin tamamlandığını belirt
    fprintf('Çerçeve %d işleme tamamlandı.\n', frameIndex);
end

% Adım 28: Tüm çerçeveler işlendiğinde video kaydını kapat
close(outputVideo);

% Adım 29: İşlem tamamlandı
disp('Tüm çerçeveler su işaretlendi ve video başarıyla oluşturuldu.');
