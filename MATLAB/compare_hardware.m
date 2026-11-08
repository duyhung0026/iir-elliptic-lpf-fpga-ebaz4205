clc;
clear;
close all;

TEST_CASE = 'th2(250)';                 % th1 / th2(150) / th2(250) / th2(350) / th3
ARCH_NAME = 'df1_cascade';        % df1 / df1_cascade / tdf2_cascade
TEST_MODE = 'near';                  % multi / near / dc
SINGLE_FREQ = 250;                 % 150 / 250 / 350 when TEST_MODE = near

fs_mat = 35511;
VREF = 3.3;
ADC_MID = 2048;
ADC_LEVELS = 4096;
DC_REF = 1.65;

SKIP_TIME = 0.05;
AUTO_ESTIMATE_FS_HW = true;
FS_HW_MANUAL = fs_mat / 4;

SAVE_DIR = '...\...\...\...\dump_data';
output_file = fullfile(SAVE_DIR, sprintf('hardware_%s(%s).txt', ARCH_NAME, TEST_CASE));

fprintf('\nReading file:\n%s\n', output_file);

switch ARCH_NAME
    case 'df1'
        arch_label = 'DF1 single biquad';
    case 'df1_cascade'
        arch_label = 'DF1 cascade';
    case 'tdf2_cascade'
        arch_label = 'TDF2 cascade';
    otherwise
        error('Invalid ARCH_NAME');
end

switch TEST_MODE
    case 'multi'
        tone_freq = [50 2000 3000];
        tone_amp = [1241 443 266] * VREF / ADC_LEVELS;
        xlim_fft = [0 3500];
        do_fft_test = true;

    case 'near'
        tone_freq = SINGLE_FREQ;
        tone_amp = 1241 * VREF / ADC_LEVELS;
        xlim_fft = [50 250];
        ylim_fft = [-40 3];
        do_fft_test = true;

    case 'dc'
        tone_freq = [];
        tone_amp = [];
        xlim_fft = [0 500];
        do_fft_test = false;

    otherwise
        error('Invalid TEST_MODE');
end

fs = fs_mat;
run('gen_coeff.m');
fs_mat = fs;

% Convert SOS cascade to transfer function
[b4, a4] = sos2tf(sos);

% Get zeros and poles
[z4, p4, k4] = tf2zp(b4, a4);

% Create figure
figure('Name', 'Pole-Zero Plot - 4th Order Elliptic Filter', ...
       'Position', [150 120 700 650]);

zplane(z4, p4);
grid on;
box on;

title('Pole-Zero Plot of the Fourth-Order Elliptic Lowpass Filter', ...
      'FontSize', 12, 'FontWeight', 'bold');

xlabel('Real Part', 'FontSize', 11);
ylabel('Imaginary Part', 'FontSize', 11);

axis equal;
xlim([-1.10 1.10]);
ylim([-1.10 1.10]);

xticks(-1:0.5:1);
yticks(-1:0.5:1);

pbaspect([1 1 1]);

set(gcf, 'Units', 'inches', 'Position', [1 1 4.8 4.8]);
set(gca, 'FontSize', 11, 'LineWidth', 0.8);

% Export PDF and PNG
set(gcf, 'Renderer', 'painters');

exportgraphics(gcf, 'pole_zero_4th_order_full.pdf', ...
    'ContentType', 'vector', ...
    'BackgroundColor', 'white');

exportgraphics(gcf, 'pole_zero_4th_order_full.png', ...
    'Resolution', 600, ...
    'BackgroundColor', 'white');

fprintf('\nExported full pole-zero figure:\n');
fprintf('pole_zero_4th_order_full.pdf\n');
fprintf('pole_zero_4th_order_full.png\n');

hw_out_raw = read_adc_file(output_file);

% Residual voltage relative to ideal 1.65 V / ADC mid-scale
adc_to_residual_v = @(x) (double(x(:)) - ADC_MID) * VREF / ADC_LEVELS;
hw_out = adc_to_residual_v(hw_out_raw);

fprintf('\nDEBUG RAW DATA\n');
fprintf('Number of samples       = %d\n', length(hw_out_raw));
fprintf('First 5 raw ADC samples = %s\n', mat2str(hw_out_raw(1:min(5,end))'));
fprintf('Raw ADC min             = %.3f code\n', min(hw_out_raw));
fprintf('Raw ADC max             = %.3f code\n', max(hw_out_raw));
fprintf('Raw ADC mean            = %.3f code\n', mean(hw_out_raw));
fprintf('Raw ADC std             = %.3f code\n', std(double(hw_out_raw)));

fprintf('\nDEBUG VOLTAGE\n');
fprintf('Output mean deviation from %.2f V = %.6f V\n', DC_REF, mean(hw_out));
fprintf('Output std deviation             = %.6f V\n', std(hw_out));

if do_fft_test
    hw_out = hw_out - mean(hw_out);
end

if do_fft_test && AUTO_ESTIMATE_FS_HW
    fs_hw = estimate_fs_from_tone(hw_out, tone_freq(1));
else
    fs_hw = FS_HW_MANUAL;
end

fprintf('\nfs MATLAB       = %.3f Hz\n', fs_mat);
fprintf('fs Hardware UART = %.3f Hz\n', fs_hw);

T_hw = length(hw_out) / fs_hw;
N_mat = round(T_hw * fs_mat);
t_mat = (0:N_mat-1)' / fs_mat;

if do_fft_test
    mat_in = zeros(N_mat, 1);

    for k = 1:length(tone_freq)
        mat_in = mat_in + tone_amp(k) * sin(2*pi*tone_freq(k)*t_mat);
    end
else
    mat_in = zeros(N_mat, 1);
end

switch ARCH_NAME
    case 'df1'
        mat_out = sosfilt(sos_df1, mat_in);

    case {'df1_cascade', 'tdf2_cascade'}
        mat_out = sosfilt(sos, mat_in);

    otherwise
        error('Invalid ARCH_NAME');
end

if do_fft_test
    mat_in = mat_in - mean(mat_in);
    mat_out = mat_out - mean(mat_out);
end

skip_hw = min(round(SKIP_TIME * fs_hw), length(hw_out) - 10);
skip_mat = min(round(SKIP_TIME * fs_mat), length(mat_out) - 10);

skip_hw = max(skip_hw, 0);
skip_mat = max(skip_mat, 0);

hw_out_a = hw_out(skip_hw+1:end);
mat_in_a = mat_in(skip_mat+1:end);
mat_out_a = mat_out(skip_mat+1:end);
hw_raw_a = hw_out_raw(skip_hw+1:end);

if do_fft_test
    NFFT = 37682;

    [f_mat, MAT_IN_SPEC] = one_sided_spectrum(mat_in_a, fs_mat, NFFT);
    [~, MAT_OUT_SPEC] = one_sided_spectrum(mat_out_a, fs_mat, NFFT);
    [f_hw, HW_OUT_SPEC] = one_sided_spectrum(hw_out_a, fs_hw, NFFT);

    REF_IN = max(tone_amp);

    MAT_IN_dB = 20*log10(MAT_IN_SPEC / REF_IN + eps);
    MAT_OUT_dB = 20*log10(MAT_OUT_SPEC / REF_IN + eps);
    HW_OUT_dB = 20*log10(HW_OUT_SPEC / REF_IN + eps);
end

fprintf('\nRESULTS\n');

if do_fft_test
    A_in = zeros(size(tone_freq));
    A_mat = zeros(size(tone_freq));
    A_hw = zeros(size(tone_freq));

    for k = 1:length(tone_freq)
        f0 = tone_freq(k);
        A_in(k) = amp_at_freq(mat_in_a, fs_mat, f0);
        A_mat(k) = amp_at_freq(mat_out_a, fs_mat, f0);
        A_hw(k) = amp_at_freq(hw_out_a, fs_hw, f0);
    end

    A_in_dB = 20*log10(A_in ./ tone_amp + eps);
    A_mat_dB = 20*log10(A_mat ./ tone_amp + eps);
    A_hw_dB = 20*log10(A_hw ./ tone_amp + eps);
    err_dB = A_hw_dB - A_mat_dB;

    fprintf('%8s %14s %18s %18s %14s\n', ...
        'Freq(Hz)', 'Input(dB)', 'MATLAB out(dB)', 'HW out(dB)', 'Error(dB)');

    for k = 1:length(tone_freq)
        fprintf('%8.0f %14.3f %18.3f %18.3f %14.3f\n', ...
            tone_freq(k), A_in_dB(k), A_mat_dB(k), A_hw_dB(k), err_dB(k));
    end

else
    fprintf('Raw ADC mean after skip                  = %.3f code\n', mean(hw_raw_a));
    fprintf('Raw ADC std after skip                   = %.3f code\n', std(double(hw_raw_a)));
    fprintf('HW output mean deviation from %.2f V      = %.6f V\n', DC_REF, mean(hw_out_a));
    fprintf('HW output std deviation                  = %.6f V\n', std(hw_out_a));
end

if do_fft_test
    fig_title = sprintf('FFT Input and Output - %s - %d Hz', arch_label, SINGLE_FREQ);
else
    fig_title = sprintf('DC Output Stability Check - %s', arch_label);
end

figure('Name', fig_title, 'Position', [150 120 1100 520]);

if do_fft_test
    plot(f_mat, MAT_IN_dB, 'b-', 'LineWidth', 1.0);
    hold on;
    plot(f_mat, MAT_OUT_dB, 'k--', 'LineWidth', 1.6);
    plot(f_hw, HW_OUT_dB, 'r-.', 'LineWidth', 1.3);

    grid on;
    title(fig_title, 'Interpreter', 'none');
    xlabel('Frequency (Hz)');
    ylabel('Amplitude (dB)');

    legend('MATLAB input theory', ...
           'MATLAB output theory', ...
           'Hardware output', ...
           'Location', 'best');

    xlim(xlim_fft);
    ylim(ylim_fft);

% for k = 1:length(tone_freq)
%     xline(tone_freq(k), '--b', sprintf('%d Hz', tone_freq(k)), ...
%         'LabelVerticalAlignment', 'bottom', ...
%         'HandleVisibility', 'off');
% end

else
    t_hw_a = (0:length(hw_out_a)-1)' / fs_hw;

    plot(t_hw_a, hw_out_a, 'b', 'LineWidth', 1.2);
    grid on;

    title(fig_title, 'Interpreter', 'none');
    xlabel('Time (s)');
    ylabel('Output voltage deviation from 1.65 V (V)');

    % No legend for DC plot
end
%% FORMAT FIGURE FOR LATEX EXPORT

% IEEE one-column figure size
set(gcf, 'Units', 'inches', 'Position', [1 1 5.2 3.2]);

% Font size
set(gca, 'FontSize', 12);

% Line width and box
set(gca, 'LineWidth', 0.8);
box on;

% Make title and axis labels larger
title(fig_title, 'Interpreter', 'none', 'FontSize', 12, 'FontWeight', 'bold');

if do_fft_test
    xlabel('Frequency (Hz)', 'FontSize', 10);
    ylabel('Amplitude (dB)', 'FontSize', 10);

    lgd = legend('MATLAB input theory', ...
                 'MATLAB output theory', ...
                 'Hardware output', ...
                 'Location', 'best');
    set(lgd, 'FontSize', 7);
else
    xlabel('Time (s)', 'FontSize', 10);
    ylabel('Output voltage deviation from 1.65 V (V)', 'FontSize', 10);
end

switch ARCH_NAME
    case 'df1'
        arch_file = 'df1';
    case 'df1_cascade'
        arch_file = 'df1cascade';
    case 'tdf2_cascade'
        arch_file = 'tdf2cascade';
end

if do_fft_test
    export_name = sprintf('%s_%dhz_fft', arch_file, SINGLE_FREQ);
else
    export_name = sprintf('%s_dc_time', arch_file);
end

set(gcf, 'Renderer', 'painters');

exportgraphics(gcf, [export_name '.pdf'], ...
    'ContentType', 'vector', ...
    'BackgroundColor', 'white');

exportgraphics(gcf, [export_name '.png'], ...
    'Resolution', 600, ...
    'BackgroundColor', 'white');

fprintf('\nExported figure:\n');
fprintf('%s.pdf\n', export_name);
fprintf('%s.png\n', export_name);

function x = read_adc_file(fname)
    if ~isfile(fname)
        error('File not found: %s', fname);
    end

    lines = strtrim(readlines(fname));
    lines(lines == "") = [];
    x = zeros(length(lines), 1);

    for i = 1:length(lines)
        s = char(lines(i));

        if any(isstrprop(s, 'alpha'))
            x(i) = hex2dec(s);
        else
            x(i) = str2double(s);
        end
    end

    x = max(0, min(4095, x));
end

function [f, A] = one_sided_spectrum(x, fs, NFFT)
    x = x(:) - mean(x);
    N = length(x);
    n = (0:N-1)';

    w = 0.5 - 0.5*cos(2*pi*n/(N-1));

    X = fft(x .* w, NFFT);

    A = abs(X(1:NFFT/2+1)) * 2 / sum(w);
    A(1) = A(1) / 2;

    f = (0:NFFT/2)' * fs / NFFT;
end

function A = amp_at_freq(x, fs, f0)
    x = x(:) - mean(x);
    N = length(x);
    n = (0:N-1)';

    w = 0.5 - 0.5*cos(2*pi*n/(N-1));

    Xf = sum((x .* w) .* exp(-1j*2*pi*f0*n/fs));

    A = 2 * abs(Xf) / sum(w);
end

function fs_est = estimate_fs_from_tone(x, f_tone)
    x = x(:) - mean(x);
    N = length(x);

    NFFT = max(32768, 2^nextpow2(N * 8));
    n = (0:N-1)';

    w = 0.5 - 0.5*cos(2*pi*n/(N-1));

    X = abs(fft(x .* w, NFFT));
    X = X(1:NFFT/2+1);
    X(1:5) = 0;

    [~, idx] = max(X);

    if idx > 1 && idx < length(X)
        y1 = X(idx-1);
        y2 = X(idx);
        y3 = X(idx+1);

        denom = y1 - 2*y2 + y3;

        if abs(denom) > eps
            delta = 0.5 * (y1 - y3) / denom;
        else
            delta = 0;
        end
    else
        delta = 0;
    end

    bin_est = (idx - 1) + delta;
    f_norm = bin_est / NFFT;

    fs_est = f_tone / f_norm;
end
