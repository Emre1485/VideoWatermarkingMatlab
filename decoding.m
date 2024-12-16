%% STEP 1: Read the Watermarked Video
% Load the watermarked video and read frames
watermarkedVideo = VideoReader('watermarked_video.avi');
frames = {};
frameIndex = 1;

while hasFrame(watermarkedVideo)
    frames{frameIndex} = readFrame(watermarkedVideo);
    frameIndex = frameIndex + 1;
end

numFrames = length(frames);
display(['Number of frames read: ', num2str(numFrames)]);

%% STEP 2: Apply a Simulated Attack
% Simulate an attack (e.g., adding noise, compression, etc.)
attackedFrames = frames; % Initialize attacked frames

for i = 1:numFrames
    % Example: Add Gaussian noise to each frame
    attackedFrames{i} = imnoise(attackedFrames{i}, 'gaussian', 0, 0.01); 
end

display('Simulated attack applied to frames.');

%% STEP 3: Repeat Embedding Algorithm Steps 2 to 5
% Extract the blue channel from each attacked frame and prepare for decoding
blueChannelFrames = {};
for i = 1:numFrames
    currentFrame = attackedFrames{i};
    blueChannelFrames{i} = currentFrame(:, :, 3); % Extract the blue channel
end

display('Blue channel extracted from attacked frames.');

%% STEP 4: Decode Watermark Parts (Simulating FPGA Functionality)
% Define watermark dimensions and parameters (adjust as necessary)
[watermarkRows, watermarkCols] = size(blueChannelFrames{1});
WP_m = watermarkRows / 4; % Assume 4 parts as in encoding
watermarkParts = cell(1, 4);

% Extract watermark parts from blue channel regions
for partIndex = 1:4
    rowStart = (partIndex - 1) * WP_m + 1;
    rowEnd = partIndex * WP_m;
    watermarkParts{partIndex} = blueChannelFrames{1}(rowStart:rowEnd, :); % Extract part
end

display('Watermark parts extracted from the blue channel.');

%% Combine Watermark Parts into Full Watermark
% Reconstruct the full watermark from the extracted parts
reconstructedWatermark = cat(1, watermarkParts{:});

% Display the reconstructed watermark
imshow(reconstructedWatermark, []);
title('Reconstructed Watermark');

%% STEP 5: Divide Watermark into Blocks and Count Pixels
% Assume each block is of size BxB
blockSize = 8; % Example block size
blocks = mat2cell(reconstructedWatermark, repmat(blockSize, 1, size(reconstructedWatermark, 1)/blockSize), repmat(blockSize, 1, size(reconstructedWatermark, 2)/blockSize));

%% STEP 6: Pick the First Block
currentBlock = blocks{1, 1};

% Visualize the first block
imshow(currentBlock, []);
title('First Block');

%% STEP 7: Initialize Counter and Process Pixels
counter = 0; % Initialize the counter

%% STEP 8: Loop Through Pixels in the Block
[blockRows, blockCols] = size(currentBlock);
for row = 1:blockRows
    for col = 1:blockCols
        pixel = currentBlock(row, col); % Pick the pixel

        % STEP 9: Divide the pixel into MSB and LSB
        msb = bitshift(pixel, -4); % Most Significant Bits (upper 4 bits)
        lsb = bitand(pixel, 15);  % Least Significant Bits (lower 4 bits)

        % Calculate parity
        parityMSB = mod(sum(bitget(msb, 1:4)), 2); % Parity of MSB
        parityLSB = mod(sum(bitget(lsb, 1:4)), 2); % Parity of LSB

        % STEP 10: Check parity condition
        if parityMSB == 0 || parityLSB == 0
            counter = counter + 1;
        end
    end
end

display(['Counter value: ', num2str(counter)]);

%% STEP 12: Compare Counter with Block Pixel Count
numPixelsInBlock = blockRows * blockCols;
if counter > numPixelsInBlock / 2
    watermarkBit = '0';
else
    watermarkBit = '1';
end

display(['Watermark bit for current block: ', watermarkBit]);

%% STEP 13: Process Remaining Blocks in the Part
watermarkBits = ''; % Initialize watermark bits string
for blockIndex = 1:numel(blocks)
    currentBlock = blocks{blockIndex};
    counter = 0; % Reset counter for each block

    % Loop through pixels in the block
    [blockRows, blockCols] = size(currentBlock);
    for row = 1:blockRows
        for col = 1:blockCols
            pixel = currentBlock(row, col);

            % Divide the pixel into MSB and LSB
            msb = bitshift(pixel, -4);
            lsb = bitand(pixel, 15);

            % Calculate parity
            parityMSB = mod(sum(bitget(msb, 1:4)), 2);
            parityLSB = mod(sum(bitget(lsb, 1:4)), 2);

            % Check parity condition
            if parityMSB == 0 || parityLSB == 0
                counter = counter + 1;
            end
        end
    end

    % Compare counter with block pixel count
    if counter > numPixelsInBlock / 2
        watermarkBits = strcat(watermarkBits, '0');
    else
        watermarkBits = strcat(watermarkBits, '1');
    end
end

display(['Watermark bits for current part: ', watermarkBits]);

%% STEP 14: Send Watermark Part to PC
% Assuming sending is simulated as storing the bits
receivedWatermarkParts = watermarkBits; % Simulate sending and receiving

display(['Received watermark part: ', receivedWatermarkParts]);

%% STEP 15: Process All Parts of the Current Frame
fullWatermark = '';
for partIndex = 1:length(watermarkParts)
    % Simulate processing each part (use above logic for each part)
    fullWatermark = strcat(fullWatermark, receivedWatermarkParts);
end

display(['Full reconstructed watermark: ', fullWatermark]);

%% STEP 16: Construct the Watermark Image
% Combine received watermark parts into the final watermark image
numericWatermark = arrayfun(@(x) str2double(x), fullWatermark);

% Hedef boyutların eleman sayısını kontrol et
expectedElements = watermarkRows * watermarkCols;

if numel(numericWatermark) ~= expectedElements
    error('Number of elements in numericWatermark (%d) does not match expected size (%d).', ...
          numel(numericWatermark), expectedElements);
end

% Doğru boyutlara yeniden şekillendir
finalWatermark = reshape(numericWatermark, watermarkRows, watermarkCols);

% Final watermark görüntüsünü göster
imshow(finalWatermark, []);
title('Final Watermark Image');


%% STEP 17: Repeat for All Watermarked Frames
for frameIdx = 1:numFrames
    % Repeat decoding process for each frame
    % (This is a simplified demonstration; adapt logic as needed)
    display(['Processing frame ', num2str(frameIdx), ' of ', num2str(numFrames)]);
end

display('All frames processed.');

%% STEP 18: End
% Final cleanup and termination
clearvars;
display('Decoding process completed.');
