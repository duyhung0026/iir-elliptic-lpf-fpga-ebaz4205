clc;
clear;
close all;

%% CONFIG
ARCH_NAME  = 'tdf2_cascade';         % df1 / df1_cascade / tdf2_cascade
TEST_CASE  = 'th2(250)';    % th1 / th2(150) / th2(250) / th2(350) / th3

DATA_DIR   = '...\...\...\dump_data';
SAVE_DIR   = '...\...\...\image_pdf\new pdf';

VREF       = 3.3;
ADC_LEVELS = 4096;
PLOT_N     = 400;

PDF_WIDTH_PT  = 335;
PDF_HEIGHT_PT = 226;

input_file = fullfile(DATA_DIR,  sprintf('hardware_%s(%s).txt', ARCH_NAME, TEST_CASE));

if ~exist(SAVE_DIR, 'dir')
    mkdir(SAVE_DIR);
end

%% DOC FILE TXT
adc_code = readmatrix(input_file);
adc_code = adc_code(:);

fprintf('Read %d Samples from:\n%s\n', numel(adc_code), input_file);
fprintf('Min = %d, Max = %d, Mean = %.2f\n', min(adc_code), max(adc_code), mean(adc_code));

if numel(adc_code) < PLOT_N
    warning(['File chi co %d mau, it hon PLOT_N = %d '  '-> dung het so mau hien co.'],  numel(adc_code), PLOT_N);
    PLOT_N = numel(adc_code);
end

voltage    = adc_code * VREF / ADC_LEVELS;
sample_idx = (0:PLOT_N-1)';

%% VE HINH
% Dat figure theo point de dong bo chinh xac voi PDF FFT 335 x 226 point
fig_hw = figure( 'Units', 'points',  'Position', [100 100 PDF_WIDTH_PT PDF_HEIGHT_PT], 'Color', 'white');

plot(sample_idx, voltage(1:PLOT_N), 'b', 'LineWidth', 1.0);
grid on;
box on;

ax = gca;
ax.FontName = 'Times New Roman';
ax.FontSize = 10;
ax.LineWidth = 0.8;

ylim([0 VREF]);
xlim([0 PLOT_N]);

xlabel('Sample',  'FontName', 'Times New Roman', 'FontSize', 10);

ylabel('Voltage (V)', 'FontName', 'Times New Roman', 'FontSize', 10);

title('FPGA-IIR Filter Output - UART 921600',  'FontName', 'Times New Roman', 'FontSize', 12,  'FontWeight', 'bold');

last_v   = voltage(PLOT_N);
last_adc = adc_code(PLOT_N);

text(0.02, 0.95,  sprintf('Latest: %.3f V (ADC=%d)', last_v, last_adc),  'Units', 'normalized', 'FontName', 'Times New Roman', 'FontSize', 8,  'Color', [0.3 0.3 0.3]);

set(fig_hw, 'Renderer', 'painters', 'InvertHardcopy', 'off');

switch ARCH_NAME
    case 'df1'
        arch_file = 'df1';
    case 'df1_cascade'
        arch_file = 'df1cascade';
    case 'tdf2_cascade'
        arch_file = 'tdf2cascade';
    otherwise
        arch_file = ARCH_NAME;
end
freq_token = regexp(TEST_CASE, '\((\d+)\)', 'tokens', 'once');

if ~isempty(freq_token)
    test_label = [freq_token{1} 'hz'];
elseif strcmpi(TEST_CASE, 'th1')
    test_label = 'multi';
elseif strcmpi(TEST_CASE, 'th3')
    test_label = 'dc';
else
    all_numbers = regexp(TEST_CASE, '\d+', 'match');

    if ~isempty(all_numbers)
        test_label = [all_numbers{end} 'hz'];
    else
        test_label = 'unknown';
    end
end

hw_export_name = fullfile(SAVE_DIR, ...
    sprintf('%s_%s_hw_output', arch_file, test_label));

pdf_file = [hw_export_name '.pdf'];
png_file = [hw_export_name '.png'];


set(fig_hw, ...
    'PaperUnits', 'points', ...
    'PaperSize', [PDF_WIDTH_PT PDF_HEIGHT_PT], ...
    'PaperPosition', [0 0 PDF_WIDTH_PT PDF_HEIGHT_PT], ...
    'PaperPositionMode', 'manual');

print(fig_hw, pdf_file, '-dpdf', '-painters');

print(fig_hw, png_file, '-dpng', '-r600');

fprintf('\nDa xuat:\n');
fprintf('PDF: %s\n', pdf_file);
fprintf('PNG: %s\n', png_file);
fprintf('Size of PDF: %d x %d point (%.5f x %.5f inch)\n', ...
    PDF_WIDTH_PT, PDF_HEIGHT_PT, ...
    PDF_WIDTH_PT/72, PDF_HEIGHT_PT/72);
