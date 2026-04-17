function [data, original_name] = convert_csv_to_series(filename)

    T = readtable(filename);
    
    original_name = T.Properties.VariableNames{2}; % second column name
    
    % Rename to 'Close'
    T.Properties.VariableNames{2} = 'Close';
    
    data = T;
end
%%
function [log_returns, name] = convert_prices_to_log_return(filename)

    [data, name] = convert_csv_to_series(filename);
    
    prices = data.Close;
    
    log_returns = diff(log(prices)); % log returns
end
%%
function [mu_hat, sigma_hat, sigma_sq_hat] = estimate_from_data(data, dt)

    sigma_sq_hat = var(data, 1) / dt;   % variance
    sigma_hat = sqrt(sigma_sq_hat);
    
    mu_hat = (mean(data) / dt) + (sigma_sq_hat / 2);
end
%%
function [mean_path, lower_path, upper_path, mu_hat, sigma_sq_hat] = simulate_prices(data_price, data_log_return, T, dt, n_simulations)

    [mu_hat, sigma_hat, sigma_sq_hat] = estimate_from_data(data_log_return, dt);
    
    drift = (mu_hat - 0.5 * sigma_hat^2) * dt;
    
    S0 = data_price(end);
    
    paths = zeros(T, n_simulations);
    paths(1, :) = S0;

    for t = 2:T
        Z = randn(1, n_simulations);
        paths(t, :) = paths(t-1, :) .* exp(drift + sigma_hat * sqrt(dt) .* Z);
    end
    
    mean_path  = mean(paths, 2);
    lower_path = prctile(paths, 2.5, 2);
    upper_path = prctile(paths, 97.5, 2);
end
%%
function [mean_path, lower_path, upper_path, param_table] = final_result(data_log_return, data_prices, test_data)

    T = height(test_data);
    dt = 1/252;
    n_simulations = 1000;
    
    [mean_path, lower_path, upper_path, mu_hat, sigma_sq_hat] = ...
        simulate_prices(data_prices, data_log_return, T, dt, n_simulations);

    % Create table
    param_table = table(mu_hat, sigma_sq_hat, ...
        'VariableNames', {'Mu_hat', 'Sigma_Square_hat'});
end
%%
function plot_predictions(test_data, mean_path, lower_path, upper_path, title_str)

    dates = datetime(test_data.Date);
    actual = test_data{:,2}; % second column
    
    T = min(length(dates), length(mean_path));
    
    dates = dates(1:T);
    actual = actual(1:T);
    mean_path = mean_path(1:T);
    lower_path = lower_path(1:T);
    upper_path = upper_path(1:T);
    
    % Metrics
    rmse = sqrt(mean((actual - mean_path).^2));
    mape = mean(abs((actual - mean_path) ./ actual)) * 100;
    
    figure;
    hold on;
    
    % Confidence band
    fill([dates; flipud(dates)], ...
         [lower_path; flipud(upper_path)], ...
         [0.8 0.8 0.8], 'FaceAlpha', 0.3, 'EdgeColor', 'none', ...
         'DisplayName', '95% Confidence Band');
    
    % Actual
    plot(dates, actual, 'LineWidth', 2, 'DisplayName', 'Actual');
    
    % Mean prediction
    plot(dates, mean_path, '--', 'LineWidth', 2, 'DisplayName', 'Predicted (Mean)');
    
    title(title_str);
    xlabel('Date');
    ylabel('Price');
    legend;
    grid on;
    
    % Metrics text
    text(dates(round(T*0.6)), max(actual), ...
        sprintf('RMSE = %.3f\nMAPE = %.3f%%', rmse, mape), ...
        'BackgroundColor', 'white');
    
    hold off;
end
%%
% Load data
[log_returns, ~] = convert_prices_to_log_return('sbi_main.csv');
[data_prices_table, ~] = convert_csv_to_series('sbi_main.csv');
test_data = readtable('sbi_test.csv');

data_prices = data_prices_table.Close;

% Run model
[mean_path, lower_path, upper_path, param_table] = final_result( ...
    log_returns, data_prices, test_data);

% Display parameter estimates
disp('Estimated Parameters:');
disp(param_table);

% Plot
plot_predictions(test_data, mean_path, lower_path, upper_path, ...
    'SBIN.NS — GBM Price Prediction');